/// Phone frame and screen label, matched to the m3e-canvas reference.
///
/// Geometry comes from [EditorMetrics] (measured at a 1440x900 viewport):
/// a 343x725 bezel body with a 328x709 screen inset by 7.5.
///
/// The screen content is exempt from the chrome dogfooding rule (it is user
/// content), but it still builds nodes through [buildCatalogItem], so unknown
/// kinds render fallback output instead of crashing.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_core/canvas_core.dart';

/// Floor for the node clamp below: guarantees a finite box even for drops at
/// the screen's far edges (content clips at the frame instead of exploding).
const double _kMinNodeExtent = 48.0;

/// Snap threshold for drag aids, in logical px in pre-zoom screen space: a
/// palette-drag pointer within this distance of a guide axis shows the guide
/// and, on drop, lands snapped onto the axis. X and Y resolve independently.
const double kSnapThreshold = 8.0;

/// Finders for the live alignment guides (used by drag-aids tests).
const ValueKey<String> kDragGuideVerticalKey =
    ValueKey<String>('drag-guide-vertical');
const ValueKey<String> kDragGuideHorizontalKey =
    ValueKey<String>('drag-guide-horizontal');

/// Sentinel listenable for a [ScreenSurface] with no [ScreenSurface.dropPointer].
final ValueNotifier<Offset?> _kNoPointer = ValueNotifier<Offset?>(null);

/// Active alignment-guide axes for a drag pointer, in screen-local logical
/// px. Each axis is `null` when no axis is within [kSnapThreshold].
class DragGuides {
  final double? x;
  final double? y;
  const DragGuides({this.x, this.y});
}

double? _snapAxis(double pointer, List<double> nodeAxes, double centerAxis) {
  double? best;
  var bestDist = double.infinity;
  for (final axis in nodeAxes) {
    final dist = (pointer - axis).abs();
    if (dist <= kSnapThreshold && dist < bestDist) {
      best = axis;
      bestDist = dist;
    }
  }
  // Node edges/centers win over the screen center; the center only applies
  // when no node axis is near enough.
  if (best != null) return best;
  return (pointer - centerAxis).abs() <= kSnapThreshold ? centerAxis : null;
}

/// Guide axes near [pointer] (screen-local logical px): the screen center H/V
/// axes plus every node's center + edge axes. Nodes are stored as top-left
/// origins with intrinsic (unmeasured) sizes, so each node's origin doubles
/// as its edge/center anchor. X and Y resolve independently.
DragGuides guidesForPointer(Offset pointer, List<CanvasNode> nodes) {
  return DragGuides(
    x: _snapAxis(
      pointer.dx,
      [for (final node in nodes) node.x],
      EditorMetrics.phoneInnerWidth / 2,
    ),
    y: _snapAxis(
      pointer.dy,
      [for (final node in nodes) node.y],
      EditorMetrics.phoneInnerHeight / 2,
    ),
  );
}

/// Snaps [pointer] (screen-local logical px) onto the nearest guide axes from
/// [guidesForPointer]. Used ONLY for pointer drops in
/// [ScreenSurface]'s accept path; [DesignCanvas.onAccept] stays
/// verbatim/unsnapped so programmatic callers keep exact coords.
Offset snapDropPosition(Offset pointer, List<CanvasNode> nodes) {
  final guides = guidesForPointer(pointer, nodes);
  return Offset(guides.x ?? pointer.dx, guides.y ?? pointer.dy);
}

/// The bezel + screen body. Clips [child] to the inner screen radius.
class PhoneFrame extends StatelessWidget {
  /// Fill behind [child], i.e. the screen's own background.
  final Color screenColor;
  final Widget child;

  const PhoneFrame({
    super.key,
    required this.screenColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: EditorMetrics.phoneOuterWidth,
      height: EditorMetrics.phoneOuterHeight,
      decoration: BoxDecoration(
        color: colors.bezel,
        borderRadius: BorderRadius.circular(EditorMetrics.phoneOuterRadius),
      ),
      padding: const EdgeInsets.all(EditorMetrics.phoneBezel),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorMetrics.phoneInnerRadius),
        child: ColoredBox(color: screenColor, child: child),
      ),
    );
  }
}

/// The row above a frame: a phone/desktop segmented pair plus the screen name.
class ScreenLabel extends StatelessWidget {
  final String name;

  /// `false` = phone (default), `true` = desktop.
  final bool desktop;
  final ValueChanged<bool>? onFormatChanged;

  const ScreenLabel({
    super.key,
    required this.name,
    this.desktop = false,
    this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _formatButton(
          colors: colors,
          icon: Icons.smartphone,
          selected: !desktop,
          radius: const BorderRadius.horizontal(
            left: Radius.circular(14),
            right: Radius.circular(4),
          ),
          onTap: () => onFormatChanged?.call(false),
        ),
        const SizedBox(width: 2),
        _formatButton(
          colors: colors,
          icon: Icons.desktop_windows_outlined,
          selected: desktop,
          radius: const BorderRadius.horizontal(
            left: Radius.circular(4),
            right: Radius.circular(14),
          ),
          onTap: () => onFormatChanged?.call(true),
        ),
        const SizedBox(width: 10),
        Text(
          name,
          style: EditorType.screenLabel.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }

  Widget _formatButton({
    required EditorColors colors,
    required IconData icon,
    required bool selected,
    required BorderRadius radius,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? colors.railActive : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: selected ? colors.onRailActive : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Finder for the flow insertion index line (used by flow-layout tests).
const ValueKey<String> kFlowInsertLineKey =
    ValueKey<String>('flow-insert-line');

/// Insertion index for [pointerMain] (pointer position along a container's
/// main axis, in screen-local logical px) given the container's
/// [childCenters] along the same axis in flow (doc) order: the first index
/// whose center sits past the pointer. An empty container yields 0. Shared by
/// the hover line and the drop path so the visual and the landing agree.
int flowInsertionIndex(double pointerMain, List<double> childCenters) {
  var index = 0;
  while (index < childCenters.length && childCenters[index] <= pointerMain) {
    index++;
  }
  return index;
}

/// Renders one screen's nodes into a [PhoneFrame], with selection affordances.
/// Insertion target resolved from a screen-local pointer: the deepest row
/// containing it ([parentId], with [targetRect] driving the row highlight)
/// else the screen root, plus the child [index] and the [lineMain] position
/// of the 2px index line (x within a row, y at root; both screen-local px).
class _FlowHit {
  final String? parentId;
  final int index;
  final double lineMain;
  final Rect? targetRect;

  const _FlowHit({
    required this.parentId,
    required this.index,
    required this.lineMain,
    required this.targetRect,
  });
}

/// Renders one screen's nodes into a [PhoneFrame], with selection
/// affordances, in flow layout.
///
/// The screen content is `Padding(kFlowScreenPadding)` around a top-left
/// `Column` of the screen's root nodes (`parentId == null`, doc order,
/// `kFlowScreenGap` separators). A row container (`isRow`) renders as a
/// start/center `Row` of its children (doc order, node `gap` separators);
/// every other node renders today's `ConstrainedBox` leaf (the clamp stays,
/// and inside rows the incoming flex width additionally bounds `maxWidth`,
/// so every catalog widget gets the finite box it needs and nothing crashes
/// on unbounded flex). Empty rows render a dashed drop placeholder (min
/// height 64, always hit-testable); the empty-screen hint is unchanged.
///
/// `x`/`y` are stored drop metadata and ignored by this renderer (see
/// [DesignCanvas.onAccept]). Bezel/labels/zoom/selection ring/drop-wash and
/// the magnetic guide infra are unchanged; the guide infra is extended with
/// a container wash on the hovered row plus the index line above.
class ScreenSurface extends StatefulWidget {
  final CanvasScreen screen;
  final List<CanvasNode> nodes;
  final String? selectedNodeId;
  final ValueChanged<String>? onSelectNode;

  /// Fired when a palette tile is dropped, with the drop point in screen
  /// coordinates (already relative to the phone's inner area) plus the
  /// flow insertion target resolved from measured geometry: [parentId] is
  /// the hovered row (null for the screen root) and [index] the child
  /// position within it. [DesignCanvas] forwards these to `onAccept`, which
  /// lands the node there in one commit.
  final void Function(
    String kind,
    Offset position, {
    String? parentId,
    int? index,
  })? onDropKind;

  /// Current viewport scale of the enclosing [DesignCanvas]. Kept so drop
  /// math can stay zoom-aware if the hit-testing path ever changes.
  final double zoom;

  /// Live global pointer position tracked by the enclosing [DesignCanvas].
  /// When available, the drop point is derived from it (the true pointer)
  /// instead of `DragTargetDetails.offset` (the drag feedback's top-left,
  /// which trails the pointer by the grab offset inside the tile).
  final ValueListenable<Offset?>? dropPointer;

  /// `true` while the pan tool is active: leaf pointer-down selection is
  /// disabled so viewport pans never (de)select nodes. Threaded from
  /// [DesignCanvas.panMode].
  final bool panMode;

  const ScreenSurface({
    super.key,
    required this.screen,
    required this.nodes,
    this.selectedNodeId,
    this.onSelectNode,
    this.onDropKind,
    this.zoom = 1.0,
    this.dropPointer,
    this.panMode = false,
  });

  @override
  State<ScreenSurface> createState() => _ScreenSurfaceState();
}

class _ScreenSurfaceState extends State<ScreenSurface> {
  /// Measured-layout keys per node id (rows and leaves alike).
  final Map<String, GlobalKey> _flowKeys = {};

  GlobalKey _flowKey(String id) => _flowKeys.putIfAbsent(id, () => GlobalKey());

  /// Screen-local rect of a laid-out node, or null before first layout.
  Rect? _nodeRect(String id, RenderBox screenBox) {
    final nodeContext = _flowKeys[id]?.currentContext;
    final box = nodeContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final topLeft = screenBox.globalToLocal(box.localToGlobal(Offset.zero));
    return Rect.fromLTWH(
      topLeft.dx - EditorMetrics.phoneBezel,
      topLeft.dy - EditorMetrics.phoneBezel,
      box.size.width,
      box.size.height,
    );
  }

  /// Shared insert/reorder path: resolves the pointer to a flow target plus
  /// a child index (by child midpoints along the container's axis; empty
  /// containers yield 0) and the index-line position. Used identically by the
  /// hover visuals and the drop path so the line and the landing agree.
  _FlowHit _flowHit(Offset pointer, RenderBox screenBox) {
    // Deepest row containing the pointer wins; smallest area breaks ties so
    // nested rows (should they ever nest) resolve inward.
    CanvasNode? hitRow;
    Rect? hitRect;
    for (final node in widget.nodes) {
      if (node.parentId != null || !node.isRow) continue;
      final rect = _nodeRect(node.id, screenBox);
      if (rect == null || !rect.contains(pointer)) continue;
      if (hitRect == null ||
          rect.width * rect.height < hitRect.width * hitRect.height) {
        hitRow = node;
        hitRect = rect;
      }
    }
    if (hitRow != null && hitRect != null) {
      final kids = [
        for (final node in widget.nodes)
          if (node.parentId == hitRow.id) node,
      ];
      final centers = <double>[];
      final starts = <double?>[];
      final ends = <double?>[];
      for (final kid in kids) {
        final rect = _nodeRect(kid.id, screenBox);
        if (rect == null) {
          // Pre-layout fallback: stored x as the center proxy.
          centers.add(kid.x);
          starts.add(null);
          ends.add(null);
        } else {
          centers.add((rect.left + rect.right) / 2);
          starts.add(rect.left);
          ends.add(rect.right);
        }
      }
      final rowRect = hitRect;
      final index =
          flowInsertionIndex(pointer.dx, centers).clamp(0, kids.length);
      return _FlowHit(
        parentId: hitRow.id,
        index: index,
        lineMain: _boundary(
          pointer.dx,
          index,
          starts,
          ends,
          rowRect.left,
          rowRect.right,
        ),
        targetRect: rowRect,
      );
    }
    final roots = [
      for (final node in widget.nodes)
        if (node.parentId == null) node,
    ];
    final centers = <double>[];
    final starts = <double?>[];
    final ends = <double?>[];
    for (final root in roots) {
      final rect = _nodeRect(root.id, screenBox);
      if (rect == null) {
        // Pre-layout fallback: stored y as the center proxy.
        centers.add(root.y);
        starts.add(null);
        ends.add(null);
      } else {
        centers.add((rect.top + rect.bottom) / 2);
        starts.add(rect.top);
        ends.add(rect.bottom);
      }
    }
    final index =
        flowInsertionIndex(pointer.dy, centers).clamp(0, roots.length);
    return _FlowHit(
      parentId: null,
      index: index,
      lineMain: _boundary(
        pointer.dy,
        index,
        starts,
        ends,
        kFlowScreenPadding,
        null,
      ),
      targetRect: null,
    );
  }

  /// Index-line position along the container's main axis: the midpoint
  /// between the flanking measured children, the container's padding edge
  /// before the first child, the last child's far edge at the end, else the
  /// pointer itself (unmeasured fallback).
  double _boundary(
    double pointer,
    int index,
    List<double?> starts,
    List<double?> ends,
    double edgeStart,
    double? edgeEnd,
  ) {
    if (index <= 0) {
      if (starts.isNotEmpty && starts.first != null) return starts.first!;
      return edgeStart;
    }
    if (index >= starts.length) {
      if (ends.isNotEmpty && ends.last != null) return ends.last!;
      if (edgeEnd != null) return edgeEnd;
      return pointer;
    }
    final before = ends[index - 1];
    final after = starts[index];
    if (before != null && after != null) return (before + after) / 2;
    return pointer;
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    // Drop keys for removed nodes so measurement never goes stale.
    _flowKeys.removeWhere(
      (id, _) => !widget.nodes.any((node) => node.id == id),
    );
    return PhoneFrame(
      screenColor: colors.surface,
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          // Prefer the live pointer (true drop point) when the enclosing
          // canvas tracked one; fall back to the feedback corner otherwise.
          final global = widget.dropPointer?.value ?? details.offset;
          final local = box.globalToLocal(global);
          // ZOOM FINDING (test-driven, see canvas_store_screens_test.dart
          // 'drop at zoom 2.0 lands at unscaled screen coords'): pass the
          // converted point through WITHOUT dividing by [zoom].
          // `globalToLocal` already inverts every ancestor transform,
          // including the `Transform.scale` in DesignCanvas, so `local` is
          // already in unscaled screen px. Dividing by `zoom` again would
          // double-correct and land the node at ~half the intended point.
          // [zoom] is therefore kept as a parameter for future-proofing but
          // intentionally unused in this conversion.
          final position = Offset(
            local.dx - EditorMetrics.phoneBezel,
            local.dy - EditorMetrics.phoneBezel,
          );
          // Magnetic snap applies to pointer drops only — `onAccept` itself
          // stays verbatim/unsnapped for programmatic callers, so the snapped
          // point is computed here and forwarded through `onDropKind`.
          final snapped = snapDropPosition(position, widget.nodes);
          // Shared insert path with the hover visuals below: the target and
          // index resolve from measured geometry and `onAccept` lands the
          // node there in one commit.
          final hit = _flowHit(snapped, box);
          widget.onDropKind?.call(
            details.data,
            snapped,
            parentId: hit.parentId,
            index: hit.index,
          );
        },
        builder: (_, candidate, rejected) {
          // Live guides driven by the enclosing canvas's pointer tracking
          // (the same `dropPointer` plumbing the accept path uses), so the
          // lines follow the hover and vanish with `candidate` on
          // drop/cancel/leave.
          return ValueListenableBuilder<Offset?>(
            valueListenable: widget.dropPointer ?? _kNoPointer,
            builder: (guideContext, global, _) {
              var guides = const DragGuides();
              _FlowHit? hover;
              if (candidate.isNotEmpty && global != null) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final local = box.globalToLocal(global);
                  final pointer = Offset(
                    local.dx - EditorMetrics.phoneBezel,
                    local.dy - EditorMetrics.phoneBezel,
                  );
                  guides = guidesForPointer(pointer, widget.nodes);
                  hover = _flowHit(pointer, box);
                }
              }
              final hoverHit = hover;
              final hoverRect = hover?.targetRect;
              // A hovered row carries its own wash; otherwise the whole
              // screen washes while a drag hovers it.
              final hoveringRow = hoverHit?.parentId != null;
              return Stack(
                children: [
                  _buildFlow(colors),
                  if (candidate.isNotEmpty && !hoveringRow)
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.railActive.withValues(alpha: 0.25),
                      ),
                    ),
                  if (hoverRect != null)
                    Positioned.fromRect(
                      rect: hoverRect,
                      child: ColoredBox(
                        color: colors.railActive.withValues(alpha: 0.25),
                      ),
                    ),
                  if (widget.nodes.isEmpty && candidate.isEmpty)
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Drag a part here to start',
                            textAlign: TextAlign.center,
                            style: EditorType.field
                                .copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  // 2px index line spanning the hovered container's cross
                  // axis. Gated on `candidate` via `hover`, so it vanishes
                  // on drop/leave with the guides.
                  if (hoverHit != null) _buildInsertLine(hoverHit, colors),
                  if (guides.x != null)
                    Positioned(
                      key: kDragGuideVerticalKey,
                      left: guides.x,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: colors.toolbarActive.withValues(alpha: 0.5),
                      ),
                    ),
                  if (guides.y != null)
                    Positioned(
                      key: kDragGuideHorizontalKey,
                      top: guides.y,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: colors.toolbarActive.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Screen content: padded top-left column of root nodes (doc order).
  Widget _buildFlow(EditorColors colors) {
    final roots = [
      for (final node in widget.nodes)
        if (node.parentId == null) node,
    ];
    return Padding(
      padding: const EdgeInsets.all(kFlowScreenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < roots.length; i++) ...[
            if (i > 0) const SizedBox(height: kFlowScreenGap),
            if (roots[i].isRow)
              _buildRow(roots[i], colors)
            else
              _buildLeaf(roots[i], colors),
          ],
        ],
      ),
    );
  }

  /// One row container: full-width tap target (selects the row for gap
  /// editing) around a start/center `Row` of its children (doc order, node
  /// `gap` separators). Children ride `Flexible` so each gets a finite width
  /// share — kit widgets with internal `Expanded` rows (e.g. `TextField`)
  /// would detonate on the `Row`'s unbounded width otherwise.
  Widget _buildRow(CanvasNode node, EditorColors colors) {
    final kids = [
      for (final child in widget.nodes)
        if (child.parentId == node.id) child,
    ];
    // Clamp defensive: a negative stored gap must never size a separator.
    final gap = math.max(0.0, node.gap);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelectNode?.call(node.id),
      child: Container(
        key: _flowKey(node.id),
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: node.id == widget.selectedNodeId
            ? BoxDecoration(
                border: Border.all(
                  color: colors.toolbarActive,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: kids.isEmpty
            ? _EmptyRowPlaceholder(colors: colors)
            : Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < kids.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Flexible(child: _buildLeaf(kids[i], colors)),
                  ],
                ],
              ),
      ),
    );
  }

  /// One leaf node: today's `ConstrainedBox` content (the clamp stays —
  /// guarantees a finite box even for drops at the screen's far edges, where
  /// content clips at the frame instead of exploding). Intrinsically-sized
  /// widgets (button/card/badge) are unaffected — only the maximum shrinks.
  ///
  /// Selection rides [Listener.onPointerDown], NOT `GestureDetector.onTap`:
  /// interactive kit content (buttons, switches, inputs, tabs, …) owns tap
  /// recognizers that beat the outer detector in the gesture arena, so
  /// `onTap` never fires for those nodes (regression: tap_diagnosis_test).
  /// A [Listener] is arena-exempt and always observes the hit. The
  /// [GestureDetector] stays for tap semantics (screen readers) and for
  /// non-interactive content; selecting the same id twice is harmless.
  /// Gated on [ScreenSurface.panMode] so viewport pans never select.
  /// The opaque behavior (unlike the old defer-to-child default) also makes
  /// the 4px padding hit-testable, matching the row's full-bleed target.
  Widget _buildLeaf(CanvasNode node, EditorColors colors) {
    void select() {
      if (!widget.panMode) widget.onSelectNode?.call(node.id);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => select(),
      child: GestureDetector(
        onTap: select,
        child: Container(
          key: _flowKey(node.id),
          padding: const EdgeInsets.all(4),
          decoration: node.id == widget.selectedNodeId
              ? BoxDecoration(
                  border: Border.all(
                    color: colors.toolbarActive,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(
                _kMinNodeExtent,
                EditorMetrics.phoneInnerWidth - node.x,
              ),
              maxHeight: math.max(
                _kMinNodeExtent,
                EditorMetrics.phoneInnerHeight - node.y,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in node.items)
                  buildCatalogItem(item.kind, item.props),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2px index line spanning the hovered container's cross axis: horizontal
  /// across the content for the root column, vertical across the row for a
  /// row container.
  Widget _buildInsertLine(_FlowHit hit, EditorColors colors) {
    if (hit.parentId == null) {
      return Positioned(
        key: kFlowInsertLineKey,
        left: kFlowScreenPadding,
        right: kFlowScreenPadding,
        top: hit.lineMain - 1,
        height: 2,
        child: ColoredBox(color: colors.toolbarActive),
      );
    }
    final rect = hit.targetRect!;
    return Positioned(
      key: kFlowInsertLineKey,
      left: hit.lineMain - 1,
      width: 2,
      top: rect.top,
      height: rect.height,
      child: ColoredBox(color: colors.toolbarActive),
    );
  }
}

/// Empty-row drop target: dashed rounded rect, min height 64, muted
/// 'Drop here' label. Sized (never zero) so it stays hit-testable, and the
/// row's opaque tap detector selects the row through it.
class _EmptyRowPlaceholder extends StatelessWidget {
  final EditorColors colors;

  const _EmptyRowPlaceholder({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      child: CustomPaint(
        painter: _DashedOutline(
          color: colors.toolbarActive.withValues(alpha: 0.5),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Drop here',
              style: EditorType.field.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect stroke.
class _DashedOutline extends CustomPainter {
  final Color color;

  const _DashedOutline({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawPath(
      _dashPath(path, 6, 4),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => oldDelegate.color != color;
}

/// Dashes [source] into alternating [dash]/[gap] lengths.
Path _dashPath(Path source, double dash, double gap) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var dist = 0.0;
    while (dist < metric.length) {
      final end = math.min(dist + dash, metric.length);
      out.addPath(metric.extractPath(dist, end), Offset.zero);
      dist = end + gap;
    }
  }
  return out;
}
