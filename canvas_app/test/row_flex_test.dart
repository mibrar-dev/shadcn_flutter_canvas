/// Track U2 row flex rules + the reported squeeze regression.
///
/// SQUEEZE (user-observed): two parts side-by-side in a row rendered
/// ~45px each with letter-by-letter text wrap instead of sharing space.
/// Root cause: the old [wrapRowChild] default (`Flexible`, loose fit) let
/// shrink-wrapping content collapse to its minimum intrinsic width. The fix
/// pins the default to tight equal shares ([Expanded]).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenDoc _rowDoc(List<Map<String, dynamic>> nodes) => ScreenDoc.fromJson({
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
      'meta': {'title': 'Flex', 'brief': ''},
    });

/// The reported squeeze shape: a row holding two small-intrinsic parts
/// (badges ≈ 45px intrinsic each).
ScreenDoc _squeezeDoc() => _rowDoc([
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
    ]);

void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _autoKid = CanvasNode(
  id: 'k',
  screenId: 's1',
  x: 0,
  y: 0,
  items: [],
);

void main() {
  group('wrapRowChild rule', () {
    test('null-width default is tight Flexible with flex 1 (equal shares)',
        () {
      final wrapped = wrapRowChild(_autoKid, const SizedBox());
      expect(wrapped, isA<Flexible>());
      // Tight fit (shares like Expanded) but exact runtime type Flexible
      // (pinned by container_layout_test.dart).
      expect(wrapped, isNot(isA<Expanded>()));
      final flex = wrapped as Flexible;
      expect(flex.flex, 1);
      expect(flex.fit, FlexFit.tight);
    });

    test('explicit flex without expand is honored (was pinned to 1)', () {
      const kid = CanvasNode(
        id: 'k',
        screenId: 's1',
        x: 0,
        y: 0,
        items: [],
        flex: 3,
      );
      final wrapped = wrapRowChild(kid, const SizedBox());
      expect(wrapped, isA<Flexible>());
      final flex = wrapped as Flexible;
      expect(flex.flex, 3);
      expect(flex.fit, FlexFit.tight);
    });

    test('expanded → Expanded, flex → loose Flexible, none → tight Flexible',
        () {
      const expanded = CanvasNode(
        id: 'e',
        screenId: 's1',
        x: 0,
        y: 0,
        items: [],
        expand: 'expanded',
        flex: 2,
      );
      const flex = CanvasNode(
        id: 'f',
        screenId: 's1',
        x: 0,
        y: 0,
        items: [],
        expand: 'flex',
      );
      const none = CanvasNode(
        id: 'n',
        screenId: 's1',
        x: 0,
        y: 0,
        items: [],
        expand: 'none',
      );
      const child = SizedBox();
      expect((wrapRowChild(expanded, child) as Expanded).flex, 2);
      final loose = wrapRowChild(flex, child) as Flexible;
      expect(loose, isNot(isA<Expanded>()));
      expect(loose.fit, FlexFit.loose);
      final tight = wrapRowChild(none, child) as Flexible;
      expect(tight, isNot(isA<Expanded>()));
      expect(tight.fit, FlexFit.tight);
    });

    test('fixed w bypasses flex with exact pixels (beats expand)', () {
      const kid = CanvasNode(
        id: 'k',
        screenId: 's1',
        x: 0,
        y: 0,
        items: [],
        expand: 'expanded',
        flex: 2,
        w: 100,
      );
      final wrapped = wrapRowChild(kid, const SizedBox());
      expect(wrapped, isA<SizedBox>());
      expect((wrapped as SizedBox).width, 100.0);
    });
  });

  group('applyNodeSize', () {
    test('auto passes content through untouched', () {
      const child = SizedBox();
      expect(applyNodeSize(_autoKid, child), same(child));
      expect(applyNodeSizeValues(null, null, child), same(child));
    });

    // Track X1 fill: pinned dims wrap in a SizedBox whose child FILLS the
    // box (stretch column + Expanded), so kit surfaces paint at the pinned
    // size instead of shrinking intrinsic top-left. Updated from the old
    // `child same` pin when the fill rule landed.
    test('fixed dims wrap in a filling SizedBox', () {
      const child = SizedBox();
      const kid = CanvasNode(
        id: 'k',
        screenId: 's1',
        x: 0,
        y: 0,
        items: [],
        w: 120,
        h: 80,
      );
      final wrapped = applyNodeSize(kid, child) as SizedBox;
      expect(wrapped.width, 120.0);
      expect(wrapped.height, 80.0);
      final column = wrapped.child! as Column;
      expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
      final expanded = column.children.single as Expanded;
      expect(expanded.child, same(child));
    });

    test('width-only pin stretches with intrinsic height (no Expanded)', () {
      const child = SizedBox();
      final wrapped = applyNodeSizeValues(120, null, child) as SizedBox;
      expect(wrapped.width, 120.0);
      expect(wrapped.height, isNull);
      final column = wrapped.child! as Column;
      expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
      expect(column.mainAxisSize, MainAxisSize.min);
      expect(column.children.single, same(child));
    });
  });

  group('handle drag math (pure)', () {
    test('resizeDeltaToLocal divides by zoom', () {
      expect(resizeDeltaToLocal(20, 1.0), 20.0);
      expect(resizeDeltaToLocal(20, 2.0), 10.0);
      expect(resizeDeltaToLocal(-8, 4.0), -2.0);
    });

    test('non-positive zoom falls back to unscaled (no divide by zero)', () {
      expect(resizeDeltaToLocal(20, 0.0), 20.0);
      expect(resizeDeltaToLocal(20, -2.0), 20.0);
    });

    test('clamps pin to [floor, stage]', () {
      expect(clampResizeWidth(200, 390), 200.0);
      expect(clampResizeWidth(10, 390), kMinNodeSize);
      expect(clampResizeWidth(5000, 390), 390.0);
      expect(clampResizeHeight(200, 709), 200.0);
      expect(clampResizeHeight(10, 709), kMinNodeSize);
      expect(clampResizeHeight(5000, 709), 709.0);
    });

    test('degenerate stage max clamps to the floor itself', () {
      expect(clampResizeWidth(10, 20), kMinNodeSize);
      expect(clampResizeHeight(10, 20), kMinNodeSize);
    });
  });

  group('squeeze regression (widget)', () {
    // Geometry (phone stage): content 390 − 32 padding = 358; row chrome
    // padding 8 → 350 strip; gap 8 → two equal cells of 171 each. Cell
    // lefts are measured instead of content widths on purpose: badges keep
    // their intrinsic size inside the cell (they must NOT stretch), so only
    // cell positions prove equal sharing — and they are kit-internals-proof.
    testWidgets('two auto row children share width equally', (tester) async {
      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _squeezeDoc());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      final firstX = tester.getTopLeft(find.text('Alpha')).dx;
      final secondX = tester.getTopLeft(find.text('Beta')).dx;
      // Equal 171px cells + 8px gap: the second cell starts ~179px right of
      // the first (the pre-fix loose-Flexible huddle sat at ~81px).
      expect(secondX - firstX, greaterThan(150));
      expect(secondX - firstX, lessThan(200));
      // Content keeps its natural size inside the share (no stretch, and —
      // with 171px cells — no letter-by-letter wrap either).
      expect(
        tester.getSize(find.byType(shadcn.PrimaryBadge).at(0)).width,
        lessThan(100),
      );
      expect(
        tester.getSize(find.byType(shadcn.PrimaryBadge).at(1)).width,
        lessThan(100),
      );
    });

    testWidgets('fixed-w row child takes exact pixels', (tester) async {
      _useReferenceViewport(tester);
      final doc = _squeezeDoc();
      final sized = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                w: 100.0,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: sized);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();

      // Cell + content layering: both pin width 100 (see [_rowCell] and
      // [_nodeChrome] — the outer box defeats flex, the inner pins content).
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 100.0,
        ),
        findsWidgets,
      );
      // 100px fixed cell + 8px gap: the sibling starts ~108px right.
      // Track X1 note: the fixed-w cell now FILLS (badge paint stretches to
      // the 92px chrome interior) and the badge centers its label, so the
      // Alpha text sits ~13px further right than the old intrinsic badge
      // did. The cell geometry is unchanged (SizedBox pin above); only this
      // text-position proxy shifted, so the lower bound moves 95 → 85. The
      // squeeze regression would still read ~53px here.
      final firstX = tester.getTopLeft(find.text('Alpha')).dx;
      final secondX = tester.getTopLeft(find.text('Beta')).dx;
      expect(secondX - firstX, greaterThan(85));
      expect(secondX - firstX, lessThan(125));
    });

    testWidgets('fixed h renders an exact-height box', (tester) async {
      _useReferenceViewport(tester);
      final doc = _squeezeDoc();
      final sized = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                h: 90.0,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: sized);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 90.0,
        ),
        findsOneWidget,
      );
    });

    testWidgets('oversize fixed widths overflow visibly (no scroll/clip)',
        (tester) async {
      // Overflow decision (documented on [CanvasNode]): fixed widths wider
      // than the strip overflow VISIBLY — an honest authoring signal. No
      // scrolling (unbounded width would detonate tight flex and kit
      // internals) and no clipping (clip hides content without silencing the
      // report). The RenderFlex overflow report IS the pin: a scrolled or
      // clipped row would lay out clean and report nothing.
      _useReferenceViewport(tester);
      final doc = _squeezeDoc();
      final sized = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c1' || n.id == 'c2')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                w: 300.0,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final store = CanvasStore(initial: sized);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pump();
      // Both fixed cells still build at exact pixels (nothing clipped away).
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 300.0,
        ),
        findsWidgets,
      );
      final error = tester.takeException();
      expect(error, isNotNull);
      expect('$error', contains('overflowed'));
    });

    testWidgets('row crossAxis still defaults to center', (tester) async {      _useReferenceViewport(tester);
      final store = CanvasStore(initial: _squeezeDoc());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DesignCanvas(store: store))),
      );
      await tester.pumpAndSettle();

      Row? row;
      tester.element(find.text('Alpha')).visitAncestorElements((el) {
        if (row == null && el.widget is Row) row = el.widget as Row;
        return row == null;
      });
      expect(row, isNotNull);
      expect(row!.crossAxisAlignment, CrossAxisAlignment.center);
    });
  });
}
