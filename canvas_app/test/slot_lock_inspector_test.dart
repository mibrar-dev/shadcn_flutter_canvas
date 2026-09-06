/// Track DD: inspector slots section + lock toggle (widget tests, driving
/// editors the way `action_editor_test` does — Selects via `onChanged`,
/// buttons via taps).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: no prefs — a prefs-backed store schedules autosave timers that keep
// the fake async zone busy after the tree disposes (see `action_editor_test`
// using bare `CanvasStore()` for the same reason).

/// `card` host (`h`/`ih`) plus two `button` roots (`c`, `o`) on `s1`.
CanvasStore _slotStore() {
  final store = CanvasStore();
  store.replaceDoc(ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': [
      {
        'id': 'h',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {'id': 'ih', 'kind': 'card', 'title': 'T'},
        ],
      },
      {
        'id': 'c',
        'screenId': 's1',
        'x': 0.0,
        'y': 100.0,
        'items': [
          {'id': 'ic', 'kind': 'button', 'label': 'Go'},
        ],
      },
      {
        'id': 'o',
        'screenId': 's1',
        'x': 0.0,
        'y': 200.0,
        'items': [
          {'id': 'io', 'kind': 'button', 'label': 'Other'},
        ],
      },
    ],
    'theme': {
      'paletteKey': 'clean-slate',
      'dark': true,
      'shape': 'rounded',
      'motion': 'standard'
    },
    'meta': {'title': 'T', 'brief': ''},
  }));
  return store;
}

CanvasNode _node(CanvasStore store, String id) =>
    store.doc.nodes.singleWhere((n) => n.id == id);

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

/// Tall viewport so every inspector card builds deterministically (see
/// `action_editor_test.dart`).
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('slots section', () {
    testWidgets('card host shows picker + clear wired to the store',
        (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      await _pumpInspector(tester, store, nodeId: 'h', itemId: 'ih');

      expect(find.text('Slots'), findsOneWidget);
      // The lock card renders (header 'Lock' + the keyed toggle button).
      expect(find.byKey(const ValueKey('node-lock')), findsOneWidget);
      final picker =
          find.byKey(const ValueKey('slot-content'));
      expect(picker, findsOneWidget);
      expect(find.byKey(const ValueKey('slot-clear-content')), findsOneWidget);

      // Assign through the Select exactly like the action-target tests do.
      tester
          .widget<shadcn.Select<String>>(picker)
          .onChanged!('c');
      await tester.pump();
      expect(_node(store, 'h').slotNodes, {'content': 'c'});

      // Clear through the button.
      await _tapKey(tester, 'slot-clear-content');
      expect(_node(store, 'h').slotNodes, isEmpty);
    });

    testWidgets('illegal targets never reach the throwing store path',
        (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      await _pumpInspector(tester, store, nodeId: 'h', itemId: 'ih');

      final picker = find.byKey(const ValueKey('slot-content'));
      // Self assignment is disabled in the UI: the guarded onChanged drops
      // it instead of throwing.
      tester.widget<shadcn.Select<String>>(picker).onChanged!('h');
      await tester.pump();
      expect(_node(store, 'h').slotNodes, isEmpty);

      // A descendant is equally guarded: parent c under h first.
      store.reparentNode('c', 'h');
      await tester.pump();
      tester.widget<shadcn.Select<String>>(picker).onChanged!('c');
      await tester.pump();
      expect(_node(store, 'h').slotNodes, isEmpty);
    });

    testWidgets('slot picker opens with disabled reasons for illegal targets',
        (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      await _pumpInspector(tester, store, nodeId: 'h', itemId: 'ih');

      await _tapKey(tester, 'slot-content');
      // Bounded pumps only: the popup overlay animation never settles under
      // fake async (pumpAndSettle times out).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Self and current-child reasons surface in the open popup.
      expect(find.textContaining('cannot slot itself'), findsOneWidget);
      // Legal targets carry no reason suffix.
      expect(find.text('Button · o'), findsOneWidget);
    });

    testWidgets('non-slotted kinds show no Slots card', (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      await _pumpInspector(tester, store, nodeId: 'c', itemId: 'ic');

      expect(find.text('Slots'), findsNothing);
      expect(find.byKey(const ValueKey('node-lock')), findsOneWidget);
    });

    testWidgets('locked host disables pickers with a hint', (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      store.setNodeLocked('h', true);
      await _pumpInspector(tester, store, nodeId: 'h', itemId: 'ih');

      expect(find.text('Slots'), findsOneWidget);
      expect(find.text('Unlock to edit slots.'), findsOneWidget);
      final select =
          tester.widget<shadcn.Select<String>>(
        find.byKey(const ValueKey('slot-content')),
      );
      expect(select.enabled, isFalse);
      final clear = tester.widget<shadcn.OutlineButton>(
        find.byKey(const ValueKey('slot-clear-content')),
      );
      expect(clear.onPressed, isNull);
    });
  });

  group('lock toggle', () {
    testWidgets('lock/unlock button flips the store flag', (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      await _pumpInspector(tester, store, nodeId: 'c', itemId: 'ic');

      expect(find.text('Unlocked'), findsOneWidget);
      await _tapKey(tester, 'node-lock');
      expect(_node(store, 'c').locked, isTrue);

      await tester.pump();
      expect(find.text('Locked'), findsOneWidget);
      expect(
        find.textContaining('disabled until unlock'),
        findsOneWidget,
      );
      await _tapKey(tester, 'node-lock');
      expect(_node(store, 'c').locked, isFalse);
    });

    testWidgets('lock toggle undoes cleanly', (tester) async {
      _tallViewport(tester);
      final store = _slotStore();
      await _pumpInspector(tester, store, nodeId: 'c', itemId: 'ic');

      await _tapKey(tester, 'node-lock');
      expect(_node(store, 'c').locked, isTrue);
      expect(store.undo(), isTrue);
      expect(_node(store, 'c').locked, isFalse);
    });
  });
}
