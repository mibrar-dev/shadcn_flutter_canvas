import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Reference viewport (HANDOFF §2): the phone frame is 343x725 and
  /// overflows the default 800x600 test surface.
  void useReferenceViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('guidesForPointer / snapDropPosition (pure)', () {
    CanvasNode nodeAt(double x, double y) => CanvasNode(
          id: 'n1',
          screenId: 's1',
          x: x,
          y: y,
          items: const [],
        );

    test('node axes win over screen center; X and Y independent', () {
      // Screen center is (164, 354.5); park a node almost on top of it so
      // both a node axis and the center axis are within the threshold.
      final nodes = [nodeAt(160, 350)];
      final guides = guidesForPointer(const Offset(162, 356), nodes);
      // dx=162: node 160 (dist 2) beats center 164 (dist 2) by preference.
      expect(guides.x, 160.0);
      // dy=356: node 350 (dist 6) beats center 354.5 (dist 1.5) by preference.
      expect(guides.y, 350.0);
    });

    test('threshold boundary: 8.0 snaps, beyond does not', () {
      final nodes = [nodeAt(100, 100)];
      expect(guidesForPointer(const Offset(108, 500), nodes).x, 100.0);
      expect(guidesForPointer(const Offset(108.5, 500), nodes).x, isNull);
      // snapDropPosition forwards the snapped axis and keeps the rest exact.
      expect(
        snapDropPosition(const Offset(108, 500), nodes),
        const Offset(100, 500),
      );
      expect(
        snapDropPosition(const Offset(250, 500), nodes),
        const Offset(250, 500),
      );
    });
  });

  group('drag aids on canvas (widget)', () {
    /// Pumps a palette tile above a [DesignCanvas]; returns the canvas so
    /// tests can seed nodes exactly via the unsnapped `onAccept`.
    Future<({DesignCanvas canvas, CanvasStore store})> pumpEditor(
      WidgetTester tester,
    ) async {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Draggable<String>(
                  data: 'button',
                  feedback: Material(child: Text('dragging')),
                  child: SizedBox(width: 100, height: 40, child: Text('tile')),
                ),
                Expanded(child: canvas),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (canvas: canvas, store: store);
    }

    /// Starts a tile drag with a grab point deliberately off the tile corner
    /// (mirrors dnd_offset_test) and returns the gesture plus the drop
    /// target box for screen-local → global conversion.
    Future<({TestGesture gesture, RenderBox targetBox})> startTileDrag(
      WidgetTester tester,
    ) async {
      final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
      final gesture =
          await tester.startGesture(tileTopLeft + const Offset(80, 30));
      await tester.pump();
      final box =
          tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
      return (gesture: gesture, targetBox: box);
    }

    testWidgets('hover near a node edge shows a guide, far away shows none',
        (tester) async {
      useReferenceViewport(tester);
      final editor = await pumpEditor(tester);
      // Seed one node exactly (`onAccept` is unsnapped by contract).
      editor.canvas.onAccept('button', const Offset(100, 100));
      await tester.pumpAndSettle();

      final drag = await startTileDrag(tester);
      // Hover NEAR the node's left edge (within kSnapThreshold) but far
      // from every horizontal axis: vertical guide only.
      await drag.gesture
          .moveTo(drag.targetBox.localToGlobal(const Offset(104, 300)));
      await tester.pump();
      expect(find.byKey(kDragGuideVerticalKey), findsOneWidget);
      expect(find.byKey(kDragGuideHorizontalKey), findsNothing);

      // Hover far from every axis: no guides.
      await drag.gesture
          .moveTo(drag.targetBox.localToGlobal(const Offset(250, 500)));
      await tester.pump();
      expect(find.byKey(kDragGuideVerticalKey), findsNothing);
      expect(find.byKey(kDragGuideHorizontalKey), findsNothing);

      // Cancel: nothing added, guides stay gone.
      await drag.gesture.cancel();
      await tester.pumpAndSettle();
      expect(editor.store.doc.nodes, hasLength(1));
      expect(find.byKey(kDragGuideVerticalKey), findsNothing);
      expect(find.byKey(kDragGuideHorizontalKey), findsNothing);
    });

    testWidgets('drop within threshold snaps onto the node edge',
        (tester) async {
      useReferenceViewport(tester);
      final editor = await pumpEditor(tester);
      editor.canvas.onAccept('button', const Offset(100, 100));
      await tester.pumpAndSettle();

      final drag = await startTileDrag(tester);
      // Pointer 3px right of the node edge: within the threshold on X, far
      // from every axis on Y.
      await drag.gesture
          .moveTo(drag.targetBox.localToGlobal(const Offset(103, 200)));
      await tester.pump();
      expect(find.byKey(kDragGuideVerticalKey), findsOneWidget);
      await drag.gesture.up();
      await tester.pumpAndSettle();

      expect(editor.store.doc.nodes, hasLength(2));
      final node = editor.store.doc.nodes.last;
      expect(node.x, 100.0);
      expect(node.y, moreOrLessEquals(200, epsilon: 1.0));
      // Guides vanish on drop.
      expect(find.byKey(kDragGuideVerticalKey), findsNothing);
      expect(find.byKey(kDragGuideHorizontalKey), findsNothing);
    });

    testWidgets('drop on empty screen far from axes lands exact',
        (tester) async {
      useReferenceViewport(tester);
      final editor = await pumpEditor(tester);

      final drag = await startTileDrag(tester);
      const want = Offset(50, 60);
      await drag.gesture.moveTo(drag.targetBox.localToGlobal(want));
      await tester.pump();
      expect(find.byKey(kDragGuideVerticalKey), findsNothing);
      expect(find.byKey(kDragGuideHorizontalKey), findsNothing);
      await drag.gesture.up();
      await tester.pumpAndSettle();

      expect(editor.store.doc.nodes, hasLength(1));
      final node = editor.store.doc.nodes.single;
      expect(node.x, moreOrLessEquals(want.dx, epsilon: 1.0));
      expect(node.y, moreOrLessEquals(want.dy, epsilon: 1.0));
    });
  });
}
