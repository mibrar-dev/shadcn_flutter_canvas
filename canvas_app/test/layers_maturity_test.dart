import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
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

ScreenDoc _layerDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's9', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 10.0,
          'y': 10.0,
          'items': [],
        },
        {
          'id': 'n3',
          'screenId': 's1',
          'x': 20.0,
          'y': 20.0,
          'items': [],
        },
        {
          'id': 'm1',
          'screenId': 's9',
          'x': 0.0,
          'y': 0.0,
          'items': [],
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Layers', 'brief': ''},
    });

/// Paint order of screen `s1` (doc order filtered to the screen).
List<String> _s1Order(CanvasStore store) => [
      for (final n in store.doc.nodes)
        if (n.screenId == 's1') n.id,
    ];

Widget _harness({
  required CanvasStore store,
  String? selectedNodeId,
  ValueChanged<String?>? onSelectNode,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LayersPanel(
        store: store,
        selectedNodeId: selectedNodeId,
        onSelectNode: onSelectNode ?? (_) {},
      ),
    ),
  );
}

String _addButton(CanvasStore store) {
  return store.addNode(
    screenId: 's1',
    x: 0,
    y: 0,
    items: [
      CanvasItem(id: store.uid(), kind: 'button', props: const {}),
    ],
  );
}

void main() {
  test('reorder moves paint order and undo restores it', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _layerDoc());
    expect(_s1Order(store), ['n1', 'n2', 'n3']);

    store.reorderNode('n1', 2);
    expect(_s1Order(store), ['n2', 'n3', 'n1']);

    expect(store.undo(), isTrue);
    expect(_s1Order(store), ['n1', 'n2', 'n3']);

    expect(store.redo(), isTrue);
    expect(_s1Order(store), ['n2', 'n3', 'n1']);
  });

  test('reorder clamps and never crosses screens; unknown id throws clean', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _layerDoc());

    // Out-of-range indices clamp into the screen's node list.
    store.reorderNode('n1', 99);
    expect(_s1Order(store), ['n2', 'n3', 'n1']);
    store.reorderNode('n1', -5);
    expect(_s1Order(store), ['n1', 'n2', 'n3']);

    // Cross-screen moves are refused: the node keeps its screen and the
    // other screen's nodes keep their exact positions.
    store.reorderNode('n2', 0);
    expect(_s1Order(store), ['n2', 'n1', 'n3']);
    expect(
      store.doc.nodes.singleWhere((n) => n.id == 'n2').screenId,
      's1',
    );
    expect(
      [
        for (final n in store.doc.nodes)
          if (n.screenId == 's9') n.id,
      ],
      ['m1'],
    );

    // Unknown id throws before committing, so history stays clean.
    final fresh = CanvasStore(prefs: FakePrefs(), initial: _layerDoc());
    expect(() => fresh.reorderNode('nope', 0), throwsStateError);
    expect(fresh.canUndo, isFalse);
    expect(_s1Order(fresh), ['n1', 'n2', 'n3']);

    // A no-op reorder (already at the clamped index) does not pollute undo.
    fresh.reorderNode('n1', 0);
    expect(fresh.canUndo, isFalse);
  });

  testWidgets('rename updates the header text in a pumped LayersPanel',
      (tester) async {
    final store = CanvasStore();
    await tester.pumpWidget(_harness(store: store));
    expect(find.text('Screen 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename screen'));
    await tester.pumpAndSettle();

    // Dialog TextField arrives prefilled with the screen name.
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'Screen 1');

    await tester.enterText(field, 'Gallery');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Screen 1'), findsNothing);
    expect(store.doc.screens.single.name, 'Gallery');

    // Empty Save is a no-op close: dialog dismisses, name untouched.
    await tester.tap(find.byTooltip('Rename screen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    expect(store.doc.screens.single.name, 'Gallery');
  });

  testWidgets('reorder buttons move paint order; edges disabled not hidden',
      (tester) async {
    final store = CanvasStore();
    final first = _addButton(store);
    final second = _addButton(store);
    await tester.pumpWidget(_harness(store: store));
    await tester.pump();

    Finder moveUp(int at) => find
        .byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Move up',
        )
        .at(at);
    Finder moveDown(int at) => find
        .byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Move down',
        )
        .at(at);
    expect(moveUp(0), findsOneWidget);
    expect(moveDown(0), findsOneWidget);
    expect(moveUp(1), findsOneWidget);
    expect(moveDown(1), findsOneWidget);

    // Rows are frontmost-first: row 0 is `second` (up disabled), row 1 is
    // `first` (down disabled). Buttons stay visible, just disabled.
    expect(tester.widget<IconButton>(moveUp(0)).onPressed, isNull);
    expect(tester.widget<IconButton>(moveDown(0)).onPressed, isNotNull);
    expect(tester.widget<IconButton>(moveUp(1)).onPressed, isNotNull);
    expect(tester.widget<IconButton>(moveDown(1)).onPressed, isNull);

    // Send the frontmost row backward: doc order flips.
    await tester.tap(moveDown(0));
    await tester.pump();
    expect(
      [for (final n in store.doc.nodes) n.id],
      [second, first],
    );

    // Edges swap: the moved row is now backmost (down disabled).
    expect(tester.widget<IconButton>(moveDown(1)).onPressed, isNull);
    expect(tester.widget<IconButton>(moveUp(1)).onPressed, isNotNull);
  });

  testWidgets('existing select/duplicate/delete unaffected', (tester) async {
    final store = CanvasStore();
    final id = _addButton(store);
    String? selected;
    await tester.pumpWidget(
      _harness(store: store, onSelectNode: (v) => selected = v),
    );
    await tester.pump();

    await tester.tap(find.textContaining(id));
    expect(selected, id);

    await tester.tap(find.byTooltip('Duplicate'));
    await tester.pump();
    expect(store.doc.nodes, hasLength(2));

    await tester.tap(find.textContaining(id).first);
    await tester.pump();
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pump();
    expect(store.doc.nodes, hasLength(1));

    // Reorder chrome coexists with the original actions.
    expect(find.byTooltip('Move up'), findsOneWidget);
    expect(find.byTooltip('Move down'), findsOneWidget);
  });
}
