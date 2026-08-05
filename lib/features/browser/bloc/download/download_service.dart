import 'dart:io';

import 'package:mechanix_browser/core/utils/app_logger.dart';

class DownloadService {
  /// Returns the absolute path to the user's Downloads directory.
  /// Falls back to `./Downloads` in the working directory if `$HOME` is unavailable.
  static Future<String> getDownloadsDirectoryPath() async {
    final home = Platform.environment['HOME'];
    final downloadsPath = home != null && home.isNotEmpty
        ? '$home/Downloads'
        : '${Directory.current.path}/Downloads';

    final dir = Directory(downloadsPath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
        AppLogger.i(
          '[DownloadService] Created missing downloads directory: $downloadsPath',
        );
      } catch (e) {
        AppLogger.i('Failed to create downloads directory: $e');
      }
    }

    return downloadsPath;
  }

  /// Sanitizes a suggested file name to prevent path traversal exploits and illegal path characters.
  ///
  /// Removes characters like `/ \ : * ? " < > |` and `..` traversal sequences.
  /// Falls back to `downloaded_file` if the sanitized result is empty or invalid.
  static String sanitizeFilename(String suggestedName, String url) {
    String name = suggestedName.trim();
    if (name.isEmpty) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          name = Uri.decodeComponent(segments.last);
        }
      } catch (_) {}
    }

    if (name.isEmpty) {
      name = 'downloaded_file';
    }

    // Remove path traversal sequences and illegal filesystem characters
    name = name.replaceAll(RegExp(r'[\/\x00-\x1F\x7F<>:"\\|?*]'), '_');
    while (name.contains('..')) {
      name = name.replaceAll('..', '_');
    }
    name = name.trim();
    if (name.isEmpty || name == '.' || name == '..') {
      name = 'downloaded_file';
    }

    return name;
  }

  /// Generates a non-conflicting destination file path in [dirPath].
  ///
  /// Checks if the target path or its partial `.crdownload` counterpart already exists on disk
  /// or in [activePaths]. Appends `(1)`, `(2)`, etc. before the extension until an available path is found.
  static String getUniqueDestinationPath(
    String dirPath,
    String filename, {
    Set<String>? activePaths,
  }) {
    final separator = Platform.pathSeparator;
    final fullPath = '$dirPath$separator$filename';

    bool isPathInUse(String p) {
      if (activePaths != null && activePaths.contains(p)) return true;
      if (File(p).existsSync()) return true;
      if (File('$p.crdownload').existsSync()) return true;
      return false;
    }

    if (!isPathInUse(fullPath)) {
      return fullPath;
    }

    final dotIdx = filename.lastIndexOf('.');
    String nameStem = filename;
    String extension = '';
    if (dotIdx != -1 && dotIdx > 0) {
      nameStem = filename.substring(0, dotIdx);
      extension = filename.substring(dotIdx);
    }

    int counter = 1;
    while (true) {
      final newFilename = '$nameStem ($counter)$extension';
      final newPath = '$dirPath$separator$newFilename';
      if (!isPathInUse(newPath)) {
        AppLogger.i(
          '[DownloadService] Collision detected for $filename. Resolved unique path: $newPath',
        );
        return newPath;
      }
      counter++;
    }
  }

  /// Returns all potential disk paths for a target download path (including `.crdownload` variations).
  ///
  /// Used for scanning and deleting partial downloads created by Chromium.
  static List<String> getPossibleFilePaths(String filePath) {
    if (filePath.isEmpty) return [];
    final set = <String>{filePath};

    if (filePath.endsWith('.crdownload')) {
      final base = filePath.substring(
        0,
        filePath.length - '.crdownload'.length,
      );
      if (base.isNotEmpty) {
        set.add(base);
      }
    } else {
      set.add('$filePath.crdownload');
    }

    return set.toList();
  }

  /// Checks disk for existing bytes associated with [filePath] (checking target path and `.crdownload`).
  static int getActualDownloadedBytes(String filePath) {
    if (filePath.isEmpty) return 0;
    try {
      final possiblePaths = getPossibleFilePaths(filePath);
      for (final p in possiblePaths) {
        final f = File(p);
        if (f.existsSync()) {
          final len = f.lengthSync();
          if (len > 0) return len;
        }
      }
    } catch (e) {
      AppLogger.i('Error reading file length for $filePath: $e');
    }
    return 0;
  }

  /// Deletes the downloaded file and any associated partial files (`.crdownload`) from disk.
  static Future<bool> deleteFileFromDisk(String filePath) async {
    if (filePath.isEmpty) return false;
    bool deleted = false;
    try {
      final possiblePaths = getPossibleFilePaths(filePath);
      for (final p in possiblePaths) {
        final f = File(p);
        if (await f.exists()) {
          final len = await f.length();
          final ext = p.contains('.') ? p.split('.').last : 'no_ext';
          AppLogger.i(
            '[DownloadService] Deleted file (ext: .$ext, path: $p, size: $len bytes)',
          );
          await f.delete();
          deleted = true;
        }
      }
    } catch (e) {
      AppLogger.i('Error deleting file from disk $filePath: $e');
    }
    return deleted;
  }

  /// Opens a downloaded file using the default desktop OS viewer (`xdg-open`, `open`, `explorer`).
  static Future<void> openDownloadedFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;

    try {
      AppLogger.i('[DownloadService] Opening downloaded file: $filePath');
      if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      }
    } catch (e) {
      AppLogger.i('Failed to open file: $e');
    }
  }

  /// Opens the folder containing [filePath] in the native OS file manager (`xdg-open`, `open`, `explorer`).
  static Future<void> openDownloadFolder(String filePath) async {
    final file = File(filePath);
    final folderPath = file.existsSync()
        ? file.parent.path
        : Directory(filePath).path;

    try {
      AppLogger.i('[DownloadService] Opening download folder: $folderPath');
      if (Platform.isLinux) {
        await Process.run('xdg-open', [folderPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [folderPath]);
      }
    } catch (e) {
      AppLogger.i('Failed to open folder: $e');
    }
  }
}
