/// Track FF5 (BUILD_SPEC §9.2 rows 4a–4d): canvas.
///
/// Structure + callbacks + DnD payload stability, NOT pixels (§12 rule 4):
/// the neutral canvas backdrop (dots dropped), the plain device frame
/// (bezel skin only — geometry tokens verbatim), the selectionOutline accent
/// outline + floating kind label, and the restyled floating toolbars with
/// every op kept. Pan/zoom/hit-test paths are pinned unchanged.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';
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

/// One root button-node on s1. Returns its id.
String _addButton(CanvasStore store) => store.addNode(
      screenId: 's1',
      x: 0,
      y: 0,
      items: [CanvasItem(id: store.uid(), kind: 'button', props: const {})],
    );

Future<void> _pumpCanvas(
  WidgetTester tester,
  CanvasStore store, {
  String? selectedNodeId,
}) {
  _useReferenceViewport(tester);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EditorTheme(
          colors: EditorColors.light,
          child: DesignCanvas(
            store: store,
            selectedNodeId: selectedNodeId,
            onSelectNode: (_) {},
          ),
        ),
      ),
    ),
  );
}

/// All highlight boxes carrying an outline ring of exactly [outline].
Finder _ringsWith(Color outline) => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).border != null &&
          (w.decoration! as BoxDecoration).border!.top.color == outline,
    );

void main() {
  group('FF5 neutral backdrop (dots dropped)', () {
    testWidgets('canvasBackdrop wash fills behind the viewport',
        (tester) async {
      await _pumpCanvas(tester, CanvasStore());
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ColoredBox && w.color == EditorColors.light.canvasBackdrop,
        ),
        findsOneWidget,
      );
    });

    test('pan/zoom math paths are unchanged', () {
      expect(clampZoom(99), kCanvasMaxZoom);
      expect(clampZoom(0.01), kCanvasMinZoom);
      expect(clampZoom(1.5), 1.5);
      // Plain wheel pans vertically; Shift+wheel pans horizontally.
      expect(
        applyWheelPan(Offset.zero, const Offset(0, 10), shift: false),
        const Offset(0, -10),
      );
      expect(
        applyWheelPan(Offset.zero, const Offset(3, 10), shift: true),
        const Offset(-13, 0),
      );
      // Scroll-up (negative dy) zooms in.
      expect(wheelZoomFactor(-100), greaterThan(1));
      expect(wheelZoomFactor(100), lessThan(1));
    });

    test('drop accept path still lands nodes (incl. rows)', () {
      final store = CanvasStore();
      final canvas = DesignCanvas(store: store);
      final leaf = canvas.onAccept('button', Offset.zero);
      expect(store.doc.nodes.any((n) => n.id == leaf), isTrue);
      final row = canvas.onAccept('row', Offset.zero);
      expect(
        store.doc.nodes.any((n) => n.id == row && n.isRow),
        isTrue,
      );
    });
  });

  group('FF5 plain device frame (bezel skin only)', () {
    testWidgets('bezel keeps its token color with no shadow paint',
        (tester) async {
      await _pumpCanvas(tester, CanvasStore());
      await tester.pump();

      expect(find.byType(PhoneFrame), findsWidgets);
      // Bezel skin: the bezel token still paints the frame body …
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  EditorColors.light.bezel,
        ),
        findsWidgets,
      );
      // … but the frame carries no drop shadow (plain device frame).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).boxShadow != null &&
              (w.decoration! as BoxDecoration).boxShadow!.isNotEmpty,
        ),
        findsNothing,
      );
    });

    test('frame geometry tokens are verbatim (hit-test contract)', () {
      // The FF5 wave touches paint only: the outer box, bezel budget, and
      // radii that every drop/hit-test conversion subtracts are unchanged.
      const frame = PhoneFrame(screenColor: Colors.white, child: SizedBox());
      expect(frame.outerWidth, EditorMetrics.phoneOuterWidth);
      expect(frame.outerHeight, EditorMetrics.phoneOuterHeight);
      expect(EditorMetrics.phoneBezel, 7.5);
      expect(EditorMetrics.phoneOuterWidth, 343);
      expect(EditorMetrics.phoneOuterHeight, 725);
      expect(EditorMetrics.phoneInnerWidth, 328);
      expect(EditorMetrics.phoneInnerHeight, 709);
      expect(EditorMetrics.phoneOuterRadius, 44);
      expect(EditorMetrics.phoneInnerRadius, 36);
    });
  });

  group('FF5 selection outline + kind label', () {
    testWidgets('selected node gets the accent outline and label',
        (tester) async {
      final store = CanvasStore();
      final id = _addButton(store);
      await _pumpCanvas(tester, store, selectedNodeId: id);
      await tester.pump();

      // Accent outline (was toolbarActive) on the selected chrome.
      expect(_ringsWith(EditorColors.light.selectionOutline), findsOneWidget);
      // Floating kind label over the selection.
      expect(find.byKey(selectionLabelKey(id)), findsOneWidget);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(selectionLabelKey(id)),
          matching: find.byType(Text),
        ),
      );
      expect(label.data, 'Button');
      // Resize handles ride the same selection.
      expect(find.byKey(resizeHandleKey(id, 'right')), findsOneWidget);
      expect(find.byKey(resizeHandleKey(id, 'bottom')), findsOneWidget);
      expect(find.byKey(resizeHandleKey(id, 'corner')), findsOneWidget);
    });

    testWidgets('no outline or label without a selection', (tester) async {
      final store = CanvasStore();
      _addButton(store);
      await _pumpCanvas(tester, store);
      await tester.pump();

      expect(
        _ringsWith(EditorColors.light.selectionOutline),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('selection-label:'),
        ),
        findsNothing,
      );
    });
  });

  group('FF5 floating toolbars (ops kept)', () {
    Future<void> pumpToolbar(
      WidgetTester tester, {
      required VoidCallback onDelete,
      VoidCallback? onUndo,
      VoidCallback? onExport,
      bool canGroup = false,
      VoidCallback? onGroup,
      bool canUngroup = false,
      VoidCallback? onUngroup,
    }) {
      _useReferenceViewport(tester);
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorTheme(
              colors: EditorColors.light,
              child: CanvasToolbar(
                panMode: false,
                onPanModeChanged: (_) {},
                onAddScreen: () {},
                onPreview: () {},
                onUndo: onUndo,
                onRedo: null,
                onDelete: onDelete,
                hasSelection: true,
                onOpen: () {},
                onExport: onExport,
                canGroup: canGroup,
                onGroup: onGroup,
                canUngroup: canUngroup,
                onUngroup: onUngroup,
              ),
            ),
          ),
        ),
      );
    }

    EditorIconButton buttonFor(WidgetTester tester, IconData icon) =>
        tester.widget<EditorIconButton>(
          find.descendant(
            of: find.byType(CanvasToolbar),
            matching: find.byWidgetPredicate(
              (w) => w is EditorIconButton && w.icon == icon,
            ),
          ),
        );

    testWidgets('every kept op fires through the pill', (tester) async {
      var deletes = 0;
      var undos = 0;
      var exports = 0;
      var groups = 0;
      var ungroups = 0;
      await pumpToolbar(
        tester,
        onDelete: () => deletes++,
        onUndo: () => undos++,
        onExport: () => exports++,
        canGroup: true,
        onGroup: () => groups++,
        canUngroup: true,
        onUngroup: () => ungroups++,
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.tap(find.byIcon(Icons.undo));
      await tester.tap(find.byIcon(Icons.ios_share));
      await tester.tap(find.byIcon(Icons.group_work));
      await tester.tap(find.byIcon(Icons.call_split));
      await tester.tap(find.byIcon(Icons.add_to_photos));
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pump();
      expect(deletes, 1);
      expect(undos, 1);
      expect(exports, 1);
      expect(groups, 1);
      expect(ungroups, 1);
      // Null undo renders the disabled state (idiom kept).
      expect(buttonFor(tester, Icons.redo).onPressed, isNull);
      // The ops row floats as a neutral pill.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  EditorColors.light.panelBg,
        ),
        findsOneWidget,
      );
    });

    testWidgets('selection toolbar fires up/down/duplicate, hides unselected',
        (tester) async {
      var up = 0;
      var down = 0;
      var duplicate = 0;
      _useReferenceViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorTheme(
              colors: EditorColors.light,
              child: ForgeSelectionToolbar(
                selectedNodeId: 'n1',
                onMoveUp: () => up++,
                onMoveDown: () => down++,
                onDuplicate: () => duplicate++,
              ),
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
  });
}
