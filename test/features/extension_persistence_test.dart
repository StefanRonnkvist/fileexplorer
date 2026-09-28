import 'package:fileexplorer/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

    await tester.pumpWidget(FileExplorerApp(discoverer: discoverFiles));
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
    await tester.pumpWidget(FileExplorerApp(discoverer: discoverFiles));
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
      FileExplorerApp(
        discoverer: (_) async => const <String>[textFile, jsonFile],
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
      FileExplorerApp(
        discoverer: (_) async => const <String>[
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
}
