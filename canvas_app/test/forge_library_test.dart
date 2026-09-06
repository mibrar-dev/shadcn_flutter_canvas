/// Forge Library (Track Y3) tests: tile anatomy, tap-to-add through the DnD
/// creation path, search-filter parity, section collapse, and the unchanged
/// DnD payload contract.
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): the panel column overflows the default
/// 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The live tile's "+ Add" button for [kind] (see the `forge-add-<kind>`
/// key format documented on the Library tile).
Finder _addButton(String kind) => find.byKey(ValueKey('forge-add-$kind'));

/// Visible tile count: every registry kind minus the hidden utilities.
int _expectedTileCount() => kRegistry.length - kHiddenUtilityKinds.length;

Future<void> _pumpLibrary(
  WidgetTester tester, {
  CanvasStore? store,
  String screenId = 's1',
  ValueChanged<String>? onNodeAdded,
  VoidCallback? onCollapse,
}) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PartsPalette(
          store: store,
          screenId: screenId,
          onNodeAdded: onNodeAdded,
          onCollapse: onCollapse,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('tile anatomy: chip glyph + name + desc + dashed Add', (
    tester,
  ) async {
    await _pumpLibrary(tester, store: CanvasStore());

    // Name (humanized kind), one line.
    expect(find.text('Button'), findsOneWidget);
    // One-line manifest desc.
    expect(find.textContaining('Shadcn-style button'), findsOneWidget);
    // Icon chip glyph (unique to the button entry).
    expect(find.byIcon(Icons.smart_button), findsOneWidget);
    // Dashed "+ Add" button, one per visible tile.
    expect(_addButton('button'), findsOneWidget);
    expect(find.text('+ Add'), findsNWidgets(_expectedTileCount()));
  });

  testWidgets("'+ Add' appends the tapped kind with catalog defaults", (
    tester,
  ) async {
    final store = CanvasStore();
    String? added;
    await _pumpLibrary(tester, store: store, onNodeAdded: (id) => added = id);

    await tester.ensureVisible(_addButton('button'));
    await tester.tap(_addButton('button'));
    await tester.pump();

    expect(store.doc.nodes, hasLength(1));
    final node = store.doc.nodes.single;
    expect(node.screenId, 's1');
    expect(node.items, hasLength(1));
    expect(node.items.single.kind, 'button');
    expect(node.items.single.props, findEntry('button')!.defaults);
    expect(added, node.id);
    expect(store.canUndo, isTrue);

    // A second tap appends after the first (doc order grows).
    await tester.ensureVisible(_addButton('button'));
    await tester.tap(_addButton('button'));
    await tester.pump();
    expect(store.doc.nodes, hasLength(2));
    expect(store.doc.nodes.last.items.single.kind, 'button');
  });

  testWidgets("'+ Add' on Row takes the row creation branch", (tester) async {
    final store = CanvasStore();
    await _pumpLibrary(tester, store: store);

    await tester.ensureVisible(_addButton('row'));
    await tester.tap(_addButton('row'));
    await tester.pump();

    expect(store.doc.nodes, hasLength(1));
    final node = store.doc.nodes.single;
    expect(node.screenId, 's1');
    expect(node.isRow, isTrue);
    expect(node.items, isEmpty);
  });

  testWidgets('tap-to-add appends after dropped nodes (same path)', (
    tester,
  ) async {
    final store = CanvasStore();
    // Seed via the DnD path directly, then tap-add through the tile.
    DesignCanvas(store: store).onAccept('badge', const Offset(16, 96));
    await _pumpLibrary(tester, store: store);

    await tester.ensureVisible(_addButton('button'));
    await tester.tap(_addButton('button'));
    await tester.pump();

    expect(
      [for (final n in store.doc.nodes) n.items.single.kind],
      ['badge', 'button'],
    );
  });

  testWidgets("'+ Add' disables without a store (Y6 wires it)", (tester) async {
    await _pumpLibrary(tester);

    final button = tester.widget<shadcn.GhostButton>(_addButton('button'));
    expect(button.onPressed, isNull);
  });

  testWidgets('search filters tiles identically (word-start)', (tester) async {
    await _pumpLibrary(tester, store: CanvasStore());

    // Forge header copy.
    expect(find.text('WIDGETS · FLUTTER'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);

    await tester.enterText(find.byType(shadcn.TextField), 'but');
    await tester.pump();
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Card'), findsNothing);

    await tester.enterText(
      find.byType(shadcn.TextField),
      'zzz-no-such-part',
    );
    await tester.pump();
    expect(find.text('No parts match'), findsOneWidget);
  });

  testWidgets('sections collapse and expand', (tester) async {
    await _pumpLibrary(tester, store: CanvasStore());

    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Row'), findsOneWidget);

    await tester.ensureVisible(find.text('Controls'));
    await tester.tap(find.text('Controls'));
    await tester.pump();
    expect(find.text('Button'), findsNothing);
    // Other sections are unaffected.
    expect(find.text('Row'), findsOneWidget);

    await tester.tap(find.text('Controls'));
    await tester.pump();
    expect(find.text('Button'), findsOneWidget);
  });

  testWidgets('DnD payloads unchanged: one Draggable per kind', (tester) async {
    await _pumpLibrary(tester, store: CanvasStore());

    final draggables = tester.widgetList<Draggable<String>>(
      find.byType(Draggable<String>),
    );
    expect(draggables.length, _expectedTileCount());
    final kinds = {for (final d in draggables) d.data};
    final visible = {
      for (final section in kRegistrySectionOrder)
        ...registrySectionEntries(section).map((e) => e.kind),
    };
    expect(kinds, visible);
  });
}
