/// FlutterFlow-style persistent nav rail (Track FF2, BUILD_SPEC §9.1-2a,
/// §9.3 FF2).
///
/// A 48px icon column with five destinations (Tree / Palette / Theme /
/// Assets / Settings) that switches what the panel host shows. This is a
/// DELIBERATE reversal of the Track Y6 rail deletion (`f56b6839`, which
/// folded Layers into pills): FlutterFlow's model *is* the rail, so the rail
/// comes back as the panel switcher.
///
/// Stateless vs the store, like [ForgeTopbar]: the selection arrives as a
/// [FfRailDestination] prop and every tap leaves through [onSelect] — the
/// widget never imports the store, so it is widget-testable without a shell.
/// (Cutover mounting stays FF7-owned; this file mounts nothing.)
///
/// Token rule: chrome reads [EditorColors]/[EditorMetrics] only — no hex
/// literals, no magic numbers. All FF geometry is APPROXIMATE per the
/// measured-spec rule (structure/callbacks are tested, not pixels, per §12
/// rule 4).
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;

import 'editor_tokens.dart';

/// The five rail destinations, in display order (BUILD_SPEC §9.1).
enum FfRailDestination {
  /// Widget tree — the first-class always-available panel (§9.1-2).
  tree,

  /// Widget palette (list rows, DnD payloads unchanged).
  palette,

  /// Theme panel (rail destination per §9.1-3c).
  theme,

  /// Assets panel (empty-state stub for v1 per §9.1-3d).
  assets,

  /// Editor settings.
  settings,
}

/// Icon + label metadata for each [FfRailDestination].
extension FfRailDestinationMeta on FfRailDestination {
  /// Rail glyph for this destination.
  IconData get icon {
    switch (this) {
      case FfRailDestination.tree:
        return Icons.account_tree_outlined;
      case FfRailDestination.palette:
        return Icons.widgets_outlined;
      case FfRailDestination.theme:
        return Icons.palette_outlined;
      case FfRailDestination.assets:
        return Icons.folder_outlined;
      case FfRailDestination.settings:
        return Icons.settings_outlined;
    }
  }

  /// Rail label, also used as the hover tooltip and the panel host header.
  String get label {
    switch (this) {
      case FfRailDestination.tree:
        return 'Tree';
      case FfRailDestination.palette:
        return 'Palette';
      case FfRailDestination.theme:
        return 'Theme';
      case FfRailDestination.assets:
        return 'Assets';
      case FfRailDestination.settings:
        return 'Settings';
    }
  }
}

/// FlutterFlow nav rail: 48px persistent icon column. See the library doc
/// for the data flow.
class FfNavRail extends StatelessWidget {
  /// Currently selected destination (shell-owned).
  final FfRailDestination selected;

  /// Tap on a destination: the shell switches the panel host to it.
  final ValueChanged<FfRailDestination> onSelect;

  const FfNavRail({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: EditorMetrics.ffRailWidth,
      color: colors.railBg,
      child: Column(
        children: [
          for (final destination in FfRailDestination.values)
            _FfRailButton(
              destination: destination,
              active: destination == selected,
              onTap: () => onSelect(destination),
            ),
        ],
      ),
    );
  }
}

/// Single rail destination button: a leading active-indicator bar plus the
/// destination glyph in a [EditorMetrics.ffRailButtonSize] box.
///
/// The indicator bar is always laid out (transparent when inactive) so
/// selecting a destination never shifts the glyph.
class _FfRailButton extends StatelessWidget {
  final FfRailDestination destination;
  final bool active;
  final VoidCallback onTap;

  const _FfRailButton({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return shadcn.Tooltip(
      tooltip: (context) => shadcn.TooltipContainer(
        child: Text(destination.label),
      ),
      child: SizedBox(
        width: EditorMetrics.ffRailWidth,
        height: EditorMetrics.ffRailButtonSize,
        child: Row(
          children: [
            Container(
              width: EditorMetrics.ffRailIndicatorWidth,
              height: EditorMetrics.ffRailButtonSize,
              color: active ? colors.railActiveIndicator : Colors.transparent,
            ),
            Expanded(
              child: shadcn.IconButton.ghost(
                icon: Icon(
                  destination.icon,
                  size: EditorMetrics.ffRailIconSize,
                  color: active
                      ? colors.railActiveIndicator
                      : colors.onSurfaceVariant,
                ),
                onPressed: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
