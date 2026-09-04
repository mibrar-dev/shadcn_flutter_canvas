import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('empty screen shows header plus Empty note', (tester) async {
    final store = CanvasStore();
    await tester.pumpWidget(_harness(store: store));

    expect(find.text('Screen 1'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('rows list frontmost first with kind label and id suffix',
      (tester) async {
    final store = CanvasStore();
    final first = _addButton(store);
    final second = _addButton(store);
    await tester.pumpWidget(_harness(store: store));
    await tester.pump();

    // Reversed doc order: second (frontmost) row appears before first.
    final secondY = tester.getTopLeft(find.textContaining(second)).dy;
    final firstY = tester.getTopLeft(find.textContaining(first)).dy;
    expect(secondY, lessThan(firstY));
    expect(find.textContaining('Button'), findsNWidgets(2));
  });

  testWidgets('tap row selects, duplicate copies, delete removes',
      (tester) async {
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
  });
}
