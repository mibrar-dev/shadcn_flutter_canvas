/// Zoom controls pill, Forge-restyle (Track Y4, FORGE.md §1-3b, §3).
///
/// White card, radius full, holding `-`, the `%` readout, `+`, the fit
/// button, and (when [onShowGuidesChanged] is non-null) the snap-guides grid
/// toggle. The pill is embedded in [ForgeCanvasHeader]'s header row; the
/// pre-Forge shell mount (bottom-right, no grid toggle) keeps working until
/// the Y6 cutover remounts it.
///
/// Zoom math/contracts are UNCHANGED: zoom-in disables at or above 4.0 and
/// zoom-out disables at or below 0.25 (the [kCanvasMinZoom]/[kCanvasMaxZoom]
/// bounds in `design_canvas.dart`), and the readout keeps the
/// [EditorMetrics.zoomLabelWidth] slot.
library;

import 'package:flutter/material.dart';

import 'editor_buttons.dart';
import 'editor_tokens.dart';

/// Forge zoom pill: zoom-out, percentage readout, zoom-in, fit, guides grid.
///
/// Composed from [EditorIconButton] at the spec's ~32px targets (FORGE.md
/// §3). Uses [MainAxisSize.min] so the caller (the header row) can place it.
class ZoomControls extends StatelessWidget {
  /// Current zoom fraction (1.0 means 100%).
  final double zoom;

  /// Zoom in one step.
  final VoidCallback onZoomIn;

  /// Zoom out one step.
  final VoidCallback onZoomOut;

  /// Fit the screen into view.
  final VoidCallback onFit;

  /// Whether snap guides are on. Renders the grid toggle's active state.
  /// Defaults to true, matching [DesignCanvas]'s `showGuides` default.
  final bool showGuides;

  /// Grid-icon toggle: called with the flipped [showGuides] value. Null
  /// hides the grid button (the pre-Forge shell mount passes nothing; the
  /// Forge header always passes a handler).
  final ValueChanged<bool>? onShowGuidesChanged;

  const ZoomControls({
    super.key,
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    this.showGuides = true,
    this.onShowGuidesChanged,
  });

  /// Pill target size. APPROXIMATE ~32px (FORGE.md §3 — each pill control is
  /// ~32px; structure/callbacks are tested, not pixels, per §6).
  static const double _kTargetSize = 32;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final onToggleGuides = onShowGuidesChanged;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        // Token-adapted "white card": [surface] is near-white in light and
        // the dark chrome surface in dark, so the pill stays legible under
        // both modes (same idiom as the Forge topbar pills).
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceContainerHigh),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EditorIconButton(
            icon: Icons.remove,
            size: _kTargetSize,
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
            size: _kTargetSize,
            onPressed: zoom >= 4.0 ? null : onZoomIn,
            tooltip: 'Zoom in',
          ),
          EditorIconButton(
            icon: Icons.fit_screen,
            size: _kTargetSize,
            onPressed: onFit,
            tooltip: 'Fit to screen',
          ),
          if (onToggleGuides != null)
            EditorIconButton(
              icon: showGuides ? Icons.grid_on : Icons.grid_off,
              size: _kTargetSize,
              background:
                  showGuides ? colors.surfaceContainerHigh : Colors.transparent,
              onPressed: () => onToggleGuides(!showGuides),
              tooltip: 'Toggle snap guides',
            ),
        ],
      ),
    );
  }
}
