/// Track F2: the ten layout primitives — catalog builders render real
/// Flutter widgets, schemas cover every default, and the registry bridges
/// them in a first-ordered `Layout Primitives` section.
///
/// Flex-role kinds (`expanded`, `spacer`) pump inside a `Column`/`Row`
/// (bare pumps violate the Flutter `ParentDataWidget` contract by design —
/// see `_kFlexKinds` in `narrow_width_test.dart`).
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:canvas_app/canvas/props_schema.dart';
import 'package:canvas_core/canvas_core.dart' show kFlowRowGapDefault;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _kPrimitiveKinds = [
  'container',
  'column',
  'row',
  'stack',
  'padding',
  'center',
  'align',
  'expanded',
  'sized_box',
  'spacer',
];

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> _pumpFlex(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Column(children: [widget]))),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  group('f2 primitive catalog entries', () {
    test('all ten kinds are registered with labels and defaults', () {
      for (final kind in _kPrimitiveKinds) {
        final entry = findEntry(kind);
        expect(entry, isNotNull, reason: kind);
        expect(entry!.label, isNotEmpty, reason: kind);
        expect(entry.defaults, isNotEmpty, reason: kind);
      }
    });

    test('container-kind membership: nine containers, spacer is a leaf', () {
      for (final kind in [
        'container',
        'column',
        'row',
        'stack',
        'padding',
        'center',
        'align',
        'expanded',
        'sized_box',
      ]) {
        expect(kContainerKinds, contains(kind));
      }
      expect(kContainerKinds, isNot(contains('spacer')));
    });

    test('registry Layout Primitives section is first with ten bridges', () {
      expect(kRegistrySectionOrder.first, 'Layout Primitives');
      final entries = registrySectionEntries('Layout Primitives');
      expect(
        entries.map((e) => e.kind).toSet(),
        _kPrimitiveKinds.toSet(),
      );
      for (final entry in entries) {
        expect(entry.canvasReady, isTrue, reason: entry.kind);
      }
    });
  });

  group('f2 primitive schemas', () {
    test('every primitive kind resolves a schema', () {
      for (final kind in _kPrimitiveKinds) {
        expect(
          kPropSchemas.containsKey(kind),
          isTrue,
          reason: 'missing schema for $kind',
        );
      }
    });

    test('container style vocabulary specs exist', () {
      for (final name in [
        'color',
        'padding',
        'margin',
        'radius',
        'border',
        'gradient',
        'shadow',
      ]) {
        expect(findSpec('container', name), isNotNull, reason: name);
      }
    });

    test('defaults resolve through specs', () {
      expect(resolveProp('column', 'gap', {}, null), 12.0);
      expect(resolveProp('row', 'gap', {}, null), kFlowRowGapDefault);
      expect(resolveProp('align', 'alignment', {}, null), 'center');
      expect(resolveProp('expanded', 'flex', {}, null), 1);
      expect(resolveProp('container', 'color', {}, null), isNull);
    });
  });

  group('f2 primitive builders', () {
    testWidgets('container merges color+radius into BoxDecoration', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('container', {
          'color': {
            '\$': 'color',
            'v': {
              'kind': 'token',
              'token': 'primary',
            },
          },
          'radius': 16.0,
          'padding': 20,
        }, [const Text('kid')]),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.padding, const EdgeInsets.all(20));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Theme.of(
        tester.element(find.byType(Container).first),
      ).colorScheme.primary);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(find.text('kid'), findsOneWidget);
    });

    testWidgets('container literal hex color needs no theme', (tester) async {
      await _pump(
        tester,
        buildCatalogItem('container', {
          'color': '#FF2196F3',
          'padding': {
            '\$': 'edgeInsets',
            'v': {'l': 1, 't': 2, 'r': 3, 'b': 4},
          },
        }),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.padding, const EdgeInsets.fromLTRB(1, 2, 3, 4));
      // Color-only: direct `color:` arg, no decoration (§6.2).
      expect(container.decoration, isNull);
      expect(container.color, const Color(0xFF2196F3));
    });

    testWidgets('container color without decoration stays direct', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('container', {
          'color': {'\$': 'color', 'v': {'kind': 'token', 'token': 'surface'}},
        }, [const Text('kid')]),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isNull);
      expect(container.color, isNotNull);
    });

    testWidgets('childless container shows its ghost', (tester) async {
      await _pump(tester, buildCatalogItem('container', {}));
      expect(find.text('container'), findsOneWidget);
    });

    testWidgets('column lays out children with gap separators', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('column', {
          'gap': 4.0,
          'mainAxis': 'center',
        }, [const Text('a'), const Text('b')]),
      );
      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
      expect(find.byType(SizedBox), findsOneWidget);
      final gap = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(gap.height, 4.0);
    });

    testWidgets('row item-kind lays out children horizontally', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('row', {
          'gap': 8.0,
        }, [const Text('a'), const Text('b')]),
      );
      expect(find.byType(Row), findsOneWidget);
      final gap = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(gap.width, 8.0);
    });

    testWidgets('stack/padding/center/align wrap a single child', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('stack', {
          'alignment': 'topLeft',
        }, [const Text('s')]),
      );
      expect(
        tester
            .widget<Stack>(
              find.ancestor(
                of: find.text('s'),
                matching: find.byType(Stack),
              ),
            )
            .alignment,
        Alignment.topLeft,
      );
      await _pump(
        tester,
        buildCatalogItem('padding', {
          'padding': 24,
        }, [const Text('p')]),
      );
      expect(
        tester
            .widget<Padding>(
              find.ancestor(
                of: find.text('p'),
                matching: find.byType(Padding),
              ),
            )
            .padding,
        const EdgeInsets.all(24),
      );
      await _pump(tester, buildCatalogItem('center', {}, [const Text('c')]));
      expect(find.byType(Center), findsOneWidget);
      await _pump(
        tester,
        buildCatalogItem('align', {
          'alignment': 'bottomRight',
        }, [const Text('a')]),
      );
      expect(
        tester
            .widget<Align>(
              find.ancestor(
                of: find.text('a'),
                matching: find.byType(Align),
              ),
            )
            .alignment,
        Alignment.bottomRight,
      );
    });

    testWidgets('expanded and spacer render flex in Flex contexts', (
      tester,
    ) async {
      await _pumpFlex(
        tester,
        buildCatalogItem('expanded', {
          'flex': 2,
        }, [const Text('e')]),
      );
      final expanded = tester.widget<Expanded>(find.byType(Expanded).first);
      expect(expanded.flex, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [buildCatalogItem('spacer', {'flex': 2})],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(Spacer), findsOneWidget);
      expect(tester.widget<Spacer>(find.byType(Spacer)).flex, 2);
    });

    testWidgets('sized_box pins dims; dimless+childless shows ghost', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('sized_box', {'width': 120.0, 'height': 60.0}),
      );
      final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(box.width, 120.0);
      expect(box.height, 60.0);
      await _pump(tester, buildCatalogItem('sized_box', {}));
      expect(find.text('sized_box'), findsOneWidget);
    });

    testWidgets('two kids under a single slot wrap in a Column', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('padding', {
          'padding': 8,
        }, [const Text('a'), const Text('b')]),
      );
      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.child, isA<Column>());
    });

    testWidgets('gradient + shadow + border build without throwing', (
      tester,
    ) async {
      await _pump(
        tester,
        buildCatalogItem('container', {
          'gradient': {
            'begin': {'x': -1.0, 'y': 0.0},
            'end': {'x': 1.0, 'y': 0.0},
            'colors': [
              {
                'kind': 'token',
                'token': 'primary',
              },
              {
                'kind': 'token',
                'token': 'secondary',
              },
            ],
          },
          'border': {
            'color': '#FF000000',
            'width': 2,
          },
          'shadow': [
            {
              'color': '#40000000',
              'blur': 8,
              'offset': {'x': 0, 'y': 2},
            },
          ],
          'radius': 16.0,
        }, [const Text('kid')]),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, hasLength(1));
    });
  });
}
