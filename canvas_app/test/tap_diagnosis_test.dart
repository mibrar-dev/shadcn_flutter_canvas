/// Regression tests for the dead canvas-node tap.
///
/// Root cause: each leaf node selected via `GestureDetector.onTap`, but
/// interactive kit content (buttons, switches, inputs, tabs, …) owns its
/// own tap recognizers, which beat the outer detector in the gesture arena
/// — the outer `onTap` never fires. A `Listener.onPointerDown` is
/// arena-exempt and always observes the hit, so selection rides that
/// (see `ScreenSurface._buildLeaf`). The last test pins the underlying
/// framework behavior with bare widgets.
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): the phone frame is 343x725 and
/// overflows the default 800x600 test surface.
void _viewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<String> _pumpLeaf(
  WidgetTester tester,
  String kind,
  Map<String, dynamic> props,
  String label, {
  bool panMode = false,
  required void Function(String?) onSelect,
}) async {
  final store = CanvasStore();
  final canvas = DesignCanvas(
    store: store,
    panMode: panMode,
    onSelectNode: onSelect,
  );
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: canvas)));
  final id = canvas.onAccept(kind, const Offset(16, 96));
  await tester.pump();
  if (label.isNotEmpty) expect(find.text(label), findsOneWidget);
  return id;
}

/// Doc with a row container holding two children plus one root leaf.
ScreenDoc _rowDoc() => ScreenDoc.fromJson({
  'screens': [
    {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
  ],
  'nodes': [
    {
      'id': 'r1',
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'items': [],
      'parentId': null,
      'isRow': true,
      'gap': 8.0,
    },
    {
      'id': 'c1',
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'items': [
        {'id': 'ic1', 'kind': 'button', 'label': 'C1'},
      ],
      'parentId': 'r1',
      'isRow': false,
      'gap': 8.0,
    },
    {
      'id': 'r2',
      'screenId': 's1',
      'x': 0.0,
      'y': 200.0,
      'items': [],
      'parentId': null,
      'isRow': true,
      'gap': 8.0,
    },
  ],
  'theme': {
    'paletteKey': 'clean-slate',
    'dark': true,
    'shape': 'rounded',
    'motion': 'standard',
  },
  'meta': {'title': 'Flow', 'brief': ''},
});

void main() {
  testWidgets('tapping a button node selects it', (tester) async {
    _viewport(tester);
    String? selected;
    final id = await _pumpLeaf(
      tester,
      'button',
      const {},
      'Button',
      onSelect: (v) => selected = v,
    );
    await tester.tap(find.text('Button'));
    await tester.pump();
    expect(selected, id);
  });

  testWidgets('tapping a badge node selects it', (tester) async {
    _viewport(tester);
    String? selected;
    final id = await _pumpLeaf(
      tester,
      'badge',
      const {},
      'Badge',
      onSelect: (v) => selected = v,
    );
    await tester.tap(find.text('Badge'));
    await tester.pump();
    expect(selected, id);
  });

  testWidgets('tapping a switch node selects it', (tester) async {
    _viewport(tester);
    String? selected;
    final id = await _pumpLeaf(
      tester,
      'switch',
      const {},
      // The switch renders no label; tap the widget itself.
      '',
      onSelect: (v) => selected = v,
    );
    // _pumpLeaf's label finder does not apply here; tap the switch.
    await tester.tap(find.byType(shadcn.Switch));
    await tester.pump();
    expect(selected, id);
  });

  testWidgets('tapping a button inside a row selects the child, not the row',
      (tester) async {
    _viewport(tester);
    final store = CanvasStore(initial: _rowDoc());
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesignCanvas(
            store: store,
            onSelectNode: (v) => selected = v,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('C1'));
    await tester.pump();
    expect(selected, 'c1');
  });

  testWidgets('tapping an empty row selects the row', (tester) async {
    _viewport(tester);
    final store = CanvasStore(initial: _rowDoc());
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesignCanvas(
            store: store,
            onSelectNode: (v) => selected = v,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Drop here'));
    await tester.pump();
    expect(selected, 'r2');
  });

  testWidgets('pan mode: tapping a node does not select', (tester) async {
    _viewport(tester);
    String? selected;
    await _pumpLeaf(
      tester,
      'button',
      const {},
      'Button',
      panMode: true,
      onSelect: (v) => selected = v,
    );
    await tester.tap(find.text('Button'));
    await tester.pump();
    expect(selected, isNull);
  });

  testWidgets('inner tap suppresses outer onTap but not Listener',
      (tester) async {
    _viewport(tester);
    var outerTap = 0;
    var listenerDown = 0;
    var innerTap = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => outerTap++,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => listenerDown++,
              child: Container(
                width: 200,
                height: 100,
                alignment: Alignment.center,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => innerTap++,
                  child: Container(
                    width: 120,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Text('Inner'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inner'));
    await tester.pump();
    // The arena gives the tap to the inner detector only, while the
    // arena-exempt listener still observes the pointer down.
    expect(innerTap, 1);
    expect(outerTap, 0);
    expect(listenerDown, 1);
  });
}
