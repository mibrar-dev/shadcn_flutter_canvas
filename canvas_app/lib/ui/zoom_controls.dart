/// Zoom controls row, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Right-aligned row near the bottom of the canvas area; see CHROME_SPEC.md.
library;

import 'package:flutter/material.dart';

import 'editor_buttons.dart';
import 'editor_tokens.dart';

/// Bottom-right zoom controls: zoom-out, percentage readout, zoom-in, fit.
///
/// Composed from [EditorIconButton]. Zoom-in disables at or above 4.0 and
/// zoom-out disables at or below 0.25. Uses [MainAxisSize.min] so the caller
/// can align it.
class ZoomControls extends StatelessWidget {
  /// Current zoom fraction (1.0 means 100%).
  final double zoom;

  /// Zoom in one step.
  final VoidCallback onZoomIn;

  /// Zoom out one step.
  final VoidCallback onZoomOut;

  /// Fit the screen into view.
  final VoidCallback onFit;

  const ZoomControls({
    super.key,
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EditorIconButton(
          icon: Icons.remove,
          onPressed: zoom <= 0.25 ? null : onZoomOut,
          tooltip: 'Zoom out',
        ),
        SizedBox(
          width: EditorMetrics.zoomLabelWidth,
          child: Center(
            child: Text(
              '${(zoom * 100).round()}%',
              style: EditorType.readout.copyWith(color: colors.onSurface),
            ),
          ),
        ),
        EditorIconButton(
          icon: Icons.add,
          onPressed: zoom >= 4.0 ? null : onZoomIn,
          tooltip: 'Zoom in',
        ),
        EditorIconButton(
          icon: Icons.fit_screen,
          onPressed: onFit,
          tooltip: 'Fit to screen',
        ),
      ],
    );
  }
}
