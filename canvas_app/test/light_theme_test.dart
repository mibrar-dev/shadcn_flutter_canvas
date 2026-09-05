/// Guards for [EditorColors.light], measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) in light mode at a 1440x900
/// viewport via `getComputedStyle`.
///
/// Measured 2026-09-05 (Brightness = Light):
/// - body + both asides bg `#FEF7FF`, text `#1D1B20`
/// - `.m3-tile` bg `#F7F2FA` (114x72 r16), tile label `#49454F`
/// - search input bg `#ECE6F0` (244x40 r20)
/// - active rail button bg `#E8DEF8`, glyph `#1D192B`; inactive `#49454F`
/// - active toolbar segment bg `#6750A4`, glyph `#FFFFFF`
/// - disabled undo glyph `#CAC4D0` (also the reference's `--sb` var)
/// - phone bezel `#322F35`
///
/// Also pins [EditorColors.dark] (frozen spec from HANDOFF.md section 2) so
/// any accidental dark edit fails loudly.
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  final hi = x > y ? x : y;
  final lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('EditorColors.light matches the measured reference light mode', () {
    const light = EditorColors.light;

    test('pinned measured values', () {
      expect(light.surface, const Color(0xFFFEF7FF));
      expect(light.surfaceContainer, const Color(0xFFF7F2FA));
      expect(light.surfaceContainerHigh, const Color(0xFFECE6F0));
      expect(light.onSurface, const Color(0xFF1D1B20));
      expect(light.onSurfaceVariant, const Color(0xFF49454F));
      expect(light.disabled, const Color(0xFFCAC4D0));
      expect(light.railActive, const Color(0xFFE8DEF8));
      expect(light.onRailActive, const Color(0xFF1D192B));
      expect(light.toolbarActive, const Color(0xFF6750A4));
      expect(light.onToolbarActive, const Color(0xFFFFFFFF));
      expect(light.bezel, const Color(0xFF322F35));
    });

    test('surface luminance ordering mirrors the dark ramp', () {
      // Dark ramp: surface < container < containerHigh (ascending lightness).
      // Light mirrors it: surface > container > containerHigh.
      final s = light.surface.computeLuminance();
      final c = light.surfaceContainer.computeLuminance();
      final h = light.surfaceContainerHigh.computeLuminance();
      expect(s, greaterThan(c));
      expect(c, greaterThan(h));
    });

    test('text/background pairs meet WCAG AA (>= 4.5)', () {
      expect(_contrast(light.onSurface, light.surface), greaterThanOrEqualTo(4.5));
      expect(
        _contrast(light.onSurfaceVariant, light.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.onSurfaceVariant, light.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.onSurface, light.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.onRailActive, light.railActive),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.onToolbarActive, light.toolbarActive),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('disabled stays muted and below text contrast', () {
      expect(
        _contrast(light.disabled, light.surface),
        lessThan(_contrast(light.onSurfaceVariant, light.surface)),
      );
      expect(_contrast(light.disabled, light.surface), lessThan(3.0));
    });
  });

  group('EditorColors.dark is frozen (HANDOFF.md section 2)', () {
    const dark = EditorColors.dark;

    test('pinned measured dark spec', () {
      expect(dark.surface, const Color(0xFF141317));
      expect(dark.surfaceContainer, const Color(0xFF1C1B1F));
      expect(dark.surfaceContainerHigh, const Color(0xFF2B292D));
      expect(dark.onSurface, const Color(0xFFE4E1E7));
      expect(dark.onSurfaceVariant, const Color(0xFFC9C4D1));
      expect(dark.disabled, const Color(0xFF494550));
      expect(dark.railActive, const Color(0xFF4B425D));
      expect(dark.onRailActive, const Color(0xFFE9DDFD));
      expect(dark.toolbarActive, const Color(0xFFD2BCFC));
      expect(dark.onToolbarActive, const Color(0xFF32226F));
      expect(dark.bezel, const Color(0xFFE4E1E7));
    });
  });
}
