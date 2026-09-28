import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/comparison_entry.dart';
import '../services/comparison_pdf_builder.dart';

/// Displays distinct file contents side by side in a full-screen dialog.
class FullScreenComparison extends StatefulWidget {
  const FullScreenComparison({
    super.key,
    required this.fileName,
    required this.entries,
  });

  final String? fileName;
  final List<ComparisonEntry> entries;

  @override
  State<FullScreenComparison> createState() => _FullScreenComparisonState();
}

class _FullScreenComparisonState extends State<FullScreenComparison> {
  late final List<ScrollController> _horizontalControllers;

  @override
  void initState() {
    super.initState();
    // Each pane needs its own controller so every always-visible horizontal
    // scrollbar reports and controls the correct content offset.
    _horizontalControllers = List<ScrollController>.generate(
      widget.entries.length,
      (_) => ScrollController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _horizontalControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _printComparison() async {
    // Printing supplies the selected printer's page format to the PDF builder.
    await Printing.layoutPdf(
      name: widget.fileName ?? 'Comparison',
      onLayout: (pageFormat) =>
          buildComparisonPdf(pageFormat, widget.fileName, widget.entries),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog.fullscreen(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: Text(
                  widget.fileName == null
                      ? 'Compare'
                      : 'Compare: ${widget.fileName}',
                ),
                actions: [
                  TextButton.icon(
                    key: const ValueKey<String>('print-full-screen-compare'),
                    onPressed: _printComparison,
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                  IconButton(
                    key: const ValueKey<String>('close-full-screen-compare'),
                    tooltip: 'Close full screen',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // On wide displays panes share the viewport; on smaller
                    // displays minimum widths preserve readable source text.
                    final paneWidth =
                        (constraints.maxWidth / widget.entries.length)
                            .clamp(400.0, 800.0)
                            .toDouble();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: paneWidth * widget.entries.length,
                        height: constraints.maxHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var index = 0;
                              index < widget.entries.length;
                              index++
                            )
                              SizedBox(
                                width: paneWidth,
                                child: _buildEntry(context, index, paneWidth),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, int index, double paneWidth) {
    final entry = widget.entries[index];
    final horizontalController = _horizontalControllers[index];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 112,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  entry.paths.join('\n'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              controller: horizontalController,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                key: ValueKey<String>(
                  'full-screen-comparison-horizontal-scroll-$index',
                ),
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: paneWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: SelectableText(
                      entry.content,
                      key: ValueKey<String>(
                        'full-screen-comparison-content-$index',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
