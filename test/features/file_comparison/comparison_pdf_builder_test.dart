import 'dart:convert';

import 'package:fileexplorer/features/file_comparison/models/comparison_entry.dart';
import 'package:fileexplorer/features/file_comparison/services/comparison_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
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
}
