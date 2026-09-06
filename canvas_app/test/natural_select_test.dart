/// Track AA (render: natural fill + deep select + lock-skip).
///
/// * NATURAL FILL: widths keep filling (Z1 stays), heights never stretch
///   unless `node.h` is pinned; content sits top-left natural; the intrinsic
///   set ([alignIntrinsicKind]) keeps working.
/// * SLOT INJECTION: generic `slotWidgets` build + props spread in the canvas
///   renderers and the preview player (cycle-safe, missing-id-safe), with the
///   flow-vs-slot rule SLOT WINS / FLOW SKIPS (see the rule doc on the
///   renderers). Builders read `props['<slot>'] as Widget?` per the shared
///   slot contract ([kNodeSlots] — e.g. card `content`, scaffold `body`), so
///   these tests pin the full loop: the slot child paints inside the host
///   chrome exactly once and never stacks in flow.
/// * DEEP SELECT: single click selects the deepest widget under the pointer
///   (FlutterFlow pattern); a second click on the same spot drills out to
///   the parent; breadcrumb/layers do the rest.
/// * LOCK-SKIP: locked nodes are never selectable — taps fall through to the
///   nearest unlocked ancestor (or nothing at root); paint is identical.
library;

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_app/ui/preview_player.dart';
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
  required String id,
  required String kind,
  Map<String, dynamic> props = const {},
  String? parentId,
  bool isRow = false,
  double? w,
  double? h,
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
      w: w,
      h: h,
      locked: locked,
      slotNodes: slotNodes,
    );

ScreenDoc _doc(List<CanvasNode> nodes) => ScreenDoc(
      screens: const [
        CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
      ],
      nodes: nodes,
      theme: _theme,
      meta: const DocMeta(title: 'AA', brief: ''),
    );

/// Selection harness: drives [ScreenSurface] with live selection state so
/// multi-tap drill-out can be observed ([calls] records every selection in
/// order; [selected] is the current shell selection).
class _SelectHarness extends StatefulWidget {
  final List<CanvasNode> nodes;
  final List<String> calls;

  const _SelectHarness({required this.nodes, required this.calls});

  @override
  State<_SelectHarness> createState() => _SelectHarnessState();
}

class _SelectHarnessState extends State<_SelectHarness> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EditorTheme(
        colors: EditorColors.dark,
        child: Scaffold(
          body: ThemedCanvas(
            theme: _theme,
            child: ScreenSurface(
              screen: _screen,
              nodes: widget.nodes,
              selectedNodeId: selected,
              onSelectNode: (id) {
                widget.calls.add(id);
                setState(() => selected = id);
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  List<CanvasNode> nodes,
  List<String> calls,
) async {
  await tester.pumpWidget(_SelectHarness(nodes: nodes, calls: calls));
  await tester.pumpAndSettle();
}

Future<void> _pumpSurface(WidgetTester tester, List<CanvasNode> nodes) async {
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
              onSelectNode: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PreviewPlayer(doc: doc))),
  );
  await tester.pumpAndSettle();
}

/// Flow geometry (same live measurement as fullbleed_test): stage =
/// scroll-viewport width; flow = stage − 2×screen padding; chrome (card) =
/// flow − 2×4px node padding.
double _stageWidth(WidgetTester tester) =>
    tester.getSize(find.byType(SingleChildScrollView).first).width;
double _flowWidth(WidgetTester tester) =>
    _stageWidth(tester) - 2 * kFlowScreenPadding;
double _chromeWidth(WidgetTester tester) => _flowWidth(tester) - 8.0;

void _useReferenceViewport(WidgetTester tester) {
  // Reference viewport: the phone frame overflows the default 800x600 test
  // surface (same rule as every other canvas widget test).
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('natural fill', () {
    testWidgets('auto card fills width and keeps intrinsic height', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(id: 'card1', kind: 'card', props: {'title': 'T'}),
      ]);
      final cardSize = tester.getSize(find.byType(shadcn.Card).first);
      expect(
        cardSize.width,
        moreOrLessEquals(_chromeWidth(tester), epsilon: 1.5),
        reason: 'auto card keeps filling the flow width (Z1 behavior stays)',
      );
      expect(
        cardSize.height,
        lessThan(250.0),
        reason: 'auto height stays intrinsic, never stretched',
      );
      expect(cardSize.height, greaterThan(10.0));
    });

    testWidgets('pinned-h box fills exactly, paint stays natural', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(id: 'card1', kind: 'card', w: 200, h: 120),
      ]);
      // The layout box (and selection chrome) is exactly the pin ...
      final box = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 200.0 && w.height == 120.0,
      );
      expect(box, findsWidgets);
      expect(tester.getSize(box.first), const Size(200, 120));
      // ... while the paint stays natural: full pinned width, intrinsic
      // height top-left (never stretched past the pin, never centered).
      final cardSize = tester.getSize(find.byType(shadcn.Card).first);
      expect(cardSize.width, moreOrLessEquals(200, epsilon: 1.0));
      expect(cardSize.height, lessThanOrEqualTo(120.0));
      expect(cardSize.height, greaterThan(10.0));
    });

    testWidgets('width-only pin fills width with intrinsic height', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(id: 'card1', kind: 'card', w: 200),
      ]);
      final cardSize = tester.getSize(find.byType(shadcn.Card).first);
      expect(cardSize.width, moreOrLessEquals(200, epsilon: 1.0));
      expect(
        cardSize.height,
        lessThan(200.0),
        reason: 'no height pin means no vertical stretch',
      );
    });

    testWidgets('tall content does not blow up (scrolls, stays finite)', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        for (var i = 0; i < 3; i++) _node(id: 't$i', kind: 'card', h: 350),
      ]);
      // Settles with no overflow errors (the post-test error check fails the
      // test on any reported overflow): every pinned box is exactly 350 tall
      // while the paint stays natural-intrinsic, and the stack scrolls.
      final boxes = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 350.0,
      );
      expect(boxes, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(boxes.at(i)).height, 350.0);
        final paint = tester.getSize(find.byType(shadcn.Card).at(i));
        expect(paint.width.isFinite, isTrue);
        expect(paint.height, lessThanOrEqualTo(350.0));
      }
      final scrollable = find.byType(Scrollable).first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0.0),
        reason: 'over-tall content scrolls inside the fixed frame',
      );
    });

    testWidgets('text content sits top-left natural', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(
          id: 'host',
          kind: 'scaffold',
          props: {'title': 'App', 'body': 'Welcome'},
        ),
      ]);
      // Scaffold chrome is a fixed 320px-tall box; the body text must ride
      // the top (builder start column + renderer top-left), never the
      // vertical middle.
      final scaffoldBox = tester.renderObject<RenderBox>(
        find.byType(shadcn.Scaffold).first,
      );
      final scaffoldTop = scaffoldBox.localToGlobal(Offset.zero).dy;
      final bodyTop = tester.getTopLeft(find.text('Welcome')).dy;
      expect(scaffoldBox.size.height, moreOrLessEquals(320, epsilon: 1.0));
      expect(
        bodyTop - scaffoldTop,
        lessThan(160.0),
        reason: 'body text rides near the top, not vertically centered',
      );
    });

    testWidgets('intrinsic kinds keep natural size left-aligned', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(id: 'av1', kind: 'avatar', props: {'initials': 'WD'}),
      ]);
      final avatarBox = tester.renderObject<RenderBox>(
        find.byType(shadcn.Avatar).first,
      );
      expect(avatarBox.size.width, lessThan(100));
      expect(avatarBox.size.width, greaterThan(20));
      final flowLeft = tester
              .getTopLeft(
                find.byType(SingleChildScrollView).first,
              )
              .dx +
          kFlowScreenPadding +
          4.0;
      expect(
        tester.getTopLeft(find.byType(shadcn.Avatar).first).dx,
        moreOrLessEquals(flowLeft, epsilon: 2.0),
      );
    });
  });

  group('slot injection (canvas)', () {
    testWidgets('slot-assigned root paints in the slot, never in flow', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      // Control: without slotNodes the root kid renders in the root flow.
      await _pumpSurface(tester, [
        _node(id: 'host', kind: 'card', props: {'title': 'Host'}),
        _node(id: 'kid', kind: 'button', props: {'label': 'Slot Kid'}),
      ]);
      expect(find.text('Slot Kid'), findsOneWidget);

      // With the slot assignment the kid leaves the root flow and paints
      // inside the host chrome through the shared slot contract (card
      // declares the `content` slot) — exactly once.
      await _pumpSurface(tester, [
        _node(
          id: 'host',
          kind: 'card',
          props: {'title': 'Host'},
          slotNodes: const {'content': 'kid'},
        ),
        _node(id: 'kid', kind: 'button', props: {'label': 'Slot Kid'}),
      ]);
      expect(find.text('Slot Kid'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Slot Kid'),
          matching: find.byType(shadcn.Card),
        ),
        findsOneWidget,
        reason: 'slot kid paints inside the host chrome, not in flow',
      );
    });

    testWidgets('slot-assigned parentId child renders exactly once', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(
          id: 'host',
          kind: 'card',
          props: {'title': 'Host'},
          slotNodes: const {'content': 'kid'},
        ),
        _node(
          id: 'kid',
          kind: 'button',
          props: {'label': 'Slot Kid'},
          parentId: 'host',
        ),
      ]);
      // Slot wins over flow: the kid paints via the slot prop, never
      // duplicated by the normal child splice.
      expect(find.text('Slot Kid'), findsOneWidget);
    });

    testWidgets('missing slot id is safe (host renders, no crash)', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(
          id: 'host',
          kind: 'card',
          props: {'title': 'Host'},
          slotNodes: const {'body': 'ghost'},
        ),
      ]);
      expect(find.text('Host'), findsOneWidget);
    });

    testWidgets('cyclic slots terminate (island rule)', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(id: 'h', kind: 'button', props: {'label': 'Healthy'}),
        _node(
          id: 'a',
          kind: 'card',
          props: {'title': 'A'},
          slotNodes: const {'x': 'b'},
        ),
        _node(
          id: 'b',
          kind: 'card',
          props: {'title': 'B'},
          parentId: 'a',
          slotNodes: const {'x': 'a'},
        ),
      ]).timeout(const Duration(seconds: 10));
      // Terminates with no crash; the healthy root is unaffected ...
      expect(find.text('Healthy'), findsOneWidget);
      // ... while the A↔B slot island renders nothing: every island member
      // is slot-assigned (flow withholds it) and no live host builds the
      // island — the same honesty rule as unreachable parentId cycles, which
      // never render either.
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
    });

    testWidgets('leaf and fallback paths accept slotNodes without crashing',
        (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(
          id: 'leaf',
          kind: 'button',
          props: {'label': 'Leaf'},
          slotNodes: const {'s': 'ghost'},
        ),
        _node(
          id: 'fb',
          kind: 'button',
          props: {'label': 'Fallback'},
          slotNodes: const {'s': 'ghost'},
        ),
        _node(
          id: 'fbkid',
          kind: 'badge',
          props: {'label': 'Fb Kid'},
          parentId: 'fb',
        ),
      ]);
      expect(find.text('Leaf'), findsOneWidget);
      expect(find.text('Fallback'), findsOneWidget);
      expect(find.text('Fb Kid'), findsOneWidget);
    });
  });

  group('slot injection (preview parity)', () {
    testWidgets('slot-assigned root paints in the slot, never in flow', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpPreview(
        tester,
        _doc([
          _node(id: 'host', kind: 'card', props: {'title': 'Host'}),
          _node(id: 'kid', kind: 'button', props: {'label': 'Slot Kid'}),
        ]),
      );
      expect(find.text('Slot Kid'), findsOneWidget);

      await _pumpPreview(
        tester,
        _doc([
          _node(
            id: 'host',
            kind: 'card',
            props: {'title': 'Host'},
            slotNodes: const {'content': 'kid'},
          ),
          _node(id: 'kid', kind: 'button', props: {'label': 'Slot Kid'}),
        ]),
      );
      // Canvas parity: paints inside the host chrome exactly once.
      expect(find.text('Slot Kid'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Slot Kid'),
          matching: find.byType(shadcn.Card),
        ),
        findsOneWidget,
      );
    });

    testWidgets('missing and cyclic slot ids are safe', (tester) async {
      _useReferenceViewport(tester);
      await _pumpPreview(
        tester,
        _doc([
          _node(
            id: 'host',
            kind: 'card',
            props: {'title': 'Host'},
            slotNodes: const {'body': 'ghost'},
          ),
          _node(
            id: 'a',
            kind: 'card',
            props: {'title': 'A'},
            slotNodes: const {'x': 'b'},
          ),
          _node(
            id: 'b',
            kind: 'card',
            props: {'title': 'B'},
            parentId: 'a',
            slotNodes: const {'x': 'a'},
          ),
        ]),
      ).timeout(const Duration(seconds: 10));
      expect(find.text('Host'), findsOneWidget);
      // Island rule (canvas parity): the A↔B slot island renders nothing —
      // every member is slot-assigned and no live host builds it.
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
    });
  });

  group('deep select', () {
    testWidgets('first click on a nested avatar selects the avatar', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final calls = <String>[];
      await _pumpHarness(
          tester,
          [
            _node(id: 'host', kind: 'card', props: {'title': 'Host'}),
            _node(
              id: 'av',
              kind: 'avatar',
              props: {'initials': 'WD'},
              parentId: 'host',
            ),
          ],
          calls);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['av']);
    });

    testWidgets('second click on the same spot drills out to the parent', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final calls = <String>[];
      await _pumpHarness(
          tester,
          [
            _node(id: 'host', kind: 'card', props: {'title': 'Host'}),
            _node(
              id: 'av',
              kind: 'avatar',
              props: {'initials': 'WD'},
              parentId: 'host',
            ),
          ],
          calls);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['av', 'host']);
    });

    testWidgets('deep select works three levels deep', (tester) async {
      _useReferenceViewport(tester);
      final calls = <String>[];
      await _pumpHarness(
          tester,
          [
            _node(id: 'l1', kind: 'card', props: {'title': 'L1'}),
            _node(
              id: 'l2',
              kind: 'outlined_container',
              props: {'label': 'L2'},
              parentId: 'l1',
            ),
            _node(
              id: 'l3',
              kind: 'avatar',
              props: {'initials': 'WD'},
              parentId: 'l2',
            ),
          ],
          calls);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['l3']);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['l3', 'l2']);
    });

    testWidgets('slot-nested avatar selects on first click (user repro)', (
      tester,
    ) async {
      // The reported shape: an avatar nested in a scaffold selects the
      // scaffold first and needs a second click. With slot injection the
      // avatar paints inside the scaffold `body` slot with its own chrome,
      // so the first click lands on the avatar and the second drills out.
      _useReferenceViewport(tester);
      final calls = <String>[];
      await _pumpHarness(
          tester,
          [
            _node(
              id: 'host',
              kind: 'scaffold',
              props: {'title': 'App', 'body': 'Welcome'},
              slotNodes: const {'body': 'av'},
            ),
            _node(
              id: 'av',
              kind: 'avatar',
              props: {'initials': 'WD'},
              parentId: 'host',
            ),
          ],
          calls);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['av']);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['av', 'host']);
    });
  });

  group('lock-skip', () {
    testWidgets('locked node tap falls through to the parent', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      final calls = <String>[];
      await _pumpHarness(
          tester,
          [
            _node(id: 'host', kind: 'card', props: {'title': 'Host'}),
            _node(
              id: 'av',
              kind: 'avatar',
              props: {'initials': 'WD'},
              parentId: 'host',
              locked: true,
            ),
          ],
          calls);
      await tester.tap(find.byType(shadcn.Avatar));
      await tester.pump();
      expect(calls, ['host']);
      expect(calls, isNot(contains('av')));
    });

    testWidgets('locked root tap selects nothing', (tester) async {
      _useReferenceViewport(tester);
      final calls = <String>[];
      await _pumpHarness(
          tester,
          [
            _node(
              id: 'btn',
              kind: 'button',
              props: {'label': 'Locked'},
              locked: true,
            ),
          ],
          calls);
      await tester.tap(find.text('Locked'));
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('locked nodes render identical paint (no badge, no dim)', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpSurface(tester, [
        _node(id: 'av', kind: 'avatar', props: {'initials': 'WD'}),
      ]);
      final unlocked = tester.getSize(find.byType(shadcn.Avatar));
      await _pumpSurface(tester, [
        _node(
          id: 'av',
          kind: 'avatar',
          props: {'initials': 'WD'},
          locked: true,
        ),
      ]);
      final lockedSize = tester.getSize(find.byType(shadcn.Avatar));
      expect(lockedSize, unlocked);
      expect(find.byIcon(Icons.lock), findsNothing);
    });
  });
}
