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
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/responsive.dart';
import 'package:canvas_core/canvas_core.dart';

/// Floor for the node clamp below: guarantees a finite box even for drops at
/// the screen's far edges (content clips at the frame instead of exploding).
const double _kMinNodeExtent = 48.0;

/// Track X1 modern bezel: the visual padding inside the frame (the measured
/// [EditorMetrics.phoneBezel] 7.5 stays as the OUTER budget — see the
/// `outerWidth` formula at the `ScreenSurface` site and [screenOuterWidth] —
/// so the outer body keeps its measured geometry while the freed pixels go to
/// the screen). All screen-origin math ([_ScreenSurfaceState._nodeRect], the
/// drop/hover conversions) subtracts this, never the token.
const double _kFrameBezel = 4.0;

/// Track X1 resize-handle gesture area (square side, logical px). The
/// pointer target is >= 28px per side while the painted square stays small
/// (see [_kHandleVisualSize]); handles sit inside the selected chrome edges
/// (see [_ScreenSurfaceState._withHandles]).
const double _kHandleHitSize = 28.0;

/// Track X1 painted handle square (square side, logical px): the visual
/// stays 10-12px, centered in the transparent [_kHandleHitSize] hit area.
const double _kHandleVisualSize = 12.0;

/// Track X1 status-bar strip height (logical px): the overlaid phone status
/// bar (time + glyphs) plus the matching top reserve in the screen scroll
/// view so no content hides underneath it.
const double _kStatusBarHeight = 28.0;

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
///
/// [centerX]/[centerY] override the screen-center axes (defaults are the
/// phone metrics); wider per-screen devices pass their own center so guides
/// track the actual frame.
DragGuides guidesForPointer(
  Offset pointer,
  List<CanvasNode> nodes, {
  double? centerX,
  double? centerY,
}) {
  return DragGuides(
    x: _snapAxis(
      pointer.dx,
      [for (final node in nodes) node.x],
      centerX ?? EditorMetrics.phoneInnerWidth / 2,
    ),
    y: _snapAxis(
      pointer.dy,
      [for (final node in nodes) node.y],
      centerY ?? EditorMetrics.phoneInnerHeight / 2,
    ),
  );
}

/// Snaps [pointer] (screen-local logical px) onto the nearest guide axes from
/// [guidesForPointer]. Used ONLY for pointer drops in
/// [ScreenSurface]'s accept path; [DesignCanvas.onAccept] stays
/// verbatim/unsnapped so programmatic callers keep exact coords.
Offset snapDropPosition(
  Offset pointer,
  List<CanvasNode> nodes, {
  double? centerX,
  double? centerY,
}) {
  final guides =
      guidesForPointer(pointer, nodes, centerX: centerX, centerY: centerY);
  return Offset(guides.x ?? pointer.dx, guides.y ?? pointer.dy);
}

/// The bezel + screen body. Clips [child] to the inner screen radius.
///
/// [outerWidth]/[outerHeight] default to the phone metrics; per-screen
/// devices pass a wider [outerWidth] (device stage width + bezel) while the
/// height stays fixed.
class PhoneFrame extends StatelessWidget {
  /// Fill behind [child], i.e. the screen's own background.
  final Color screenColor;
  final Widget child;

  /// Outer box size (bezel included).
  final double outerWidth;
  final double outerHeight;

  const PhoneFrame({
    super.key,
    required this.screenColor,
    required this.child,
    this.outerWidth = EditorMetrics.phoneOuterWidth,
    this.outerHeight = EditorMetrics.phoneOuterHeight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: outerWidth,
      height: outerHeight,
      decoration: BoxDecoration(
        color: colors.bezel,
        borderRadius: BorderRadius.circular(EditorMetrics.phoneOuterRadius),
        // Track X1 frame polish: a soft drop shadow grounds the device on the
        // canvas well. The shadow paints outside the measured box without
        // changing layout (a decoration *border* would deflate the child by
        // its width and shift the screen origin — never add one here; the
        // drop math subtracts exactly [_kFrameBezel]).
        // Token colors only — no hardcoded hex.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_kFrameBezel),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorMetrics.phoneInnerRadius),
        child: ColoredBox(color: screenColor, child: child),
      ),
    );
  }
}

/// Track X1 phone status bar: overlaid strip with the classic `9:41` time on
/// the left and signal/wifi/battery glyphs on the right. Token-styled
/// ([EditorColors.onSurfaceVariant] on the screen background); `IgnorePointer`
/// Wrapped in [IgnorePointer] so it never claims taps, selection, or drops.
class _StatusBar extends StatelessWidget {
  final EditorColors colors;
  final Color background;

  const _StatusBar({required this.colors, required this.background});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: _kStatusBarHeight,
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              '9:41',
              style: EditorType.readout.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.signal_cellular_alt,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Icon(Icons.wifi, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Icon(
              Icons.battery_full,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Finder for the selected-screen highlight ring (used by
/// screen-interaction tests).
ValueKey<String> screenSelectedKey(String screenId) =>
    ValueKey<String>('screen-selected:$screenId');

/// The row above a frame: per-screen device buttons plus the screen name.
///
/// The device buttons are real controls: tapping one calls [onDeviceChanged]
/// with that preset's id, except phone (the default) which passes null so
/// the doc stays sparse. Tapping the name calls [onSelect]; the name renders
/// in the selected style while [selected] is true.
class ScreenLabel extends StatelessWidget {
  final String name;

  /// Per-screen device id (a `PreviewDeviceSpec` id); null = phone default.
  final String? device;

  /// Called with the tapped device id (null for phone).
  final ValueChanged<String?>? onDeviceChanged;

  /// Whether this screen holds the shell selection.
  final bool selected;

  /// Called when the screen name is tapped.
  final VoidCallback? onSelect;

  const ScreenLabel({
    super.key,
    required this.name,
    this.device,
    this.onDeviceChanged,
    this.selected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final spec = specForScreenDevice(device);
    final activeId = spec.id;
    // Track X1: live WxH readout of the screen device (frameless fluid
    // presets carry no fixed height, so they read width-only).
    final dims = spec.height == null
        ? '${spec.width.round()}'
        : '${spec.width.round()}×${spec.height!.round()}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kPreviewDevices.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          _deviceButton(
            colors: colors,
            device: kPreviewDevices[i],
            selected: kPreviewDevices[i].id == activeId,
            first: i == 0,
            last: i == kPreviewDevices.length - 1,
            onTap: () => onDeviceChanged?.call(
              kPreviewDevices[i].id == kPreviewDevicePhone.id
                  ? null
                  : kPreviewDevices[i].id,
            ),
          ),
        ],
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSelect,
          child: Text(
            name,
            style: EditorType.screenLabel.copyWith(
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dims,
          style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _deviceButton({
    required EditorColors colors,
    required PreviewDeviceSpec device,
    required bool selected,
    required bool first,
    required bool last,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.horizontal(
      left: Radius.circular(first ? 14 : 4),
      right: Radius.circular(last ? 14 : 4),
    );
    return shadcn.Tooltip(
      tooltip: (context) =>
          shadcn.TooltipContainer(child: Text(device.label)),
      child: Container(
        width: 28,
        height: EditorMetrics.screenLabelHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.railActive : Colors.transparent,
          borderRadius: radius,
        ),
        child: shadcn.IconButton.ghost(
          icon: Icon(
            device.icon,
            size: 16,
            color: selected ? colors.onRailActive : colors.onSurfaceVariant,
          ),
          onPressed: onTap,
          size: shadcn.ButtonSize.small,
          density: shadcn.ButtonDensity.compact,
        ),
      ),
    );
  }
}

/// Finder for the flow insertion index line (used by flow-layout tests).
const ValueKey<String> kFlowInsertLineKey =
    ValueKey<String>('flow-insert-line');

/// Finder for the drop-preview ghost (used by drop-preview tests): the
/// in-chrome ghost of the dragged kind rendered at the hover insertion index
/// while a palette drag hovers a container/row/root target.
const ValueKey<String> kDropPreviewKey = ValueKey<String>('drop-preview');

/// W3 container alignment mapping: row `mainAxis` strings to
/// [MainAxisAlignment] (`null` → start, unknown → start).
MainAxisAlignment rowMainAxis(String? value) {
  switch (value) {
    case 'center':
      return MainAxisAlignment.center;
    case 'end':
      return MainAxisAlignment.end;
    case 'spaceBetween':
      return MainAxisAlignment.spaceBetween;
    case 'spaceAround':
      return MainAxisAlignment.spaceAround;
    case 'spaceEvenly':
      return MainAxisAlignment.spaceEvenly;
    case 'start':
    case null:
      return MainAxisAlignment.start;
    default:
      return MainAxisAlignment.start;
  }
}

/// W3 container alignment mapping: row `crossAxis` strings to
/// [CrossAxisAlignment] (`null` → center, unknown → center).
CrossAxisAlignment rowCrossAxis(String? value) {
  switch (value) {
    case 'start':
      return CrossAxisAlignment.start;
    case 'end':
      return CrossAxisAlignment.end;
    case 'stretch':
      return CrossAxisAlignment.stretch;
    case 'center':
    case null:
      return CrossAxisAlignment.center;
    default:
      return CrossAxisAlignment.center;
  }
}

/// W3 child flex wrapper + Track U2 sizing (single source of truth for the
/// canvas renderer and the preview player, which imports this function).
///
/// SQUEEZE ROOT CAUSE (user-observed: two parts side-by-side in a row
/// rendered ~45px each with letter-by-letter text wrap instead of sharing
/// space): the pre-U2 default here was `Flexible(child: content)` —
/// `FlexFit.loose`. Loose fit lets shrink-wrapping content (cards, badges,
/// …) collapse to its MINIMUM intrinsic width instead of filling its share
/// of the `Row`, so two cards sat side by side at intrinsic width with dead
/// space around them, wrapping their text into the tiny box. The U2 fix:
/// null-width children default to TIGHT fit (equal shares), so available
/// space is shared by construction.
///
/// ROW FLEX RULE:
/// * `w != null` → `SizedBox(width: w)`: exact pixels, NO flex (an explicit
///   fixed size beats flex; clear it to restore the flex role). Heights ride
///   inside the cell (see [applyNodeSize]) — rows keep the `crossAxis`
///   default `center`, and a fixed `h` centers per it.
/// * `expand == 'expanded'` → `Expanded(flex ?? 1)` (tight).
/// * `expand == 'flex'` → `Flexible(flex ?? 1)` (loose).
/// * otherwise (null/`none`/unknown) → tight `Flexible(flex ?? 1)` (equal
///   shares — the squeeze fix; an explicit `flex` is honored).
///   Deliberately `Flexible` with [FlexFit.tight], NOT [Expanded] (which is
///   the same layout): `find.byType(Flexible)` matches exact runtime types,
///   and `container_layout_test.dart` pins the default cell as `Flexible`.
///
/// Every branch yields a FINITE width, so kit widgets with internal
/// `Expanded` rows never see unbounded width. Unsized codegen keeps the
/// legacy unwrapped emission (byte-identical goldens), so canvas and export
/// agree exactly once sizes are set and differ only for plain auto rows
/// (canvas shares, export shrink-wraps as before) — documented on
/// [CanvasNode].
Widget wrapRowChild(CanvasNode child, Widget content) {
  // Track X1 fill: a fixed-w cell fills its pixels through the same
  // [applyNodeSizeValues] rule (stretch column, intrinsic height) instead of
  // a bare SizedBox.
  if (child.w != null) return applyNodeSizeValues(child.w, null, content);
  switch (child.expand) {
    case 'expanded':
      return Expanded(flex: child.flex ?? 1, child: content);
    case 'flex':
      return Flexible(flex: child.flex ?? 1, child: content);
    default:
      return Flexible(
        flex: child.flex ?? 1,
        fit: FlexFit.tight,
        child: content,
      );
  }
}

/// Applies a node's explicit size to [content] (Track U2, fill Track X1):
/// null dims pass through untouched (auto — today's behavior, byte-identical
/// tree), set dims wrap in a [SizedBox] whose child FILLS the pinned box —
/// a `Column` with [CrossAxisAlignment.stretch] holding [content] directly
/// for width-only pins (intrinsic height) or in an [Expanded] once a height
/// is pinned (fills both axes). Without the stretch layer the intermediate
/// start-aligned content columns loosen the tight box and kit surfaces paint
/// intrinsic top-left while the selection ring grows (the reported bug).
/// Pure widget helper shared by leaves, containers, and row bodies so canvas
/// sizing has one rule; codegen mirrors it with the same `SizedBox` idiom.
Widget applyNodeSize(CanvasNode node, Widget content) =>
    applyNodeSizeValues(node.w, node.h, content);

/// Tentative-size variant of [applyNodeSize]: [w]/[h] are the effective
/// (in-gesture tentative ?? stored) dims, used while a resize drag is live.
Widget applyNodeSizeValues(double? w, double? h, Widget content) {
  if (w == null && h == null) return content;
  if (h == null) {
    return SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content],
      ),
    );
  }
  return SizedBox(
    width: w,
    height: h,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: content)],
    ),
  );
}

/// Converts a drag [delta] from global (pointer) px to screen-local logical
/// px for the current [zoom] (Track U2 handle math).
///
/// ZOOM LESSON, DELTA HALF (contrast the drop-offset rule kept on
/// [ScreenSurface]: `globalToLocal` inverts the layout zoom for POSITIONS,
/// so drops must NOT divide — but gesture DELTAS are raw pointer-space
/// differences the framework never transforms, so they MUST be divided by
/// [zoom] to land in screen space). Unit-tested below; non-positive zoom
/// falls back to unscaled (never divide by zero).
double resizeDeltaToLocal(double delta, double zoom) =>
    zoom > 0 ? delta / zoom : delta;

/// Clamps a dragged width into the sane UI range `[kMinNodeSize, maxWidth]`
/// (Track U2). [maxWidth] is the live stage width; a degenerate max below
/// the floor clamps to the floor itself. Heights use [clampResizeHeight].
/// The store stays permissive (any positive finite loads); these clamps live
/// at the gesture layer only.
double clampResizeWidth(double value, double maxWidth) {
  final hi = math.max(kMinNodeSize, maxWidth);
  return value.clamp(kMinNodeSize, hi).toDouble();
}

/// Clamps a dragged height into `[kMinNodeSize, maxHeight]` (see
/// [clampResizeWidth]). [maxHeight] is the fixed stage height.
double clampResizeHeight(double value, double maxHeight) {
  final hi = math.max(kMinNodeSize, maxHeight);
  return value.clamp(kMinNodeSize, hi).toDouble();
}

/// Finder key for a Track U2 resize handle: [edge] is one of
/// `'right'`/`'bottom'`/`'corner'` (used by resize-handle tests).
ValueKey<String> resizeHandleKey(String nodeId, String edge) =>
    ValueKey<String>('resize-$edge:$nodeId');

/// Finder key for the Track X1 live WxH readout chip shown near the selected
/// node while its resize drag is live (used by stretch/handle tests).
ValueKey<String> resizeReadoutKey(String nodeId) =>
    ValueKey<String>('resize-readout:$nodeId');

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
/// Insertion target resolved from a screen-local pointer: the deepest
/// container-or-row containing it ([parentId], with [targetRect] driving the
/// target highlight) else the screen root, plus the child [index] and the
/// [lineMain] position of the 2px index line (x within a row, y within a
/// container or at root; all screen-local px). [targetIsRow] tells the index
/// line which axis to span (rows are horizontal, containers vertical).
class _FlowHit {
  final String? parentId;
  final int index;
  final double lineMain;
  final Rect? targetRect;
  final bool targetIsRow;

  const _FlowHit({
    required this.parentId,
    required this.index,
    required this.lineMain,
    required this.targetRect,
    this.targetIsRow = true,
  });
}

/// In-chrome drop-preview target (Track D3): the hovered flow target plus the
/// dragged kind, resolved from the SAME [_FlowHit] as the landing path so the
/// ghost and the drop agree on parent + index. Null while no drag hovers.
typedef _DropGhostSpec = ({String? parentId, int index, String kind});

/// Screen background for [screen] inside the inner components-themed canvas.
///
/// `bg == 'surface'` follows the kit scheme background — read live from the
/// enclosing `ThemedCanvas` via `shadcn.Theme.of(context)` — while any other
/// `bg` keeps the chrome [EditorColors.surface]. The kit color converts
/// through the same `Color(color.toARGB32())` idiom as `_materialColor` in
/// `theme_bar.dart` (no hardcoded hex); this makes the long-dead
/// `screen.bg` config live again.
Color _screenBackground(
  BuildContext context,
  EditorColors chrome,
  CanvasScreen screen,
) {
  if (screen.bg != 'surface') return chrome.surface;
  return Color(shadcn.Theme.of(context).colorScheme.background.toARGB32());
}

/// Renders one screen's nodes into a [PhoneFrame], with selection
/// affordances, in flow layout.
///
/// The frame renders at the screen's per-screen device width: the inner
/// stage width is the resolved `PreviewDeviceSpec` width (see
/// [specForScreenDevice]; null device = phone) inside the standard bezel,
/// while the height stays the fixed phone metric. The stage width IS the
/// responsive breakpoint (the same [tierForWidth] rule as the preview
/// stage): nodes hidden on the resolved tier ([isNodeHiddenOnWidth]) are
/// skipped live — a hidden row container hides its whole subtree — so
/// tablet/desktop-width screens demo responsive `hiddenOn` without entering
/// preview.
///
/// Tapping empty screen area calls [onSelectScreen] (node taps are claimed
/// by the inner leaf/row detectors, so they select the node instead); while
/// [selected] the frame carries a highlight ring in
/// [EditorColors.toolbarActive].
class ScreenSurface extends StatefulWidget {
  final CanvasScreen screen;
  final List<CanvasNode> nodes;
  final String? selectedNodeId;
  final ValueChanged<String>? onSelectNode;

  /// Whether this screen holds the shell selection (highlight ring).
  final bool selected;

  /// Called when empty screen area is tapped.
  final VoidCallback? onSelectScreen;

  /// Fired when a palette tile is dropped, with the drop point in screen
  /// coordinates (already relative to the phone's inner area) plus the
  /// flow insertion target resolved from measured geometry: [parentId] is
  /// the hovered container-or-row (null for the screen root) and [index]
  /// the child position within it. [DesignCanvas] forwards these to
  /// `onAccept`, which lands the node there in one commit.
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
  /// which trails the pointer by the grab offset inside the tile). The hover
  /// visuals (guides, insert line, and the D3 drop-preview ghost) resolve
  /// their target from it each frame via the shared [_flowHit] path.
  final ValueListenable<Offset?>? dropPointer;

  /// `true` while the pan tool is active: leaf pointer-down selection is
  /// disabled so viewport pans never (de)select nodes. Threaded from
  /// [DesignCanvas.panMode].
  final bool panMode;

  /// Commit for a finished Track U2 resize gesture: the selected node's
  /// handles report concrete sizes here on drag end (a null dim stayed auto —
  /// wire `(id, w, h) => store.setNodeSize(id, w: w, h: h)`).
  ///
  /// WIRING (for the coordinator — `DesignCanvas` is owned by another batch
  /// and cannot pass this yet): add that one line at the
  /// `DesignCanvas → ScreenSurface` construction site. Until then handles
  /// render with live tentative feedback and no-op on release, while the
  /// inspector W/H editors (which own the store) work end to end today.
  final void Function(String nodeId, double? w, double? h)? onResizeNode;

  const ScreenSurface({
    super.key,
    required this.screen,
    required this.nodes,
    this.selectedNodeId,
    this.onSelectNode,
    this.selected = false,
    this.onSelectScreen,
    this.onDropKind,
    this.zoom = 1.0,
    this.dropPointer,
    this.panMode = false,
    this.onResizeNode,
  });

  @override
  State<ScreenSurface> createState() => _ScreenSurfaceState();
}

class _ScreenSurfaceState extends State<ScreenSurface> {
  /// Track X1 vertical scroll for over-tall content: the screen viewport keeps
  /// its fixed frame height while the flow scrolls inside it (see [build]).
  /// Drop/hover math resolves in DOC coords (viewport pointer + scroll offset)
  /// so the landing and the insert line agree while scrolled.
  final ScrollController _scrollController = ScrollController();

  /// Current vertical scroll offset in screen-local logical px (0 when the
  /// scroll view is not laid out yet).
  double get _scrollY =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Measured-layout keys per node id (rows and leaves alike).
  final Map<String, GlobalKey> _flowKeys = {};

  GlobalKey _flowKey(String id) => _flowKeys.putIfAbsent(id, () => GlobalKey());

  /// In-progress resize gesture starts, keyed by node id (Track U2): the
  /// concrete size the drag began from (stored size, else the measured render
  /// size, else the floor) plus which axes have moved. Only touched axes
  /// commit on release (see [_endResize]) — dragging the width handle of an
  /// auto-height node must not pin its height. Present from pointer-down
  /// until end/cancel; visuals only change once [_dragSizes] gains a
  /// tentative value.
  final Map<String, ({double w, double h, bool touchedW, bool touchedH})>
      _resizeStarts = {};

  /// Tentative sizes for the live resize gesture, keyed by node id.
  /// Commit-on-release (ONE undo entry per gesture): drag updates only
  /// `setState` this map for live feedback while the store stays untouched;
  /// the single commit goes through [ScreenSurface.onResizeNode] on drag end.
  /// Cleared on end/cancel and for nodes that vanish.
  final Map<String, ({double w, double h})> _dragSizes = {};

  /// Pointer id holding the node-selection claim. Pointer-down dispatches
  /// deepest-first, so the first node [Listener] to claim a pointer wins and
  /// ancestors skip: tapping a nested child selects the child, not every
  /// ancestor up to the root (without this, nested taps would end on the
  /// outermost container because ancestor Listeners fire after the deepest
  /// one — Listeners are arena-exempt, unlike the row `GestureDetector`s).
  /// Cleared on pointer-up/cancel. Gated per-tap, so sequential taps and
  /// taps on empty chrome are unaffected.
  int? _selectionClaim;

  /// Claims the tap-selection for [node] unless a deeper node already
  /// claimed [pointer] (see [_selectionClaim]).
  void _claimSelect(CanvasNode node, int pointer) {
    if (_selectionClaim == pointer) return;
    _selectionClaim = pointer;
    if (!widget.panMode) widget.onSelectNode?.call(node.id);
  }

  void _releaseClaim(int pointer) {
    if (_selectionClaim == pointer) _selectionClaim = null;
  }

  /// Effective (rendered) width of [node]: the live tentative size while its
  /// handle drags, else the stored size. Row cells ([_rowCell]) and chrome
  /// ([_nodeChrome]/[_buildRow]) all read through here so the gesture preview
  /// and the committed render agree.
  double? _effW(CanvasNode node) => _dragSizes[node.id]?.w ?? node.w;

  /// Effective (rendered) height of [node] (see [_effW]).
  double? _effH(CanvasNode node) => _dragSizes[node.id]?.h ?? node.h;

  /// Track X1 fill axis for a node's own content column: a pinned dim
  /// (live drag size wins, like the chrome) stretches the column so kit
  /// surfaces paint at the pinned width instead of shrinking to intrinsic
  /// top-left. Auto nodes keep `start` — today's behavior, so badges stay
  /// intrinsic and the row squeeze fix is untouched.
  CrossAxisAlignment _contentCrossAxis(CanvasNode node) =>
      (_effW(node) != null || _effH(node) != null)
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start;

  /// Measured render size of [id]'s chrome, or null before first layout.
  Size? _measuredSize(String id) {
    final box = _flowKeys[id]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.size;
  }

  /// Records a resize-gesture start: resolves the concrete drag origin
  /// (stored size, else the measured render size so auto nodes resize from
  /// what the user sees, else the floor, clamped to the live stage). No
  /// `setState` — visuals change only once movement produces a tentative.
  void _beginResize(CanvasNode node) {
    final measured = _measuredSize(node.id);
    _resizeStarts[node.id] = (
      w: clampResizeWidth(
        node.w ?? measured?.width ?? kMinNodeSize,
        _innerWidth,
      ),
      h: clampResizeHeight(
        node.h ?? measured?.height ?? kMinNodeSize,
        EditorMetrics.phoneInnerHeight,
      ),
      touchedW: false,
      touchedH: false,
    );
  }

  /// Applies one drag update in screen-local px (callers divide by [zoom]
  /// via [resizeDeltaToLocal]): accumulates onto the tentative (or the start
  /// on the first update) clamped to the live stage, then rebuilds for live
  /// feedback. The store is untouched until [_endResize].
  void _updateResize(
    String nodeId,
    double dxLocal,
    double dyLocal, {
    required bool horizontal,
    required bool vertical,
  }) {
    final start = _resizeStarts[nodeId];
    if (start == null) return;
    final base = _dragSizes[nodeId] ?? (w: start.w, h: start.h);
    setState(() {
      _resizeStarts[nodeId] = (
        w: start.w,
        h: start.h,
        touchedW: start.touchedW || horizontal,
        touchedH: start.touchedH || vertical,
      );
      _dragSizes[nodeId] = (
        w: horizontal
            ? clampResizeWidth(base.w + dxLocal, _innerWidth)
            : base.w,
        h: vertical
            ? clampResizeHeight(
                base.h + dyLocal,
                EditorMetrics.phoneInnerHeight,
              )
            : base.h,
      );
    });
  }

  /// Ends a resize gesture with a SINGLE commit (one undo entry): untouched
  /// axes report as null (stayed auto/unchanged), and touched axes equal to
  /// the stored size report as null too — so `setNodeSize` no-ops and a grab
  /// without movement writes no history. A grab that DID move fixes the
  /// touched dims at the dragged value even from auto (standard editor
  /// behavior). Always clears the gesture state.
  void _endResize(CanvasNode node) {
    final start = _resizeStarts.remove(node.id);
    final tentative = _dragSizes.remove(node.id);
    setState(() {});
    if (start == null || tentative == null) return;
    widget.onResizeNode?.call(
      node.id,
      start.touchedW && tentative.w != node.w ? tentative.w : null,
      start.touchedH && tentative.h != node.h ? tentative.h : null,
    );
  }

  /// Cancels a resize gesture: tentative state is dropped, the store is
  /// untouched, and the node snaps back to its stored size.
  void _cancelResize(String nodeId) {
    if (_dragSizes.remove(nodeId) != null || _resizeStarts.remove(nodeId) != null) {
      setState(() {});
    }
  }

  /// Inner stage width: the resolved per-screen device width.
  double get _innerWidth => specForScreenDevice(widget.screen.device).width;

  /// Nodes visible at the screen's own tier (see the [ScreenSurface] docs):
  /// hidden nodes — and a hidden row's whole subtree — are skipped live.
  List<CanvasNode> get _visibleNodes {
    final byId = {for (final n in widget.nodes) n.id: n};
    // A node is hidden when it — or any ancestor row up its parentId chain —
    // is hidden at this screen's width (cycle-safe via [seen]; mirrors the
    // preview player's cascade).
    bool effectivelyHidden(CanvasNode node) {
      CanvasNode? cursor = node;
      final seen = <String>{};
      while (cursor != null && seen.add(cursor.id)) {
        if (isNodeHiddenOnWidth(_innerWidth, cursor.hiddenOn)) return true;
        final parentId = cursor.parentId;
        cursor = parentId == null ? null : byId[parentId];
      }
      return false;
    }

    return [
      for (final node in widget.nodes)
        if (!effectivelyHidden(node)) node,
    ];
  }

  /// Root nodes for the flow: `parentId == null`, plus dangling-`parentId`
  /// nodes (parent id names no node on this screen) rendered as roots — the
  /// same honesty rule codegen uses, so corrupt docs never silently drop
  /// nodes. Self-parented and cyclic nodes stay excluded (they name a
  /// present node, so they are never roots and never reachable — cycle-safe
  /// by construction; `validateNesting` reports them).
  List<CanvasNode> get _rootNodes {
    final byId = {for (final n in widget.nodes) n.id: n};
    return [
      for (final node in _visibleNodes)
        if (node.parentId == null || !byId.containsKey(node.parentId)) node,
    ];
  }

  /// Visible direct children of [parentId] in document order (the same order
  /// as core `childrenOf`), excluding self-parents and ids already on the
  /// current build path ([ancestors]) so corrupt cyclic docs terminate.
  List<CanvasNode> _childNodes(String parentId, Set<String> ancestors) => [
    for (final node in _visibleNodes)
      if (node.parentId == parentId &&
          node.id != parentId &&
          !ancestors.contains(node.id))
        node,
  ];

  /// Whether [node] renders its children INSIDE its component chrome: a
  /// non-row node whose first item's kind is in [kContainerKinds]
  /// (`canvas/COMPOSITION.md` §2; the first-item rule is documented on
  /// [kContainerKinds] — nodes carry item lists, the spec names one kind).
  bool _isContainerNode(CanvasNode node) =>
      !node.isRow &&
      node.items.isNotEmpty &&
      kContainerKinds.contains(node.items.first.kind);

  /// Node items with the screen tier's [CanvasNode.breakpointValues] merged
  /// over each item's props (`{...item.props, ...overrides}` — the same rule
  /// as the preview player, applied per level). Empty overrides return the
  /// items untouched, so docs without overrides render exactly as before.
  List<CanvasItem> _nodeItems(CanvasNode node) {
    final overrides =
        node.breakpointValues[tierForWidth(_innerWidth).name];
    if (overrides == null || overrides.isEmpty) return node.items;
    return [
      for (final item in node.items)
        item.copyWith(props: {...item.props, ...overrides}),
    ];
  }

  /// Viewport-local rect of a laid-out node, or null before first layout.
  /// The origin is the screen top-left (inside the frame bezel); callers
  /// working in doc coords shift by [_scrollY] (see [_flowHit]).
  Rect? _nodeRect(String id, RenderBox screenBox) {
    final nodeContext = _flowKeys[id]?.currentContext;
    final box = nodeContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final topLeft = screenBox.globalToLocal(box.localToGlobal(Offset.zero));
    return Rect.fromLTWH(
      topLeft.dx - _kFrameBezel,
      topLeft.dy - _kFrameBezel,
      box.size.width,
      box.size.height,
    );
  }

  /// Shared insert/reorder path: resolves the pointer to a flow target plus
  /// a child index (by child midpoints along the target's axis — x for rows,
  /// y for containers and the root; empty targets yield 0) and the
  /// index-line position. Used identically by the hover visuals and the drop
  /// path so the line and the landing agree.
  ///
  /// Target rule (Track C2 nesting — COMPOSITION.md §4): the deepest
  /// container-or-row under the pointer wins (measured rects, smallest-area
  /// tiebreak, so nested targets resolve inward). Container-ness reuses
  /// [_isContainerNode] (the catalog [kContainerKinds] first-item rule —
  /// never re-derived here). Leaf nodes are never targets (even with
  /// children — their children render below, never inside chrome), so a
  /// pointer over a leaf falls through to the enclosing container-or-row or
  /// to the root. Every target kind carries a measured key (rows, containers
  /// and leaves all build through [_nodeChrome] or the row detector), so
  /// empty containers stay hit-testable through their chrome rect — no
  /// placeholder needed in the builders.
  _FlowHit _flowHit(Offset pointerDoc, RenderBox screenBox) {
    // Track X1 scroll: [pointerDoc] is in DOC coords (viewport pointer +
    // scroll offset). Measured rects arrive viewport-local from [_nodeRect]
    // and shift to doc for the math; the returned line/rect go back to
    // viewport for the overlay visuals. At scroll 0 doc == viewport, so the
    // unscrolled behavior is byte-identical to before.
    final scrollY = _scrollY;
    // Deepest container-or-row containing the pointer wins; smallest area
    // breaks ties so nested targets (row-in-card, card-in-row, 3-deep
    // chains) resolve inward.
    CanvasNode? hitTarget;
    Rect? hitRectVp;
    for (final node in _visibleNodes) {
      if (!node.isRow && !_isContainerNode(node)) continue;
      final rectVp = _nodeRect(node.id, screenBox);
      if (rectVp == null) continue;
      final rect =
          Rect.fromLTWH(rectVp.left, rectVp.top + scrollY, rectVp.width, rectVp.height);
      if (!rect.contains(pointerDoc)) continue;
      if (hitRectVp == null ||
          rect.width * rect.height <
              hitRectVp.width * hitRectVp.height) {
        hitTarget = node;
        hitRectVp = rectVp;
      }
    }
    if (hitTarget != null && hitRectVp != null) {
      final target = hitTarget;
      final targetRectVp = hitRectVp;
      final targetRectDoc = Rect.fromLTWH(
        targetRectVp.left,
        targetRectVp.top + scrollY,
        targetRectVp.width,
        targetRectVp.height,
      );
      final horizontal = target.isRow;
      final kids = [
        for (final node in _visibleNodes)
          if (node.parentId == target.id) node,
      ];
      final centers = <double>[];
      final starts = <double?>[];
      final ends = <double?>[];
      for (final kid in kids) {
        final rectVp = _nodeRect(kid.id, screenBox);
        if (rectVp == null) {
          // Pre-layout fallback: stored x/y (doc coords) as the center
          // proxy along the target's axis.
          centers.add(horizontal ? kid.x : kid.y);
          starts.add(null);
          ends.add(null);
        } else if (horizontal) {
          centers.add((rectVp.left + rectVp.right) / 2);
          starts.add(rectVp.left);
          ends.add(rectVp.right);
        } else {
          centers.add((rectVp.top + rectVp.bottom) / 2 + scrollY);
          starts.add(rectVp.top + scrollY);
          ends.add(rectVp.bottom + scrollY);
        }
      }
      final pointerMain = horizontal ? pointerDoc.dx : pointerDoc.dy;
      final index =
          flowInsertionIndex(pointerMain, centers).clamp(0, kids.length);
      final lineDoc = _boundary(
        pointerMain,
        index,
        starts,
        ends,
        horizontal ? targetRectDoc.left : targetRectDoc.top,
        horizontal ? targetRectDoc.right : targetRectDoc.bottom,
      );
      return _FlowHit(
        parentId: target.id,
        index: index,
        lineMain: horizontal ? lineDoc : lineDoc - scrollY,
        targetRect: targetRectVp,
        targetIsRow: horizontal,
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
      final rectVp = _nodeRect(root.id, screenBox);
      if (rectVp == null) {
        // Pre-layout fallback: stored y (doc coords) as the center proxy.
        centers.add(root.y);
        starts.add(null);
        ends.add(null);
      } else {
        centers.add((rectVp.top + rectVp.bottom) / 2 + scrollY);
        starts.add(rectVp.top + scrollY);
        ends.add(rectVp.bottom + scrollY);
      }
    }
    const edgeStartDoc = kFlowScreenPadding + _kStatusBarHeight;
    final index =
        flowInsertionIndex(pointerDoc.dy, centers).clamp(0, roots.length);
    return _FlowHit(
      parentId: null,
      index: index,
      lineMain: _boundary(
            pointerDoc.dy,
            index,
            starts,
            ends,
            edgeStartDoc,
            null,
          ) -
          scrollY,
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
    // Same hygiene for resize gestures (a node deleted mid-drag snaps shut).
    _dragSizes.removeWhere(
      (id, _) => !widget.nodes.any((node) => node.id == id),
    );
    _resizeStarts.removeWhere(
      (id, _) => !widget.nodes.any((node) => node.id == id),
    );
    final screenColor = _screenBackground(context, colors, widget.screen);
    final frame = PhoneFrame(
      screenColor: screenColor,
      // Outer body keeps the measured bezel budget (see [_kFrameBezel]).
      outerWidth: _innerWidth + EditorMetrics.phoneBezel * 2,
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
          //
          // Track X1 scroll: the stored landing is in DOC coords (viewport
          // pointer + scroll offset) so drops while scrolled land at the
          // right doc position and agree with the stored node axes.
          final scrollY = _scrollY;
          final position = Offset(
            local.dx - _kFrameBezel,
            local.dy - _kFrameBezel + scrollY,
          );
          // Magnetic snap applies to pointer drops only — `onAccept` itself
          // stays verbatim/unsnapped for programmatic callers, so the snapped
          // point is computed here and forwarded through `onDropKind`.
          // Guides track the actual stage width, not the phone default; the
          // center axis rides the scroll so snapped drops agree while
          // scrolled (identical to before at scroll 0).
          final snapped = snapDropPosition(
            position,
            _visibleNodes,
            centerX: _innerWidth / 2,
            centerY: scrollY + EditorMetrics.phoneInnerHeight / 2,
          );
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
                  final scrollY = _scrollY;
                  final pointer = Offset(
                    local.dx - _kFrameBezel,
                    local.dy - _kFrameBezel + scrollY,
                  );
                  guides = guidesForPointer(
                    pointer,
                    _visibleNodes,
                    centerX: _innerWidth / 2,
                    centerY:
                        scrollY + EditorMetrics.phoneInnerHeight / 2,
                  );
                  hover = _flowHit(pointer, box);
                }
              }
              final hoverHit = hover;
              final hoverRect = hover?.targetRect;
              // D3 drop preview: the dragged kind rides the DragTarget
              // candidate list; paired with the shared _flowHit so the ghost
              // previews exactly where the landing path would commit. Gated
              // on both (like the insert line), so it vanishes on
              // drop/cancel/leave with the guides.
              String? dragKind;
              for (final c in candidate) {
                if (c != null) {
                  dragKind = c;
                  break;
                }
              }
              final _DropGhostSpec? ghost =
                  (hoverHit != null && dragKind != null)
                      ? (
                          parentId: hoverHit.parentId,
                          index: hoverHit.index,
                          kind: dragKind,
                        )
                      : null;
              // A hovered container-or-row carries its own wash; otherwise the
              // whole screen washes while a drag hovers it.
              final hoveringTarget = hoverHit?.parentId != null;
              // Screen-tap selection lives OUTSIDE the node detectors: taps
              // on nodes are claimed by the inner leaf/row `onTap`s (which
              // win the arena as the deeper recognizer), so this fires only
              // for empty screen area.
              // Track X1 scroll: the flow rides a vertical scroll view (the
              // frame height stays fixed) with a top reserve for the overlaid
              // status bar, so over-tall content scrolls instead of clipping.
              // The scrollable is a plain (non-positioned) Stack child like
              // the old column, so the viewport layout is unchanged.
              final scrollY = _scrollY;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onSelectScreen,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: _kStatusBarHeight),
                      child: _buildFlow(colors, ghost: ghost),
                    ),
                    // Track X1 frame polish: overlaid status bar + floating
                    // home indicator (both pointer-transparent, token colors
                    // only). They sit above the hover washes so the device
                    // chrome reads while dragging.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _StatusBar(
                        colors: colors,
                        background: screenColor,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 134,
                            height: 5,
                            decoration: BoxDecoration(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (candidate.isNotEmpty && !hoveringTarget)
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
                      // Guides resolve in doc coords (see [_flowHit]); shift
                      // back to viewport for the overlay.
                      top: guides.y! - scrollY,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: colors.toolbarActive.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    if (!widget.selected) return frame;
    // Overlay ring: `Positioned.fill` adds no size, so selecting a screen
    // never shifts the fixed content box (a border on the wrapper would add
    // 4px and overflow the zoom `FittedBox`).
    return Stack(
      children: [
        frame,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              key: screenSelectedKey(widget.screen.id),
              decoration: BoxDecoration(
                border: Border.all(color: colors.toolbarActive, width: 2),
                borderRadius: BorderRadius.circular(
                  EditorMetrics.phoneOuterRadius + 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Screen content: padded top-left column of root nodes (doc order).
  /// Root leaves ignore `expand`/`flex` (W3): they render unwrapped.
  /// Tier-hidden nodes are skipped (see [_visibleNodes]). Every root builds
  /// through [_buildNodeWidget] so nesting applies at any depth; childless
  /// nodes take the exact pre-composition path.
  ///
  /// D3 drop preview: when [ghost] targets the screen root (`parentId ==
  /// null`), the ghost splices into the root column at the hover index (same
  /// mapping as the landing path), joined with the usual separators.
  Widget _buildFlow(EditorColors colors, {_DropGhostSpec? ghost}) {
    final roots = _rootNodes;
    final items = <Widget>[
      for (final root in roots)
        _buildNodeWidget(root, colors, {root.id}, ghost: ghost),
    ];
    if (ghost != null && ghost.parentId == null) {
      items.insert(
        ghost.index.clamp(0, items.length),
        _DropGhostBox(colors: colors, kind: ghost.kind),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(kFlowScreenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: kFlowScreenGap),
            items[i],
          ],
        ],
      ),
    );
  }

  /// Recursive node dispatcher (Track C1 composition — COMPOSITION.md §1).
  ///
  /// [ancestors] holds the ids on the current build path including [node]'s
  /// own (roots seed `{root.id}`); children build with the extended set, so
  /// corrupt cycles can never loop forever. Rows keep their horizontal
  /// semantics at any depth; containers receive built children inside their
  /// chrome; leaves with children get the fallback `Column([own,
  /// ...children])`; childless nodes return [_buildLeaf] untouched.
  ///
  /// Track U2: cells ride [_rowCell] (live drag width, else [wrapRowChild]);
  /// the row container honors the node's own `w`/`h`, and the selected row
  /// gains resize handles via [_withHandles].
  ///
  /// D3 drop preview: [ghost] threads through every level untouched (only the
  /// matching target splices it in). An empty container targeted by the drag
  /// routes to [_buildContainer] so the ghost still previews inside its
  /// chrome instead of taking the childless [_buildLeaf] path.
  Widget _buildNodeWidget(
    CanvasNode node,
    EditorColors colors,
    Set<String> ancestors, {
    _DropGhostSpec? ghost,
  }) {
    if (node.isRow) return _buildRow(node, colors, ancestors: ancestors, ghost: ghost);
    final kids = _childNodes(node.id, ancestors);
    if (kids.isEmpty) {
      if (ghost != null &&
          ghost.parentId == node.id &&
          _isContainerNode(node)) {
        return _buildContainer(node, colors, ancestors, kids, ghost: ghost);
      }
      return _buildLeaf(node, colors);
    }
    if (_isContainerNode(node)) {
      return _buildContainer(node, colors, ancestors, kids, ghost: ghost);
    }
    return _buildLeafFallback(node, colors, ancestors, kids, ghost: ghost);
  }

  /// One row cell (Track U2, fill Track X1): the live drag width wins while
  /// a handle drags, else the [wrapRowChild] rule (fixed `w` → exact pixels,
  /// auto → equal flex share). Both fixed paths ride [applyNodeSizeValues]
  /// so the cell fills its pixels. Keeps gesture preview and committed
  /// render on one path.
  Widget _rowCell(CanvasNode kid, Widget built) {
    final dragW = _dragSizes[kid.id]?.w;
    if (dragW != null) return applyNodeSizeValues(dragW, null, built);
    return wrapRowChild(kid, built);
  }

  /// Overlays the Track U2 resize handles on the SELECTED node's chrome
  /// (leaves, containers, and rows alike — callers pass their chrome box).
  ///
  /// Handles sit INSIDE the chrome edges (a `Stack` clips half-outside
  /// handles, so half-outside placement is not cheap here): right-middle
  /// (width), bottom-middle (height), and bottom-right corner (both). Only
  /// the selected node gets handles; anything else returns [chrome]
  /// untouched, so selection/tap behavior is unchanged for unselected nodes.
  /// Cursor previews the axis ([SystemMouseCursors.resizeRight]/[resizeDown]/
  /// [resizeDownRight]); the gesture math divides by [ScreenSurface.zoom]
  /// (see [resizeDeltaToLocal]).
  ///
  /// Track X1: while a resize drag is live a token-styled WxH readout chip
  /// floats at the chrome's top-right (pointer-transparent, so it never
  /// steals the gesture).
  Widget _withHandles(CanvasNode node, Widget chrome) {
    if (node.id != widget.selectedNodeId) return chrome;
    final tentative = _dragSizes[node.id];
    return Stack(
      children: [
        chrome,
        // Edge strips stop one hit-size short of the corner so the three
        // pads never overlap (overlapping pads let the later sibling steal
        // the gesture and pin the wrong axis).
        Positioned(
          top: 0,
          bottom: _kHandleHitSize,
          right: 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: _resizeHandle(
              node: node,
              edge: 'right',
              cursor: SystemMouseCursors.resizeRight,
              horizontal: true,
              vertical: false,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: _kHandleHitSize,
          bottom: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _resizeHandle(
              node: node,
              edge: 'bottom',
              cursor: SystemMouseCursors.resizeDown,
              horizontal: false,
              vertical: true,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: _resizeHandle(
            node: node,
            edge: 'corner',
            cursor: SystemMouseCursors.resizeDownRight,
            horizontal: true,
            vertical: true,
          ),
        ),
        if (tentative != null)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                key: resizeReadoutKey(node.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: EditorTheme.of(context).surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tentative.w.round()}×${tentative.h.round()}',
                  style: EditorType.readout.copyWith(
                    color: EditorTheme.of(context).onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One resize handle (Track U2, grab area Track X1): pan events drive
  /// [_updateResize] in screen-local px; release commits once via [_endResize].
  /// The pan recognizer owns the gesture on move (content taps underneath are
  /// suppressed mid-drag); a tap without movement re-selects the already
  /// selected node, which is harmless.
  ///
  /// Usability: the gesture target is a [_kHandleHitSize] transparent pad
  /// while only the centered [_kHandleVisualSize] square paints, so the grab
  /// area is finger-friendly without changing the chrome's visual language.
  Widget _resizeHandle({
    required CanvasNode node,
    required String edge,
    required MouseCursor cursor,
    required bool horizontal,
    required bool vertical,
  }) {
    final colors = EditorTheme.of(context);
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _beginResize(node),
        onPanUpdate: (details) => _updateResize(
          node.id,
          resizeDeltaToLocal(details.delta.dx, widget.zoom),
          resizeDeltaToLocal(details.delta.dy, widget.zoom),
          horizontal: horizontal,
          vertical: vertical,
        ),
        onPanEnd: (_) => _endResize(node),
        onPanCancel: () => _cancelResize(node.id),
        child: Container(
          key: resizeHandleKey(node.id, edge),
          width: _kHandleHitSize,
          height: _kHandleHitSize,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: _kHandleVisualSize,
            height: _kHandleVisualSize,
            decoration: BoxDecoration(
              color: colors.toolbarActive,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: colors.surface, width: 1),
            ),
          ),
        ),
      ),
    );
  }
  /// One row container: full-width tap target (selects the row for gap
  /// editing) around a `Row` of its children (doc order, node `gap`
  /// separators) with W3 alignment (`mainAxis` null → start, `crossAxis`
  /// null → center). Children build through [_buildNodeWidget] so rows nest
  /// at any depth (row-in-row, row-in-container); each rides [wrapRowChild]
  /// so it gets a finite width share — kit widgets with internal `Expanded`
  /// rows (e.g. `TextField`) would detonate on the `Row`'s unbounded width
  /// otherwise. `expand`/`flex` keep working for row children at any depth;
  /// container children ignore them (vertical stack, like root).
  ///
  /// `crossAxis == stretch` wraps the Row in [IntrinsicHeight]: a Row with
  /// stretch inside the screen Column (which measures children with
  /// unbounded height) asserts without a tight cross-axis height, and
  /// IntrinsicHeight supplies it from the tallest child.
  ///
  /// D3 drop preview: when [ghost] targets this row, the ghost splices into
  /// the strip at the hover index (a [Flexible] cell like any other child,
  /// so it takes a finite width share); an empty targeted row renders the
  /// ghost in place of the placeholder.
  Widget _buildRow(
    CanvasNode node,
    EditorColors colors, {
    Set<String> ancestors = const {},
    _DropGhostSpec? ghost,
  }) {
    final next = {...ancestors, node.id};
    final kids = _childNodes(node.id, next);
    // Clamp defensive: a negative stored gap must never size a separator.
    final gap = math.max(0.0, node.gap);
    final cross = rowCrossAxis(node.crossAxis);
    final _DropGhostSpec? rowGhost =
        (ghost != null && ghost.parentId == node.id) ? ghost : null;
    Widget body;
    if (kids.isEmpty && rowGhost == null) {
      body = _EmptyRowPlaceholder(colors: colors);
    } else {
      final cells = <Widget>[
        for (final kid in kids)
          _rowCell(
            kid,
            _buildNodeWidget(kid, colors, next, ghost: ghost),
          ),
      ];
      if (rowGhost != null) {
        cells.insert(
          rowGhost.index.clamp(0, cells.length),
          Flexible(
            child: _DropGhostBox(
              colors: colors,
              kind: rowGhost.kind,
              horizontal: true,
            ),
          ),
        );
      }
      Widget row = Row(
        mainAxisAlignment: rowMainAxis(node.mainAxis),
        crossAxisAlignment: cross,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            cells[i],
          ],
        ],
      );
      if (cross == CrossAxisAlignment.stretch && cells.isNotEmpty) {
        row = IntrinsicHeight(child: row);
      }
      body = row;
    }
    return _withHandles(
      node,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelectNode?.call(node.id),
        child: Container(
          key: _flowKey(node.id),
          // Track U2: a fixed `w` pins the container (cells share the pinned
          // width); auto keeps full-bleed. A fixed `h` pins the body height;
          // auto stays intrinsic.
          width: _effW(node) ?? double.infinity,
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
          child: applyNodeSizeValues(null, _effH(node), body),
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
  /// Nested taps claim the deepest node (see [_selectionClaim]) so a child
  /// tap never ends on an ancestor.
  Widget _buildLeaf(CanvasNode node, EditorColors colors) {
    return _nodeChrome(
      node,
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        // Track X1 fill: pinned dims stretch so the paint fills the box
        // (see [_contentCrossAxis]); auto keeps `start`.
        crossAxisAlignment: _contentCrossAxis(node),
        children: [
          for (final item in _nodeItems(node))
            buildCatalogItem(item.kind, item.props),
        ],
      ),
    );
  }

  /// Shared node-chrome wrapper for container and fallback nodes: the exact
  /// [_buildLeaf] selection affordances (claim-guarded [Listener],
  /// [GestureDetector], key, padding, selection ring, content clamp) around
  /// [content]. Keeps nested nodes' tap/selection/clamp semantics identical
  /// to roots — the "same builder path" rule.
  Widget _nodeChrome(CanvasNode node, EditorColors colors, Widget content) {
    void select() {
      if (!widget.panMode) widget.onSelectNode?.call(node.id);
    }

    return _withHandles(
      node,
      Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _claimSelect(node, event.pointer),
        onPointerUp: (event) => _releaseClaim(event.pointer),
        onPointerCancel: (event) => _releaseClaim(event.pointer),
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
                  _innerWidth - node.x,
                ),
                maxHeight: math.max(
                  _kMinNodeExtent,
                  EditorMetrics.phoneInnerHeight - node.y,
                ),
              ),
              // Track U2: explicit sizes pin the content (inside the legacy
              // max clamp, which keeps guarding far-edge drops); auto passes
              // through untouched.
              child: applyNodeSizeValues(_effW(node), _effH(node), content),
            ),
          ),
        ),
      ),
    );
  }

  /// One container node ([_isContainerNode]): the first item's builder
  /// receives the built children spliced into its spec slot; any further own
  /// items stack below the chrome (see [kContainerKinds]). Children build
  /// through [_buildNodeWidget] (props/tier/hidden semantics apply
  /// recursively) and stack vertically with [kFlowScreenGap] separators.
  ///
  /// D3 drop preview: when [ghost] targets this container, the ghost splices
  /// into the slot's child list at the hover index, so it renders inside the
  /// real chrome with the catalog's own separators.
  Widget _buildContainer(
    CanvasNode node,
    EditorColors colors,
    Set<String> ancestors,
    List<CanvasNode> kids, {
    _DropGhostSpec? ghost,
  }) {
    final next = {...ancestors, node.id};
    final items = _nodeItems(node);
    final builtKids = <Widget>[
      for (final kid in kids)
        _buildNodeWidget(kid, colors, next, ghost: ghost),
    ];
    if (ghost != null && ghost.parentId == node.id) {
      builtKids.insert(
        ghost.index.clamp(0, builtKids.length),
        _DropGhostBox(colors: colors, kind: ghost.kind),
      );
    }
    return _nodeChrome(
      node,
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        // Track X1 fill (see [_contentCrossAxis]).
        crossAxisAlignment: _contentCrossAxis(node),
        children: [
          buildCatalogItem(items.first.kind, items.first.props, builtKids),
          for (final item in items.skip(1))
            buildCatalogItem(item.kind, item.props),
        ],
      ),
    );
  }

  /// One leaf-with-children node (kind NOT in [kContainerKinds]): the §1
  /// fallback `Column([ownWidget, ...children])` — children stack BELOW the
  /// parent's own widget with [kFlowScreenGap] separators, never inside
  /// chrome. D3 drop preview: [ghost] forwards to the children (a targeted
  /// container may nest under a leaf via the below-fallback).
  Widget _buildLeafFallback(
    CanvasNode node,
    EditorColors colors,
    Set<String> ancestors,
    List<CanvasNode> kids, {
    _DropGhostSpec? ghost,
  }) {
    final next = {...ancestors, node.id};
    return _nodeChrome(
      node,
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        // Track X1 fill (see [_contentCrossAxis]).
        crossAxisAlignment: _contentCrossAxis(node),
        children: [
          for (final item in _nodeItems(node))
            buildCatalogItem(item.kind, item.props),
          for (var i = 0; i < kids.length; i++) ...[
            const SizedBox(height: kFlowScreenGap),
            _buildNodeWidget(kids[i], colors, next, ghost: ghost),
          ],
        ],
      ),
    );
  }

  /// 2px index line spanning the hovered target's cross axis: horizontal
  /// across the content for the root column and for vertical (container)
  /// targets, vertical across the row for a row target. Gated on `candidate`
  /// via the caller, so it vanishes on drop/leave with the guides.
  Widget _buildInsertLine(_FlowHit hit, EditorColors colors) {
    if (hit.parentId == null || !hit.targetIsRow) {
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
        left: rect.left,
        width: rect.width,
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

/// In-chrome drop-preview ghost (Track D3): a lightweight dashed box carrying
/// the dragged kind's label, rendered at the hover insertion index INSIDE the
/// target chrome (container slot, row strip, or root column) while a palette
/// drag hovers. Deliberately cheaper than the dragged tile mini: no catalog
/// build, no measurement — just chrome + label. `IgnorePointer`d so it never
/// claims taps/selection; keyed [kDropPreviewKey] for tests. The existing
/// insert line is untouched and stays the axis indicator.
class _DropGhostBox extends StatelessWidget {
  final EditorColors colors;
  final String kind;

  /// Row targets lay children out horizontally: drop the full-width fill so
  /// the ghost takes a finite share inside the strip instead.
  final bool horizontal;

  const _DropGhostBox({
    required this.colors,
    required this.kind,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: kDropPreviewKey,
        width: horizontal ? null : double.infinity,
        constraints: BoxConstraints(
          minHeight: 56,
          minWidth: horizontal ? 96 : 0,
        ),
        child: CustomPaint(
          painter: _DashedOutline(
            color: colors.toolbarActive.withValues(alpha: 0.7),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Drop $kind here',
                style: EditorType.field.copyWith(color: colors.toolbarActive),
              ),
            ),
          ),
        ),
      ),
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
