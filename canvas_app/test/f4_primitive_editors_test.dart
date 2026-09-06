/// Track F4: inspector editors for layout primitives — the box-model
/// (`edgeInsets`) editor and the alignment grid.
///
/// Editors stay dumb (every edit reports through `onChanged` into
/// `store.patchItem`, so undo/redo keep working); the inspector integration
/// tests below prove the store round-trip for container padding and stack
/// alignment.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
