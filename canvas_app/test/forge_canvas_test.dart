/// Track Y4 (FORGE.md §1-3a–3g, §3): Forge canvas-area chrome.
///
/// Covers the header breadcrumb trail + taps, the zoom cluster call-through
/// (zoom math/contracts unchanged), the guides grid toggle, the compact
/// device strip, the dismissible hint pill, the dotted background, the
/// Dynamic Island overlay, and the black selection toolbar.
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/forge_canvas_header.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_app/ui/zoom_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): the canvas + phone frames overflow the
/// default 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ForgeCanvasHeader _header({
  String projectTitle = 'Checkout',
  String screenId = 's1',
  String screenName = 'Pay',
  ValueChanged<String?>? onSelectScreen,
  String? selectedNodeId = 'card_1',
  String? selectedNodeLabel = 'Card · card_1',
  ValueChanged<String?>? onSelectNode,
  double zoom = 1.0,
  VoidCallback? onZoomIn,
  VoidCallback? onZoomOut,
  VoidCallback? onFit,
  bool showGuides = true,
  ValueChanged<bool>? onShowGuidesChanged,
  String? screenDevice,
  ValueChanged<String?>? onDeviceChanged,
}) {
  return ForgeCanvasHeader(
    projectTitle: projectTitle,
    screenId: screenId,
    screenName: screenName,
    onSelectScreen: onSelectScreen ?? (_) {},
    selectedNodeId: selectedNodeId,
    selectedNodeLabel: selectedNodeLabel,
    onSelectNode: onSelectNode ?? (_) {},
    zoom: zoom,
    onZoomIn: onZoomIn ?? () {},
    onZoomOut: onZoomOut ?? () {},
    onFit: onFit ?? () {},
    showGuides: showGuides,
    onShowGuidesChanged: onShowGuidesChanged,
    screenDevice: screenDevice,
    onDeviceChanged: onDeviceChanged ?? (_) {},
  );
}

Future<void> _pumpHeader(WidgetTester tester, ForgeCanvasHeader header) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: header)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCanvas(WidgetTester tester, CanvasStore store) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
  );
  await tester.pumpAndSettle();
}

/// Reads an [EditorIconButton]'s enabled state by its glyph.
EditorIconButton _chromeButton(WidgetTester tester, IconData icon) {
  return tester.widget<EditorIconButton>(
    find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(EditorIconButton),
    ),
  );
}

void main() {
  group('ForgeCanvasHeader breadcrumb', () {
    testWidgets('renders the project › screen › node trail', (tester) async {
      await _pumpHeader(tester, _header());
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('Card · card_1'), findsOneWidget);
      expect(find.text('›'), findsNWidgets(2));
      expect(find.byType(ZoomControls), findsOneWidget);
    });

    testWidgets('screen and node taps fire the shell callbacks',
        (tester) async {
      String? screen;
      String? node;
      await _pumpHeader(
        tester,
        _header(
          onSelectScreen: (id) => screen = id,
          onSelectNode: (id) => node = id,
        ),
      );
      await tester.tap(find.text('Pay'));
      await tester.pump();
      expect(screen, 's1');
      await tester.tap(find.text('Card · card_1'));
      await tester.pump();
      expect(node, 'card_1');
    });

    testWidgets('no selection renders a single separator, no node crumb',
        (tester) async {
      await _pumpHeader(
        tester,
        _header(selectedNodeId: null, selectedNodeLabel: null),
      );
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('›'), findsOneWidget);
    });
  });

  group('ForgeCanvasHeader zoom cluster', () {
    testWidgets('zoom buttons call through and the readout tracks zoom',
        (tester) async {
      var zoomIn = 0;
      var zoomOut = 0;
      var fit = 0;
      await _pumpHeader(
        tester,
        _header(
          zoom: 1.0,
          onZoomIn: () => zoomIn++,
          onZoomOut: () => zoomOut++,
          onFit: () => fit++,
          onShowGuidesChanged: (_) {},
        ),
      );
      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pump();
      expect(zoomOut, 1);
      expect(zoomIn, 1);
      expect(fit, 1);
    });

    testWidgets('zoom clamps disable at the 25% / 400% ends',
        (tester) async {
      await _pumpHeader(tester, _header(zoom: 4.0));
      expect(_chromeButton(tester, Icons.add).onPressed, isNull);
      expect(_chromeButton(tester, Icons.remove).onPressed, isNotNull);

      await _pumpHeader(tester, _header(zoom: 0.25));
      expect(_chromeButton(tester, Icons.remove).onPressed, isNull);
      expect(_chromeButton(tester, Icons.add).onPressed, isNotNull);
    });

    testWidgets('grid toggle flips the guides flag and reflects state',
        (tester) async {
      bool? toggled;
      await _pumpHeader(
        tester,
        _header(showGuides: true, onShowGuidesChanged: (v) => toggled = v),
      );
      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pump();
      expect(toggled, isFalse);

      await _pumpHeader(
        tester,
        _header(showGuides: false, onShowGuidesChanged: (_) {}),
      );
      expect(find.byIcon(Icons.grid_off), findsOneWidget);
    });

    testWidgets('no guides handler hides the grid button (shell compat)',
        (tester) async {
      _useReferenceViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZoomControls(
              zoom: 1.0,
              onZoomIn: _noop,
              onZoomOut: _noop,
              onFit: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.grid_on), findsNothing);
      expect(find.byIcon(Icons.grid_off), findsNothing);
    });
  });

  group('ForgeCanvasHeader device strip', () {
    testWidgets('device taps report the preset id (null for phone)',
        (tester) async {
      String? device = 'unset';
      await _pumpHeader(
        tester,
        _header(
          screenDevice: null,
          onDeviceChanged: (id) => device = id,
        ),
      );
      await tester.tap(find.byIcon(Icons.tablet_mac));
      await tester.pump();
      expect(device, 'tablet');

      await tester.tap(find.byIcon(Icons.smartphone));
      await tester.pump();
      expect(device, isNull);
    });
  });

  group('ForgeSelectionToolbar', () {
    testWidgets('hidden without a selection', (tester) async {
      _useReferenceViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ForgeSelectionToolbar(selectedNodeId: null)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(kForgeSelectionToolbarKey), findsNothing);
    });

    testWidgets('up / down / duplicate fire with a selection',
        (tester) async {
      var up = 0;
      var down = 0;
      var duplicate = 0;
      _useReferenceViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeSelectionToolbar(
              selectedNodeId: 'n1',
              onMoveUp: () => up++,
              onMoveDown: () => down++,
              onDuplicate: () => duplicate++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(kForgeSelectionToolbarKey), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();
      expect(up, 1);
      expect(down, 1);
      expect(duplicate, 1);
    });

    testWidgets('null callbacks render the disabled state', (tester) async {
      _useReferenceViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ForgeSelectionToolbar(selectedNodeId: 'n1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _chromeButton(tester, Icons.arrow_upward).onPressed,
        isNull,
      );
      expect(
        _chromeButton(tester, Icons.arrow_downward).onPressed,
        isNull,
      );
      expect(
        _chromeButton(tester, Icons.content_copy).onPressed,
        isNull,
      );
    });
  });

  group('hint pill + dotted background', () {
    testWidgets('hint shows the reference copy and dismisses via ×',
        (tester) async {
      await _pumpCanvas(tester, CanvasStore());
      expect(
        find.text('Drop widgets… · click a block… · drag the corner…'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(ForgeHintPill),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      expect(find.byType(ForgeHintPill), findsNothing);
    });

    testWidgets('dots paint behind the viewport', (tester) async {
      await _pumpCanvas(tester, CanvasStore());
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ForgeDotsPainter,
        ),
        findsOneWidget,
      );
    });

    test('dots painter repaints only on visual change', () {
      const painter = ForgeDotsPainter(color: Colors.grey);
      expect(
        painter.shouldRepaint(const ForgeDotsPainter(color: Colors.grey)),
        isFalse,
      );
      expect(
        painter.shouldRepaint(const ForgeDotsPainter(color: Colors.black)),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ForgeDotsPainter(color: Colors.grey, spacing: 24),
        ),
        isTrue,
      );
    });

    test('DesignCanvas guides default on and accept an override', () {
      expect(DesignCanvas(store: CanvasStore()).showGuides, isTrue);
      expect(
        DesignCanvas(store: CanvasStore(), showGuides: false).showGuides,
        isFalse,
      );
    });
  });

  group('Dynamic Island', () {
    testWidgets('present, spec-sized, and pointer-transparent',
        (tester) async {
      await _pumpCanvas(tester, CanvasStore());
      final island = find.byKey(kDynamicIslandKey);
      expect(island, findsOneWidget);
      expect(tester.getSize(island), const Size(110, 28));
      // Pointer-transparent like the status bar: an `IgnorePointer` with
      // `ignoring: true` above it means taps, selection, and drops pass
      // through.
      final blockers = tester.widgetList<IgnorePointer>(
        find.ancestor(of: island, matching: find.byType(IgnorePointer)),
      );
      expect(blockers.any((w) => w.ignoring), isTrue);
    });
  });

  group('zoom math kept', () {
    test('clampZoom pins to the 25% / 400% bounds', () {
      expect(clampZoom(99), 4.0);
      expect(clampZoom(-1), 0.25);
      expect(clampZoom(1.5), 1.5);
    });
  });
}

void _noop() {}
