/// Track X1 (fill + handles + frame): pinned dims paint at the pinned size,
/// finger-friendly handle hit areas with a live WxH readout, a scrollable
/// screen with scroll-correct drop math, and the polished device frame.
///
/// The full-bleed proof below fails on the pre-X1 tree (kit surfaces painted
/// intrinsic top-left inside the tight box); the scroll/drop test fails when
/// the scroll offset is not added to the pointer and the landing.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _theme = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

const _screen = CanvasScreen(
  id: 's1',
  name: 'Home',
  x: 0,
  y: 0,
  bg: 'surface',
);

CanvasNode _node({
  String id = 'n1',
  double? w,
  double? h,
  String kind = 'button',
  String label = 'FillMe',
}) =>
    CanvasNode(
      id: id,
      screenId: 's1',
      x: 0,
      y: 0,
      items: [CanvasItem(id: 'i-$id', kind: kind, props: {'label': label})],
      w: w,
      h: h,
    );

Future<void> _pumpSurface(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
  String? selectedNodeId,
  double zoom = 1.0,
  void Function(String nodeId, double? w, double? h)? onResize,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EditorTheme(
        colors: EditorColors.dark,
        child: Scaffold(
          body: ThemedCanvas(
            theme: _theme,
            child: ScreenSurface(
              screen: _screen,
              nodes: nodes,
              selectedNodeId: selectedNodeId,
              onSelectNode: (_) {},
              zoom: zoom,
              onResizeNode: onResize,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('fill rule (full-bleed proof)', () {
    testWidgets('pinned w+h paints the surface at the pinned size', (
      tester,
    ) async {
      await _pumpSurface(
        tester,
        nodes: [_node(kind: 'card', w: 200, h: 120)],
      );
      // The sizing box itself pins both dims ...
      final box = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 200.0 && w.height == 120.0,
      );
      expect(box, findsWidgets);
      expect(tester.getSize(box.first), const Size(200, 120));
      // ... and the painted card fills the pinned width (pre-X1 it stayed
      // intrinsic, ~110px, top-left inside the box).
      final cardSize = tester.getSize(find.byType(shadcn.Card).first);
      expect(cardSize.width, 200.0);
    });

    testWidgets('width-only pin stretches with intrinsic height', (
      tester,
    ) async {
      await _pumpSurface(tester, nodes: [_node(w: 200)]);
      final box = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 200.0 && w.height == null,
      );
      expect(box, findsWidgets);
      // Paint fills the pinned width while the height stays intrinsic (no
      // forced 200px-tall button).
      final buttonBox =
          tester.renderObject<RenderBox>(find.byType(shadcn.PrimaryButton).first);
      expect(buttonBox.size.width, 200.0);
      expect(buttonBox.size.height, lessThan(200.0));
    });

    testWidgets('fixed-w row child fills its pixels', (tester) async {
      _useReferenceViewport(tester);
      final doc = ScreenDoc.fromJson({
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
              {'id': 'ic1', 'kind': 'badge', 'label': 'Alpha'},
            ],
            'parentId': 'r1',
            'w': 100.0,
          },
          {
            'id': 'c2',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'ic2', 'kind': 'badge', 'label': 'Beta'},
            ],
            'parentId': 'r1',
          },
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Flex', 'brief': ''},
      });
      final store = CanvasStore(initial: doc);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      // Cell pins exact pixels and the badge paint fills the chrome
      // interior (100px cell minus the 4px node padding on each side; pre-X1
      // the badge stayed at its ~45px intrinsic width and wrapped).
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 100.0),
        findsWidgets,
      );
      expect(
        tester.getSize(find.byType(shadcn.PrimaryBadge).first).width,
        92.0,
      );
    });
  });

  group('handle usability', () {
    testWidgets('grab area is >= 28px while the visual stays 10-12px', (
      tester,
    ) async {
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
      );
      for (final edge in ['right', 'bottom', 'corner']) {
        final handle = find.byKey(resizeHandleKey('n1', edge));
        expect(handle, findsOneWidget);
        expect(tester.getSize(handle), const Size(28, 28));
        final visuals = find.descendant(
          of: handle,
          matching: find.byType(Container),
        );
        expect(visuals, findsOneWidget);
        expect(tester.getSize(visuals), const Size(12, 12));
      }
    });

    testWidgets('resize cursors preview the drag axis', (tester) async {
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
      );
      final cursors = {
        'right': SystemMouseCursors.resizeRight,
        'bottom': SystemMouseCursors.resizeDown,
        'corner': SystemMouseCursors.resizeDownRight,
      };
      for (final entry in cursors.entries) {
        expect(
          find.ancestor(
            of: find.byKey(resizeHandleKey('n1', entry.key)),
            matching: find.byWidgetPredicate(
              (w) => w is MouseRegion && w.cursor == entry.value,
            ),
          ),
          findsOneWidget,
          reason: '${entry.key} handle misses its resize cursor',
        );
      }
    });

    testWidgets('live WxH readout shows while dragging, hides on release', (
      tester,
    ) async {
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
      );
      expect(find.byKey(resizeReadoutKey('n1')), findsNothing);
      final handle =
          tester.getCenter(find.byKey(resizeHandleKey('n1', 'corner')));
      final gesture = await tester.startGesture(handle);
      await gesture.moveBy(const Offset(16, 24));
      await tester.pump();
      final readout = find.byKey(resizeReadoutKey('n1'));
      expect(readout, findsOneWidget);
      expect(find.text('116×104'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(find.byKey(resizeReadoutKey('n1')), findsNothing);
    });

    testWidgets('full inner width is reachable by drag', (tester) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'right')),
        const Offset(5000, 0),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.w, specForScreenDevice(null).width);
    });
  });

  group('height freedom (scroll + drop math)', () {
    ScreenDoc tallDoc() => ScreenDoc.fromJson({
          'screens': [
            {
              'id': 's1',
              'name': 'Screen 1',
              'x': 0.0,
              'y': 0.0,
              'bg': 'surface',
            },
          ],
          'nodes': [
            for (var i = 0; i < 3; i++)
              {
                'id': 't$i',
                'screenId': 's1',
                'x': 0.0,
                'y': 0.0,
                'items': [
                  {'id': 'it$i', 'kind': 'card'},
                ],
                'h': 350.0,
              },
          ],
          'theme': {
            'paletteKey': 'clean-slate',
            'dark': true,
            'shape': 'rounded',
            'motion': 'standard',
          },
          'meta': {'title': 'Tall', 'brief': ''},
        });

    testWidgets('over-tall content scrolls instead of clipping', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: tallDoc());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        0.0,
      );
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      // A vertical drag scrolls the screen (the ~20px touch slop the gesture
      // arena consumes before the scroll recognizer wins never reaches the
      // offset, so pin movement, not an exact figure).
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(250.0),
      );
    });

    testWidgets('drop while scrolled lands at pointer + scroll offset', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: tallDoc());
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
                Expanded(child: DesignCanvas(store: store)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Scroll the screen down 300px first.
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      final scrolled =
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(scrolled, greaterThan(200.0));

      // Drop into the root gap between the first and second tall cards (doc
      // y 402..414: card chrome is 350 + 8 padding, gap 12, content top 44).
      // While scrolled ~280 that gap sits at viewport ~122..134, so a
      // viewport-128 drop resolves to root index 1 with the stored position
      // carrying the scroll offset. (Dropping onto a card body would
      // correctly nest inside it per the deepest-container rule — the gap
      // pins the root path.)
      final box =
          tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
      const wantViewport = Offset(50, 128);
      final global = box.localToGlobal(wantViewport);
      final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
      final gesture =
          await tester.startGesture(tileTopLeft + const Offset(80, 30));
      await gesture.moveTo(global);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.doc.nodes, hasLength(4));
      final landed = store.doc.nodes[1];
      expect(landed.items.single.kind, 'button');
      expect(landed.parentId, isNull);
      expect(landed.x, moreOrLessEquals(wantViewport.dx, epsilon: 1.5));
      expect(
        landed.y,
        moreOrLessEquals(wantViewport.dy + scrolled, epsilon: 1.5),
      );
    });
  });

  group('frame polish', () {
    testWidgets('status bar + home indicator render token-styled', (
      tester,
    ) async {
      await _pumpSurface(tester, nodes: [_node()]);
      expect(find.text('9:41'), findsOneWidget);
      expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.battery_full), findsOneWidget);
      // Glyphs ride the secondary-label token, never a hardcoded color.
      final wifi = tester.widget<Icon>(find.byIcon(Icons.wifi));
      expect(wifi.color, EditorColors.dark.onSurfaceVariant);
      final time = tester.widget<Text>(find.text('9:41'));
      expect(time.style?.color, EditorColors.dark.onSurfaceVariant);
    });

    testWidgets('ScreenLabel shows the live device WxH readout', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditorTheme(
            colors: EditorColors.dark,
            child: Scaffold(
              body: ScreenLabel(name: 'Home', device: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('390×844'), findsOneWidget);
    });

    testWidgets('ScreenLabel tracks the tablet preset dims', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditorTheme(
            colors: EditorColors.dark,
            child: Scaffold(
              body: ScreenLabel(name: 'Tab', device: 'tablet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('768×1024'), findsOneWidget);
    });

    testWidgets('frame keeps its measured outer geometry', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();
      // Outer body untouched (phone budget: stage + measured bezel): only the
      // inner visual padding slimmed, so the outer box still matches the
      // pinned interaction-test formula.
      expect(
        tester.getSize(find.byType(PhoneFrame).first).width,
        moreOrLessEquals(390 + 7.5 * 2),
      );
    });
  });
}
