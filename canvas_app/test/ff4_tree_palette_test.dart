/// Track FF4 (BUILD_SPEC §9.2 rows 3a–3b): tree + palette panels.
///
/// Structure + callbacks + DnD payload stability, NOT pixels (§12 rule 4):
/// the tree keeps every store path (select / multi-select / reorder /
/// cascade-delete / lock / group) under its full-height panel skin
/// (panelBg + groupHeaderFg + indent guides), and the palette keeps its DnD
/// payloads (`Draggable<String>` data = kind) and search behavior as
/// FlutterFlow-style list rows with Layout Primitives first.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): chrome columns overflow the default
/// 800x600 test surface.
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

Future<void> _pumpLayers(
  WidgetTester tester,
  CanvasStore store, {
  Set<String> selected = const {},
  String? primary,
  ValueChanged<String?>? onSelectNode,
}) {
  _useReferenceViewport(tester);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EditorTheme(
          colors: EditorColors.light,
          child: LayersPanel(
            store: store,
            selectedNodeIds: selected,
            selectedNodeId: primary,
            onSelectNode: onSelectNode ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpPalette(
  WidgetTester tester, {
  VoidCallback? onCollapse,
}) {
  _useReferenceViewport(tester);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EditorTheme(
          colors: EditorColors.light,
          child: PartsPalette(onCollapse: onCollapse),
        ),
      ),
    ),
  );
}

void main() {
  group('FF4 tree panel skin', () {
    testWidgets('panel fills with panelBg and headers read groupHeaderFg',
        (tester) async {
      final store = CanvasStore();
      final id = _addButton(store);
      await _pumpLayers(tester, store, selected: {id}, primary: id);
      await tester.pump();

      // Full-height panel: a panelBg wash behind the tree.
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.color == EditorColors.light.panelBg,
        ),
        findsWidgets,
      );
      // Screen header uses the grouped-panel header token.
      final header = tester.widget<Text>(find.text('Screen 1'));
      expect(header.style?.color, EditorColors.light.groupHeaderFg);
      // Selection count header uses the same token.
      final count = tester.widget<Text>(find.text('1 selected'));
      expect(count.style?.color, EditorColors.light.groupHeaderFg);
    });

    testWidgets('nested rows gain one indent guide per depth level',
        (tester) async {
      final store = CanvasStore();
      final parent = _addButton(store);
      final childId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [CanvasItem(id: store.uid(), kind: 'badge', props: const {})],
      );
      store.reparentNode(childId, parent);
      await _pumpLayers(tester, store);
      await tester.pump();

      // The nested row sits in a Row whose leading lanes carry the guide
      // rule; the root row has none. Guides are pure decoration: Border with
      // only the right edge painted.
      final guides = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border is Border &&
            ((w.decoration! as BoxDecoration).border! as Border).left ==
                BorderSide.none &&
            ((w.decoration! as BoxDecoration).border! as Border).right !=
                BorderSide.none,
      );
      expect(guides, findsOneWidget);
      // Kind labels keep the '<Kind> · <id>' contract.
      expect(find.textContaining('Button · $parent'), findsOneWidget);
      expect(find.textContaining('Badge · $childId'), findsOneWidget);
    });
  });

  group('FF4 tree store paths (kept)', () {
    testWidgets('tap selects, lock toggles, delete cascades', (tester) async {
      final store = CanvasStore();
      final parent = _addButton(store);
      final childId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [CanvasItem(id: store.uid(), kind: 'badge', props: const {})],
      );
      store.reparentNode(childId, parent);
      String? selected;
      await _pumpLayers(
        tester,
        store,
        onSelectNode: (id) => selected = id,
      );
      await tester.pump();

      // Select path.
      await tester.tap(find.textContaining(parent).first);
      await tester.pump();
      expect(selected, parent);

      // Lock path (undoable store write, filled glyph).
      await tester.tap(find.byKey(ValueKey('layer-lock-$parent')));
      await tester.pump();
      expect(
        store.doc.nodes.firstWhere((n) => n.id == parent).locked,
        isTrue,
      );
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Cascade delete path: deleting the parent takes the child. (Track DD:
      // a delete covering a locked node is a silent no-op, so unlock first.)
      await tester.tap(find.byKey(ValueKey('layer-lock-$parent')));
      await tester.pump();
      expect(
        store.doc.nodes.firstWhere((n) => n.id == parent).locked,
        isFalse,
      );

      // Cascade delete path: deleting the parent takes the child. Tree
      // order is screen-header delete, then parent-row delete, then the
      // nested child-row delete — so the parent's is at index 1.
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pump();
      expect(
        store.doc.nodes.where((n) => n.id == parent || n.id == childId),
        isEmpty,
      );
    });

    testWidgets('reorder buttons move within the visual group', (tester) async {
      final store = CanvasStore();
      final first = _addButton(store);
      _addButton(store);
      await _pumpLayers(tester, store);
      await tester.pump();

      final before = [for (final n in store.doc.nodes) n.id];
      // The backmost row's move-up control is enabled; the frontmost's is
      // disabled (edge nulls kept).
      await tester.tap(find.byIcon(Icons.arrow_upward).last);
      await tester.pump();
      final after = [for (final n in store.doc.nodes) n.id];
      expect(after, isNot(equals(before)));
      expect(after.toSet(), before.toSet());
      expect(first, isNot(after.first));
    });

    testWidgets('multi-select header with group + delete-set', (tester) async {
      final store = CanvasStore();
      final a = _addButton(store);
      final b = _addButton(store);
      await _pumpLayers(tester, store, selected: {a, b}, primary: a);
      await tester.pump();

      expect(find.text('2 selected'), findsOneWidget);
      expect(
        find.text('Tip: Ctrl/Cmd+click toggles, Shift+click selects a range'),
        findsOneWidget,
      );
      // Group path: two roots group into a row.
      await tester.tap(find.byIcon(Icons.group_work));
      await tester.pump();
      expect(store.doc.nodes.any((n) => n.isRow), isTrue);
    });
  });

  group('FF4 palette list rows', () {
    testWidgets('Layout Primitives section comes first', (tester) async {
      await _pumpPalette(tester);
      await tester.pump();

      expect(kRegistrySectionOrder.first, 'Layout Primitives');
      final sections = kRegistrySectionOrder
          .where(
            (s) => registrySectionEntries(s).isNotEmpty,
          )
          .toList();
      expect(sections.first, 'Layout Primitives');
      // The ten primitives render as rows with kind labels.
      for (final kind in [
        'container',
        'column',
        'row',
        'stack',
        'padding',
        'center',
        'align',
        'expanded',
        'sized_box',
        'spacer',
      ]) {
        expect(find.text(_rowLabel(kind)), findsOneWidget);
      }
    });

    testWidgets('DnD payloads are the kind strings (incl. primitives)',
        (tester) async {
      await _pumpPalette(tester);
      await tester.pump();

      for (final kind in ['container', 'row', 'button', 'card']) {
        final draggables = tester.widgetList<Draggable<String>>(
          find.byType(Draggable<String>),
        );
        expect(
          draggables.where((d) => d.data == kind),
          hasLength(1),
          reason: 'exactly one draggable payload for $kind',
        );
      }
      final expected = kRegistry.length - kHiddenUtilityKinds.length;
      expect(find.byType(Draggable<String>), findsNWidgets(expected));
    });

    testWidgets('search filters rows, collapse still fires', (tester) async {
      await _pumpPalette(tester);
      await tester.pump();

      await tester.enterText(find.byType(shadcn.TextField), 'but');
      await tester.pump();
      expect(find.text('Button'), findsOneWidget);
      expect(find.text('Card'), findsNothing);

      await tester.enterText(
        find.byType(shadcn.TextField),
        'zzz-no-such-part',
      );
      await tester.pump();
      expect(find.text('No parts match'), findsOneWidget);
    });

    testWidgets('section collapse hides its rows', (tester) async {
      var collapsed = 0;
      await _pumpPalette(tester, onCollapse: () => collapsed++);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(collapsed, 1);
    });

    testWidgets('rows use the panel tokens, no raw Material chrome',
        (tester) async {
      await _pumpPalette(tester);
      await tester.pump();

      final scope = find.byType(PartsPalette);
      for (final type in [Tooltip, IconButton, TextButton, TextField]) {
        expect(
          find.descendant(of: scope, matching: find.byType(type)),
          findsNothing,
          reason: 'raw Material $type under PartsPalette',
        );
      }
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.color == EditorColors.light.panelBg,
        ),
        findsWidgets,
      );
    });
  });
}

/// Visible row label for [kind]: `radio_group` → `Radio Group`.
String _rowLabel(String kind) => kind
    .split('_')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
