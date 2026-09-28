import 'dart:async';

import 'package:flutter/material.dart';

import '../features/contact/contact_page.dart';
import '../features/file_comparison/controllers/comparison_controller.dart';
import '../features/file_discovery/controllers/discovery_controller.dart';
import '../features/file_discovery/widgets/discover_tab.dart';
import '../features/help/help_page.dart';
import '../features/settings/controllers/settings_controller.dart';
import '../features/settings/widgets/settings_dialog.dart';
import 'app_config.dart';

/// Tabbed shell holding the Discover, Information, and Help tabs.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.settings,
    required this.discovery,
    required this.comparison,
  });

  final SettingsController settings;
  final DiscoveryController discovery;
  final ComparisonController comparison;

  Future<void> _openSettings(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => SettingsDialog(
        settings: settings,
        extensionsListenable: discovery,
        includedExtensions: () => discovery.includedExtensions,
        onReset: _resetSettings,
        onScanNow: scan,
      ),
    );
  }

  /// Restores every default and shows all extensions of the current scan again.
  Future<void> _resetSettings() async {
    await settings.reset();
    discovery.includeAllExtensions();
  }

  /// Runs a scan, discarding any previous comparison first.
  Future<void> scan() async {
    if (discovery.isScanning) {
      return;
    }
    comparison.clear();
    await discovery.scan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Discover'),
                Tab(text: 'Information'),
                Tab(text: 'Help'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  DiscoverTab(discovery: discovery, comparison: comparison),
                  ContactPage(serverUri: AppConfig.contactEndpoint),
                  const HelpPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
