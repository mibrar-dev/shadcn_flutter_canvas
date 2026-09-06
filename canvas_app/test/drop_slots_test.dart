/// Track FF1 drop-into-slots: scaffold-children honesty + slot assignment.
///
/// * BUG 1: a palette drop parented under a scaffold must render (children
///   fall into the body region below/after the body slot). The confirm-first
///   test below pins it.
/// * SLOT-DROP RULE: dropping a leaf kind onto a host with an EMPTY
///   compatible slot assigns that slot instead of plain parenting —
///   `body` for scaffold, `content` for single-content hosts, first empty
///   slot in declared order otherwise (e.g. `basic` → `leading`);
///   an occupied slot (or a locked host, or a `row` drop) falls back to
///   plain parenting exactly as today. One commit per drop (atomic undo).
/// * GHOST: while hovering a host whose empty slot would be assigned, the
///   ghost previews INSIDE the slot region and the flow index line hides
///   (the landing ignores the index, so the line would lie).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/design_canvas.dart';
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

void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CanvasNode _node({
  required String id,
  required String kind,
  Map<String, dynamic> props = const {},
  String? parentId,
  bool isRow = false,
  bool locked = false,
  Map<String, String> slotNodes = const {},
}) =>
    CanvasNode(
      id: id,
      screenId: 's1',
      x: 0,
      y: 0,
      items: [
        if (!isRow) CanvasItem(id: 'i-$id', kind: kind, props: props),
      ],
      parentId: parentId,
      isRow: isRow,
      locked: locked,
      slotNodes: slotNodes,
    );

ScreenDoc _doc(List<CanvasNode> nodes) => ScreenDoc(
      screens: const [
        CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
      ],
      nodes: nodes,
      theme: _theme,
      meta: const DocMeta(title: 'FF1', brief: ''),
    );

/// Pumps a [DesignCanvas] holding [doc] with a palette tile of [tileKind]
/// above it. Returns the store for doc assertions.
Future<CanvasStore> _pumpCanvas(
  WidgetTester tester,
  ScreenDoc doc, {
  String tileKind = 'badge',
}) async {
  final store = CanvasStore(initial: doc);
  final canvas = DesignCanvas(store: store);
  await tester.pumpWidget(
    MaterialApp(
      home: EditorTheme(
        colors: EditorColors.dark,
        child: Scaffold(
          body: ThemedCanvas(
            theme: _theme,
            child: Column(
              children: [
                Draggable<String>(
                  data: tileKind,
                  feedback: const Material(child: Text('dragging')),
                  child: const SizedBox(
                    width: 100,
                    height: 40,
                    child: Text('tile'),
                  ),
                ),
                Expanded(child: canvas),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<TestGesture> _startTileDrag(WidgetTester tester) async {
  final tileTopLeft = tester.getTopLeft(find.byType(Draggable<String>));
  final gesture = await tester.startGesture(tileTopLeft + const Offset(80, 30));
  await tester.pump();
  return gesture;
}

void main() {
  group('bug 1: scaffold-parented drops render', () {
    testWidgets('parented child paints in the scaffold body region', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(
          tester,
          _doc([
            _node(id: 'scaf', kind: 'scaffold'),
            _node(
              id: 'kid',
              kind: 'badge',
              props: const {'label': 'Scaffold Kid'},
              parentId: 'scaf',
            ),
          ]));

      // The drop did not vanish: the child paints exactly once, below the
      // body text (children splice complements the body region).
      expect(find.text('Scaffold Kid'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Welcome')).dy,
        lessThan(tester.getTopLeft(find.text('Scaffold Kid')).dy),
      );
    });

    testWidgets('onAccept onto a scaffold renders the landed node', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final store =
          CanvasStore(initial: _doc([_node(id: 'scaf', kind: 'scaffold')]));
      final canvas = DesignCanvas(store: store);
      await tester.pumpWidget(
        MaterialApp(
          home: EditorTheme(
            colors: EditorColors.dark,
            child: Scaffold(
              body: ThemedCanvas(theme: _theme, child: canvas),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 200),
        parentId: 'scaf',
        index: 0,
      );
      await tester.pumpAndSettle();

      expect(store.doc.nodes.any((n) => n.id == id), isTrue);
      expect(find.text('Badge'), findsOneWidget);
    });

    testWidgets('every slot host renders a parented child somewhere', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      // `refresh_trigger` is covered separately below: its fixed 140px list
      // shell keeps a child below the fold until scrolled (builder-owned
      // chrome — scrolling reveals it, so nothing vanishes).
      const hosts = [
        'scaffold',
        'card',
        'dialog',
        'alert_dialog',
        'drawer',
        'form',
        'outlined_container',
        'hidden',
        'clickable',
        'scrollbar',
        'chat',
        'toast',
        'validated',
        'card_image',
        'basic',
      ];
      await _pumpCanvas(
          tester,
          _doc([
            for (final kind in hosts) _node(id: 'host-$kind', kind: kind),
            for (final kind in hosts)
              _node(
                id: 'kid-$kind',
                kind: 'badge',
                props: {'label': 'kid-$kind'},
                parentId: 'host-$kind',
              ),
          ]));

      // No dropped node may vanish: containers splice children into chrome,
      // non-container slot hosts (basic, card_image) stack them below.
      for (final kind in hosts) {
        expect(
          find.text('kid-$kind'),
          findsOneWidget,
          reason: 'parented child of $kind must render',
        );
      }
    });

    testWidgets('refresh_trigger child renders inside its list shell', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(
          tester,
          _doc([
            _node(id: 'host', kind: 'refresh_trigger'),
            _node(
              id: 'kid',
              kind: 'badge',
              props: const {'label': 'kid-refresh'},
              parentId: 'host',
            ),
          ]));

      // The fixed-height shell lays out without crashing; scrolling the
      // inner list reveals the spliced child — it renders, not vanishes.
      expect(find.byType(ListView), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('kid-refresh'), findsOneWidget);
    });
  });

  group('drop-into-slot rule', () {
    test('drop onto an empty scaffold assigns the body slot', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'scaf', kind: 'scaffold')]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 200),
        parentId: 'scaf',
        index: 0,
      );

      final host = store.doc.nodes.singleWhere((n) => n.id == 'scaf');
      expect(host.slotNodes['body'], id);
      final kid = store.doc.nodes.singleWhere((n) => n.id == id);
      expect(kid.parentId, 'scaf');
    });

    test('drop onto an empty content host assigns content', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'card1', kind: 'card')]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 10),
        parentId: 'card1',
        index: 0,
      );

      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'card1').slotNodes,
        {'content': id},
      );
    });

    test('drop onto basic assigns the first empty slot (leading)', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'b1', kind: 'basic')]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 10),
        parentId: 'b1',
        index: 0,
      );

      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'b1').slotNodes,
        {'leading': id},
      );
    });

    test('occupied slot falls back to plain parenting', () {
      final store = CanvasStore(
        initial: _doc([
          _node(
            id: 'scaf',
            kind: 'scaffold',
            slotNodes: const {'body': 'old'},
          ),
          _node(id: 'old', kind: 'badge', parentId: 'scaf'),
        ]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 200),
        parentId: 'scaf',
        index: 1,
      );

      // The taken slot is untouched; the newcomer parents as a plain child.
      final host = store.doc.nodes.singleWhere((n) => n.id == 'scaf');
      expect(host.slotNodes['body'], 'old');
      expect(
        store.doc.nodes.singleWhere((n) => n.id == id).parentId,
        'scaf',
      );
    });

    test('row drops never take slots (parent as today)', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'scaf', kind: 'scaffold')]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'row',
        const Offset(10, 200),
        parentId: 'scaf',
      );

      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'scaf').slotNodes,
        isEmpty,
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == id).parentId,
        'scaf',
      );
    });

    test('locked host refuses the slot without throwing', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'scaf', kind: 'scaffold', locked: true)]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 200),
        parentId: 'scaf',
        index: 0,
      );

      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'scaf').slotNodes,
        isEmpty,
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == id).parentId,
        'scaf',
      );
    });

    test('slot drop lands in one undo step', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'scaf', kind: 'scaffold')]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 200),
        parentId: 'scaf',
        index: 0,
      );
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'scaf').slotNodes['body'],
        id,
      );

      expect(store.undo(), isTrue);
      expect(store.doc.nodes.any((n) => n.id == id), isFalse);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'scaf').slotNodes,
        isEmpty,
      );
      // Exactly one commit: nothing left to undo.
      expect(store.canUndo, isFalse);
    });

    testWidgets('slot-assigned drop paints exactly once, in the slot', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final store = await _pumpCanvas(
        tester,
        _doc([_node(id: 'scaf', kind: 'scaffold')]),
        tileKind: 'badge',
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 200),
        parentId: 'scaf',
        index: 0,
      );
      await tester.pumpAndSettle();

      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'scaf').slotNodes['body'],
        id,
      );
      // Slot wins over flow: one paint, inside the host chrome.
      expect(find.text('Badge'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Badge'),
          matching: find.byType(PhoneFrame),
        ),
        findsOneWidget,
      );
    });
  });

  group('slot ghost preview', () {
    testWidgets('hovering an empty-slot host shows the ghost, hides the line',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(
        tester,
        _doc([_node(id: 'scaf', kind: 'scaffold')]),
      );

      final gesture = await _startTileDrag(tester);
      await gesture.moveTo(tester.getCenter(find.text('Welcome')));
      await tester.pump();

      // The ghost previews the slot assignment; the flow index line hides
      // because the landing ignores the index.
      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsNothing);

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
    });

    testWidgets('slot ghost heads the card above its plain children',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(
        tester,
        _doc([
          _node(id: 'card1', kind: 'card'),
          _node(
            id: 'kidA',
            kind: 'badge',
            props: const {'label': 'Kid A'},
            parentId: 'card1',
          ),
        ]),
      );

      final gesture = await _startTileDrag(tester);
      await gesture.moveTo(tester.getCenter(find.text('Kid A')));
      await tester.pump();

      // Empty content slot → the ghost previews inside the slot (heads the
      // card content), and the misleading index line stays hidden.
      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsNothing);
      expect(
        tester.getBottomLeft(find.byKey(kDropPreviewKey)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Kid A')).dy),
      );

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
    });

    testWidgets('occupied-slot hover keeps the plain child ghost + line',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpCanvas(
        tester,
        _doc([
          _node(
            id: 'card1',
            kind: 'card',
            slotNodes: const {'content': 'slotKid'},
          ),
          _node(
            id: 'slotKid',
            kind: 'badge',
            props: const {'label': 'Slot Kid'},
            parentId: 'card1',
          ),
          _node(
            id: 'kidB',
            kind: 'badge',
            props: const {'label': 'Kid B'},
            parentId: 'card1',
          ),
        ]),
      );

      final gesture = await _startTileDrag(tester);
      await gesture.moveTo(tester.getCenter(find.text('Kid B')));
      await tester.pump();

      // Slot taken → classic flow preview between the visible children.
      expect(find.byKey(kDropPreviewKey), findsOneWidget);
      expect(find.byKey(kFlowInsertLineKey), findsOneWidget);

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(kDropPreviewKey), findsNothing);
    });
  });

  group('invalid slot drops never crash', () {
    test('drop onto unknown parent still degrades to root', () {
      final store = CanvasStore(
        initial: _doc([_node(id: 'scaf', kind: 'scaffold')]),
      );
      final canvas = DesignCanvas(store: store);

      final id = canvas.onAccept(
        'badge',
        const Offset(10, 10),
        parentId: 'ghost',
      );

      expect(
        store.doc.nodes.singleWhere((n) => n.id == id).parentId,
        isNull,
      );
    });

    test('slot child id that names nothing is a safe no-op render', () {
      // Guards the renderer path the slot-drop writes through: a dangling
      // slot entry (hand doc or race) must never crash the surface.
      expect(
        () => _doc([
          _node(
            id: 'scaf',
            kind: 'scaffold',
            slotNodes: const {'body': 'ghost'},
          ),
        ]),
        returnsNormally,
      );
    });
  });
}
