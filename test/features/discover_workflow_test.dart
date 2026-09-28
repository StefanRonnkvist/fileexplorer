import 'dart:async';
import 'dart:io';

import 'package:fileexplorer/app/app.dart';
import 'package:fileexplorer/features/file_discovery/services/file_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boot splash transitions to the main interface', (tester) async {
    await tester.pumpWidget(const FileExplorerApp(showSplash: true));

    expect(find.text('Loading...'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Loading...'), findsNothing);
    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets('first tab is labeled Discover', (tester) async {
    await tester.pumpWidget(const FileExplorerApp());
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('Information tab displays the contact form', (tester) async {
    await tester.pumpWidget(const FileExplorerApp());
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
    await tester.pumpWidget(const FileExplorerApp());
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

  group('scanning', () {
    testWidgets('shows a circular progress indicator while scanning', (
      tester,
    ) async {
      final scanCompleter = Completer<List<String>>();

      await tester.pumpWidget(
        FileExplorerApp(discoverer: (_) => scanCompleter.future),
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

    testWidgets('Scan now saves the root and immediately scans it', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('scan_now_root_');
      final file = File('${root.path}/found.txt')..writeAsStringSync('found');

      await tester.pumpWidget(
        FileExplorerApp(
          discoverer: (rootLocation) async =>
              FileScanner.scanSync(rootLocation),
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
  });

  group('discovery results', () {
    testWidgets('extension filters are unique and hide unchecked file paths', (
      tester,
    ) async {
      const textFile = 'C:/Root/first.txt';
      const secondTextFile = 'C:/Root/nested/second.TXT';
      const jsonFile = 'C:/Root/data.json';

      await tester.pumpWidget(
        FileExplorerApp(
          discoverer: (_) async => const <String>[
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

    testWidgets('folder scan displays PowerShell files and the ps1 extension', (
      tester,
    ) async {
      await tester.pumpWidget(
        FileExplorerApp(
          discoverer: (_) async => const <String>[
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
        FileExplorerApp(discoverer: (_) async => const <String>[filePath]),
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

    testWidgets('results column groups paths under sorted file names', (
      tester,
    ) async {
      const alphaPath = 'C:/Root/z-folder/Alpha.txt';
      const secondAlphaPath = 'C:/Root/other/Alpha.txt';
      const middlePath = 'C:/Root/m-folder/middle.txt';
      const zetaPath = 'C:/Root/a-folder/zeta.txt';

      await tester.pumpWidget(
        FileExplorerApp(
          discoverer: (_) async => const <String>[
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
  });

  group('workspace layout', () {
    testWidgets('the complete Discover display scrolls horizontally', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FileExplorerApp(
          discoverer: (_) async => const <String>['C:/Root/file.txt'],
        ),
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

    testWidgets('columns can be resized and collapsed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        FileExplorerApp(
          discoverer: (_) async => const <String>['C:/Root/file.txt'],
        ),
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

    testWidgets('column strings remain on one line', (tester) async {
      const longPath =
          'C:/Root/a-very-long-folder-name/another-long-folder/report.final.txt';

      await tester.binding.setSurfaceSize(const Size(500, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        FileExplorerApp(discoverer: (_) async => const <String>[longPath]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      final sortedHeader = tester.widget<Text>(
        find.text('Sorted by File Name'),
      );
      expect(sortedHeader.maxLines, 1);

      await tester.ensureVisible(find.text('report.final.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('report.final.txt'));
      await tester.pumpAndSettle();

      final pathText = tester.widget<Text>(find.text(longPath));
      expect(pathText.maxLines, 1);
    });
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
      FileExplorerApp(
        discoverer: (_) async => allPaths,
        contentReader: (path) async {
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
}
