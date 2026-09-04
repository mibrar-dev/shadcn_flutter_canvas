/// Editor icon rail, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Uses [EditorMetrics] / [EditorColors] for every size and color.
/// Renders the 52px rail with its fixed group structure and active states.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/ui/editor_tokens.dart';

/// Fixed rail item ids in display order (top groups, then bottom item).
const String kRailParts = 'parts';
const String kRailLayers = 'layers';
const String kRailColor = 'color';
const String kRailShape = 'shape';
const String kRailType = 'type';
const String kRailMotion = 'motion';
const String kRailAi = 'ai';
const String kRailLang = 'lang';

/// All selectable rail ids, in display order.
const List<String> kRailIds = <String>[
  kRailParts,
  kRailLayers,
  kRailColor,
  kRailShape,
  kRailType,
  kRailMotion,
  kRailAi,
  kRailLang,
];

class EditorIconRail extends StatelessWidget {
  /// All selectable rail ids, in display order.
  static const List<String> ids = kRailIds;

  /// Currently active item id.
  final String activeId;

  /// Called with the tapped item id.
  final ValueChanged<String> onSelect;

  const EditorIconRail({
    super.key,
    required this.activeId,
    required this.onSelect,
  });

  static const List<List<String>> _topGroups = <List<String>>[
    <String>['parts'],
    <String>['layers'],
    <String>['color', 'shape', 'type', 'motion'],
    <String>['ai'],
  ];

  static IconData iconFor(String id) {
    switch (id) {
      case 'parts':
        return Icons.add_box;
      case 'layers':
        return Icons.layers;
      case 'color':
        return Icons.palette;
      case 'shape':
        return Icons.rounded_corner;
      case 'type':
        return Icons.text_fields;
      case 'motion':
        return Icons.animation;
      case 'ai':
        return Icons.auto_awesome;
      case 'lang':
        return Icons.translate;
      default:
        return Icons.widgets;
    }
  }

  static String tooltipFor(String id) {
    switch (id) {
      case 'parts':
        return 'Parts';
      case 'layers':
        return 'Layers';
      case 'color':
        return 'Color';
      case 'shape':
        return 'Shape';
      case 'type':
        return 'Type';
      case 'motion':
        return 'Motion';
      case 'ai':
        return 'AI';
      case 'lang':
        return 'Language';
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: EditorMetrics.railWidth,
      color: colors.surface,
      child: Column(
        children: [
          const SizedBox(height: EditorMetrics.railTopInset),
          for (var gi = 0; gi < _topGroups.length; gi++) ...[
            for (var ii = 0; ii < _topGroups[gi].length; ii++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _RailButton(
                  icon: iconFor(_topGroups[gi][ii]),
                  tooltip: tooltipFor(_topGroups[gi][ii]),
                  active: activeId == _topGroups[gi][ii],
                  onTap: () => onSelect(_topGroups[gi][ii]),
                ),
              ),
              if (ii != _topGroups[gi].length - 1)
                const SizedBox(
                  height:
                      EditorMetrics.railButtonStep -
                      EditorMetrics.railButtonSize,
                ),
            ],
            if (gi != _topGroups.length - 1)
              const SizedBox(
                height:
                    EditorMetrics.railButtonStep -
                    EditorMetrics.railButtonSize +
                    EditorMetrics.railGroupGap,
              ),
          ],
          const Expanded(child: SizedBox()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _RailButton(
              icon: iconFor('lang'),
              tooltip: tooltipFor('lang'),
              active: activeId == 'lang',
              onTap: () => onSelect('lang'),
            ),
          ),
          const SizedBox(
            height:
                EditorMetrics.railButtonStep - EditorMetrics.railButtonSize,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: 'GitHub',
              child: SizedBox(
                width: EditorMetrics.railButtonSize,
                height: EditorMetrics.railButtonSize,
                child: Icon(
                  Icons.code,
                  size: 22,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Single 44x44 fully-rounded rail button with hover feedback.
class _RailButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final background = active ? colors.railActive : Colors.transparent;
    final foreground =
        active ? colors.onRailActive : colors.onSurfaceVariant;
    final radius = BorderRadius.circular(
      EditorMetrics.railButtonSize / 2,
    );
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: active
              ? colors.railActive
              : colors.surfaceContainerHigh,
          onTap: onTap,
          child: SizedBox(
            width: EditorMetrics.railButtonSize,
            height: EditorMetrics.railButtonSize,
            child: Icon(icon, size: 22, color: foreground),
          ),
        ),
      ),
    );
  }
}
