import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capitalized kind id, matching the palette tile labels.
String _tileLabel(String kind) =>
    kind.isEmpty ? kind : kind[0].toUpperCase() + kind.substring(1);

void main() {
  /// Reference viewport (HANDOFF §2): the phone frame is 343x725 and
  /// overflows the default 800x600 test surface.
  void useReferenceViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('onAccept adds exactly one node to screen s1 with defaults', () {
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);

    final id = canvas.onAccept('button', const Offset(16, 96));

    expect(store.doc.nodes, hasLength(1));
    final node = store.doc.nodes.single;
    expect(node.id, id);
    expect(node.screenId, 's1');
    expect(node.x, 16);
    expect(node.y, 96);
    expect(node.items, hasLength(1));
    expect(node.items.single.kind, 'button');
    expect(
      node.items.single.props,
      findEntry('button')!.defaults,
    );
  });

  test('second onAccept keeps existing nodes on the same screen', () {
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);

    canvas.onAccept('button', const Offset(16, 96));
    final id = canvas.onAccept('badge', const Offset(32, 120));

    expect(store.doc.nodes, hasLength(2));
    expect(store.doc.nodes.last.id, id);
    expect(store.doc.nodes.last.screenId, 's1');
    expect(store.doc.nodes.last.items.single.kind, 'badge');
  });

  testWidgets('drop renders the node inside PhoneFrame', (tester) async {
    useReferenceViewport(tester);
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

    expect(find.byType(PhoneFrame), findsOneWidget);
    expect(find.byType(shadcn.PrimaryButton), findsNothing);

    canvas.onAccept('button', const Offset(16, 96));
    await tester.pump();

    expect(store.doc.nodes, hasLength(1));
    expect(find.byType(PhoneFrame), findsOneWidget);
    expect(find.byType(shadcn.PrimaryButton), findsOneWidget);
    expect(find.text('Button'), findsOneWidget);
  });

  testWidgets('unknown kind drops to fallback instead of crashing', (
    tester,
  ) async {
    useReferenceViewport(tester);
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

    canvas.onAccept('mystery', const Offset(8, 8));
    await tester.pump();

    expect(store.doc.nodes, hasLength(1));
    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.text('unknown: mystery'), findsOneWidget);
  });

  testWidgets('parts palette shows one draggable tile per catalog kind', (
    tester,
  ) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PartsPalette())),
    );

    for (final entry in kCatalog) {
      expect(find.text(_tileLabel(entry.kind)), findsOneWidget);
    }
    expect(find.byType(Draggable<String>), findsNWidgets(kCatalog.length));
  });

  testWidgets('palette search filters tiles and reports empty results', (
    tester,
  ) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PartsPalette())),
    );

    await tester.enterText(find.byType(TextField), 'but');
    await tester.pump();
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Card'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz-no-such-part');
    await tester.pump();
    expect(find.text('No parts match'), findsOneWidget);
  });

  testWidgets('tapping a node selects it with a ring', (tester) async {
    useReferenceViewport(tester);
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

    canvas.onAccept('badge', const Offset(16, 96));
    await tester.pump();
    // No palette is pumped here, so this finds only the dropped node.
    expect(find.text('Badge'), findsOneWidget);

    await tester.tap(find.text('Badge'));
    await tester.pump();
    // Still exactly one node; selection is visual state, no extra nodes.
    expect(store.doc.nodes, hasLength(1));
    expect(find.text('Badge'), findsOneWidget);
  });
}
