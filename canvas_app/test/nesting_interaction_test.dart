/// Track C2 nesting-interaction tests: store reparenting, container drop
/// targeting, inspector breadcrumb + parent picker, and nested layers.
///
/// Covers: `reparentNode` happy paths (into container/row/root) + every
/// refusal (unknown node/parent, cross-screen, self, descendant) + undo +
/// no-history-pollution on no-ops, drop landing inside container chrome
/// (deepest-container hit test end to end), inspector breadcrumb + picker
/// wiring (disabled illegal options), and layers nesting display
/// (indentation + expand/collapse + reparent-safe delete).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/phone_frame.dart';
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

/// Store doc: card1 (container) parents mid1 (container) parents leaf1;
/// btn1 is a root leaf; row1 a root row; s2 holds an off-screen container.
ScreenDoc _nestingDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Away', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'card1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'icard1', 'kind': 'card', 'title': 'Host Card'},
          ],
        },
        {
          'id': 'btn1',
          'screenId': 's1',
          'x': 0.0,
          'y': 10.0,
          'items': [
            {'id': 'ibtn1', 'kind': 'button', 'label': 'Lone Btn'},
          ],
        },
        {
          'id': 'row1',
          'screenId': 's1',
          'x': 0.0,
          'y': 20.0,
          'items': [],
          'isRow': true,
          'gap': 8.0,
        },
        {
          'id': 'mid1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'parentId': 'card1',
          'items': [
            {'id': 'imid1', 'kind': 'outlined_container', 'label': 'Mid Box'},
          ],
        },
        {
          'id': 'leaf1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'parentId': 'mid1',
          'items': [
            {'id': 'ileaf1', 'kind': 'button', 'label': 'Deep Btn'},
          ],
        },
        {
          'id': 'cardX',
          'screenId': 's2',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'icardX', 'kind': 'card', 'title': 'Away Card'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Nesting interaction', 'brief': ''},
    });

CanvasNode _node(CanvasStore store, String id) =>
    store.doc.nodes.singleWhere((n) => n.id == id);

Future<void> _pumpInspector(
  WidgetTester tester,
  CanvasStore store, {
  String? nodeId,
  String? itemId,
}) async {
  // Tall viewport: the inspector is a ListView and the nesting card sits at
  // its end — finders skip offstage widgets, so the surface must fit it.
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InspectorPanel(store: store, nodeId: nodeId, itemId: itemId),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpLayers(WidgetTester tester, CanvasStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LayersPanel(
          store: store,
          selectedNodeId: null,
          onSelectNode: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CanvasStore.reparentNode happy path', () {
    test('reparents a root leaf into a container at the group end', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('btn1', 'card1');

      expect(_node(store, 'btn1').parentId, 'card1');
      expect(
        [for (final n in childrenOf(store.doc, 'card1')) n.id],
        ['mid1', 'btn1'],
      );
    });

    test('moving into a row vs a container just re-parents', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('btn1', 'row1');
      expect(_node(store, 'btn1').parentId, 'row1');

      // Layout follows the parent's kind (row: horizontal, container:
      // inside chrome) — the store only re-points the edge.
      store.reparentNode('btn1', 'card1');
      expect(_node(store, 'btn1').parentId, 'card1');
    });

    test('moves back to the root with null', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('mid1', null);
      expect(_node(store, 'mid1').parentId, isNull);
      // Its own child rides along (the edge still names mid1).
      expect(_node(store, 'leaf1').parentId, 'mid1');
    });

    test('is undoable and redoable', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('btn1', 'card1');
      expect(_node(store, 'btn1').parentId, 'card1');

      expect(store.undo(), isTrue);
      expect(_node(store, 'btn1').parentId, isNull);

      expect(store.redo(), isTrue);
      expect(_node(store, 'btn1').parentId, 'card1');
    });

    test('preserves every field (setNodeResponsive deep-copy precedent)', () {
      final doc = _nestingDoc();
      final rich = CanvasNode(
        id: 'rich',
        screenId: 's1',
        x: 11.0,
        y: 22.0,
        items: const [
          CanvasItem(
            id: 'irich',
            kind: 'button',
            props: {'label': 'Pay', 'variant': 'primary'},
            action: NodeAction(to: 's2', transition: 'slide'),
          ),
        ],
        gap: 9.0,
        mainAxis: 'center',
        crossAxis: 'end',
        expand: 'flex',
        flex: 2,
        hiddenOn: const {'mobile'},
        breakpointValues: const {
          'tablet': {'columns': 2},
        },
        slots: const {'main': 'irich'},
      );
      final store = CanvasStore(
        initial: ScreenDoc(
          screens: doc.screens,
          nodes: [...doc.nodes, rich],
          theme: doc.theme,
          meta: doc.meta,
        ),
      );
      final before = _node(store, 'rich');
      store.reparentNode('rich', 'card1');

      final n = _node(store, 'rich');
      expect(n.parentId, 'card1');
      expect(n.screenId, before.screenId);
      expect(n.x, before.x);
      expect(n.y, before.y);
      expect(n.isRow, before.isRow);
      expect(n.gap, 9.0);
      expect(n.mainAxis, 'center');
      expect(n.crossAxis, 'end');
      expect(n.expand, 'flex');
      expect(n.flex, 2);
      expect(n.hiddenOn, {'mobile'});
      expect(
        n.breakpointValues,
        {
          'tablet': {'columns': 2},
        },
      );
      expect(n.slots, {'main': 'irich'});
      expect(n.items.single.props['label'], 'Pay');
      expect(n.items.single.action?.to, 's2');
      // Deep copy: responsive collections must not alias the pre-move node.
      expect(identical(n.hiddenOn, before.hiddenOn), isFalse);
      expect(identical(n.slots, before.slots), isFalse);
      expect(identical(n.breakpointValues, before.breakpointValues), isFalse);
    });

    test('reorders within a container group after the move', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('btn1', 'card1');
      expect(
        [for (final n in childrenOf(store.doc, 'card1')) n.id],
        ['mid1', 'btn1'],
      );
      store.reorderNode('btn1', 0);
      expect(
        [for (final n in childrenOf(store.doc, 'card1')) n.id],
        ['btn1', 'mid1'],
      );
    });
  });

  group('CanvasStore.reparentNode refusals', () {
    test('unknown node is a no-op without committing', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('ghost', 'card1');
      expect(store.canUndo, isFalse);
      expect(store.doc.nodes.map((n) => n.id), isNot(contains('ghost')));
    });

    test('unknown parent is a no-op without committing', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('btn1', 'ghost');
      expect(store.canUndo, isFalse);
      expect(_node(store, 'btn1').parentId, isNull);
    });

    test('cross-screen parent throws StateError before committing', () {
      final store = CanvasStore(initial: _nestingDoc());
      final before = [for (final n in store.doc.nodes) n.toJson()];
      expect(
        () => store.reparentNode('btn1', 'cardX'),
        throwsStateError,
      );
      expect(store.canUndo, isFalse);
      expect(
        [for (final n in store.doc.nodes) n.toJson()],
        before,
      );
    });

    test('self parent throws StateError before committing', () {
      final store = CanvasStore(initial: _nestingDoc());
      expect(() => store.reparentNode('card1', 'card1'), throwsStateError);
      expect(store.canUndo, isFalse);
      expect(_node(store, 'card1').parentId, isNull);
    });

    test('descendant parent throws StateError before committing', () {
      final store = CanvasStore(initial: _nestingDoc());
      // card1 > mid1 > leaf1: moving an ancestor under its own descendant
      // would cycle (uses isAncestorOf).
      expect(() => store.reparentNode('card1', 'mid1'), throwsStateError);
      expect(() => store.reparentNode('card1', 'leaf1'), throwsStateError);
      expect(() => store.reparentNode('mid1', 'leaf1'), throwsStateError);
      expect(store.canUndo, isFalse);
      expect(_node(store, 'card1').parentId, isNull);
      expect(_node(store, 'mid1').parentId, 'card1');
    });

    test('moving down the tree (child under ancestor) stays legal', () {
      final store = CanvasStore(initial: _nestingDoc());
      store.reparentNode('leaf1', 'card1');
      expect(_node(store, 'leaf1').parentId, 'card1');
    });

    test('same-position is a no-op without committing', () {
      final store = CanvasStore(initial: _nestingDoc());
      // Root node moved to root, child moved to its current parent.
      store.reparentNode('btn1', null);
      expect(store.canUndo, isFalse);
      store.reparentNode('mid1', 'card1');
      expect(store.canUndo, isFalse);
      expect(_node(store, 'mid1').parentId, 'card1');
    });
  });

  group('DesignCanvas.onAccept container drops', () {
    test('leaf with a container parentId and index lands parented', () {
      final store = CanvasStore(initial: _nestingDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(5, 5),
        parentId: 'card1',
        index: 0,
      );

      final node = _node(store, id);
      expect(node.parentId, 'card1');
      expect(node.items.single.kind, 'badge');
      expect(childrenOf(store.doc, 'card1').first.id, id);
      // One undo step removes the drop.
      expect(store.undo(), isTrue);
      expect(store.doc.nodes.any((n) => n.id == id), isFalse);
    });

    test('cross-screen parentId degrades to root (never lost, never throws)',
        () {
      final store = CanvasStore(initial: _nestingDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(0, 999),
        parentId: 'cardX',
      );

      expect(_node(store, id).parentId, isNull);
      expect(_node(store, id).screenId, 's1');
    });

    test('unknown kinds keep landing via the catalog fallback', () {
      final store = CanvasStore(initial: _nestingDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'mystery',
        const Offset(5, 5),
        parentId: 'card1',
      );

      expect(_node(store, id).parentId, 'card1');
      expect(_node(store, id).items.single.kind, 'mystery');
    });

    test('row with a container parent nests (row-in-card)', () {
      final store = CanvasStore(initial: _nestingDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'row',
        const Offset(5, 5),
        parentId: 'card1',
      );

      final row = _node(store, id);
      expect(row.isRow, isTrue);
      expect(row.parentId, 'card1');
    });

    test('row without a parent still lands root-level', () {
      final store = CanvasStore(initial: _nestingDoc());
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept('row', const Offset(0, 999));

      expect(_node(store, id).isRow, isTrue);
      expect(_node(store, id).parentId, isNull);
    });

    testWidgets('dragging a tile onto a card parents the drop', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _nestingDoc());
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

      // card1's chrome: the card title sits inside it.
      final cardCenter = tester.getCenter(find.text('Host Card'));
      final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
      final gesture =
          await tester.startGesture(tileTopLeft + const Offset(80, 30));
      await gesture.moveTo(cardCenter);
      await tester.pump();

      // FF1 (drop-into-slot): card1's `content` slot is empty, so the hover
      // previews the slot assignment (ghost in the slot) INSTEAD of the
      // flow index line — the landing ignores the index, so the line hides.
      // The ghost pin lives in `drop_slots_test.dart` (slot ghost preview).
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
      expect(find.byKey(kDropPreviewKey), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      final badge = store.doc.nodes.singleWhere(
        (n) => n.items.any((i) => i.kind == 'badge'),
      );
      expect(badge.parentId, 'card1');
      // ... and fills the empty slot in the same commit.
      expect(
        store.doc.nodes
            .singleWhere((n) => n.id == 'card1')
            .slotNodes['content'],
        badge.id,
      );
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
    });
  });

  group('inspector nesting card', () {
    testWidgets('breadcrumb shows Screen › ancestors › node', (tester) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpInspector(tester, store, nodeId: 'leaf1', itemId: 'ileaf1');

      expect(
        find.byKey(const ValueKey('nesting-breadcrumb')),
        findsOneWidget,
      );
      expect(
        find.text('Home › Card · card1 › Outlined_container · mid1 › '
            'Button · leaf1'),
        findsOneWidget,
      );
    });

    testWidgets('root node breadcrumbs to the screen only', (tester) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpInspector(tester, store, nodeId: 'card1', itemId: 'icard1');

      expect(find.text('Home › Card · card1'), findsOneWidget);
    });

    testWidgets('row node shows breadcrumb plus picker', (tester) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpInspector(tester, store, nodeId: 'row1');

      expect(find.text('Home › Row · row1'), findsOneWidget);
      expect(find.text('Nesting'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
    });

    testWidgets('move-into button reparents and refreshes the breadcrumb', (
      tester,
    ) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpInspector(tester, store, nodeId: 'btn1', itemId: 'ibtn1');
      expect(find.text('Home › Button · btn1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nesting-move-card1')));
      await tester.pump();

      expect(_node(store, 'btn1').parentId, 'card1');
      expect(
        find.text('Home › Card · card1 › Button · btn1'),
        findsOneWidget,
      );
    });

    testWidgets('move-to-root button lifts the node back out', (tester) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpInspector(tester, store, nodeId: 'mid1', itemId: 'imid1');

      await tester.tap(find.byKey(const ValueKey('nesting-move-root')));
      await tester.pump();

      expect(_node(store, 'mid1').parentId, isNull);
      expect(find.text('Home › Outlined_container · mid1'), findsOneWidget);
    });

    testWidgets('illegal targets stay disabled with reasons', (tester) async {
      final store = CanvasStore(initial: _nestingDoc());
      // card1 parents mid1 parents leaf1; card1 itself is root.
      await _pumpInspector(tester, store, nodeId: 'card1', itemId: 'icard1');

      // Self: visible but disabled (no move button, reason shown).
      expect(
        find.byKey(const ValueKey('nesting-move-card1')),
        findsNothing,
      );
      expect(find.text('cannot contain itself'), findsOneWidget);
      // Descendant container: likewise disabled as a cycle.
      expect(
        find.byKey(const ValueKey('nesting-move-mid1')),
        findsNothing,
      );
      expect(find.text('would create a cycle'), findsOneWidget);
      // Already at root: the root option is disabled too.
      expect(
        find.byKey(const ValueKey('nesting-move-root')),
        findsNothing,
      );
      expect(find.text('already at root'), findsOneWidget);
      // The current-parent reason shows once the node is nested: move btn1
      // under card1, then card1's row reads `current parent`.
      await _pumpInspector(tester, store, nodeId: 'btn1', itemId: 'ibtn1');
      await tester.tap(find.byKey(const ValueKey('nesting-move-card1')));
      await tester.pump();
      expect(_node(store, 'btn1').parentId, 'card1');
      expect(find.text('current parent'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('nesting-move-card1')),
        findsNothing,
      );
      // Legal targets stay enabled.
      expect(
        find.byKey(const ValueKey('nesting-move-row1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('nesting-move-root')),
        findsOneWidget,
      );
      // Cross-screen containers never list (a move never changes screens).
      expect(
        find.byKey(const ValueKey('nesting-move-cardX')),
        findsNothing,
      );
      expect(find.textContaining('cardX'), findsNothing);
      // Non-container leaves never list as picker options either (steered
      // to the fallback): no move button is keyed for btn1 even though it
      // shares the screen.
      expect(
        find.byKey(const ValueKey('nesting-move-btn1')),
        findsNothing,
      );
    });
  });

  group('layers nested display', () {
    testWidgets('three-deep tree indents one level per depth', (tester) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpLayers(tester, store);

      expect(find.text('Card · card1'), findsOneWidget);
      expect(find.text('Outlined_container · mid1'), findsOneWidget);
      expect(find.text('Button · leaf1'), findsOneWidget);
      final cardX = tester.getTopLeft(find.text('Card · card1')).dx;
      final midX = tester.getTopLeft(find.text('Outlined_container · mid1')).dx;
      final leafX = tester.getTopLeft(find.text('Button · leaf1')).dx;
      expect(cardX, lessThan(midX));
      expect(midX, lessThan(leafX));
    });

    testWidgets('collapse hides the subtree, expand restores it', (
      tester,
    ) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpLayers(tester, store);

      // card1 and mid1 own subtrees, so both carry the collapse toggle;
      // tree order puts card1's first.
      expect(find.byIcon(Icons.expand_more), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pump();

      expect(find.text('Card · card1'), findsOneWidget);
      expect(find.textContaining('mid1'), findsNothing);
      expect(find.textContaining('leaf1'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('Outlined_container · mid1'), findsOneWidget);
      expect(find.text('Button · leaf1'), findsOneWidget);
    });

    testWidgets('deleting a nested node cascades to its subtree only', (
      tester,
    ) async {
      final store = CanvasStore(initial: _nestingDoc());
      await _pumpLayers(tester, store);

      // Tree order: s1-header delete, s1 rows frontmost-first (row1,
      // btn1, then card1's subtree depth-first), s2-header delete, cardX.
      final deletes = find.byIcon(Icons.delete_outline);
      expect(deletes, findsNWidgets(8));
      await tester.tap(deletes.at(4));
      await tester.pump();

      expect(
        {for (final n in store.doc.nodes) n.id},
        {'card1', 'btn1', 'row1', 'cardX'},
      );
      expect(find.text('Card · card1'), findsOneWidget);
      expect(find.textContaining('mid1'), findsNothing);
    });

    testWidgets('nested reorder controls coexist with selection', (
      tester,
    ) async {
      final store = CanvasStore(initial: _nestingDoc());
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

      await tester.tap(find.text('Outlined_container · mid1'));
      expect(selected, 'mid1');
    });
  });
}