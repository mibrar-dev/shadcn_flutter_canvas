/// Z-order Layers panel replacing the icon rail's `<id> panel` placeholder.
///
/// Groups one row per node under its screen header (HANDOFF P1-4). Doc order
/// is reversed within a group so the top row is the frontmost node. Row
/// containers render as a header with their children indented one level
/// beneath (frontmost-first within the row); the row header itself is
/// selectable for gap editing. Rows carry bring-forward/send-backward
/// controls wired to [CanvasStore.reorderNode] within their visual group,
/// and screen headers carry a rename affordance wired to
/// [CanvasStore.renameScreen].
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
              style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(EditorMetrics.panelInset),
          children: [
            for (final screen in doc.screens) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      screen.name,
                      style: EditorType.sectionHeader
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rename screen',
                    onPressed: () => _renameScreen(context, screen),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: _kActionButtonSize,
                      height: _kActionButtonSize,
                    ),
                    iconSize: _kActionIconSize,
                    color: colors.onSurfaceVariant,
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
              const SizedBox(height: EditorMetrics.tileGap),
              Builder(
                builder: (_) {
                  final roots = _rootsFrontmostFirst(doc, screen);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < roots.length; index++) ...[
                        _layerRow(roots[index], roots.length, index),
                        // Row children indent one level under their row
                        // header, reordering within their own visual group.
                        ..._childRows(doc, roots[index]),
                      ],
                    ],
                  );
                },
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

  /// One layer row wired to the store: tap selects (rows select for gap
  /// editing), duplicate/delete act, and the reorder buttons move within the
  /// node's visual group ([groupLength]/[visualIndex] in frontmost-first
  /// display order) by passing the group-relative doc index.
  Widget _layerRow(CanvasNode node, int groupLength, int visualIndex) {
    return _LayerRow(
      node: node,
      selected: node.id == widget.selectedNodeId,
      onTap: () => widget.onSelectNode(node.id),
      onDuplicate: () => widget.store.duplicateNode(node.id),
      onDelete: () => widget.store.deleteNode(node.id),
      // Displayed frontmost-first: group-relative doc index of this row is
      // groupLength-1-visualIndex; up moves toward the front (+1).
      onMoveUp: visualIndex == 0
          ? null
          : () => widget.store.reorderNode(
                node.id,
                groupLength - visualIndex,
              ),
      onMoveDown: visualIndex == groupLength - 1
          ? null
          : () => widget.store.reorderNode(
                node.id,
                groupLength - 2 - visualIndex,
              ),
    );
  }

  /// Indented child rows for a row container (frontmost-first in the row).
  /// Empty for leaves.
  List<Widget> _childRows(ScreenDoc doc, CanvasNode row) {
    if (!row.isRow) return const [];
    final kids = _childrenFrontmostFirst(doc, row);
    return [
      for (var ci = 0; ci < kids.length; ci++)
        Padding(
          padding: const EdgeInsets.only(left: EditorMetrics.panelInset),
          child: _layerRow(kids[ci], kids.length, ci),
        ),
    ];
  }

  /// Opens the screen-rename dialog (prefilled; empty Save is a no-op close).
  void _renameScreen(BuildContext context, CanvasScreen screen) {
    final controller = TextEditingController(text: screen.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = EditorTheme.of(dialogContext);
        void save() {
          final name = controller.text;
          Navigator.of(dialogContext).pop();
          if (name.trim().isEmpty) return;
          widget.store.renameScreen(screen.id, name);
        }

        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          title: Text(
            'Rename screen',
            style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: EditorType.field.copyWith(color: colors.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  EditorMetrics.segmentInnerRadius,
                ),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => save(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: EditorType.tileLabel
                    .copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: save,
              child: Text(
                'Save',
                style: EditorType.tileLabel.copyWith(color: colors.onSurface),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Root nodes of [screen] in doc order reversed (top row = frontmost).
List<CanvasNode> _rootsFrontmostFirst(ScreenDoc doc, CanvasScreen screen) {
  final nodes = [
    for (final n in doc.nodes)
      if (n.screenId == screen.id && n.parentId == null) n,
  ];
  return nodes.reversed.toList();
}

/// Children of [row] in doc order reversed (top row = frontmost).
List<CanvasNode> _childrenFrontmostFirst(ScreenDoc doc, CanvasNode row) {
  final nodes = [
    for (final n in doc.nodes)
      if (n.parentId == row.id) n,
  ];
  return nodes.reversed.toList();
}

bool _hasNodes(ScreenDoc doc, CanvasScreen screen) =>
    doc.nodes.any((n) => n.screenId == screen.id);

/// Capitalized kind of the node's first item, 'Row' for row containers, or
/// 'empty' when it has none.
String _kindLabel(CanvasNode node) {
  if (node.isRow) return 'Row';
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
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final CanvasNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// Null disables (never hides) the button at the z-order edge: [onMoveUp]
  /// is null on the frontmost row, [onMoveDown] on the backmost.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final radius = BorderRadius.circular(EditorMetrics.segmentInnerRadius);
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
                    color:
                        selected ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: onMoveUp,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: _kActionButtonSize,
                  height: _kActionButtonSize,
                ),
                iconSize: _kActionIconSize,
                color: colors.onSurfaceVariant,
                disabledColor: colors.disabled,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: onMoveDown,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: _kActionButtonSize,
                  height: _kActionButtonSize,
                ),
                iconSize: _kActionIconSize,
                color: colors.onSurfaceVariant,
                disabledColor: colors.disabled,
                icon: const Icon(Icons.arrow_downward),
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
