/// Track D2: multi-select set semantics + group/ungroup + toolbar enablement.
///
/// Pure selection helpers live in `lib/main.dart` ([resolveNodeTap],
/// [toggleNodeSelection], [rangeNodeSelection], [canGroupNodes],
/// [ungroupTargetRow], [ungroupRowDoc]); grouping commits through
/// [CanvasStore.groupIntoRow] (one atomic undo unit); ungrouping commits
/// through [CanvasStore.replaceDoc] of [ungroupRowDoc] (likewise atomic).
import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three root leaves on s1 in doc order (a, b, c). Returns the store plus ids.
(CanvasStore, List<String>) _threeLeaves() {
  final store = CanvasStore();
  final a = store.addNode(screenId: 's1', x: 0, y: 0);
  final b = store.addNode(screenId: 's1', x: 0, y: 10);
  final c = store.addNode(screenId: 's1', x: 0, y: 20);
  return (store, [a, b, c]);
}

/// Fixture doc with CLEAN history (built as `initial:`, so `canUndo` starts
/// false and any commit is observable): screens s1 (leaves a, b, c + row r
/// parenting n) and s2 (leaf d).
ScreenDoc _fixtureDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Screen 2', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {'id': 'a', 'screenId': 's1', 'x': 0.0, 'y': 0.0, 'items': []},
        {'id': 'b', 'screenId': 's1', 'x': 0.0, 'y': 10.0, 'items': []},
        {'id': 'c', 'screenId': 's1', 'x': 0.0, 'y': 20.0, 'items': []},
        {
          'id': 'r',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [],
          'isRow': true
        },
        {
          'id': 'n',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [],
          'parentId': 'r'
        },
        {'id': 'd', 'screenId': 's2', 'x': 0.0, 'y': 0.0, 'items': []},
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'T', 'brief': ''},
    });

CanvasStore _fixtureStore() => CanvasStore(initial: _fixtureDoc());

String _docJson(CanvasStore store) => jsonEncode(store.doc.toJson());

void main() {
  group('set semantics', () {
    test('toggle adds absent and removes present without mutating input', () {
      const current = {'a'};
      expect(toggleNodeSelection(current, 'b'), {'a', 'b'});
      expect(toggleNodeSelection(current, 'a'), isEmpty);
      expect(current, {'a'});
    });

    test('range selects the inclusive doc-order span within one group', () {
      final (store, ids) = _threeLeaves();
      final doc = store.doc;
      expect(rangeNodeSelection(doc, ids[0], ids[2]), ids.toSet());
      expect(rangeNodeSelection(doc, ids[2], ids[0]), ids.toSet());
      expect(rangeNodeSelection(doc, ids[1], ids[1]), {ids[1]});
    });

    test('range refuses unknown ids, cross-parent, and cross-screen taps', () {
      final (store, ids) = _threeLeaves();
      expect(rangeNodeSelection(store.doc, 'nope', ids[0]), isEmpty);
      expect(rangeNodeSelection(store.doc, ids[0], 'nope'), isEmpty);

      final row = store.addRow(screenId: 's1');
      store.reparentNode(ids[2], row);
      // c now lives under the row: root↔child is a cross-group tap.
      expect(rangeNodeSelection(store.doc, ids[0], ids[2]), isEmpty);

      final other = store.addScreen(name: 'Other');
      final d = store.addNode(screenId: other, x: 0, y: 0);
      expect(rangeNodeSelection(store.doc, ids[0], d), isEmpty);
    });

    test('plain tap collapses the set; null tap clears', () {
      final (store, ids) = _threeLeaves();
      final collapsed = resolveNodeTap(
        current: {ids[0], ids[1]},
        anchor: ids[0],
        doc: store.doc,
        tappedId: ids[2],
      );
      expect(collapsed.ids, {ids[2]});
      expect(collapsed.anchor, ids[2]);

      final cleared = resolveNodeTap(
        current: {ids[0]},
        anchor: ids[0],
        doc: store.doc,
        tappedId: null,
      );
      expect(cleared.ids, isEmpty);
      expect(cleared.anchor, isNull);
    });

    test('additive tap toggles; removing keeps the anchor', () {
      final (store, ids) = _threeLeaves();
      final added = resolveNodeTap(
        current: {ids[0]},
        anchor: ids[0],
        doc: store.doc,
        tappedId: ids[1],
        additive: true,
      );
      expect(added.ids, {ids[0], ids[1]});
      expect(added.anchor, ids[1]);

      final removed = resolveNodeTap(
        current: {ids[0], ids[1]},
        anchor: ids[1],
        doc: store.doc,
        tappedId: ids[0],
        additive: true,
      );
      expect(removed.ids, {ids[1]});
      expect(removed.anchor, ids[1]);
    });

    test('ranged tap unions the anchor span; bad anchor degrades to add', () {
      final (store, ids) = _threeLeaves();
      final extended = resolveNodeTap(
        current: {ids[0]},
        anchor: ids[0],
        doc: store.doc,
        tappedId: ids[2],
        ranged: true,
      );
      expect(extended.ids, ids.toSet());
      expect(extended.anchor, ids[2]);

      // Unknown anchor: plain add, anchor moves to the tap.
      final degraded = resolveNodeTap(
        current: {ids[0]},
        anchor: 'nope',
        doc: store.doc,
        tappedId: ids[1],
        ranged: true,
      );
      expect(degraded.ids, {ids[0], ids[1]});
      expect(degraded.anchor, ids[1]);

      // Null anchor + shift behaves like a plain tap (collapse).
      final noAnchor = resolveNodeTap(
        current: {ids[0]},
        anchor: null,
        doc: store.doc,
        tappedId: ids[1],
        ranged: true,
      );
      expect(noAnchor.ids, {ids[1]});
    });

    test('additive wins when both modifiers are held', () {
      final (store, ids) = _threeLeaves();
      final resolved = resolveNodeTap(
        current: {ids[0]},
        anchor: ids[0],
        doc: store.doc,
        tappedId: ids[0],
        additive: true,
        ranged: true,
      );
      expect(resolved.ids, isEmpty);
    });
  });

  group('canGroupNodes', () {
    test('needs 2+ existing same-screen root nodes', () {
      final (store, ids) = _threeLeaves();
      expect(canGroupNodes(store.doc, {}), isFalse);
      expect(canGroupNodes(store.doc, {ids[0]}), isFalse);
      expect(canGroupNodes(store.doc, {ids[0], ids[1]}), isTrue);
      expect(canGroupNodes(store.doc, ids.toSet()), isTrue);
      expect(canGroupNodes(store.doc, {ids[0], 'nope'}), isFalse);
    });

    test('refuses nested and cross-screen sets', () {
      final (store, ids) = _threeLeaves();
      final row = store.addRow(screenId: 's1');
      store.reparentNode(ids[2], row);
      expect(canGroupNodes(store.doc, {ids[0], ids[2]}), isFalse);

      final other = store.addScreen(name: 'Other');
      final d = store.addNode(screenId: other, x: 0, y: 0);
      expect(canGroupNodes(store.doc, {ids[0], d}), isFalse);
    });
  });

  group('groupIntoRow', () {
    test('happy path: row at first grouped slot, children in input order', () {
      final (store, ids) = _threeLeaves();
      final rowId = store.groupIntoRow([ids[1], ids[0]]);
      final nodes = store.doc.nodes;
      // First grouped node in doc order is ids[0] (slot 0): row lands there,
      // children follow in the requested [b, a] order, c stays last.
      expect(nodes.map((n) => n.id).toList(), [rowId, ids[1], ids[0], ids[2]]);
      final row = nodes.first;
      expect(row.isRow, isTrue);
      expect(row.parentId, isNull);
      expect(row.screenId, 's1');
      expect(row.items, isEmpty);
      expect(row.gap, kFlowRowGapDefault);
      expect(nodes[1].parentId, rowId);
      expect(nodes[2].parentId, rowId);
      expect(nodes[3].parentId, isNull);
    });

    test('deep-copies every field (only parentId changes)', () {
      final store = CanvasStore();
      final id = store.addNode(
        screenId: 's1',
        x: 5,
        y: 7,
        items: [
          CanvasItem(
            id: 'i9',
            kind: 'button',
            props: {'label': 'Go'},
            action: const NodeAction(to: 's1', transition: 'fade'),
          ),
        ],
        mainAxis: 'center',
        crossAxis: 'stretch',
        expand: 'flex',
        flex: 2,
      );
      store.patchNode(id, gap: 12);
      store.setNodeResponsive(
        id,
        hiddenOn: {'tablet'},
        breakpointValues: {
          'tablet': {'columns': 2},
        },
        slots: {'body': 'i9'},
      );
      final other = store.addNode(screenId: 's1', x: 0, y: 99);
      final before = {
        for (final n in store.doc.nodes)
          n.id: Map<String, dynamic>.from(n.toJson()),
      };

      final rowId = store.groupIntoRow([id, other]);

      for (final grouped in [id, other]) {
        final after =
            store.doc.nodes.singleWhere((n) => n.id == grouped).toJson();
        expect(after, {...before[grouped]!, 'parentId': rowId});
      }
    });

    test('refusals throw StateError and commit nothing', () {
      // Empty / singleton / unknown.
      for (final bad in [
        <String>[],
        ['a'],
        ['a', 'nope']
      ]) {
        final store = _fixtureStore();
        final snapshot = _docJson(store);
        expect(() => store.groupIntoRow(bad), throwsStateError);
        expect(store.canUndo, isFalse);
        expect(_docJson(store), snapshot);
      }
      // Nested node.
      {
        final store = _fixtureStore();
        final snapshot = _docJson(store);
        expect(() => store.groupIntoRow(['a', 'n']), throwsStateError);
        expect(store.canUndo, isFalse);
        expect(_docJson(store), snapshot);
      }
      // Cross-screen.
      {
        final store = _fixtureStore();
        final snapshot = _docJson(store);
        expect(() => store.groupIntoRow(['a', 'd']), throwsStateError);
        expect(store.canUndo, isFalse);
        expect(_docJson(store), snapshot);
      }
    });

    test('atomic undo: one undo restores the pre-group doc', () {
      final store = _fixtureStore();
      final snapshot = _docJson(store);
      final rowId = store.groupIntoRow(['a', 'c']);
      expect(store.doc.nodes.map((n) => n.id).toList(),
          [rowId, 'a', 'c', 'b', 'r', 'n', 'd']);
      expect(store.undo(), isTrue);
      expect(_docJson(store), snapshot);
      expect(store.canUndo, isFalse);
      expect(store.redo(), isTrue);
      expect(store.doc.nodes.map((n) => n.id).toList(), contains(rowId));
    });
  });

  group('ungroup', () {
    test('target is the single selected row, nothing else', () {
      final (store, ids) = _threeLeaves();
      final row = store.addRow(screenId: 's1');
      expect(ungroupTargetRow(store.doc, {}), isNull);
      expect(ungroupTargetRow(store.doc, {ids[0]}), isNull);
      expect(ungroupTargetRow(store.doc, {ids[0], row}), isNull);
      expect(ungroupTargetRow(store.doc, {row}), row);
      expect(ungroupTargetRow(store.doc, {'nope'}), isNull);
    });

    test('happy path: children take the row slot, grandchild stays nested', () {
      final store = _fixtureStore();
      final g = store.addNode(screenId: 's1', x: 1, y: 1);
      store.reparentNode(g, 'n');
      final before = {
        for (final n in store.doc.nodes)
          n.id: Map<String, dynamic>.from(n.toJson()),
      };

      store.replaceDoc(ungroupRowDoc(store.doc, 'r'));

      final nodes = store.doc.nodes;
      expect(nodes.map((n) => n.id).toList(), ['a', 'b', 'c', 'n', g, 'd']);
      final released = nodes.singleWhere((n) => n.id == 'n').toJson();
      expect(released, {...before['n']!, 'parentId': null});
      expect(nodes.singleWhere((n) => n.id == g).parentId, 'n');
    });

    test('empty row ungroups to just removing the row', () {
      final store = CanvasStore();
      final row = store.addRow(screenId: 's1');
      store.replaceDoc(ungroupRowDoc(store.doc, row));
      expect(store.doc.nodes, isEmpty);
    });

    test('refusals throw StateError', () {
      final (store, ids) = _threeLeaves();
      expect(() => ungroupRowDoc(store.doc, 'nope'), throwsStateError);
      expect(() => ungroupRowDoc(store.doc, ids[0]), throwsStateError);
    });

    test('atomic undo: one undo restores the grouped doc', () {
      final store = _fixtureStore();
      final rowId = store.groupIntoRow(['a', 'b']);
      final snapshot = _docJson(store);
      store.replaceDoc(ungroupRowDoc(store.doc, rowId));
      expect(store.doc.nodes.any((n) => n.id == rowId), isFalse);
      expect(store.undo(), isTrue);
      expect(_docJson(store), snapshot);
    });
  });

  group('delete-set', () {
    test('deletes every id; row cascade covers parent+child pairs', () {
      final (store, ids) = _threeLeaves();
      final rowId = store.groupIntoRow([ids[0], ids[1]]);
      // Selection holds a leaf, a row, AND the row's child: the child delete
      // no-ops after the row cascade removes it.
      for (final id in [ids[2], rowId, ids[0]]) {
        store.deleteNode(id);
      }
      expect(store.doc.nodes, isEmpty);
    });

    test('unknown ids are a no-op without committing', () {
      final store = CanvasStore();
      expect(store.canUndo, isFalse);
      store.deleteNode('nope');
      expect(store.canUndo, isFalse);
    });
  });

  group('toolbar enablement', () {
    Future<void> pumpToolbar(
      WidgetTester tester, {
      bool canGroup = false,
      VoidCallback? onGroup,
      bool canUngroup = false,
      VoidCallback? onUngroup,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorTheme(
              colors: EditorColors.light,
              child: CanvasToolbar(
                panMode: false,
                onPanModeChanged: (_) {},
                onAddScreen: () {},
                onPreview: () {},
                onUndo: null,
                onRedo: null,
                onDelete: () {},
                hasSelection: true,
                onOpen: () {},
                canGroup: canGroup,
                onGroup: onGroup,
                canUngroup: canUngroup,
                onUngroup: onUngroup,
              ),
            ),
          ),
        ),
      );
    }

    EditorIconButton buttonFor(WidgetTester tester, IconData icon) {
      return tester.widget<EditorIconButton>(
        find.descendant(
          of: find.byType(CanvasToolbar),
          matching: find.byWidgetPredicate(
            (w) => w is EditorIconButton && w.icon == icon,
          ),
        ),
      );
    }

    testWidgets('Group enabled only when canGroup with a handler',
        (tester) async {
      var calls = 0;
      await pumpToolbar(tester, canGroup: true, onGroup: () => calls++);
      expect(buttonFor(tester, Icons.group_work).onPressed, isNotNull);
      await tester.tap(find.byIcon(Icons.group_work));
      await tester.pump();
      expect(calls, 1);

      await pumpToolbar(tester, canGroup: false, onGroup: () => calls++);
      expect(buttonFor(tester, Icons.group_work).onPressed, isNull);

      // Flag without a handler stays disabled (defensive, never crashes).
      await pumpToolbar(tester, canGroup: true);
      expect(buttonFor(tester, Icons.group_work).onPressed, isNull);
    });

    testWidgets('Ungroup enabled only when canUngroup with a handler',
        (tester) async {
      var calls = 0;
      await pumpToolbar(tester, canUngroup: true, onUngroup: () => calls++);
      expect(buttonFor(tester, Icons.call_split).onPressed, isNotNull);
      await tester.tap(find.byIcon(Icons.call_split));
      await tester.pump();
      expect(calls, 1);

      await pumpToolbar(tester, canUngroup: false, onUngroup: () => calls++);
      expect(buttonFor(tester, Icons.call_split).onPressed, isNull);
    });

    testWidgets('Group/Ungroup presence does not disturb existing actions',
        (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.group_work), findsOneWidget);
      expect(find.byIcon(Icons.call_split), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });
  });
}
