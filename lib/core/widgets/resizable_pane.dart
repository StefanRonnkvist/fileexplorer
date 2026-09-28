import 'package:flutter/material.dart';

/// Width of a pane while it is collapsed to its expand button.
const double collapsedPaneWidth = 48;

/// Width of the drag handle placed after every pane.
const double paneResizerWidth = 8;

/// Mutable width and collapse state of one workspace pane.
class PaneState {
  PaneState({required this.width, required this.minWidth, this.maxWidth});

  final double minWidth;
  final double? maxWidth;
  double width;
  bool collapsed = false;

  double get displayWidth => collapsed ? collapsedPaneWidth : width;

  /// Applies a drag of [delta] pixels; dragging also reopens a collapsed pane.
  void resize(double delta) {
    collapsed = false;
    width = (width + delta).clamp(minWidth, maxWidth ?? double.infinity);
  }
}

/// A titled pane that can collapse to a single expand button.
class CollapsiblePane extends StatelessWidget {
  const CollapsiblePane({
    super.key,
    required this.title,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.child,
    this.leadingAction,
  });

  final String title;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;
  final Widget child;
  final Widget? leadingAction;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Align(
        alignment: Alignment.topCenter,
        child: IconButton(
          tooltip: 'Expand $title',
          onPressed: () => onCollapsedChanged(false),
          icon: const Icon(Icons.chevron_right),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              ?leadingAction,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Collapse $title',
                onPressed: () => onCollapsedChanged(true),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

/// Vertical drag handle that reports horizontal drag distances.
class PaneResizer extends StatelessWidget {
  const PaneResizer({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: paneResizerWidth,
          child: Center(
            child: VerticalDivider(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
