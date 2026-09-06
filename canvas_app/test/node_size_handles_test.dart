/// Track U2 resize handles: presence, zoom-aware drag math through the real
/// gesture path, commit-on-release (one store write per gesture), and clamps.
///
/// The harness pumps [ScreenSurface] directly (like `tap_action_test.dart`)
/// with a recording `onResizeNode` — production wiring at the
/// `DesignCanvas` site is a documented one-liner for the coordinator (see
/// [ScreenSurface.onResizeNode]).
library;

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

CanvasNode _node({double? w, double? h}) => CanvasNode(
      id: 'n1',
      screenId: 's1',
      x: 0,
      y: 0,
      items: const [
        CanvasItem(id: 'i1', kind: 'button', props: {'label': 'ResizeMe'}),
      ],
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

void main() {
  group('handle presence', () {
    testWidgets('unselected node shows no handles', (tester) async {
      await _pumpSurface(tester, nodes: [_node()]);
      expect(find.byKey(resizeHandleKey('n1', 'right')), findsNothing);
      expect(find.byKey(resizeHandleKey('n1', 'bottom')), findsNothing);
      expect(find.byKey(resizeHandleKey('n1', 'corner')), findsNothing);
    });

    testWidgets('selected node shows right + bottom + corner', (
      tester,
    ) async {
      await _pumpSurface(
        tester,
        nodes: [_node()],
        selectedNodeId: 'n1',
      );
      expect(find.byKey(resizeHandleKey('n1', 'right')), findsOneWidget);
      expect(find.byKey(resizeHandleKey('n1', 'bottom')), findsOneWidget);
      expect(find.byKey(resizeHandleKey('n1', 'corner')), findsOneWidget);
    });

    testWidgets('handles follow selection, not other nodes', (tester) async {
      await _pumpSurface(
        tester,
        nodes: [_node()],
        selectedNodeId: 'other',
      );
      expect(find.byKey(resizeHandleKey('n1', 'right')), findsNothing);
    });
  });

  group('drag math through the gesture path', () {
    testWidgets('right handle grows width (unchanged h reports null)', (
      tester,
    ) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'right')),
        const Offset(20, 0),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.id, 'n1');
      expect(calls.single.w, 120.0);
      expect(calls.single.h, isNull);
    });

    testWidgets('zoom divides the pointer delta', (tester) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        zoom: 2.0,
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'right')),
        const Offset(20, 0),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      // 20 pointer px at 2x zoom = 10 screen px.
      expect(calls.single.w, 110.0);
    });

    testWidgets('bottom handle grows height only', (tester) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'bottom')),
        const Offset(30, 40),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.w, isNull);
      expect(calls.single.h, 120.0);
    });

    testWidgets('corner handle drives both dims', (tester) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'corner')),
        const Offset(16, 24),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.w, 116.0);
      expect(calls.single.h, 104.0);
    });

    testWidgets('multi-move gesture commits once (commit-on-release)', (
      tester,
    ) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      final handle =
          tester.getCenter(find.byKey(resizeHandleKey('n1', 'right')));
      final gesture = await tester.startGesture(handle);
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();
      // Live tentative state rebuilds without committing mid-gesture.
      expect(calls, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.w, 110.0);
    });

    testWidgets('auto node resizes from its measured size', (tester) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node()],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'right')),
        const Offset(20, 0),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      // Measured start + 20: concrete, sane, and wider than the floor.
      expect(calls.single.w, isNotNull);
      expect(calls.single.w!, greaterThan(kMinNodeSize));
      expect(calls.single.w!, lessThanOrEqualTo(390.0));
      // The untouched height axis stays auto (not pinned at measured).
      expect(calls.single.h, isNull);
    });

    testWidgets('bottom drag on auto-height node leaves width alone', (
      tester,
    ) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'bottom')),
        const Offset(0, 20),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.w, isNull);
      expect(calls.single.h, isNotNull);
    });
  });

  group('clamps', () {
    testWidgets('drag below the floor pins to kMinNodeSize', (tester) async {
      final calls = <({String id, double? w, double? h})>[];
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
        onResize: (id, w, h) => calls.add((id: id, w: w, h: h)),
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'right')),
        const Offset(-500, 0),
      );
      await tester.pump();
      expect(calls, hasLength(1));
      expect(calls.single.w, kMinNodeSize);
    });

    testWidgets('drag past the stage pins to the stage width', (
      tester,
    ) async {
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
      // Phone stage width.
      expect(calls.single.w, 390.0);
    });

    testWidgets('unwired surface (no onResizeNode) drags without crashing',
        (tester) async {
      await _pumpSurface(
        tester,
        nodes: [_node(w: 100, h: 80)],
        selectedNodeId: 'n1',
      );
      await tester.drag(
        find.byKey(resizeHandleKey('n1', 'right')),
        const Offset(20, 0),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
