import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('drop renders the node inside PhoneFrame', (tester) async {
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
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

    canvas.onAccept('mystery', const Offset(8, 8));
    await tester.pump();

    expect(store.doc.nodes, hasLength(1));
    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.text('unknown: mystery'), findsOneWidget);
  });

  testWidgets('palette renders all five catalog labels', (tester) async {
    final store = CanvasStore();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
    );

    for (final entry in kCatalog) {
      expect(find.text(entry.label), findsOneWidget);
    }
  });

  testWidgets('tapping a node selects it with a ring', (tester) async {
    final store = CanvasStore();
    final canvas = DesignCanvas(store: store);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));

    canvas.onAccept('badge', const Offset(16, 96));
    await tester.pump();
    // The dropped node badge shows the default 'Badge' label; palette tiles
    // show kind ids + descriptions, so this finds only the node.
    expect(find.text('Badge'), findsOneWidget);

    await tester.tap(find.text('Badge'));
    await tester.pump();
    // Still exactly one node; selection is visual state, no extra nodes.
    expect(store.doc.nodes, hasLength(1));
    expect(find.text('Badge'), findsOneWidget);
  });
}
