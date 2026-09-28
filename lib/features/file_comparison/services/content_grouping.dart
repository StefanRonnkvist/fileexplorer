import '../models/comparison_entry.dart';

/// Merges files whose content is identical into one entry that lists every
/// source path, preserving first-seen order.
List<ComparisonEntry> groupByContent(Iterable<MapEntry<String, String>> files) {
  final pathsByContent = <String, List<String>>{};
  for (final file in files) {
    pathsByContent.putIfAbsent(file.value, () => <String>[]).add(file.key);
  }
  return [
    for (final entry in pathsByContent.entries)
      (paths: List<String>.unmodifiable(entry.value), content: entry.key),
  ];
}
