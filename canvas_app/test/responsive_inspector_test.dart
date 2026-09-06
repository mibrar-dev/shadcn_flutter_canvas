import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CanvasNode _node(CanvasStore store, String nodeId) =>
    store.doc.nodes.singleWhere((n) => n.id == nodeId);

(String, String) _addButtonNode(CanvasStore store) {
  const itemId = 'i1';
  final nodeId = store.addNode(
    screenId: 's1',
    x: 0,
    y: 0,
    items: const [
      CanvasItem(
        id: itemId,
        kind: 'button',
        props: {
          'label': 'Button',
          'variant': 'primary',
          'size': 'md',
          'disabled': false,
        },
      ),
    ],
  );
  return (nodeId, itemId);
}

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

void main() {
  group('setNodeResponsive store', () {
    test('sets hiddenOn', () {
      final store = CanvasStore();
      final (nodeId, _) = _addButtonNode(store);
      store.setNodeResponsive(nodeId, hiddenOn: {'mobile', 'tablet'});
      expect(_node(store, nodeId).hiddenOn, {'mobile', 'tablet'});
    });

    test('clears hiddenOn via clearHiddenOn', () {
      final store = CanvasStore();
      final (nodeId, _) = _addButtonNode(store);
      store.setNodeResponsive(nodeId, hiddenOn: {'mobile'});
      expect(_node(store, nodeId).hiddenOn, {'mobile'});
      store.setNodeResponsive(nodeId, clearHiddenOn: true);
      expect(_node(store, nodeId).hiddenOn, isEmpty);
    });

    test('unknown tier throws ArgumentError', () {
      final store = CanvasStore();
      final (nodeId, _) = _addButtonNode(store);
      expect(
        () => store.setNodeResponsive(nodeId, hiddenOn: {'watch'}),
        throwsArgumentError,
      );
    });

    test('unknown node is a no-op without history pollution', () {
      final store = CanvasStore();
      expect(store.canUndo, isFalse);
      store.setNodeResponsive('missing', hiddenOn: {'mobile'});
      expect(store.doc.nodes, isEmpty);
      expect(store.canUndo, isFalse);
    });

    test('undo restores previous hiddenOn', () {
      final store = CanvasStore();
      final (nodeId, _) = _addButtonNode(store);
      store.setNodeResponsive(nodeId, hiddenOn: {'mobile'});
      expect(_node(store, nodeId).hiddenOn, {'mobile'});
      expect(store.undo(), isTrue);
      expect(_node(store, nodeId).hiddenOn, isEmpty);
      expect(store.redo(), isTrue);
      expect(_node(store, nodeId).hiddenOn, {'mobile'});
    });

    test('preserves existing node fields when rebuilding', () {
      final store = CanvasStore();
      final (nodeId, _) = _addButtonNode(store);
      store.patchNode(nodeId, mainAxis: 'center', expand: 'flex', flex: 2);
      store.setNodeResponsive(nodeId, hiddenOn: {'desktop'});
      final node = _node(store, nodeId);
      expect(node.hiddenOn, {'desktop'});
      expect(node.mainAxis, 'center');
      expect(node.expand, 'flex');
      expect(node.flex, 2);
      expect(node.items, hasLength(1));
    });
  });

  group('Visibility inspector section', () {
    testWidgets('toggling Mobile writes and clears hiddenOn', (tester) async {
      final store = CanvasStore();
      final (nodeId, itemId) = _addButtonNode(store);
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      // The inspector list lazily builds below-the-fold cards: scroll the
      // "On tap" card (Track K, above Visibility) into view so the
      // Visibility section builds before asserting.
      await tester.ensureVisible(find.text('On tap'));
      await tester.pump();

      expect(find.text('Visibility'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Desktop'), findsOneWidget);
      expect(
        find.text('hidden on: none (always visible)'),
        findsOneWidget,
      );
      // Visibility toggles are buttons (not Switches) so the leaf bool
      // editor keeps its exact widget count.
      expect(find.byType(shadcn.Switch), findsOneWidget);
      expect(
        find.byKey(const ValueKey('visibility-mobile')),
        findsOneWidget,
      );

      // Track X2: the Size presets lengthen the panel, so the Visibility
      // toggle can sit below the fold — scroll it into view before tapping.
      await tester.ensureVisible(
        find.byKey(const ValueKey('visibility-mobile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('visibility-mobile')));
      await tester.pump();
      expect(_node(store, nodeId).hiddenOn, {'mobile'});
      expect(find.text('hidden on: mobile'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('visibility-mobile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('visibility-mobile')));
      await tester.pump();
      expect(_node(store, nodeId).hiddenOn, isEmpty);
      expect(
        find.text('hidden on: none (always visible)'),
        findsOneWidget,
      );
    });
  });
}
