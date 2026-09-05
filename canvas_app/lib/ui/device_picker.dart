/// Preview device presets + picker UI for [PreviewPlayer].
///
/// Our own device-frame picker: `device_preview` was deliberately NOT added
/// (only 1.3.1 resolves on Flutter 3.44.6; 3.0.0 needs ≥3.47; the 2.x line
/// has known web gesture bugs — see the W4 report). Four base presets plus a
/// landscape toggle cover all six target geometries:
///
/// - phone 390×844, phone landscape 844×390
/// - tablet 768×1024, tablet landscape 1024×768
/// - desktop fluid 1100 (frameless), desktop wide 1440 (frameless)
///
/// Mobile/tablet stages render in a bezel-ish rounded frame (see
/// `preview_player.dart`, using [EditorTokens]); desktop stays frameless
/// fluid. Chrome here uses the shared editor primitives ([EditorSegmented],
/// [EditorIconButton]), so it stays token-styled with the rest of the shell.
library;

import 'package:flutter/material.dart';

import 'editor_buttons.dart';

/// One preview device preset.
///
/// [width] is the logical stage width; [height] is the fixed stage height
/// for framed devices, or null for frameless fluid stages (desktop) that
/// fill the available height. [framed] selects the bezel frame.
@immutable
class PreviewDeviceSpec {
  /// Stable id (`phone`, `tablet`, `desktop-fluid`, `desktop-wide`).
  final String id;

  /// Human label, also used as the picker tooltip.
  final String label;

  /// Logical stage width.
  final double width;

  /// Fixed stage height, or null for fluid-fill stages.
  final double? height;

  /// Picker glyph.
  final IconData icon;

  /// Whether the stage renders in a bezel-ish rounded frame.
  final bool framed;

  const PreviewDeviceSpec({
    required this.id,
    required this.label,
    required this.width,
    this.height,
    required this.icon,
    required this.framed,
  });

  PreviewDeviceSpec _copyWith({double? width, double? height}) =>
      PreviewDeviceSpec(
        id: id,
        label: label,
        width: width ?? this.width,
        height: height ?? this.height,
        icon: icon,
        framed: framed,
      );
}

/// Phone portrait 390×844, framed.
const kPreviewDevicePhone = PreviewDeviceSpec(
  id: 'phone',
  label: 'Phone 390×844',
  width: 390,
  height: 844,
  icon: Icons.smartphone,
  framed: true,
);

/// Tablet portrait 768×1024, framed.
const kPreviewDeviceTablet = PreviewDeviceSpec(
  id: 'tablet',
  label: 'Tablet 768×1024',
  width: 768,
  height: 1024,
  icon: Icons.tablet_mac,
  framed: true,
);

/// Desktop fluid 1100, frameless (fills height).
const kPreviewDeviceDesktopFluid = PreviewDeviceSpec(
  id: 'desktop-fluid',
  label: 'Desktop fluid 1100',
  width: 1100,
  icon: Icons.desktop_windows_outlined,
  framed: false,
);

/// Desktop wide 1440, frameless (fills height).
const kPreviewDeviceDesktopWide = PreviewDeviceSpec(
  id: 'desktop-wide',
  label: 'Desktop 1440',
  width: 1440,
  icon: Icons.desktop_mac_outlined,
  framed: false,
);

/// Base presets in picker order: phone, tablet, desktop fluid, desktop wide.
const List<PreviewDeviceSpec> kPreviewDevices = [
  kPreviewDevicePhone,
  kPreviewDeviceTablet,
  kPreviewDeviceDesktopFluid,
  kPreviewDeviceDesktopWide,
];

/// Applies the landscape toggle: framed presets (phone/tablet) swap to
/// 844×390 / 1024×768; frameless desktop presets are returned unchanged.
PreviewDeviceSpec resolveDevice(
  PreviewDeviceSpec base, {
  required bool landscape,
}) {
  if (!landscape || !base.framed) return base;
  final height = base.height;
  if (height == null) return base;
  return base._copyWith(width: height, height: base.width);
}

/// Segmented device strip + landscape toggle for the preview top bar.
///
/// Icons/tooltips intentionally keep `Icons.smartphone` (phone) and
/// `Icons.desktop_windows_outlined` (desktop fluid) so the original
/// two-segment toggle tests keep passing against the new strip.
class DevicePicker extends StatelessWidget {
  /// Index into [kPreviewDevices] of the selected preset.
  final int selectedIndex;

  /// Called with the tapped preset index.
  final ValueChanged<int> onSelect;

  /// Whether the landscape toggle is on (phone/tablet swap dimensions).
  final bool landscape;

  /// Called when the rotate toggle flips. The toggle disables itself when a
  /// frameless desktop preset is selected (nothing to rotate).
  final ValueChanged<bool> onLandscapeChanged;

  const DevicePicker({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.landscape,
    required this.onLandscapeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFramed = kPreviewDevices[selectedIndex].framed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorSegmented(
          items: [
            for (final device in kPreviewDevices)
              EditorSegmentItem(icon: device.icon, tooltip: device.label),
          ],
          selectedIndex: selectedIndex,
          onSelect: onSelect,
        ),
        const SizedBox(width: 4),
        EditorIconButton(
          icon: Icons.screen_rotation,
          tooltip: landscape
              ? 'Landscape on — tap for portrait'
              : 'Rotate to landscape',
          // Desktop presets are frameless fluid: no landscape variant.
          onPressed: isFramed ? () => onLandscapeChanged(!landscape) : null,
        ),
      ],
    );
  }
}
