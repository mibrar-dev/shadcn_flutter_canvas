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

const _chrome = CanvasTheme(
  paletteKey: 'amber-minimal',
  dark: false,
  shape: 'pill',
  motion: 'standard',
);

CanvasTheme _richTheme() => const CanvasTheme(
      paletteKey: 'clean-slate',
      dark: true,
      shape: 'rounded',
      motion: 'standard',
      chrome: _chrome,
    );

/// Rich leaf node carrying every CanvasNode/CanvasItem field.
CanvasNode _richNode({String id = 'n1', String screenId = 's1'}) => CanvasNode(
      id: id,
      screenId: screenId,
      x: 11.0,
      y: 22.0,
      items: const [
        CanvasItem(
          id: 'i1',
          kind: 'button',
          props: {'label': 'Pay', 'variant': 'primary'},
          action: NodeAction(to: 's2', transition: 'slide'),
        ),
      ],
      parentId: null,
      isRow: false,
      gap: 9.0,
      mainAxis: 'center',
      crossAxis: 'end',
      expand: 'flex',
      flex: 2,
      hiddenOn: {'mobile'},
      breakpointValues: {
        'tablet': {'columns': 2},
      },
      slots: {'main': 'i1'},
    );

ScreenDoc _richDoc() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Pay',
          x: 1.0,
          y: 2.0,
          bg: 'surface',
          device: 'tablet',
        ),
        CanvasScreen(
          id: 's2',
          name: 'Done',
          x: 420.0,
          y: 0.0,
          bg: 'surface',
          device: 'desktop-wide',
        ),
      ],
      nodes: [_richNode()],
      theme: _richTheme(),
      meta: const DocMeta(title: 'T', brief: 'B'),
    );

CanvasNode _node(CanvasStore store, String id) =>
    store.doc.nodes.singleWhere((n) => n.id == id);

void _expectRichNode(CanvasNode n, {String id = 'n1'}) {
  expect(n.id, id);
  expect(n.screenId, 's1');
  expect(n.parentId, isNull);
  expect(n.isRow, isFalse);
  expect(n.gap, 9.0);
  expect(n.mainAxis, 'center');
  expect(n.crossAxis, 'end');
  expect(n.expand, 'flex');
  expect(n.flex, 2);
  expect(n.hiddenOn, {'mobile'});
  expect(n.breakpointValues, {
    'tablet': {'columns': 2},
  });
  expect(n.slots, {'main': 'i1'});
  expect(n.items, hasLength(1));
  final item = n.items.single;
  expect(item.id, 'i1');
  expect(item.kind, 'button');
  expect(item.props['label'], 'Pay');
  expect(item.props['variant'], 'primary');
  expect(item.action?.to, 's2');
  expect(item.action?.transition, 'slide');
}

void _expectRichTheme(CanvasTheme t) {
  expect(t.paletteKey, 'clean-slate');
  expect(t.dark, isTrue);
  expect(t.shape, 'rounded');
  expect(t.motion, 'standard');
  expect(t.chrome, isNotNull);
  expect(t.chrome!.paletteKey, 'amber-minimal');
  expect(t.chrome!.dark, isFalse);
  expect(t.chrome!.shape, 'pill');
  expect(t.chrome!.motion, 'standard');
}

void main() {
  test('moveNode changes x/y and preserves every other field', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    final before = _node(store, 'n1');
    store.moveNode('n1', 100, 200);
    final n = _node(store, 'n1');
    expect(n.x, 100);
    expect(n.y, 200);
    expect(n.screenId, before.screenId);
    expect(n.parentId, before.parentId);
    expect(n.isRow, before.isRow);
    expect(n.gap, before.gap);
    expect(n.mainAxis, before.mainAxis);
    expect(n.crossAxis, before.crossAxis);
    expect(n.expand, before.expand);
    expect(n.flex, before.flex);
    expect(n.hiddenOn, {'mobile'});
    expect(n.breakpointValues, {
      'tablet': {'columns': 2},
    });
    expect(n.slots, {'main': 'i1'});
    expect(n.items.single.props['label'], 'Pay');
    expect(n.items.single.action?.to, 's2');
    // Deep copy: responsive collections must not alias the pre-move snapshot.
    expect(identical(n.hiddenOn, before.hiddenOn), isFalse);
    expect(identical(n.slots, before.slots), isFalse);
  });

  test('patchNode changes gap and preserves responsive fields', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.patchNode('n1', gap: 24.0);
    final n = _node(store, 'n1');
    expect(n.gap, 24.0);
    expect(n.mainAxis, 'center');
    expect(n.crossAxis, 'end');
    expect(n.expand, 'flex');
    expect(n.flex, 2);
    expect(n.x, 11.0);
    expect(n.y, 22.0);
    expect(n.hiddenOn, {'mobile'});
    expect(n.breakpointValues, {
      'tablet': {'columns': 2},
    });
    expect(n.slots, {'main': 'i1'});
    expect(n.items.single.action?.to, 's2');
  });

  test('setNodeResponsive changes responsive and preserves layout/action', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.setNodeResponsive(
      'n1',
      hiddenOn: {'tablet', 'desktop'},
      breakpointValues: {
        'desktop': {'columns': 3},
      },
      slots: {'hero': 'i1'},
    );
    final n = _node(store, 'n1');
    expect(n.hiddenOn, {'tablet', 'desktop'});
    expect(n.breakpointValues, {
      'desktop': {'columns': 3},
    });
    expect(n.slots, {'hero': 'i1'});
    // Layout + item fields untouched.
    expect(n.gap, 9.0);
    expect(n.mainAxis, 'center');
    expect(n.crossAxis, 'end');
    expect(n.expand, 'flex');
    expect(n.flex, 2);
    expect(n.x, 11.0);
    expect(n.y, 22.0);
    expect(n.items.single.props['label'], 'Pay');
    expect(n.items.single.action?.to, 's2');
  });

  test('duplicateNode preserves every field with fresh ids and offset', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    final copyId = store.duplicateNode('n1');
    expect(copyId, isNot('n1'));
    final src = _node(store, 'n1');
    final copy = _node(store, copyId);
    expect(copy.x, src.x + 16);
    expect(copy.y, src.y + 16);
    expect(copy.screenId, src.screenId);
    expect(copy.parentId, src.parentId);
    expect(copy.isRow, src.isRow);
    expect(copy.gap, src.gap);
    expect(copy.mainAxis, src.mainAxis);
    expect(copy.crossAxis, src.crossAxis);
    expect(copy.expand, src.expand);
    expect(copy.flex, src.flex);
    expect(copy.hiddenOn, src.hiddenOn);
    expect(copy.breakpointValues, src.breakpointValues);
    expect(copy.slots, src.slots);
    expect(copy.items, hasLength(1));
    expect(copy.items.single.id, isNot(src.items.single.id));
    expect(copy.items.single.kind, 'button');
    expect(copy.items.single.props['label'], 'Pay');
    expect(copy.items.single.action?.to, 's2');
    expect(copy.items.single.action?.transition, 'slide');
    expect(identical(copy.hiddenOn, src.hiddenOn), isFalse);
  });

  test('duplicateNode subtree preserves responsive fields and re-parents', () {
    final doc = ScreenDoc(
      screens: const [
        CanvasScreen(id: 's1', name: 'S', x: 0, y: 0, bg: 'surface'),
      ],
      nodes: [
        const CanvasNode(
          id: 'r1',
          screenId: 's1',
          x: 0,
          y: 0,
          items: [],
          isRow: true,
          gap: 8.0,
          hiddenOn: {'desktop'},
          breakpointValues: {
            'tablet': {'columns': 1},
          },
          slots: {'row-slot': 'x'},
        ),
        CanvasNode(
          id: 'c1',
          screenId: 's1',
          x: 1,
          y: 1,
          items: const [
            CanvasItem(
              id: 'ic1',
              kind: 'button',
              props: {'label': 'C1'},
              action: NodeAction(to: 's1', transition: 'fade'),
            ),
          ],
          parentId: 'r1',
          mainAxis: 'end',
          expand: 'expanded',
          flex: 3,
          hiddenOn: const {'mobile'},
          breakpointValues: const {
            'desktop': {'span': 2},
          },
          slots: const {'main': 'ic1'},
        ),
      ],
      theme: _richTheme(),
      meta: const DocMeta(title: 'T', brief: 'B'),
    );
    final store = CanvasStore(prefs: FakePrefs(), initial: doc);
    final rowCopyId = store.duplicateNode('r1');
    final rowCopy = _node(store, rowCopyId);
    expect(rowCopy.isRow, isTrue);
    expect(rowCopy.hiddenOn, {'desktop'});
    expect(rowCopy.breakpointValues, {
      'tablet': {'columns': 1},
    });
    expect(rowCopy.slots, {'row-slot': 'x'});
    final childCopies = [
      for (final n in store.doc.nodes)
        if (n.parentId == rowCopyId) n,
    ];
    expect(childCopies, hasLength(1));
    final child = childCopies.single;
    expect(child.id, isNot('c1'));
    expect(child.mainAxis, 'end');
    expect(child.expand, 'expanded');
    expect(child.flex, 3);
    expect(child.hiddenOn, {'mobile'});
    expect(child.breakpointValues, {
      'desktop': {'span': 2},
    });
    expect(child.slots, {'main': 'ic1'});
    expect(child.items.single.props['label'], 'C1');
    expect(child.items.single.action?.to, 's1');
    // Originals untouched.
    expect(_node(store, 'c1').parentId, 'r1');
  });

  test('setScreenDevice changes device and preserves other screen fields', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.setScreenDevice('s1', 'desktop-fluid');
    final s = store.doc.screens.singleWhere((e) => e.id == 's1');
    expect(s.device, 'desktop-fluid');
    expect(s.name, 'Pay');
    expect(s.x, 1.0);
    expect(s.y, 2.0);
    expect(s.bg, 'surface');
    // Sibling screen untouched.
    final other = store.doc.screens.singleWhere((e) => e.id == 's2');
    expect(other.device, 'desktop-wide');
  });

  test('renameScreen renames and preserves device and coords', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.renameScreen('s1', 'Home');
    final s = store.doc.screens.singleWhere((e) => e.id == 's1');
    expect(s.name, 'Home');
    expect(s.device, 'tablet');
    expect(s.x, 1.0);
    expect(s.y, 2.0);
    expect(s.bg, 'surface');
  });

  test('reorderNode reorders without dropping node fields', () {
    final doc = ScreenDoc(
      screens: const [
        CanvasScreen(id: 's1', name: 'S', x: 0, y: 0, bg: 'surface'),
        CanvasScreen(id: 's2', name: 'O', x: 0, y: 0, bg: 'surface'),
      ],
      nodes: [
        _richNode(id: 'n1'),
        const CanvasNode(
          id: 'n2',
          screenId: 's1',
          x: 5,
          y: 5,
          items: [],
          gap: 4.0,
          mainAxis: 'end',
          hiddenOn: {'tablet'},
          breakpointValues: {
            'desktop': {'span': 1},
          },
          slots: {'side': 'x'},
        ),
      ],
      theme: _richTheme(),
      meta: const DocMeta(title: 'T', brief: 'B'),
    );
    final store = CanvasStore(prefs: FakePrefs(), initial: doc);
    store.reorderNode('n1', 1);
    expect(store.doc.nodes.map((n) => n.id).toList(), ['n2', 'n1']);
    _expectRichNode(_node(store, 'n1'));
    final n2 = _node(store, 'n2');
    expect(n2.gap, 4.0);
    expect(n2.mainAxis, 'end');
    expect(n2.hiddenOn, {'tablet'});
    expect(n2.breakpointValues, {
      'desktop': {'span': 1},
    });
    expect(n2.slots, {'side': 'x'});
  });

  test('addRow keeps existing nodes intact and honors layout args', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    final rowId = store.addRow(
      screenId: 's1',
      mainAxis: 'center',
      crossAxis: 'stretch',
      expand: 'flex',
      flex: 2,
      gap: 10.0,
    );
    _expectRichNode(_node(store, 'n1'));
    final row = _node(store, rowId);
    expect(row.isRow, isTrue);
    expect(row.screenId, 's1');
    expect(row.gap, 10.0);
    expect(row.mainAxis, 'center');
    expect(row.crossAxis, 'stretch');
    expect(row.expand, 'flex');
    expect(row.flex, 2);
  });

  test('patchItem merges props and preserves action + node fields', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.patchItem('n1', 'i1', props: {'label': 'Pay now'});
    final n = _node(store, 'n1');
    expect(n.items.single.props['label'], 'Pay now');
    expect(n.items.single.props['variant'], 'primary');
    expect(n.items.single.action?.to, 's2');
    expect(n.items.single.action?.transition, 'slide');
    expect(n.gap, 9.0);
    expect(n.mainAxis, 'center');
    expect(n.flex, 2);
    expect(n.hiddenOn, {'mobile'});
    expect(n.breakpointValues, {
      'tablet': {'columns': 2},
    });
    expect(n.slots, {'main': 'i1'});
  });

  test('setItemAction replaces action and preserves props + node fields', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.setItemAction(
      'n1',
      'i1',
      const NodeAction(to: 's1', transition: 'fade'),
    );
    final n = _node(store, 'n1');
    expect(n.items.single.action?.to, 's1');
    expect(n.items.single.action?.transition, 'fade');
    expect(n.items.single.props['label'], 'Pay');
    expect(n.items.single.props['variant'], 'primary');
    expect(n.hiddenOn, {'mobile'});
    expect(n.breakpointValues, {
      'tablet': {'columns': 2},
    });
    expect(n.slots, {'main': 'i1'});
    expect(n.flex, 2);
  });

  test('clearItemProps removes keys and preserves rest + node fields', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    store.clearItemProps('n1', 'i1', {'variant'});
    final n = _node(store, 'n1');
    expect(n.items.single.props.containsKey('variant'), isFalse);
    expect(n.items.single.props['label'], 'Pay');
    expect(n.items.single.action?.to, 's2');
    expect(n.hiddenOn, {'mobile'});
    expect(n.breakpointValues, {
      'tablet': {'columns': 2},
    });
    expect(n.slots, {'main': 'i1'});
    expect(n.mainAxis, 'center');
    expect(n.flex, 2);
  });

  test('setTheme replaces theme verbatim incl. chrome, keeps nodes/screens',
      () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    const next = CanvasTheme(
      paletteKey: 'indigo',
      dark: false,
      shape: 'pill',
      motion: 'standard',
      chrome: CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
    );
    store.setTheme(next);
    expect(store.doc.theme.paletteKey, 'indigo');
    expect(store.doc.theme.dark, isFalse);
    expect(store.doc.theme.chrome?.paletteKey, 'clean-slate');
    expect(store.doc.theme.chrome?.dark, isTrue);
    _expectRichNode(_node(store, 'n1'));
    expect(store.doc.screens.singleWhere((s) => s.id == 's1').device, 'tablet');
  });

  test('undo/redo round-trip restores every field', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _richDoc());
    _expectRichTheme(store.doc.theme);
    _expectRichNode(_node(store, 'n1'));
    store.moveNode('n1', 100, 200);
    expect(_node(store, 'n1').x, 100);
    expect(store.undo(), isTrue);
    _expectRichNode(_node(store, 'n1'));
    expect(_node(store, 'n1').x, 11.0);
    _expectRichTheme(store.doc.theme);
    expect(store.redo(), isTrue);
    final n = _node(store, 'n1');
    expect(n.x, 100);
    expect(n.y, 200);
    expect(n.hiddenOn, {'mobile'});
    expect(n.breakpointValues, {
      'tablet': {'columns': 2},
    });
    expect(n.slots, {'main': 'i1'});
    expect(n.flex, 2);
    expect(n.items.single.action?.to, 's2');
    _expectRichTheme(store.doc.theme);
  });
}
