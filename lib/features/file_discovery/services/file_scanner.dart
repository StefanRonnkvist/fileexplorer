import 'dart:async';
import 'dart:io';

/// Recursively discovers files beneath a root directory.
///
/// Paths are normalized to use forward slashes and returned in sorted order.
/// Symbolic links are not followed, which prevents cycles in the directory
/// tree.
class FileScanner {
  const FileScanner._();

  /// The maximum duration used by [scan] when no timeout is supplied.
  static const defaultTimeout = Duration(minutes: 2);

  /// Scans [rootLocation] without blocking the UI isolate between directory
  /// listings.
  ///
  /// [onProgress] receives immutable snapshots after the first file, every
  /// 100 files, and once when the scan finishes. If [timeout] expires, the
  /// partial result is returned after [onTimeout] is called.
  static Future<List<String>> scan(
    String rootLocation, {
    Duration timeout = defaultTimeout,
    void Function(List<String> files)? onProgress,
    void Function()? onTimeout,
  }) async {
    final normalizedRoot = rootLocation.trim();
    if (normalizedRoot.isEmpty) {
      return const <String>[];
    }

    final rootDirectory = Directory(normalizedRoot);
    if (!await rootDirectory.exists()) {
      return const <String>[];
    }

    final results = <String>[];
    final pendingDirectories = <Directory>[rootDirectory];
    final stopwatch = Stopwatch()..start();

    // Use an explicit stack so each directory listing can honor the remaining
    // scan-wide timeout without building a deeply recursive call stack.
    while (pendingDirectories.isNotEmpty) {
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        onTimeout?.call();
        break;
      }

      final directory = pendingDirectories.removeLast();
      try {
        await for (final entity
            in directory.list(followLinks: false).timeout(remaining)) {
          if (entity is File) {
            results.add(entity.path.replaceAll('\\', '/'));
            if (results.length == 1 || results.length % 100 == 0) {
              onProgress?.call(List<String>.unmodifiable(results));
            }
          } else if (entity is Directory) {
            pendingDirectories.add(entity);
          }
        }
      } on FileSystemException {
        continue;
      } on TimeoutException {
        onTimeout?.call();
        break;
      }
    }

    results.sort();
    onProgress?.call(List<String>.unmodifiable(results));
    return results;
  }

  /// Synchronously scans [rootLocation], primarily for non-UI callers and
  /// tests that need a complete result without progress or timeout callbacks.
  static List<String> scanSync(String rootLocation) {
    final normalizedRoot = rootLocation.trim();
    if (normalizedRoot.isEmpty) {
      return const <String>[];
    }

    final rootDirectory = Directory(normalizedRoot);
    if (!rootDirectory.existsSync()) {
      return const <String>[];
    }

    final results = <String>[];

    void walk(Directory directory) {
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is File) {
          results.add(entity.path.replaceAll('\\', '/'));
        } else if (entity is Directory) {
          walk(entity);
        }
      }
    }

    walk(rootDirectory);
    results.sort();
    return results;
  }
}
