import '../../../core/utils/path_utils.dart';
import '../models/file_name_group.dart';

/// Groups [paths] by file name case-insensitively.
///
/// Groups are ordered by lowercase name and the paths inside each group are
/// sorted, so the result is stable regardless of discovery order.
List<FileNameGroup> groupByFileName(Iterable<String> paths) {
  final pathsByName = <String, List<String>>{};
  for (final path in paths) {
    pathsByName
        .putIfAbsent(fileNameOf(path).toLowerCase(), () => <String>[])
        .add(path);
  }
  final keys = pathsByName.keys.toList()..sort();
  final groups = <FileNameGroup>[];
  for (final key in keys) {
    final groupPaths = pathsByName[key]!..sort();
    groups.add((
      fileName: fileNameOf(groupPaths.first),
      paths: List<String>.unmodifiable(groupPaths),
    ));
  }
  return groups;
}

/// Orders [extensions] with included ones first, then alphabetically.
List<String> sortExtensions(Iterable<String> extensions, Set<String> included) {
  return extensions.toList()..sort((first, second) {
    final firstIncluded = included.contains(first);
    final secondIncluded = included.contains(second);
    if (firstIncluded != secondIncluded) {
      return firstIncluded ? -1 : 1;
    }
    return first.compareTo(second);
  });
}
