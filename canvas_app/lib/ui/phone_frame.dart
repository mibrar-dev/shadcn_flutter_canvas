/// Phone frame and screen label, matched to the m3e-canvas reference.
///
/// Geometry comes from [EditorMetrics] (measured at a 1440x900 viewport):
/// a 343x725 bezel body with a 328x709 screen inset by 7.5.
///
/// The screen content is exempt from the chrome dogfooding rule (it is user
/// content), but it still builds nodes through [buildCatalogItem], so unknown
/// kinds render fallback output instead of crashing.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_core/canvas_core.dart';

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

  const ScreenSurface({
    super.key,
    required this.screen,
    required this.nodes,
    this.selectedNodeId,
    this.onSelectNode,
    this.onDropKind,
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
          final local = box.globalToLocal(details.offset);
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
            ],
          );
        },
      ),
    );
  }
}
