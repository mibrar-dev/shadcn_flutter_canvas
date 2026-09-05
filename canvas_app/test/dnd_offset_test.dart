import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePrefs implements PrefsPort {
  final writes = <String, String>{};
  @override
  Future<String?> read(String key) async => writes[key];
  @override
  Future<void> write(String key, String value) async {
    writes[key] = value;
  }
}

void main() {
  testWidgets('drop lands at pointer, not feedback corner', (tester) async {
    // 1440x900 viewport per repo convention.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = CanvasStore(prefs: _FakePrefs());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // Default child-anchored strategy: the drop's details.offset is
              // the feedback top-left (pointer minus grab offset), not the
              // pointer itself.
              const Draggable<String>(
                data: 'button',
                feedback: Material(child: Text('dragging')),
                child: SizedBox(width: 100, height: 40, child: Text('tile')),
              ),
              Expanded(child: DesignCanvas(store: store)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Aim the POINTER at inner-screen point (50, 60).
    final box =
        tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
    const want = Offset(50, 60);
    final global = box.localToGlobal(want);

    // Grab deliberately off the tile corner so the feedback corner and the
    // pointer differ by a large, assertion-visible margin.
    final tileTopLeft =
        tester.getTopLeft(find.byType(Draggable<String>));
    const grabInsideTile = Offset(80, 30);
    final grab = tileTopLeft + grabInsideTile;

    final gesture = await tester.startGesture(grab);
    await gesture.moveTo(global);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.doc.nodes, hasLength(1));
    final node = store.doc.nodes.single;
    // Pointer location within 1px.
    expect(node.x, moreOrLessEquals(want.dx, epsilon: 1.0));
    expect(node.y, moreOrLessEquals(want.dy, epsilon: 1.0));
  });
}
