/// Track R1: the inspector action-step editor, binding affordances, and the
/// app-state card (widget tests, driving editors the way `tap_action_test`
/// does — Selects via `onChanged`, buttons via taps).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Store with a `count` var and a plain `Go` button on `s1`, plus an empty
/// `Done` screen. Returns `(store, nodeId, itemId, doneScreenId)`.
(CanvasStore, String, String, String) _storeWithButton() {
  final store = CanvasStore();
  store.addVar(const AppStateVar(name: 'count', type: 'number', defaultValue: 0));
  final doneId = store.addScreen(name: 'Done');
  final nodeId = store.addNode(
    screenId: 's1',
    x: 16,
    y: 96,
    items: const [
      CanvasItem(
        id: 'i1',
        kind: 'button',
        props: {'label': 'Go', 'variant': 'primary'},
      ),
    ],
  );
  return (store, nodeId, 'i1', doneId);
}

CanvasItem _item(CanvasStore store, String nodeId, String itemId) => store.doc
    .nodes
    .singleWhere((n) => n.id == nodeId)
    .items
    .singleWhere((i) => i.id == itemId);

Future<void> _pumpInspector(
  WidgetTester tester,
  CanvasStore store, {
  String? nodeId,
  String? itemId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InspectorPanel(store: store, nodeId: nodeId, itemId: itemId),
      ),
    ),
  );
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Tall viewport so every inspector card builds deterministically: the
/// panel is a lazy ListView, and docs with vars render taller cards — at the
/// default 600px height the action card lands on the cache-extent boundary
/// and flakes in and out of the tree.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('action-step editor', () {
    testWidgets('adding a navigate step from empty action', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, doneId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.text('On tap'), findsOneWidget);
      expect(_item(store, nodeId, itemId).action, isNull);

      await _tapKey(tester, 'step-add-navigate');

      final action = _item(store, nodeId, itemId).action!;
      expect(action.steps, hasLength(1));
      expect(action.steps.single.kind, 'navigate');
      // Legacy to syncs to the navigate target for old readers.
      expect(action.to, action.steps.single.to);
      expect(find.textContaining('Navigate to'), findsOneWidget);
      // Legacy pickers hide while stepped.
      expect(find.byKey(const ValueKey('action-target')), findsNothing);
      expect(doneId, isNotEmpty);
    });

    testWidgets('first edit materializes the legacy nav as step 1', (
      tester,
    ) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, doneId) = _storeWithButton();
      store.setItemAction(nodeId, itemId, NodeAction(to: doneId, transition: 'fade'));
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      // Legacy editors still present for the legacy action.
      expect(find.byKey(const ValueKey('action-target')), findsOneWidget);

      await _tapKey(tester, 'step-add-showSnackBar');

      final steps = _item(store, nodeId, itemId).action!.steps;
      expect(steps, hasLength(2));
      expect(steps[0].kind, 'navigate');
      expect(steps[0].to, doneId);
      expect(steps[0].transition, 'fade');
      expect(steps[1].kind, 'showSnackBar');
    });

    testWidgets('step target picker rewrites the navigate step', (
      tester,
    ) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, doneId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-navigate');

      tester
          .widget<shadcn.Select<String>>(
            find.byKey(const ValueKey('step-0-target')),
          )
          .onChanged!(doneId);
      await tester.pump();

      final steps = _item(store, nodeId, itemId).action!.steps;
      expect(steps.single.to, doneId);
    });

    testWidgets('setState step edits var and value', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, _) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-setState');

      tester
          .widget<shadcn.Select<String>>(
            find.byKey(const ValueKey('step-0-var')),
          )
          .onChanged!('count');
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('step-0-value')),
        '5',
      );
      await tester.pump();

      final step = _item(store, nodeId, itemId).action!.steps.single;
      expect(step.kind, 'setState');
      expect(step.variable, 'count');
      expect(step.value, '5');
    });

    testWidgets('reorder swaps steps; delete removes; last delete restores legacy', (
      tester,
    ) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, doneId) = _storeWithButton();
      store.setItemAction(nodeId, itemId, NodeAction(to: doneId, transition: 'slide'));
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-showSnackBar');
      await _tapKey(tester, 'step-add-showDialog');

      // [navigate, snackBar, dialog] → move dialog up → [navigate, dialog, snackBar].
      await _tapKey(tester, 'step-up-2');
      var kinds = _item(store, nodeId, itemId).action!.steps.map((s) => s.kind);
      expect(kinds, ['navigate', 'showDialog', 'showSnackBar']);

      // Delete the dialog.
      await _tapKey(tester, 'step-delete-1');
      kinds = _item(store, nodeId, itemId).action!.steps.map((s) => s.kind);
      expect(kinds, ['navigate', 'showSnackBar']);

      // Delete everything → pure legacy action restored.
      await _tapKey(tester, 'step-delete-1');
      await _tapKey(tester, 'step-delete-0');
      final action = _item(store, nodeId, itemId).action!;
      expect(action.steps, isEmpty);
      expect(action.to, doneId);
      // ...and the legacy pickers are back.
      expect(find.byKey(const ValueKey('action-target')), findsOneWidget);
    });

    testWidgets('condition nests a then-branch editor', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, doneId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-condition');

      tester
          .widget<shadcn.Select<String>>(
            find.byKey(const ValueKey('step-0-var')),
          )
          .onChanged!('count');
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('step-0-equals')),
        '1',
      );
      await tester.pump();
      await _tapKey(tester, 'step-0-then-add-navigate');

      final step = _item(store, nodeId, itemId).action!.steps.single;
      expect(step.kind, 'condition');
      expect(step.variable, 'count');
      expect(step.equals, '1');
      expect(step.thenSteps, hasLength(1));
      expect(step.thenSteps.single.kind, 'navigate');
      expect(find.textContaining('If count == 1'), findsOneWidget);
      expect(doneId, isNotEmpty);
    });

    testWidgets('clear removes stepped actions entirely', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, _) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-navigate');
      expect(_item(store, nodeId, itemId).action, isNotNull);
      await _tapKey(tester, 'action-clear');
      expect(_item(store, nodeId, itemId).action, isNull);
    });
  });

  group('bindings UI', () {
    testWidgets('unbound string prop offers a bind picker', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, _) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      final picker = tester.widget<PropSelectEditor>(
        find.byKey(const ValueKey('bind-i1-label')),
      );
      expect(picker.options, ['count']);

      picker.onChanged!('count');
      await tester.pump();
      expect(_item(store, nodeId, itemId).props['label'], '=count');
      expect(find.textContaining('=count = 0'), findsOneWidget);
    });

    testWidgets('bound prop shows resolved hint and unlinks', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, _) = _storeWithButton();
      store.patchItem(nodeId, itemId, props: const {'label': '=count'});
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.textContaining('=count = 0'), findsOneWidget);
      await _tapKey(tester, 'bind-unlink-i1-label');
      expect(_item(store, nodeId, itemId).props['label'], '0');
    });

    testWidgets('missing var shows a missing note', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId, _) = _storeWithButton();
      store.patchItem(nodeId, itemId, props: const {'label': '=ghost'});
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.textContaining('(missing var)'), findsOneWidget);
    });

    testWidgets('no vars means no binding affordances', (tester) async {
      _tallViewport(tester);
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'button')],
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');
      expect(find.text('App state'), findsOneWidget);
      expect(find.byKey(const ValueKey('bind-i1-label')), findsNothing);
    });
  });

  group('app-state card', () {
    testWidgets('add creates var1; rename and delete work', (tester) async {
      _tallViewport(tester);
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'button')],
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      await _tapKey(tester, 'state-add');
      expect(store.doc.states.map((v) => v.name), ['var1']);

      await tester.enterText(
        find.byKey(const ValueKey('state-name-var1')),
        'count',
      );
      await tester.pump();
      expect(store.doc.states.map((v) => v.name), ['count']);

      await _tapKey(tester, 'state-delete-count');
      expect(store.doc.states, isEmpty);
    });

    testWidgets('add numbering skips taken names', (tester) async {
      _tallViewport(tester);
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [CanvasItem(id: 'i1', kind: 'button')],
      );
      store.addVar(const AppStateVar(name: 'var1', type: 'bool', defaultValue: true));
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      await _tapKey(tester, 'state-add');
      expect(store.doc.states.map((v) => v.name), ['var1', 'var2']);
    });
  });
}
