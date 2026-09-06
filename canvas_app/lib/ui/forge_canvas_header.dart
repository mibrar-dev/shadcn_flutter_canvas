/// Forge canvas header row (Track Y4, FORGE.md §1-3a–3c, §1-3g, §3, §4.2).
///
/// Transparent ~48px row over the dotted canvas: the breadcrumb trail
/// (`meta.title › screen name › <Kind> · <id>`), the compact per-screen
/// device strip, and the zoom pill ([ZoomControls] with the snap-guides grid
/// toggle).
///
/// Stateless vs the store, like [ForgeTopbar]: the trail arrives as prebuilt
/// props (the `<Kind> · <id>` idiom mirrors the inspector's
/// `_nodeShortLabel`; the header takes the label as a string and never
/// imports the inspector or the store), and every interaction leaves through
/// callbacks — the widget never imports the store, so it is widget-testable
/// without a shell. Screen taps call [onSelectScreen] and node taps call
/// [onSelectNode], the same callbacks the shell already wires to the canvas.
/// Device taps call [onDeviceChanged] with the preset id (null for phone, the
/// sparse-doc default — the same contract as [ScreenLabel]); the shell
/// forwards it to `store.setScreenDevice` at the Y6 cutover.
///
/// Token rule: chrome reads [EditorColors]/[EditorType] only — no hex
/// literals. The 13/400 crumb + 13/600 screen styles are inline const
/// [TextStyle]s with token colors (FORGE.md §3 APPROXIMATE; the same idiom as
/// [ForgeTopbar]). All §3 numbers are APPROXIMATE per FORGE.md §6
/// (structure/callbacks are tested, not pixels).
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;

import 'device_picker.dart';
import 'editor_tokens.dart';
import 'zoom_controls.dart';

/// Canvas header row height. APPROXIMATE ~48px (FORGE.md §3).
const double kForgeCanvasHeaderHeight = 48;

/// Forge canvas header: breadcrumb + device strip + zoom pill. See the
/// library doc for the data flow.
class ForgeCanvasHeader extends StatelessWidget {
  /// Project title for the first crumb (`doc.meta.title`).
  final String projectTitle;

  /// Currently selected screen id (shell-owned).
  final String screenId;

  /// Currently selected screen name (shell-owned).
  final String screenName;

  /// Tap on the screen crumb: the shell selects this screen (same path as a
  /// canvas screen tap — node selection clears, screen selection sets).
  final ValueChanged<String?>? onSelectScreen;

  /// Currently selected node id (shell-owned; null when none).
  final String? selectedNodeId;

  /// Prebuilt selected-node label (`<Kind> · <id>`, e.g. `Card · card_1`).
  /// Null hides the node crumb.
  final String? selectedNodeLabel;

  /// Tap on the node crumb: the shell reselects this node (same
  /// `onSelectNode` callback the canvas uses).
  final ValueChanged<String?>? onSelectNode;

  /// Current zoom fraction (1.0 means 100%), forwarded to [ZoomControls].
  final double zoom;

  /// Zoom in one step (shell-owned zoom state, like today).
  final VoidCallback onZoomIn;

  /// Zoom out one step.
  final VoidCallback onZoomOut;

  /// Fit the screen into view.
  final VoidCallback onFit;

  /// Whether snap guides are on. Renders the grid toggle's active state.
  /// Defaults to true, matching [ZoomControls] and the canvas default.
  final bool showGuides;

  /// Grid-icon toggle: called with the flipped [showGuides] value. The shell
  /// owns the flag (same shell-owned pattern as the zoom value).
  final ValueChanged<bool>? onShowGuidesChanged;

  /// Per-screen device id (a `PreviewDeviceSpec` id); null = phone default.
  final String? screenDevice;

  /// Called with the tapped device id (null for phone). The shell forwards
  /// it to `store.setScreenDevice` for the current screen.
  final ValueChanged<String?>? onDeviceChanged;

  const ForgeCanvasHeader({
    super.key,
    required this.projectTitle,
    required this.screenId,
    required this.screenName,
    this.onSelectScreen,
    this.selectedNodeId,
    this.selectedNodeLabel,
    this.onSelectNode,
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    this.showGuides = true,
    this.onShowGuidesChanged,
    this.screenDevice,
    this.onDeviceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      height: kForgeCanvasHeaderHeight,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _breadcrumb(colors)),
          _deviceStrip(colors),
          const SizedBox(width: 12),
          ZoomControls(
            zoom: zoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onFit: onFit,
            showGuides: showGuides,
            onShowGuidesChanged: onShowGuidesChanged,
          ),
        ],
      ),
    );
  }

  /// Breadcrumb 13/400 muted with the screen name 13/600 dark (FORGE.md §3).
  /// The node crumb renders only when a labelled selection exists.
  Widget _breadcrumb(EditorColors colors) {
    final nodeId = selectedNodeId;
    final nodeLabel = selectedNodeLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            projectTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        _separator(colors),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelectScreen?.call(screenId),
          child: Text(
            screenName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EditorType.readout.copyWith(color: colors.onSurface),
          ),
        ),
        if (nodeId != null && nodeLabel != null) ...[
          _separator(colors),
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectNode?.call(nodeId),
              child: Text(
                nodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
                        .copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _separator(EditorColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '›',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)
            .copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }

  /// Compact device strip (FORGE.md §1-3g): the [ScreenLabel] device buttons
  /// over the same [kPreviewDevices] specs and the same phone-defaults-to-
  /// null contract, without the name/dims text the breadcrumb replaces.
  /// Styled with the exact [ScreenLabel] idiom (28px segments, kit tooltip +
  /// ghost icon button) so the strip reads as the moved control, not a new
  /// one.
  Widget _deviceStrip(EditorColors colors) {
    final spec = specForScreenDevice(screenDevice);
    final activeId = spec.id;
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
          ),
        ],
      ],
    );
  }

  Widget _deviceButton({
    required EditorColors colors,
    required PreviewDeviceSpec device,
    required bool selected,
    required bool first,
    required bool last,
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
          onPressed: () => onDeviceChanged?.call(
            device.id == kPreviewDevicePhone.id ? null : device.id,
          ),
          size: shadcn.ButtonSize.small,
          density: shadcn.ButtonDensity.compact,
        ),
      ),
    );
  }
}
