/// Track S2: layers-panel multi-select (toggle/range/collapse from the panel,
/// primary-ring vs secondary-tint highlight, count header, delete-set and
/// group call-through).
///
/// The harness below mimics the shell wiring in `lib/main.dart` (plain tap
/// collapses, Ctrl/Cmd-tap toggles, Shift-tap ranges via
/// `ui/selection_model.dart`; header actions commit through the same store
/// calls the shell uses) and spies on the header action callbacks.
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/selection_model.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three root button-nodes on s1 in doc order. Returns their ids.
List<String> _threeNodes(CanvasStore store) => [
      for (var i = 0; i < 3; i++)
        store.addNode(
          screenId: 's1',
          x: 0,
          y: i * 10.0,
          items: [
            CanvasItem(id: store.uid(), kind: 'button', props: const {}),
          ],
        ),
    ];

class _PanelHarness extends StatefulWidget {
  const _PanelHarness({
    required this.store,
    this.initialIds = const {},
    this.initialAnchor,
  });

  final CanvasStore store;
  final Set<String> initialIds;
  final String? initialAnchor;

  @override
  State<_PanelHarness> createState() => _PanelHarnessState();
}

class _PanelHarnessState extends State<_PanelHarness> {
  late Set<String> selected = Set<String>.of(widget.initialIds);
  late String? anchor = widget.initialAnchor;

  int groupCalls = 0;
  int ungroupCalls = 0;
  int deleteCalls = 0;

  /// Shell-style primary: anchor while selected, else first in doc order.
  String? _primary() {
    if (anchor != null && selected.contains(anchor)) return anchor;
    for (final n in widget.store.doc.nodes) {
      if (selected.contains(n.id)) return n.id;
    }
    return null;
  }

  void _apply(NodeTapSelection resolved) => setState(() {
        selected = resolved.ids;
        anchor = resolved.anchor;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: EditorTheme(
          colors: EditorColors.light,
          child: LayersPanel(
            store: widget.store,
            selectedNodeIds: selected,
            selectedNodeId: _primary(),
            onSelectNode: (id) => setState(() {
              selected = id == null ? <String>{} : {id};
              anchor = id;
            }),
            onToggleNode: (id) => _apply(
              resolveNodeTap(
                current: selected,
                anchor: anchor,
                doc: widget.store.doc,
                tappedId: id,
                additive: true,
              ),
            ),
            onRangeSelectNode: (id) => _apply(
              resolveNodeTap(
                current: selected,
                anchor: anchor,
                doc: widget.store.doc,
                tappedId: id,
                ranged: true,
              ),
            ),
            onGroupSelection: () {
              groupCalls++;
              final rowId = widget.store.groupIntoRow(selected.toList());
              setState(() {
                selected = {rowId};
                anchor = rowId;
              });
            },
            onUngroupSelection: () {
              ungroupCalls++;
              final rowId = ungroupTargetRow(widget.store.doc, selected);
              if (rowId == null) return;
              final kids = [
                for (final n in widget.store.doc.nodes)
                  if (n.parentId == rowId) n.id,
              ];
              widget.store.replaceDoc(ungroupRowDoc(widget.store.doc, rowId));
              setState(() {
                selected = kids.toSet();
                anchor = kids.isEmpty ? null : kids.last;
              });
            },
            onDeleteSelection: () {
              deleteCalls++;
              for (final id in selected.toList()) {
                widget.store.deleteNode(id);
              }
              setState(() {
                selected = <String>{};
                anchor = null;
              });
            },
          ),
        ),
      ),
    );
  }
}

_PanelHarnessState _harnessState(WidgetTester tester) =>
    tester.state<_PanelHarnessState>(find.byType(_PanelHarness));

/// Taps the layer row labeled with [id], holding [modifier] while tapping
/// (null = plain tap). Mirrors how a user Ctrl/Cmd+clicks or Shift+clicks.
Future<void> _tapRow(
  WidgetTester tester,
  String id, {
  LogicalKeyboardKey? modifier,
}) async {
  if (modifier != null) await tester.sendKeyDownEvent(modifier);
  await tester.tap(find.textContaining(id).first);
  await tester.pump();
  if (modifier != null) await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

/// All row highlight boxes with exactly [color] as their fill.
Finder _rowsWithFill(Color color) => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == color,
    );

/// All row highlight boxes carrying the primary ring.
Finder _rowsWithRing(Color ring) => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).border != null &&
          (w.decoration! as BoxDecoration).border!.top.color == ring,
    );

shadcn.IconButton _headerButton(WidgetTester tester, IconData icon) =>
    tester.widget<shadcn.IconButton>(
      find
          .ancestor(
            of: find.byIcon(icon),
            matching: find.byType(shadcn.IconButton),
          )
          .first,
    );

void main() {
  testWidgets('plain tap collapses the set to the tapped node', (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0], ids[1]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await _tapRow(tester, ids[2]);

    final state = _harnessState(tester);
    expect(state.selected, {ids[2]});
    expect(state.anchor, ids[2]);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('Ctrl+tap toggles membership, Shift+tap ranges from the anchor',
      (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();

    // Ctrl+tap an absent node adds it and moves the anchor.
    await _tapRow(tester, ids[1], modifier: LogicalKeyboardKey.controlLeft);
    expect(_harnessState(tester).selected, {ids[0], ids[1]});
    expect(_harnessState(tester).anchor, ids[1]);
    expect(find.text('2 selected'), findsOneWidget);

    // Ctrl+tap a present node removes it (anchor stays, still live).
    await _tapRow(tester, ids[0], modifier: LogicalKeyboardKey.controlLeft);
    expect(_harnessState(tester).selected, {ids[1]});

    // Shift+tap ranges from the live anchor (ids[1]) to the tap.
    await _tapRow(tester, ids[2], modifier: LogicalKeyboardKey.shiftLeft);
    expect(_harnessState(tester).selected, {ids[1], ids[2]});
    expect(_harnessState(tester).anchor, ids[2]);
    expect(find.text('2 selected'), findsOneWidget);

    // Shift+tap back ranges the full span again.
    await _tapRow(tester, ids[0], modifier: LogicalKeyboardKey.shiftLeft);
    expect(_harnessState(tester).selected, ids.toSet());
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('Cmd+tap toggles via the meta variant', (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();

    await _tapRow(tester, ids[2], modifier: LogicalKeyboardKey.metaLeft);
    expect(_harnessState(tester).selected, {ids[0], ids[2]});
  });

  testWidgets('primary ring vs secondary tint highlight', (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0], ids[1]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();

    final Color ring = EditorColors.light.toolbarActive;
    final primaryFill = ring.withValues(alpha: 0.35);
    final secondaryFill = ring.withValues(alpha: 0.15);

    // Exactly one primary ring (ids[0]) and one secondary tint (ids[1]);
    // the unselected row (ids[2]) carries neither fill.
    expect(_rowsWithRing(ring), findsOneWidget);
    expect(_rowsWithFill(primaryFill), findsOneWidget);
    expect(_rowsWithFill(secondaryFill), findsOneWidget);
  });

  testWidgets('no header or hint without a selection', (tester) async {
    final store = CanvasStore();
    _threeNodes(store);
    await tester.pumpWidget(_PanelHarness(store: store));
    await tester.pump();

    expect(find.textContaining('selected'), findsNothing);
    expect(find.textContaining('Shift+click'), findsNothing);
  });

  testWidgets('header hint visible while selected', (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0], ids[2]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
    expect(
      find.text(
        'Tip: Ctrl/Cmd+click toggles, Shift+click selects a range',
      ),
      findsOneWidget,
    );
  });

  testWidgets('header group action calls through and selects the row',
      (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0], ids[1]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();

    // Group enabled for two same-screen roots.
    expect(
      _headerButton(tester, Icons.group_work).onPressed,
      isNotNull,
    );

    await tester.tap(find.byIcon(Icons.group_work));
    await tester.pump();

    final state = _harnessState(tester);
    expect(state.groupCalls, 1);
    expect(store.doc.nodes.where((n) => n.isRow), hasLength(1));
    expect(state.selected, hasLength(1));
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('header group disabled for singletons', (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();

    expect(
      _headerButton(tester, Icons.group_work).onPressed,
      isNull,
    );
    expect(
      _headerButton(tester, Icons.call_split).onPressed,
      isNull,
    );
  });

  testWidgets('header delete-set removes every node and clears',
      (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    await tester.pumpWidget(
      _PanelHarness(
        store: store,
        initialIds: {ids[0], ids[2]},
        initialAnchor: ids[0],
      ),
    );
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pump();

    final state = _harnessState(tester);
    expect(state.deleteCalls, 1);
    expect(
      [for (final n in store.doc.nodes) n.id],
      [ids[1]],
    );
    expect(state.selected, isEmpty);
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('header delete-set falls back to the store without a callback',
      (tester) async {
    final store = CanvasStore();
    final ids = _threeNodes(store);
    String? collapsed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorTheme(
            colors: EditorColors.light,
            child: LayersPanel(
              store: store,
              selectedNodeIds: {ids[0], ids[1]},
              selectedNodeId: ids[0],
              onSelectNode: (id) => collapsed = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pump();

    expect([for (final n in store.doc.nodes) n.id], [ids[2]]);
    expect(collapsed, isNull);
  });
}
