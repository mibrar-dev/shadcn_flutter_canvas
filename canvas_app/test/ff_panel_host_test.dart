/// Track FF2 (BUILD_SPEC §9.3): panel host structure tests.
///
/// Asserts structure, NOT pixels (§12 rule 4): the host shows the selected
/// destination's panel (header + body), hides the rest, keeps state across
/// switches via [IndexedStack], and renders empty for missing destinations.
/// The host owns no callbacks — selection lives in [FfNavRail].
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/ff_nav_rail.dart';
import 'package:canvas_app/ui/ff_panel_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  FfRailDestination selected = FfRailDestination.tree,
  Map<FfRailDestination, Widget>? panels,
  EditorColors colors = EditorColors.light,
}) {
  return MaterialApp(
    home: Scaffold(
      body: EditorTheme(
        colors: colors,
        child: FfPanelHost(
          selected: selected,
          panels: panels ??
              {
                FfRailDestination.tree: const Text('tree body'),
                FfRailDestination.palette: const Text('palette body'),
                FfRailDestination.theme: const Text('theme body'),
                FfRailDestination.assets: const Text('assets body'),
                FfRailDestination.settings: const Text('settings body'),
              },
        ),
      ),
    ),
  );
}

void main() {
  group('FfPanelHost structure', () {
    testWidgets('shows the selected panel with its header', (tester) async {
      await tester.pumpWidget(_harness(selected: FfRailDestination.tree));
      await tester.pump();

      // Header carries the destination label; body shows its panel.
      expect(find.text('Tree'), findsOneWidget);
      expect(find.text('tree body'), findsOneWidget);
      expect(find.text('palette body'), findsNothing);
    });

    testWidgets('switching destinations swaps header + body', (tester) async {
      await tester.pumpWidget(_harness(selected: FfRailDestination.tree));
      await tester.pump();
      expect(find.text('tree body'), findsOneWidget);

      await tester.pumpWidget(_harness(selected: FfRailDestination.palette));
      await tester.pump();
      expect(find.text('Palette'), findsOneWidget);
      expect(find.text('palette body'), findsOneWidget);
      expect(find.text('tree body'), findsNothing);
    });

    testWidgets('host width comes from the ff metric', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(
        tester.getSize(find.byType(FfPanelHost)).width,
        EditorMetrics.ffPanelWidth,
      );
    });

    testWidgets('missing destinations render empty without crashing',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          selected: FfRailDestination.assets,
          panels: const {FfRailDestination.tree: Text('tree body')},
        ),
      );
      await tester.pump();

      expect(find.text('Assets'), findsOneWidget);
      expect(find.text('tree body'), findsNothing);
    });

    testWidgets('stateful panels keep state across switches', (tester) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);
      Widget shell(FfRailDestination selected) => MaterialApp(
            home: Scaffold(
              body: EditorTheme(
                colors: EditorColors.light,
                child: FfPanelHost(
                  selected: selected,
                  panels: {
                    FfRailDestination.tree: TextField(
                      key: const ValueKey('tree-search'),
                      controller: searchController,
                    ),
                    FfRailDestination.palette: const Text('palette body'),
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(shell(FfRailDestination.tree));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('tree-search')),
        'button',
      );
      await tester.pump();

      await tester.pumpWidget(shell(FfRailDestination.palette));
      await tester.pump();
      await tester.pumpWidget(shell(FfRailDestination.tree));
      await tester.pump();

      expect(searchController.text, 'button');
    });
  });
}
