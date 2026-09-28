import 'package:fileexplorer/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('settings dialog includes a valid local root location default', (
    tester,
  ) async {
    await tester.pumpWidget(const FileExplorerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Display mode'), findsOneWidget);
    expect(find.text('Root location'), findsOneWidget);
    expect(find.text('G:\\My Drive'), findsOneWidget);
  });

  testWidgets('restores the persisted root location at startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'root_location': 'C:/Saved/Root',
    });

    await tester.pumpWidget(const FileExplorerApp());
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

    await tester.pumpWidget(const FileExplorerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('G:\\My Drive'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('root_location'), 'G:\\My Drive');
  });

  testWidgets('Save persists the edited root location', (tester) async {
    await tester.pumpWidget(const FileExplorerApp());
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

    await tester.pumpWidget(const FileExplorerApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('theme selection is persisted', (tester) async {
    await tester.pumpWidget(const FileExplorerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme_mode'), 'light');
  });

  testWidgets('Reset clears persisted values and restores defaults', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'root_location': 'C:/Saved/Root',
      'theme_mode': 'dark',
      'deselected_extensions': <String>['.json'],
    });

    await tester.pumpWidget(const FileExplorerApp());
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

  testWidgets('settings dropdown lists extensions selected for future scans', (
    tester,
  ) async {
    await tester.pumpWidget(
      FileExplorerApp(
        discoverer: (_) async => const <String>[
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
}
