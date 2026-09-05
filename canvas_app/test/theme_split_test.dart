/// Track G theme-split guards: full-registry palette list, nested
/// chrome/components [ThemedCanvas], `effectiveChrome`, and the two-group
/// [ColorPanel].
library;

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_app/ui/theme_panels.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 7 ids the bar hardcoded before Track G (must all stay selectable).
const _legacyIds = <String>{
  'clean-slate',
  'amber-minimal',
  'mono',
  'neo-brutalism',
  'ocean-breeze',
  'supabase',
  't3-chat',
};

void main() {
  // resolveCanvasThemeData mutates the global InstalledThemePreset.current;
  // preserve it across tests.
  late shadcn.RegistryThemePreset prevPreset;
  setUp(() => prevPreset = shadcn.InstalledThemePreset.current);
  tearDown(() => shadcn.InstalledThemePreset.current = prevPreset);

  test('kPaletteOptions exposes every registry preset, incl. the old 7', () {
    expect(
      kPaletteOptions.length,
      shadcn.registryThemePresets.length,
      reason: 'bar must offer ALL registry presets, not a hardcoded subset',
    );
    // Spec pins 42 presets; fail loudly if the kit adds/removes any.
    expect(shadcn.registryThemePresets.length, 42);
    expect(kPaletteOptions.length, 42);
    for (final id in _legacyIds) {
      expect(kPaletteOptions, contains(id), reason: 'missing legacy id $id');
    }
    // No duplicates.
    expect(kPaletteOptions.toSet().length, kPaletteOptions.length);
  });

  test('chrome null -> effectiveChrome is self', () {
    const theme = CanvasTheme(
      paletteKey: 'clean-slate',
      dark: false,
      shape: 'rounded',
      motion: 'standard',
    );
    expect(theme.chrome, isNull);
    expect(identical(theme.effectiveChrome, theme), isTrue);
  });

  test('chrome set -> effectiveChrome is the override', () {
    const theme = CanvasTheme(
      paletteKey: 'clean-slate',
      dark: false,
      shape: 'rounded',
      motion: 'standard',
      chrome: CanvasTheme(
        paletteKey: 'supabase',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
    );
    expect(theme.effectiveChrome.paletteKey, 'supabase');
    expect(theme.effectiveChrome.dark, isTrue);
  });

  test('missing chrome JSON key parses to null; toJson omits when null', () {
    final theme = CanvasTheme.fromJson({
      'paletteKey': 'clean-slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    });
    expect(theme.chrome, isNull);
    expect(theme.toJson().containsKey('chrome'), isFalse);
    expect(identical(theme.effectiveChrome, theme), isTrue);
  });

  testWidgets('nested ThemedCanvas splits chrome and components', (
    tester,
  ) async {
    const chrome = CanvasTheme(
      paletteKey: 'clean-slate',
      dark: false,
      shape: 'rounded',
      motion: 'standard',
    );
    const components = CanvasTheme(
      paletteKey: 'supabase',
      dark: true,
      shape: 'rounded',
      motion: 'standard',
    );
    shadcn.ThemeData? outer;
    shadcn.ThemeData? inner;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemedCanvas(
            theme: chrome,
            child: Builder(
              builder: (outerCtx) {
                outer = shadcn.Theme.of(outerCtx);
                return ThemedCanvas(
                  theme: components,
                  child: Builder(
                    builder: (innerCtx) {
                      inner = shadcn.Theme.of(innerCtx);
                      return const Text('x');
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(outer, isNotNull);
    expect(inner, isNotNull);
    // Outside the inner canvas: chrome preset; inside: components preset.
    expect(outer!.colorScheme.brightness, Brightness.light);
    expect(inner!.colorScheme.brightness, Brightness.dark);
    final chromePreset = shadcn.registryThemePresets.firstWhere(
      (p) => p.id == 'clean-slate',
    );
    final compPreset = shadcn.registryThemePresets.firstWhere(
      (p) => p.id == 'supabase',
    );
    expect(outer!.colorScheme.primary, chromePreset.light.primary);
    expect(inner!.colorScheme.primary, compPreset.dark.primary);
  });

  testWidgets('ColorPanel shows both groups; chrome toggle keeps main intact',
      (tester) async {
    const main = CanvasTheme(
      paletteKey: 'clean-slate',
      dark: false,
      shape: 'rounded',
      motion: 'standard',
    );
    final seen = <CanvasTheme>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColorPanel(theme: main, onChanged: seen.add),
          ),
        ),
      ),
    );
    expect(find.text('Components'), findsOneWidget);
    expect(find.text('App chrome'), findsOneWidget);
    // Components switch + chrome switch.
    expect(find.byType(shadcn.Switch), findsNWidgets(2));

    // Toggle the CHROME dark switch (second in tree order).
    await tester.tap(find.byType(shadcn.Switch).at(1));
    expect(seen, hasLength(1));
    final emitted = seen.single;
    // Main theme untouched...
    expect(emitted.paletteKey, 'clean-slate');
    expect(emitted.dark, isFalse);
    expect(emitted.shape, 'rounded');
    expect(emitted.motion, 'standard');
    // ...chrome set from the chrome-or-main base with the flipped dark.
    expect(emitted.chrome, isNotNull);
    expect(emitted.chrome!.paletteKey, 'clean-slate');
    expect(emitted.chrome!.dark, isTrue);
  });

  testWidgets('ColorPanel Follow components clears the chrome override',
      (tester) async {
    const themed = CanvasTheme(
      paletteKey: 'clean-slate',
      dark: false,
      shape: 'rounded',
      motion: 'standard',
      chrome: CanvasTheme(
        paletteKey: 'supabase',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
    );
    final seen = <CanvasTheme>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColorPanel(theme: themed, onChanged: seen.add),
          ),
        ),
      ),
    );
    expect(find.text('Follow components'), findsOneWidget);
    await tester.tap(find.text('Follow components'));
    expect(seen, hasLength(1));
    expect(seen.single.chrome, isNull);
    expect(seen.single.paletteKey, 'clean-slate');
    expect(seen.single.dark, isFalse);
  });

  testWidgets('ColorPanel components toggle preserves an existing chrome',
      (tester) async {
    const themed = CanvasTheme(
      paletteKey: 'clean-slate',
      dark: false,
      shape: 'rounded',
      motion: 'standard',
      chrome: CanvasTheme(
        paletteKey: 'supabase',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
    );
    final seen = <CanvasTheme>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColorPanel(theme: themed, onChanged: seen.add),
          ),
        ),
      ),
    );
    // First switch is the components one.
    await tester.tap(find.byType(shadcn.Switch).at(0));
    expect(seen, hasLength(1));
    expect(seen.single.dark, isTrue);
    expect(seen.single.paletteKey, 'clean-slate');
    expect(seen.single.chrome, isNotNull);
    expect(seen.single.chrome!.paletteKey, 'supabase');
    expect(seen.single.chrome!.dark, isTrue);
  });
}
