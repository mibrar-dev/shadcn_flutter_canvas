/// Track C1 composition render tests: recursive nesting in `ScreenSurface`
/// (via [DesignCanvas]) and [PreviewPlayer].
///
/// Covers: container-with-child inside chrome (find descendant), 3-deep
/// nesting, row-in-card + card-in-row, leaf below-fallback, hidden parent
/// pruning a nested action (untappable), childless/row-only golden behavior,
/// and cycle-safe corrupt docs (timeout-guarded pumps).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): the phone frame is 343x725 and overflows
/// the default 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Wide viewport so desktop stages (1100) are never clamped by the window.
void _useWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ScreenDoc _doc(
  List<Map<String, dynamic>> nodes, {
  List<Map<String, dynamic>>? screens,
}) => ScreenDoc.fromJson({
  'screens':
      screens ??
      [
        {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
  'nodes': nodes,
  'theme': {
    'paletteKey': 'clean-slate',
    'dark': true,
    'shape': 'rounded',
    'motion': 'standard',
  },
  'meta': {'title': 'Nesting', 'brief': ''},
});

Future<void> _pumpCanvas(WidgetTester tester, ScreenDoc doc) async {
  final store = CanvasStore(initial: doc);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PreviewPlayer(doc: doc))),
  );
  await tester.pump();
}

/// Card node holding one button child.
ScreenDoc _cardWithButtonDoc() => _doc([
  {
    'id': 'card1',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'items': [
      {
        'id': 'icard',
        'kind': 'card',
        'title': 'Outer Card',
        'description': 'Outer Desc',
      },
    ],
  },
  {
    'id': 'btn1',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'card1',
    'items': [
      {'id': 'ibtn', 'kind': 'button', 'label': 'Inner Btn'},
    ],
  },
]);

/// Three-deep container chain: card > outlined_container > button.
ScreenDoc _deepChainDoc() => _doc([
  {
    'id': 'l1',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'items': [
      {'id': 'il1', 'kind': 'card', 'title': 'Level1', 'description': 'Top'},
    ],
  },
  {
    'id': 'l2',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'l1',
    'items': [
      {'id': 'il2', 'kind': 'outlined_container', 'label': 'Mid Box'},
    ],
  },
  {
    'id': 'l3',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'l2',
    'items': [
      {'id': 'il3', 'kind': 'button', 'label': 'Deep Btn'},
    ],
  },
]);

/// Both cross directions: a row nested in a card, and a card nested in a row.
ScreenDoc _rowBothWaysDoc() => _doc([
  {
    'id': 'cardA',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'items': [
      {'id': 'icardA', 'kind': 'card', 'title': 'Card Host'},
    ],
  },
  {
    'id': 'rowA',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'cardA',
    'isRow': true,
    'gap': 8.0,
    'items': [],
  },
  {
    'id': 'strip1',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'rowA',
    'items': [
      {'id': 'istrip1', 'kind': 'button', 'label': 'Strip Left'},
    ],
  },
  {
    'id': 'strip2',
    'screenId': 's1',
    'x': 10.0,
    'y': 0.0,
    'parentId': 'rowA',
    'items': [
      {'id': 'istrip2', 'kind': 'badge', 'label': 'Strip Right'},
    ],
  },
  {
    'id': 'rowB',
    'screenId': 's1',
    'x': 0.0,
    'y': 100.0,
    'isRow': true,
    'gap': 8.0,
    'items': [],
  },
  {
    'id': 'cardB',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'rowB',
    'items': [
      {'id': 'icardB', 'kind': 'card', 'title': 'Row Card'},
    ],
  },
  {
    'id': 'tagB',
    'screenId': 's1',
    'x': 10.0,
    'y': 0.0,
    'parentId': 'rowB',
    'items': [
      {'id': 'itagB', 'kind': 'badge', 'label': 'Row Tag'},
    ],
  },
]);

/// Leaf (button) node with a badge child: the §1 below-fallback.
ScreenDoc _leafFallbackDoc() => _doc([
  {
    'id': 'leafTop',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'items': [
      {'id': 'ileaf', 'kind': 'button', 'label': 'Leaf Top'},
    ],
  },
  {
    'id': 'leafKid',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'leafTop',
    'items': [
      {'id': 'ikid', 'kind': 'badge', 'label': 'Leaf Kid'},
    ],
  },
]);

/// Mobile-hidden card holding a button whose action navigates to Away.
ScreenDoc _hiddenActionDoc() => _doc(
  [
    {
      'id': 'hideCard',
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'hiddenOn': ['mobile'],
      'items': [
        {'id': 'ihide', 'kind': 'card', 'title': 'Hide Card'},
      ],
    },
    {
      'id': 'secretBtn',
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'parentId': 'hideCard',
      'items': [
        {
          'id': 'isecret',
          'kind': 'button',
          'label': 'Secret Go',
          'action': {'to': 's2', 'transition': 'slide'},
        },
      ],
    },
    {
      'id': 'awayMark',
      'screenId': 's2',
      'x': 0.0,
      'y': 0.0,
      'items': [
        {'id': 'iarrived', 'kind': 'button', 'label': 'Arrived Mark'},
      ],
    },
  ],
  screens: [
    {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    {'id': 's2', 'name': 'Away', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
  ],
);

/// Childless doc: solo roots plus one row-only group (no nesting).
ScreenDoc _childlessDoc() => _doc([
  {
    'id': 'soloBtn',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'items': [
      {'id': 'isolo', 'kind': 'button', 'label': 'Solo Btn'},
    ],
  },
  {
    'id': 'soloCard',
    'screenId': 's1',
    'x': 0.0,
    'y': 50.0,
    'items': [
      {'id': 'isoloCard', 'kind': 'card', 'title': 'Solo Card'},
    ],
  },
  {
    'id': 'rowR',
    'screenId': 's1',
    'x': 0.0,
    'y': 100.0,
    'isRow': true,
    'gap': 8.0,
    'items': [],
  },
  {
    'id': 'rOne',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'rowR',
    'items': [
      {'id': 'irOne', 'kind': 'button', 'label': 'R One'},
    ],
  },
  {
    'id': 'rTwo',
    'screenId': 's1',
    'x': 10.0,
    'y': 0.0,
    'parentId': 'rowR',
    'items': [
      {'id': 'irTwo', 'kind': 'badge', 'label': 'R Two'},
    ],
  },
]);

/// Corrupt doc: an A↔B parent cycle, a self-parent, and one healthy root.
/// `validateNesting` reports the cycle/self-parent; renderers must terminate
/// (unreachable cyclic nodes simply never render).
ScreenDoc _cycleDoc() => _doc([
  {
    'id': 'healthy',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'items': [
      {'id': 'ihealthy', 'kind': 'button', 'label': 'Cycle Root'},
    ],
  },
  {
    'id': 'cycA',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'cycB',
    'items': [
      {'id': 'icycA', 'kind': 'button', 'label': 'Cycle A'},
    ],
  },
  {
    'id': 'cycB',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'cycA',
    'items': [
      {'id': 'icycB', 'kind': 'button', 'label': 'Cycle B'},
    ],
  },
  {
    'id': 'selfS',
    'screenId': 's1',
    'x': 0.0,
    'y': 0.0,
    'parentId': 'selfS',
    'items': [
      {'id': 'iself', 'kind': 'button', 'label': 'Self Loop'},
    ],
  },
]);

void main() {
  group('container with button child (canvas)', () {
    testWidgets('button renders inside the card chrome', (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(tester, _cardWithButtonDoc());

      expect(find.text('Outer Card'), findsOneWidget);
      expect(find.text('Inner Btn'), findsOneWidget);
      final card = find.ancestor(
        of: find.text('Outer Card'),
        matching: find.byType(shadcn.Card),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Inner Btn')),
        findsOneWidget,
      );
    });

    testWidgets('3-deep chain nests inside each chrome', (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(tester, _deepChainDoc());

      expect(find.text('Level1'), findsOneWidget);
      expect(find.text('Mid Box'), findsOneWidget);
      expect(find.text('Deep Btn'), findsOneWidget);
      final card = find.ancestor(
        of: find.text('Level1'),
        matching: find.byType(shadcn.Card),
      );
      expect(card, findsOneWidget);
      final mid = find.ancestor(
        of: find.text('Mid Box'),
        matching: find.byType(shadcn.OutlinedContainer),
      );
      expect(mid, findsOneWidget);
      // Outlined box sits inside the card; the button sits inside the box.
      expect(find.descendant(of: card, matching: mid), findsOneWidget);
      expect(
        find.descendant(of: mid, matching: find.text('Deep Btn')),
        findsOneWidget,
      );
    });

    testWidgets('row-in-card is horizontal, card-in-row keeps chrome', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(tester, _rowBothWaysDoc());

      // Row inside the card: horizontal strip, both children in the chrome.
      final host = find.ancestor(
        of: find.text('Card Host'),
        matching: find.byType(shadcn.Card),
      );
      expect(host, findsOneWidget);
      expect(
        find.descendant(of: host, matching: find.text('Strip Left')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: host, matching: find.text('Strip Right')),
        findsOneWidget,
      );
      final leftX = tester.getTopLeft(find.text('Strip Left')).dx;
      final rightX = tester.getTopLeft(find.text('Strip Right')).dx;
      expect(leftX, lessThan(rightX));

      // Card inside the row: chrome kept, laid out beside its sibling.
      expect(find.text('Row Card'), findsOneWidget);
      expect(find.text('Row Tag'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Row Card'),
          matching: find.byType(shadcn.Card),
        ),
        findsOneWidget,
      );
      final cardX = tester.getTopLeft(find.text('Row Card')).dx;
      final tagX = tester.getTopLeft(find.text('Row Tag')).dx;
      expect(cardX, lessThan(tagX));
    });

    testWidgets('leaf child stacks below the parent widget', (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(tester, _leafFallbackDoc());

      expect(find.text('Leaf Top'), findsOneWidget);
      expect(find.text('Leaf Kid'), findsOneWidget);
      // Below, not beside: the fallback is a vertical stack.
      final topY = tester.getTopLeft(find.text('Leaf Top')).dy;
      final kidY = tester.getTopLeft(find.text('Leaf Kid')).dy;
      expect(kidY, greaterThan(topY));
      // And never inside chrome: no container chrome in this doc renders
      // the kid as a descendant.
      expect(
        find.ancestor(
          of: find.text('Leaf Kid'),
          matching: find.byType(shadcn.Card),
        ),
        findsNothing,
      );
    });
  });

  group('container with button child (preview)', () {
    testWidgets('button renders inside the card chrome', (tester) async {
      _useWideViewport(tester);
      await _pumpPreview(tester, _cardWithButtonDoc());

      final card = find.ancestor(
        of: find.text('Outer Card'),
        matching: find.byType(shadcn.Card),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Inner Btn')),
        findsOneWidget,
      );
    });

    testWidgets('row-in-card is horizontal, card-in-row keeps chrome', (
      tester,
    ) async {
      _useWideViewport(tester);
      await _pumpPreview(tester, _rowBothWaysDoc());

      final host = find.ancestor(
        of: find.text('Card Host'),
        matching: find.byType(shadcn.Card),
      );
      expect(
        find.descendant(of: host, matching: find.text('Strip Left')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: host, matching: find.text('Strip Right')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Strip Left')).dx,
        lessThan(tester.getTopLeft(find.text('Strip Right')).dx),
      );
      expect(find.text('Row Card'), findsOneWidget);
      expect(find.text('Row Tag'), findsOneWidget);
    });

    testWidgets('leaf child stacks below the parent widget', (tester) async {
      _useWideViewport(tester);
      await _pumpPreview(tester, _leafFallbackDoc());

      expect(find.text('Leaf Top'), findsOneWidget);
      expect(find.text('Leaf Kid'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Leaf Kid')).dy,
        greaterThan(tester.getTopLeft(find.text('Leaf Top')).dy),
      );
    });
  });

  group('hidden parent hides nested action (preview)', () {
    testWidgets('nested action untappable on mobile, works on desktop', (
      tester,
    ) async {
      _useWideViewport(tester);
      await _pumpPreview(tester, _hiddenActionDoc());

      // Phone stage is the mobile tier: the hidden card prunes its whole
      // subtree, so the nested action is absent (hence untappable).
      expect(find.text('mobile · 390'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Hide Card'), findsNothing);
      expect(find.text('Secret Go'), findsNothing);

      // Desktop re-tiers: the subtree renders and the nested action works.
      await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
      await tester.pump();
      expect(find.text('desktop · 1100'), findsOneWidget);
      expect(find.text('Hide Card'), findsOneWidget);
      expect(find.text('Secret Go'), findsOneWidget);

      await tester.tap(find.text('Secret Go'));
      await tester.pump();
      expect(find.text('Away'), findsOneWidget);
      expect(find.text('Arrived Mark'), findsOneWidget);
      expect(find.text('Secret Go'), findsNothing);
    });
  });

  group('childless golden behavior intact', () {
    testWidgets('canvas renders solo roots and row order', (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(tester, _childlessDoc());

      expect(find.text('Solo Btn'), findsOneWidget);
      expect(find.text('Solo Card'), findsOneWidget);
      expect(find.text('R One'), findsOneWidget);
      expect(find.text('R Two'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('R One')).dx,
        lessThan(tester.getTopLeft(find.text('R Two')).dx),
      );
    });

    testWidgets('preview renders solo roots and row order', (tester) async {
      _useWideViewport(tester);
      await _pumpPreview(tester, _childlessDoc());

      expect(find.text('Solo Btn'), findsOneWidget);
      expect(find.text('Solo Card'), findsOneWidget);
      expect(find.text('R One'), findsOneWidget);
      expect(find.text('R Two'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('R One')).dx,
        lessThan(tester.getTopLeft(find.text('R Two')).dx),
      );
    });
  });

  group('corrupt cycle docs terminate', () {
    testWidgets('canvas renders the healthy root without hanging', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _cycleDoc());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      // Timeout-guarded: a recursion without the visited-set guard would
      // never settle this pump.
      await tester.pump().timeout(const Duration(seconds: 10));

      expect(find.text('Cycle Root'), findsOneWidget);
      // Unreachable cyclic/self-parented nodes never render.
      expect(find.text('Cycle A'), findsNothing);
      expect(find.text('Cycle B'), findsNothing);
      expect(find.text('Self Loop'), findsNothing);
    });

    testWidgets('preview renders the healthy root without hanging', (
      tester,
    ) async {
      _useWideViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(doc: _cycleDoc())),
        ),
      );
      await tester.pump().timeout(const Duration(seconds: 10));

      expect(find.text('Cycle Root'), findsOneWidget);
      expect(find.text('Cycle A'), findsNothing);
      expect(find.text('Cycle B'), findsNothing);
      expect(find.text('Self Loop'), findsNothing);
    });
  });
}
