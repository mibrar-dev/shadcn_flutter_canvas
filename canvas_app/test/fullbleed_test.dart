/// Track Z1 full-bleed stretch: root widgets fill the phone flow width.
///
/// FlutterFlow behavior: root widgets stretch full width by default. Pre-Z1
/// the screen flow Column used `crossAxisAlignment.start` and nodes rendered
/// intrinsic, so dropped cards/inputs sat as a narrow left-aligned column.
/// Z1 stretches the flow + content columns; fixed-w keeps exact pixels
/// left-aligned inside the stretch wrapper (outer chrome fills, pinned box
/// sits top-left); row equal-share flex is preserved inside rows.
///
/// Stretch rules (documented on `phone_frame.dart`):
/// * Root flow Column → `CrossAxisAlignment.stretch` (every root wrapper
///   fills flow width = stage − 2×screen padding).
/// * Leaf/container/fallback content columns → always stretch (auto fills;
///   fixed-w keeps pixels via the `_nodeChrome` left wrapper, which converts
///   tight to loose when the pin fits and shrinks without flex-overflow when
///   oversized).
/// * `_nodeChrome` outer `width: double.infinity` so nested children fill
///   builder-owned `start` slots too.
/// * Rows unchanged (horizontal flex shares via `wrapRowChild`; only the
///   vertical cross-axis changed). Preview stage mirrors the same columns.
///
/// Layout only — no light+dark variants needed.
library;

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/device_picker.dart';
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

/// Flow geometry is measured live (the editor frame frees bezel pixels to
/// the screen, so the stage is ~397px, not the 390px spec): stage =
/// scroll-viewport width; flow = stage − 2×screen padding; chrome (card)
/// = flow − 2×4px node padding.
double _stageWidth(WidgetTester tester) =>
    tester.getSize(find.byType(SingleChildScrollView).first).width;
double _flowWidth(WidgetTester tester) =>
    _stageWidth(tester) - 2 * kFlowScreenPadding;
double _chromeWidth(WidgetTester tester) => _flowWidth(tester) - 8.0;

CanvasNode _node({
  required String id,
  required String kind,
  Map<String, dynamic> props = const {},
  String? parentId,
  bool isRow = false,
  double gap = 8.0,
  double? w,
  double? h,
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
      gap: gap,
      w: w,
      h: h,
    );

Future<void> _pumpSurface(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
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
              onSelectNode: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScreenDoc _doc(List<CanvasNode> nodes) => ScreenDoc(
      screens: const [
        CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
      ],
      nodes: nodes,
      theme: _theme,
      meta: const DocMeta(title: 'Fullbleed', brief: ''),
    );

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PreviewPlayer(doc: doc))),
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
  group('canvas full-bleed (flow stretch)', () {
    testWidgets('root card fills flow width', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(
        tester,
        nodes: [
          _node(
            id: 'card1',
            kind: 'card',
            props: {'title': 'T', 'description': 'D'},
          ),
        ],
      );
      final cardWidth =
          tester.getSize(find.byType(shadcn.Card).first).width;
      expect(
        cardWidth,
        moreOrLessEquals(_chromeWidth(tester), epsilon: 1.5),
        reason: 'auto card should fill flow width minus chrome padding',
      );
    });

    testWidgets('input fills flow width', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(
        tester,
        nodes: [
          _node(
            id: 'in1',
            kind: 'input',
            props: {'placeholder': 'Type here'},
          ),
        ],
      );
      final fieldWidth =
          tester.getSize(find.byType(shadcn.TextField).first).width;
      expect(
        fieldWidth,
        moreOrLessEquals(_chromeWidth(tester), epsilon: 1.5),
        reason: 'auto input should fill flow minus chrome padding',
      );
    });

    testWidgets('nested container child fills', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(
        tester,
        nodes: [
          _node(id: 'host', kind: 'card', props: {'title': 'Host'}),
          _node(
            id: 'kid',
            kind: 'button',
            props: {'label': 'Nested'},
            parentId: 'host',
          ),
        ],
      );
      final cardWidth =
          tester.getSize(find.byType(shadcn.Card).first).width;
      expect(
        cardWidth,
        moreOrLessEquals(_chromeWidth(tester), epsilon: 1.5),
      );
      // The nested button lives inside the card's builder slot (16px card
      // padding each side) plus its own 4px chrome padding each side, so it
      // paints ~40px narrower than the outer card — but crucially it FILLS
      // the slot (>200px) instead of staying intrinsic (~100px).
      final buttonBox = tester.renderObject<RenderBox>(
        find.byType(shadcn.PrimaryButton).first,
      );
      expect(buttonBox.size.width, greaterThan(200));
      expect(buttonBox.size.width, lessThanOrEqualTo(cardWidth));
      expect(
        buttonBox.size.width,
        moreOrLessEquals(cardWidth - 40, epsilon: 3.0),
      );
    });

    testWidgets('fixed-w node keeps pixels left-aligned', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(
        tester,
        nodes: [
          _node(id: 'auto', kind: 'card', props: {'title': 'A'}),
          _node(id: 'fixed', kind: 'card', props: {'title': 'F'}, w: 200),
        ],
      );
      final cards = find.byType(shadcn.Card);
      expect(cards, findsNWidgets(2));
      final autoWidth = tester.getSize(cards.at(0)).width;
      final fixedWidth = tester.getSize(cards.at(1)).width;
      expect(autoWidth, moreOrLessEquals(_chromeWidth(tester), epsilon: 1.5));
      // Fixed-w keeps exact pixels via the left-aligned wrapper (SizedBox
      // wins inside the loose wrapper; outer chrome still fills).
      expect(fixedWidth, moreOrLessEquals(200, epsilon: 1.0));
      // Both left-align at the same x (flow left + chrome padding).
      final autoLeft = tester.getTopLeft(cards.at(0)).dx;
      final fixedLeft = tester.getTopLeft(cards.at(1)).dx;
      expect(fixedLeft, moreOrLessEquals(autoLeft, epsilon: 1.5));
    });

    testWidgets('intrinsic kinds keep natural size left-aligned', (tester) async {
      // Regression: stretch must not balloon fixed-geometry widgets — an
      // avatar root rendered at full flow width in a screenshot. Intrinsic
      // kinds stay natural-size, left-aligned at the flow edge.
      _useReferenceViewport(tester);
      await _pumpSurface(
        tester,
        nodes: [
          _node(id: 'av1', kind: 'avatar', props: {'initials': 'WD'}),
        ],
      );
      final avatarBox = tester.renderObject<RenderBox>(
        find.byType(shadcn.Avatar).first,
      );
      expect(avatarBox.size.width, lessThan(100));
      expect(avatarBox.size.width, greaterThan(20));
      final flowLeft = tester.getTopLeft(
        find.byType(SingleChildScrollView).first,
      ).dx + kFlowScreenPadding + 4.0;
      expect(
        tester.getTopLeft(find.byType(shadcn.Avatar).first).dx,
        moreOrLessEquals(flowLeft, epsilon: 2.0),
      );
    });

    testWidgets('row shares preserved', (tester) async {
      _useReferenceViewport(tester);
      await _pumpSurface(
        tester,
        nodes: [
          _node(id: 'r1', kind: 'row', isRow: true),
          _node(
            id: 'c1',
            kind: 'badge',
            props: {'label': 'Alpha'},
            parentId: 'r1',
          ),
          _node(
            id: 'c2',
            kind: 'badge',
            props: {'label': 'Beta'},
            parentId: 'r1',
          ),
        ],
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      final firstX = tester.getTopLeft(find.text('Alpha')).dx;
      final secondX = tester.getTopLeft(find.text('Beta')).dx;
      // Equal 171px cells + 8px gap → ~179px offset (same shares as the
      // squeeze fix; only the inner paint now fills its cell).
      expect(secondX - firstX, greaterThan(150));
      expect(secondX - firstX, lessThan(200));
    });
  });

  group('preview stage parity', () {
    testWidgets('preview card fills, fixed keeps, row shares', (
      tester,
    ) async {
      _useReferenceViewport(tester);
      await _pumpPreview(
        tester,
        _doc([
          _node(id: 'pcard', kind: 'card', props: {'title': 'P'}),
          _node(id: 'pfixed', kind: 'card', props: {'title': 'Q'}, w: 200),
          _node(id: 'prow', kind: 'row', isRow: true),
          _node(
            id: 'pc1',
            kind: 'badge',
            props: {'label': 'PAlpha'},
            parentId: 'prow',
          ),
          _node(
            id: 'pc2',
            kind: 'badge',
            props: {'label': 'PBeta'},
            parentId: 'prow',
          ),
        ]),
      );
      // Preview has no 4px chrome padding (ListView padding only), so the
      // auto card fills stage − 2×screen padding (preview stage is exactly
      // the 390px spec — no bezel freeing like the editor frame).
      final previewCardWidth =
          tester.getSize(find.byType(shadcn.Card).first).width;
      expect(
        previewCardWidth,
        moreOrLessEquals(
          specForScreenDevice(null).width - 2 * kFlowScreenPadding,
          epsilon: 2.0,
        ),
      );
      // Fixed-w keeps exact pixels left-aligned (Align wrapper).
      final fixedWidth =
          tester.getSize(find.byType(shadcn.Card).at(1)).width;
      expect(fixedWidth, moreOrLessEquals(200, epsilon: 1.0));
      // Row shares preserved in preview too.
      final firstX = tester.getTopLeft(find.text('PAlpha')).dx;
      final secondX = tester.getTopLeft(find.text('PBeta')).dx;
      expect(secondX - firstX, greaterThan(140));
      expect(secondX - firstX, lessThan(220));
    });
  });
}
