import 'package:fileexplorer/core/utils/path_utils.dart';
import 'package:fileexplorer/features/file_discovery/services/file_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extensionOf', () {
    test('returns the lowercase extension including its dot', () {
      expect(extensionOf('C:/Root/file.TXT'), '.txt');
    });

    test('labels files without an extension', () {
      expect(extensionOf('C:/Root/README'), noExtension);
      expect(extensionOf('C:/Root/name.'), noExtension);
      expect(extensionOf('C:/Root/.gitignore'), noExtension);
    });
  });

  test('groupByFileName groups case-insensitively and sorts paths', () {
    final groups = groupByFileName([
      'C:/Root/z/Alpha.txt',
      'C:/Root/a/alpha.TXT',
      'C:/Root/middle.txt',
    ]);

    expect(groups, hasLength(2));
    // The displayed name comes from the first path after sorting, so the
    // group keeps one consistent spelling.
    expect(groups.first.fileName, 'alpha.TXT');
    expect(groups.first.paths, ['C:/Root/a/alpha.TXT', 'C:/Root/z/Alpha.txt']);
    expect(groups.last.fileName, 'middle.txt');
  });

  test('sortExtensions lists included extensions first', () {
    final sorted = sortExtensions(['.txt', '.json', '.ps1'], {'.json', '.txt'});

    expect(sorted, ['.json', '.txt', '.ps1']);
  });
}
