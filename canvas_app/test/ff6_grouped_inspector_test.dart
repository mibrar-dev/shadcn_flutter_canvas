/// Track FF6 (BUILD_SPEC §9.2-5a–5c, §9.3 FF6): grouped properties.
///
/// Asserts structure and callbacks, NOT pixels (§12 rule 4):
/// - the flat F4 prop list re-hosts as collapsible Layout / Style / …
///   sections (same group titles, same schema order);
/// - every F4 editor keeps its stable key and its store path
///   (`node-size-mode`, `node-flex`, `i1/<prop>`, `gradient-add`,
///   `shadow-add`, `radius-all`, `border-width`);
/// - the FF6 box-model `All` stepper + symmetry readout write through
///   `store.patchItem` like the per-side steppers;
/// - collapsing a group unmounts only that group's editors;
/// - the Code tab still mounts [CodePeek] (BUILD_SPEC §9.2-5c, KEEP).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/code_peek.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adds a `container` item `i1` (Layout + Style groups: width/height plus
/// the full §7.3 style vocabulary) and returns its node id.
String _addContainer(CanvasStore store) {
  return store.addNode(
    screenId: 's1',
    x: 0,
    y: 0,
    items: const [CanvasItem(id: 'i1', kind: 'container')],
  );
}

Future<void> _pumpInspector(
  WidgetTester tester,
  CanvasStore store,
  String nodeId,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InspectorPanel(store: store, nodeId: nodeId, itemId: 'i1'),
      ),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> _propsOf(CanvasStore store, String nodeId) => store
    .doc
    .nodes
    .singleWhere((n) => n.id == nodeId)
    .items
    .single
    .props;

void main() {
  group('ff6 grouped sections', () {
    testWidgets('container props re-host under Layout + Style headers', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = _addContainer(store);
      await _pumpInspector(tester, store, nodeId);

      // Same group titles as the flat list (the polish tests pin these),
      // now as collapsible section headers with stable keys.
      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inspector-group-layout')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspector-group-style')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspector-group-header-layout')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspector-group-header-style')),
        findsOneWidget,
      );
    });

    testWidgets('F4 editors keep stable keys and store paths', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = _addContainer(store);
      await _pumpInspector(tester, store, nodeId);

      // Every F4 editor re-hosted by its pinned key (sections start
      // expanded, so all of these are mounted).
      expect(find.byKey(const ValueKey('node-size-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/padding')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/margin')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/color')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/radius')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/border')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/gradient')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/shadow')), findsOneWidget);
      expect(find.byKey(const ValueKey('i1/alignment')), findsOneWidget);
      expect(find.byKey(const ValueKey('radius-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('border-width')), findsOneWidget);
      expect(find.byKey(const ValueKey('gradient-add')), findsOneWidget);
      expect(find.byKey(const ValueKey('shadow-add')), findsOneWidget);

      // Store path intact: the per-side stepper still patches the item.
      final paddingPlus = find.descendant(
        of: find.byKey(const ValueKey('i1/padding')),
        matching: find.text('+'),
      );
      await tester.ensureVisible(paddingPlus.first);
      await tester.pumpAndSettle();
      await tester.tap(paddingPlus.first);
      await tester.pump();
      expect(_propsOf(store, nodeId)['padding'], {
        'l': 4.0,
        't': 0.0,
        'r': 0.0,
        'b': 0.0,
      });
    });

    testWidgets('collapsing Style hides only its editors', (tester) async {
      final store = CanvasStore();
      final nodeId = _addContainer(store);
      await _pumpInspector(tester, store, nodeId);

      final styleHeader = find.byKey(
        const ValueKey('inspector-group-header-style'),
      );
      await tester.ensureVisible(styleHeader);
      await tester.pumpAndSettle();
      await tester.tap(styleHeader);
      await tester.pump();

      // Style editors unmount; Layout editors stay mounted.
      expect(find.byKey(const ValueKey('i1/padding')), findsNothing);
      expect(find.byKey(const ValueKey('i1/radius')), findsNothing);
      expect(find.text('Style'), findsOneWidget);
      expect(find.byKey(const ValueKey('node-size-mode')), findsOneWidget);

      // Re-expand restores them.
      await tester.tap(styleHeader);
      await tester.pump();
      expect(find.byKey(const ValueKey('i1/padding')), findsOneWidget);
    });
  });

  group('ff6 box-model All + symmetry', () {
    testWidgets('All stepper writes the uniform map through the store', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = _addContainer(store);
      await _pumpInspector(tester, store, nodeId);

      // Two edge editors (padding + margin) each carry an All stepper
      // (uniform zeros → the shared readout, not `Mixed`).
      expect(find.text('All sides equal'), findsNWidgets(2));
      final allInc = find.descendant(
        of: find.byKey(const ValueKey('i1/padding')),
        matching: find.byKey(const ValueKey('edge-all-inc')),
      );
      expect(allInc, findsOneWidget);
      await tester.ensureVisible(allInc);
      await tester.pumpAndSettle();
      await tester.tap(allInc);
      await tester.pump();
      expect(_propsOf(store, nodeId)['padding'], {
        'l': 4.0,
        't': 4.0,
        'r': 4.0,
        'b': 4.0,
      });
    });

    testWidgets('symmetry readout tracks the four sides', (tester) async {
      Future<void> pumpSides(Map<String, double> value) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PropEdgeInsetsEditor(
                value: value,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpSides(const {'l': 8.0, 't': 8.0, 'r': 8.0, 'b': 8.0});
      expect(find.text('All sides equal'), findsOneWidget);

      await pumpSides(const {'l': 16.0, 't': 8.0, 'r': 16.0, 'b': 8.0});
      expect(find.text('Symmetric sides'), findsOneWidget);

      await pumpSides(const {'l': 16.0, 't': 8.0, 'r': 4.0, 'b': 8.0});
      expect(find.text('Mixed sides'), findsOneWidget);
    });
  });

  group('ff6 code peek kept', () {
    testWidgets('Code tab still mounts the read-only peek', (tester) async {
      final store = CanvasStore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RightAside(store: store))),
      );
      await tester.pump();

      await tester.tap(
        find
            .descendant(
              of: find.byType(RightAside),
              matching: find.byIcon(Icons.code),
            )
            .first,
      );
      await tester.pump();
      expect(find.byType(CodePeek), findsOneWidget);
      expect(find.text('No selection'), findsOneWidget);
    });
  });
}
