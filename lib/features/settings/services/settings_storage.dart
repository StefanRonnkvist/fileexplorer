import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Values restored from persistent storage at startup.
typedef StoredSettings = ({
  String? rootLocation,
  ThemeMode themeMode,
  Set<String> excludedExtensions,
});

/// Reads and writes user settings through [SharedPreferences].
///
/// Keys are kept stable so settings saved by earlier app versions still load.
class SettingsStorage {
  const SettingsStorage();

  static const String rootLocationKey = 'root_location';
  static const String themeModeKey = 'theme_mode';
  static const String excludedExtensionsKey = 'deselected_extensions';

  Future<StoredSettings> read() async {
    final preferences = await SharedPreferences.getInstance();
    final savedThemeMode = preferences.getString(themeModeKey);
    return (
      rootLocation: preferences.getString(rootLocationKey),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == savedThemeMode,
        orElse: () => ThemeMode.system,
      ),
      excludedExtensions:
          preferences.getStringList(excludedExtensionsKey)?.toSet() ??
          <String>{},
    );
  }

  Future<void> writeRootLocation(String rootLocation) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(rootLocationKey, rootLocation);
  }

  Future<void> writeThemeMode(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(themeModeKey, themeMode.name);
  }

  Future<void> writeExcludedExtensions(Set<String> extensions) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      excludedExtensionsKey,
      extensions.toList()..sort(),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.remove(rootLocationKey),
      preferences.remove(themeModeKey),
      preferences.remove(excludedExtensionsKey),
    ]);
  }
}
