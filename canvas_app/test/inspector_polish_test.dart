/// Track I inspector + palette polish tests: group headers for every group,
/// the zero-spec empty state, and spec-only props writing end to end.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/props_schema.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

(String, String) _addItem(CanvasStore store, String kind) {
  const itemId = 'i1';
  final nodeId = store.addNode(
    screenId: 's1',
    x: 0,
    y: 0,
    items: [CanvasItem(id: itemId, kind: kind, props: const {})],
  );
  return (nodeId, itemId);
}

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
  group('inspector group headers', () {
    testWidgets('button shows a header for every group', (tester) async {
      final store = CanvasStore();
      final (nodeId, itemId) = _addItem(store, 'button');
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
    });

    testWidgets('row container shows a Layout header', (tester) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      await _pumpInspector(tester, store, nodeId: rowId);

      expect(find.text('Layout'), findsOneWidget);
    });
  });

  group('inspector empty states', () {
    testWidgets('no selection shows the hint plus guidance', (tester) async {
      await _pumpInspector(tester, CanvasStore());

      expect(
        find.text('Select an item to edit its props'),
        findsOneWidget,
      );
      expect(
        find.text('Click a component on the canvas to edit it.'),
        findsOneWidget,
      );
    });

    testWidgets('zero-spec kind shows No editable properties + hint', (
      tester,
    ) async {
      final store = CanvasStore();
      final (nodeId, itemId) = _addItem(store, 'mystery');
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.text('No editable properties'), findsOneWidget);
      expect(
        find.text('Kind “mystery” has no editable props yet.'),
        findsOneWidget,
      );
      // The node-level Visibility card still renders for zero-spec kinds.
      expect(find.text('Visibility'), findsOneWidget);
    });
  });

  group('spec-only props end to end', () {
    testWidgets('avatar size stepper writes, badges, and resets', (
      tester,
    ) async {
      final store = CanvasStore();
      final (nodeId, itemId) = _addItem(store, 'avatar');
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      Map<String, dynamic> props() => store.doc.nodes
          .singleWhere((n) => n.id == nodeId)
          .items
          .singleWhere((i) => i.id == itemId)
          .props;

      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('modified'), findsNothing);

      await tester.tap(find.text('+'));
      await tester.pump();
      expect(props()['size'], 44.0);
      expect(find.text('modified'), findsOneWidget);

      await tester.tap(find.text('reset'));
      await tester.pump();
      expect(props().containsKey('size'), isFalse);
      expect(
        resolveProp('avatar', 'size', props(), null),
        40.0,
      );
      expect(find.text('modified'), findsNothing);
    });
  });

  group('palette empty state', () {
    testWidgets('empty search shows the improved empty state', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PartsPalette())),
      );

      await tester.enterText(find.byType(TextField), 'zzz-no-such-part');
      await tester.pump();
      expect(find.text('No parts match'), findsOneWidget);
      expect(
        find.text('Try a different search term.'),
        findsOneWidget,
      );
    });
  });
}
