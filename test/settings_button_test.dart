import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fileexplorer/main.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boot splash transitions to the main interface', (tester) async {
    await tester.pumpWidget(const MainApp(showSplash: true));

    expect(find.text('Loading...'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Loading...'), findsNothing);
    expect(find.text('Discover'), findsOneWidget);
  });

  test('comparison PDF creates one page per column', () async {
    final bytes = await buildComparisonPdf(
      PdfPageFormat.a4,
      'shared.txt',
      const <ComparisonEntry>[
        (paths: <String>['C:/Root/first/shared.txt'], content: 'first'),
        (paths: <String>['C:/Root/second/shared.txt'], content: 'second'),
      ],
    );
    final pdfSource = latin1.decode(bytes);

    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdfSource), hasLength(2));
  });

  test(
    'comparison PDF paginates long content without scaling it down',
    () async {
      final longContent = List<String>.generate(
        200,
        (index) => 'Line ${index + 1}: readable comparison content',
      ).join('\n');
      final bytes = await buildComparisonPdf(
        PdfPageFormat.a4,
        'long.txt',
        <ComparisonEntry>[
          (paths: const <String>['C:/Root/long.txt'], content: longContent),
        ],
      );
      final pdfSource = latin1.decode(bytes);

      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(pdfSource).length,
        greaterThan(1),
      );
    },
  );

  test('discoverSubordinateFiles recursively finds descendant files', () {
    final root = Directory.systemTemp.createTempSync('discover_root_');
    final nested = Directory('${root.path}/nested');
    nested.createSync(recursive: true);

    final first = File('${root.path}/top.txt');
    final second = File('${nested.path}/child.txt');
    first.writeAsStringSync('first');
    second.writeAsStringSync('second');

    final paths = MainApp.discoverSubordinateFiles(root.path);

    expect(paths, contains(first.path.replaceAll('\\', '/')));
    expect(paths, contains(second.path.replaceAll('\\', '/')));

    root.deleteSync(recursive: true);
  });

  test('scanSubordinateFiles completes with discovered files', () async {
    final root = Directory.systemTemp.createTempSync('background_scan_root_');
    final file = File('${root.path}/found.txt')..writeAsStringSync('found');

    final paths = await MainApp.scanSubordinateFiles(
      root.path,
    ).timeout(const Duration(seconds: 5));

    expect(paths, contains(file.path.replaceAll('\\', '/')));

    root.deleteSync(recursive: true);
  });

  test('scanSubordinateFiles stops when its time limit expires', () async {
    final root = Directory.systemTemp.createTempSync('timed_scan_root_');
    var timedOut = false;

    final paths = await MainApp.scanSubordinateFiles(
      root.path,
      timeout: Duration.zero,
      onTimeout: () => timedOut = true,
    );

    expect(timedOut, isTrue);
    expect(paths, isEmpty);

    root.deleteSync(recursive: true);
  });

  test(
    'discoverSubordinateFiles returns empty for an invalid root location',
    () {
      final fallbackPaths = MainApp.discoverSubordinateFiles(
        'C:/this/path/does/not/exist',
      );

      expect(fallbackPaths, isEmpty);
    },
  );

  testWidgets('settings dialog includes a valid local root location default', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Display mode'), findsOneWidget);
    expect(find.text('Root location'), findsOneWidget);
    expect(find.text('G:\\My Drive'), findsOneWidget);
  });

  testWidgets('Information tab displays the contact form', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Information'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Send a Question'), findsOneWidget);
    expect(find.text('Return name'), findsOneWidget);
    expect(find.text('Return email'), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
  });

  testWidgets('Help tab displays file discovery instructions', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Help'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('File Explorer Help'), findsOneWidget);
    expect(find.text('Choose a root location'), findsOneWidget);
    expect(find.text('Discover files'), findsOneWidget);
    expect(find.text('Filter the results'), findsOneWidget);
    expect(find.text('Compare matching files'), findsOneWidget);
    expect(find.textContaining('stops after 2 minutes'), findsOneWidget);
    expect(find.textContaining('identical content'), findsOneWidget);
  });

  testWidgets('restores the persisted root location at startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'root_location': 'C:/Saved/Root',
    });

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('C:/Saved/Root'), findsOneWidget);
  });

  testWidgets('migrates the previous default root location at startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'root_location': 'C:/Users/stefa/Documents',
    });

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('G:\\My Drive'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('root_location'), 'G:\\My Drive');
  });

  testWidgets('Save persists the edited root location', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'C:/New/Root');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('root_location'), 'C:/New/Root');
  });

  testWidgets('restores the persisted theme mode at startup', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode': 'dark',
    });

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('theme selection is persisted', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme_mode'), 'light');
  });

  testWidgets('settings dropdown lists extensions selected for future scans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (_) async => const <String>[
          'C:/Root/file.txt',
          'C:/Root/file.json',
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final jsonExtension = find.descendant(
      of: find.byType(CheckboxListTile),
      matching: find.text('.json'),
    );
    await tester.tap(jsonExtension);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Extensions for future scans'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('extension-dropdown')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DropdownMenuItem<String>),
        matching: find.text('.txt'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DropdownMenuItem<String>),
        matching: find.text('.json'),
      ),
      findsNothing,
    );
  });

  testWidgets('Reset clears persisted values and restores defaults', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'root_location': 'C:/Saved/Root',
      'theme_mode': 'dark',
      'deselected_extensions': <String>['.json'],
    });

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('root_location'), isFalse);
    expect(preferences.containsKey('theme_mode'), isFalse);
    expect(preferences.containsKey('deselected_extensions'), isFalse);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(find.text('G:\\My Drive'), findsOneWidget);
  });

  testWidgets('Scan now saves the root and immediately scans it', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('scan_now_root_');
    final file = File('${root.path}/found.txt')..writeAsStringSync('found');

    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (rootLocation) async {
          return MainApp.discoverSubordinateFiles(rootLocation);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), root.path);
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(file.uri.pathSegments.last), findsOneWidget);

    root.deleteSync(recursive: true);
  });

  testWidgets('shows a circular progress indicator while scanning', (
    tester,
  ) async {
    final scanCompleter = Completer<List<String>>();

    await tester.pumpWidget(
      MainApp(fileDiscoverer: (_) => scanCompleter.future),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Scanning'), findsOneWidget);

    scanCompleter.complete(const <String>[]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('extension filters are unique and hide unchecked file paths', (
    tester,
  ) async {
    const textFile = 'C:/Root/first.txt';
    const secondTextFile = 'C:/Root/nested/second.TXT';
    const jsonFile = 'C:/Root/data.json';

    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (_) async => const <String>[
          textFile,
          secondTextFile,
          jsonFile,
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final textExtension = find.descendant(
      of: find.byType(CheckboxListTile),
      matching: find.text('.txt'),
    );
    final jsonExtension = find.descendant(
      of: find.byType(CheckboxListTile),
      matching: find.text('.json'),
    );

    expect(find.text('Extensions'), findsOneWidget);
    expect(find.text('File Paths'), findsNothing);
    expect(find.text('Path Parts'), findsNothing);
    expect(find.text('Sorted by File Name'), findsOneWidget);
    expect(textExtension, findsOneWidget);
    expect(jsonExtension, findsOneWidget);
    expect(find.text('first.txt'), findsOneWidget);
    expect(find.text('second.TXT'), findsOneWidget);
    expect(find.text('data.json'), findsOneWidget);

    final textExtensionPosition = tester.getCenter(textExtension);
    final jsonExtensionPosition = tester.getCenter(jsonExtension);
    final filePosition = tester.getCenter(find.text('first.txt'));
    expect(textExtensionPosition.dx, closeTo(jsonExtensionPosition.dx, 1));
    expect(textExtensionPosition.dy, isNot(jsonExtensionPosition.dy));
    expect(textExtensionPosition.dx, lessThan(filePosition.dx));

    await tester.tap(jsonExtension);
    await tester.pump();

    expect(
      tester.getCenter(jsonExtension).dy,
      greaterThan(tester.getCenter(textExtension).dy),
    );
    expect(find.text('data.json'), findsNothing);

    await tester.tap(jsonExtension);
    await tester.pump();

    await tester.tap(textExtension);
    await tester.pump();

    expect(find.text('first.txt'), findsNothing);
    expect(find.text('second.TXT'), findsNothing);
    expect(find.text('data.json'), findsOneWidget);
  });

  testWidgets('unchecked extensions remain disabled after restart', (
    tester,
  ) async {
    const textFile = 'C:/Root/file.txt';
    const jsonFile = 'C:/Root/file.json';
    Future<List<String>> discoverFiles(_) async => const <String>[
      textFile,
      jsonFile,
    ];

    await tester.pumpWidget(MainApp(fileDiscoverer: discoverFiles));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final jsonExtension = find.descendant(
      of: find.byType(CheckboxListTile),
      matching: find.text('.json'),
    );
    await tester.tap(jsonExtension);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MainApp(fileDiscoverer: discoverFiles));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final restoredJsonTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('.json').first,
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(restoredJsonTile.value, isFalse);
    expect(find.text('file.json'), findsNothing);
    expect(find.text('file.txt'), findsOneWidget);
  });

  testWidgets('unchecked extensions remain disabled after rescan', (
    tester,
  ) async {
    const textFile = 'C:/Root/file.txt';
    const jsonFile = 'C:/Root/file.json';

    await tester.pumpWidget(
      MainApp(fileDiscoverer: (_) async => const <String>[textFile, jsonFile]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final jsonExtension = find.descendant(
      of: find.byType(CheckboxListTile),
      matching: find.text('.json'),
    );
    await tester.tap(jsonExtension);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final jsonTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('.json').first,
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(jsonTile.value, isFalse);
    expect(find.text('file.json'), findsNothing);
    expect(find.text('file.txt'), findsOneWidget);
  });

  testWidgets('saved extension selections apply to an immediate startup scan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'deselected_extensions': <String>['.json'],
    });

    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (_) async => const <String>[
          'C:/Root/file.txt',
          'C:/Root/file.json',
        ],
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final jsonTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('.json').first,
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(jsonTile.value, isFalse);
    expect(find.text('file.json'), findsNothing);
  });

  testWidgets('folder scan displays PowerShell files and the ps1 extension', (
    tester,
  ) async {
    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (_) async => const <String>[
          'C:/Root/scripts/build.ps1',
          'C:/Root/scripts/deploy.PS1',
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('.ps1'), findsOneWidget);
    expect(find.text('build.ps1'), findsOneWidget);
    expect(find.text('deploy.PS1'), findsOneWidget);
  });

  testWidgets('removed path columns are not displayed', (tester) async {
    const filePath = 'C:/Root/nested/report.final.json';

    await tester.pumpWidget(
      MainApp(fileDiscoverer: (_) async => const <String>[filePath]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Extensions'), findsOneWidget);
    expect(find.text('File Paths'), findsNothing);
    expect(find.text('Path Parts'), findsNothing);
    expect(find.text('Root'), findsNothing);
    expect(find.text('Folder path'), findsNothing);
    expect(find.text('File name'), findsNothing);
    expect(find.text('File extension'), findsNothing);
    expect(find.text('Sorted by File Name'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);
    expect(find.text('report.final.json'), findsOneWidget);
  });

  testWidgets('the complete Discover display scrolls horizontally', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MainApp(fileDiscoverer: (_) async => const <String>['C:/Root/file.txt']),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final horizontalDisplay = find.byKey(
      const ValueKey<String>('discover-horizontal-scroll'),
    );
    final initialPosition = tester.getTopLeft(find.text('Extensions')).dx;

    await tester.drag(horizontalDisplay, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Extensions')).dx,
      lessThan(initialPosition),
    );
  });

  testWidgets('Discover columns can be resized and collapsed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MainApp(fileDiscoverer: (_) async => const <String>['C:/Root/file.txt']),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final initialSortedNamesX = tester
        .getTopLeft(find.text('Sorted by File Name'))
        .dx;
    await tester.drag(
      find.byKey(const ValueKey<String>('extensions-resizer')),
      const Offset(100, 0),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Sorted by File Name')).dx,
      greaterThan(initialSortedNamesX),
    );

    await tester.tap(find.byTooltip('Collapse Extensions'));
    await tester.pump();
    expect(find.text('Extensions'), findsNothing);
    expect(find.byTooltip('Expand Extensions'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand Extensions'));
    await tester.pump();
    expect(find.text('Extensions'), findsOneWidget);
  });

  testWidgets('results column groups paths under sorted file names', (
    tester,
  ) async {
    const alphaPath = 'C:/Root/z-folder/Alpha.txt';
    const secondAlphaPath = 'C:/Root/other/Alpha.txt';
    const middlePath = 'C:/Root/m-folder/middle.txt';
    const zetaPath = 'C:/Root/a-folder/zeta.txt';

    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (_) async => const <String>[
          zetaPath,
          middlePath,
          alphaPath,
          secondAlphaPath,
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Sorted by File Name'), findsOneWidget);
    final sortedPane = find.byKey(
      const ValueKey<String>('sorted-file-names-pane'),
    );
    final sortedAlpha = find.descendant(
      of: sortedPane,
      matching: find.text('Alpha.txt'),
    );
    final sortedMiddle = find.descendant(
      of: sortedPane,
      matching: find.text('middle.txt'),
    );
    final sortedZeta = find.descendant(
      of: sortedPane,
      matching: find.text('zeta.txt'),
    );

    expect(sortedAlpha, findsOneWidget);
    expect(
      find.descendant(of: sortedPane, matching: find.text(alphaPath)),
      findsNothing,
    );
    expect(
      find.descendant(of: sortedPane, matching: find.text(secondAlphaPath)),
      findsNothing,
    );
    expect(
      tester.getCenter(sortedAlpha).dy,
      lessThan(tester.getCenter(sortedMiddle).dy),
    );
    expect(
      tester.getCenter(sortedMiddle).dy,
      lessThan(tester.getCenter(sortedZeta).dy),
    );

    await tester.ensureVisible(sortedAlpha);
    await tester.pumpAndSettle();
    await tester.tap(sortedAlpha);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sortedPane, matching: find.text(alphaPath)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sortedPane, matching: find.text(secondAlphaPath)),
      findsOneWidget,
    );
  });

  testWidgets('Compare deduplicates content and lists every matching path', (
    tester,
  ) async {
    const firstPath = 'C:/Root/first/shared.txt';
    const secondPath = 'C:/Root/second/shared.txt';
    final duplicatePaths = List<String>.generate(
      20,
      (index) => 'C:/Root/duplicate-$index/shared.txt',
    );
    final allPaths = <String>[firstPath, secondPath, ...duplicatePaths];
    final duplicateContentPaths =
        allPaths.where((path) => path != secondPath).toList()..sort();
    final requestedPaths = <String>[];

    await tester.pumpWidget(
      MainApp(
        fileDiscoverer: (_) async => allPaths,
        fileContentReader: (path) async {
          requestedPaths.add(path);
          return path == secondPath ? 'second file text' : 'first file text';
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Compare'), findsNothing);
    await tester.tap(find.text('shared.txt'));
    await tester.pumpAndSettle();

    final compareButton = find.widgetWithText(FilledButton, 'Compare');
    expect(compareButton, findsOneWidget);
    await tester.tap(compareButton);
    await tester.pumpAndSettle();

    expect(requestedPaths, unorderedEquals(allPaths));
    final comparisonPane = find.byKey(
      const ValueKey<String>('comparison-pane'),
    );
    expect(
      find.descendant(of: comparisonPane, matching: find.byType(Card)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: comparisonPane,
        matching: find.text(duplicateContentPaths.join('\n')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: comparisonPane, matching: find.text(secondPath)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comparisonPane,
        matching: find.text('first file text'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comparisonPane,
        matching: find.text('second file text'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('comparison-content-0')),
      findsOneWidget,
    );
    final comparisonHorizontalScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey<String>('comparison-horizontal-scroll-0')),
    );
    expect(comparisonHorizontalScroll.scrollDirection, Axis.horizontal);

    final fullScreenButton = find.byKey(
      const ValueKey<String>('full-screen-compare-button'),
    );
    final comparePaneLeft = tester.getTopLeft(comparisonPane).dx;
    expect(
      tester.getTopLeft(fullScreenButton).dx,
      inInclusiveRange(comparePaneLeft, comparePaneLeft + 32),
    );
    await tester.ensureVisible(fullScreenButton);
    await tester.pumpAndSettle();
    await tester.tap(fullScreenButton);
    await tester.pumpAndSettle();

    final fullScreenDialog = find.byType(Dialog);
    expect(fullScreenDialog, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('print-full-screen-compare')),
      findsOneWidget,
    );
    final firstFullScreenScroll = tester.widget<SingleChildScrollView>(
      find.byKey(
        const ValueKey<String>('full-screen-comparison-horizontal-scroll-0'),
      ),
    );
    final secondFullScreenScroll = tester.widget<SingleChildScrollView>(
      find.byKey(
        const ValueKey<String>('full-screen-comparison-horizontal-scroll-1'),
      ),
    );
    expect(firstFullScreenScroll.scrollDirection, Axis.horizontal);
    expect(secondFullScreenScroll.scrollDirection, Axis.horizontal);
    final firstFullScreenScrollbar = tester.widget<Scrollbar>(
      find.ancestor(
        of: find.byKey(
          const ValueKey<String>('full-screen-comparison-horizontal-scroll-0'),
        ),
        matching: find.byType(Scrollbar),
      ),
    );
    final secondFullScreenScrollbar = tester.widget<Scrollbar>(
      find.ancestor(
        of: find.byKey(
          const ValueKey<String>('full-screen-comparison-horizontal-scroll-1'),
        ),
        matching: find.byType(Scrollbar),
      ),
    );
    expect(firstFullScreenScrollbar.thumbVisibility, isTrue);
    expect(secondFullScreenScrollbar.thumbVisibility, isTrue);
    expect(
      firstFullScreenScrollbar.controller,
      firstFullScreenScroll.controller,
    );
    expect(
      secondFullScreenScrollbar.controller,
      secondFullScreenScroll.controller,
    );
    final firstFullScreenContent = find.descendant(
      of: fullScreenDialog,
      matching: find.text('first file text'),
    );
    final secondFullScreenContent = find.descendant(
      of: fullScreenDialog,
      matching: find.text('second file text'),
    );
    expect(
      tester.getTopLeft(firstFullScreenContent).dx,
      lessThan(tester.getTopLeft(secondFullScreenContent).dx),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('column strings remain on one line', (tester) async {
    const longPath =
        'C:/Root/a-very-long-folder-name/another-long-folder/report.final.txt';

    await tester.binding.setSurfaceSize(const Size(500, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MainApp(fileDiscoverer: (_) async => const <String>[longPath]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    final sortedHeader = tester.widget<Text>(find.text('Sorted by File Name'));
    expect(sortedHeader.maxLines, 1);

    await tester.ensureVisible(find.text('report.final.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('report.final.txt'));
    await tester.pumpAndSettle();

    final pathText = tester.widget<Text>(find.text(longPath));
    expect(pathText.maxLines, 1);
  });

  testWidgets('first tab is labeled Discover', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });
}
