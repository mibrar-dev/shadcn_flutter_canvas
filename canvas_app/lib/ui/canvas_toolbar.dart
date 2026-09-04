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

  /// Clear the canvas.
  final VoidCallback onClear;

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
    required this.onClear,
    required this.onOpen,
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
          onPressed: onClear,
          tooltip: 'Clear',
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
