import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/comparison_entry.dart';

/// Builds a printable PDF with one independently paginated section per entry.
///
/// Paths are printed as a heading and file contents use a monospaced font.
/// Long entries may span physical pages because each section is a [pw.MultiPage].
Future<Uint8List> buildComparisonPdf(
  PdfPageFormat pageFormat,
  String? fileName,
  List<ComparisonEntry> entries,
) async {
  final document = pw.Document();
  // Starting each distinct content entry in its own MultiPage preserves a
  // clear comparison boundary while allowing long files to paginate naturally.
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            fileName == null
                ? 'Comparison ${index + 1}'
                : '$fileName - Comparison ${index + 1}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            entry.paths.join('\n'),
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          for (final line in entry.content.split(RegExp(r'\r\n?|\n')))
            line.isEmpty
                ? pw.SizedBox(height: 14)
                : pw.Text(
                    line,
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontSize: 12,
                      lineSpacing: 2,
                    ),
                  ),
        ],
      ),
    );
  }
  return document.save();
}
