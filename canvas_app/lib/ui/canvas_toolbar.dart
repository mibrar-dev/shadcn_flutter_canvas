/// Center floating toolbar, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Single row centered over the canvas; see CHROME_SPEC.md.
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
    this.canGroup = false,
    this.onGroup,
    this.canUngroup = false,
    this.onUngroup,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
          tooltip:
              hasSelection ? 'Delete selected' : 'Select a part or screen to delete',
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
          tooltip:
              canUngroup ? 'Ungroup row' : 'Select a row to ungroup',
        ),
        const SizedBox(width: EditorMetrics.toolbarButtonGap),
        EditorIconButton(
          icon: Icons.folder_open,
          onPressed: onOpen,
          tooltip: 'Open',
        ),
      ],
    );
  }
}
