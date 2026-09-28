import 'package:flutter/material.dart';

import '../controllers/discovery_controller.dart';

/// Lists the extensions found in the current scan as checkboxes.
class ExtensionList extends StatelessWidget {
  const ExtensionList({
    super.key,
    required this.discovery,
    required this.extensions,
  });

  final DiscoveryController discovery;
  final List<String> extensions;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: extensions.length,
      itemBuilder: (context, index) {
        final extension = extensions[index];
        return CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(extension, maxLines: 1, overflow: TextOverflow.ellipsis),
          value: discovery.isIncluded(extension),
          onChanged: (selected) => discovery.setExtensionIncluded(
            extension,
            included: selected ?? false,
          ),
        );
      },
    );
  }
}
