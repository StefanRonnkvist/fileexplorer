import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact/contact_page.dart';
import 'features/file_comparison/models/comparison_entry.dart';
import 'features/file_comparison/widgets/full_screen_comparison.dart';
import 'features/file_discovery/services/file_scanner.dart';
import 'features/help/help_page.dart';
import 'splash_screen.dart';

export 'features/file_comparison/models/comparison_entry.dart';
export 'features/file_comparison/services/comparison_pdf_builder.dart';

void main() {
  runApp(const MainApp(showSplash: true));
}

/// Root application widget for file discovery, filtering, and comparison.
///
/// Optional discovery and content-reading callbacks allow tests or embedders
/// to replace direct file-system access.
class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    this.fileDiscoverer,
    this.fileContentReader,
    this.showSplash = false,
  });

  final Future<List<String>> Function(String rootLocation)? fileDiscoverer;
  final Future<String> Function(String path)? fileContentReader;
  final bool showSplash;

  /// Recursively scans [rootLocation], reporting partial results and timeout
  /// events through the optional callbacks.
  static Future<List<String>> scanSubordinateFiles(
    String rootLocation, {
    Duration timeout = FileScanner.defaultTimeout,
    void Function(List<String> files)? onProgress,
    void Function()? onTimeout,
  }) => FileScanner.scan(
    rootLocation,
    timeout: timeout,
    onProgress: onProgress,
    onTimeout: onTimeout,
  );

  /// Performs the same recursive discovery synchronously.
  static List<String> discoverSubordinateFiles(String rootLocation) {
    return FileScanner.scanSync(rootLocation);
  }

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static const String _rootLocationKey = 'root_location';
  static const String _themeModeKey = 'theme_mode';
  static const String _deselectedExtensionsKey = 'deselected_extensions';
  static const String _noExtension = '(no extension)';
  static const String _defaultRootLocation = 'G:\\My Drive';
  static const Set<String> _legacyDefaultRootLocations = <String>{
    'C:/Users/stefa/Documents',
    'C:\\Users\\stefa\\Documents',
  };

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ScrollController _horizontalScrollController = ScrollController();
  late final Future<void> _preferencesReady;
  Timer? _splashTimer;
  Future<void> _extensionPersistence = Future<void>.value();
  late bool _showSplash;
  ThemeMode _themeMode = ThemeMode.system;
  final TextEditingController _rootLocationController = TextEditingController(
    text: _defaultRootLocation,
  );
  List<String> _discoveredFiles = const <String>[];
  Set<String> _selectedExtensions = <String>{};
  Set<String> _deselectedExtensions = <String>{};
  double _extensionsWidth = 240;
  double _sortedFileNamesWidth = 600;
  double _comparisonWidth = 800;
  bool _extensionsCollapsed = false;
  bool _sortedFileNamesCollapsed = false;
  bool _comparisonCollapsed = false;
  bool _isScanning = false;
  bool _isLoadingComparison = false;
  String? _scanNotice;
  String? _comparisonFileName;
  List<ComparisonEntry> _comparisonEntries = const [];

  @override
  void initState() {
    super.initState();
    _showSplash = widget.showSplash;
    if (_showSplash) {
      _splashTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showSplash = false);
        }
      });
    }
    _preferencesReady = _loadPreferences();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _horizontalScrollController.dispose();
    _rootLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final savedRootLocation = preferences.getString(_rootLocationKey);
    // Replace only known historical defaults; user-selected paths must remain
    // untouched when the application's default changes.
    final shouldMigrateRootLocation =
        savedRootLocation != null &&
        _legacyDefaultRootLocations.contains(savedRootLocation);
    if (shouldMigrateRootLocation) {
      await preferences.setString(_rootLocationKey, _defaultRootLocation);
    }
    final savedThemeMode = preferences.getString(_themeModeKey);
    final savedDeselectedExtensions = preferences.getStringList(
      _deselectedExtensionsKey,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      if (shouldMigrateRootLocation) {
        _rootLocationController.text = _defaultRootLocation;
      } else if (savedRootLocation != null && savedRootLocation.isNotEmpty) {
        _rootLocationController.text = savedRootLocation;
      }
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedThemeMode,
        orElse: () => ThemeMode.system,
      );
      _deselectedExtensions = savedDeselectedExtensions?.toSet() ?? <String>{};
    });
  }

  Future<void> _saveRootLocation(String rootLocation) async {
    final normalizedRootLocation = rootLocation.trim();
    _rootLocationController.text = normalizedRootLocation;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_rootLocationKey, normalizedRootLocation);
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    setState(() => _themeMode = themeMode);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, themeMode.name);
  }

  Future<void> _resetPreferences() async {
    // Wait for queued extension writes so a late write cannot restore a value
    // immediately after the reset removes it.
    await _extensionPersistence;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.remove(_rootLocationKey),
      preferences.remove(_themeModeKey),
      preferences.remove(_deselectedExtensionsKey),
    ]);
    if (!mounted) {
      return;
    }

    setState(() {
      _rootLocationController.text = _defaultRootLocation;
      _themeMode = ThemeMode.system;
      _deselectedExtensions = <String>{};
      _selectedExtensions = _discoveredFiles.map(_extensionOf).toSet();
    });
  }

  void _setExtensionSelected(String extension, bool selected) {
    setState(() {
      if (selected) {
        _selectedExtensions.add(extension);
        _deselectedExtensions.remove(extension);
      } else {
        _selectedExtensions.remove(extension);
        _deselectedExtensions.add(extension);
      }
    });
    final extensions = _deselectedExtensions.toList()..sort();
    // Serialize writes because users can toggle several checkboxes before a
    // previous SharedPreferences operation has completed.
    _extensionPersistence = _extensionPersistence.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_deselectedExtensionsKey, extensions);
    });
  }

  String _extensionOf(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    final fileName = normalizedPath.substring(
      normalizedPath.lastIndexOf('/') + 1,
    );
    final dotIndex = fileName.lastIndexOf('.');
    // Leading dots represent dotfiles, while trailing dots have no suffix.
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return _noExtension;
    }
    return fileName.substring(dotIndex).toLowerCase();
  }

  String _fileNameOf(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    return normalizedPath.substring(normalizedPath.lastIndexOf('/') + 1);
  }

  void _updateDiscoveredFiles(List<String> files) {
    // Rebuild the active set from persisted exclusions so preferences also
    // apply to extensions first encountered during this scan.
    final currentExtensions = files.map(_extensionOf).toSet();

    _discoveredFiles = files;
    _selectedExtensions
      ..clear()
      ..addAll(
        currentExtensions.where(
          (extension) => !_deselectedExtensions.contains(extension),
        ),
      );
  }

  Future<void> _scanCurrentRoot() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _discoveredFiles = const <String>[];
      _selectedExtensions = <String>{};
      _scanNotice = null;
      _isLoadingComparison = false;
      _comparisonFileName = null;
      _comparisonEntries = const [];
    });

    try {
      await _preferencesReady;
      if (!mounted) {
        return;
      }

      var timedOut = false;
      final customDiscoverer = widget.fileDiscoverer;
      // Production scans stream snapshots into the UI. Injected discoverers
      // return a single result and keep widget tests independent of the disk.
      final files = customDiscoverer != null
          ? await customDiscoverer(_rootLocationController.text)
          : await MainApp.scanSubordinateFiles(
              _rootLocationController.text,
              onProgress: (files) {
                if (mounted) {
                  setState(() => _updateDiscoveredFiles(files));
                }
              },
              onTimeout: () => timedOut = true,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateDiscoveredFiles(files);
        if (timedOut) {
          _scanNotice = 'Scan stopped after 2 minutes. Showing files found.';
        }
      });
    } on FileSystemException catch (error) {
      if (mounted) {
        setState(() => _scanNotice = 'Scan failed: ${error.message}');
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _compareFiles(String fileName, List<String> paths) async {
    setState(() {
      _isLoadingComparison = true;
      _comparisonCollapsed = false;
      _comparisonFileName = fileName;
      _comparisonEntries = const [];
    });

    final reader =
        widget.fileContentReader ?? (path) => File(path).readAsString();
    final entries = await Future.wait(
      paths.map((path) async {
        try {
          return MapEntry(path, await reader(path));
        } on Object catch (error) {
          return MapEntry(path, 'Unable to read file as text.\n$error');
        }
      }),
    );
    if (!mounted || _comparisonFileName != fileName) {
      return;
    }

    // Identical content is shown once, with every matching source path listed
    // above it. This keeps copied files from producing redundant panes.
    final pathsByContent = <String, List<String>>{};
    for (final entry in entries) {
      pathsByContent.putIfAbsent(entry.value, () => <String>[]).add(entry.key);
    }
    setState(() {
      _comparisonEntries = [
        for (final entry in pathsByContent.entries)
          (paths: List<String>.unmodifiable(entry.value), content: entry.key),
      ];
      _isLoadingComparison = false;
    });
  }

  Future<void> _showFullScreenComparison() async {
    // Use the app navigator's context because this action can originate from a
    // horizontally scrolling pane nested below the tab controller.
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }

    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => FullScreenComparison(
        fileName: _comparisonFileName,
        entries: _comparisonEntries,
      ),
    );
  }

  Future<void> _showThemeSettings() async {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }

    var editedRootLocation = _rootLocationController.text;
    final futureScanExtensions = _selectedExtensions.toList()..sort();

    await showDialog<void>(
      context: dialogContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Display mode'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                    ),
                  ],
                  selected: <ThemeMode>{_themeMode},
                  onSelectionChanged: (Set<ThemeMode> selection) {
                    unawaited(_setThemeMode(selection.first));
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: editedRootLocation,
                  onChanged: (value) => editedRootLocation = value,
                  decoration: const InputDecoration(
                    labelText: 'Root location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>('extension-dropdown'),
                  decoration: const InputDecoration(
                    labelText: 'Extensions for future scans',
                    border: OutlineInputBorder(),
                  ),
                  hint: Text(
                    futureScanExtensions.isEmpty
                        ? 'No extensions selected'
                        : '${futureScanExtensions.length} selected',
                  ),
                  items: [
                    for (final extension in futureScanExtensions)
                      DropdownMenuItem<String>(
                        value: extension,
                        child: Text(extension),
                      ),
                  ],
                  onChanged: futureScanExtensions.isEmpty ? null : (_) {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _resetPreferences();
                editedRootLocation = _defaultRootLocation;
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                _showThemeSettings();
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _saveRootLocation(editedRootLocation);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await _saveRootLocation(editedRootLocation);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                _scanCurrentRoot();
              },
              icon: const Icon(Icons.search),
              label: const Text('Scan now'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    final files = _discoveredFiles;

    if (files.isEmpty) {
      return Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: _buildScanButton()),
          Expanded(
            child: Center(
              child: Text(
                _isScanning
                    ? 'Searching selected path...'
                    : _scanNotice ?? 'No files found in the root location.',
              ),
            ),
          ),
        ],
      );
    }

    final extensions = files.map(_extensionOf).toSet().toList()
      ..sort((first, second) {
        final firstSelected = _selectedExtensions.contains(first);
        final secondSelected = _selectedExtensions.contains(second);
        if (firstSelected != secondSelected) {
          return firstSelected ? -1 : 1;
        }
        return first.compareTo(second);
      });
    final visibleFiles = files
        .where((path) => _selectedExtensions.contains(_extensionOf(path)))
        .toList();
    // Lowercase keys make grouping case-insensitive while the first path
    // preserves the file name's original spelling for display.
    final pathsByFileName = <String, List<String>>{};
    for (final path in visibleFiles) {
      final fileName = _fileNameOf(path);
      pathsByFileName
          .putIfAbsent(fileName.toLowerCase(), () => <String>[])
          .add(path);
    }
    final sortedFileNameGroups = pathsByFileName.entries.toList()
      ..sort((first, second) => first.key.compareTo(second.key));
    for (final group in sortedFileNameGroups) {
      group.value.sort();
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: _buildScanButton()),
        if (_scanNotice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(_scanNotice!),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final extensionsWidth = _extensionsCollapsed
                  ? 48.0
                  : _extensionsWidth;
              final sortedFileNamesWidth = _sortedFileNamesCollapsed
                  ? 48.0
                  : _sortedFileNamesWidth;
              final comparisonWidth = _comparisonCollapsed
                  ? 48.0
                  : _comparisonWidth;
              final contentWidth =
                  extensionsWidth + sortedFileNamesWidth + comparisonWidth + 24;
              // Keep all panes at their preferred widths and expose horizontal
              // scrolling whenever the viewport cannot contain the workspace.
              final displayWidth = contentWidth < constraints.maxWidth
                  ? constraints.maxWidth
                  : contentWidth;

              return Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  key: const ValueKey<String>('discover-horizontal-scroll'),
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: displayWidth,
                    height: constraints.maxHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: extensionsWidth,
                          child: _extensionsCollapsed
                              ? _buildCollapsedPane(
                                  'Extensions',
                                  () => setState(
                                    () => _extensionsCollapsed = false,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildSectionHeader(
                                      'Extensions',
                                      onCollapse: () => setState(
                                        () => _extensionsCollapsed = true,
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: extensions.length,
                                        itemBuilder: (context, index) {
                                          final extension = extensions[index];
                                          return CheckboxListTile(
                                            dense: true,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                            title: Text(
                                              extension,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            value: _selectedExtensions.contains(
                                              extension,
                                            ),
                                            onChanged: (selected) {
                                              _setExtensionSelected(
                                                extension,
                                                selected ?? false,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        _buildColumnResizer(
                          'extensions-resizer',
                          (delta) => setState(() {
                            _extensionsCollapsed = false;
                            _extensionsWidth = (_extensionsWidth + delta).clamp(
                              200.0,
                              600.0,
                            );
                          }),
                        ),
                        SizedBox(
                          key: const ValueKey<String>('sorted-file-names-pane'),
                          width: sortedFileNamesWidth,
                          child: _sortedFileNamesCollapsed
                              ? _buildCollapsedPane(
                                  'Sorted by File Name',
                                  () => setState(
                                    () => _sortedFileNamesCollapsed = false,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildSectionHeader(
                                      'Sorted by File Name',
                                      onCollapse: () => setState(
                                        () => _sortedFileNamesCollapsed = true,
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: sortedFileNameGroups.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No file extensions selected.',
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount:
                                                  sortedFileNameGroups.length,
                                              separatorBuilder: (_, _) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final paths =
                                                    sortedFileNameGroups[index]
                                                        .value;
                                                final fileName = _fileNameOf(
                                                  paths.first,
                                                );
                                                return ExpansionTile(
                                                  dense: true,
                                                  tilePadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  childrenPadding:
                                                      const EdgeInsets.only(
                                                        left: 16,
                                                      ),
                                                  leading: const Icon(
                                                    Icons.insert_drive_file,
                                                  ),
                                                  title: Text(
                                                    fileName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  children: [
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 16,
                                                              bottom: 8,
                                                            ),
                                                        child:
                                                            FilledButton.icon(
                                                              onPressed: () =>
                                                                  _compareFiles(
                                                                    fileName,
                                                                    paths,
                                                                  ),
                                                              icon: const Icon(
                                                                Icons.compare,
                                                              ),
                                                              label: const Text(
                                                                'Compare',
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                    for (final path in paths)
                                                      ListTile(
                                                        dense: true,
                                                        leading: const Icon(
                                                          Icons
                                                              .subdirectory_arrow_right,
                                                        ),
                                                        title: Text(
                                                          path,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                        ),
                        _buildColumnResizer(
                          'sorted-file-names-resizer',
                          (delta) => setState(() {
                            _sortedFileNamesCollapsed = false;
                            _sortedFileNamesWidth =
                                (_sortedFileNamesWidth + delta).clamp(
                                  400.0,
                                  900.0,
                                );
                          }),
                        ),
                        SizedBox(
                          key: const ValueKey<String>('comparison-pane'),
                          width: comparisonWidth,
                          child: _comparisonCollapsed
                              ? _buildCollapsedPane(
                                  'Compare',
                                  () => setState(
                                    () => _comparisonCollapsed = false,
                                  ),
                                )
                              : _buildComparisonPane(),
                        ),
                        _buildColumnResizer(
                          'comparison-resizer',
                          (delta) => setState(() {
                            _comparisonCollapsed = false;
                            _comparisonWidth = (_comparisonWidth + delta).clamp(
                              500.0,
                              1400.0,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String label, {
    Widget? leadingAction,
    required VoidCallback onCollapse,
  }) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          ?leadingAction,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Collapse $label',
            onPressed: onCollapse,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedPane(String label, VoidCallback onExpand) {
    return Align(
      alignment: Alignment.topCenter,
      child: IconButton(
        tooltip: 'Expand $label',
        onPressed: onExpand,
        icon: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildColumnResizer(String key, ValueChanged<double> onDrag) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        key: ValueKey<String>(key),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: 8,
          child: Center(
            child: VerticalDivider(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          _comparisonFileName == null
              ? 'Compare'
              : 'Compare: $_comparisonFileName',
          leadingAction: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilledButton.tonalIcon(
              key: const ValueKey<String>('full-screen-compare-button'),
              onPressed: _comparisonEntries.isEmpty
                  ? null
                  : _showFullScreenComparison,
              icon: const Icon(Icons.fullscreen),
              label: const Text('Full Screen'),
            ),
          ),
          onCollapse: () => setState(() => _comparisonCollapsed = true),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingComparison
              ? const Center(child: CircularProgressIndicator())
              : _comparisonEntries.isEmpty
              ? const Center(
                  child: Text('Expand a file group and select Compare.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _comparisonEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _comparisonEntries[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 96,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SelectableText(
                                    entry.paths.join('\n'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: SingleChildScrollView(
                                  key: ValueKey<String>(
                                    'comparison-horizontal-scroll-$index',
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  child: SelectableText(
                                    entry.content,
                                    key: ValueKey<String>(
                                      'comparison-content-$index',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return ElevatedButton.icon(
      onPressed: _isScanning ? null : _scanCurrentRoot,
      icon: _isScanning
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search),
      label: Text(_isScanning ? 'Scanning' : 'Scan'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      home: _showSplash
          ? const SplashScreen()
          : Scaffold(
              appBar: AppBar(
                title: const Text('File Explorer'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: _showThemeSettings,
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
                          _buildDiscoverTab(),
                          ContactPage(
                            serverUri: Uri.parse(
                              'https://stefanronnkvist.com/contact.php',
                            ),
                            showAppBar: false,
                            wrapInScaffold: false,
                          ),
                          const HelpPage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
