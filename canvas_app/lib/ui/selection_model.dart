/// Track S2 shared multi-selection primitives (pure, widget-testable).
///
/// Extracted from `lib/main.dart` (Track D2) so both the editor shell and the
/// multi-aware layers panel can use them without an import cycle (`main`
/// imports `layers_panel`, so layers importing `main` would cycle).
///
/// The shell owns a SET of selected node ids plus a range anchor; screen
/// selection stays a single id mutually exclusive with any node selection.
/// Canvas AND layers taps resolve through [resolveNodeTap] (the caller reads
/// the live modifier keys via `HardwareKeyboard` because tap signatures carry
/// only the node id).
library;

import 'package:canvas_core/canvas_core.dart';

/// Toggles [id] in [current]: removed when present, added when absent.
Set<String> toggleNodeSelection(Set<String> current, String id) {
  final next = Set<String>.of(current);
  if (!next.remove(id)) next.add(id);
  return next;
}

/// Inclusive doc-order range between [anchorId] and [tappedId] when both name
/// nodes in the SAME sibling group (equal `screenId` AND equal `parentId`);
/// empty otherwise (unknown ids, cross-parent, or cross-screen taps fall back
/// to a plain add at the call site).
Set<String> rangeNodeSelection(
  ScreenDoc doc,
  String anchorId,
  String tappedId,
) {
  CanvasNode? anchor;
  CanvasNode? tapped;
  for (final n in doc.nodes) {
    if (n.id == anchorId) anchor = n;
    if (n.id == tappedId) tapped = n;
  }
  if (anchor == null || tapped == null) return const {};
  if (anchor.screenId != tapped.screenId) return const {};
  if (anchor.parentId != tapped.parentId) return const {};
  final group = [
    for (final n in doc.nodes)
      if (n.screenId == anchor.screenId && n.parentId == anchor.parentId)
        n.id,
  ];
  final from = group.indexOf(anchorId);
  final to = group.indexOf(tappedId);
  final lo = from < to ? from : to;
  final hi = from < to ? to : from;
  return group.sublist(lo, hi + 1).toSet();
}

/// Resolved outcome of one node tap: the next selection set plus the
/// next range anchor.
typedef NodeTapSelection = ({Set<String> ids, String? anchor});

/// Resolves a node tap into selection semantics:
///
/// * plain tap (`additive`/`ranged` false, or null [tappedId]) collapses to
///   the single tapped node (null clears);
/// * Ctrl/Cmd-tap ([additive]) toggles the node in the set and moves the
///   anchor onto it when added (removing keeps the old anchor so a follow-up
///   Shift-tap still ranges from a live doc node);
/// * Shift-tap ([ranged]) unions the anchor→tap range (see
///   [rangeNodeSelection]) into the set; a cross-group/unknown-anchor range
///   degrades to a plain add. The anchor moves to the tap in both cases.
///   [additive] wins when both modifiers are held.
NodeTapSelection resolveNodeTap({
  required Set<String> current,
  required String? anchor,
  required ScreenDoc doc,
  required String? tappedId,
  bool additive = false,
  bool ranged = false,
}) {
  if (tappedId == null) return (ids: <String>{}, anchor: null);
  if (additive) {
    final next = Set<String>.of(current);
    var nextAnchor = anchor;
    if (next.contains(tappedId)) {
      next.remove(tappedId);
    } else {
      next.add(tappedId);
      nextAnchor = tappedId;
    }
    return (ids: next, anchor: nextAnchor);
  }
  if (ranged && anchor != null) {
    final range = rangeNodeSelection(doc, anchor, tappedId);
    if (range.isNotEmpty) {
      return (ids: {...current, ...range}, anchor: tappedId);
    }
    return (ids: {...current, tappedId}, anchor: tappedId);
  }
  return (ids: {tappedId}, anchor: tappedId);
}

/// Group availability: ≥2 selected ids that all name existing same-screen
/// ROOT-level (`parentId == null`) nodes. Anything else (singletons, unknown
/// ids, nested nodes, cross-screen sets) disables the action; the
/// store re-validates and throws [StateError] on the same conditions.
bool canGroupNodes(ScreenDoc doc, Set<String> ids) {
  if (ids.length < 2) return false;
  final byId = {for (final n in doc.nodes) n.id: n};
  String? screenId;
  for (final id in ids) {
    final node = byId[id];
    if (node == null || node.parentId != null) return false;
    screenId ??= node.screenId;
    if (node.screenId != screenId) return false;
  }
  return true;
}

/// Ungroup target: the row id when [ids] names exactly one existing row node,
/// else null (empty/multi/non-row/unknown selections disable the action).
String? ungroupTargetRow(ScreenDoc doc, Set<String> ids) {
  if (ids.length != 1) return null;
  for (final n in doc.nodes) {
    if (n.id == ids.single) return n.isRow ? n.id : null;
  }
  return null;
}

/// Rebuilds [node] with a new [parentId], preserving every other field with
/// the store's deep-copy precedent (`hiddenOn`/`breakpointValues`/`slots`
/// copied, never aliased; `items` rides along untouched).
CanvasNode _withParentId(CanvasNode node, String? parentId) => CanvasNode(
      id: node.id,
      screenId: node.screenId,
      x: node.x,
      y: node.y,
      items: node.items,
      parentId: parentId,
      isRow: node.isRow,
      gap: node.gap,
      mainAxis: node.mainAxis,
      crossAxis: node.crossAxis,
      expand: node.expand,
      flex: node.flex,
      hiddenOn: Set<String>.from(node.hiddenOn),
      breakpointValues: {
        for (final entry in node.breakpointValues.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      },
      slots: Map<String, String>.from(node.slots),
    );

/// Pure ungroup: lifts [rowId]'s DIRECT children to the screen root in doc
/// order (deeper descendants keep their parent edges under the moved
/// children) and removes the row, which takes its doc slot. Throws
/// [StateError] on unknown [rowId] or a non-row node. The caller commits via
/// `CanvasStore.replaceDoc` in one step, so ungroup is a single atomic undo
/// unit with no store API change.
ScreenDoc ungroupRowDoc(ScreenDoc doc, String rowId) {
  final index = doc.nodes.indexWhere((n) => n.id == rowId);
  if (index < 0) throw StateError('Unknown node: $rowId');
  if (!doc.nodes[index].isRow) throw StateError('Not a row: $rowId');
  final kids = [
    for (final n in doc.nodes)
      if (n.parentId == rowId) n,
  ];
  final kidIds = {for (final k in kids) k.id};
  return ScreenDoc(
    screens: List.of(doc.screens),
    nodes: [
      for (final n in doc.nodes)
        if (n.id == rowId)
          for (final k in kids) _withParentId(k, null)
        else if (!kidIds.contains(n.id))
          n,
    ],
    theme: doc.theme,
    meta: doc.meta,
  );
}
