/// Pan/zoom canvas viewport hosting the screen frames.
///
/// Rebuilds on store changes through [_StoreRelay], which forwards the
/// pure-Dart [CanvasStore] notifications to Flutter's listenable world
/// (the plan's sanctioned `Listenable` adapter under `lib/ui/`).
///
/// The palette lives in the editor shell, not here — this widget owns only the
/// scrollable/zoomable surface, matching the reference's centre column.
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/gestures.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';

/// Forwards pure-Dart store notifications to Flutter listeners.
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

/// Editor surface: drag a palette tile onto a phone frame to add a node.
class DesignCanvas extends StatefulWidget {
  final CanvasStore store;
  final String screenId;

  /// Current viewport scale, driven by the shell's zoom controls.
  final double zoom;

  /// `true` while the pan tool is active, so drags move the viewport instead
  /// of selecting.
  final bool panMode;

  /// Shell-owned selection (single source of truth — the shell also feeds
  /// the layers panel and inspector from it). Never duplicated locally: a
  /// stale local copy is exactly how the canvas ring used to desync from
  /// layers-driven selection.
  final String? selectedNodeId;

  /// Forwarded whenever the selection changes (shell wires it to the inspector).
  final ValueChanged<String?>? onSelectNode;

  const DesignCanvas({
    super.key,
    required this.store,
    this.screenId = 's1',
    this.zoom = 1.0,
    this.panMode = false,
    this.selectedNodeId,
    this.onSelectNode,
  });

  /// Store-level drop handler: adds exactly one node carrying [kind] to the
  /// target screen, seeded with the catalog defaults. Unknown kinds are
  /// accepted — [ScreenSurface] renders them via the catalog fallback instead
  /// of crashing. Returns the node id.
  ///
  /// Pass [screenId] to target a specific screen (per-surface drops do this);
  /// when omitted the drop lands on [this.screenId], preserving the original
  /// single-screen call shape.
  ///
  /// Flow insertion: [kind] `'row'` takes the row path — a container node via
  /// [CanvasStore.addRow] (items are ignored) that always lands root-level.
  /// Any other kind becomes a leaf with one item. [offset] is the pointer
  /// point: it is used for index math (see below) and still stored as the
  /// node's `x`/`y` metadata, which the flow renderer ignores (it lays out by
  /// doc order). Explicit [parentId]/[index] (computed by the surface from
  /// measured geometry) win; otherwise the root index falls back to
  /// pointer-y order (leaves sort after same-screen roots dropped at or above
  /// the pointer) and a row-child index to pointer-x order. A [parentId] that
  /// names no same-screen row container degrades to root so the drop is never
  /// lost. Leaf drops splice in a single commit (one undo step) via
  /// [CanvasStore.replaceDoc]; row drops append then move within the root
  /// group when the pointer asked for an earlier slot.
  String onAccept(
    String kind,
    Offset offset, {
    String? screenId,
    String? parentId,
    int? index,
  }) {
    final targetScreen = screenId ?? this.screenId;
    if (kind == 'row') {
      final id = store.addRow(screenId: targetScreen);
      final roots = [
        for (final n in store.doc.nodes)
          if (n.screenId == targetScreen && n.parentId == null) n,
      ];
      final at = (index ?? _rootIndexForOffset(store.doc, targetScreen, offset))
          .clamp(0, roots.length - 1);
      // addRow appends; move into place only when the pointer asked for an
      // earlier slot (the common below-all-content drop stays one commit).
      if (at != roots.length - 1) store.reorderNode(id, at);
      return id;
    }
    final entry = findEntry(kind);
    final item = CanvasItem(
      id: store.uid(),
      kind: kind,
      props: entry == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.of(entry.defaults),
    );
    final resolvedParent =
        parentId != null && store.doc.nodes.any((n) => n.id == parentId)
            ? parentId
            : null;
    final rowParent = resolvedParent != null &&
        store.doc.nodes.any(
          (n) =>
              n.id == resolvedParent && n.screenId == targetScreen && n.isRow,
        );
    final groupParent = rowParent ? resolvedParent : null;
    final groupLength = _groupLength(store.doc, targetScreen, groupParent);
    final at = (index ??
            (groupParent == null
                ? _rootIndexForOffset(store.doc, targetScreen, offset)
                : _rowIndexForOffset(store.doc, groupParent, offset)))
        .clamp(0, groupLength);
    final node = CanvasNode(
      id: store.uid(),
      screenId: targetScreen,
      x: offset.dx,
      y: offset.dy,
      items: [item],
      parentId: groupParent,
    );
    final doc = store.doc;
    final next = List.of(doc.nodes)
      ..insert(
        _docIndexForGroupIndex(doc, targetScreen, groupParent, at),
        node,
      );
    store.replaceDoc(
      ScreenDoc(
        screens: List.of(doc.screens),
        nodes: next,
        theme: doc.theme,
        meta: doc.meta,
      ),
    );
    return node.id;
  }

  @override
  State<DesignCanvas> createState() => _DesignCanvasState();
}

/// Number of nodes in a flow group: same-screen roots when [parentId] is
/// null, else the row's children.
int _groupLength(ScreenDoc doc, String screenId, String? parentId) {
  var length = 0;
  for (final n in doc.nodes) {
    if (n.screenId == screenId && n.parentId == parentId) length++;
  }
  return length;
}

/// Fallback root index from pointer position (no measured geometry): the
/// count of same-screen root siblings stored at or above the pointer's y, so
/// drops keep pointer-y order. Mirrors the core agent's `migrateToFlow`
/// `(y, x)` ordering for legacy absolute docs.
int _rootIndexForOffset(ScreenDoc doc, String screenId, Offset offset) {
  var at = 0;
  for (final n in doc.nodes) {
    if (n.screenId == screenId && n.parentId == null && n.y <= offset.dy) {
      at++;
    }
  }
  return at;
}

/// Fallback row-child index from pointer position: row children sort after
/// siblings stored at or left of the pointer's x.
int _rowIndexForOffset(ScreenDoc doc, String rowId, Offset offset) {
  var at = 0;
  for (final n in doc.nodes) {
    if (n.parentId == rowId && n.x <= offset.dx) at++;
  }
  return at;
}

/// Flat doc index where group position [at] (already clamped to
/// `0..groupLength`) splices: before the member currently there, or after
/// the last member at the end. Empty groups anchor after the row node itself
/// (row children) or after the screen's last node (roots), else doc end.
int _docIndexForGroupIndex(
  ScreenDoc doc,
  String screenId,
  String? parentId,
  int at,
) {
  final spots = <int>[];
  for (var i = 0; i < doc.nodes.length; i++) {
    final n = doc.nodes[i];
    if (n.screenId == screenId && n.parentId == parentId) spots.add(i);
  }
  if (spots.isEmpty) {
    if (parentId != null) {
      final row = doc.nodes.indexWhere((n) => n.id == parentId);
      if (row >= 0) return row + 1;
    }
    var last = -1;
    for (var i = 0; i < doc.nodes.length; i++) {
      if (doc.nodes[i].screenId == screenId) last = i;
    }
    return last + 1;
  }
  if (at >= spots.length) return spots.last + 1;
  return spots[at];
}

class _DesignCanvasState extends State<DesignCanvas> {
  late final _StoreRelay _relay = _StoreRelay(widget.store);
  Offset _pan = Offset.zero;

  /// Latest global pointer position, tracked so drops can land at the
  /// pointer instead of the drag feedback's top-left corner.
  /// See [ScreenSurface.dropPointer].
  late final ValueNotifier<Offset?> _pointerGlobal =
      ValueNotifier<Offset?>(null);

  void _recordPointer(PointerEvent e) {
    _pointerGlobal.value = e.position;
  }

  @override
  void initState() {
    super.initState();
    // Global route (not a hit-test Listener): raw pointer events reach here
    // even while a Draggable owns the gesture, and in widget tests a
    // hit-test Listener around the canvas observes nothing mid-drag.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_recordPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_recordPointer);
    _pointerGlobal.dispose();
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
        // All screens side by side. No dividers between screens (the
        // reference shares one background across columns). Gap: no screen-gap
        // token exists in EditorMetrics, so a local 48.0 const.
        const screenGap = 48.0;
        final surfaces = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < doc.screens.length; i++) ...[
              if (i > 0) const SizedBox(width: screenGap),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenLabel(name: doc.screens[i].name),
                  const SizedBox(height: 10),
                  ScreenSurface(
                    screen: doc.screens[i],
                    nodes: [
                      for (final n in doc.nodes)
                        if (n.screenId == doc.screens[i].id) n,
                    ],
                    selectedNodeId: widget.selectedNodeId,
                    zoom: widget.zoom,
                    panMode: widget.panMode,
                    onSelectNode: (id) => widget.onSelectNode?.call(id),
                    onDropKind: (kind, position, {parentId, index}) =>
                        widget.onAccept(
                      kind,
                      position,
                      screenId: doc.screens[i].id,
                      parentId: parentId,
                      index: index,
                    ),
                    dropPointer: _pointerGlobal,
                  ),
                ],
              ),
            ],
          ],
        );
        // ZOOM VIA LAYOUT, not paint: `Transform.scale` kept the child's
        // layout box unscaled, so the canvas overflowed its Center and — on
        // release web builds — the painted frame drifted from the hit-test
        // region (clicks on the visible frame missed by ~60-100px, moving
        // with resize history). FittedBox derives paint AND hit-test from
        // the same layout transform, so they can never diverge. The Center
        // now sizes the *scaled* box, which also removes the overflow.
        final contentWidth =
            doc.screens.length * EditorMetrics.phoneOuterWidth +
            math.max(0, doc.screens.length - 1) * screenGap;
        const contentHeight =
            EditorMetrics.screenLabelHeight + 10 + EditorMetrics.phoneOuterHeight;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate:
              widget.panMode ? (d) => setState(() => _pan += d.delta) : null,
          child: MouseRegion(
            cursor: widget.panMode
                ? SystemMouseCursors.grab
                : SystemMouseCursors.basic,
            child: Transform.translate(
              offset: _pan,
              child: Center(
                child: SizedBox(
                  width: contentWidth * widget.zoom,
                  height: contentHeight * widget.zoom,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: contentWidth,
                      height: contentHeight,
                      child: surfaces,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
