import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';

/// Dialog for display mode, root location, and extension preferences.
///
/// [extensionsListenable] and [includedExtensions] describe the extensions of
/// the current scan that remain included; the dialog rebuilds when they change
/// (for example after Reset re-includes every extension).
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.settings,
    required this.extensionsListenable,
    required this.includedExtensions,
    required this.onReset,
    required this.onScanNow,
  });

  final SettingsController settings;
  final Listenable extensionsListenable;
  final List<String> Function() includedExtensions;
  final Future<void> Function() onReset;
  final VoidCallback onScanNow;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _rootLocation = TextEditingController(
    text: widget.settings.rootLocation,
  );

  @override
  void dispose() {
    _rootLocation.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    await widget.onReset();
    _rootLocation.text = widget.settings.rootLocation;
  }

  Future<void> _save({required bool scan}) async {
    await widget.settings.setRootLocation(_rootLocation.text);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    if (scan) {
      widget.onScanNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Display mode'),
      content: SizedBox(
        width: 320,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            widget.settings,
            widget.extensionsListenable,
          ]),
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ThemeModeSelector(
                selected: widget.settings.themeMode,
                onChanged: (mode) =>
                    unawaited(widget.settings.setThemeMode(mode)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rootLocation,
                decoration: const InputDecoration(
                  labelText: 'Root location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _IncludedExtensionsDropdown(
                extensions: widget.includedExtensions(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _reset, child: const Text('Reset')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _save(scan: false),
          child: const Text('Save'),
        ),
        FilledButton.icon(
          onPressed: () => _save(scan: true),
          icon: const Icon(Icons.search),
          label: const Text('Scan now'),
        ),
      ],
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const <ButtonSegment<ThemeMode>>[
        ButtonSegment(value: ThemeMode.system, label: Text('System')),
        ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ButtonSegment(value: ThemeMode.light, label: Text('Light')),
      ],
      selected: <ThemeMode>{selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Read-only list of the extensions that future scans will include.
class _IncludedExtensionsDropdown extends StatelessWidget {
  const _IncludedExtensionsDropdown({required this.extensions});

  final List<String> extensions;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const ValueKey<String>('extension-dropdown'),
      decoration: const InputDecoration(
        labelText: 'Extensions for future scans',
        border: OutlineInputBorder(),
      ),
      hint: Text(
        extensions.isEmpty
            ? 'No extensions selected'
            : '${extensions.length} selected',
      ),
      items: [
        for (final extension in extensions)
          DropdownMenuItem<String>(value: extension, child: Text(extension)),
      ],
      onChanged: extensions.isEmpty ? null : (_) {},
    );
  }
}
