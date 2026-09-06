/// Track U2 store: `setNodeSize` validation, no-op rules, undo, and
/// field preservation (sizes survive every unrelated mutator).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenDoc _doc() => ScreenDoc.fromJson({
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
          'id': 'n1',
          'screenId': 's1',
          'x': 4.0,
          'y': 8.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Go',
              'action': {'to': 's1', 'transition': 'slide'},
            },
          ],
          'parentId': 'r1',
          'isRow': false,
          'gap': 8.0,
          'mainAxis': 'center',
          'expand': 'flex',
          'flex': 2,
          'hiddenOn': ['mobile'],
          'breakpointValues': {
            'tablet': {'columns': 2},
          },
          'slots': {'main': 'i1'},
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Sizes', 'brief': ''},
    });

CanvasNode _node(CanvasStore store, String id) =>
    store.doc.nodes.singleWhere((n) => n.id == id);

void main() {
  group('setNodeSize', () {
    test('sets w/h and undo/redo round-trips', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120, h: 80);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
      expect(store.undo(), isTrue);
      expect(_node(store, 'n1').w, isNull);
      expect(_node(store, 'n1').h, isNull);
      expect(store.redo(), isTrue);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
    });

    test('partial writes leave the other dim alone', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, isNull);
      store.setNodeSize('n1', h: 80);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
    });

    test('clear flags reset to auto and win over values', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120, h: 80);
      store.setNodeSize('n1', clearW: true);
      expect(_node(store, 'n1').w, isNull);
      expect(_node(store, 'n1').h, 80.0);
      // clearW wins over w when both are given.
      store.setNodeSize('n1', w: 200, clearW: true, clearH: true);
      expect(_node(store, 'n1').w, isNull);
      expect(_node(store, 'n1').h, isNull);
    });

    test('unknown node is a no-op without committing', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('ghost', w: 10);
      expect(store.canUndo, isFalse);
    });

    test('empty and equal writes are no-ops without committing', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1');
      expect(store.canUndo, isFalse);
      // Clearing already-auto dims commits nothing.
      store.setNodeSize('n1', clearW: true, clearH: true);
      expect(store.canUndo, isFalse);
      // One real write, then an equal rewrite: still a single undo entry.
      store.setNodeSize('n1', w: 50, h: 60);
      store.setNodeSize('n1', w: 50, h: 60);
      expect(store.undo(), isTrue);
      expect(_node(store, 'n1').w, isNull);
      expect(store.canUndo, isFalse);
    });

    test('non-positive and non-finite values throw without committing', () {
      final store = CanvasStore(initial: _doc());
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => store.setNodeSize('n1', w: bad),
          throwsArgumentError,
          reason: 'w=$bad',
        );
        expect(
          () => store.setNodeSize('n1', h: bad),
          throwsArgumentError,
          reason: 'h=$bad',
        );
      }
      expect(store.canUndo, isFalse);
      expect(_node(store, 'n1').w, isNull);
    });

    test('preserves every other field with deep-copy precedent', () {
      final store = CanvasStore(initial: _doc());
      final before = _node(store, 'n1');
      store.setNodeSize('n1', w: 120, h: 80);
      final n = _node(store, 'n1');
      expect(n.x, 4.0);
      expect(n.y, 8.0);
      expect(n.parentId, 'r1');
      expect(n.isRow, isFalse);
      expect(n.gap, 8.0);
      expect(n.mainAxis, 'center');
      expect(n.expand, 'flex');
      expect(n.flex, 2);
      expect(n.hiddenOn, {'mobile'});
      expect(n.breakpointValues, {
        'tablet': {'columns': 2},
      });
      expect(n.slots, {'main': 'i1'});
      expect(n.items.single.props['label'], 'Go');
      expect(n.items.single.action?.to, 's1');
      // Responsive collections are copied, never aliased.
      expect(identical(n.hiddenOn, before.hiddenOn), isFalse);
      expect(identical(n.slots, before.slots), isFalse);
      expect(
        identical(
          n.breakpointValues['tablet'],
          before.breakpointValues['tablet'],
        ),
        isFalse,
      );
    });
  });

  group('size preservation across mutators', () {
    test('moveNode/patchItem/patchNode keep w/h', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120, h: 80);
      store.moveNode('n1', 99, 88);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
      store.patchItem('n1', 'i1', props: {'label': 'Stop'});
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
      store.patchNode('n1', gap: 20);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
    });

    test('duplicateNode clones w/h with fresh ids', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120, h: 80);
      final copyId = store.duplicateNode('n1');
      final copy = _node(store, copyId);
      expect(copy.w, 120.0);
      expect(copy.h, 80.0);
      expect(copy.items.single.id, isNot('i1'));
    });

    test('setNodeResponsive and reparentNode keep w/h', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120, h: 80);
      store.setNodeResponsive('n1', hiddenOn: {'tablet'});
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
      store.reparentNode('n1', null);
      expect(_node(store, 'n1').parentId, isNull);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
    });

    test('sizes persist through JSON snapshot (undo payload)', () {
      final store = CanvasStore(initial: _doc());
      store.setNodeSize('n1', w: 120, h: 80);
      store.moveNode('n1', 1, 2);
      expect(store.undo(), isTrue);
      expect(_node(store, 'n1').w, 120.0);
      expect(_node(store, 'n1').h, 80.0);
      expect(store.undo(), isTrue);
      expect(_node(store, 'n1').w, isNull);
    });
  });
}
