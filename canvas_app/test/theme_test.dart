import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _light = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: false,
  shape: 'rounded',
  motion: 'standard',
);

Future<void> _pumpBar(
  WidgetTester tester,
  CanvasTheme theme,
  ValueChanged<CanvasTheme> onChanged,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ThemeBar(theme: theme, onChanged: onChanged)),
    ),
  );
}

void main() {
  // resolveCanvasThemeData mutates the global InstalledThemePreset.current;
  // preserve it across tests.
  late shadcn.RegistryThemePreset prevPreset;
  setUp(() => prevPreset = shadcn.InstalledThemePreset.current);
  tearDown(() => shadcn.InstalledThemePreset.current = prevPreset);

  testWidgets('dark toggle emits a flipped theme and rebuild reflects it', (
    tester,
  ) async {
    final seen = <CanvasTheme>[];
    await _pumpBar(tester, _light, seen.add);

    expect(tester.widget<shadcn.Switch>(find.byType(shadcn.Switch)).value,
        isFalse);
    await tester.tap(find.byType(shadcn.Switch));
    expect(seen, hasLength(1));
    expect(seen.single.dark, isTrue);
    expect(seen.single.paletteKey, 'clean-slate');

    // Rebuild with the emitted theme: the switch now reads on.
    await _pumpBar(tester, seen.single, (_) {});
    expect(tester.widget<shadcn.Switch>(find.byType(shadcn.Switch)).value,
        isTrue);
  });

  testWidgets('palette select shows the current preset', (tester) async {
    await _pumpBar(tester, _light, (_) {});
    expect(find.text('clean-slate'), findsOneWidget);
    expect(find.text('rounded'), findsOneWidget);
  });

  test('resolveCanvasThemeData maps dark + shape to brightness + radius', () {
    final dark = resolveCanvasThemeData(
      const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'sharp',
        motion: 'standard',
      ),
    );
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.radius, 0.0);

    final light = resolveCanvasThemeData(_light);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(light.radius, 0.5);
  });

  test('resolvePreset falls back instead of throwing on unknown keys', () {
    expect(resolvePreset('nope'), shadcn.registryThemePresets.first);
    expect(resolvePreset('amber-minimal').id, 'amber-minimal');
    // Unknown keys still resolve to usable theme data (store default 'slate').
    final data = resolveCanvasThemeData(
      const CanvasTheme(
        paletteKey: 'slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
      ),
    );
    expect(data.radius, 0.5);
  });

  testWidgets('ThemedCanvas provides the kit theme to descendants', (
    tester,
  ) async {
    shadcn.ThemeData? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemedCanvas(
            theme: const CanvasTheme(
              paletteKey: 'clean-slate',
              dark: true,
              shape: 'pill',
              motion: 'standard',
            ),
            child: Builder(
              builder: (context) {
                captured = shadcn.Theme.of(context);
                return const Text('child');
              },
            ),
          ),
        ),
      ),
    );
    expect(captured, isNotNull);
    expect(captured!.colorScheme.brightness, Brightness.dark);
    expect(captured!.radius, 1.0);
  });
}
