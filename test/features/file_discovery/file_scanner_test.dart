import 'dart:io';

import 'package:fileexplorer/features/file_discovery/services/file_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanSync recursively finds descendant files', () {
    final root = Directory.systemTemp.createTempSync('discover_root_');
    final nested = Directory('${root.path}/nested')
      ..createSync(recursive: true);

    final first = File('${root.path}/top.txt')..writeAsStringSync('first');
    final second = File('${nested.path}/child.txt')
      ..writeAsStringSync('second');

    final paths = FileScanner.scanSync(root.path);

    expect(paths, contains(first.path.replaceAll('\\', '/')));
    expect(paths, contains(second.path.replaceAll('\\', '/')));

    root.deleteSync(recursive: true);
  });

  test('scanSync returns empty for an invalid root location', () {
    expect(FileScanner.scanSync('C:/this/path/does/not/exist'), isEmpty);
  });

  test('scan completes with discovered files', () async {
    final root = Directory.systemTemp.createTempSync('background_scan_root_');
    final file = File('${root.path}/found.txt')..writeAsStringSync('found');

    final paths = await FileScanner.scan(
      root.path,
    ).timeout(const Duration(seconds: 5));

    expect(paths, contains(file.path.replaceAll('\\', '/')));

    root.deleteSync(recursive: true);
  });

  test('scan stops when its time limit expires', () async {
    final root = Directory.systemTemp.createTempSync('timed_scan_root_');
    var timedOut = false;

    final paths = await FileScanner.scan(
      root.path,
      timeout: Duration.zero,
      onTimeout: () => timedOut = true,
    );

    expect(timedOut, isTrue);
    expect(paths, isEmpty);

    root.deleteSync(recursive: true);
  });
}
