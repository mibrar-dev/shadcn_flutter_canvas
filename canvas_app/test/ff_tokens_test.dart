/// Track FF1 (BUILD_SPEC §9.3): FlutterFlow-chrome additive tokens.
///
/// Pins the six FF1 colors (`railBg`, `railActiveIndicator`, `panelBg`,
/// `canvasBackdrop`, `selectionOutline`, `groupHeaderFg`) plus the `ff*`
/// metrics in both chrome modes. All values are APPROXIMATE per the
/// measured-spec rule (re-measured in Track H) — this test guards against
/// accidental edits, not against re-measurement.
///
/// Pre-existing values stay guarded by `light_theme_test.dart` (untouched).
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1 tokens (additive, BUILD_SPEC §9.3)', () {
    test('light values match the FF1 APPROXIMATE spec', () {
      expect(EditorColors.light.railBg, const Color(0xFFFFFFFF));
      expect(
        EditorColors.light.railActiveIndicator,
        const Color(0xFF2563EB),
      );
      expect(EditorColors.light.panelBg, const Color(0xFFFFFFFF));
      expect(EditorColors.light.canvasBackdrop, const Color(0xFFE8ECF1));
      expect(EditorColors.light.selectionOutline, const Color(0xFF2563EB));
      expect(EditorColors.light.groupHeaderFg, const Color(0xFF6B7280));
    });

    test('dark values match the FF1 APPROXIMATE spec', () {
      expect(EditorColors.dark.railBg, const Color(0xFF1E1D20));
      expect(
        EditorColors.dark.railActiveIndicator,
        const Color(0xFF60A5FA),
      );
      expect(EditorColors.dark.panelBg, const Color(0xFF1C1B1F));
      expect(EditorColors.dark.canvasBackdrop, const Color(0xFF0F0E11));
      expect(EditorColors.dark.selectionOutline, const Color(0xFF60A5FA));
      expect(EditorColors.dark.groupHeaderFg, const Color(0xFF9CA3AF));
    });

    test('selection outline follows the accent ramp in both modes', () {
      expect(
        EditorColors.light.selectionOutline,
        EditorColors.light.accent,
      );
      expect(
        EditorColors.dark.selectionOutline,
        EditorColors.dark.accent,
      );
    });

    test('ff metrics match the §9.1 shell geometry', () {
      expect(EditorMetrics.ffRailWidth, 48);
      expect(EditorMetrics.ffRailButtonSize, 40);
      expect(EditorMetrics.ffRailIconSize, 20);
      expect(EditorMetrics.ffRailIndicatorWidth, 3);
      expect(EditorMetrics.ffTopbarHeight, 56);
      expect(EditorMetrics.ffPanelWidth, 280);
      expect(EditorMetrics.ffInspectorWidth, 300);
      expect(EditorMetrics.ffCompactButtonSize, 28);
    });

    test('rail button fits inside the rail with an inset each side', () {
      expect(
        EditorMetrics.ffRailButtonSize,
        lessThan(EditorMetrics.ffRailWidth),
      );
    });
  });
}
