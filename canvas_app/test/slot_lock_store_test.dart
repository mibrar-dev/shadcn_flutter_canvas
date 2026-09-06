/// Track DD: named slots (`setSlotChild`) + editor lock (`setNodeLocked`)
/// store coverage — assign/clear/refusals/undo, lock guards on
/// delete/reparent/resize/group, and the locked+slotNodes carry audit over
/// every mutator (plus the `selection_model` ungroup path).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/ui/selection_model.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePrefs implements PrefsPort {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

/// One screen with a `card` host (`h`), a `button` child (`c`), and a second
/// `button` root (`o`); screen `s2` holds a cross-screen `button` (`x`).
/// Card declares the `content` slot (catalog table).
CanvasStore _slotStore() {
  final store = CanvasStore(prefs: _FakePrefs());
  store.replaceDoc(ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      {'id': 's2', 'name': 'Away', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': [
      {
        'id': 'h',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {'id': 'ih', 'kind': 'card', 'title': 'T'},
        ],
      },
      {
        'id': 'c',
        'screenId': 's1',
        'x': 0.0,
        'y': 100.0,
        'items': [
          {'id': 'ic', 'kind': 'button', 'label': 'Go'},
        ],
      },
      {
        'id': 'o',
        'screenId': 's1',
        'x': 0.0,
        'y': 200.0,
        'items': [
          {'id': 'io', 'kind': 'button', 'label': 'Other'},
        ],
      },
      {
        'id': 'x',
        'screenId': 's2',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {'id': 'ix', 'kind': 'button', 'label': 'Away'},
        ],
      },
    ],
    'theme': {
      'paletteKey': 'clean-slate',
      'dark': true,
      'shape': 'rounded',
      'motion': 'standard'
    },
    'meta': {'title': 'T', 'brief': ''},
  }));
  return store;
}

CanvasNode _node(CanvasStore store, String id) =>
    store.doc.nodes.singleWhere((n) => n.id == id);

/// History depth (number of undoable commits so far).
int _depth(CanvasStore store) {
  var depth = 0;
  while (store.canUndo) {
    store.undo();
    depth++;
  }
  for (var i = 0; i < depth; i++) {
    store.redo();
  }
  return depth;
}

void main() {
  group('setSlotChild', () {
    test('assigns, clears, and undoes', () {
      final store = _slotStore();

      store.setSlotChild('h', 'content', 'c');
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      expect(store.undo(), isTrue);
      expect(_node(store, 'h').slotNodes, isEmpty);

      expect(store.redo(), isTrue);
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      store.setSlotChild('h', 'content', null);
      expect(_node(store, 'h').slotNodes, isEmpty);

      expect(store.undo(), isTrue);
      expect(_node(store, 'h').slotNodes, {'content': 'c'});
    });

    test('empty-string child clears like null', () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');
      store.setSlotChild('h', 'content', '');
      expect(_node(store, 'h').slotNodes, isEmpty);
    });

    test('unknown host / unknown child / absent clear / same value: no-ops',
        () {
      final store = _slotStore();
      final before = _depth(store);

      store.setSlotChild('ghost', 'content', 'c');
      expect(_depth(store), before);

      store.setSlotChild('h', 'content', 'ghost');
      expect(_depth(store), before);
      expect(_node(store, 'h').slotNodes, isEmpty);

      store.setSlotChild('h', 'content', null);
      expect(_depth(store), before);

      store.setSlotChild('h', 'content', 'c');
      expect(_depth(store), before + 1);
      store.setSlotChild('h', 'content', 'c');
      expect(_depth(store), before + 1);
    });

    test('unknown slot name for the kind throws ArgumentError', () {
      final store = _slotStore();
      final before = _depth(store);
      // Button declares no slots.
      expect(
        () => store.setSlotChild('c', 'content', 'o'),
        throwsArgumentError,
      );
      // Rows declare no slots either.
      final row = store.addRow(screenId: 's1');
      expect(
        () => store.setSlotChild(row, 'content', 'c'),
        throwsArgumentError,
      );
      expect(
        () => store.setSlotChild('h', '', 'c'),
        throwsArgumentError,
      );
      // History holds only the addRow commit (failures commit nothing).
      expect(_depth(store), before + 1);
    });

    test('cross-screen / self / descendant children throw StateError', () {
      final store = _slotStore();
      expect(
        () => store.setSlotChild('h', 'content', 'x'),
        throwsStateError,
      );
      expect(
        () => store.setSlotChild('h', 'content', 'h'),
        throwsStateError,
      );
      // Descendant via parentId: kid under the host cannot slot back into it.
      store.reparentNode('c', 'h');
      expect(
        () => store.setSlotChild('h', 'content', 'c'),
        throwsStateError,
      );
    });

    test('locked host refuses assign and clear with StateError', () {
      final store = _slotStore();
      store.setNodeLocked('h', true);
      expect(
        () => store.setSlotChild('h', 'content', 'c'),
        throwsStateError,
      );
      expect(
        () => store.setSlotChild('h', 'content', null),
        throwsStateError,
      );
    });
  });

  group('setNodeLocked', () {
    test('toggles, undoes, and no-ops on unknown / same value', () {
      final store = _slotStore();
      expect(_node(store, 'h').locked, isFalse);
      final before = _depth(store);

      store.setNodeLocked('h', true);
      expect(_node(store, 'h').locked, isTrue);

      expect(store.undo(), isTrue);
      expect(_node(store, 'h').locked, isFalse);
      expect(store.redo(), isTrue);
      expect(_node(store, 'h').locked, isTrue);

      store.setNodeLocked('ghost', true);
      store.setNodeLocked('h', true);
      // Same value: no extra commit.
      expect(_depth(store), before + 1);
    });
  });

  group('lock guards', () {
    test('deleteNode no-ops on locked nodes and locked subtrees', () {
      final store = _slotStore();
      store.setNodeLocked('c', true);

      store.deleteNode('c');
      expect(_node(store, 'c').id, 'c');

      // Cascade containing a locked descendant refuses the whole delete.
      store.setNodeLocked('c', false);
      store.reparentNode('c', 'h');
      store.setNodeLocked('c', true);
      store.deleteNode('h');
      expect(_node(store, 'h').id, 'h');
      expect(_node(store, 'c').id, 'c');

      // Unlocked, the same delete commits.
      store.setNodeLocked('c', false);
      store.deleteNode('h');
      expect(store.doc.nodes.map((n) => n.id), isNot(contains('h')));
    });

    test('deleteNode scrubs slot refs to deleted nodes', () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');
      store.deleteNode('c');
      expect(_node(store, 'h').slotNodes, isEmpty);
      expect(store.undo(), isTrue);
      expect(_node(store, 'h').slotNodes, {'content': 'c'});
    });

    test('reparentNode throws on locked nodes and locked parents', () {
      final store = _slotStore();
      store.setNodeLocked('c', true);
      expect(() => store.reparentNode('c', 'h'), throwsStateError);
      expect(() => store.reparentNode('c', null), throwsStateError);

      store.setNodeLocked('c', false);
      store.setNodeLocked('h', true);
      expect(() => store.reparentNode('o', 'h'), throwsStateError);
    });

    test('setNodeSize no-ops on locked nodes', () {
      final store = _slotStore();
      store.setNodeLocked('c', true);
      final before = _depth(store);
      store.setNodeSize('c', w: 200);
      expect(_node(store, 'c').w, isNull);
      expect(_depth(store), before);
    });

    test('groupIntoRow throws when a member is locked', () {
      final store = _slotStore();
      store.setNodeLocked('c', true);
      expect(() => store.groupIntoRow(['c', 'o']), throwsStateError);
    });
  });

  group('locked+slotNodes carry audit', () {
    test('moveNode / patchItem / clearItemProps / setItemSteps carry', () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');

      store.moveNode('h', 5, 6);
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      store.patchItem('h', 'ih', props: {'title': 'T2'});
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      store.clearItemProps('h', 'ih', {'title'});
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      store.setItemSteps('h', 'ih', [ActionStep.navigate(to: 's2')]);
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      store.setNodeLocked('h', true);
      store.patchItem('h', 'ih', props: {'title': 'T3'});
      final h = _node(store, 'h');
      expect(h.slotNodes, {'content': 'c'});
      expect(h.locked, isTrue);
    });

    test('patchNode / setNodeResponsive / setNodeSize / reparentNode carry',
        () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');

      store.patchNode('h', gap: 4);
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      store.setNodeResponsive('h', hiddenOn: {'mobile'});
      var h = _node(store, 'h');
      expect(h.slotNodes, {'content': 'c'});
      expect(h.hiddenOn, {'mobile'});

      store.setNodeSize('h', w: 200);
      h = _node(store, 'h');
      expect(h.slotNodes, {'content': 'c'});
      expect(h.w, 200);

      final row = store.addRow(screenId: 's1');
      store.reparentNode('h', row);
      final h2 = _node(store, 'h');
      expect(h2.parentId, row);
      expect(h2.slotNodes, {'content': 'c'});
    });

    test('groupIntoRow carries member slots (locked members refuse)', () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');
      final row = store.groupIntoRow(['h', 'o']);
      expect(row, isNotEmpty);
      final h = _node(store, 'h');
      expect(h.parentId, row);
      expect(h.slotNodes, {'content': 'c'});
      expect(h.locked, isFalse);
      // Locked members never reach the rebuild (the guard throws first —
      // see the lock-guards group), so there is no locked-carry path here.
    });

    test('duplicateNode clones locks and remaps in-subtree slot refs', () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');
      store.setNodeLocked('c', true);
      // Slot ref OUTSIDE the duplicated subtree keeps pointing out.
      final cloneId = store.duplicateNode('h');
      final clone = _node(store, cloneId);
      expect(clone.slotNodes, {'content': 'c'});
      expect(clone.locked, isFalse);

      final kidClone = store.duplicateNode('c');
      expect(_node(store, kidClone).locked, isTrue);

      // Import-style doc where the slot target sits INSIDE the duplicated
      // subtree (unreachable via setSlotChild, which refuses descendants):
      // the clone's slot must re-point at the fresh clone id.
      final store2 = CanvasStore(prefs: _FakePrefs());
      store2.replaceDoc(ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'h',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'ih', 'kind': 'card'},
            ],
            'slotNodes': {'content': 'c'},
          },
          {
            'id': 'c',
            'screenId': 's1',
            'x': 0.0,
            'y': 10.0,
            'parentId': 'h',
            'items': [
              {'id': 'ic', 'kind': 'button'},
            ],
          },
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard'
        },
        'meta': {'title': 'T', 'brief': ''},
      }));
      final clone2 = store2.duplicateNode('h');
      final cloneNode =
          store2.doc.nodes.singleWhere((n) => n.id == clone2);
      final kidCloneId = cloneNode.slotNodes['content']!;
      expect(kidCloneId, isNot('c'));
      final kidClone2 =
          store2.doc.nodes.singleWhere((n) => n.id == kidCloneId);
      expect(kidClone2.parentId, clone2);
    });

    test('renameVar / deleteVar node rebuilds carry', () {
      final store = _slotStore();
      store.addVar(
        const AppStateVar(name: 'v', type: 'string', defaultValue: ''),
      );
      store.patchItem('h', 'ih', props: {'title': '=v'});
      store.setSlotChild('h', 'content', 'c');
      store.setNodeLocked('h', true);

      store.renameVar('v', 'w');
      var h = _node(store, 'h');
      expect(h.slotNodes, {'content': 'c'});
      expect(h.locked, isTrue);

      store.deleteVar('w');
      h = _node(store, 'h');
      expect(h.slotNodes, {'content': 'c'});
      expect(h.locked, isTrue);
    });

    test('ungroupRowDoc carries member slots and locks', () {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');
      final row = store.groupIntoRow(['h', 'o']);
      store.setNodeLocked('h', true);
      final next = ungroupRowDoc(store.doc, row);
      final h = next.nodes.singleWhere((n) => n.id == 'h');
      expect(h.parentId, isNull);
      expect(h.slotNodes, {'content': 'c'});
      expect(h.locked, isTrue);
    });
  });
}
