/// Track Y5 (FORGE.md §5): inspector + code-peek tests.
///
/// Covers the right-aside 4-pill header (Design | Code | Prompt | Audit)
/// — pills switch tabs while the auto-switch rule (selection → Design,
/// else Prompt; Code/Audit manual-only) is preserved — the Forge SELECTED
/// card (kind · id header, existing editors still hitting `patchItem`,
/// Duplicate/Delete pass-through firing with the node id), and the
/// read-only code-peek (renders whole-doc generator output, regenerates on
/// open/selection-change/Refresh but never on doc edits alone, empty-doc
/// state, Copy sink call-through).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/code_peek.dart';
import 'package:canvas_app/ui/export_panel.dart' show buildExportSingleFile;
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/prompt_panel.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test doc: one `card` node on s1 (the FORGE.md §5 contract shape: card
/// with a title), plus the generated node id and the item id.
(CanvasStore, String, String) _storeWithCard() {
  final store = CanvasStore();
  const itemId = 'card_item';
  final nodeId = store.addNode(
    screenId: 's1',
    x: 0,
    y: 0,
    items: const [
      CanvasItem(
        id: itemId,
        kind: 'card',
        props: {
          'title': 'Kyoto in autumn',
          'description': 'A quiet temple garden.',
          'showFooter': false,
        },
      ),
    ],
  );
  return (store, nodeId, itemId);
}

Future<void> _pumpAside(
  WidgetTester tester,
  CanvasStore store, {
  String? nodeId,
  String? itemId,
  ValueChanged<String>? onDuplicate,
  ValueChanged<String>? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: RightAside(
            store: store,
            nodeId: nodeId,
            itemId: itemId,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpPeek(
  WidgetTester tester,
  ScreenDoc doc, {
  String? nodeId,
  String? itemId,
  Future<void> Function(String text)? onCopy,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 600,
          child: CodePeek(
            doc: doc,
            nodeId: nodeId,
            itemId: itemId,
            onCopy: onCopy,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

String _peekCode(WidgetTester tester) =>
    tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('code-peek-code')),
        )
        .data ??
    '';

/// Finder for a pill label scoped to its tab segment (the Prompt/Audit
/// labels also appear inside their tab bodies, so bare `find.text` would
/// be ambiguous).
Finder _pillLabel(String tabKey, String label) => find.descendant(
      of: find.byKey(ValueKey(tabKey)),
      matching: find.text(label),
    );

void main() {
  group('four-pill header', () {
    testWidgets('renders Design, Code, Prompt, and Audit pills', (
      tester,
    ) async {
      await _pumpAside(tester, CanvasStore());

      expect(_pillLabel('aside-tab-design', 'Design'), findsOneWidget);
      expect(_pillLabel('aside-tab-code', 'Code'), findsOneWidget);
      expect(_pillLabel('aside-tab-prompt', 'Prompt'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('aside-tab-audit')),
          matching: find.textContaining('Audit'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pills switch tabs', (tester) async {
      final (store, _, _) = _storeWithCard();
      await _pumpAside(tester, store);

      // No selection lands on Prompt (auto-switch preserved).
      expect(find.byType(PromptPanel), findsOneWidget);
      expect(find.byType(InspectorPanel), findsNothing);

      await tester.tap(find.byKey(const ValueKey('aside-tab-design')));
      await tester.pump();
      expect(find.byType(InspectorPanel), findsOneWidget);
      expect(
        find.text('Select an item to edit its props'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('aside-tab-code')));
      await tester.pump();
      expect(find.byType(CodePeek), findsOneWidget);
      // No selection: the peek header says so, the code still renders.
      expect(find.text('No selection'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('code-peek-code')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('aside-tab-prompt')));
      await tester.pump();
      expect(find.byType(PromptPanel), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('aside-tab-audit')));
      await tester.pump();
      expect(find.byType(AuditPanel), findsOneWidget);
    });

    testWidgets('selection auto-opens Design, never Code or Audit', (
      tester,
    ) async {
      final (store, nodeId, itemId) = _storeWithCard();
      await _pumpAside(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.byType(InspectorPanel), findsOneWidget);
      expect(find.byType(CodePeek), findsNothing);
      expect(find.byType(AuditPanel), findsNothing);
    });
  });

  group('SELECTED card', () {
    testWidgets('header shows kind · id', (tester) async {
      final (store, nodeId, itemId) = _storeWithCard();
      await _pumpAside(tester, store, nodeId: nodeId, itemId: itemId);

      // The header text is asserted through its key: the inspector's
      // parent picker legitimately renders the same `Kind · id` label for
      // the node itself, so a bare `find.text` would match twice.
      final header = tester.widget<Text>(
        find.byKey(const ValueKey('inspector-selected-header')),
      );
      expect(header.data, 'Card · $nodeId');
    });

    testWidgets('existing title editor still patches the store', (
      tester,
    ) async {
      final (store, nodeId, itemId) = _storeWithCard();
      await _pumpAside(tester, store, nodeId: nodeId, itemId: itemId);

      // Card schema order is title-then-description, so the first field is
      // the TITLE editor.
      await tester.enterText(
        find.byType(shadcn.TextField).first,
        'Osaka at night',
      );
      await tester.pump();

      final props = store.doc.nodes
          .singleWhere((n) => n.id == nodeId)
          .items
          .singleWhere((i) => i.id == itemId)
          .props;
      expect(props['title'], 'Osaka at night');
    });

    testWidgets('Duplicate/Delete fire with the node id, store untouched', (
      tester,
    ) async {
      final (store, nodeId, itemId) = _storeWithCard();
      final duplicated = <String>[];
      final deleted = <String>[];
      await _pumpAside(
        tester,
        store,
        nodeId: nodeId,
        itemId: itemId,
        onDuplicate: duplicated.add,
        onDelete: deleted.add,
      );

      await tester.tap(find.byKey(const ValueKey('inspector-duplicate')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('inspector-delete')));
      await tester.pump();

      // Pass-through only: the shell owns the store calls (wired in Y6),
      // so the doc is unchanged and each callback saw the node id once.
      expect(duplicated, [nodeId]);
      expect(deleted, [nodeId]);
      expect(store.doc.nodes.map((n) => n.id), [nodeId]);
    });
  });

  group('code peek', () {
    testWidgets('renders whole-doc generated code with selection header', (
      tester,
    ) async {
      final (store, nodeId, itemId) = _storeWithCard();
      await _pumpPeek(tester, store.doc, nodeId: nodeId, itemId: itemId);

      expect(find.text('Card · $nodeId'), findsOneWidget);
      expect(_peekCode(tester), buildExportSingleFile(store.doc));
    });

    testWidgets('regenerates on selection change, never on doc edits alone',
        (tester) async {
      final (store, nodeId, itemId) = _storeWithCard();
      await _pumpPeek(tester, store.doc, nodeId: nodeId, itemId: itemId);
      final firstCode = _peekCode(tester);

      // A doc edit with the same selection leaves the peek stale by
      // design (FORGE.md §4.3 — no per-keystroke whole-doc codegen).
      store.patchItem(nodeId, itemId, props: const {'title': 'Edited'});
      await _pumpPeek(tester, store.doc, nodeId: nodeId, itemId: itemId);
      expect(_peekCode(tester), firstCode);
      expect(_peekCode(tester), isNot(buildExportSingleFile(store.doc)));

      // Selecting another node regenerates (fresh code + new header).
      final otherId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 64,
        items: const [
          CanvasItem(id: 'other_item', kind: 'button', props: {}),
        ],
      );
      await _pumpPeek(
        tester,
        store.doc,
        nodeId: otherId,
        itemId: 'other_item',
      );
      expect(_peekCode(tester), buildExportSingleFile(store.doc));
      expect(find.text('Button · $otherId'), findsOneWidget);
    });

    testWidgets('Refresh regenerates after doc edits', (tester) async {
      final (store, nodeId, itemId) = _storeWithCard();
      await _pumpPeek(tester, store.doc, nodeId: nodeId, itemId: itemId);

      // The store edit flows into the widget through a parent rebuild
      // (as in RightAside), which alone must NOT regenerate ...
      store.patchItem(nodeId, itemId, props: const {'title': 'Edited'});
      await _pumpPeek(tester, store.doc, nodeId: nodeId, itemId: itemId);
      expect(_peekCode(tester), isNot(contains('Edited')));

      // ... but Refresh does.
      await tester.tap(find.byKey(const ValueKey('code-peek-refresh')));
      await tester.pump();

      expect(_peekCode(tester), buildExportSingleFile(store.doc));
      expect(_peekCode(tester), contains('Edited'));
    });

    testWidgets('Copy forwards the generated code to the sink', (
      tester,
    ) async {
      final (store, nodeId, itemId) = _storeWithCard();
      final copied = <String>[];
      await _pumpPeek(
        tester,
        store.doc,
        nodeId: nodeId,
        itemId: itemId,
        onCopy: (text) async {
          copied.add(text);
        },
      );

      await tester.tap(find.byKey(const ValueKey('code-peek-copy')));
      await tester.pump();
      await tester.pump();

      expect(copied, [buildExportSingleFile(store.doc)]);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('empty doc shows the empty state', (tester) async {
      final base = CanvasStore.emptyDoc();
      final empty = ScreenDoc(
        screens: const [],
        nodes: const [],
        theme: base.theme,
        meta: base.meta,
      );
      await _pumpPeek(tester, empty);

      expect(
        find.text('Nothing to export yet — add a screen first.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('code-peek-code')),
        findsNothing,
      );
    });
  });
}
