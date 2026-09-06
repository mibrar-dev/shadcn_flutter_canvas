/// Track DD: layers lock toggle + slot chips (widget tests, mirroring the
/// `layers_multiselect_test` harness wiring).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: bare `CanvasStore()` (no prefs) — see `slot_lock_inspector_test`.

/// `card` host (`h`) plus two `button` roots (`c`, `o`) on `s1`.
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

/// Minimal shell-style harness: selection state plus the collapse wiring the
/// panel falls back to (mirrors `layers_multiselect_test`).
class _PanelHarness extends StatefulWidget {
  const _PanelHarness({required this.store, this.initialIds = const {}});

  final CanvasStore store;
  final Set<String> initialIds;

  @override
  State<_PanelHarness> createState() => _PanelHarnessState();
}

class _PanelHarnessState extends State<_PanelHarness> {
  late Set<String> selected = Set<String>.of(widget.initialIds);

  @override
  Widget build(BuildContext context) {
    String? primary;
    for (final n in widget.store.doc.nodes) {
      if (selected.contains(n.id)) {
        primary ??= n.id;
      }
    }
    return MaterialApp(
      home: Scaffold(
        body: EditorTheme(
          colors: EditorColors.light,
          child: LayersPanel(
            store: widget.store,
            selectedNodeIds: selected,
            selectedNodeId: primary,
            onSelectNode: (id) => setState(() {
              selected = id == null ? <String>{} : {id};
            }),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpPanel(
  WidgetTester tester,
  CanvasStore store, {
  Set<String> initialIds = const {},
}) async {
  await tester.pumpWidget(
    _PanelHarness(store: store, initialIds: initialIds),
  );
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  group('lock toggle', () {
    testWidgets('every row carries a lock action flipping the store flag',
        (tester) async {
      final store = _slotStore();
      await _pumpPanel(tester, store);

      for (final id in ['h', 'c', 'o']) {
        expect(
          find.byKey(ValueKey('layer-lock-$id')),
          findsOneWidget,
          reason: 'lock action for $id',
        );
      }

      await _tapKey(tester, 'layer-lock-c');
      expect(_node(store, 'c').locked, isTrue);
      await tester.pump();
      // Kit tooltips don't register with `find.byTooltip` (see
      // `layers_panel_test.dart`): assert the lock glyphs by icon.
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));

      await _tapKey(tester, 'layer-lock-c');
      expect(_node(store, 'c').locked, isFalse);
    });

    testWidgets('header delete-set skips locked nodes', (tester) async {
      final store = _slotStore();
      store.setNodeLocked('c', true);
      await _pumpPanel(tester, store, initialIds: {'c', 'o'});

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pump();

      // The unlocked node is gone; the locked one survives and stays
      // selected (collapsed onto the survivor).
      expect(store.doc.nodes.map((n) => n.id), isNot(contains('o')));
      expect(_node(store, 'c').locked, isTrue);
      expect(find.byKey(const ValueKey('layer-lock-c')), findsOneWidget);
    });
  });

  group('slot chips', () {
    testWidgets('host shows a chip per slot; tap selects the child',
        (tester) async {
      final store = _slotStore();
      store.setSlotChild('h', 'content', 'c');
      await _pumpPanel(tester, store);

      final chip = find.byKey(const ValueKey('slot-chip-h-content'));
      expect(chip, findsOneWidget);
      expect(find.text('content → Button · c'), findsOneWidget);

      await tester.tap(chip);
      await tester.pump();
      // Tapping the chip collapses the selection onto the child.
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('dangling slot refs render missing with no tap target',
        (tester) async {
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
              {'id': 'ih', 'kind': 'card'},
            ],
            'slotNodes': {'content': 'ghost'},
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
      await _pumpPanel(tester, store);

      expect(find.byKey(const ValueKey('slot-chip-h-content')), findsOneWidget);
      expect(find.text('content → missing'), findsOneWidget);
    });
  });
}
