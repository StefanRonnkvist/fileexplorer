import 'dart:async';

import 'package:flutter/material.dart';

import '../features/file_comparison/controllers/comparison_controller.dart';
import '../features/file_discovery/controllers/discovery_controller.dart';
import '../features/settings/controllers/settings_controller.dart';
import 'app_config.dart';
import 'home_page.dart';
import 'splash_screen.dart';

/// Root widget of the application.
///
/// [discoverer] and [contentReader] replace file-system access so tests and
/// embedders can run without touching the disk.
class FileExplorerApp extends StatefulWidget {
  const FileExplorerApp({
    super.key,
    this.discoverer,
    this.contentReader,
    this.showSplash = false,
  });

  final Future<List<String>> Function(String rootLocation)? discoverer;
  final Future<String> Function(String path)? contentReader;
  final bool showSplash;

  @override
  State<FileExplorerApp> createState() => _FileExplorerAppState();
}

class _FileExplorerAppState extends State<FileExplorerApp> {
  late final SettingsController _settings = SettingsController();
  late final DiscoveryController _discovery = DiscoveryController(
    settings: _settings,
    discoverer: widget.discoverer,
  );
  late final ComparisonController _comparison = ComparisonController(
    reader: widget.contentReader,
  );
  Timer? _splashTimer;
  late bool _showSplash = widget.showSplash;

  @override
  void initState() {
    super.initState();
    if (_showSplash) {
      _splashTimer = Timer(AppConfig.splashDuration, () {
        if (mounted) {
          setState(() => _showSplash = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _comparison.dispose();
    _discovery.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: _settings.themeMode,
        home: _showSplash
            ? const SplashScreen()
            : HomePage(
                settings: _settings,
                discovery: _discovery,
                comparison: _comparison,
              ),
      ),
    );
  }
}
