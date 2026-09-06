/// Track K2 — scaffold contrast repro + pins (P11 J2).
///
/// P11 step 4 runs components under supabase/light while the chrome stays
/// clean-slate/dark. In that split the scaffold builder's app-bar title and
/// body text read washed-out, while dark-on-dark stays crisp.
///
/// Root cause under test: [_buildScaffold] leaves the bar/body foregrounds to
/// the ambient `DefaultTextStyle`. On canvas that ambient comes from the
/// OUTER (chrome) material theme — dark chrome yields near-white text — while
/// the kit bar/body surfaces resolve from the INNER components scheme
/// (`AppBar`: `widget.backgroundColor ?? theme.colorScheme.card`;
/// `Scaffold` body: `widget.backgroundColor ?? compTheme?.backgroundColor ??
/// theme.colorScheme.background`, both near-white under supabase light), so
/// light text lands on near-white surfaces. Dark components keep dark
/// surfaces, which is why only the light combo washes out.
///
/// The contrast floor below is WCAG 2.x AA for normal text (4.5:1): the bar
/// title renders at `large()`/`medium()` (~18px semibold), below WCAG's
/// large-scale bar (18.66px bold / 24px regular), so the 4.5 bar — not the
/// 3:1 large-text bar — applies; the body is plain base-size text.
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG AA floor for normal text (see file docs for why 4.5, not 3.0).
const double _kMinContrast = 4.5;

/// P11 step 4 split: light components under a dark chrome.
const _componentsLight = CanvasTheme(
  paletteKey: 'supabase',
  dark: false,
  shape: 'rounded',
  motion: 'standard',
);

const _componentsDark = CanvasTheme(
  paletteKey: 'supabase',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

const _chromeDark = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

/// WCAG contrast ratio between two resolved colors.
double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// Production stacking (main.dart): outer chrome [ThemedCanvas] -> material
/// shell [Scaffold] -> inner components [ThemedCanvas] -> node.
Future<void> _pumpNode(
  WidgetTester tester,
  Widget node, {
  required CanvasTheme chrome,
  required CanvasTheme components,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ThemedCanvas(
        theme: chrome,
        child: Scaffold(
          body: ThemedCanvas(theme: components, child: node),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Effective rendered color of the [Text] showing [text]: ambient
/// `DefaultTextStyle` (which carries the kit `WrappedText` merges such as
/// `large()`/`medium()`) merged with the `Text`'s own style (which carries
/// the catalog's explicit scheme binding after the fix).
Color _effectiveTextColor(WidgetTester tester, String text) {
  final element = tester.element(find.text(text));
  final ambient = DefaultTextStyle.of(element).style;
  final widget = element.widget as Text;
  final color = ambient.merge(widget.style).color;
  expect(color, isNotNull, reason: 'no resolved text color for "$text"');
  return color!;
}

/// Nearest colored ancestor behind the [Text] showing [text]: the surface
/// the text actually reads against (kit `AppBar`'s `Container(color:)` for
/// titles, kit `Scaffold`'s body `Container(color:)` for body text, kit
/// `DrawerWrapper`'s `BoxDecoration` for drawer text, kit `Card`'s
/// `OutlinedContainer` decoration for card text).
Color _surfaceBehind(WidgetTester tester, String text) {
  Color? found;
  tester.element(find.text(text)).visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Container) {
      if (widget.color != null) {
        found = widget.color;
        return false;
      }
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        found = decoration.color;
        return false;
      }
    }
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        found = decoration.color;
        return false;
      }
    }
    if (widget is ColoredBox) {
      found = widget.color;
      return false;
    }
    return true;
  });
  expect(found, isNotNull, reason: 'no colored surface behind "$text"');
  return found!;
}

/// Innermost (components) kit scheme installed by [_pumpNode].
shadcn.ColorScheme _componentsScheme(WidgetTester tester) => tester
    .widget<shadcn.Theme>(find.byType(shadcn.Theme).last)
    .data
    .colorScheme;

void main() {
  // resolveCanvasThemeData mutates the global InstalledThemePreset.current;
  // preserve it across tests (same idiom as theme_apply_test.dart).
  late shadcn.RegistryThemePreset prevPreset;
  setUp(() => prevPreset = shadcn.InstalledThemePreset.current);
  tearDown(() => shadcn.InstalledThemePreset.current = prevPreset);

  group('scaffold contrast (P11 J2)', () {
    testWidgets(
      'washed-out combo: supabase light components under dark chrome',
      (tester) async {
        await _pumpNode(
          tester,
          buildCatalogItem('scaffold', const {
            'title': 'Login',
            'body': 'Welcome back',
          }),
          chrome: _chromeDark,
          components: _componentsLight,
        );

        final titleColor = _effectiveTextColor(tester, 'Login');
        final barBg = _surfaceBehind(tester, 'Login');
        final titleContrast = _contrastRatio(titleColor, barBg);
        debugPrint(
          'K2 light-split title 0x${titleColor.toARGB32().toRadixString(16)} '
          'on bar 0x${barBg.toARGB32().toRadixString(16)} '
          '= ${titleContrast.toStringAsFixed(2)}:1',
        );
        expect(
          titleContrast,
          greaterThanOrEqualTo(_kMinContrast),
          reason: 'app-bar title washes out under supabase light + dark chrome',
        );

        final bodyColor = _effectiveTextColor(tester, 'Welcome back');
        final bodyBg = _surfaceBehind(tester, 'Welcome back');
        final bodyContrast = _contrastRatio(bodyColor, bodyBg);
        debugPrint(
          'K2 light-split body 0x${bodyColor.toARGB32().toRadixString(16)} '
          'on bg 0x${bodyBg.toARGB32().toRadixString(16)} '
          '= ${bodyContrast.toStringAsFixed(2)}:1',
        );
        expect(
          bodyContrast,
          greaterThanOrEqualTo(_kMinContrast),
          reason: 'scaffold body washes out under supabase light + dark chrome',
        );
      },
    );

    testWidgets('dark components stay crisp under dark chrome', (tester) async {
      await _pumpNode(
        tester,
        buildCatalogItem('scaffold', const {
          'title': 'Login',
          'body': 'Welcome back',
        }),
        chrome: _chromeDark,
        components: _componentsDark,
      );

      final titleContrast = _contrastRatio(
        _effectiveTextColor(tester, 'Login'),
        _surfaceBehind(tester, 'Login'),
      );
      debugPrint(
          'K2 dark title contrast = ${titleContrast.toStringAsFixed(2)}:1');
      expect(titleContrast, greaterThanOrEqualTo(_kMinContrast));

      final bodyContrast = _contrastRatio(
        _effectiveTextColor(tester, 'Welcome back'),
        _surfaceBehind(tester, 'Welcome back'),
      );
      debugPrint(
          'K2 dark body contrast = ${bodyContrast.toStringAsFixed(2)}:1');
      expect(bodyContrast, greaterThanOrEqualTo(_kMinContrast));
    });

    testWidgets('single-theme light stays crisp (no split)', (tester) async {
      await _pumpNode(
        tester,
        buildCatalogItem('scaffold', const {
          'title': 'Login',
          'body': 'Welcome back',
        }),
        chrome: _componentsLight,
        components: _componentsLight,
      );

      expect(
        _contrastRatio(
          _effectiveTextColor(tester, 'Login'),
          _surfaceBehind(tester, 'Login'),
        ),
        greaterThanOrEqualTo(_kMinContrast),
      );
      expect(
        _contrastRatio(
          _effectiveTextColor(tester, 'Welcome back'),
          _surfaceBehind(tester, 'Welcome back'),
        ),
        greaterThanOrEqualTo(_kMinContrast),
      );
    });

    testWidgets('builder binds bar/body to kit scheme roles explicitly', (
      tester,
    ) async {
      await _pumpNode(
        tester,
        buildCatalogItem('scaffold', const {
          'title': 'Login',
          'body': 'Welcome back',
        }),
        chrome: _chromeDark,
        components: _componentsLight,
      );

      final scheme = _componentsScheme(tester);
      final bar = tester.widget<shadcn.AppBar>(find.byType(shadcn.AppBar));
      expect(
        bar.backgroundColor,
        scheme.card,
        reason: 'AppBar must bind the kit card role, not a null default',
      );
      final scaffold = tester.widget<shadcn.Scaffold>(
        find.byType(shadcn.Scaffold),
      );
      expect(
        scaffold.backgroundColor,
        scheme.background,
        reason:
            'Scaffold must bind the kit background role, not a null default',
      );
      // Foregrounds ride the matching on-roles (no hardcoded colors).
      expect(
        _effectiveTextColor(tester, 'Login'),
        scheme.cardForeground,
      );
      expect(
        _effectiveTextColor(tester, 'Welcome back'),
        scheme.foreground,
      );
    });
  });

  group('sibling shells in the washed-out combo', () {
    // Drawer shared the scaffold's disease (bare panel texts + ambient
    // foreground + theme background: measured 1.20:1 pre-fix) and binds
    // `scheme.foreground` explicitly now. Card never had it: kit `Card`
    // wraps its child in `DefaultTextStyle.merge(color: cardForeground)`
    // itself (measured 17.47:1 pre-fix), so the catalog leaves it alone —
    // this pin documents that protection.
    testWidgets('drawer panel reads crisply in the split combo', (
      tester,
    ) async {
      await _pumpNode(
        tester,
        buildCatalogItem('drawer', const {
          'title': 'DrawerT',
          'content': 'DrawerC',
        }),
        chrome: _chromeDark,
        components: _componentsLight,
      );
      final scheme = _componentsScheme(tester);
      for (final label in ['DrawerT', 'DrawerC']) {
        final fg = _effectiveTextColor(tester, label);
        final bg = _surfaceBehind(tester, label);
        final ratio = _contrastRatio(fg, bg);
        debugPrint(
          'K2 drawer "$label" 0x${fg.toARGB32().toRadixString(16)} on '
          '0x${bg.toARGB32().toRadixString(16)} = ${ratio.toStringAsFixed(2)}:1',
        );
        expect(fg, scheme.foreground);
        expect(ratio, greaterThanOrEqualTo(_kMinContrast));
      }
    });

    testWidgets('drawer panel stays crisp when dark', (tester) async {
      await _pumpNode(
        tester,
        buildCatalogItem('drawer', const {
          'title': 'DrawerT',
          'content': 'DrawerC',
        }),
        chrome: _chromeDark,
        components: _componentsDark,
      );
      for (final label in ['DrawerT', 'DrawerC']) {
        expect(
          _contrastRatio(
            _effectiveTextColor(tester, label),
            _surfaceBehind(tester, label),
          ),
          greaterThanOrEqualTo(_kMinContrast),
        );
      }
    });

    testWidgets('card keeps kit-bound foregrounds (Z2 muted description)', (
      tester,
    ) async {
      // Track Z2 beauty cause: the description now binds `mutedForeground`
      // (the kit card preview's own `.muted().small()` idiom) while the
      // title stays on `cardForeground`. Both roles are kit scheme roles —
      // never hardcoded — and both still clear the 4.5 floor in this split
      // (title ~17.5:1, description ~15.9:1 at the time of the change).
      await _pumpNode(
        tester,
        buildCatalogItem('card', const {
          'title': 'CardT',
          'description': 'CardD',
          'showFooter': false,
        }),
        chrome: _chromeDark,
        components: _componentsLight,
      );
      final scheme = _componentsScheme(tester);
      final titleFg = _effectiveTextColor(tester, 'CardT');
      final titleRatio = _contrastRatio(
        titleFg,
        _surfaceBehind(tester, 'CardT'),
      );
      debugPrint(
          'K2 card "CardT" contrast = ${titleRatio.toStringAsFixed(2)}:1');
      expect(titleFg, scheme.cardForeground);
      expect(titleRatio, greaterThanOrEqualTo(_kMinContrast));

      final descFg = _effectiveTextColor(tester, 'CardD');
      final descRatio = _contrastRatio(descFg, _surfaceBehind(tester, 'CardD'));
      debugPrint(
          'K2 card "CardD" contrast = ${descRatio.toStringAsFixed(2)}:1');
      expect(descFg, scheme.mutedForeground);
      expect(descRatio, greaterThanOrEqualTo(_kMinContrast));
    });
  });
}
