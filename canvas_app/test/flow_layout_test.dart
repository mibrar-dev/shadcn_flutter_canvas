import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doc with a row container holding two children plus two root leaves.
ScreenDoc _rowDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'r1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [],
          'parentId': null,
          'isRow': true,
          'gap': 8.0,
        },
        {
          'id': 'a',
          'screenId': 's1',
          'x': 0.0,
          'y': 10.0,
          'items': [
            {'id': 'ia', 'kind': 'button', 'label': 'A'},
          ],
          'parentId': null,
          'isRow': false,
          'gap': 8.0,
        },
        {
          'id': 'b',
          'screenId': 's1',
          'x': 0.0,
          'y': 20.0,
          'items': [
            {'id': 'ib', 'kind': 'badge', 'label': 'B'},
          ],
          'parentId': null,
          'isRow': false,
          'gap': 8.0,
        },
        {
          'id': 'c1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'ic1', 'kind': 'button', 'label': 'C1'},
          ],
          'parentId': 'r1',
          'isRow': false,
          'gap': 8.0,
        },
        {
          'id': 'c2',
          'screenId': 's1',
          'x': 10.0,
          'y': 0.0,
          'items': [
            {'id': 'ic2', 'kind': 'badge', 'label': 'C2'},
          ],
          'parentId': 'r1',
          'isRow': false,
          'gap': 8.0,
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Flow', 'brief': ''},
    });

/// Doc order of one flow group (roots when [parentId] is null).
List<String> _groupOrder(CanvasStore store, String? parentId) => [
      for (final n in store.doc.nodes)
        if (n.screenId == 's1' && n.parentId == parentId) n.id,
    ];

/// Reference viewport (HANDOFF §2): the phone frame is 343x725 and overflows
/// the default 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _layersHarness({required CanvasStore store}) {
  return MaterialApp(
    home: Scaffold(
      body: LayersPanel(
        store: store,
        selectedNodeId: null,
        onSelectNode: (_) {},
      ),
    ),
  );
}

void main() {
  group('CanvasStore.addRow', () {
    test('creates a root-level container with defaults', () {
      final store = CanvasStore();
      final id = store.addRow(screenId: 's1');

      expect(store.doc.nodes, hasLength(1));
      final row = store.doc.nodes.single;
      expect(row.id, id);
      expect(row.screenId, 's1');
      expect(row.items, isEmpty);
      expect(row.isRow, isTrue);
      expect(row.parentId, isNull);
      expect(row.gap, kFlowRowGapDefault);
    });

    test('is undoable and redoable', () {
      final store = CanvasStore();
      final id = store.addRow(screenId: 's1');
      expect(store.undo(), isTrue);
      expect(store.doc.nodes, isEmpty);
      expect(store.redo(), isTrue);
      expect(store.doc.nodes.singleWhere((n) => n.id == id).isRow, isTrue);
    });
  });

  group('CanvasStore.patchNode', () {
    test('sets the gap and undo restores it', () {
      final store = CanvasStore(initial: _rowDoc());
      store.patchNode('r1', gap: 20);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'r1').gap,
        20.0,
      );
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'r1').gap,
        kFlowRowGapDefault,
      );
    });

    test('throws StateError on unknown id without committing', () {
      final store = CanvasStore(initial: _rowDoc());
      expect(() => store.patchNode('nope', gap: 4), throwsStateError);
      expect(store.canUndo, isFalse);
    });

    test('null gap is a no-op without committing', () {
      final store = CanvasStore(initial: _rowDoc());
      store.patchNode('r1');
      expect(store.canUndo, isFalse);
    });
  });

  group('CanvasStore.reorderNode parent groups', () {
    test('reorders within a row without touching roots', () {
      final store = CanvasStore(initial: _rowDoc());
      expect(_groupOrder(store, 'r1'), ['c1', 'c2']);

      store.reorderNode('c1', 1);
      expect(_groupOrder(store, 'r1'), ['c2', 'c1']);
      expect(_groupOrder(store, null), ['r1', 'a', 'b']);
      // The moved child keeps its parent and screen.
      final moved = store.doc.nodes.singleWhere((n) => n.id == 'c1');
      expect(moved.parentId, 'r1');
      expect(moved.screenId, 's1');
    });

    test('reorders roots without touching row children', () {
      final store = CanvasStore(initial: _rowDoc());
      store.reorderNode('a', 99);
      expect(_groupOrder(store, null), ['r1', 'b', 'a']);
      expect(_groupOrder(store, 'r1'), ['c1', 'c2']);
    });

    test('clamps and refuses cross-parent moves structurally', () {
      final store = CanvasStore(initial: _rowDoc());
      // Far out-of-range stays inside the child's own row group.
      store.reorderNode('c1', 99);
      expect(_groupOrder(store, 'r1'), ['c2', 'c1']);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'c1').parentId,
        'r1',
      );
      store.reorderNode('c1', -5);
      expect(_groupOrder(store, 'r1'), ['c1', 'c2']);
    });

    test('unknown id throws and no-op stays undo-clean', () {
      final store = CanvasStore(initial: _rowDoc());
      expect(() => store.reorderNode('nope', 0), throwsStateError);
      expect(store.canUndo, isFalse);
      store.reorderNode('a', 1);
      expect(store.canUndo, isFalse);
    });
  });

  group('DesignCanvas.onAccept flow insertion', () {
    test('row kind takes the addRow path and ignores items', () {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept('row', const Offset(10, 10));

      expect(store.doc.nodes, hasLength(1));
      final row = store.doc.nodes.single;
      expect(row.id, id);
      expect(row.isRow, isTrue);
      expect(row.items, isEmpty);
      expect(row.parentId, isNull);
    });

    test('row honors an explicit root index', () {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      canvas.onAccept('button', const Offset(0, 10));
      canvas.onAccept('button', const Offset(0, 20));

      final rowId = canvas.onAccept('row', const Offset(0, 99), index: 0);

      expect(
        [for (final n in store.doc.nodes) n.id],
        [rowId, store.doc.nodes[1].id, store.doc.nodes[2].id],
      );
      expect(store.doc.nodes.first.isRow, isTrue);
    });

    test('row without an index falls back to pointer-y order', () {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      canvas.onAccept('button', const Offset(0, 10));
      canvas.onAccept('button', const Offset(0, 20));

      final rowId = canvas.onAccept('row', const Offset(0, 25));

      expect(store.doc.nodes.last.id, rowId);
    });

    test('leaf with explicit parentId and index lands in the row', () {
      final store = CanvasStore(initial: _rowDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(5, 5),
        parentId: 'r1',
        index: 0,
      );

      final node = store.doc.nodes.singleWhere((n) => n.id == id);
      expect(node.parentId, 'r1');
      expect(node.items.single.kind, 'badge');
      expect(_groupOrder(store, 'r1').first, id);
    });

    test('leaf with unknown parentId degrades to root', () {
      final store = CanvasStore(initial: _rowDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(0, 999),
        parentId: 'ghost',
      );

      final node = store.doc.nodes.singleWhere((n) => n.id == id);
      expect(node.parentId, isNull);
      expect(_groupOrder(store, null).last, id);
    });

    test('leaf index clamps into the group', () {
      final store = CanvasStore(initial: _rowDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(0, 0),
        parentId: 'r1',
        index: 99,
      );

      expect(_groupOrder(store, 'r1').last, id);
    });

    test('leaf without parentId falls back to pointer-y order', () {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      canvas.onAccept('button', const Offset(0, 100));

      final id = canvas.onAccept('button', const Offset(0, 10));

      // Dropped above the existing node: inserts before it.
      expect(store.doc.nodes.first.id, id);
      expect(store.doc.nodes.last.y, 100);
    });

    test('leaf drop stores x/y and lands in one undo step', () {
      final store = CanvasStore(initial: _rowDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(7, 8),
        parentId: 'r1',
        index: 1,
      );

      final node = store.doc.nodes.singleWhere((n) => n.id == id);
      expect(node.x, 7);
      expect(node.y, 8);
      expect(store.undo(), isTrue);
      expect(store.doc.nodes.any((n) => n.id == id), isFalse);
    });

    test('unknown kinds still land via the catalog fallback', () {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept('mystery', const Offset(8, 8));

      expect(store.doc.nodes.single.id, id);
      expect(store.doc.nodes.single.items.single.kind, 'mystery');
    });
  });

  group('palette container resolution', () {
    test('row resolves to the container tile', () {
      final entry = resolvePaletteEntry('row');
      expect(entry, isNotNull);
      expect(entry!.kind, 'row');
      expect(entry.label, 'Row');
    });

    test('catalog kinds resolve first, unknown kinds stay null', () {
      expect(resolvePaletteEntry('button')?.label, findEntry('button')!.label);
      expect(resolvePaletteEntry('nope'), isNull);
    });

    test('kContainerTiles carries the row record shape', () {
      expect(kContainerTiles['row']!.label, 'Row');
      expect(kContainerTiles['row']!.icon, Icons.view_column);
    });
  });

  group('flowInsertionIndex', () {
    test('empty container yields 0', () {
      expect(flowInsertionIndex(42, const []), 0);
    });

    test('indexes by child midpoints', () {
      const centers = [10.0, 20.0, 30.0];
      expect(flowInsertionIndex(5, centers), 0);
      expect(flowInsertionIndex(10, centers), 1);
      expect(flowInsertionIndex(25, centers), 2);
      expect(flowInsertionIndex(100, centers), 3);
    });
  });

  group('flow render (widget)', () {
    testWidgets('root leaves lay out top to bottom in doc order',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

      canvas.onAccept('button', const Offset(0, 10));
      canvas.onAccept('badge', const Offset(0, 20));
      canvas.onAccept('input', const Offset(0, 30));
      await tester.pump();

      final ys = [
        tester.getTopLeft(find.text('Button')).dy,
        tester.getTopLeft(find.text('Badge')).dy,
        // Input renders a TextField with a placeholder child.
        tester.getTopLeft(find.text('Type here')).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
    });

    testWidgets('row children lay out left to right in doc order',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

      final rowId = canvas.onAccept('row', const Offset(0, 0));
      canvas.onAccept('button', const Offset(0, 0), parentId: rowId);
      canvas.onAccept('badge', const Offset(50, 0), parentId: rowId);
      await tester.pump();

      final buttonX = tester.getTopLeft(find.text('Button')).dx;
      final badgeX = tester.getTopLeft(find.text('Badge')).dx;
      expect(buttonX, lessThan(badgeX));
    });

    testWidgets('empty row shows the dashed drop placeholder', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

      canvas.onAccept('row', const Offset(0, 0));
      await tester.pump();

      expect(find.text('Drop here'), findsOneWidget);
    });

    testWidgets('empty screen keeps the existing hint', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );

      expect(find.text('Drag a part here to start'), findsOneWidget);
    });

    testWidgets('row tile drag creates a container node', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Draggable<String>(
                  data: 'row',
                  feedback: Material(child: Text('dragging')),
                  child: SizedBox(width: 100, height: 40, child: Text('tile')),
                ),
                Expanded(child: DesignCanvas(store: store)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box =
          tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
      const want = Offset(50, 60);
      final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
      final gesture =
          await tester.startGesture(tileTopLeft + const Offset(80, 30));
      await gesture.moveTo(box.localToGlobal(want));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.doc.nodes, hasLength(1));
      final row = store.doc.nodes.single;
      expect(row.isRow, isTrue);
      expect(row.items, isEmpty);
      expect(row.parentId, isNull);
      expect(find.text('Drop here'), findsOneWidget);
    });

    testWidgets('dropping a leaf onto a row parents it', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Draggable<String>(
                  data: 'badge',
                  feedback: Material(child: Text('dragging')),
                  child: SizedBox(width: 100, height: 40, child: Text('tile')),
                ),
                Expanded(child: canvas),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rowId = canvas.onAccept('row', const Offset(0, 0));
      await tester.pumpAndSettle();

      final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
      final gesture =
          await tester.startGesture(tileTopLeft + const Offset(80, 30));
      await gesture.moveTo(tester.getCenter(find.text('Drop here')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.doc.nodes, hasLength(2));
      final leaf = store.doc.nodes.singleWhere((n) => n.id != rowId);
      expect(leaf.parentId, rowId);
      expect(find.text('Badge'), findsOneWidget);
    });

    testWidgets('hovering a row shows the insertion line', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Draggable<String>(
                  data: 'button',
                  feedback: Material(child: Text('dragging')),
                  child: SizedBox(width: 100, height: 40, child: Text('tile')),
                ),
                Expanded(child: canvas),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      canvas.onAccept('row', const Offset(0, 0));
      await tester.pumpAndSettle();

      final box =
          tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
      final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
      final gesture =
          await tester.startGesture(tileTopLeft + const Offset(80, 30));
      // Inside the empty row's placeholder (top of the screen content).
      await gesture.moveTo(box.localToGlobal(const Offset(164, 40)));
      await tester.pump();

      expect(find.byKey(kFlowInsertLineKey), findsOneWidget);

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
    });
  });

  group('layers tree (widget)', () {
    testWidgets('row header shows with children indented beneath',
        (tester) async {
      final store = CanvasStore(initial: _rowDoc());
      await tester.pumpWidget(_layersHarness(store: store));
      await tester.pump();

      expect(find.textContaining('Row · r1'), findsOneWidget);
      final rowX = tester.getTopLeft(find.textContaining('Row · r1')).dx;
      // Frontmost-first: c2 (last child) renders above c1, both indented.
      final c2X = tester.getTopLeft(find.textContaining('c2')).dx;
      final c1X = tester.getTopLeft(find.textContaining('c1')).dx;
      expect(c2X, greaterThan(rowX));
      expect(c1X, greaterThan(rowX));
      final c2Y = tester.getTopLeft(find.textContaining('c2')).dy;
      final c1Y = tester.getTopLeft(find.textContaining('c1')).dy;
      expect(c2Y, lessThan(c1Y));
    });

    testWidgets('tapping a row header selects the row', (tester) async {
      final store = CanvasStore(initial: _rowDoc());
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayersPanel(
              store: store,
              selectedNodeId: null,
              onSelectNode: (v) => selected = v,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.textContaining('Row · r1'));
      expect(selected, 'r1');
    });
  });

  group('flow integrity', () {
    test('deleteNode on a row cascades to children and grandchildren', () {
      final store = CanvasStore(initial: _nestedFlowDoc());
      expect(
        {for (final n in store.doc.nodes) n.id},
        {'r1', 'c1', 'r2', 'g1', 'solo'},
      );

      store.deleteNode('r1');

      expect(
        [for (final n in store.doc.nodes) n.id],
        ['solo'],
      );

      expect(store.undo(), isTrue);
      expect(
        {for (final n in store.doc.nodes) n.id},
        {'r1', 'c1', 'r2', 'g1', 'solo'},
      );
      // Restored links are intact.
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'c1').parentId,
        'r1',
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'g1').parentId,
        'r2',
      );
    });

    test('duplicateNode on a row clones the whole subtree with fresh ids',
        () {
      final store = CanvasStore(initial: _nestedFlowDoc());
      final beforeIds = {for (final n in store.doc.nodes) n.id};
      final beforeItemIds = {
        for (final n in store.doc.nodes)
          for (final i in n.items) i.id,
      };
      final beforeGap = {
        for (final n in store.doc.nodes) n.id: n.gap,
      };
      final beforeParent = {
        for (final n in store.doc.nodes) n.id: n.parentId,
      };
      final beforeIsRow = {
        for (final n in store.doc.nodes) n.id: n.isRow,
      };

      final newRowId = store.duplicateNode('r1');

      expect(newRowId, isNot('r1'));
      expect(beforeIds, isNot(contains(newRowId)));
      // 5 originals + 4 clones (r1, c1, r2, g1).
      expect(store.doc.nodes, hasLength(9));

      // Original subtree untouched.
      for (final id in ['r1', 'c1', 'r2', 'g1']) {
        final n = store.doc.nodes.singleWhere((e) => e.id == id);
        expect(n.parentId, beforeParent[id]);
        expect(n.isRow, beforeIsRow[id]);
        expect(n.gap, beforeGap[id]);
      }

      final newRow = store.doc.nodes.singleWhere((n) => n.id == newRowId);
      expect(newRow.isRow, isTrue);
      expect(newRow.gap, 20.0);
      expect(newRow.parentId, isNull);

      // Clones are re-parented to the fresh row id.
      final newChildren = [
        for (final n in store.doc.nodes)
          if (n.parentId == newRowId) n,
      ];
      expect(newChildren, hasLength(2));
      final c1Clone =
          newChildren.singleWhere((n) => n.isRow == false);
      final r2Clone = newChildren.singleWhere((n) => n.isRow == true);
      expect(c1Clone.gap, beforeGap['c1']);
      expect(r2Clone.gap, beforeGap['r2']);

      // Grandchild chain stays intact under the cloned nested row.
      final g1Clones = [
        for (final n in store.doc.nodes)
          if (n.parentId == r2Clone.id) n,
      ];
      expect(g1Clones, hasLength(1));
      expect(g1Clones.single.gap, beforeGap['g1']);
      expect(g1Clones.single.isRow, isFalse);

      // Every clone id (nodes + items) is fresh and unique.
      final cloneNodes = [
        for (final n in store.doc.nodes)
          if (!beforeIds.contains(n.id)) n,
      ];
      expect(cloneNodes, hasLength(4));
      expect(
        {for (final n in cloneNodes) n.id},
        hasLength(4),
      );
      final cloneItemIds = [
        for (final n in cloneNodes)
          for (final i in n.items) i.id,
      ];
      expect(cloneItemIds, isNotEmpty);
      for (final id in cloneItemIds) {
        expect(beforeItemIds, isNot(contains(id)));
      }
      expect(cloneItemIds.toSet(), hasLength(cloneItemIds.length));
      // Original items survive verbatim.
      expect(
        {for (final n in store.doc.nodes) for (final i in n.items) i.id},
        containsAll(['ic1', 'ig1', 'isolo']),
      );
    });

    test('duplicateNode on a leaf preserves parentId/isRow/gap', () {
      final store = CanvasStore(initial: _nestedFlowDoc());
      final copyId = store.duplicateNode('c1');

      expect(copyId, isNot('c1'));
      final orig = store.doc.nodes.singleWhere((n) => n.id == 'c1');
      final copy = store.doc.nodes.singleWhere((n) => n.id == copyId);
      expect(copy.parentId, 'r1');
      expect(copy.parentId, orig.parentId);
      expect(copy.isRow, orig.isRow);
      expect(copy.isRow, isFalse);
      expect(copy.gap, orig.gap);
      expect(copy.gap, 14.0);
    });

    test('moveNode preserves parentId/isRow/gap while updating x/y', () {
      final store = CanvasStore(initial: _nestedFlowDoc());
      store.moveNode('c1', 99, 88);

      final n = store.doc.nodes.singleWhere((e) => e.id == 'c1');
      expect(n.x, 99);
      expect(n.y, 88);
      expect(n.parentId, 'r1');
      expect(n.isRow, isFalse);
      expect(n.gap, 14.0);
    });

    test('patchItem preserves parentId/isRow/gap while merging props', () {
      final store = CanvasStore(initial: _nestedFlowDoc());
      store.patchItem('c1', 'ic1', props: {'variant': 'secondary'});

      final n = store.doc.nodes.singleWhere((e) => e.id == 'c1');
      expect(n.parentId, 'r1');
      expect(n.isRow, isFalse);
      expect(n.gap, 14.0);
      final item = n.items.singleWhere((i) => i.id == 'ic1');
      expect(item.props['label'], 'C1');
      expect(item.props['variant'], 'secondary');
    });

    test('load() migrates a legacy absolute doc to y-sorted flow', () async {
      final prefs = _FakeFlowPrefs();
      prefs.writes[CanvasStore.docKey] = jsonEncode({
        'screens': [
          {'id': 's1', 'name': 'Screen 1', 'x': 0, 'y': 0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0,
            'y': 30,
            'items': [
              {'id': 'i1', 'kind': 'button', 'label': 'One'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'x': 0,
            'y': 10,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Two'},
            ],
          },
          {
            'id': 'n3',
            'screenId': 's1',
            'x': 0,
            'y': 20,
            'items': [
              {'id': 'i3', 'kind': 'button', 'label': 'Three'},
            ],
          },
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Legacy', 'brief': ''},
      });

      final store = CanvasStore(prefs: prefs);
      await store.load();

      expect(
        [for (final n in store.doc.nodes) n.id],
        ['n2', 'n3', 'n1'],
      );
      for (final n in store.doc.nodes) {
        expect(n.parentId, isNull);
        expect(n.isRow, isFalse);
        expect(n.gap, kFlowRowGapDefault);
        expect(n.gap, 8.0);
      }
      // y metadata survives the migration.
      expect(
        [for (final n in store.doc.nodes) n.y],
        [10.0, 20.0, 30.0],
      );
    });
  });
}

/// Nested flow doc for integrity tests: r1 holds c1 plus nested row r2,
/// r2 holds g1; solo is an unrelated root. Leaf gaps are non-default so
/// preservation checks are meaningful (a reset to 8.0 would fail).
ScreenDoc _nestedFlowDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'r1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [],
          'parentId': null,
          'isRow': true,
          'gap': 20.0,
        },
        {
          'id': 'c1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'ic1', 'kind': 'button', 'label': 'C1'},
          ],
          'parentId': 'r1',
          'isRow': false,
          'gap': 14.0,
        },
        {
          'id': 'r2',
          'screenId': 's1',
          'x': 10.0,
          'y': 0.0,
          'items': [],
          'parentId': 'r1',
          'isRow': true,
          'gap': 12.0,
        },
        {
          'id': 'g1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'ig1', 'kind': 'badge', 'label': 'G1'},
          ],
          'parentId': 'r2',
          'isRow': false,
          'gap': 18.0,
        },
        {
          'id': 'solo',
          'screenId': 's1',
          'x': 0.0,
          'y': 99.0,
          'items': [
            {'id': 'isolo', 'kind': 'button', 'label': 'Solo'},
          ],
          'parentId': null,
          'isRow': false,
          'gap': 8.0,
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Flow', 'brief': ''},
    });

/// PrefsPort fake mirroring canvas_store_test.dart.
class _FakeFlowPrefs implements PrefsPort {
  final writes = <String, String>{};
  @override
  Future<String?> read(String key) async => writes[key];
  @override
  Future<void> write(String key, String value) async {
    writes[key] = value;
  }
}
