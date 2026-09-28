import 'package:flutter/material.dart';

import '../models/file_name_group.dart';

/// Lists discovered files grouped by name, one group per expandable tile.
class FileGroupList extends StatelessWidget {
  const FileGroupList({
    super.key,
    required this.groups,
    required this.onCompare,
  });

  final List<FileNameGroup> groups;
  final void Function(String fileName, List<String> paths) onCompare;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(child: Text('No file extensions selected.'));
    }
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final group = groups[index];
        return ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(left: 16),
          leading: const Icon(Icons.insert_drive_file),
          title: Text(
            group.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: FilledButton.icon(
                  onPressed: () => onCompare(group.fileName, group.paths),
                  icon: const Icon(Icons.compare),
                  label: const Text('Compare'),
                ),
              ),
            ),
            for (final path in group.paths)
              ListTile(
                dense: true,
                leading: const Icon(Icons.subdirectory_arrow_right),
                title: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        );
      },
    );
  }
}
