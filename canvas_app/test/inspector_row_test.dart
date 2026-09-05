import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Row-inspector + full-prop audit tests.
///
/// AUDIT (enforced): every [kCatalog] kind resolves a [kInspectorSchemas]
/// entry — loop test below.
///
/// ROW UI: row container nodes (created via `store.addRow`) carry no items,
/// so the inspector shows the container editor (badge + id + child count +
/// gap stepper reporting through `store.patchNode`).
void main() {
  group('inspector schema audit', () {
    test('every catalog kind resolves a schema (loop)', () {
      expect(kCatalog, isNotEmpty);
      for (final entry in kCatalog) {
        expect(
          kInspectorSchemas.containsKey(entry.kind),
          isTrue,
          reason: 'missing kInspectorSchemas entry for kind ${entry.kind}',
        );
      }
    });

    test('all 19 catalog kinds are covered', () {
      const expected = {
        'button',
        'card',
        'input',
        'badge',
        'switch',
        'avatar',
        'checkbox',
        'divider',
        'progress',
        'tabs',
        'accordion',
        'select',
        'radio_group',
        'skeleton',
        'breadcrumb',
        'dialog',
        'tooltip',
        'toast',
        'drawer',
      };
      expect(Set.of(kCatalog.map((e) => e.kind)), expected);
      expect(Set.of(kInspectorSchemas.keys), containsAll(expected));
    });
  });

  group('row container editor', () {
    testWidgets('row node shows gap editor', (tester) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: rowId),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('row'), findsOneWidget);
      expect(find.text(rowId), findsOneWidget);
      expect(find.text('0 children'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // Step up to 12 through the real button.
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).gap,
        12.0,
      );
    });

    test('patchNode persists the gap and undo restores it', () {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      store.patchNode(rowId, gap: 20.0);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).gap,
        20.0,
      );
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).gap,
        8.0,
      );
    });
  });
}
