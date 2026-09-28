import 'package:flutter/material.dart';

import '../../../core/widgets/resizable_pane.dart';
import '../controllers/comparison_controller.dart';
import 'comparison_results.dart';
import 'full_screen_comparison.dart';

/// Pane showing the comparison results, with a full-screen view.
class ComparisonPane extends StatelessWidget {
  const ComparisonPane({
    super.key,
    required this.comparison,
    required this.collapsed,
    required this.onCollapsedChanged,
  });

  final ComparisonController comparison;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;

  Future<void> _showFullScreen(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FullScreenComparison(
        fileName: comparison.fileName,
        entries: comparison.entries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: comparison,
      builder: (context, _) {
        final fileName = comparison.fileName;
        return CollapsiblePane(
          title: fileName == null ? 'Compare' : 'Compare: $fileName',
          collapsed: collapsed,
          onCollapsedChanged: onCollapsedChanged,
          leadingAction: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilledButton.tonalIcon(
              key: const ValueKey<String>('full-screen-compare-button'),
              onPressed: comparison.entries.isEmpty
                  ? null
                  : () => _showFullScreen(context),
              icon: const Icon(Icons.fullscreen),
              label: const Text('Full Screen'),
            ),
          ),
          child: ComparisonResults(comparison: comparison),
        );
      },
    );
  }
}
