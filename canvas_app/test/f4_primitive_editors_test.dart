/// Track F4: inspector editors for layout primitives — the box-model
/// (`edgeInsets`) editor and the alignment grid.
///
/// Editors stay dumb (every edit reports through `onChanged` into
/// `store.patchItem`, so undo/redo keep working); the inspector integration
/// tests below prove the store round-trip for container padding and stack
/// alignment.
///
/// Track F4 remainder: the sizing-mode selector (fixed|expand|hug over the
/// derived [SizeMode] getters — no new JSON keys) and the paint editors
/// (color/radius/border/gradient/shadow). Every flow below is
/// set value → store updates → catalog rebuilds → codegen reflects, with
/// the codegen half asserted through the real bundle exporter.
library;

import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON round-trip guard for the sizing selector: re-encoding a decoded
/// doc is byte-identical and carries no sizing-mode keys (the modes are
/// derived, never stored — P16 reconciliation).
String _roundTripJson(ScreenDoc doc) {
  final first = jsonEncode(doc.toJson());
  final revived =
      ScreenDoc.fromJson(jsonDecode(first) as Map<String, dynamic>);
  expect(jsonEncode(revived.toJson()), first);
  expect(first.contains('widthMode'), isFalse);
  expect(first.contains('heightMode'), isFalse);
  expect(first.contains('sizeMode'), isFalse);
  return first;
}

/// Bundle text for [store]'s doc through the real exporter.
String _bundleText(CanvasStore store) {
  final bundle = buildCleanBundle(store.doc, const {});
  return bundle.files.values.join('\n');
}

/// The segmented sizing control rescoped to one tap: the width and height
/// selectors share option labels, so every tap scopes through the
/// `node-size-mode` key.
Future<void> _tapSizeMode(WidgetTester tester, String mode) async {
  final finder = find.descendant(
    of: find.byKey(const ValueKey('node-size-mode')),
    matching: find.text(mode),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

CanvasNode _nodeOf(CanvasStore store, String nodeId) =>
    store.doc.nodes.singleWhere((n) => n.id == nodeId);

Map<String, dynamic> _propsOf(CanvasStore store, String nodeId) =>
    _nodeOf(store, nodeId).items.single.props;

void main() {
  group('f4 box-model editor', () {
    test('parse covers every shape without throwing', () {
      expect(
        PropEdgeInsetsEditor.parse(null),
        {'l': 0.0, 't': 0.0, 'r': 0.0, 'b': 0.0},
      );
      expect(
        PropEdgeInsetsEditor.parse(12),
        {'l': 12.0, 't': 12.0, 'r': 12.0, 'b': 12.0},
      );
      expect(
        PropEdgeInsetsEditor.parse({
          '\$': 'edgeInsets',
          'v': {'l': 1, 't': 2, 'r': 3, 'b': 4},
        }),
        {'l': 1.0, 't': 2.0, 'r': 3.0, 'b': 4.0},
      );
      expect(
        PropEdgeInsetsEditor.parse({'l': 5}),
        {'l': 5.0, 't': 0.0, 'r': 0.0, 'b': 0.0},
      );
      expect(
        PropEdgeInsetsEditor.parse('nope'),
        {'l': 0.0, 't': 0.0, 'r': 0.0, 'b': 0.0},
      );
    });

    testWidgets('stepping Left reports the canonical map', (tester) async {
      Map<String, double>? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropEdgeInsetsEditor(
              value: const {'l': 8.0, 't': 0.0, 'r': 0.0, 'b': 0.0},
              onChanged: (v) => seen = v,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // One '+' stepper per side; tap the first (Left 8 → 12).
      await tester.tap(find.text('+').first);
      await tester.pump();
      expect(seen, {'l': 12.0, 't': 0.0, 'r': 0.0, 'b': 0.0});
    });
  });

  group('f4 alignment grid', () {
    test('read passes names through, exotic forms show nothing', () {
      expect(PropAlignmentGrid.read('topLeft'), 'topLeft');
      expect(PropAlignmentGrid.read(null), isNull);
      expect(
        PropAlignmentGrid.read({
          '\$': 'alignment',
          'v': {'x': 0.0, 'y': 0.0},
        }),
        isNull,
      );
    });

    testWidgets('tapping a cell reports its name', (tester) async {
      String? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropAlignmentGrid(
              value: 'center',
              onChanged: (v) => seen = v,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('topLeft'));
      await tester.pump();
      expect(seen, 'topLeft');
    });
  });

  group('f4 inspector integration', () {
    testWidgets('container node edits padding through the store', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();
      // Box-model editors for padding + margin (two Left labels); nudge
      // the padding one via its keyed editor.
      expect(find.text('Left'), findsNWidgets(2));
      expect(find.text('padding'), findsWidgets);
      final paddingPlus = find.descendant(
        of: find.byKey(const ValueKey('i1/padding')),
        matching: find.text('+'),
      );
      await tester.tap(paddingPlus.first);
      await tester.pump();
      final props = store.doc.nodes
          .singleWhere((n) => n.id == nodeId)
          .items
          .single
          .props;
      expect(props['padding'], {'l': 4.0, 't': 0.0, 'r': 0.0, 'b': 0.0});
    });

    testWidgets('stack node picks alignment through the store', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'stack')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('bottomRight'));
      await tester.pump();
      final props = store.doc.nodes
          .singleWhere((n) => n.id == nodeId)
          .items
          .single
          .props;
      expect(props['alignment'], 'bottomRight');
    });
  });

  group('f4 sizing-mode selector', () {
    testWidgets('f4_sizing_starts_hug_with_steppers_intact', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();
      // Derived hug: no stored dims, no expand role.
      expect(_nodeOf(store, nodeId).widthMode, SizeMode.hug);
      expect(_nodeOf(store, nodeId).heightMode, SizeMode.hug);
      // The selector mounts exactly once; the flex stepper stays out of
      // the tree while hug (row-gap `+` suites keep their unique match).
      expect(
        find.byKey(const ValueKey('node-size-mode')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('node-flex')), findsNothing);
      // Legacy steppers + presets below are untouched.
      expect(find.byKey(const ValueKey('node-width-inc')), findsWidgets);
      _roundTripJson(store.doc);
    });

    testWidgets('f4_sizing_expand_sets_flex_and_clears_dims', (tester) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      store.reparentNode(nodeId, rowId);
      store.setNodeSize(nodeId, w: 200, h: 100);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      await _tapSizeMode(tester, 'expand');
      final node = _nodeOf(store, nodeId);
      expect(node.expand, 'flex');
      expect(node.flex, 1);
      expect(node.w, isNull);
      expect(node.h, isNull);
      expect(node.widthMode, SizeMode.expand);
      // Flex stepper appears once expand lands.
      expect(find.byKey(const ValueKey('node-flex')), findsOneWidget);
      _roundTripJson(store.doc);
      // Codegen reflects the flex role through the real bundle exporter
      // (`expand: 'flex'` → `Flexible`; `'expanded'` → `Expanded`, a
      // distinction the F3 goldens pin — the selector writes `flex`).
      expect(_bundleText(store), contains('Flexible('));
      expect(_bundleText(store), contains('flex: 1'));
    });

    testWidgets('f4_sizing_fixed_seeds_missing_dims', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      await _tapSizeMode(tester, 'fixed');
      expect(_nodeOf(store, nodeId).w, 160.0);
      expect(_nodeOf(store, nodeId).h, 160.0);
      expect(_nodeOf(store, nodeId).widthMode, SizeMode.fixed);
      expect(_nodeOf(store, nodeId).heightMode, SizeMode.fixed);
      _roundTripJson(store.doc);
      // Re-picking fixed is a no-op: one undo returns to hug.
      await _tapSizeMode(tester, 'fixed');
      expect(store.undo(), isTrue);
      expect(_nodeOf(store, nodeId).w, isNull);
      expect(_nodeOf(store, nodeId).h, isNull);
    });

    testWidgets('f4_sizing_hug_clears_both', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      await _tapSizeMode(tester, 'expand');
      expect(_nodeOf(store, nodeId).widthMode, SizeMode.expand);
      await _tapSizeMode(tester, 'hug');
      final node = _nodeOf(store, nodeId);
      expect(node.w, isNull);
      expect(node.h, isNull);
      // hug clears the expand role via the documented default-equivalent
      // (`patchNode` has no null-clear path); it still derives to hug.
      expect(node.expand, 'none');
      expect(node.widthMode, SizeMode.hug);
      expect(find.byKey(const ValueKey('node-flex')), findsNothing);
      _roundTripJson(store.doc);
    });

    testWidgets('f4_sizing_row_card_selector', (tester) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InspectorPanel(store: store, nodeId: rowId)),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('node-size-mode')),
        findsOneWidget,
      );
      await _tapSizeMode(tester, 'expand');
      expect(_nodeOf(store, rowId).expand, 'flex');
      expect(_nodeOf(store, rowId).widthMode, SizeMode.expand);
      _roundTripJson(store.doc);
    });
  });

  group('f4 paint editors', () {
    test('f4_paint_parse_covers_shapes', () {
      expect(
        PropPaintEditor.parse({
          r'$': 'color',
          'v': {'kind': 'token', 'token': 'primary'},
        }),
        (token: 'primary', hex: ''),
      );
      expect(
        PropPaintEditor.parse({'kind': 'token', 'token': 'secondary'}),
        (token: 'secondary', hex: ''),
      );
      expect(
        PropPaintEditor.parse('#EF4444'),
        (token: null, hex: '#EF4444'),
      );
      expect(PropPaintEditor.parse(null), (token: null, hex: ''));
      expect(PropPaintEditor.parse('nope'), (token: null, hex: 'nope'));
    });

    testWidgets('f4_paint_token_emits_theme_accessor', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      // Token path: the tagged envelope (never a raw hex downstream).
      tester
          .widget<PropPaintEditor>(find.byKey(const ValueKey('i1/color')))
          .onChanged(PropPaintEditor.tokenEnvelope('primary'));
      await tester.pump();
      expect(_propsOf(store, nodeId)['color'], {
        r'$': 'color',
        'v': {'kind': 'token', 'token': 'primary'},
      });
      // Catalog rebuilds with the token color…
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('container', _propsOf(store, nodeId)),
          ),
        ),
      );
      await tester.pump();
      // …and codegen resolves the theme accessor, never a hex.
      expect(
        _bundleText(store),
        contains('Theme.of(context).colorScheme.primary'),
      );

      // Literal path: a raw hex string becomes `Color(0xFF…)`.
      store.patchItem(nodeId, 'i1', props: {'color': '#EF4444'});
      await tester.pump();
      expect(_bundleText(store), contains('Color(0xFFEF4444)'));
      _roundTripJson(store.doc);
    });

    testWidgets('f4_radius_uniform_collapses_to_circular', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      // The All stepper writes the raw num (uniform collapse).
      final all = find.descendant(
        of: find.byKey(const ValueKey('i1/radius')),
        matching: find.text('+'),
      );
      await tester.ensureVisible(all.first);
      await tester.pumpAndSettle();
      await tester.tap(all.first);
      await tester.pump();
      expect(_propsOf(store, nodeId)['radius'], 4.0);
      expect(_bundleText(store), contains('BorderRadius.circular(4)'));

      // Mixed corners keep the tagged envelope.
      tester
          .widget<PropBorderRadiusEditor>(
            find.byKey(const ValueKey('i1/radius')),
          )
          .onChanged(
            PropBorderRadiusEditor.collapse(
              const {'tl': 12.0, 'tr': 0.0, 'br': 0.0, 'bl': 0.0},
            ),
          );
      await tester.pump();
      expect(_propsOf(store, nodeId)['radius'], {
        r'$': 'borderRadius',
        'v': {'tl': 12.0, 'tr': 0.0, 'br': 0.0, 'bl': 0.0},
      });
      expect(_bundleText(store), contains('BorderRadius.only('));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('container', _propsOf(store, nodeId)),
          ),
        ),
      );
      await tester.pump();
      _roundTripJson(store.doc);
    });

    testWidgets('f4_border_writes_width_and_token_color', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      // Width stepper from the 1.0 default.
      final plus = find.descendant(
        of: find.byKey(const ValueKey('i1/border')),
        matching: find.text('+'),
      );
      await tester.ensureVisible(plus.first);
      await tester.pumpAndSettle();
      await tester.tap(plus.first);
      await tester.pump();
      expect(_propsOf(store, nodeId)['border'], {
        'color': null,
        'width': 2.0,
      });

      // Token color through the nested paint editor.
      tester
          .widget<PropBorderEditor>(find.byKey(const ValueKey('i1/border')))
          .onChanged({
        'color': PropPaintEditor.tokenEnvelope('secondary'),
        'width': 2.0,
      });
      await tester.pump();
      expect(
        _bundleText(store),
        contains(
          'Border.all(color: Theme.of(context).colorScheme.secondary, '
          'width: 2)',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('container', _propsOf(store, nodeId)),
          ),
        ),
      );
      await tester.pump();
      _roundTripJson(store.doc);
    });

    testWidgets('f4_gradient_add_stop_and_named_ends', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      // Add appends a token-bound stop with resolved default ends.
      final add = find.byKey(const ValueKey('gradient-add'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pump();
      final first = _propsOf(store, nodeId)['gradient'] as Map;
      expect(first['colors'], [
        {
          r'$': 'color',
          'v': {'kind': 'token', 'token': 'primary'},
        },
      ]);
      expect(first['begin'], {'x': -1.0, 'y': 0.0});
      expect(first['end'], {'x': 1.0, 'y': 0.0});

      // Named ends + two stops emit the collapsed gradient.
      tester
          .widget<PropGradientEditor>(
            find.byKey(const ValueKey('i1/gradient')),
          )
          .onChanged({
        'begin': {'x': -1.0, 'y': -1.0},
        'end': {'x': 1.0, 'y': 1.0},
        'colors': [
          PropPaintEditor.tokenEnvelope('primary'),
          '#EF4444',
        ],
      });
      await tester.pump();
      final emitted = _bundleText(store);
      expect(emitted, contains('LinearGradient('));
      expect(emitted, contains('begin: Alignment.topLeft'));
      expect(emitted, contains('end: Alignment.bottomRight'));
      expect(
        emitted,
        contains('Theme.of(context).colorScheme.primary'),
      );
      expect(emitted, contains('Color(0xFFEF4444)'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('container', _propsOf(store, nodeId)),
          ),
        ),
      );
      await tester.pump();
      _roundTripJson(store.doc);
    });

    testWidgets('f4_shadow_add_entry_and_codegen', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();

      final add = find.byKey(const ValueKey('shadow-add'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pump();
      final entries = _propsOf(store, nodeId)['shadow'] as List;
      expect(entries.length, 1);
      expect(_bundleText(store), contains('BoxShadow('));
      expect(_bundleText(store), contains('blurRadius: 4'));

      // Blur edits flow through the entry map.
      tester
          .widget<PropShadowEditor>(find.byKey(const ValueKey('i1/shadow')))
          .onChanged([
        {
          'color': PropPaintEditor.tokenEnvelope('primary'),
          'blur': 8.0,
          'offset': {'x': 0.0, 'y': 2.0},
          'spread': 0.0,
        },
      ]);
      await tester.pump();
      expect(_bundleText(store), contains('blurRadius: 8'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('container', _propsOf(store, nodeId)),
          ),
        ),
      );
      await tester.pump();
      _roundTripJson(store.doc);
    });

    testWidgets('f4_container_alignment_grid_present', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'container')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
          ),
        ),
      );
      await tester.pump();
      // The container alignment prop rides the same 3x3 grid as stack.
      expect(find.text('topLeft'), findsWidgets);
      await tester.ensureVisible(find.text('topLeft').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('topLeft').first);
      await tester.pump();
      expect(_propsOf(store, nodeId)['alignment'], 'topLeft');
      expect(_bundleText(store), contains('Alignment.topLeft'));
    });
  });
}
