import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/app_logger.dart';
import 'package:mechanix_browser/features/browser/bloc/download/browser_download.dart';
import 'package:mechanix_browser/features/browser/bloc/download/download_service.dart';
import 'package:mechanix_browser/features/browser/bloc/download/download_session_manager.dart';
import 'package:mechanix_browser/features/browser/data/repositories/download_repository.dart';
import 'package:webview_cef/webview_cef.dart';

part 'download_event.dart';
part 'download_state.dart';

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  /// ObjectBox database repository for persistent download history.
  final DownloadRepository? repository;

  /// Manages active WebViewController mappings and background tab controller teardowns.
  final DownloadSessionManager _sessionManager = DownloadSessionManager();

  /// Stores the timestamp of the last ObjectBox DB write per composite download ID for throttling.
  ///
  /// **Why Database Writes Are Throttled:**
  /// High-frequency CEF progress updates fire dozens of times per second during active downloading.
  /// Throttling ObjectBox saves to at most once per 1000ms prevents excessive synchronous disk I/O on the main thread.
  final Map<int, DateTime> _lastDbSaveMap = {};

  /// Stores ObjectBox primary keys (`id`) for retried/restarted downloads to reuse existing DB records.
  final Set<int> _pendingRetryRecordIds = {};

  DownloadBloc({this.repository}) : super(DownloadState.initial()) {
    on<DownloadInitializeRequested>(_onInitialize);
    on<DownloadBeforeStarted>(_onBeforeStarted);
    on<DownloadUpdatedEvent>(_onUpdated);
    on<DownloadCancelRequested>(_onCancelRequested);
    on<DownloadPauseRequested>(_onPauseRequested);
    on<DownloadResumeRequested>(_onResumeRequested);
    on<DownloadRemoveRequested>(_onRemoveRequested);
    on<DownloadRetryRequested>(_onRetryRequested);
    on<DownloadRestartRequested>(_onRestartRequested);
    on<DownloadClearCompletedRequested>(_onClearCompleted);
  }

  /// Generates a composite download ID combining the controller's hash and native CEF download ID.
  /// Guarantees unique download identification across multiple concurrent webview tabs.
  static int getCompositeDownloadId(
    WebViewController controller,
    int rawCefDownloadId,
  ) {
    final controllerHash = controller.hashCode.abs() % 100000;
    return controllerHash * 100000 + (rawCefDownloadId % 100000);
  }

  /// Registers a [WebViewController] whose tab was closed, to defer disposal until all its active downloads finish.
  void registerPendingDisposeController(WebViewController controller) {
    _sessionManager.registerPendingDisposeController(controller);
  }

  /// Checks if a [WebViewController] is actively handling any in-progress downloads.
  bool isControllerActive(WebViewController controller) {
    return _sessionManager.isControllerActive(controller);
  }

  /// Locates an existing download record index in state matching a retry request.
  ///
  /// **Multi-Strategy Retry Matching:**
  /// 1. Exact match on CEF download ID (active tab session).
  /// 2. Filename stem / destination path match (handles duplicate URL downloads).
  /// 3. Source URL fallback match among pending retry record IDs.
  int _findMatchingRetryIndex({
    required int compositeId,
    required int rawCefId,
    required String sanitizedName,
    required String url,
  }) {
    if (_pendingRetryRecordIds.isEmpty) return -1;

    // 1. Try exact match on CEF download ID
    int index = state.downloads.indexWhere(
      (d) =>
          _pendingRetryRecordIds.contains(d.id) &&
          (d.downloadId == compositeId || d.downloadId == rawCefId),
    );

    // 2. Try match on filename/destination stem to distinguish duplicate URL downloads
    if (index == -1) {
      index = state.downloads.indexWhere(
        (d) =>
            _pendingRetryRecordIds.contains(d.id) &&
            (d.filename == sanitizedName ||
                d.destinationPath.endsWith(sanitizedName)),
      );
    }

    // 3. Fall back to URL matching among pending retry IDs
    if (index == -1) {
      index = state.downloads.indexWhere(
        (d) => _pendingRetryRecordIds.contains(d.id) && d.url == url,
      );
    }

    return index;
  }

  /// Persists [download] entity to ObjectBox and returns updated download with assigned DB primary key.
  BrowserDownload _saveDownloadToRepo(BrowserDownload download) {
    final repo = repository;
    if (repo == null) return download;
    final dbId = repo.saveDownload(download.toEntity());
    return download.id != dbId ? download.copyWith(id: dbId) : download;
  }

  /// Updates or inserts [updatedDownload] item in state and emits updated state to UI listeners.
  void _updateStateWithDownload(
    Emitter<DownloadState> emit,
    BrowserDownload updatedDownload, {
    int existingIndex = -1,
  }) {
    final updatedList = List<BrowserDownload>.from(state.downloads);
    final targetIndex = existingIndex != -1
        ? existingIndex
        : updatedList.indexWhere(
            (d) =>
                (updatedDownload.id > 0 && d.id == updatedDownload.id) ||
                (d.downloadId != 0 &&
                    d.downloadId == updatedDownload.downloadId),
          );

    if (targetIndex != -1) {
      updatedList[targetIndex] = updatedDownload;
    } else {
      updatedList.removeWhere(
        (d) => (d.id == 0 && d.downloadId == updatedDownload.downloadId),
      );
      updatedList.insert(0, updatedDownload);
    }

    emit(
      state.copyWith(
        downloads: updatedList,
        lastStartedOrUpdated: updatedDownload,
      ),
    );
  }

  /// Handles initial application startup initialization.
  ///
  /// **Crash Recovery Workflow:**
  /// 1. Queries ObjectBox DB for all saved download records.
  /// 2. Converts abandoned incomplete downloads (`downloading`, `pending`, `paused`) from previous crashed/killed sessions to `interrupted`.
  /// 3. Deletes partial `.crdownload` buffer files from disk.
  /// 4. Emits restored download history into state for UI rendering.
  Future<void> _onInitialize(
    DownloadInitializeRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final repo = repository;
    if (repo == null) return;
    try {
      final entities = repo.getAllDownloads();
      AppLogger.i(
        '[DownloadBloc] Initialized download history. Loaded ${entities.length} records from DB',
      );

      final loadedDownloads = <BrowserDownload>[];

      for (final entity in entities) {
        if (entity.statusIndex == DownloadStatus.downloading.index ||
            entity.statusIndex == DownloadStatus.pending.index ||
            entity.statusIndex == DownloadStatus.paused.index) {
          AppLogger.i(
            '[DownloadBloc] Download interrupted on browser restart id=${entity.id} (url=${entity.url})',
          );
          entity.statusIndex = DownloadStatus.interrupted.index;
          entity.errorMessage = 'Interrupted';

          if (entity.filePath.isNotEmpty) {
            await DownloadService.deleteFileFromDisk(entity.filePath);
          }

          repo.saveDownload(entity);
        }

        loadedDownloads.add(BrowserDownload.fromEntity(entity));
      }

      emit(state.copyWith(downloads: loadedDownloads));
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error initializing download history: $e',
        error: e,
        stack: stackTrace,
      );
    }
  }

  /// Handles initial download request triggered by CEF engine (`OnBeforeDownload`).
  ///
  /// **Workflow:**
  /// 1. Computes composite unique download ID combining controller hash and native CEF ID.
  /// 2. Sanitizes suggested filename and resolves target Downloads directory path.
  /// 3. Checks if request links to a retried/restarted record in `_pendingRetryRecordIds`.
  /// 4. Resolves destination file path and handles collisions (`file (1).zip`).
  /// 5. Persists initial record in ObjectBox DB to obtain persistent primary key `id > 0`.
  /// 6. Calls native `controller.continueDownload(rawCefId, destPath)` to start byte streaming.
  Future<void> _onBeforeStarted(
    DownloadBeforeStarted event,
    Emitter<DownloadState> emit,
  ) async {
    try {
      final rawCefId = event.downloadId;
      final compositeId = getCompositeDownloadId(event.controller, rawCefId);

      _sessionManager.registerSession(compositeId, rawCefId, event.controller);

      final dirPath = await DownloadService.getDownloadsDirectoryPath();
      final sanitizedName = DownloadService.sanitizeFilename(
        event.suggestedName,
        event.url,
      );

      final existingIndex = _findMatchingRetryIndex(
        compositeId: compositeId,
        rawCefId: rawCefId,
        sanitizedName: sanitizedName,
        url: event.url,
      );

      int targetDbId = 0;
      if (existingIndex != -1) {
        // Retrieve DB primary key to link transfer to existing record instead of creating a duplicate
        targetDbId = state.downloads[existingIndex].id;
        // Consume the ID from the pending retries set now that matching succeeded
        _pendingRetryRecordIds.remove(targetDbId);
        AppLogger.i(
          '[DownloadBloc] Linked retry/restart request to existing database record id=$targetDbId for url=${event.url}',
        );
      }

      final activePaths = state.downloads
          .where(
            (d) => d.status == DownloadStatus.downloading && d.id != targetDbId,
          )
          .map((d) => d.destinationPath)
          .toSet();

      final String destPath;
      if (targetDbId > 0 &&
          existingIndex != -1 &&
          state.downloads[existingIndex].destinationPath.isNotEmpty) {
        // Reuse original destination path for retried or restarted downloads
        destPath = state.downloads[existingIndex].destinationPath;
      } else {
        // Generate a new unique destination path for new downloads to avoid filename collisions
        destPath = DownloadService.getUniqueDestinationPath(
          dirPath,
          sanitizedName,
          activePaths: activePaths,
        );
      }

      final extractedFilename = destPath.split('/').last.split('\\').last;

      var newDownload = BrowserDownload(
        id: targetDbId,
        downloadId: compositeId,
        url: event.url,
        filename: extractedFilename,
        destinationPath: destPath,
        receivedBytes: 0,
        totalBytes: event.totalBytes,
        currentSpeed: 0,
        progress: 0.0,
        status: DownloadStatus.downloading,
        startTimestamp: DateTime.now(),
      );

      newDownload = _saveDownloadToRepo(newDownload);
      AppLogger.i(
        '[DownloadBloc] Starting download id=${newDownload.id} (compositeId=$compositeId, rawCefId=$rawCefId, file=${newDownload.filename}, url=${event.url})',
      );

      _updateStateWithDownload(emit, newDownload, existingIndex: existingIndex);

      // Instruct CEF native webview controller to start writing data stream to destPath
      await event.controller.continueDownload(
        rawCefId,
        destPath,
        showDialog: false,
      );
    } catch (e) {
      AppLogger.e('Error handling download before start: $e');
    }
  }

  /// Handles progress tick events emitted by CEF engine during active downloading.
  ///
  /// **Workflow:**
  /// 1. Matches incoming composite download ID to active state list.
  /// 2. Translates native CEF event flags (`isComplete`, `isCanceled`, `isInterrupted`) into domain [DownloadStatus].
  /// 3. Computes progress percentage and updates transfer speed / received bytes.
  /// 4. **DB Write Throttling:** Persists to ObjectBox at most once per 1000ms, or immediately on terminal status.
  /// 5. Disposes pending background controllers when terminal status is reached.
  void _onUpdated(DownloadUpdatedEvent event, Emitter<DownloadState> emit) {
    final compositeId = getCompositeDownloadId(
      event.controller,
      event.downloadId,
    );

    final index = state.downloads.indexWhere(
      (d) => d.downloadId == compositeId,
    );
    if (index == -1) return;

    final existing = state.downloads[index];

    DownloadStatus status;
    String? errorMsg;

    if (existing.status == DownloadStatus.paused &&
        !event.isComplete &&
        !event.isCanceled &&
        !event.isInterrupted) {
      status = DownloadStatus.paused;
    } else {
      switch (event) {
        case _ when event.isComplete:
          status = DownloadStatus.completed;
        case _ when event.isCanceled:
          status = DownloadStatus.cancelled;
          errorMsg = 'Cancelled';
        case _ when event.isInterrupted:
          status = DownloadStatus.failed;
          errorMsg = _getInterruptReasonText(event.interruptReason);
        default:
          status = DownloadStatus.downloading;
      }
    }

    double progress = 0.0;
    if (event.totalBytes > 0) {
      progress = (event.receivedBytes / event.totalBytes).clamp(0.0, 1.0);
    }

    final filename = event.fullPath.isNotEmpty
        ? event.fullPath.split('/').last.split('\\').last
        : existing.filename;

    BrowserDownload updatedDownload = existing.copyWith(
      filename: filename,
      destinationPath: event.fullPath.isNotEmpty
          ? event.fullPath
          : existing.destinationPath,
      receivedBytes: event.receivedBytes,
      totalBytes: event.totalBytes > 0 ? event.totalBytes : existing.totalBytes,
      currentSpeed: event.currentSpeed,
      progress: progress,
      status: status,
      endTime:
          (status == DownloadStatus.completed ||
              status == DownloadStatus.failed ||
              status == DownloadStatus.cancelled)
          ? DateTime.now()
          : existing.endTime,
      errorMessage: errorMsg ?? existing.errorMessage,
    );

    final now = DateTime.now();
    final lastSave = _lastDbSaveMap[compositeId];
    final isTerminal =
        status == DownloadStatus.completed ||
        status == DownloadStatus.failed ||
        status == DownloadStatus.cancelled ||
        status == DownloadStatus.paused;

    if (isTerminal ||
        lastSave == null ||
        now.difference(lastSave).inMilliseconds >= 1000) {
      updatedDownload = _saveDownloadToRepo(updatedDownload);
      _lastDbSaveMap[compositeId] = now;
    }

    _updateStateWithDownload(emit, updatedDownload, existingIndex: index);

    // Minimal structured logging for key terminal lifecycle transitions
    if (status == DownloadStatus.completed) {
      AppLogger.i(
        '[DownloadBloc] Download completed id=${updatedDownload.id} (file=${updatedDownload.filename}, bytes=${updatedDownload.receivedBytes})',
      );
    } else if (status == DownloadStatus.failed) {
      AppLogger.i(
        '[DownloadBloc] Download failed id=${updatedDownload.id} (reason=${updatedDownload.errorMessage})',
      );
    } else if (status == DownloadStatus.cancelled) {
      AppLogger.i('[DownloadBloc] Download cancelled id=${updatedDownload.id}');
    }

    if (isTerminal && status != DownloadStatus.paused) {
      _sessionManager.removeSession(compositeId);
      _lastDbSaveMap.remove(compositeId);
      _sessionManager.checkAndDisposePendingController(
        event.controller,
        state.downloads,
      );
    }
  }

  /// Cancels an active download stream.
  ///
  /// **Workflow:**
  /// 1. Issues `cancelDownload` command to native CEF engine controller.
  /// 2. Purges active session mappings.
  /// 3. Updates ObjectBox record status to `cancelled`.
  /// 4. Disposes background WebViewController if closed tab has no other active transfers.
  Future<void> _onCancelRequested(
    DownloadCancelRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final index = state.downloads.indexWhere(
      (d) => d.id == event.downloadId || d.downloadId == event.downloadId,
    );

    if (index != -1) {
      final item = state.downloads[index];
      AppLogger.i(
        '[DownloadBloc] Cancelling download id=${item.id} (compositeId=${item.downloadId})',
      );

      final controller = _sessionManager.getController(item.downloadId);
      final rawCefId = _sessionManager.getRawCefId(item.downloadId);

      if (controller != null) {
        await controller.cancelDownload(rawCefId);
      }
      _sessionManager.removeSession(item.downloadId);

      var updated = item.copyWith(
        status: DownloadStatus.cancelled,
        errorMessage: 'Cancelled',
        endTime: DateTime.now(),
      );

      if (updated.id > 0) {
        updated = _saveDownloadToRepo(updated);
      }

      _updateStateWithDownload(emit, updated, existingIndex: index);

      if (controller != null) {
        _sessionManager.checkAndDisposePendingController(
          controller,
          state.downloads,
        );
      }
    }
  }

  /// Pauses an active download stream.
  Future<void> _onPauseRequested(
    DownloadPauseRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final index = state.downloads.indexWhere(
      (d) => d.id == event.downloadId || d.downloadId == event.downloadId,
    );

    if (index != -1) {
      final item = state.downloads[index];
      AppLogger.i(
        '[DownloadBloc] Pausing download id=${item.id} (compositeId=${item.downloadId})',
      );

      final controller = _sessionManager.getController(item.downloadId);
      final rawCefId = _sessionManager.getRawCefId(item.downloadId);

      if (controller != null) {
        await controller.pauseDownload(rawCefId);
      }

      var updated = item.copyWith(status: DownloadStatus.paused);
      if (updated.id > 0) {
        updated = _saveDownloadToRepo(updated);
      }

      _updateStateWithDownload(emit, updated, existingIndex: index);
    }
  }

  /// Resumes a paused download stream.
  ///
  /// **Workflow:**
  /// 1. If native CEF controller stream is active in memory, issues `resumeDownload(rawCefId)`.
  /// 2. If stream/tab was closed, falls back to reloading source URL in webview (`loadUrl`) while adding ID to `_pendingRetryRecordIds`.
  Future<void> _onResumeRequested(
    DownloadResumeRequested event,
    Emitter<DownloadState> emit,
  ) async {
    try {
      final index = state.downloads.indexWhere(
        (d) => d.id == event.downloadId || d.downloadId == event.downloadId,
      );

      if (index != -1) {
        final download = state.downloads[index];
        AppLogger.i(
          '[DownloadBloc] Resuming download id=${download.id} (compositeId=${download.downloadId})',
        );

        final controller =
            event.controller ??
            _sessionManager.getController(download.downloadId);
        final rawCefId = _sessionManager.getRawCefId(download.downloadId);

        if (download.status == DownloadStatus.paused &&
            controller != null &&
            controller.value) {
          await controller.resumeDownload(rawCefId);
          var updated = download.copyWith(status: DownloadStatus.downloading);
          if (updated.id > 0) {
            updated = _saveDownloadToRepo(updated);
          }
          _updateStateWithDownload(emit, updated, existingIndex: index);
        } else if (controller != null && controller.value) {
          if (download.id > 0) {
            _pendingRetryRecordIds.add(download.id);
          }
          await controller.loadUrl(download.url);
        } else {
          AppLogger.i(
            '[DownloadBloc] Cannot resume download id=${download.id}: No active webview controller available.',
          );
        }
      }
    } catch (e) {
      AppLogger.e("Error resuming download: $e");
    }
  }

  /// Removes a download record from state and ObjectBox storage.
  ///
  /// **History Removal vs File Deletion:**
  /// - `event.deleteFile == true`: Deletes physical target file and `.crdownload` file from disk via `DownloadService.deleteFileFromDisk`.
  /// - `event.deleteFile == false`: Leaves physical file on disk intact and only deletes ObjectBox DB record and state entry.
  Future<void> _onRemoveRequested(
    DownloadRemoveRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final index = state.downloads.indexWhere(
      (d) =>
          d.id == event.downloadId ||
          (d.id == 0 && d.downloadId == event.downloadId),
    );

    if (index != -1) {
      final item = state.downloads[index];
      final targetRecordId = item.id != 0 ? item.id : event.downloadId;

      AppLogger.i(
        '[DownloadBloc] Removing download id=$targetRecordId (deleteFile=${event.deleteFile})',
      );

      if (event.deleteFile && item.destinationPath.isNotEmpty) {
        try {
          await DownloadService.deleteFileFromDisk(item.destinationPath);
        } catch (e) {
          AppLogger.i('Error deleting file on disk $e');
        }
      }

      final repo = repository;
      if (repo != null && targetRecordId > 0) {
        repo.deleteDownload(targetRecordId);
      }

      final controller = _sessionManager.getController(item.downloadId);
      final rawCefId = _sessionManager.getRawCefId(item.downloadId);

      if ((item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.pending ||
              item.status == DownloadStatus.paused) &&
          controller != null) {
        try {
          await controller.cancelDownload(rawCefId);
        } catch (e) {
          AppLogger.i('Error cancelling CEF download stream on remove: $e');
        }
      }

      _sessionManager.removeSession(item.downloadId);
      _lastDbSaveMap.remove(item.downloadId);

      if (controller != null) {
        _sessionManager.checkAndDisposePendingController(
          controller,
          state.downloads,
        );
      }
    } else {
      final repo = repository;
      if (repo != null && event.downloadId > 0) {
        repo.deleteDownload(event.downloadId);
      }
    }

    final updatedList = List<BrowserDownload>.from(state.downloads)
      ..removeWhere(
        (d) =>
            d.id == event.downloadId ||
            (d.id == 0 && d.downloadId == event.downloadId),
      );

    emit(state.copyWith(downloads: updatedList));
  }

  /// Retries a failed download by reloading source URL in webview.
  ///
  /// **Workflow:**
  /// 1. Registers persistent `id` in `_pendingRetryRecordIds`.
  /// 2. Reloads source URL in webview via `controller.loadUrl(item.url)`.
  /// 3. Subsequent `_onBeforeStarted` matches `_pendingRetryRecordIds` to reuse existing database ID.
  Future<void> _onRetryRequested(
    DownloadRetryRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final index = state.downloads.indexWhere(
      (d) =>
          (event.download.id > 0 && d.id == event.download.id) ||
          (d.downloadId != 0 && d.downloadId == event.download.downloadId) ||
          (d.url == event.download.url),
    );
    final item = index != -1 ? state.downloads[index] : event.download;

    AppLogger.i(
      '[DownloadBloc] Retrying download id=${item.id}, file=${item.filename}',
    );

    if (item.id > 0) {
      _pendingRetryRecordIds.add(item.id);
    }

    final controller =
        event.controller ?? _sessionManager.getController(item.downloadId);
    if (controller != null && controller.value) {
      await controller.loadUrl(item.url);
    } else {
      AppLogger.i(
        "No active webview controller available to retry download ${event.download.filename}",
      );
    }
  }

  /// Restarts a download from byte 0, discarding any partial `.crdownload` file on disk.
  Future<void> _onRestartRequested(
    DownloadRestartRequested event,
    Emitter<DownloadState> emit,
  ) async {
    AppLogger.i(
      '[DownloadBloc] Restarting download id=${event.download.id} from byte 0',
    );

    if (event.download.destinationPath.isNotEmpty) {
      try {
        await DownloadService.deleteFileFromDisk(
          event.download.destinationPath,
        );
      } catch (e) {
        AppLogger.i('Error clearing partial file on restart: $e');
      }
    }

    if (event.download.id > 0) {
      _pendingRetryRecordIds.add(event.download.id);
      final repo = repository;
      if (repo != null) {
        final entity = event.download.toEntity();
        entity.downloadedBytes = 0;
        entity.statusIndex = DownloadStatus.pending.index;
        repo.saveDownload(entity);
      }
    }

    final controller =
        event.controller ??
        _sessionManager.getController(event.download.downloadId);
    if (controller != null && controller.value) {
      await controller.loadUrl(event.download.url);
    }
  }

  /// Clears finished downloads (`completed`, `cancelled`, `failed`) from state and ObjectBox.
  Future<void> _onClearCompleted(
    DownloadClearCompletedRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final toRemove = state.downloads
        .where(
          (d) =>
              d.status == DownloadStatus.completed ||
              d.status == DownloadStatus.cancelled ||
              d.status == DownloadStatus.failed,
        )
        .toList();

    AppLogger.i(
      '[DownloadBloc] Clearing finished downloads (count=${toRemove.length}, deleteFiles=${event.deleteFiles})',
    );

    final repo = repository;
    for (final item in toRemove) {
      if (event.deleteFiles && item.destinationPath.isNotEmpty) {
        try {
          await DownloadService.deleteFileFromDisk(item.destinationPath);
        } catch (e) {
          AppLogger.i('Error deleting file on clear completed: $e');
        }
      }
      if (repo != null && item.id > 0) {
        repo.deleteDownload(item.id);
      }
      _sessionManager.removeSession(item.downloadId);
      _lastDbSaveMap.remove(item.downloadId);
    }

    final updatedList = state.downloads
        .where(
          (d) =>
              d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.pending ||
              d.status == DownloadStatus.paused ||
              d.status == DownloadStatus.interrupted,
        )
        .toList();

    emit(state.copyWith(downloads: updatedList));
  }

  /// Translates CEF interrupt reasons into human-readable error text.
  String _getInterruptReasonText(int reason) {
    switch (reason) {
      case 10:
        return 'File failed';
      case 20:
        return 'Network error';
      case 30:
        return 'Server error';
      case 40:
        return 'User error';
      default:
        return 'Network error';
    }
  }

  /// Cleans up resources when Bloc is disposed.
  /// Marks incomplete downloads as `cancelled` and cleans up partial files on disk.
  @override
  Future<void> close() async {
    final repo = repository;
    if (repo != null) {
      for (final d in state.downloads) {
        if ((d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.pending ||
                d.status == DownloadStatus.paused) &&
            d.id > 0) {
          final entity = d.toEntity();
          entity.statusIndex = DownloadStatus.cancelled.index;
          entity.errorMessage = 'Cancelled';
          if (d.destinationPath.isNotEmpty) {
            await DownloadService.deleteFileFromDisk(d.destinationPath);
          }
          repo.saveDownload(entity);
        }
      }
    }

    _sessionManager.close();
    _lastDbSaveMap.clear();
    _pendingRetryRecordIds.clear();
    return super.close();
  }
}
