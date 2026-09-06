/// Track L root-cause repro: "when I change the app theme to dark the
/// default color is not changing".
///
/// Trace under test: `store.setTheme` → relay → shell build →
/// [resolveCanvasThemeData] (sets global `InstalledThemePreset.current` as a
/// side effect) → `_materialScheme` → Scaffold bg, plus the [ScreenSurface]
/// bg mapping via [PhoneFrame.screenColor].
///
/// Verdict encoded here (see theme_split_test.dart for the split guards):
/// chrome-dark flips the chrome (Scaffold bg, [EditorColors], outer kit
/// scheme) while the canvas components keep their own theme BY DESIGN —
/// the canvas screens do not follow the chrome toggle. These tests pin that
/// behavior so a future regression (stale `doc.theme` capture, relay missing
/// notify, nested-build clobbering via the global) fails loudly.
///
/// Dogfood guards for the Track L allowlist (`theme_bar.dart`,
/// `theme_panels.dart`): ColorPanel/ThemeBar build kit Switch/Select/Card
/// with no raw Material Switch/Card/AlertDialog/TextField.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_app/ui/theme_panels.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _componentsLight = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: false,
  shape: 'rounded',
  motion: 'standard',
);

const _chromeDark = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

/// Reference viewport (HANDOFF §2): the 3-column shell is measured at
/// 1440x900 and overflows the default 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpShell(WidgetTester tester, CanvasStore store) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
  await tester.pump();
}

Color _scaffoldBg(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;

/// Kit [Theme] data installed by the outer (chrome) vs inner (components)
/// [ThemedCanvas]. Tree order is outer-first.
shadcn.ThemeData shandcnThemeData(WidgetTester tester, int at) =>
    tester.widget<shadcn.Theme>(find.byType(shadcn.Theme).at(at)).data;

void main() {
  // resolveCanvasThemeData mutates the global InstalledThemePreset.current;
  // preserve it across tests.
  late shadcn.RegistryThemePreset prevPreset;
  setUp(() => prevPreset = shadcn.InstalledThemePreset.current);
  tearDown(() => shadcn.InstalledThemePreset.current = prevPreset);

  testWidgets(
    'chrome-dark flips chrome (Scaffold + EditorColors + outer kit scheme) '
    'while components stay light',
    (tester) async {
      final store = CanvasStore();
      store.setTheme(_componentsLight);
      await _pumpShell(tester, store);

      // Baseline: all-light chrome follows the light components theme.
      expect(_scaffoldBg(tester), EditorColors.light.surface);
      expect(
          shandcnThemeData(tester, 0).colorScheme.brightness, Brightness.light);
      expect(
          shandcnThemeData(tester, 1).colorScheme.brightness, Brightness.light);

      // The reported repro: flip ONLY the chrome (App chrome → Dark).
      store.setTheme(
        const CanvasTheme(
          paletteKey: 'clean-slate',
          dark: false,
          shape: 'rounded',
          motion: 'standard',
          chrome: _chromeDark,
        ),
      );
      await tester.pump();

      // Chrome flipped...
      expect(_scaffoldBg(tester), EditorColors.dark.surface);
      expect(
        shandcnThemeData(tester, 0).colorScheme.brightness,
        Brightness.dark,
      );
      expect(
        tester.widget<PhoneFrame>(find.byType(PhoneFrame)).screenColor,
        // Track K: `surface` screens follow the components (light) theme,
        // not the dark chrome.
        Color(
          resolveCanvasThemeData(
            _componentsLight,
          ).colorScheme.background.toARGB32(),
        ),
      );
      // ...canvas components stayed put (correct new behavior, not a bug).
      expect(
        shandcnThemeData(tester, 1).colorScheme.brightness,
        Brightness.light,
      );
    },
  );

  testWidgets('main dark toggle with following chrome flips everything',
      (tester) async {
    final store = CanvasStore();
    store.setTheme(_componentsLight);
    await _pumpShell(tester, store);
    expect(_scaffoldBg(tester), EditorColors.light.surface);

    // Components dark, chrome null → effectiveChrome follows main.
    store.setTheme(
      const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
    );
    await tester.pump();

    expect(_scaffoldBg(tester), EditorColors.dark.surface);
    expect(shandcnThemeData(tester, 0).colorScheme.brightness, Brightness.dark);
    expect(shandcnThemeData(tester, 1).colorScheme.brightness, Brightness.dark);
  });

  testWidgets('follow-components re-ties chrome to the main theme',
      (tester) async {
    final store = CanvasStore();
    store.setTheme(
      const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
        chrome: _chromeDark,
      ),
    );
    await _pumpShell(tester, store);
    expect(_scaffoldBg(tester), EditorColors.dark.surface);

    // Clearing the override (ColorPanel "Follow components") drops chrome
    // back onto the light main theme.
    store.setTheme(_componentsLight);
    await tester.pump();

    expect(_scaffoldBg(tester), EditorColors.light.surface);
    expect(
        shandcnThemeData(tester, 0).colorScheme.brightness, Brightness.light);
  });

  testWidgets(
    'nested chrome/components builds do not clobber each other via the '
    'InstalledThemePreset global',
    (tester) async {
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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemedCanvas(
              theme: chrome,
              child: ThemedCanvas(
                theme: components,
                child: const Text('x'),
              ),
            ),
          ),
        ),
      );
      final datas = tester
          .widgetList<shadcn.Theme>(find.byType(shadcn.Theme))
          .map((w) => w.data)
          .toList();
      expect(datas, hasLength(2));
      // Each build captured its own preset synchronously at build time.
      expect(datas[0].colorScheme.brightness, Brightness.light);
      expect(datas[1].colorScheme.brightness, Brightness.dark);
      final chromePreset =
          shadcn.registryThemePresets.firstWhere((p) => p.id == 'clean-slate');
      final compPreset =
          shadcn.registryThemePresets.firstWhere((p) => p.id == 'supabase');
      expect(datas[0].colorScheme.primary, chromePreset.light.primary);
      expect(datas[1].colorScheme.primary, compPreset.dark.primary);
      // The global ends on the inner (components) preset — last writer wins —
      // which is safe because AppTheme reads it synchronously inside
      // resolveCanvasThemeData, never across builds.
      expect(shadcn.InstalledThemePreset.current.id, 'supabase');
    },
  );

  group('dogfood: theme_bar/theme_panels use kit widgets', () {
    testWidgets('ColorPanel uses kit Switch/Select, no raw Material ones',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColorPanel(theme: _componentsLight, onChanged: (_) {}),
            ),
          ),
        ),
      );
      expect(find.byType(shadcn.Switch), findsNWidgets(2));
      expect(find.byType(shadcn.Select<String>), findsWidgets);
      expect(find.byType(shadcn.Card), findsOneWidget);
      expect(find.byType(shadcn.GhostButton), findsNothing);
      // No raw Material interactive widgets in the panel.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('ThemeBar uses kit Card/Switch/Select, no raw Material ones',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeBar(theme: _componentsLight, onChanged: (_) {}),
          ),
        ),
      );
      expect(find.byType(shadcn.Switch), findsOneWidget);
      expect(find.byType(shadcn.Select<String>), findsWidgets);
      expect(find.byType(shadcn.Card), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Shape/Motion panels use kit Select without raw widgets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ShapePanel(theme: _componentsLight, onChanged: (_) {}),
                  MotionPanel(theme: _componentsLight, onChanged: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(shadcn.Select<String>), findsNWidgets(2));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
