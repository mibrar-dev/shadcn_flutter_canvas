/// Track F3 (app side): the §7.5 definition-of-done tree composes through
/// the real catalog builders and pumps clean — the editor renders what the
/// F3 exporters emit (codegen goldens live in
/// `canvas_core/test/primitives_f3_goldens_test.dart`).
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The §7.5 tree built exactly as the renderers build it: already-built
/// children spliced into each container builder (see `NodeBuilder`).
Widget _sectionTree() {
  final nameCol = buildCatalogItem('column', {
    'gap': 4
  }, const [
    Text('Ada K'),
    Text('Engineer'),
  ]);
  final heroRow = Row(
    children: [
      buildCatalogItem('avatar', {'initials': 'AK'}),
      nameCol,
      buildCatalogItem('spacer', {'flex': 1}),
      buildCatalogItem('badge', {'label': 'Pro', 'variant': 'secondary'}),
    ],
  );
  final hero = buildCatalogItem('container', {
    'padding': {
      '\$': 'edgeInsets',
      'v': {'l': 20, 't': 20, 'r': 20, 'b': 20},
    },
    'color': {
      '\$': 'color',
      'v': {
        'kind': 'token',
        'token': 'primaryContainer',
      },
    },
    'radius': {
      '\$': 'borderRadius',
      'v': {'tl': 16, 'tr': 16, 'br': 16, 'bl': 16},
    },
    'gradient': {
      'begin': {'x': -1.0, 'y': 0.0},
      'end': {'x': 1.0, 'y': 0.0},
      'colors': [
        {'kind': 'token', 'token': 'primary'},
        {'kind': 'token', 'token': 'secondary'},
      ],
    },
  }, [
    heroRow
  ]);
  final cards = buildCatalogItem('column', {
    'gap': 12
  }, [
    buildCatalogItem('card', {
      'title': 'Card 1',
      'description': 'First',
    }),
    buildCatalogItem('card', {
      'title': 'Card 2',
      'description': 'Second',
    }),
    buildCatalogItem('card', {
      'title': 'Card 3',
      'description': 'Third',
    }),
  ]);
  return buildCatalogItem('column', {}, [
    hero,
    buildCatalogItem('sized_box', {'height': 24}),
    buildCatalogItem('expanded', {}, [cards]),
  ]);
}

void main() {
  group('f3 §7.5 render composition', () {
    testWidgets('the full tree pumps with every expected widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _sectionTree())),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Hero gradient container with the row inside.
      expect(find.text('Ada K'), findsOneWidget);
      expect(find.text('Engineer'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
      // Gap box + expanded card column.
      expect(find.text('Card 1'), findsOneWidget);
      expect(find.text('Card 2'), findsOneWidget);
      expect(find.text('Card 3'), findsOneWidget);
      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('renders in dark mode too', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: _sectionTree()),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Card 3'), findsOneWidget);
    });
  });
}
