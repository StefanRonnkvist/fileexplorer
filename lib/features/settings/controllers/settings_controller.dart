import 'package:flutter/material.dart';

import '../services/settings_storage.dart';

/// Owns the user's persisted settings and notifies listeners when they change.
class SettingsController extends ChangeNotifier {
  SettingsController({this.storage = const SettingsStorage()}) {
    ready = _load();
  }

  static const String defaultRootLocation = 'G:\\My Drive';

  /// Defaults shipped by earlier versions. A saved value that still matches one
  /// of these is upgraded to [defaultRootLocation]; user-chosen paths are kept.
  static const Set<String> legacyDefaultRootLocations = <String>{
    'C:/Users/stefa/Documents',
    'C:\\Users\\stefa\\Documents',
  };

  /// Persistent storage backend, replaceable in tests.
  final SettingsStorage storage;

  /// Completes once saved settings have been applied.
  late final Future<void> ready;

  String _rootLocation = defaultRootLocation;
  ThemeMode _themeMode = ThemeMode.system;
  Set<String> _excludedExtensions = <String>{};
  Future<void> _pendingExtensionWrite = Future<void>.value();
  bool _disposed = false;

  String get rootLocation => _rootLocation;
  ThemeMode get themeMode => _themeMode;

  /// Extensions the user has unchecked; they stay hidden in future scans.
  Set<String> get excludedExtensions => Set.unmodifiable(_excludedExtensions);

  Future<void> _load() async {
    final stored = await storage.read();
    final savedRoot = stored.rootLocation;
    if (savedRoot != null && legacyDefaultRootLocations.contains(savedRoot)) {
      await storage.writeRootLocation(defaultRootLocation);
      _rootLocation = defaultRootLocation;
    } else if (savedRoot != null && savedRoot.isNotEmpty) {
      _rootLocation = savedRoot;
    }
    _themeMode = stored.themeMode;
    _excludedExtensions = stored.excludedExtensions;
    _notify();
  }

  Future<void> setRootLocation(String rootLocation) async {
    _rootLocation = rootLocation.trim();
    _notify();
    await storage.writeRootLocation(_rootLocation);
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    _notify();
    await storage.writeThemeMode(themeMode);
  }

  void setExtensionExcluded(String extension, {required bool excluded}) {
    if (excluded) {
      _excludedExtensions.add(extension);
    } else {
      _excludedExtensions.remove(extension);
    }
    final snapshot = Set<String>.of(_excludedExtensions);
    // Writes are chained because the user can toggle several checkboxes before
    // an earlier write finishes; the last toggle must win.
    _pendingExtensionWrite = _pendingExtensionWrite.then(
      (_) => storage.writeExcludedExtensions(snapshot),
    );
  }

  /// Clears persisted settings and restores every default.
  Future<void> reset() async {
    // Let queued writes finish so none of them restores a value after reset.
    await _pendingExtensionWrite;
    await storage.clear();
    _rootLocation = defaultRootLocation;
    _themeMode = ThemeMode.system;
    _excludedExtensions = <String>{};
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
