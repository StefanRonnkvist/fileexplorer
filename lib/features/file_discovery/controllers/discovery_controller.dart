import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/path_utils.dart';
import '../../settings/controllers/settings_controller.dart';
import '../models/file_name_group.dart';
import '../services/file_grouping.dart';
import '../services/file_scanner.dart';

/// Returns every file path beneath a root location.
typedef FileDiscoverer = Future<List<String>> Function(String rootLocation);

/// Scans the configured root location and tracks which extensions are shown.
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({required this.settings, this.discoverer});

  final SettingsController settings;

  /// Replaces [FileScanner] when set (tests, embedders). Custom discoverers
  /// return one complete result instead of streaming progress.
  final FileDiscoverer? discoverer;

  List<String> _files = const <String>[];
  Set<String> _includedExtensions = <String>{};
  bool _isScanning = false;
  String? _notice;
  bool _disposed = false;

  List<String> get files => _files;
  bool get isScanning => _isScanning;

  /// Timeout or failure message for the most recent scan.
  String? get notice => _notice;

  bool isIncluded(String extension) => _includedExtensions.contains(extension);

  /// Included extensions of the current scan, sorted alphabetically.
  List<String> get includedExtensions => _includedExtensions.toList()..sort();

  /// Every extension found, with included ones listed first.
  List<String> get extensions =>
      sortExtensions(_files.map(extensionOf).toSet(), _includedExtensions);

  /// Visible files grouped by name.
  List<FileNameGroup> get fileNameGroups => groupByFileName(
    _files.where((path) => _includedExtensions.contains(extensionOf(path))),
  );

  Future<void> scan() async {
    if (_isScanning) {
      return;
    }
    _isScanning = true;
    _files = const <String>[];
    _includedExtensions = <String>{};
    _notice = null;
    _notify();

    try {
      // Saved exclusions must be known before the first results are shown.
      await settings.ready;
      if (_disposed) {
        return;
      }

      var timedOut = false;
      final custom = discoverer;
      final files = custom != null
          ? await custom(settings.rootLocation)
          : await FileScanner.scan(
              settings.rootLocation,
              onProgress: _showFiles,
              onTimeout: () => timedOut = true,
            );
      _applyFiles(files);
      if (timedOut) {
        _notice = 'Scan stopped after 2 minutes. Showing files found.';
      }
    } on FileSystemException catch (error) {
      _notice = 'Scan failed: ${error.message}';
    } finally {
      _isScanning = false;
      _notify();
    }
  }

  void _showFiles(List<String> files) {
    _applyFiles(files);
    _notify();
  }

  void _applyFiles(List<String> files) {
    _files = files;
    // Rebuilding from saved exclusions also applies them to extensions seen
    // for the first time in this scan.
    _includedExtensions = files
        .map(extensionOf)
        .where((extension) => !settings.excludedExtensions.contains(extension))
        .toSet();
  }

  void setExtensionIncluded(String extension, {required bool included}) {
    if (included) {
      _includedExtensions.add(extension);
    } else {
      _includedExtensions.remove(extension);
    }
    settings.setExtensionExcluded(extension, excluded: !included);
    _notify();
  }

  /// Includes every extension of the current scan again (used by Reset).
  void includeAllExtensions() {
    _includedExtensions = _files.map(extensionOf).toSet();
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
