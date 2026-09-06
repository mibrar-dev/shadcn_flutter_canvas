/// Track U2 inspector: W/H numeric editors write through `setNodeSize` and
/// the Auto affordance clears back to auto — for row containers (Layout
/// group) and for leaves (Size card).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  await tester.pump();
}

void main() {
  group('row Layout W/H editors', () {
    testWidgets('steppers set, step, and clear to auto', (tester) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      await _pumpInspector(tester, store, nodeId: rowId);

      // Both dims start auto.
      expect(find.text('Width'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Auto'), findsNWidgets(2));

      // Step width up from auto: starts at the documented fallback.
      await tester.tap(find.byKey(const ValueKey('node-width-inc')));
      await tester.pump();
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        160.0,
      );
      // Step again: +8.
      await tester.tap(find.byKey(const ValueKey('node-width-inc')));
      await tester.pump();
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        168.0,
      );
      // Clear back to auto via the Auto affordance.
      await tester.tap(find.byKey(const ValueKey('node-width-auto')));
      await tester.pump();
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        isNull,
      );

      // Height stepper writes h independently.
      await tester.tap(find.byKey(const ValueKey('node-height-inc')));
      await tester.pump();
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).h,
        160.0,
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        isNull,
      );
    });

    testWidgets('decrement clamps at the floor and undo restores auto', (
      tester,
    ) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      store.setNodeSize(rowId, w: 50);
      await _pumpInspector(tester, store, nodeId: rowId);

      await tester.tap(find.byKey(const ValueKey('node-width-dec')));
      await tester.pump();
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        kMinNodeSize,
      );
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        50.0,
      );
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        isNull,
      );
    });
  });

  group('leaf Size card', () {
    testWidgets('W/H editors write through and clear', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [
          CanvasItem(id: 'i1', kind: 'button', props: {'label': 'Go'}),
        ],
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      expect(find.text('Size'), findsOneWidget);
      Future<void> tapSizeKey(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pump();
      }

      await tapSizeKey('node-width-inc');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).w,
        160.0,
      );
      await tapSizeKey('node-height-inc');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).h,
        160.0,
      );
      await tapSizeKey('node-width-auto');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).w,
        isNull,
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).h,
        160.0,
      );
    });
  });

  // Track X2 size presets: Fill clears, Half/Third compute from the node's
  // screen device width, unknown screens disable with a reason. Extends the
  // Track U2 stepper suite above (no existing cases rewritten).
  group('size presets (Track X2)', () {
    Future<void> tapPresetKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump();
    }

    testWidgets('Half/Third compute from phone width, Fill clears', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [
          CanvasItem(id: 'i1', kind: 'button', props: {'label': 'Go'}),
        ],
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      // Default screen s1 has no device (phone 390).
      await tapPresetKey(tester, 'node-width-half');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).w,
        195.0,
      );
      await tapPresetKey(tester, 'node-width-third');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).w,
        130.0,
      );
      await tapPresetKey(tester, 'node-width-fill');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).w,
        isNull,
      );

      // Height Fill clears h.
      store.setNodeSize(nodeId, h: 200);
      await tester.pump();
      await tapPresetKey(tester, 'node-height-fill');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).h,
        isNull,
      );
    });

    testWidgets('Half computes from tablet device width', (tester) async {
      final store = CanvasStore();
      store.setScreenDevice('s1', 'tablet');
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [
          CanvasItem(id: 'i1', kind: 'button', props: {'label': 'Go'}),
        ],
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      await tapPresetKey(tester, 'node-width-half');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == nodeId).w,
        384.0,
      );
    });

    testWidgets('row Layout presets share the same Half rule', (
      tester,
    ) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      await _pumpInspector(tester, store, nodeId: rowId);

      await tapPresetKey(tester, 'node-width-half');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).w,
        195.0,
      );
    });

    testWidgets('disabled with reason on unknown screen', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 'missing',
        x: 0,
        y: 0,
        items: const [
          CanvasItem(id: 'i1', kind: 'button', props: {'label': 'Go'}),
        ],
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      expect(
        find.byKey(const ValueKey('node-size-preset-reason')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<shadcn.OutlineButton>(
              find.byKey(const ValueKey('node-width-half')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<shadcn.OutlineButton>(
              find.byKey(const ValueKey('node-width-fill')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<shadcn.OutlineButton>(
              find.byKey(const ValueKey('node-height-fill')),
            )
            .onPressed,
        isNull,
      );
    });
  });
}
