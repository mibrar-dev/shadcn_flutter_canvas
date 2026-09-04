/// Z-order Layers panel replacing the icon rail's `<id> panel` placeholder.
///
/// Groups one row per node under its screen header (HANDOFF P1-4). Doc order
/// is reversed within a group so the top row is the frontmost node.
///
/// NOTE: no reorder controls — the store has no reorder primitive (only
/// moveNode x/y), so rows are display + select/duplicate/delete only.
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_core/canvas_core.dart';

/// Row tap target size for the trailing duplicate/delete actions.
const double _kActionButtonSize = 28;

/// Icon size inside the trailing action buttons.
const double _kActionIconSize = 16;

/// Forwards pure-Dart store notifications to Flutter listeners (same pattern
/// as `design_canvas.dart`'s `_StoreRelay`, the sanctioned `Listenable`
/// adapter under `lib/ui/`).
class _StoreRelay extends foundation.ChangeNotifier {
  _StoreRelay(this._store) {
    _store.addListener(_forward);
  }

  final CanvasStore _store;

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_forward);
    super.dispose();
  }
}

class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.store,
    required this.selectedNodeId,
    required this.onSelectNode,
  });

  final CanvasStore store;
  final String? selectedNodeId;
  final ValueChanged<String?> onSelectNode;

  @override
  Widget build(BuildContext context) {
    // Stateless contract: the stateful body owns the relay (and disposes it)
    // so this widget never leaks a listener across rebuilds.
    return _LayersBody(
      store: store,
      selectedNodeId: selectedNodeId,
      onSelectNode: onSelectNode,
    );
  }
}

class _LayersBody extends StatefulWidget {
  const _LayersBody({
    required this.store,
    required this.selectedNodeId,
    required this.onSelectNode,
  });

  final CanvasStore store;
  final String? selectedNodeId;
  final ValueChanged<String?> onSelectNode;

  @override
  State<_LayersBody> createState() => _LayersBodyState();
}

class _LayersBodyState extends State<_LayersBody> {
  late final _StoreRelay _relay = _StoreRelay(widget.store);

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return ListenableBuilder(
      listenable: _relay,
      builder: (context, _) {
        final doc = widget.store.doc;
        if (doc.screens.isEmpty) {
          return Center(
            child: Text(
              'No screens',
              style:
                  EditorType.field.copyWith(color: colors.onSurfaceVariant),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(EditorMetrics.panelInset),
          children: [
            for (final screen in doc.screens) ...[
              Text(
                screen.name,
                style: EditorType.sectionHeader
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: EditorMetrics.tileGap),
              for (final node in _frontmostFirst(doc, screen))
                _LayerRow(
                  node: node,
                  selected: node.id == widget.selectedNodeId,
                  onTap: () => widget.onSelectNode(node.id),
                  onDuplicate: () => widget.store.duplicateNode(node.id),
                  onDelete: () => widget.store.deleteNode(node.id),
                ),
              if (!_hasNodes(doc, screen))
                Text(
                  'Empty',
                  style: EditorType.tileLabel
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              const SizedBox(height: EditorMetrics.tileGap),
            ],
          ],
        );
      },
    );
  }
}

/// Nodes of [screen] in doc order reversed (top row = frontmost).
List<CanvasNode> _frontmostFirst(ScreenDoc doc, CanvasScreen screen) {
  final nodes = [
    for (final n in doc.nodes)
      if (n.screenId == screen.id) n,
  ];
  return nodes.reversed.toList();
}

bool _hasNodes(ScreenDoc doc, CanvasScreen screen) =>
    doc.nodes.any((n) => n.screenId == screen.id);

/// Capitalized kind of the node's first item, or 'empty' when it has none.
String _kindLabel(CanvasNode node) {
  if (node.items.isEmpty) return 'Empty';
  final kind = node.items.first.kind;
  if (kind.isEmpty) return 'Empty';
  return kind[0].toUpperCase() + kind.substring(1);
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  final CanvasNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final radius =
        BorderRadius.circular(EditorMetrics.segmentInnerRadius);
    return Material(
      color: selected
          ? colors.toolbarActive.withValues(alpha: 0.25)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: colors.surfaceContainerHigh,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EditorMetrics.panelInset,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_kindLabel(node)} · ${node.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EditorType.tileLabel.copyWith(
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Duplicate',
                onPressed: onDuplicate,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: _kActionButtonSize,
                  height: _kActionButtonSize,
                ),
                iconSize: _kActionIconSize,
                color: colors.onSurfaceVariant,
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: _kActionButtonSize,
                  height: _kActionButtonSize,
                ),
                iconSize: _kActionIconSize,
                color: colors.onSurfaceVariant,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
