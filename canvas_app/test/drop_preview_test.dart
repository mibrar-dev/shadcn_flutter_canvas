/// Track D3 drop-preview tests: while a palette drag hovers a
/// container/row/root target, a ghost preview of the dragged kind renders
/// INSIDE the target chrome at the insertion index (resolved from the same
/// `_flowHit`/index mapping as the landing path). The existing insert line
/// stays untouched and shows alongside the ghost.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): the phone frame is 343x725 and overflows
/// the default 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ScreenDoc _doc(List<Map<String, dynamic>> nodes) => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': nodes,
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Drop preview', 'brief': ''},
    });

/// Card container with two button children.
ScreenDoc _cardDoc() => _doc([
      {
        'id': 'card1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {'id': 'icard', 'kind': 'card', 'title': 'Host Card'},
        ],
      },
      {
        'id': 'kidA',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'parentId': 'card1',
        'items': [
          {'id': 'ikidA', 'kind': 'button', 'label': 'Kid A'},
        ],
      },
      {
        'id': 'kidB',
        'screenId': 's1',
        'x': 0.0,
        'y': 48.0,
        'parentId': 'card1',
        'items': [
          {'id': 'ikidB', 'kind': 'button', 'label': 'Kid B'},
        ],
      },
    ]);

/// Row container with two button children.
ScreenDoc _rowDoc() => _doc([
      {
        'id': 'row1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [],
        'isRow': true,
        'gap': 8.0,
      },
      {
        'id': 'rA',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'parentId': 'row1',
        'items': [
          {'id': 'irA', 'kind': 'button', 'label': 'R A'},
        ],
      },
      {
        'id': 'rB',
        'screenId': 's1',
        'x': 48.0,
        'y': 0.0,
        'parentId': 'row1',
        'items': [
          {'id': 'irB', 'kind': 'button', 'label': 'R B'},
        ],
      },
    ]);

/// Pumps a palette tile above a [DesignCanvas] holding [doc].
Future<DesignCanvas> _pumpEditor(WidgetTester tester, ScreenDoc doc) async {
  final store = CanvasStore(initial: doc);
  final canvas = DesignCanvas(store: store);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Draggable<String>(
              data: 'badge',
              feedback: Material(child: Text('dragging')),
              child: SizedBox(width: 100, height: 40, child: Text('tile')),
            ),
            Expanded(child: canvas),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return canvas;
}

/// Starts a tile drag with a grab point off the tile corner and returns the
/// gesture plus the drop target box for global conversion.
Future<({TestGesture gesture, RenderBox targetBox})> _startTileDrag(
  WidgetTester tester,
) async {
  final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
  final gesture =
      await tester.startGesture(tileTopLeft + const Offset(80, 30));
  await tester.pump();
  final box = tester.renderObject<RenderBox>(find.byType(DragTarget<String>));
  return (gesture: gesture, targetBox: box);
}

void main() {
  group('drop preview ghost', () {
    testWidgets('hovering a container shows the ghost between children',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpEditor(tester, _cardDoc());

      final drag = await _startTileDrag(tester);
      // FF1 (drop-into-slot): the card's `content` slot is EMPTY, so the
      // hover previews the slot assignment instead of the flow index — the
      // ghost heads the slot (above Kid A) and the index line hides (the
      // landing ignores the index). See `drop_slots_test.dart` (slot ghost
      // preview group) for the dedicated pins; the occupied-slot flow
      // preview below still covers the classic between-children ghost.
      final a = tester.getCenter(find.text('Kid A'));
      final b = tester.getCenter(find.text('Kid B'));
      await drag.gesture.moveTo(Offset(a.dx, (a.dy + b.dy) / 2));
      await tester.pump();

      // The ghost carries the dragged kind's label, inside the slot region.
      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.text('Drop badge here'), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsNothing);

      // The ghost occupies the slot head: above Kid A (and Kid B).
      final ghostBottom =
          tester.getBottomLeft(find.byKey(kDropPreviewKey)).dy;
      expect(ghostBottom,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Kid A')).dy));

      // Leave clears the ghost (no line was shown).
      await drag.gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
    });

    testWidgets('occupied slot keeps the ghost between children', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      // FF1: with the `content` slot TAKEN, the hover falls back to the
      // classic flow preview — the ghost splices between the visible
      // children at the hover index and the insert line shows. This keeps
      // the D3 between-children contract pinned after the empty-slot case
      // above moved to the slot head.
      await _pumpEditor(
        tester,
        _doc([
          {
            'id': 'card1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'icard', 'kind': 'card', 'title': 'Host Card'},
            ],
            'slotNodes': {'content': 'slotKid'},
          },
          {
            'id': 'slotKid',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'parentId': 'card1',
            'items': [
              {'id': 'islot', 'kind': 'button', 'label': 'Slot Kid'},
            ],
          },
          {
            'id': 'kidA',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'parentId': 'card1',
            'items': [
              {'id': 'ikidA', 'kind': 'button', 'label': 'Kid A'},
            ],
          },
          {
            'id': 'kidB',
            'screenId': 's1',
            'x': 0.0,
            'y': 48.0,
            'parentId': 'card1',
            'items': [
              {'id': 'ikidB', 'kind': 'button', 'label': 'Kid B'},
            ],
          },
        ]),
      );

      final drag = await _startTileDrag(tester);
      final a = tester.getCenter(find.text('Kid A'));
      final b = tester.getCenter(find.text('Kid B'));
      await drag.gesture.moveTo(Offset(a.dx, (a.dy + b.dy) / 2));
      await tester.pump();

      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.text('Drop badge here'), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsOneWidget);

      final ghostTop = tester.getTopLeft(find.byKey(kDropPreviewKey)).dy;
      final ghostBottom =
          tester.getBottomLeft(find.byKey(kDropPreviewKey)).dy;
      expect(tester.getBottomLeft(find.text('Kid A')).dy,
          lessThanOrEqualTo(ghostTop));
      expect(ghostBottom,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Kid B')).dy));

      await drag.gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
    });

    testWidgets('hovering a row shows the ghost inside the strip',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpEditor(tester, _rowDoc());

      final drag = await _startTileDrag(tester);
      // Midpoint between the two strip centers: inside the row at index 1.
      final a = tester.getCenter(find.text('R A'));
      final b = tester.getCenter(find.text('R B'));
      await drag.gesture.moveTo(Offset((a.dx + b.dx) / 2, a.dy));
      await tester.pump();

      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.text('Drop badge here'), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsOneWidget);

      final ghostLeft = tester.getTopLeft(find.byKey(kDropPreviewKey)).dx;
      final ghostRight =
          tester.getTopRight(find.byKey(kDropPreviewKey)).dx;
      expect(tester.getBottomRight(find.text('R A')).dx,
          lessThanOrEqualTo(ghostLeft));
      expect(ghostRight,
          lessThanOrEqualTo(tester.getTopLeft(find.text('R B')).dx));

      await drag.gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
    });

    testWidgets('hovering empty screen area falls back to the root ghost',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpEditor(tester, _doc([]));

      final drag = await _startTileDrag(tester);
      final box = drag.targetBox;
      await drag.gesture.moveTo(box.localToGlobal(box.size.center(Offset.zero)));
      await tester.pump();

      // Root fallback: ghost + insert line, no crash on the empty doc.
      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.text('Drop badge here'), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsOneWidget);

      await drag.gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
    });

    testWidgets('dropping after preview still lands (preview is passive)',
        (tester) async {
      _useReferenceViewport(tester);
      final canvas = await _pumpEditor(tester, _cardDoc());

      final drag = await _startTileDrag(tester);
      final b = tester.getCenter(find.text('Kid B'));
      final a = tester.getCenter(find.text('Kid A'));
      await drag.gesture.moveTo(Offset(a.dx, (a.dy + b.dy) / 2));
      await tester.pump();
      expect(find.byKey(kDropPreviewKey), findsOneWidget);

      await drag.gesture.up();
      await tester.pumpAndSettle();

      // The drop committed into the container. FF1 (drop-into-slot): the
      // card's `content` slot was empty, so the landing assigns it IN
      // ADDITION to parenting (one commit — slot wins at render, the doc
      // order below still follows the pointer). The slot-head ghost shown
      // during hover displaces the flow kids downward, so the held pointer
      // resolves above Kid A (index 0); the render is identical either way
      // because the slot heads the content.
      expect(find.byKey(kDropPreviewKey), findsNothing);
      expect(canvas.store.doc.nodes, hasLength(4));
      final landed = canvas.store.doc.nodes.singleWhere(
        (n) => n.items.any((i) => i.kind == 'badge'),
      );
      expect(landed.parentId, 'card1');
      expect(
        canvas.store.doc.nodes
            .singleWhere((n) => n.id == 'card1')
            .slotNodes['content'],
        landed.id,
      );
      final order = [
        for (final n in canvas.store.doc.nodes)
          if (n.parentId == 'card1') n.id,
      ];
      expect(order.toSet(), {'kidA', 'kidB', landed.id});
    });
  });
}
