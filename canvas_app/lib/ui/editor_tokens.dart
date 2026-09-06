/// Editor-chrome design tokens, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport via
/// `getComputedStyle`. These describe the EDITOR SHELL only — the parts on
/// the canvas stay shadcn registry widgets (see `component_catalog.dart`).
///
/// Every value here is a measured number, not a guess. When adjusting, re-measure
/// against the reference rather than eyeballing.
///
/// Track FF (BUILD_SPEC §9.3 FF1) adds `railBg`, `railActiveIndicator`,
/// `panelBg`, `canvasBackdrop`, `selectionOutline`, `groupHeaderFg` plus the
/// `ff*` metrics. Those are marked APPROXIMATE per the measured-spec rule
/// (HARD rule: never eyeball-promote them) and re-measured in Track H. No
/// pre-existing value was touched.
library;

import 'package:flutter/widgets.dart';

/// Editor chrome colors. Dark is the reference default; light mirrors it.
class EditorColors {
  /// App background and canvas surface. Reference: rgb(20, 19, 23).
  final Color surface;

  /// Palette tile / raised container. Reference: rgb(28, 27, 31).
  final Color surfaceContainer;

  /// Search field, inactive segmented chip. Reference: rgb(43, 41, 45).
  final Color surfaceContainerHigh;

  /// Primary body text. Reference: rgb(228, 225, 231).
  final Color onSurface;

  /// Icons, secondary labels. Reference: rgb(201, 196, 209).
  final Color onSurfaceVariant;

  /// Disabled icon (undo/redo when empty). Reference: rgb(73, 69, 80).
  final Color disabled;

  /// Active icon-rail item background. Reference: rgb(75, 66, 93).
  final Color railActive;

  /// Active icon-rail item foreground. Reference: rgb(233, 221, 253).
  final Color onRailActive;

  /// Active toolbar segment background. Reference: rgb(210, 188, 252).
  final Color toolbarActive;

  /// Active toolbar segment foreground. Reference: rgb(50, 34, 111).
  final Color onToolbarActive;

  /// Phone bezel. Reference: rgb(228, 225, 231).
  final Color bezel;

  /// Forge accent (Export action, links). APPROXIMATE from the Forge
  /// reference description (FORGE.md §2): light `#2563EB`, dark a lighter
  /// blue `#60A5FA`. Y-waves re-measure and pin.
  final Color accent;

  /// Text/icons on [accent]. White in both modes.
  final Color onAccent;

  /// Destructive actions (inspector Delete). APPROXIMATE (FORGE.md §2):
  /// light `#DC2626`, dark `#F87171`.
  final Color danger;

  /// FlutterFlow-chrome rail background (BUILD_SPEC §9.1, FF1). APPROXIMATE,
  /// FlutterFlow-like neutral: light `#FFFFFF`, dark `#1E1D20`.
  final Color railBg;

  /// FlutterFlow-chrome rail active-destination indicator (BUILD_SPEC §9.1,
  /// FF1). APPROXIMATE, follows the accent ramp: light `#2563EB`,
  /// dark `#60A5FA`.
  final Color railActiveIndicator;

  /// FlutterFlow-chrome side panel background (BUILD_SPEC §9.1, FF1).
  /// APPROXIMATE: light `#FFFFFF`, dark `#1C1B1F`.
  final Color panelBg;

  /// FlutterFlow-chrome neutral canvas backdrop (BUILD_SPEC §9.1, FF1).
  /// APPROXIMATE: light `#E8ECF1`, dark `#0F0E11`.
  final Color canvasBackdrop;

  /// FlutterFlow-chrome canvas selection outline (BUILD_SPEC §9.1, FF1).
  /// APPROXIMATE, follows the accent ramp: light `#2563EB`,
  /// dark `#60A5FA`.
  final Color selectionOutline;

  /// FlutterFlow-chrome grouped-panel section header foreground (BUILD_SPEC
  /// §9.1, FF1). APPROXIMATE: light `#6B7280`, dark `#9CA3AF`.
  final Color groupHeaderFg;

  const EditorColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.disabled,
    required this.railActive,
    required this.onRailActive,
    required this.toolbarActive,
    required this.onToolbarActive,
    required this.bezel,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.railBg,
    required this.railActiveIndicator,
    required this.panelBg,
    required this.canvasBackdrop,
    required this.selectionOutline,
    required this.groupHeaderFg,
  });

  /// Measured directly from the reference in its default (dark) theme.
  static const dark = EditorColors(
    surface: Color(0xFF141317),
    surfaceContainer: Color(0xFF1C1B1F),
    surfaceContainerHigh: Color(0xFF2B292D),
    onSurface: Color(0xFFE4E1E7),
    onSurfaceVariant: Color(0xFFC9C4D1),
    disabled: Color(0xFF494550),
    railActive: Color(0xFF4B425D),
    onRailActive: Color(0xFFE9DDFD),
    toolbarActive: Color(0xFFD2BCFC),
    onToolbarActive: Color(0xFF32226F),
    bezel: Color(0xFFE4E1E7),
    accent: Color(0xFF60A5FA),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFF87171),
    railBg: Color(0xFF1E1D20),
    railActiveIndicator: Color(0xFF60A5FA),
    panelBg: Color(0xFF1C1B1F),
    canvasBackdrop: Color(0xFF0F0E11),
    selectionOutline: Color(0xFF60A5FA),
    groupHeaderFg: Color(0xFF9CA3AF),
  );

  /// Light counterpart, measured from the reference's light mode (body
  /// `#FEF7FF` / `#1D1B20`, app-root gaps `#F3EDF7`) with the same role
  /// structure as [dark]. Tiles and the canvas well use `#F7F2FA`.
  static const light = EditorColors(
    surface: Color(0xFFFEF7FF),
    surfaceContainer: Color(0xFFF7F2FA),
    surfaceContainerHigh: Color(0xFFECE6F0),
    onSurface: Color(0xFF1D1B20),
    onSurfaceVariant: Color(0xFF49454F),
    disabled: Color(0xFFCAC4D0),
    railActive: Color(0xFFE8DEF8),
    onRailActive: Color(0xFF1D192B),
    toolbarActive: Color(0xFF6750A4),
    onToolbarActive: Color(0xFFFFFFFF),
    bezel: Color(0xFF322F35),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    railBg: Color(0xFFFFFFFF),
    railActiveIndicator: Color(0xFF2563EB),
    panelBg: Color(0xFFFFFFFF),
    canvasBackdrop: Color(0xFFE8ECF1),
    selectionOutline: Color(0xFF2563EB),
    groupHeaderFg: Color(0xFF6B7280),
  );
}

/// Measured layout metrics. Names match the reference's visual elements.
class EditorMetrics {
  EditorMetrics._();

  /// Left aside total width (rail + parts panel). Measured: 320.
  static const double sidePanelWidth = 320;

  /// Right aside (prompt panel) width. Measured: 320.
  static const double promptPanelWidth = 320;

  /// Icon rail column width. Measured: 52 (44 button + 4 inset each side).
  static const double railWidth = 52;

  /// Icon rail button box. Measured: 44x44, border-radius 22.
  static const double railButtonSize = 44;

  /// Vertical step between rail buttons in a group. Measured: 118-68 = 50.
  static const double railButtonStep = 50;

  /// Extra vertical space between rail groups. Measured: 178-118 = 60, so
  /// the group gap adds 10 on top of [railButtonStep].
  static const double railGroupGap = 10;

  /// First rail button top offset. Measured: y=68.
  static const double railTopInset = 68;

  /// Parts search field. Measured: 244x40 at x=64, radius 20.
  static const double searchWidth = 244;
  static const double searchHeight = 40;
  static const double searchRadius = 20;

  /// Parts panel content left inset. Measured: x=64 (52 rail + 12).
  static const double panelInset = 12;

  /// Palette tile. Measured: 114x72, radius 16, column step 120 (gap 6).
  static const double tileWidth = 114;
  static const double tileHeight = 72;
  static const double tileRadius = 16;
  static const double tileGap = 6;

  /// Center floating toolbar. Measured: height 40, top y=20.
  static const double toolbarHeight = 40;
  static const double toolbarTop = 20;

  /// Toolbar icon button box. Measured: 40x40, radius 20.
  static const double toolbarButtonSize = 40;

  /// Gap inside the select/pan segmented pair. Measured: 572-(529+40) = 3.
  static const double segmentGap = 3;

  /// Gap between toolbar groups. Measured: 634-(572+40) = 22.
  static const double toolbarGroupGap = 22;

  /// Gap between buttons within a toolbar group. Measured: 678-(634+40) = 4.
  static const double toolbarButtonGap = 4;

  /// Segmented pair outer/inner corner radii. Measured: 20 outer, 8 inner.
  static const double segmentOuterRadius = 20;
  static const double segmentInnerRadius = 8;

  /// Zoom control row bottom inset. Measured: y=832 in a 900 viewport, so
  /// 900 - 832 - 40 = 28 from the bottom.
  static const double zoomBottomInset = 28;

  /// Zoom percentage readout width. Measured: 56.
  static const double zoomLabelWidth = 56;

  /// Screen label row height above each frame (phone/desktop segmented pair).
  /// Measured: 28 — the SizedBox the label row is wrapped in.
  static const double screenLabelHeight = 28;

  /// Phone frame outer box. Measured: 343x725 (bezel included).
  static const double phoneOuterWidth = 343;
  static const double phoneOuterHeight = 725;

  /// Bezel thickness. Measured: (343-328)/2 = 7.5.
  static const double phoneBezel = 7.5;

  /// Phone screen (inner) box. Measured: 328x709.
  static const double phoneInnerWidth = 328;
  static const double phoneInnerHeight = 709;

  /// Outer corner radius of the phone body.
  static const double phoneOuterRadius = 44;

  /// Inner screen corner radius.
  static const double phoneInnerRadius = 36;

  /// FlutterFlow-chrome nav rail width. APPROXIMATE ~48px (BUILD_SPEC §9.1).
  static const double ffRailWidth = 48;

  /// FlutterFlow-chrome rail button box. APPROXIMATE ~40px (48 rail minus a
  /// 4px inset each side, mirroring the measured 52/44 rail idiom).
  static const double ffRailButtonSize = 40;

  /// FlutterFlow-chrome rail button glyph size. APPROXIMATE ~20px.
  static const double ffRailIconSize = 20;

  /// FlutterFlow-chrome rail active-indicator bar width. APPROXIMATE ~3px.
  static const double ffRailIndicatorWidth = 3;

  /// FlutterFlow-chrome dense top bar height. APPROXIMATE 56px (BUILD_SPEC
  /// §9.1).
  static const double ffTopbarHeight = 56;

  /// FlutterFlow-chrome rail-switched side panel width. APPROXIMATE ~280px
  /// (BUILD_SPEC §9.1).
  static const double ffPanelWidth = 280;

  /// FlutterFlow-chrome properties panel width. APPROXIMATE ~300px
  /// (BUILD_SPEC §9.1).
  static const double ffInspectorWidth = 300;

  /// FlutterFlow-chrome compact topbar control box (embedded device/zoom
  /// buttons). APPROXIMATE ~28px.
  static const double ffCompactButtonSize = 28;
}

/// Editor type scale. Measured font sizes/weights from the reference.
class EditorType {
  EditorType._();

  /// Palette tile label, panel body. Measured: 13px / 500.
  static const tileLabel =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.25);

  /// Search field text. Measured: 14px / 400.
  static const field = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);

  /// Section header ("Actions", "Navigation").
  static const sectionHeader =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1);

  /// Zoom readout, active segment label. Measured: 13px / 600.
  static const readout = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  /// Screen name label beside the phone frame. Measured: 15px / 500.
  static const screenLabel =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
}

/// Inherited holder so chrome widgets read one palette without prop drilling.
class EditorTheme extends InheritedWidget {
  final EditorColors colors;

  const EditorTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  static EditorColors of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<EditorTheme>();
    return t?.colors ?? EditorColors.dark;
  }

  @override
  bool updateShouldNotify(EditorTheme oldWidget) => colors != oldWidget.colors;
}
