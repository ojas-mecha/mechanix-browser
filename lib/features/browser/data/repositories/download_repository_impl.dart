import 'package:mechanix_browser/core/services/objectbox_service.dart';
import 'package:mechanix_browser/core/utils/app_logger.dart';
import 'package:mechanix_browser/features/browser/data/models/download_entity.dart';
import 'package:mechanix_browser/features/browser/data/repositories/download_repository.dart';
import 'package:mechanix_browser/objectbox.g.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  @override
  final Store store;

  @override
  late final Box<DownloadEntity> downloadBox;

  DownloadRepositoryImpl({Store? store})
    : store = store ?? ObjectBoxService.store {
    downloadBox = this.store.box<DownloadEntity>();
  }

  /// Fetches all stored download records ordered by creation timestamp descending (newest first).
  @override
  List<DownloadEntity> getAllDownloads() {
    try {
      final query =
          (downloadBox.query()
                ..order(DownloadEntity_.createdAt, flags: Order.descending))
              .build();
      try {
        final results = query.find();
        AppLogger.i(
          '[DownloadRepository] Loaded ${results.length} total history records from ObjectBox DB',
        );
        return results;
      } finally {
        query.close();
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to load download history from ObjectBox: $e',
        error: e,
        stack: stackTrace,
      );
      return [];
    }
  }

  /// Fetches a single download record by its ObjectBox primary key [id].
  @override
  DownloadEntity? getDownloadById(int id) {
    try {
      return downloadBox.get(id);
    } catch (e) {
      AppLogger.e('Error fetching download entity by id $id: $e');
      return null;
    }
  }

  /// Queries a download record by its ephemeral CEF download identifier [cefDownloadId].
  @override
  DownloadEntity? getDownloadByCefId(int cefDownloadId) {
    try {
      final query = downloadBox
          .query(DownloadEntity_.cefDownloadId.equals(cefDownloadId))
          .build();
      try {
        final results = query.find();
        return results.isNotEmpty ? results.first : null;
      } finally {
        query.close();
      }
    } catch (e) {
      AppLogger.e(
        'Error fetching download entity by cef id $cefDownloadId: $e',
      );
      return null;
    }
  }

  /// Saves or updates a download entity in ObjectBox storage.
  ///
  /// Returns the assigned ObjectBox primary key `id` (useful when saving a new entity with `id == 0`).
  @override
  int saveDownload(DownloadEntity entity) {
    try {
      final isNew = entity.id == 0;
      final savedId = downloadBox.put(entity);
      if (isNew) {
        AppLogger.i(
          '[DownloadRepository] Inserted new record id=$savedId (cefId=${entity.cefDownloadId}, file=${entity.fileName}, statusIndex=${entity.statusIndex})',
        );
      } else {
        AppLogger.i(
          '[DownloadRepository] Updated id=$savedId (file=${entity.fileName}, bytes=${entity.downloadedBytes}/${entity.totalBytes}, statusIndex=${entity.statusIndex})',
        );
      }
      return savedId;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to save download entity (id=${entity.id}): $e',
        error: e,
        stack: stackTrace,
      );
      return 0;
    }
  }

  /// Batch saves multiple download entities into ObjectBox in a single transaction.
  @override
  List<int> saveAllDownloads(List<DownloadEntity> entities) {
    try {
      final savedIds = downloadBox.putMany(entities);
      AppLogger.i(
        '[DownloadRepository] Batch saved ${savedIds.length} download entities',
      );
      return savedIds;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to save all download entities: $e',
        error: e,
        stack: stackTrace,
      );
      return [];
    }
  }

  /// Deletes a download entity from ObjectBox storage by its primary key [id].
  @override
  bool deleteDownload(int id) {
    try {
      final removed = downloadBox.remove(id);
      if (removed) {
        AppLogger.i('[DownloadRepository] Deleted download record id=$id');
      }
      return removed;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to delete download entity $id: $e',
        error: e,
        stack: stackTrace,
      );
      return false;
    }
  }

  /// Removes all download entities from persistent storage.
  @override
  void clearHistory() {
    try {
      downloadBox.removeAll();
      AppLogger.i(
        '[DownloadRepository] Cleared all download history from database',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to clear download history: $e',
        error: e,
        stack: stackTrace,
      );
    }
  }

  @override
  void close() {
    // Store lifecycle is managed globally by ObjectBoxService
  }
}
