/// Center floating toolbar, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Single row centered over the canvas; see CHROME_SPEC.md.
///
/// Track Y4 (FORGE.md §1-3f) adds [ForgeSelectionToolbar] below: the floating
/// black selection toolbar. [CanvasToolbar] itself is KEPT verbatim until the
/// Y6 cutover remounts the shell (its actions move to the topbar/header
/// there); nothing above this line changed for Y4.
///
/// Track FF5 (BUILD_SPEC §9.2 row 4d): both toolbars are restyled as floating
/// neutral pills ([EditorColors.panelBg] with an
/// [EditorColors.surfaceContainerHigh] hairline). Every op, callback,
/// tooltip, icon, key, and null-disabled idiom is unchanged.
library;

import 'package:flutter/material.dart';

import 'editor_buttons.dart';
import 'editor_tokens.dart';

/// Floating toolbar row shown at the top of the canvas area.
///
/// Composed from [EditorIconButton] and [EditorSegmented]. Null [onUndo] /
/// [onRedo] render the disabled state. Uses [MainAxisSize.min] so the caller
/// can center it.
class CanvasToolbar extends StatelessWidget {
  /// Whether pan mode is active (false means select mode).
  final bool panMode;

  /// Called with true for pan, false for select.
  final ValueChanged<bool> onPanModeChanged;

  /// Add a new screen.
  final VoidCallback onAddScreen;

  /// Enter preview.
  final VoidCallback onPreview;

  /// Undo. Null renders the disabled state.
  final VoidCallback? onUndo;

  /// Redo. Null renders the disabled state.
  final VoidCallback? onRedo;

  /// Delete the current selection (node or screen). Always enabled; a tap
  /// with nothing selected is a no-op (see [hasSelection] for the tooltip).
  final VoidCallback onDelete;

  /// Whether a node or screen is selected. Drives the delete tooltip:
  /// 'Delete selected' vs 'Select a part or screen to delete'.
  final bool hasSelection;

  /// Whether the Group action is available (≥2 selected nodes on one screen
  /// at root level). False renders the disabled state.
  final bool canGroup;

  /// Group the selection into a row. Null renders the disabled state.
  final VoidCallback? onGroup;

  /// Whether the Ungroup action is available (a single selected row).
  /// False renders the disabled state.
  final bool canUngroup;

  /// Ungroup the selected row. Null renders the disabled state.
  final VoidCallback? onUngroup;

  /// Open a design.
  final VoidCallback onOpen;

  /// Open the export dialog (ZIP / single-file / copy / project file).
  /// Null renders the disabled state (same idiom as [onUndo]/[onRedo]; test
  /// harnesses that don't wire export leave it null).
  final VoidCallback? onExport;

  const CanvasToolbar({
    super.key,
    required this.panMode,
    required this.onPanModeChanged,
    required this.onAddScreen,
    required this.onPreview,
    required this.onUndo,
    required this.onRedo,
    required this.onDelete,
    required this.hasSelection,
    required this.onOpen,
    this.onExport,
    this.canGroup = false,
    this.onGroup,
    this.canUngroup = false,
    this.onUngroup,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    // FF5: the ops row floats as a neutral pill. The pill is pure chrome —
    // every child (segmented pair, buttons, gaps, tooltips, disabled idiom)
    // is untouched.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EditorMetrics.panelInset,
        vertical: EditorMetrics.tileGap,
      ),
      decoration: BoxDecoration(
        color: colors.panelBg,
        borderRadius: BorderRadius.circular(EditorMetrics.segmentOuterRadius),
        border: Border.all(color: colors.surfaceContainerHigh),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EditorSegmented(
            items: const [
              EditorSegmentItem(icon: Icons.near_me, tooltip: 'Select'),
              EditorSegmentItem(icon: Icons.pan_tool, tooltip: 'Pan'),
            ],
            selectedIndex: panMode ? 1 : 0,
            onSelect: (index) => onPanModeChanged(index == 1),
          ),
          const SizedBox(width: EditorMetrics.toolbarGroupGap),
          EditorIconButton(
            icon: Icons.add_to_photos,
            onPressed: onAddScreen,
            tooltip: 'Add screen',
          ),
          const SizedBox(width: EditorMetrics.toolbarButtonGap),
          EditorIconButton(
            icon: Icons.play_arrow,
            onPressed: onPreview,
            tooltip: 'Preview',
          ),
          const SizedBox(width: EditorMetrics.toolbarGroupGap),
          EditorIconButton(
            icon: Icons.undo,
            onPressed: onUndo,
            tooltip: 'Undo',
          ),
          const SizedBox(width: EditorMetrics.toolbarButtonGap),
          EditorIconButton(
            icon: Icons.redo,
            onPressed: onRedo,
            tooltip: 'Redo',
          ),
          const SizedBox(width: EditorMetrics.toolbarGroupGap),
          EditorIconButton(
            icon: Icons.delete_sweep,
            onPressed: onDelete,
            tooltip: hasSelection
                ? 'Delete selected'
                : 'Select a part or screen to delete',
          ),
          const SizedBox(width: EditorMetrics.toolbarButtonGap),
          EditorIconButton(
            icon: Icons.group_work,
            onPressed: canGroup ? onGroup : null,
            tooltip: canGroup
                ? 'Group into row'
                : 'Select 2+ root parts on one screen to group',
          ),
          const SizedBox(width: EditorMetrics.toolbarButtonGap),
          EditorIconButton(
            icon: Icons.call_split,
            onPressed: canUngroup ? onUngroup : null,
            tooltip: canUngroup ? 'Ungroup row' : 'Select a row to ungroup',
          ),
          const SizedBox(width: EditorMetrics.toolbarButtonGap),
          EditorIconButton(
            icon: Icons.folder_open,
            onPressed: onOpen,
            tooltip: 'Open',
          ),
          const SizedBox(width: EditorMetrics.toolbarButtonGap),
          EditorIconButton(
            icon: Icons.ios_share,
            onPressed: onExport,
            tooltip: 'Export',
          ),
        ],
      ),
    );
  }
}

/// Finder for the Forge selection toolbar (used by forge-canvas tests).
const ValueKey<String> kForgeSelectionToolbarKey =
    ValueKey<String>('forge-selection-toolbar');

/// Floating selection toolbar (Track Y4, FORGE.md §1-3f, §3; restyled FF5,
/// BUILD_SPEC §9.2 row 4d).
///
/// Neutral pill ([EditorColors.panelBg] with a
/// [EditorColors.surfaceContainerHigh] hairline), radius full, three 32px
/// targets: move up, move down, duplicate. Renders NOTHING while
/// [selectedNodeId] is null — the toolbar shows only when a node is selected.
///
/// Stateless vs the store, like [ForgeTopbar]: the shell wires the actions
/// at the Y6 cutover (up/down resolve the node's group index and call
/// `store.reorderNode(id, i ± 1)` within the node's group; duplicate calls
/// `store.duplicateNode(id)` and reselects the clone, mirroring the shell's
/// keyboard-duplicate path). Null callbacks render the disabled state (the
/// same idiom as [CanvasToolbar]'s undo/redo).
///
/// Position (FORGE.md §3) is shell-centered horizontally near the canvas
/// bottom, above zoom — the Y6 shell mount owns the placement; this widget
/// only owns the pill. All §3 numbers are APPROXIMATE per FORGE.md §6.
class ForgeSelectionToolbar extends StatelessWidget {
  /// Currently selected node id (shell-owned). Null hides the toolbar.
  final String? selectedNodeId;

  /// Move the selection one slot earlier within its group. Null disables.
  final VoidCallback? onMoveUp;

  /// Move the selection one slot later within its group. Null disables.
  final VoidCallback? onMoveDown;

  /// Duplicate the selection. Null disables.
  final VoidCallback? onDuplicate;

  const ForgeSelectionToolbar({
    super.key,
    this.selectedNodeId,
    this.onMoveUp,
    this.onMoveDown,
    this.onDuplicate,
  });

  /// Pill target size: three 32px targets (FORGE.md §3).
  static const double _kTargetSize = 32;

  @override
  Widget build(BuildContext context) {
    if (selectedNodeId == null) return const SizedBox.shrink();
    final colors = EditorTheme.of(context);
    // FF5: neutral pill with token icons (was the near-black Forge pill), so
    // the toolbar reads on the neutral canvas backdrop in both chrome modes.
    // Ops, icons, key, and the null-disabled idiom are unchanged.
    return Container(
      key: kForgeSelectionToolbarKey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colors.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceContainerHigh),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EditorIconButton(
            icon: Icons.arrow_upward,
            size: _kTargetSize,
            foreground: colors.onSurfaceVariant,
            onPressed: onMoveUp,
            tooltip: 'Move up',
          ),
          EditorIconButton(
            icon: Icons.arrow_downward,
            size: _kTargetSize,
            foreground: colors.onSurfaceVariant,
            onPressed: onMoveDown,
            tooltip: 'Move down',
          ),
          EditorIconButton(
            icon: Icons.content_copy,
            size: _kTargetSize,
            foreground: colors.onSurfaceVariant,
            onPressed: onDuplicate,
            tooltip: 'Duplicate',
          ),
        ],
      ),
    );
  }
}
