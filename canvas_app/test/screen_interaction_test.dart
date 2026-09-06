/// Track H (canvas interaction): screen selection, delete semantics,
/// per-screen device mode, and viewport transform math.
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart' show kForgeSelectionToolbarKey;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/forge_canvas_header.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Reference viewport (HANDOFF §2): the shell and phone frames overflow the
/// default 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Canvas screen tap target (Y4, FORGE.md §1-3g: the ScreenLabel row is
/// dropped — names move to the Forge header breadcrumb at the Y6 cutover —
/// so select a screen by tapping its empty screen area, the same
/// `onSelectScreen` path the label used).
Future<void> _tapPhoneCenter(WidgetTester tester, int at) async {
  await tester.tapAt(tester.getCenter(find.byType(PhoneFrame).at(at)));
}

void main() {
  group('CanvasStore.deleteScreen', () {
    test('success removes the screen and its nodes, undo restores', () {
      final store = CanvasStore(initial: _twoScreenDoc());
      final nodeId = store.addNode(screenId: 's9', x: 0, y: 0);
      expect(store.doc.screens.map((s) => s.id), ['s1', 's9']);

      expect(store.deleteScreen('s9'), isEmpty);
      expect(store.doc.screens.map((s) => s.id), ['s1']);
      expect(store.doc.nodes.any((n) => n.id == nodeId), isFalse);

      expect(store.undo(), isTrue);
      expect(store.doc.screens.map((s) => s.id), ['s1', 's9']);
      expect(store.doc.nodes.any((n) => n.id == nodeId), isTrue);
    });

    test('dangling guard refuses without committing', () {
      final store = CanvasStore(initial: _twoScreenDoc());
      store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: store.uid(),
            kind: 'button',
            action: const NodeAction(to: 's9', transition: 'push'),
          ),
        ],
      );

      final dangling = store.deleteScreen('s9');
      expect(dangling, isNotEmpty);
      expect(dangling.single, contains('s9'));
      expect(store.doc.screens, hasLength(2));
      // The refusal committed nothing: one undo pops the node setup and
      // history is then empty.
      expect(store.undo(), isTrue);
      expect(store.doc.nodes, isEmpty);
      expect(store.canUndo, isFalse);
    });
  });

  group('CanvasStore.setScreenDevice', () {
    test('persists and undo restores, preserving other fields', () {
      final store = CanvasStore(initial: _twoScreenDoc());
      store.setScreenDevice('s1', 'tablet');
      final screen = store.doc.screens.singleWhere((s) => s.id == 's1');
      expect(screen.device, 'tablet');
      expect(screen.name, 'Pay');

      expect(store.undo(), isTrue);
      expect(
        store.doc.screens.singleWhere((s) => s.id == 's1').device,
        isNull,
      );
      expect(store.redo(), isTrue);
      expect(
        store.doc.screens.singleWhere((s) => s.id == 's1').device,
        'tablet',
      );
    });

    test('unknown device throws, unknown screen and same value are no-ops',
        () {
      final store = CanvasStore(initial: _twoScreenDoc());
      expect(
        () => store.setScreenDevice('s1', 'watch'),
        throwsArgumentError,
      );
      store.setScreenDevice('ghost', 'tablet');
      expect(store.canUndo, isFalse);
      // Already null: setting null commits nothing.
      store.setScreenDevice('s1', null);
      expect(store.canUndo, isFalse);
    });

    test('old JSON without device loads null; toJson omits null', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Old', 'x': 0, 'y': 0, 'bg': 'surface'},
        ],
        'nodes': [],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard'
        },
        'meta': {'title': 'T', 'brief': ''},
      });
      expect(doc.screens.single.device, isNull);
      final json = doc.screens.single.toJson();
      expect(json.containsKey('device'), isFalse);

      const withDevice = CanvasScreen(
        id: 's1',
        name: 'New',
        x: 0,
        y: 0,
        bg: 'surface',
        device: 'desktop-wide',
      );
      expect(withDevice.toJson()['device'], 'desktop-wide');
      expect(
        CanvasScreen.fromJson(withDevice.toJson()).device,
        'desktop-wide',
      );
    });

    test('renameScreen preserves the device', () {
      final store = CanvasStore(initial: _twoScreenDoc());
      store.setScreenDevice('s1', 'tablet');
      store.renameScreen('s1', 'Pay v2');
      final screen = store.doc.screens.singleWhere((s) => s.id == 's1');
      expect(screen.name, 'Pay v2');
      expect(screen.device, 'tablet');
    });
  });

  group('specForScreenDevice', () {
    test('null and unknown fall back to phone', () {
      expect(specForScreenDevice(null).id, 'phone');
      expect(specForScreenDevice('watch').id, 'phone');
      expect(specForScreenDevice('tablet').width, 768);
      expect(specForScreenDevice('desktop-wide').width, 1440);
    });

    test('screenOuterWidth tracks the device stage width', () {
      const phone = CanvasScreen(
        id: 's1',
        name: 'P',
        x: 0,
        y: 0,
        bg: 'surface',
      );
      expect(screenOuterWidth(phone), 390 + 7.5 * 2);
      const tablet = CanvasScreen(
        id: 's2',
        name: 'T',
        x: 0,
        y: 0,
        bg: 'surface',
        device: 'tablet',
      );
      expect(screenOuterWidth(tablet), 768 + 7.5 * 2);
    });
  });

  group('viewport transform math (pure)', () {
    test('clampZoom pins to 0.25–4.0', () {
      expect(clampZoom(0.1), 0.25);
      expect(clampZoom(5.0), 4.0);
      expect(clampZoom(1.0), 1.0);
      expect(clampZoom(0.25), 0.25);
      expect(clampZoom(4.0), 4.0);
    });

    test('wheel pans vertically; Shift+wheel pans horizontally', () {
      const pan = Offset(10, 20);
      expect(
        applyWheelPan(pan, const Offset(0, 100), shift: false),
        const Offset(10, -80),
      );
      expect(
        applyWheelPan(pan, const Offset(0, 100), shift: true),
        const Offset(-90, 20),
      );
      expect(
        applyMiddlePan(const Offset(5, 5), const Offset(3, -2)),
        const Offset(8, 3),
      );
    });

    test('wheel factor zooms in on scroll-up, out on scroll-down', () {
      expect(wheelZoomFactor(-100), greaterThan(1.0));
      expect(wheelZoomFactor(100), lessThan(1.0));
      expect(wheelZoomFactor(0), 1.0);
    });

    test('zoomAtCursor keeps the content point under the cursor', () {
      const viewport = Size(800, 600);
      const content = Size(400, 725);
      const cursor = Offset(400, 300);
      final result = zoomAtCursor(
        zoom: 1.0,
        pan: Offset.zero,
        cursor: cursor,
        viewport: viewport,
        contentSize: content,
        factor: 2.0,
      );
      expect(result.zoom, 2.0);
      Offset origin(double z) => Offset(
            (viewport.width - content.width * z) / 2,
            (viewport.height - content.height * z) / 2,
          );
      final before = (cursor - origin(1.0)) / 1.0;
      final after = (cursor - origin(result.zoom) - result.pan) / result.zoom;
      expect(after.dx, moreOrLessEquals(before.dx));
      expect(after.dy, moreOrLessEquals(before.dy));
    });

    test('zoomAtCursor clamps while keeping the anchor', () {
      const viewport = Size(800, 600);
      const content = Size(400, 725);
      const cursor = Offset(100, 100);
      final result = zoomAtCursor(
        zoom: 1.0,
        pan: Offset.zero,
        cursor: cursor,
        viewport: viewport,
        contentSize: content,
        factor: 100.0,
      );
      expect(result.zoom, kCanvasMaxZoom);
      Offset origin(double z) => Offset(
            (viewport.width - content.width * z) / 2,
            (viewport.height - content.height * z) / 2,
          );
      final before = (cursor - origin(1.0)) / 1.0;
      final after =
          (cursor - origin(result.zoom) - result.pan) / result.zoom;
      expect(after.dx, moreOrLessEquals(before.dx));
      expect(after.dy, moreOrLessEquals(before.dy));
    });
  });

  group('screen selection (widget)', () {
    testWidgets('tapping empty screen area selects the screen with a ring',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesignCanvas(
              store: store,
              onSelectScreen: (id) => selected = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(screenSelectedKey('s1')), findsNothing);

      // Y4 (FORGE.md §1-3g): the label is gone — the second phone's empty
      // screen area (the 'Drag a part here' placeholder) drives the same
      // `onSelectScreen` path.
      await _tapPhoneCenter(tester, 1);
      await tester.pump();
      expect(selected, 's9');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesignCanvas(
              store: store,
              selectedScreenId: 's9',
              onSelectScreen: (id) => selected = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(screenSelectedKey('s9')), findsOneWidget);
      expect(find.byKey(screenSelectedKey('s1')), findsNothing);
    });

    testWidgets('header device strip switches the screen device',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      // Y4 (FORGE.md §1-3g): the canvas device row moved into the Forge
      // header as a compact strip over the same specs/contract — drive it
      // there, wired to the untouched `setScreenDevice` store path.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeCanvasHeader(
              projectTitle: 'Checkout',
              screenId: 's1',
              screenName: 'Pay',
              zoom: 1.0,
              onZoomIn: () {},
              onZoomOut: () {},
              onFit: () {},
              screenDevice: store.doc.screens.first.device,
              onDeviceChanged: (device) =>
                  store.setScreenDevice('s1', device),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.doc.screens.first.device, isNull);

      // Per-screen device tips are kit tooltips: tap the tablet glyph
      // directly.
      await tester.tap(find.byIcon(Icons.tablet_mac).first);
      await tester.pumpAndSettle();
      expect(store.doc.screens.first.device, 'tablet');

      // The frame + undo contracts are unchanged: verify them store-side
      // with the canvas rendering the tablet stage.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(PhoneFrame).first).width,
        moreOrLessEquals(768 + 7.5 * 2),
      );

      expect(store.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(store.doc.screens.first.device, isNull);
    });

    testWidgets('tablet-width screens hide tablet-hidden nodes live',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: canvas)),
      );
      final id = canvas.onAccept('button', const Offset(0, 10));
      store.setNodeResponsive(id, hiddenOn: {'tablet'});
      await tester.pumpAndSettle();
      // Phone-width stage (390 → mobile): visible.
      expect(find.text('Button'), findsOneWidget);

      store.setScreenDevice('s1', 'tablet');
      await tester.pumpAndSettle();
      // Tablet-width stage (768 → tablet): hidden.
      expect(find.text('Button'), findsNothing);
    });
  });

  // Y6 cutover (FORGE.md §1-3f, §1-4e): the old always-visible toolbar + its
  // trash are removed; node deletes go through the inspector Delete row and
  // screen deletes through the topbar active-tab ×. Intent preserved: shell
  // delete semantics (node-set delete, screen delete, dangling refusal).
  group('forge delete semantics (shell)', () {
    testWidgets('nothing selected: selection toolbar hidden, doc untouched',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      store.addNode(screenId: 's1', x: 0, y: 0);
      await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
      await tester.pumpAndSettle();

      // No selection → the black Forge toolbar hides (it returns shrink).
      expect(find.byKey(kForgeSelectionToolbarKey), findsNothing);
      expect(store.doc.nodes, hasLength(1));
      expect(store.doc.screens, hasLength(2));
    });

    testWidgets('selected node deletes via inspector Delete', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      // Custom label: the canvas shows 'PickMe' while the layers row shows
      // the kind-based 'Button · <id>', keeping the tap target unambiguous.
      final entry = findEntry('button')!;
      store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: store.uid(),
            kind: 'button',
            props: {...entry.defaults, 'label': 'PickMe'},
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
      await tester.pumpAndSettle();

      // Select the node through the Layers pill (Y6 replaces the rail):
      // the row label is the kind-based 'Button · <id>'.
      await tester.tap(find.byKey(const ValueKey('forge-left-pill-layers')));
      await tester.pumpAndSettle();
      final layerRow = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('Button · '),
      );
      expect(layerRow, findsOneWidget);
      await tester.tap(layerRow);
      await tester.pumpAndSettle();
      // Selection shows the Forge toolbar and auto-opens the inspector.
      expect(find.byKey(kForgeSelectionToolbarKey), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inspector-delete')));
      await tester.pumpAndSettle();
      expect(store.doc.nodes, isEmpty);
    });

    testWidgets('selected screen deletes via topbar ×', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
      await tester.pumpAndSettle();

      // Y4: labels are gone — select s9 via its empty screen area (same
      // `onSelectScreen` path; see `_tapPhoneCenter`). The topbar then marks
      // s9 active with a deletable ×.
      await _tapPhoneCenter(tester, 1);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ForgeTopbar),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.doc.screens.map((s) => s.id), ['s1']);
    });

    testWidgets('dangling guard keeps the screen and names blockers',
        (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _twoScreenDoc());
      store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: store.uid(),
            kind: 'button',
            action: const NodeAction(to: 's9', transition: 'push'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
      await tester.pumpAndSettle();

      // Y4: labels are gone — select s9 via its empty screen area (same
      // `onSelectScreen` path; see `_tapPhoneCenter`).
      await _tapPhoneCenter(tester, 1);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ForgeTopbar),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      expect(store.doc.screens, hasLength(2));
      expect(find.textContaining('Cannot delete screen'), findsOneWidget);
      expect(find.textContaining('s9'), findsWidgets);
    });
  });

  group('layers panel screen delete', () {
    testWidgets('Delete screen removes the screen', (tester) async {
      final store = CanvasStore(initial: _twoScreenDoc());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayersPanel(
              store: store,
              selectedNodeId: null,
              onSelectNode: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Screen-header delete glyphs: first header in doc order is s1.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      // First header in doc order is s1 ('Pay'); s9 ('Done') remains.
      expect(store.doc.screens.map((s) => s.id), ['s9']);
    });

    testWidgets('Delete screen refusal shows a SnackBar', (tester) async {
      final store = CanvasStore(initial: _twoScreenDoc());
      store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: store.uid(),
            kind: 'button',
            action: const NodeAction(to: 's9', transition: 'push'),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayersPanel(
              store: store,
              selectedNodeId: null,
              onSelectNode: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Screen-header delete glyphs: last header in doc order is s9.
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump();
      expect(store.doc.screens, hasLength(2));
      expect(find.textContaining('Cannot delete'), findsOneWidget);
    });
  });
}
