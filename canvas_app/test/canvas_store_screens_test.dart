import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/phone_frame.dart';
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

ScreenDoc _twoScreenDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's9', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Checkout', 'brief': '2-screen pay flow'},
    });

/// Drag anchor that pins the feedback's top-left corner to the pointer, so
/// a simulated drop's global point is exactly the gesture point.
Offset _pointerAnchor(
        Draggable<Object> draggable, BuildContext context, Offset position) =>
    Offset.zero;

void main() {
  test('addScreen appends a default-named screen and returns its id', () {
    final store = CanvasStore(prefs: FakePrefs());
    expect(store.doc.screens, hasLength(1));
    final id = store.addScreen();
    expect(id, isNotEmpty);
    expect(store.doc.screens, hasLength(2));
    final added = store.doc.screens.last;
    expect(added.id, id);
    expect(added.name, 'Screen 2');
    expect(added.bg, 'surface');
    expect(store.doc.screens.map((s) => s.id).toSet(), hasLength(2));
  });

  test('addScreen honors an explicit name', () {
    final store = CanvasStore(prefs: FakePrefs());
    final id = store.addScreen(name: 'Onboarding');
    expect(store.doc.screens.singleWhere((s) => s.id == id).name,
        'Onboarding');
  });

  test('addScreen is undoable and redoable', () {
    final store = CanvasStore(prefs: FakePrefs());
    store.addScreen();
    expect(store.doc.screens, hasLength(2));
    expect(store.undo(), isTrue);
    expect(store.doc.screens, hasLength(1));
    expect(store.redo(), isTrue);
    expect(store.doc.screens, hasLength(2));
  });

  test('renameScreen renames and throws StateError on unknown id', () {
    final store = CanvasStore(prefs: FakePrefs());
    store.renameScreen('s1', 'Home');
    expect(store.doc.screens.single.name, 'Home');
    expect(store.undo(), isTrue);
    expect(store.doc.screens.single.name, 'Screen 1');
    expect(() => store.renameScreen('nope', 'X'), throwsStateError);
  });

  test('replaceDoc commits verbatim and is undoable', () {
    final store = CanvasStore(prefs: FakePrefs());
    store.replaceDoc(_twoScreenDoc());
    expect(store.doc.screens.map((s) => s.id), ['s1', 's9']);
    expect(store.doc.screens[1].name, 'Done');
    expect(store.undo(), isTrue);
    expect(store.doc.screens.map((s) => s.id), ['s1']);
  });

  test('onAccept defaults to widget.screenId, honors explicit screenId', () {
    final store = CanvasStore(prefs: FakePrefs(), initial: _twoScreenDoc());
    final canvas = DesignCanvas(store: store);
    final first = canvas.onAccept('button', const Offset(5, 6));
    expect(
      store.doc.nodes.singleWhere((n) => n.id == first).screenId,
      's1',
    );
    final second =
        canvas.onAccept('button', const Offset(7, 8), screenId: 's9');
    final node = store.doc.nodes.singleWhere((n) => n.id == second);
    expect(node.screenId, 's9');
    expect(node.x, 7);
    expect(node.y, 8);
  });

  testWidgets('renders every screen side by side with its label', (tester) async {
    // Wide viewport so both phones fit without a debug overflow.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = CanvasStore(prefs: FakePrefs(), initial: _twoScreenDoc());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DesignCanvas(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byType(ScreenSurface), findsNWidgets(2));
  });

  testWidgets('drop at zoom 2.0 lands at unscaled screen coords',
      (tester) async {
    // Oversized viewport so the 2x-scaled phone (686x1450+) stays fully
    // on-screen and the drop point remains hittable.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = CanvasStore(prefs: FakePrefs());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Draggable<String>(
                data: 'button',
                // Pin the feedback's top-left corner to the pointer so the
                // drop's global point is exactly the gesture point (the
                // default child-anchored strategy would offset it by the grab
                // point inside the tile and blur the zoom question).
                dragAnchorStrategy: _pointerAnchor,
                feedback: Material(child: Text('dragging')),
                child: SizedBox(width: 100, height: 40, child: Text('tile')),
              ),
              Expanded(child: DesignCanvas(store: store, zoom: 2.0)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Aim at inner-screen point (50, 60): take the inner DragTarget box and
    // convert to global coords, exactly as a real pointer drop would arrive.
    final box =
        tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
    const want = Offset(50, 60);
    final global = box.localToGlobal(want);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('tile')));
    await gesture.moveTo(global);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.doc.nodes, hasLength(1));
    final node = store.doc.nodes.single;
    expect(node.screenId, 's1');
    // Pass-through holds: globalToLocal already inverts the 2x viewport
    // scale, so the node lands at the aimed unscaled point. Dividing by the
    // zoom again would land it near (21, 26) instead.
    expect(node.x, moreOrLessEquals(want.dx, epsilon: 0.5));
    expect(node.y, moreOrLessEquals(want.dy, epsilon: 0.5));
  });
}
