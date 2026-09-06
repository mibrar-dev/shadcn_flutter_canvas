/// Z-order Layers panel replacing the icon rail's `<id> panel` placeholder.
///
/// Groups one row per node under its screen header (HANDOFF P1-4). Doc order
/// is reversed within a group so the top row is the frontmost node. Any node
/// with children renders as a header with its subtree nested beneath
/// (frontmost-first within each group, one indent level per depth); headers
/// carry an expand/collapse toggle, and every row stays selectable for gap
/// editing. All rows carry bring-forward/send-backward controls wired to
/// [CanvasStore.reorderNode] within their own visual group, and screen
/// headers carry a rename affordance wired to [CanvasStore.renameScreen].
///
/// Track S2 multi-select: the panel receives the full selection set
/// ([LayersPanel.selectedNodeIds]) plus the primary id
/// ([LayersPanel.selectedNodeId]) for compat. Plain row taps collapse via
/// [LayersPanel.onSelectNode]; Ctrl/Cmd-taps toggle via
/// [LayersPanel.onToggleNode] and Shift-taps range via
/// [LayersPanel.onRangeSelectNode] (the panel reads the live modifiers via
/// `HardwareKeyboard`, mirroring the shell's canvas tap path; when the
/// toggle/range callbacks are null — e.g. legacy single-select hosts — every
/// tap collapses). Selected rows highlight with [EditorColors.toolbarActive]:
/// the primary gets a ring plus a stronger tint, the rest of the set a
/// lighter secondary tint. A count header ("N selected") with a Shift-range
/// hint plus delete-set/group/ungroup actions sits above the screens while
/// anything is selected.
///
/// Track DD: every row carries a lock toggle (`store.setNodeLocked`; locked
/// rows show the filled lock glyph) and hosts render their named-slot chips
/// directly underneath (read-only `slot → child` labels — tap selects the
/// child, dangling refs show `missing`). The header delete-set skips locked
/// ids (they survive; see [_LayersBodyState._onDeletePressed]).
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/selection_model.dart';
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
    this.selectedNodeId,
    this.selectedNodeIds = const {},
    required this.onSelectNode,
    this.onToggleNode,
    this.onRangeSelectNode,
    this.onGroupSelection,
    this.onUngroupSelection,
    this.onDeleteSelection,
  });

  final CanvasStore store;

  /// Primary selection (compat): the ring highlight and the collapse target.
  /// The shell passes its `_primaryNodeId()` here.
  final String? selectedNodeId;

  /// Full multi-selection set. When empty and [selectedNodeId] names a node,
  /// the panel treats that single id as the selection, so legacy
  /// single-select hosts keep working unchanged.
  final Set<String> selectedNodeIds;

  /// Plain row tap (collapse to the tapped id) and selection clears (null).
  final ValueChanged<String?> onSelectNode;

  /// Ctrl/Cmd-tap toggle. Null falls back to [onSelectNode] (plain collapse).
  final ValueChanged<String>? onToggleNode;

  /// Shift-tap range. Null falls back to [onSelectNode] (plain collapse).
  final ValueChanged<String>? onRangeSelectNode;

  /// Header "Group selection" action. Null falls back to a direct
  /// `store.groupIntoRow` + select-the-row (with a SnackBar on refusal);
  /// the button disables unless [canGroupNodes] holds.
  final VoidCallback? onGroupSelection;

  /// Header "Ungroup" action. Null disables the button (the released-children
  /// selection cannot round-trip through the single-id [onSelectNode]).
  final VoidCallback? onUngroupSelection;

/// Header "Delete selection" action. Null falls back to one
/// `store.deleteNode` per selected id plus [onSelectNode] `(null)`.
/// Track DD: the fallback skips locked ids (they survive; the selection
/// collapses onto the first skipped lock, or clears when nothing was
/// skipped).
  final VoidCallback? onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    // Stateless contract: the stateful body owns the relay (and disposes it)
    // so this widget never leaks a listener across rebuilds.
    return _LayersBody(
      store: store,
      selectedNodeId: selectedNodeId,
      selectedNodeIds: selectedNodeIds,
      onSelectNode: onSelectNode,
      onToggleNode: onToggleNode,
      onRangeSelectNode: onRangeSelectNode,
      onGroupSelection: onGroupSelection,
      onUngroupSelection: onUngroupSelection,
      onDeleteSelection: onDeleteSelection,
    );
  }
}

class _LayersBody extends StatefulWidget {
  const _LayersBody({
    required this.store,
    required this.selectedNodeId,
    required this.selectedNodeIds,
    required this.onSelectNode,
    required this.onToggleNode,
    required this.onRangeSelectNode,
    required this.onGroupSelection,
    required this.onUngroupSelection,
    required this.onDeleteSelection,
  });

  final CanvasStore store;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;
  final ValueChanged<String?> onSelectNode;
  final ValueChanged<String>? onToggleNode;
  final ValueChanged<String>? onRangeSelectNode;
  final VoidCallback? onGroupSelection;
  final VoidCallback? onUngroupSelection;
  final VoidCallback? onDeleteSelection;

  @override
  State<_LayersBody> createState() => _LayersBodyState();
}

class _LayersBodyState extends State<_LayersBody> {
  late final _StoreRelay _relay = _StoreRelay(widget.store);

  /// Ids whose subtree renders collapsed (header only). Default expanded, so
  /// the full tree shows without interaction.
  final Set<String> _collapsed = {};

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
        final selected = _effectiveSelection();
        final primary = _primaryId(doc, selected);
        return ListView(
          padding: const EdgeInsets.all(EditorMetrics.panelInset),
          children: [
            if (selected.isNotEmpty)
              _selectionHeader(context, doc, selected),
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
                  _LayerAction(
                    tooltip: 'Rename screen',
                    icon: Icons.edit,
                    onPressed: () => _renameScreen(context, screen),
                  ),
                  _LayerAction(
                    tooltip: 'Delete screen',
                    icon: Icons.delete_outline,
                    onPressed: () => _deleteScreen(context, screen),
                  ),
                ],
              ),
              const SizedBox(height: EditorMetrics.tileGap),
              Builder(
                builder: (_) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _treeRows(
                      doc,
                      screen,
                      null,
                      0,
                      const {},
                      selected,
                      primary,
                    ),
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

  /// Effective selection: the multi-aware set when non-empty, else the
  /// legacy single [LayersPanel.selectedNodeId] as a singleton (so
  /// single-select hosts keep working unchanged).
  Set<String> _effectiveSelection() {
    if (widget.selectedNodeIds.isNotEmpty) return widget.selectedNodeIds;
    final primary = widget.selectedNodeId;
    return primary == null ? const {} : {primary};
  }

  /// Primary id for the ring highlight: the compat [LayersPanel.selectedNodeId]
  /// while it names a selected live node, else the first selected id in doc
  /// order (mirroring the shell's `_primaryNodeId`), else null. Stale ids
  /// (e.g. after an undo) resolve to null rather than a dangling highlight.
  String? _primaryId(ScreenDoc doc, Set<String> selected) {
    if (selected.isEmpty) return null;
    final primary = widget.selectedNodeId;
    if (primary != null && selected.contains(primary)) return primary;
    for (final n in doc.nodes) {
      if (selected.contains(n.id)) return n.id;
    }
    return null;
  }

  /// Row tap with live modifiers (mirrors the shell's canvas tap path):
  /// Ctrl/Cmd-tap toggles, Shift-tap ranges, plain tap collapses. [additive]
  /// wins when both are held. A missing toggle/range callback falls back to a
  /// plain collapse so legacy single-select hosts keep working.
  void _onRowTap(String id) {
    final keys = HardwareKeyboard.instance;
    final additive = keys.isControlPressed || keys.isMetaPressed;
    final ranged = keys.isShiftPressed;
    if (additive && widget.onToggleNode != null) {
      widget.onToggleNode!(id);
    } else if (ranged && widget.onRangeSelectNode != null) {
      widget.onRangeSelectNode!(id);
    } else {
      widget.onSelectNode(id);
    }
  }

  /// Count header plus the multi-action row, shown while anything is
  /// selected: "N selected" with delete-set/group/ungroup actions and the
  /// Shift-range hint. Group enables exactly when [canGroupNodes] holds;
  /// ungroup exactly when [ungroupTargetRow] resolves (and its callback is
  /// wired); delete-set is always enabled.
  Widget _selectionHeader(
    BuildContext context,
    ScreenDoc doc,
    Set<String> selected,
  ) {
    final colors = EditorTheme.of(context);
    final canGroup = canGroupNodes(doc, selected);
    final canUngroup =
        ungroupTargetRow(doc, selected) != null &&
            widget.onUngroupSelection != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${selected.length} selected',
                style: EditorType.sectionHeader
                    .copyWith(color: colors.onSurface),
              ),
            ),
            _LayerAction(
              tooltip: 'Group selection',
              icon: Icons.group_work,
              onPressed: canGroup ? () => _onGroupPressed(context) : null,
            ),
            _LayerAction(
              tooltip: 'Ungroup',
              icon: Icons.call_split,
              onPressed:
                  canUngroup ? widget.onUngroupSelection : null,
            ),
            _LayerAction(
              tooltip: 'Delete selection',
              icon: Icons.delete_sweep,
              onPressed: _onDeletePressed,
            ),
          ],
        ),
        Text(
          'Tip: Ctrl/Cmd+click toggles, Shift+click selects a range',
          style: EditorType.tileLabel
              .copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: EditorMetrics.tileGap),
      ],
    );
  }

  /// Header delete-set: the wired callback when present (the shell deletes
  /// the whole set and clears), else one [CanvasStore.deleteNode] per id plus
  /// a clear (cascade covers parent+child pairs, unknown ids no-op).
  ///
  /// Track DD: locked ids are skipped (the store would no-op them anyway) —
  /// they survive and the selection collapses onto the first survivor so the
  /// skip stays visible; the selection clears only when nothing was skipped.
  void _onDeletePressed() {
    final callback = widget.onDeleteSelection;
    if (callback != null) {
      callback();
      return;
    }
    final byId = {for (final n in widget.store.doc.nodes) n.id: n};
    final skippedLocked = <String>[];
    for (final id in _effectiveSelection().toList()) {
      final node = byId[id];
      if (node != null && node.locked) {
        skippedLocked.add(id);
        continue;
      }
      widget.store.deleteNode(id);
    }
    widget.onSelectNode(skippedLocked.isEmpty ? null : skippedLocked.first);
  }

  /// Header group: the wired callback when present (the shell groups and
  /// selects the row), else a direct [CanvasStore.groupIntoRow] plus
  /// select-the-row, with a SnackBar on refusal like the shell.
  void _onGroupPressed(BuildContext context) {
    final callback = widget.onGroupSelection;
    if (callback != null) {
      callback();
      return;
    }
    try {
      final rowId =
          widget.store.groupIntoRow(_effectiveSelection().toList());
      widget.onSelectNode(rowId);
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot group: ${e.message}')),
      );
    }
  }

  /// Nested layer rows for one sibling group ([parentId], null = the
  /// screen's roots) at indent [depth]: frontmost-first within the group,
  /// each header followed by its own subtree. [ancestors] holds the ids on
  /// the current path (cycle-safe: corrupt self-parent/cycle edges terminate
  /// instead of recursing forever). Collapsed subtrees (see [_collapsed])
  /// render the header only. Reorder buttons still move within the node's
  /// own visual group via [CanvasStore.reorderNode]; delete cascades through
  /// [CanvasStore.deleteNode] at any depth (reparent-safe: descendants go
  /// with the deleted node, never orphaned). [selected]/[primary] drive the
  /// multi-highlight (secondary tint vs primary ring).
  List<Widget> _treeRows(
    ScreenDoc doc,
    CanvasScreen screen,
    String? parentId,
    int depth,
    Set<String> ancestors,
    Set<String> selected,
    String? primary,
  ) {
    final group = _groupFrontmostFirst(doc, screen, parentId);
    return [
      for (var index = 0; index < group.length; index++)
        ..._subtreeRows(
          doc,
          screen,
          group[index],
          group.length,
          index,
          depth,
          ancestors,
          selected,
          primary,
        ),
    ];
  }

  /// One header row plus its (unless collapsed) nested subtree. Children are
  /// the node's own sibling group frontmost-first, minus self/ancestor ids
  /// so corrupt edges never loop.
  List<Widget> _subtreeRows(
    ScreenDoc doc,
    CanvasScreen screen,
    CanvasNode node,
    int groupLength,
    int visualIndex,
    int depth,
    Set<String> ancestors,
    Set<String> selected,
    String? primary,
  ) {
    final kids = [
      for (final k in _groupFrontmostFirst(doc, screen, node.id))
        if (k.id != node.id && !ancestors.contains(k.id)) k,
    ];
    final next = {...ancestors, node.id};
    return [
      _layerRow(
        node,
        groupLength,
        visualIndex,
        depth: depth,
        hasChildren: kids.isNotEmpty,
        selected: selected,
        primary: primary,
      ),
      // Track DD: named-slot chips sit directly under their host (read-only
      // labels — tap selects the child; dangling refs show `missing`).
      ..._slotChips(doc, node, depth),
      if (!_collapsed.contains(node.id))
        for (var ci = 0; ci < kids.length; ci++)
          ..._subtreeRows(
            doc,
            screen,
            kids[ci],
            kids.length,
            ci,
            depth + 1,
            next,
            selected,
            primary,
          ),
    ];
  }

  /// Track DD slot chips for [node]: one read-only row per `slotNodes`
  /// entry (slot-name sorted, indented one level under the host). Live
  /// children tap-select (modifier-aware, like rows); dangling refs render
  /// a `missing` label with no tap target. Chips are shortcuts, not tree
  /// rows — the child keeps its own tree position.
  List<Widget> _slotChips(ScreenDoc doc, CanvasNode node, int depth) {
    if (node.slotNodes.isEmpty) return const [];
    final byId = {for (final n in doc.nodes) n.id: n};
    final names = node.slotNodes.keys.toList()..sort();
    return [
      for (final slot in names)
        _slotChip(node, slot, byId[node.slotNodes[slot]], depth),
    ];
  }

  /// One slot chip (see [_slotChips]).
  Widget _slotChip(
    CanvasNode host,
    String slot,
    CanvasNode? child,
    int depth,
  ) {
    final colors = EditorTheme.of(context);
    final label = child == null
        ? '$slot → missing'
        : '$slot → ${_kindLabel(child)} · ${child.id}';
    final row = Row(
      children: [
        const SizedBox(width: _kActionButtonSize),
        Icon(
          Icons.link,
          size: _kActionIconSize,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: EditorMetrics.tileGap),
        Expanded(
          child: Text(
            label,
            key: ValueKey('slot-chip-${host.id}-$slot'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EditorType.tileLabel.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    final padded = Padding(
      padding: EdgeInsets.only(left: (depth + 1) * EditorMetrics.panelInset),
      child: row,
    );
    if (child == null) return padded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onRowTap(child.id),
      child: padded,
    );
  }

  /// One layer row wired to the store: tap selects (rows select for gap
  /// editing) with multi-aware modifiers (see [_onRowTap]), duplicate/delete
  /// act, and the reorder buttons move within the node's visual group
  /// ([groupLength]/[visualIndex] in frontmost-first display order) by
  /// passing the group-relative doc index. [depth] indents the row one level
  /// per nesting depth; [hasChildren] shows the expand/collapse toggle
  /// (collapsed hides the subtree via [_collapsed]).
  ///
  /// Track DD: rows carry a lock toggle writing through the undoable
  /// `store.setNodeLocked` (locked rows show the filled lock glyph).
  Widget _layerRow(
    CanvasNode node,
    int groupLength,
    int visualIndex, {
    required int depth,
    required bool hasChildren,
    required Set<String> selected,
    required String? primary,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: depth * EditorMetrics.panelInset),
      child: _LayerRow(
        node: node,
        selected: selected.contains(node.id),
        primary: node.id == primary,
        locked: node.locked,
        onTap: () => _onRowTap(node.id),
        onToggleLock: () =>
            widget.store.setNodeLocked(node.id, !node.locked),
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
        hasChildren: hasChildren,
        expanded: !_collapsed.contains(node.id),
        onToggleExpanded: hasChildren
            ? () => setState(() {
                  if (!_collapsed.remove(node.id)) {
                    _collapsed.add(node.id);
                  }
                })
            : null,
      ),
    );
  }

  /// Deletes a screen via [CanvasStore.deleteScreen]. A refusal (dangling
  /// actions would be left behind) keeps the screen and surfaces the
  /// blockers in a SnackBar; on success any selection id that no longer
  /// names a live node is cleared (multi-aware: the whole set collapses).
  void _deleteScreen(BuildContext context, CanvasScreen screen) {
    final dangling = widget.store.deleteScreen(screen.id);
    if (dangling.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete ${screen.name}: ${dangling.join('; ')}',
          ),
        ),
      );
      return;
    }
    final remaining = {for (final n in widget.store.doc.nodes) n.id};
    if (_effectiveSelection().any((id) => !remaining.contains(id))) {
      widget.onSelectNode(null);
    }
  }

  /// Opens the screen-rename dialog (prefilled; empty Save is a no-op close).
  void _renameScreen(BuildContext context, CanvasScreen screen) {
    final controller = TextEditingController(text: screen.name);
    shadcn.showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = EditorTheme.of(dialogContext);
        void save() {
          final name = controller.text;
          Navigator.of(dialogContext).pop();
          if (name.trim().isEmpty) return;
          widget.store.renameScreen(screen.id, name);
        }

        return shadcn.AlertDialog(
          title: Text(
            'Rename screen',
            style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
          ),
          content: shadcn.TextField(
            controller: controller,
            autofocus: true,
            style: EditorType.field.copyWith(color: colors.onSurface),
            onSubmitted: (_) => save(),
          ),
          actions: [
            shadcn.TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            shadcn.TextButton(
              onPressed: save,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

/// Siblings sharing [parentId] on [screen] in doc order reversed (top row =
/// frontmost). Null [parentId] selects the screen roots. Any node may parent
/// (COMPOSITION.md §1), so children are no longer a row-only concept — the
/// same helper serves every depth.
List<CanvasNode> _groupFrontmostFirst(
  ScreenDoc doc,
  CanvasScreen screen,
  String? parentId,
) {
  final nodes = [
    for (final n in doc.nodes)
      if (n.screenId == screen.id && n.parentId == parentId) n,
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

/// One 28x28 layer action (rename/delete/move/duplicate) with a kit tip.
///
/// The metric box and glyph size mirror the old material `IconButton`
/// (tight 28x28, 16px glyph); the tap surface is the kit ghost icon button.
/// A null [onPressed] renders the glyph in [EditorColors.disabled] and
/// disables taps, matching the old `disabledColor` behavior at the z-order
/// edges ([onMoveUp] null on the frontmost row, [onMoveDown] on the backmost).
class _LayerAction extends StatelessWidget {
  const _LayerAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final enabled = onPressed != null;
    return shadcn.Tooltip(
      tooltip: (context) =>
          shadcn.TooltipContainer(child: Text(tooltip)),
      child: SizedBox(
        width: _kActionButtonSize,
        height: _kActionButtonSize,
        child: shadcn.IconButton.ghost(
          icon: Icon(
            icon,
            size: _kActionIconSize,
            color: enabled ? colors.onSurfaceVariant : colors.disabled,
          ),
          onPressed: onPressed,
          size: shadcn.ButtonSize.small,
          density: shadcn.ButtonDensity.compact,
        ),
      ),
    );
  }
}

class _LayerRow extends StatefulWidget {
  const _LayerRow({
    required this.node,
    required this.selected,
    required this.primary,
    required this.locked,
    required this.onTap,
    required this.onToggleLock,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    this.hasChildren = false,
    this.expanded = true,
    this.onToggleExpanded,
  });

  final CanvasNode node;

  /// In the selection set (primary or secondary).
  final bool selected;

  /// The primary selection: ring plus stronger tint. Secondary selections
  /// ([selected] without [primary]) get the lighter tint only. Both use the
  /// [EditorColors.toolbarActive] token.
  final bool primary;

  /// Track DD: editor lock — locked rows show the filled lock glyph and the
  /// toggle flips it via [onToggleLock].
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onToggleLock;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// Null disables (never hides) the button at the z-order edge: [onMoveUp]
  /// is null on the frontmost row, [onMoveDown] on the backmost.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  /// Whether the node owns a visible subtree (shows the expand/collapse
  /// toggle); [expanded] is its current state, flipped via
  /// [onToggleExpanded].
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final radius = BorderRadius.circular(EditorMetrics.segmentInnerRadius);
    // Primary ring + stronger tint; secondary tint; hover; plain.
    final background = widget.primary
        ? colors.toolbarActive.withValues(alpha: 0.35)
        : widget.selected
            ? colors.toolbarActive.withValues(alpha: 0.15)
            : (_hovered ? colors.surfaceContainerHigh : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: widget.primary
                ? Border.all(color: colors.toolbarActive, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: EditorMetrics.panelInset,
          ),
          child: Row(
            children: [
              if (widget.hasChildren)
                _LayerAction(
                  tooltip: widget.expanded ? 'Collapse' : 'Expand',
                  icon: widget.expanded
                      ? Icons.expand_more
                      : Icons.chevron_right,
                  onPressed: widget.onToggleExpanded,
                )
              else
                const SizedBox(
                  width: _kActionButtonSize,
                  height: _kActionButtonSize,
                ),
              Expanded(
                child: Text(
                  '${_kindLabel(widget.node)} · ${widget.node.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EditorType.tileLabel.copyWith(
                    color: widget.selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              _LayerAction(
                tooltip: 'Move up',
                icon: Icons.arrow_upward,
                onPressed: widget.onMoveUp,
              ),
              _LayerAction(
                tooltip: 'Move down',
                icon: Icons.arrow_downward,
                onPressed: widget.onMoveDown,
              ),
              _LayerAction(
                key: ValueKey('layer-lock-${widget.node.id}'),
                tooltip: widget.locked ? 'Unlock' : 'Lock',
                icon: widget.locked ? Icons.lock : Icons.lock_outline,
                onPressed: widget.onToggleLock,
              ),
              _LayerAction(
                tooltip: 'Duplicate',
                icon: Icons.copy,
                onPressed: widget.onDuplicate,
              ),
              _LayerAction(
                tooltip: 'Delete',
                icon: Icons.delete_outline,
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
