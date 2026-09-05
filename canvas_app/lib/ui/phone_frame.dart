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
        borderRadius:
            BorderRadius.circular(EditorMetrics.phoneOuterRadius),
      ),
      padding: const EdgeInsets.all(EditorMetrics.phoneBezel),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(EditorMetrics.phoneInnerRadius),
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

/// Renders one screen's nodes into a [PhoneFrame], with selection affordances.
class ScreenSurface extends StatelessWidget {
  final CanvasScreen screen;
  final List<CanvasNode> nodes;
  final String? selectedNodeId;
  final ValueChanged<String>? onSelectNode;

  /// Fired when a palette tile is dropped, with the drop point in screen
  /// coordinates (already relative to the phone's inner area).
  final void Function(String kind, Offset position)? onDropKind;

  /// Current viewport scale of the enclosing [DesignCanvas]. Kept so drop
  /// math can stay zoom-aware if the hit-testing path ever changes.
  final double zoom;

  /// Live global pointer position tracked by the enclosing [DesignCanvas].
  /// When available, the drop point is derived from it (the true pointer)
  /// instead of `DragTargetDetails.offset` (the drag feedback's top-left,
  /// which trails the pointer by the grab offset inside the tile).
  final ValueListenable<Offset?>? dropPointer;

  const ScreenSurface({
    super.key,
    required this.screen,
    required this.nodes,
    this.selectedNodeId,
    this.onSelectNode,
    this.onDropKind,
    this.zoom = 1.0,
    this.dropPointer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return PhoneFrame(
      screenColor: colors.surface,
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          // Prefer the live pointer (true drop point) when the enclosing
          // canvas tracked one; fall back to the feedback corner otherwise.
          final global = dropPointer?.value ?? details.offset;
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
          onDropKind?.call(
            details.data,
            Offset(
              local.dx - EditorMetrics.phoneBezel,
              local.dy - EditorMetrics.phoneBezel,
            ),
          );
        },
        builder: (context, candidate, rejected) {
          return Stack(
            children: [
              if (candidate.isNotEmpty)
                Positioned.fill(
                  child: ColoredBox(
                    color: colors.railActive.withValues(alpha: 0.25),
                  ),
                ),
              if (nodes.isEmpty && candidate.isEmpty)
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
              for (final node in nodes)
                Positioned(
                  left: node.x,
                  top: node.y,
                  child: GestureDetector(
                    onTap: () => onSelectNode?.call(node.id),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: node.id == selectedNodeId
                          ? BoxDecoration(
                              border: Border.all(
                                color: colors.toolbarActive,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      // Positioned children get UNBOUNDED constraints from the
                      // Stack, which detonates kit widgets with internal
                      // Expanded rows (e.g. TextField's input row throws
                      // "flex but unbounded width" and renders nothing).
                      // Clamp to the remaining inner-screen room so every
                      // catalog widget gets the finite box it needs.
                      // Intrinsically-sized widgets (button/card/badge) are
                      // unaffected — only the maximum shrinks.
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
                ),
            ],
          );
        },
      ),
    );
  }
}
