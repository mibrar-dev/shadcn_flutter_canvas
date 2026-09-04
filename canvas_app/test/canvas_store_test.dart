import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePrefs implements PrefsPort {
  final writes = <String, String>{};
  @override
  Future<String?> read(String key) async => writes[key];
  @override
  Future<void> write(String key, String value) async {
    writes[key] = value;
  }
}

ScreenDoc _twoScreenDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's9', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Pay',
              'action': {'to': 's9', 'transition': 'slide'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Checkout', 'brief': '2-screen pay flow'},
    });

void main() {
  test('add node then undo removes it then redo restores it', () {
    final store = CanvasStore(prefs: FakePrefs());
    final id = store.addNode(screenId: 's1', x: 10, y: 20);
    expect(store.doc.nodes, hasLength(1));
    expect(store.undo(), isTrue);
    expect(store.doc.nodes, isEmpty);
    expect(store.redo(), isTrue);
    expect(store.doc.nodes, hasLength(1));
    expect(store.doc.nodes.single.id, id);
  });

  test('moveNode updates x/y', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _twoScreenDoc());
    store.moveNode('n1', 100, 200);
    final node = store.doc.nodes.singleWhere((n) => n.id == 'n1');
    expect(node.x, 100);
    expect(node.y, 200);
  });

  test('autosave receives JSON containing node id', () async {
    final prefs = FakePrefs();
    final store = CanvasStore(prefs: prefs);
    final id = store.addNode(screenId: 's1', x: 10, y: 20);
    await store.flush();
    final saved = jsonDecode(prefs.writes['canvas:doc']!) as Map<String, dynamic>;
    final ids = [
      for (final n in saved['nodes'] as List) (n as Map)['id'] as String
    ];
    expect(ids, contains(id));
  });

  test('duplicateNode regenerates item ids', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _twoScreenDoc());
    final copyId = store.duplicateNode('n1');
    expect(copyId, isNot('n1'));
    final itemIds = [
      for (final n in store.doc.nodes)
        for (final i in n.items) i.id,
    ];
    expect(itemIds.toSet(), hasLength(itemIds.length));
    expect(itemIds, contains('i1'));
  });

  test('deleteScreen refused while targeted, proceeds after retarget', () {    final store = CanvasStore(prefs: FakePrefs(), initial: _twoScreenDoc());
    final refused = store.deleteScreen('s9');
    expect(refused, contains('dangling action i1 -> missing screen s9'));
    expect(store.doc.screens.map((s) => s.id), contains('s9'));

    store.setItemAction(
      'n1',
      'i1',
      const NodeAction(to: 's1', transition: 'slide'),
    );
    expect(store.deleteScreen('s9'), isEmpty);
    expect(store.doc.screens.map((s) => s.id), isNot(contains('s9')));
  });

  test('setTheme replaces theme and is undoable', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _twoScreenDoc());
    store.setTheme(CanvasTheme(
        paletteKey: 'indigo', dark: true, shape: 'pill', motion: 'standard'));
    expect(store.doc.theme.dark, isTrue);
    expect(store.doc.theme.paletteKey, 'indigo');
    expect(store.undo(), isTrue);
    expect(store.doc.theme.dark, isFalse);
  });
}
