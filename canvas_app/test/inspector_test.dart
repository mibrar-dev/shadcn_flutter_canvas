import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test doc: one node on s1 with a button item carrying plan Task 3 defaults.
(CanvasStore, String, String) _storeWithButton() {
  final store = CanvasStore();
  const itemId = 'i1';
  final nodeId = store.addNode(
    screenId: 's1',
    x: 16,
    y: 96,
    items: const [
      CanvasItem(
        id: itemId,
        kind: 'button',
        props: {
          'label': 'Button',
          'variant': 'primary',
          'size': 'md',
          'disabled': false,
        },
      ),
    ],
  );
  return (store, nodeId, itemId);
}

CanvasItem _item(CanvasStore store, String nodeId, String itemId) => store
    .doc.nodes
    .singleWhere((n) => n.id == nodeId)
    .items
    .singleWhere((i) => i.id == itemId);

Future<void> _pumpInspector(
  WidgetTester tester,
  CanvasStore store, {
  String? nodeId,
  String? itemId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InspectorPanel(store: store, nodeId: nodeId, itemId: itemId),
      ),
    ),
  );
}

void main() {
  testWidgets('empty selection renders the hint', (tester) async {
    await _pumpInspector(tester, CanvasStore());
    expect(find.text('Select an item to edit its props'), findsOneWidget);
  });

  testWidgets('button item renders string, enum, and bool editors', (
    tester,
  ) async {
    final (store, nodeId, itemId) = _storeWithButton();
    await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

    expect(find.byType(shadcn.TextField), findsOneWidget);
    expect(find.byType(shadcn.Select<String>), findsNWidgets(2));
    expect(find.byType(shadcn.Switch), findsOneWidget);
  });

  testWidgets('setting label text updates the store', (tester) async {
    final (store, nodeId, itemId) = _storeWithButton();
    await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

    await tester.enterText(find.byType(shadcn.TextField), 'Pay now');
    await tester.pump();

    expect(_item(store, nodeId, itemId).props['label'], 'Pay now');
  });

  testWidgets('toggling disabled updates the store', (tester) async {
    final (store, nodeId, itemId) = _storeWithButton();
    await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

    expect(_item(store, nodeId, itemId).props['disabled'], isFalse);
    await tester.tap(find.byType(shadcn.Switch));
    await tester.pump();

    expect(_item(store, nodeId, itemId).props['disabled'], isTrue);
  });

  testWidgets('unknown kind renders a fallback note instead of crashing', (
    tester,
  ) async {
    final store = CanvasStore();
    final nodeId = store.addNode(
      screenId: 's1',
      x: 0,
      y: 0,
      items: const [CanvasItem(id: 'm1', kind: 'mystery')],
    );
    await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'm1');

    expect(find.text('No editable props for kind mystery'), findsOneWidget);
  });
}
