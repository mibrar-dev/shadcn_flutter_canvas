/// Full-screen preview: hides editor chrome, runs real widgets.
///
/// Taps reach the real catalog widgets: items WITHOUT actions are not wrapped
/// at all, and items WITH an action get a [_TapCatcher] that pushes the target
/// screen. [_TapCatcher] uses a raw [Listener] on purpose: the kit buttons
/// resolve taps through `Clickable`'s own `GestureDetector`, which wins the
/// gesture arena against an ancestor `GestureDetector.onTap` (same-type tap
/// recognizers compete — only the inner one fires, verified by probe), so a
/// wrapping `GestureDetector` would silently never navigate. Pointer events
/// bypass the arena, so both the widget's own tap and navigation fire.
/// Back pops the preview stack, or calls [onExit] at the stack root (return
/// to the editor). Unknown action targets are ignored; unknown kinds render
/// the catalog fallback.
///
/// The player takes an immutable [ScreenDoc] snapshot (preview never edits),
/// themed by [themeOverride] or `doc.theme` via [ThemedCanvas].
///
/// Device frames: the top bar holds a [DevicePicker] (phone 390×844, tablet
/// 768×1024, desktop fluid 1100, desktop 1440, plus a landscape toggle that
/// swaps phone/tablet to 844×390 / 1024×768). Mobile/tablet stages render in
/// a bezel-ish rounded frame from [EditorTokens]; desktop stays frameless
/// fluid. The stage width IS the responsive breakpoint: it resolves a [Tier]
/// via [tierForWidth] (shown as a chip under the stage), so the adaptive-nav
/// demo re-tiers live as the device changes.
///
/// Content area is exempt from the chrome dogfooding rule (user content), but
/// the chrome here (back bar) still uses registry widgets via
/// `lib/shadcn_ui.dart` — no raw Material or Cupertino widgets in this file,
/// except the adaptive-nav DEMO template below, which is a user-content
/// screen preset showcasing the canonical Material responsive nav pattern
/// (NavigationBar/NavigationRail) for later code emission.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/responsive.dart';
import 'package:canvas_app/ui/theme_bar.dart';

/// Phone stage width (mirrors [kPreviewDevicePhone.width]). Kept as a named
/// const because `preview_devices_test.dart` asserts against it.
const double kPreviewMobileMaxWidth = 390;

/// Desktop-fluid stage cap (mirrors [kPreviewDeviceDesktopFluid.width]).
/// Kept as a named const because `preview_devices_test.dart` asserts
/// against it.
const double kPreviewWebMaxWidth = 1100;

/// Preview host over [doc] starting at [startScreenId] (or the first screen).
class PreviewPlayer extends StatefulWidget {
  final ScreenDoc doc;
  final CanvasTheme? themeOverride;
  final String? startScreenId;

  /// Called when back is pressed at the stack root.
  final VoidCallback? onExit;

  const PreviewPlayer({
    super.key,
    required this.doc,
    this.themeOverride,
    this.startScreenId,
    this.onExit,
  });

  @override
  State<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<PreviewPlayer> {
  late List<String> _stack = [
    if (widget.startScreenId != null)
      widget.startScreenId!
    else if (widget.doc.screens.isNotEmpty)
      widget.doc.screens.first.id,
  ];

  /// Device picker state. Internal only (no ctor change): index into
  /// [kPreviewDevices], defaulting to phone.
  int _deviceIndex = 0;

  /// Landscape toggle: swaps framed phone/tablet dimensions (844×390 /
  /// 1024×768). Ignored for frameless desktop presets.
  bool _landscape = false;

  /// Adaptive-nav demo overlay. Behaves like a pushed preview screen: Back
  /// closes it first, then pops the doc stack.
  bool _demoOpen = false;

  String? get _currentId => _stack.isEmpty ? null : _stack.last;

  CanvasScreen? _screen(String id) {
    for (final screen in widget.doc.screens) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  void _onItemTap(CanvasItem item) {
    final to = item.action?.to;
    if (to == null || _screen(to) == null) return;
    setState(() => _stack.add(to));
  }

  void _onBack() {
    if (_demoOpen) {
      setState(() => _demoOpen = false);
      return;
    }
    if (_stack.length > 1) {
      setState(() => _stack.removeLast());
    } else {
      widget.onExit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentId == null ? null : _screen(_currentId!);
    final colors = EditorTheme.of(context);
    // ONE-TREE RULE: every device renders the SAME content subtree below
    // ([_stageContent]). Only the stage dimensions and the bezel frame
    // change — the picker must not alter item counts, tap handling, or
    // back-stack behavior.
    return ThemedCanvas(
      theme: widget.themeOverride ?? widget.doc.theme,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    shadcn.GhostButton(
                      onPressed: _onBack,
                      child: const Text('‹ Back'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _demoOpen
                            ? 'Responsive demo'
                            : (current?.name ?? 'No screens'),
                        style: EditorType.screenLabel
                            .copyWith(color: colors.onSurface),
                      ),
                    ),
                    DevicePicker(
                      selectedIndex: _deviceIndex,
                      onSelect: (index) => setState(() {
                        _deviceIndex = index;
                      }),
                      landscape: _landscape,
                      onLandscapeChanged: (value) =>
                          setState(() => _landscape = value),
                    ),
                    const SizedBox(width: 4),
                    shadcn.GhostButton(
                      onPressed: _demoOpen
                          ? null
                          : () => setState(() => _demoOpen = true),
                      child: const Text('Responsive demo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final spec = resolveDevice(
                      kPreviewDevices[_deviceIndex],
                      landscape: _landscape,
                    );
                    // Clamp the stage to the device geometry but never exceed
                    // the available viewport (narrow windows shrink
                    // gracefully). Framed devices keep their fixed height;
                    // fluid desktop stages fill the available height.
                    final stageWidth = constraints.maxWidth > spec.width
                        ? spec.width
                        : constraints.maxWidth;
                    // Stable frame skeleton: the same widget TYPES wrap the
                    // content on every device (a bare [Container] would
                    // insert/remove DecoratedBox/Padding internally when its
                    // decoration toggles, remounting the content below and
                    // wiping state like the demo's selected tab). Only scalar
                    // params collapse to zero when frameless, so the content
                    // subtree keeps its element position on every switch and
                    // demo selection survives tier changes.
                    final frame = spec.framed
                        ? EditorMetrics.phoneBezel
                        : 0.0;
                    var innerHeight = spec.height == null
                        ? constraints.maxHeight
                        : (spec.height! > constraints.maxHeight
                              ? constraints.maxHeight
                              : spec.height!);
                    // Reserve the bezel inside the available height so the
                    // frame never overflows short viewports (e.g. the 844pt
                    // phone in widget-test viewports).
                    var outerHeight = innerHeight + frame * 2;
                    if (outerHeight > constraints.maxHeight) {
                      outerHeight = constraints.maxHeight;
                    }
                    innerHeight = outerHeight - frame * 2;
                    final outerWidth =
                        stageWidth + frame * 2 > constraints.maxWidth
                        ? constraints.maxWidth
                        : stageWidth + frame * 2;
                    // The canvas IS the breakpoint: preview width resolves
                    // the tier, shown as a chip under the stage.
                    final tier = tierForWidth(stageWidth);
                    final content = _demoOpen
                        ? buildAdaptiveNavDemo()
                        : _stageContent(current, colors);
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: outerWidth,
                            height: outerHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: spec.framed
                                    ? colors.bezel
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  spec.framed
                                      ? EditorMetrics.phoneOuterRadius
                                      : 0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(frame),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    spec.framed
                                        ? EditorMetrics.phoneInnerRadius
                                        : 0,
                                  ),
                                  child: SizedBox(
                                    key: const ValueKey('previewStage'),
                                    width: stageWidth,
                                    height: innerHeight,
                                    child: content,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Center(
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${tier.name} · ${stageWidth.round()}',
                                  style: EditorType.field.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The doc content subtree — identical for every device (one-tree rule).
  Widget _stageContent(CanvasScreen? current, EditorColors colors) {
    if (current == null) {
      return Center(
        child: Text(
          'No screens to preview',
          style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final node in widget.doc.nodes)
          if (node.screenId == current.id)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [for (final item in node.items) _previewItem(item)],
              ),
            ),
      ],
    );
  }

  /// Action-less items render bare so every gesture reaches the real widget.
  Widget _previewItem(CanvasItem item) {
    final built = buildCatalogItem(item.kind, item.props);
    if (item.action == null) return built;
    return _TapCatcher(onTap: () => _onItemTap(item), child: built);
  }
}

/// Arena-independent tap catcher: raw pointer down/up within [kTouchSlop]
/// counts as a tap. Ignores drags (e.g. scrolling the preview list) and
/// never joins the gesture arena, so wrapped widgets keep their own taps.
class _TapCatcher extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TapCatcher({required this.onTap, required this.child});

  @override
  State<_TapCatcher> createState() => _TapCatcherState();
}

class _TapCatcherState extends State<_TapCatcher> {
  final Map<int, Offset> _downs = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _downs[event.pointer] = event.position,
      onPointerUp: (event) {
        final down = _downs.remove(event.pointer);
        if (down != null && (event.position - down).distance <= kTouchSlop) {
          widget.onTap();
        }
      },
      onPointerCancel: (event) => _downs.remove(event.pointer),
      child: widget.child,
    );
  }
}

/// Builds the adaptive-nav demo screen: the canonical responsive nav pattern
/// (LayoutBuilder; <600 → [NavigationBar] bottom, ≥600 → [NavigationRail]
/// side) as a screen preset template for later code emission. Opened from
/// the preview bar's "Responsive demo" button; it fills the device stage so
/// switching devices re-tiers it live (phone → bottom bar, tablet/desktop
/// → side rail).
Widget buildAdaptiveNavDemo() => const AdaptiveNavDemo();

/// Adaptive nav demo: 3 destinations + a body placeholder.
///
/// Selection state ([_index]) lives OUTSIDE the breakpoint branch, so the
/// active destination survives tier switches (the showcase interaction).
class AdaptiveNavDemo extends StatefulWidget {
  const AdaptiveNavDemo({super.key});

  @override
  State<AdaptiveNavDemo> createState() => _AdaptiveNavDemoState();
}

class _AdaptiveNavDemoState extends State<AdaptiveNavDemo> {
  int _index = 0;

  static const _labels = ['Home', 'Search', 'Settings'];
  static const _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.settings_outlined,
  ];
  static const _activeIcons = [Icons.home, Icons.search, Icons.settings];

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // State stays above this branch: only the nav CHROME differs per tier.
    return ResponsiveBuilder(
      builder: (context, tier, width) {
        final body = Center(
          child: Text('${_labels[_index]} body · ${tier.name}'),
        );
        if (tier == Tier.mobile) {
          return Column(
            children: [
              Expanded(child: body),
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_activeIcons[i]),
                      label: _labels[i],
                    ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    selectedIcon: Icon(_activeIcons[i]),
                    label: Text(_labels[i]),
                  ),
              ],
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
