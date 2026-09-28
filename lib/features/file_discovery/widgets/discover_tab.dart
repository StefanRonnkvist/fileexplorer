import 'package:flutter/material.dart';

import '../../../core/widgets/resizable_pane.dart';
import '../../file_comparison/controllers/comparison_controller.dart';
import '../../file_comparison/widgets/comparison_pane.dart';
import '../controllers/discovery_controller.dart';
import 'extension_list.dart';
import 'file_group_list.dart';
import 'scan_button.dart';

/// Main workspace: the scan control plus the extensions, file, and compare
/// panes side by side, with horizontal scrolling when they do not all fit.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({
    super.key,
    required this.discovery,
    required this.comparison,
  });

  final DiscoveryController discovery;
  final ComparisonController comparison;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _horizontalScroll = ScrollController();
  final PaneState _extensions = PaneState(
    width: 240,
    minWidth: 200,
    maxWidth: 600,
  );
  final PaneState _fileNames = PaneState(
    width: 600,
    minWidth: 400,
    maxWidth: 900,
  );
  final PaneState _comparison = PaneState(
    width: 800,
    minWidth: 500,
    maxWidth: 1400,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _resize(PaneState pane, double delta) {
    setState(() => pane.resize(delta));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.discovery,
      builder: (context, _) {
        final notice = widget.discovery.notice;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ScanButton(
                isScanning: widget.discovery.isScanning,
                onScan: widget.discovery.scan,
              ),
            ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(notice),
              ),
            Expanded(
              child: widget.discovery.files.isEmpty
                  ? Center(child: Text(_emptyMessage))
                  : _buildWorkspace(),
            ),
          ],
        );
      },
    );
  }

  String get _emptyMessage => widget.discovery.isScanning
      ? 'Searching selected path...'
      : widget.discovery.notice ?? 'No files found in the root location.';

  Widget _buildWorkspace() {
    final discovery = widget.discovery;
    return LayoutBuilder(
      builder: (context, constraints) {
        final panesWidth =
            _extensions.displayWidth +
            _fileNames.displayWidth +
            _comparison.displayWidth +
            3 * paneResizerWidth;
        // Panes keep their preferred widths; the workspace scrolls sideways
        // whenever the viewport is too narrow to show all of them.
        final displayWidth = panesWidth < constraints.maxWidth
            ? constraints.maxWidth
            : panesWidth;
        return Scrollbar(
          controller: _horizontalScroll,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            key: const ValueKey<String>('discover-horizontal-scroll'),
            controller: _horizontalScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: displayWidth,
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _extensions.displayWidth,
                    child: CollapsiblePane(
                      title: 'Extensions',
                      collapsed: _extensions.collapsed,
                      onCollapsedChanged: (collapsed) =>
                          setState(() => _extensions.collapsed = collapsed),
                      child: ExtensionList(
                        discovery: discovery,
                        extensions: discovery.extensions,
                      ),
                    ),
                  ),
                  _resizer('extensions-resizer', _extensions),
                  SizedBox(
                    key: const ValueKey<String>('sorted-file-names-pane'),
                    width: _fileNames.displayWidth,
                    child: CollapsiblePane(
                      title: 'Sorted by File Name',
                      collapsed: _fileNames.collapsed,
                      onCollapsedChanged: (collapsed) =>
                          setState(() => _fileNames.collapsed = collapsed),
                      child: FileGroupList(
                        groups: discovery.fileNameGroups,
                        onCompare: (fileName, paths) =>
                            widget.comparison.compare(fileName, paths),
                      ),
                    ),
                  ),
                  _resizer('sorted-file-names-resizer', _fileNames),
                  SizedBox(
                    key: const ValueKey<String>('comparison-pane'),
                    width: _comparison.displayWidth,
                    child: ComparisonPane(
                      comparison: widget.comparison,
                      collapsed: _comparison.collapsed,
                      onCollapsedChanged: (collapsed) =>
                          setState(() => _comparison.collapsed = collapsed),
                    ),
                  ),
                  _resizer('comparison-resizer', _comparison),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resizer(String key, PaneState pane) {
    return PaneResizer(
      key: ValueKey<String>(key),
      onDrag: (delta) => _resize(pane, delta),
    );
  }
}
