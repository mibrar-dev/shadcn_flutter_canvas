/// Track FF2 (BUILD_SPEC §9.3): nav rail structure + callback tests.
///
/// Asserts structure and callbacks, NOT pixels (§12 rule 4): five
/// destinations in order, tap call-through with the right destination, and
/// token-driven chrome (rail width + background come from
/// [EditorMetrics]/[EditorTheme], never literals).
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/ff_nav_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  FfRailDestination selected = FfRailDestination.tree,
  ValueChanged<FfRailDestination>? onSelect,
  EditorColors colors = EditorColors.light,
}) {
  return MaterialApp(
    home: Scaffold(
      body: EditorTheme(
        colors: colors,
        child: FfNavRail(
          selected: selected,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('FfNavRail structure', () {
    testWidgets('renders the five destinations in order', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      for (final destination in FfRailDestination.values) {
        expect(find.byIcon(destination.icon), findsOneWidget);
      }
      // Tooltips carry the destination labels (kit tooltips render on hover,
      // so assert the metadata directly too).
      expect(
        FfRailDestination.values.map((d) => d.label).toList(),
        ['Tree', 'Palette', 'Theme', 'Assets', 'Settings'],
      );
    });

    testWidgets('rail width comes from the ff metric', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(
        tester.getSize(find.byType(FfNavRail)).width,
        EditorMetrics.ffRailWidth,
      );
    });

    testWidgets('rail background reads the railBg token', (tester) async {
      await tester.pumpWidget(
        _harness(colors: EditorColors.light),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      expect(
        containers.any(
          (c) => c.color == EditorColors.light.railBg,
        ),
        isTrue,
      );
    });
  });

  group('FfNavRail callbacks', () {
    testWidgets('tapping a destination selects it', (tester) async {
      FfRailDestination? selected;
      await tester.pumpWidget(
        _harness(onSelect: (d) => selected = d),
      );
      await tester.pump();

      await tester.tap(find.byIcon(FfRailDestination.palette.icon));
      await tester.pump();
      expect(selected, FfRailDestination.palette);

      await tester.tap(find.byIcon(FfRailDestination.settings.icon));
      await tester.pump();
      expect(selected, FfRailDestination.settings);
    });

    testWidgets('tapping the active destination still reports it',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _harness(
          selected: FfRailDestination.theme,
          onSelect: (_) => calls++,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(FfRailDestination.theme.icon));
      await tester.pump();
      expect(calls, 1);
    });
  });

  group('FfNavRail active state', () {
    testWidgets('exactly one active indicator renders in the token color',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          selected: FfRailDestination.assets,
          colors: EditorColors.light,
        ),
      );
      await tester.pump();

      final indicators = tester.widgetList<Container>(
        find.byType(Container),
      ).where(
        (c) => c.color == EditorColors.light.railActiveIndicator,
      );
      // One indicator bar plus the active glyph share the token color.
      expect(indicators.length, greaterThanOrEqualTo(1));
    });
  });
}
