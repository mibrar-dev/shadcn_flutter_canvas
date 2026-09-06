/// Track R1: app-state var CRUD, binding rewrites, session values, and step
/// writes on the undoable store.
library;

import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Store with two screens, one `count` var, and a button bound to it with a
/// two-step flow. Returns `(store, nodeId, itemId)`.
(CanvasStore, String, String) _storeWithState() {
  final store = CanvasStore();
  store.addVar(const AppStateVar(name: 'count', type: 'number', defaultValue: 0));
  final doneId = store.doc.screens.first.id;
  final nodeId = store.addNode(
    screenId: 's1',
    x: 16,
    y: 96,
    items: const [
      CanvasItem(
        id: 'i1',
        kind: 'button',
        props: {'label': '=count'},
        action: NodeAction(
          to: 's1',
          transition: 'slide',
          steps: [
            ActionStep.setState(variable: 'count', value: '=count'),
            ActionStep.navigate(to: 's1', transition: 'slide'),
          ],
        ),
      ),
    ],
  );
  assert(doneId == 's1');
  return (store, nodeId, 'i1');
}

CanvasItem _item(CanvasStore store, String nodeId, String itemId) => store.doc
    .nodes
    .singleWhere((n) => n.id == nodeId)
    .items
    .singleWhere((i) => i.id == itemId);

void main() {
  group('var CRUD', () {
    test('addVar commits and undo removes it', () {
      final store = CanvasStore();
      expect(store.doc.states, isEmpty);
      store.addVar(
        const AppStateVar(name: 'count', type: 'number', defaultValue: 0),
      );
      expect(store.doc.states.map((v) => v.name), ['count']);
      expect(store.undo(), isTrue);
      expect(store.doc.states, isEmpty);
      expect(store.redo(), isTrue);
      expect(store.doc.states.map((v) => v.name), ['count']);
    });

    test('addVar rejects duplicates, bad names, mistyped defaults', () {
      final store = CanvasStore();
      store.addVar(
        const AppStateVar(name: 'count', type: 'number', defaultValue: 0),
      );
      expect(
        () => store.addVar(
          const AppStateVar(name: 'count', type: 'string', defaultValue: 'x'),
        ),
        throwsArgumentError,
      );
      expect(
        () => store.addVar(
          const AppStateVar(name: '9bad', type: 'number', defaultValue: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => store.addVar(
          const AppStateVar(name: 's', type: 'string', defaultValue: 3),
        ),
        throwsArgumentError,
      );
      // All refusals leave history clean (one commit so far).
      expect(store.doc.states, hasLength(1));
      expect(store.undo(), isTrue);
      expect(store.undo(), isFalse);
    });

    test('renameVar rewrites =old bindings in props and steps', () {
      final (store, nodeId, itemId) = _storeWithState();
      store.renameVar('count', 'total');
      expect(store.doc.states.single.name, 'total');
      final item = _item(store, nodeId, itemId);
      expect(item.props['label'], '=total');
      expect(item.action!.steps[0].variable, 'total');
      expect(item.action!.steps[0].value, '=total');
      // Legacy to/transition untouched.
      expect(item.action!.to, 's1');
      expect(store.undo(), isTrue);
      expect(store.doc.states.single.name, 'count');
      expect(_item(store, nodeId, itemId).props['label'], '=count');
    });

    test('renameVar refuses unknown, taken, and invalid names', () {
      final (store, _, _) = _storeWithState();
      expect(() => store.renameVar('ghost', 'x'), throwsStateError);
      store.addVar(
        const AppStateVar(name: 'other', type: 'string', defaultValue: ''),
      );
      expect(() => store.renameVar('count', 'other'), throwsArgumentError);
      expect(() => store.renameVar('count', '9bad'), throwsArgumentError);
      // Same-name is a quiet no-op.
      final undoable = store.canUndo;
      store.renameVar('count', 'count');
      expect(store.canUndo, undoable);
      expect(store.doc.states.map((v) => v.name), ['count', 'other']);
    });

    test('deleteVar clears bindings to raw, keeps var refs in steps', () {
      final (store, nodeId, itemId) = _storeWithState();
      store.deleteVar('count');
      expect(store.doc.states, isEmpty);
      final item = _item(store, nodeId, itemId);
      // Prop binding stripped to the raw literal.
      expect(item.props['label'], 'count');
      // Step variable refs stay (executor skips unknown vars); value refs
      // clear to raw.
      expect(item.action!.steps[0].variable, 'count');
      expect(item.action!.steps[0].value, 'count');
      expect(store.undo(), isTrue);
      expect(store.doc.states.single.name, 'count');
      expect(_item(store, nodeId, itemId).props['label'], '=count');
    });

    test('deleteVar of an unknown var is a no-op', () {
      final (store, _, _) = _storeWithState();
      store.deleteVar('ghost');
      expect(store.canUndo, isTrue); // only the setup commits exist
      final fresh = CanvasStore();
      fresh.deleteVar('ghost');
      expect(fresh.canUndo, isFalse);
    });
  });

  group('session values', () {
    test('stateValue falls back to defaults; setStateValue notifies', () {
      final (store, _, _) = _storeWithState();
      expect(store.stateValue('count'), 0);
      expect(store.stateValue('ghost'), isNull);
      var notified = 0;
      store.addListener(() => notified++);
      store.setStateValue('count', 5);
      expect(store.stateValue('count'), 5);
      expect(notified, 1);
      // Re-setting the same value is a no-op.
      store.setStateValue('count', 5);
      expect(notified, 1);
      // Unknown vars are a quiet no-op.
      store.setStateValue('ghost', 1);
      expect(notified, 1);
      store.resetSessionValues();
      expect(store.stateValue('count'), 0);
    });

    test('session values never commit history or persist', () {
      final store = CanvasStore();
      expect(store.canUndo, isFalse);
      store.addVar(
        const AppStateVar(name: 'count', type: 'number', defaultValue: 0),
      );
      store.setStateValue('count', 42);
      // One commit (the addVar); the session write added none.
      expect(store.undo(), isTrue);
      expect(store.doc.states, isEmpty);
      expect(store.undo(), isFalse);
      // And the persisted doc carries declarations, not values.
      final store2 = CanvasStore();
      store2.addVar(
        const AppStateVar(name: 'count', type: 'number', defaultValue: 0),
      );
      store2.setStateValue('count', 42);
      final json = jsonEncode(store2.doc.toJson());
      expect(json, isNot(contains('42')));
      expect(json, contains('"count"'));
    });
  });

  group('step writes', () {
    test('setItemSteps syncs legacy to and is undoable', () {
      final store = CanvasStore();
      final s2 = store.addScreen(name: 'Done');
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'button')],
      );
      store.setItemSteps(nodeId, 'i1', [
        const ActionStep.setState(variable: 'count', value: '1'),
        ActionStep.navigate(to: s2, transition: 'fade'),
      ]);
      final action = _item(store, nodeId, 'i1').action!;
      expect(action.steps, hasLength(2));
      // Legacy to follows the last navigate step for old readers.
      expect(action.to, s2);
      expect(action.transition, 'fade');
      expect(store.undo(), isTrue);
      expect(_item(store, nodeId, 'i1').action, isNull);
    });

    test('setItemSteps no-ops on unknown ids and equal writes', () {
      final (store, nodeId, itemId) = _storeWithState();
      final before = store.doc;
      store.setItemSteps('nope', itemId, const [
        ActionStep.navigate(to: 's1'),
      ]);
      store.setItemSteps(nodeId, 'nope', const [
        ActionStep.navigate(to: 's1'),
      ]);
      expect(identical(store.doc, before), isTrue);
      // Equal write: no new history entry.
      final current = _item(store, nodeId, itemId).action!.steps;
      store.setItemSteps(nodeId, itemId, List.of(current));
      expect(store.undo(), isTrue); // pops a setup commit, not the no-op
      expect(store.doc.states.single.name, 'count');
    });

    test('clearing steps restores the legacy action', () {
      final (store, nodeId, itemId) = _storeWithState();
      final legacyTo = _item(store, nodeId, itemId).action!.to;
      store.setItemSteps(nodeId, itemId, const []);
      final action = _item(store, nodeId, itemId).action!;
      expect(action.steps, isEmpty);
      expect(action.to, legacyTo);
    });

    test('duplicateNode copies steps', () {
      final (store, nodeId, itemId) = _storeWithState();
      final copyId = store.duplicateNode(nodeId);
      final copy = store.doc.nodes.singleWhere((n) => n.id == copyId);
      expect(
        copy.items.singleWhere((i) => i.kind == 'button').action!.steps,
        _item(store, nodeId, itemId).action!.steps,
      );
    });
  });

  group('states survive edits', () {
    test('addNode/patchItem/moveNode keep vars', () {
      final (store, nodeId, itemId) = _storeWithState();
      store.addNode(screenId: 's1', x: 0, y: 0);
      store.patchItem(nodeId, itemId, props: const {'variant': 'primary'});
      store.moveNode(nodeId, 5, 5);
      expect(store.doc.states.single.name, 'count');
      expect(_item(store, nodeId, itemId).props['label'], '=count');
    });
  });
}
