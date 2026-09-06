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
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';

/// Zoom bounds shared by the shell's [ZoomControls] and the wheel/pinch
/// path below (the controls disable at exactly these ends).
const double kCanvasMinZoom = 0.25;
const double kCanvasMaxZoom = 4.0;

/// Exponential gain for Ctrl/Cmd+wheel zoom (trackpad pinch on desktop
/// arrives as Ctrl+wheel): one 100px wheel notch scales by ~e^0.2.
const double kWheelZoomGain = 0.002;

/// Clamps [zoom] into the supported viewport range.
double clampZoom(double zoom) =>
    zoom.clamp(kCanvasMinZoom, kCanvasMaxZoom).toDouble();

/// Viewport pan for a wheel event: plain wheel pans vertically, Shift+wheel
/// pans horizontally (both native components feed the horizontal axis so
/// platform differences in Shift+wheel reporting don't matter).
Offset applyWheelPan(Offset pan, Offset scrollDelta, {required bool shift}) {
  if (shift) {
    return Offset(pan.dx - scrollDelta.dx - scrollDelta.dy, pan.dy);
  }
  return Offset(pan.dx, pan.dy - scrollDelta.dy);
}

/// Viewport pan for a middle-button drag: the content follows the pointer.
Offset applyMiddlePan(Offset pan, Offset delta) => pan + delta;

/// Multiplicative zoom factor for a Ctrl/Cmd+wheel delta: scrolling up
/// (negative dy) zooms in, scrolling down zooms out.
double wheelZoomFactor(double scrollDeltaY) =>
    math.exp(-scrollDeltaY * kWheelZoomGain);

/// Cursor-anchored zoom: scales [zoom] by [factor] (clamped) and shifts [pan]
/// so the content point under [cursor] stays fixed.
///
/// [viewport] is the viewport size and [contentSize] the unscaled content
/// size; the content origin follows the build's `Center` layout
/// (`(viewport - scaled) / 2 + pan`). Pure so it unit-tests without pointer
/// simulation.
({Offset pan, double zoom}) zoomAtCursor({
  required double zoom,
  required Offset pan,
  required Offset cursor,
  required Size viewport,
  required Size contentSize,
  required double factor,
}) {
  final next = clampZoom(zoom * factor);
  Offset origin(double z) => Offset(
        (viewport.width - contentSize.width * z) / 2,
        (viewport.height - contentSize.height * z) / 2,
      );
  final contentPoint = (cursor - origin(zoom) - pan) / zoom;
  return (pan: cursor - origin(next) - contentPoint * next, zoom: next);
}

/// Outer frame width of [screen]: device stage width plus the bezel.
double screenOuterWidth(CanvasScreen screen) =>
    specForScreenDevice(screen.device).width + EditorMetrics.phoneBezel * 2;

/// First-run hint pill (Track Y4, FORGE.md §1-3c, §3).
///
/// Dark pill, radius full, padding APPROXIMATE 8×16px, with a × dismiss
/// button. The copy is the reference text verbatim. Visibility state lives in
/// [_DesignCanvasState] (no persistence — the pill reappears on restart, per
/// spec); this widget only owns the pill chrome.
class ForgeHintPill extends StatelessWidget {
  /// Dismiss tap (×). Null hides the × button.
  final VoidCallback? onDismiss;

  const ForgeHintPill({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    // Dark pill with light text: [onSurface]/[surface] invert per mode (the
    // same idiom as the Forge topbar's dark pills), so the hint stays
    // legible under both chrome modes.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Drop widgets… · click a block… · drag the corner…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)
                  .copyWith(color: colors.surface),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: colors.surface),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

  /// Shell-owned screen selection (mutually exclusive with the node
  /// selection — the shell clears one when the other is set).
  final String? selectedScreenId;

  /// Forwarded when empty screen area (or a screen label) is tapped.
  final ValueChanged<String?>? onSelectScreen;

  /// Zoom requests from the wheel/pinch path. The shell's `_setZoom` stays
  /// the source of truth (same clamps as [ZoomControls]); the canvas only
  /// adjusts its pan around the requested zoom.
  final ValueChanged<double>? onZoomChanged;

  /// Whether snap guides (alignment guides + magnetic snap) are on. Shell-
  /// owned, toggled by the header's grid icon; defaults on.
  ///
  /// Y4 CONTRACT NOTE (FORGE.md §1-3b deviation): the flag is accepted,
  /// stored, and exposed here, but the guide visuals + snap live in
  /// [ScreenSurface] (`phone_frame.dart`, island-only for Y4), so enforcement
  /// is a follow-up: add `showGuides` (default true) to [ScreenSurface] and
  /// gate its `guidesForPointer`/`snapDropPosition` calls plus the guide
  /// overlays on it. Until then the toggle flips state without suppressing
  /// guides; zoom math, pan, and drop accuracy are untouched.
  final bool showGuides;

  const DesignCanvas({
    super.key,
    required this.store,
    this.screenId = 's1',
    this.zoom = 1.0,
    this.panMode = false,
    this.selectedNodeId,
    this.onSelectNode,
    this.selectedScreenId,
    this.onSelectScreen,
    this.onZoomChanged,
    this.showGuides = true,
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
  /// Drop-offset → parent/index mapping (Track C2 nesting — COMPOSITION.md
  /// §1/§4): the surface resolves the pointer to the deepest container-or-row
  /// under it (measured rects, smallest-area tiebreak) and forwards that as
  /// [parentId] plus an [index] within the target's child group. [offset] is
  /// the pointer point: it is used for index math (see below) and still
  /// stored as the node's `x`/`y` metadata, which the flow renderer ignores
  /// (it lays out by doc order). Explicit [parentId]/[index] (computed by the
  /// surface from measured geometry) win; otherwise the index falls back to
  /// pointer order along the target's axis — pointer-y for the screen root
  /// and for container (vertical-stack) parents, pointer-x for row
  /// (horizontal) parents. A [parentId] that names no SAME-SCREEN node
  /// (unknown id or cross-screen) degrades to root so the drop is never lost.
  /// Leaf drops splice in a single commit (one undo step) via
  /// [CanvasStore.replaceDoc]; row drops append then move within their group
  /// when the pointer asked for a non-final slot.
  ///
  /// Flow insertion: [kind] `'row'` takes the row path — a container node via
  /// [CanvasStore.addRow] (items are ignored). Without an explicit same-screen
  /// [parentId] it lands root-level (today's behavior); with one it nests
  /// under that parent (row-in-card) via [CanvasStore.reparentNode]. Any
  /// other kind becomes a leaf with one item parented to [parentId] (row,
  /// container, or — via the model, though the surface never targets one —
  /// leaf, whose children render with the below-fallback).
  ///
  /// FF1 drop-into-slot: a leaf drop onto a host with an EMPTY compatible
  /// slot fills it ([dropSlotForNewChild]: `body` for scaffolds, `content`
  /// for single-content hosts, first-empty otherwise) instead of plain
  /// parenting; an occupied slot, a locked host, or a `row` drop keeps the
  /// plain-parent path above. The slot edge is written into the SAME
  /// [CanvasStore.replaceDoc] commit as the new node, so one undo step
  /// removes both. Slot validation mirrors [CanvasStore.setSlotChild] but
  /// never throws mid-drag: the rule only yields known slots on unlocked
  /// same-screen hosts for a fresh (cycle-impossible) child, and any residual
  /// failure falls back to plain parenting.
  String onAccept(
    String kind,
    Offset offset, {
    String? screenId,
    String? parentId,
    int? index,
  }) {
    final targetScreen = screenId ?? this.screenId;
    // Any same-screen node may parent (COMPOSITION.md §1 — layout follows
    // the parent's kind); anything else degrades to root, never a throw.
    String? resolvedParent;
    if (parentId != null) {
      for (final n in store.doc.nodes) {
        if (n.id == parentId && n.screenId == targetScreen) {
          resolvedParent = parentId;
          break;
        }
      }
    }
    if (kind == 'row') {
      final id = store.addRow(screenId: targetScreen);
      String? groupParent;
      if (resolvedParent != null) {
        // addRow always appends root-level; nest when asked (never self —
        // the id is fresh, so no cycle is possible here).
        store.reparentNode(id, resolvedParent);
        groupParent = resolvedParent;
      }
      final groupLength = _groupLength(store.doc, targetScreen, groupParent);
      // Fallback index along the group's axis: pointer-y for the root and
      // for vertical (container) parents, pointer-x for horizontal (row)
      // parents.
      final int fallback;
      if (groupParent == null) {
        fallback = _rootIndexForOffset(store.doc, targetScreen, offset);
      } else if (_parentIsRow(store.doc, groupParent)) {
        fallback = _rowIndexForOffset(store.doc, groupParent, offset);
      } else {
        fallback = _containerIndexForOffset(store.doc, groupParent, offset);
      }
      final at = (index ?? fallback).clamp(0, groupLength - 1);
      // addRow appends; move into place only when the pointer asked for a
      // non-final slot (the common below-all-content drop stays at two
      // commits: add + nest, or one when root-final).
      if (at != groupLength - 1) store.reorderNode(id, at);
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
    final groupParent = resolvedParent;
    final groupLength = _groupLength(store.doc, targetScreen, groupParent);
    // Fallback index along the group's axis (see the row path above):
    // pointer-y for the root and for vertical (container/leaf) parents,
    // pointer-x for horizontal (row) parents.
    final int fallback;
    if (groupParent == null) {
      fallback = _rootIndexForOffset(store.doc, targetScreen, offset);
    } else if (_parentIsRow(store.doc, groupParent)) {
      fallback = _rowIndexForOffset(store.doc, groupParent, offset);
    } else {
      fallback = _containerIndexForOffset(store.doc, groupParent, offset);
    }
    final at = (index ?? fallback).clamp(0, groupLength);
    final doc = store.doc;
    final node = CanvasNode(
      id: store.uid(),
      screenId: targetScreen,
      x: offset.dx,
      y: offset.dy,
      items: [item],
      parentId: groupParent,
    );
    // FF1 drop-into-slot (see the method docs): resolve the empty-slot
    // assignment BEFORE the commit; rows never slot (structural strip).
    String? slot;
    if (groupParent != null) {
      try {
        slot = dropSlotForNewChild(doc.nodes, groupParent);
      } catch (_) {
        slot = null;
      }
    }
    final next = List.of(doc.nodes)
      ..insert(
        _docIndexForGroupIndex(doc, targetScreen, groupParent, at),
        node,
      );
    if (slot != null) {
      // Same-commit slot edge (atomic undo): rebuild the host with the new
      // entry. Infallible by construction (known slot, same-screen unlocked
      // host, fresh child), but never throws mid-drag — a failure keeps the
      // plain parenting above.
      try {
        final hostIndex = next.indexWhere((n) => n.id == groupParent);
        if (hostIndex >= 0) {
          final host = next[hostIndex];
          if (!host.locked && !host.slotNodes.containsKey(slot)) {
            next[hostIndex] = CanvasNode(
              id: host.id,
              screenId: host.screenId,
              x: host.x,
              y: host.y,
              items: host.items,
              parentId: host.parentId,
              isRow: host.isRow,
              gap: host.gap,
              mainAxis: host.mainAxis,
              crossAxis: host.crossAxis,
              expand: host.expand,
              flex: host.flex,
              w: host.w,
              h: host.h,
              hiddenOn: Set<String>.from(host.hiddenOn),
              breakpointValues: {
                for (final entry in host.breakpointValues.entries)
                  entry.key: Map<String, dynamic>.from(entry.value),
              },
              slots: Map<String, String>.from(host.slots),
              slotNodes: Map<String, String>.from(host.slotNodes)
                ..[slot] = node.id,
              locked: host.locked,
            );
          }
        }
      } catch (_) {
        // Plain parenting stands.
      }
    }
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

/// Whether [parentId] names a horizontal (row) parent: rows lay children out
/// left-to-right, every other parent stacks vertically.
bool _parentIsRow(ScreenDoc doc, String parentId) {
  for (final n in doc.nodes) {
    if (n.id == parentId) return n.isRow;
  }
  return false;
}

/// Fallback container-child index from pointer position: container children
/// stack vertically (COMPOSITION.md §1), so they sort after siblings stored
/// at or above the pointer's y — the child-group analogue of
/// [_rootIndexForOffset].
int _containerIndexForOffset(ScreenDoc doc, String parentId, Offset offset) {
  var at = 0;
  for (final n in doc.nodes) {
    if (n.parentId == parentId && n.y <= offset.dy) at++;
  }
  return at;
}

/// Flat doc index where group position [at] (already clamped to
/// `0..groupLength`) splices: before the member currently there, or after
/// the last member at the end. Empty groups anchor after the parent node
/// itself (child groups — rows and containers alike) or after the screen's
/// last node (roots), else doc end.
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
  /// pointer instead of the drag feedback's top-left corner, and so hover
  /// visuals (alignment guides, the flow insert line, and the D3 in-chrome
  /// drop-preview ghost) can resolve the SAME `_flowHit` target the landing
  /// path uses.
  /// See [ScreenSurface.dropPointer].
  late final ValueNotifier<Offset?> _pointerGlobal =
      ValueNotifier<Offset?>(null);

  void _recordPointer(PointerEvent e) {
    _pointerGlobal.value = e.position;
  }

  /// Hint-pill visibility: plain state, no persistence — the pill reappears
  /// on restart (FORGE.md §3, deliberate).
  bool _hintVisible = true;

  /// Unscaled content size for the cursor-anchored zoom math (must match the
  /// `SizedBox` pair in [build]).
  Size _contentSize(ScreenDoc doc) {
    const screenGap = 48.0;
    var contentWidth = 0.0;
    for (final screen in doc.screens) {
      contentWidth += screenOuterWidth(screen);
    }
    if (doc.screens.length > 1) {
      contentWidth += screenGap * (doc.screens.length - 1);
    }
    // Y4: the ScreenLabel row is dropped (FORGE.md §1-3g — names move to the
    // Forge header breadcrumb), so the content height is the phone alone.
    const contentHeight = EditorMetrics.phoneOuterHeight;
    return Size(contentWidth, contentHeight);
  }

  /// Applies a cursor-anchored zoom [factor]: the pan shifts so the content
  /// point under the cursor stays fixed, then the shell (source of truth)
  /// applies the clamped zoom.
  void _zoomAtCursor(Offset globalPosition, double factor) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final result = zoomAtCursor(
      zoom: widget.zoom,
      pan: _pan,
      cursor: box.globalToLocal(globalPosition),
      viewport: box.size,
      contentSize: _contentSize(widget.store.doc),
      factor: factor,
    );
    setState(() => _pan = result.pan);
    widget.onZoomChanged?.call(result.zoom);
  }

  /// Mouse wheel / trackpad gestures: plain wheel pans vertically,
  /// Shift+wheel pans horizontally, Ctrl/Cmd+wheel (trackpad pinch on
  /// desktop) zooms anchored at the cursor, and a native pinch
  /// ([PointerScaleEvent]) zooms by its scale at the cursor.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        _zoomAtCursor(event.position, wheelZoomFactor(event.scrollDelta.dy));
      } else {
        setState(
          () => _pan = applyWheelPan(
            _pan,
            event.scrollDelta,
            shift: keys.isShiftPressed,
          ),
        );
      }
    } else if (event is PointerScaleEvent) {
      _zoomAtCursor(event.position, event.scale);
    }
  }

  /// Middle-button drag pans the viewport (any mode — it never selects).
  void _onPointerMove(PointerMoveEvent event) {
    if (event.buttons & kMiddleMouseButton != 0) {
      setState(() => _pan = applyMiddlePan(_pan, event.delta));
    }
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
              // Y4: the ScreenLabel row (per-screen device buttons + name/dims)
              // is dropped (FORGE.md §1-3g). Names move to the Forge header
              // breadcrumb and the device strip moves into the header at the
              // Y6 cutover; screen tap selection stays on the empty-area path
              // below, and `store.setScreenDevice` is untouched.
              ScreenSurface(
                screen: doc.screens[i],
                nodes: [
                  for (final n in doc.nodes)
                    if (n.screenId == doc.screens[i].id) n,
                ],
                selectedNodeId: widget.selectedNodeId,
                selected: doc.screens[i].id == widget.selectedScreenId,
                onSelectScreen: () =>
                    widget.onSelectScreen?.call(doc.screens[i].id),
                zoom: widget.zoom,
                panMode: widget.panMode,
                onSelectNode: (id) => widget.onSelectNode?.call(id),
                onResizeNode: (id, w, h) =>
                    widget.store.setNodeSize(id, w: w, h: h),
                onDropKind: (kind, position, {parentId, index}) =>
                    widget.onAccept(
                  kind,
                  position,
                  screenId: doc.screens[i].id,
                  parentId: parentId,
                  index: index,
                ),
                // Hover-visual plumbing (D3): the same live pointer that
                // the accept path snaps also drives the guides, the flow
                // insert line, and the in-chrome drop-preview ghost.
                dropPointer: _pointerGlobal,
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
        //
        // Screens size per device (see [screenOuterWidth]); the unscaled size
        // must stay in sync with [_contentSize] (cursor-anchored zoom math).
        var contentWidth = 0.0;
        for (final screen in doc.screens) {
          contentWidth += screenOuterWidth(screen);
        }
        contentWidth += math.max(0, doc.screens.length - 1) * screenGap;
        // Y4: tracks [_contentSize] (label row dropped — phone height only).
        const contentHeight = EditorMetrics.phoneOuterHeight;
        final viewport = Listener(
          onPointerSignal: _onPointerSignal,
          onPointerMove: _onPointerMove,
          child: GestureDetector(
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
          ),
        );
        // FF5 FlutterFlow canvas chrome (BUILD_SPEC §9.2 row 4a): the neutral
        // [EditorColors.canvasBackdrop] fills behind the viewport and the
        // dismissible hint pill floats top-center above it. Both are pure
        // overlays — pan/zoom/gesture code above is untouched. The Forge dot
        // grid is dropped with the Forge chrome.
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: colors.canvasBackdrop),
            ),
            viewport,
            if (_hintVisible)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: ForgeHintPill(
                    onDismiss: () => setState(() => _hintVisible = false),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
