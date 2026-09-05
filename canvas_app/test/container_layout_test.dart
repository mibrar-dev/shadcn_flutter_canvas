import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// W3 container alignment/flex: model defaults live in canvas_core's
/// flow_model_test; here we cover the store patch path plus the render
/// mapping (row alignment → Row, child expand → Expanded/Flexible).
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

void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The flow [Row] hosting [label]: the closest Row ancestor of the label's
/// text (row children render their catalog label inside the leaf).
Row _rowOf(WidgetTester tester, String label) {
  Row? found;
  tester.element(find.text(label)).visitAncestorElements((el) {
    if (found == null && el.widget is Row) {
      found = el.widget as Row;
      return false;
    }
    return true;
  });
  expect(found, isNotNull, reason: 'no Row ancestor for $label');
  return found!;
}

void main() {
  group('patchNode alignment/flex', () {
    test('sets all four fields and undo restores them', () {
      final store = CanvasStore(initial: _rowDoc());
      store.patchNode('r1', mainAxis: 'center', crossAxis: 'stretch');
      store.patchNode('c1', expand: 'expanded', flex: 2);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'r1').mainAxis,
        'center',
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'r1').crossAxis,
        'stretch',
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'c1').expand,
        'expanded',
      );
      expect(store.doc.nodes.singleWhere((n) => n.id == 'c1').flex, 2);
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'c1').expand,
        isNull,
      );
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'r1').mainAxis,
        isNull,
      );
    });

    test('gap-only patch keeps alignment fields', () {
      final store = CanvasStore(initial: _rowDoc());
      store.patchNode('r1', mainAxis: 'end');
      store.patchNode('r1', gap: 20);
      final row = store.doc.nodes.singleWhere((n) => n.id == 'r1');
      expect(row.gap, 20.0);
      expect(row.mainAxis, 'end');
    });

    test('throws StateError on unknown id without committing', () {
      final store = CanvasStore(initial: _rowDoc());
      expect(
        () => store.patchNode('nope', mainAxis: 'center'),
        throwsStateError,
      );
      expect(store.canUndo, isFalse);
    });

    test('all-null is a no-op without committing', () {
      final store = CanvasStore(initial: _rowDoc());
      store.patchNode('r1');
      expect(store.canUndo, isFalse);
    });

    test('addNode/addRow default to nulls', () {
      final store = CanvasStore();
      final leafId = store.addNode(screenId: 's1', x: 1, y: 2);
      final leaf = store.doc.nodes.singleWhere((n) => n.id == leafId);
      expect(leaf.mainAxis, isNull);
      expect(leaf.crossAxis, isNull);
      expect(leaf.expand, isNull);
      expect(leaf.flex, isNull);
      final rowId = store.addRow(screenId: 's1');
      final row = store.doc.nodes.singleWhere((n) => n.id == rowId);
      expect(row.gap, kFlowRowGapDefault);
      expect(row.mainAxis, isNull);
      expect(row.crossAxis, isNull);
      expect(row.expand, isNull);
      expect(row.flex, isNull);
    });

    test('duplicate/move/patchItem preserve new fields', () {
      final store = CanvasStore(initial: _rowDoc());
      store.patchNode('r1', mainAxis: 'center', crossAxis: 'stretch');
      store.patchNode('c1', expand: 'expanded', flex: 3);
      final copyId = store.duplicateNode('c1');
      final copy = store.doc.nodes.singleWhere((n) => n.id == copyId);
      expect(copy.expand, 'expanded');
      expect(copy.flex, 3);
      store.moveNode('c1', 5, 6);
      final moved = store.doc.nodes.singleWhere((n) => n.id == 'c1');
      expect(moved.expand, 'expanded');
      expect(moved.flex, 3);
      store.patchItem('c1', 'ic1', props: {'variant': 'secondary'});
      final patched = store.doc.nodes.singleWhere((n) => n.id == 'c1');
      expect(patched.expand, 'expanded');
      expect(patched.flex, 3);
      expect(patched.items.single.props['variant'], 'secondary');
      final rowCopyId = store.duplicateNode('r1');
      final rowCopy = store.doc.nodes.singleWhere((n) => n.id == rowCopyId);
      expect(rowCopy.mainAxis, 'center');
      expect(rowCopy.crossAxis, 'stretch');
    });
  });

  group('render mapping units', () {
    test('rowMainAxis maps all values (null → start)', () {
      expect(rowMainAxis(null), MainAxisAlignment.start);
      expect(rowMainAxis('start'), MainAxisAlignment.start);
      expect(rowMainAxis('center'), MainAxisAlignment.center);
      expect(rowMainAxis('end'), MainAxisAlignment.end);
      expect(rowMainAxis('spaceBetween'), MainAxisAlignment.spaceBetween);
      expect(rowMainAxis('spaceAround'), MainAxisAlignment.spaceAround);
      expect(rowMainAxis('spaceEvenly'), MainAxisAlignment.spaceEvenly);
      expect(rowMainAxis('bogus'), MainAxisAlignment.start);
    });

    test('rowCrossAxis maps all values (null → center)', () {
      expect(rowCrossAxis(null), CrossAxisAlignment.center);
      expect(rowCrossAxis('center'), CrossAxisAlignment.center);
      expect(rowCrossAxis('start'), CrossAxisAlignment.start);
      expect(rowCrossAxis('end'), CrossAxisAlignment.end);
      expect(rowCrossAxis('stretch'), CrossAxisAlignment.stretch);
      expect(rowCrossAxis('bogus'), CrossAxisAlignment.center);
    });

    test('wrapRowChild: expanded → Expanded, flex → Flexible, else Flexible',
        () {
      const expanded = CanvasNode(
        id: 'e',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
        expand: 'expanded',
        flex: 2,
      );
      const flex = CanvasNode(
        id: 'f',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
        expand: 'flex',
      );
      const plain = CanvasNode(
        id: 'p',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
      );
      const none = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
        expand: 'none',
      );
      const child = SizedBox();
      final wExpanded = wrapRowChild(expanded, child);
      expect(wExpanded, isA<Expanded>());
      expect((wExpanded as Expanded).flex, 2);
      final wFlex = wrapRowChild(flex, child);
      expect(wFlex, isA<Flexible>());
      expect((wFlex as Flexible).flex, 1);
      expect(wrapRowChild(plain, child), isA<Flexible>());
      expect(wrapRowChild(none, child), isA<Flexible>());
    });
  });

  group('render widgets', () {
    testWidgets('row honors main/cross alignment', (tester) async {
      _useReferenceViewport(tester);
      final doc = _rowDoc();
      final aligned = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'r1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: true,
                gap: n.gap,
                mainAxis: 'center',
                crossAxis: 'stretch',
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: aligned);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      final row = _rowOf(tester, 'C1');
      expect(row.mainAxisAlignment, MainAxisAlignment.center);
      expect(row.crossAxisAlignment, CrossAxisAlignment.stretch);
    });

    testWidgets('default row renders start/center', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _rowDoc());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      final row = _rowOf(tester, 'C1');
      expect(row.mainAxisAlignment, MainAxisAlignment.start);
      expect(row.crossAxisAlignment, CrossAxisAlignment.center);
    });

    testWidgets('expanded child renders inside Expanded', (tester) async {
      _useReferenceViewport(tester);
      final doc = _rowDoc();
      final wrapped = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'expanded',
                flex: 2,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: wrapped);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      expect(
        find.ancestor(of: find.text('C1'), matching: find.byType(Expanded)),
        findsOneWidget,
      );
      final expanded =
          tester.widget<Expanded>(find.ancestor(
        of: find.text('C1'),
        matching: find.byType(Expanded),
      ).first);
      expect(expanded.flex, 2);
      // Sibling without expand stays Flexible.
      expect(
        find.ancestor(of: find.text('C2'), matching: find.byType(Flexible)),
        findsWidgets,
      );
    });

    testWidgets('flex child renders inside Flexible with flex', (tester) async {
      _useReferenceViewport(tester);
      final doc = _rowDoc();
      final wrapped = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c2')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'flex',
                flex: 3,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: wrapped);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      final flexFinder = find.ancestor(
        of: find.text('C2'),
        matching: find.byType(Flexible),
      );
      expect(flexFinder, findsWidgets);
      // The innermost Flexible carries the flex (Expanded is a Flexible
      // subclass, but C2 has no Expanded ancestor).
      expect(
        find.ancestor(of: find.text('C2'), matching: find.byType(Expanded)),
        findsNothing,
      );
    });

    testWidgets('root leaves ignore expand', (tester) async {
      _useReferenceViewport(tester);
      final doc = _rowDoc();
      final flagged = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'solo')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'expanded',
                flex: 5,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: flagged);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Solo'), findsOneWidget);
      // No Expanded/Flexible between the root Column and the Solo leaf.
      expect(
        find.ancestor(of: find.text('Solo'), matching: find.byType(Expanded)),
        findsNothing,
      );
    });
  });
}
