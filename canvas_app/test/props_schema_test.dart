/// W2 schema-driven inspector tests: schema completeness, control coverage,
/// override semantics, and dictated-API gap probes.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/props_schema.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _expectedKinds = {
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

(CanvasStore, String, String) _storeWithButton() {
  final store = CanvasStore();
  const itemId = 'i1';
  final nodeId = store.addNode(
    screenId: 's1',
    x: 16,
    y: 96,
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
  return (store, nodeId, itemId);
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
}

void main() {
  group('schema completeness', () {
    test('every catalog kind resolves a schema (loop)', () {
      expect(kCatalog, isNotEmpty);
      for (final entry in kCatalog) {
        expect(
          kPropSchemas.containsKey(entry.kind),
          isTrue,
          reason: 'missing kPropSchemas entry for kind ${entry.kind}',
        );
      }
    });

    test('all 19 catalog kinds plus the row container are covered', () {
      expect(Set.of(kCatalog.map((e) => e.kind)), _expectedKinds);
      expect(Set.of(kPropSchemas.keys), containsAll(_expectedKinds));
      expect(kPropSchemas.containsKey('row'), isTrue);
      expect(kPropSchemas.length, _expectedKinds.length + 1);
    });

    test('schema defaults mirror catalog defaults in both directions', () {
      for (final entry in kCatalog) {
        final specs = kPropSchemas[entry.kind]!;
        final specNames = {for (final s in specs) s.name};
        expect(
          specNames,
          equals(entry.defaults.keys.toSet()),
          reason: 'schema/catalog key mismatch for kind ${entry.kind}',
        );
        for (final spec in specs) {
          expect(
            entry.defaults[spec.name],
            spec.defaultValue,
            reason: 'default mismatch for ${entry.kind}.${spec.name}',
          );
        }
      }
    });

    test('row container schema carries gap/mainAxis/crossAxis', () {
      final gap = findSpec('row', 'gap')!;
      expect(gap.type, 'number');
      expect(gap.control, 'stepper');
      expect(gap.group, 'layout');
      expect([gap.min, gap.max, gap.step], [0.0, 32.0, 4.0]);
      expect(gap.defaultValue, kFlowRowGapDefault);

      final mainAxis = findSpec('row', 'mainAxis')!;
      expect(mainAxis.type, 'enum');
      expect(mainAxis.group, 'layout');
      expect(mainAxis.options, orderedEquals(kMainAxisOptions));
      expect(
        kMainAxisOptions,
        orderedEquals([
          'start',
          'center',
          'end',
          'spaceBetween',
          'spaceAround',
          'spaceEvenly',
        ]),
      );
      expect(mainAxis.nullable, isTrue);
      expect(mainAxis.defaultValue, isNull);

      final crossAxis = findSpec('row', 'crossAxis')!;
      expect(crossAxis.type, 'enum');
      expect(crossAxis.group, 'layout');
      expect(crossAxis.options, orderedEquals(kCrossAxisOptions));
      expect(
        kCrossAxisOptions,
        orderedEquals(['start', 'center', 'end', 'stretch']),
      );
      expect(crossAxis.nullable, isTrue);
      expect(crossAxis.defaultValue, isNull);
    });

    test('findSpec returns null for unknown kind/prop', () {
      expect(findSpec('mystery', 'label'), isNull);
      expect(findSpec('button', 'nope'), isNull);
    });
  });

  group('override resolution', () {
    test('resolveProp layers schema <- catalog <- props', () {
      expect(resolveProp('button', 'label', {}), 'Button');
      expect(
        resolveProp('button', 'label', {}, {'label': 'FromCatalog'}),
        'FromCatalog',
      );
      expect(
        resolveProp(
          'button',
          'label',
          {'label': 'Mine'},
          {'label': 'FromCatalog'},
        ),
        'Mine',
      );
      expect(resolveProp('button', 'nope', {}), isNull);
    });

    test('isPropOverridden fires only on a differing value', () {
      expect(isPropOverridden('button', 'label', {}), isFalse);
      expect(
        isPropOverridden('button', 'label', {'label': 'Button'}),
        isFalse,
      );
      expect(
        isPropOverridden('button', 'label', {'label': 'Pay now'}),
        isTrue,
      );
      expect(
        isPropOverridden('button', 'disabled', {'disabled': true}),
        isTrue,
      );
    });
  });

  group('every control type renders', () {
    testWidgets('text editor renders', (tester) async {
      await _pump(
        tester,
        PropTextEditor(initial: 'hi', onChanged: (_) {}),
      );
      expect(find.byType(shadcn.TextField), findsOneWidget);
    });

    testWidgets('text editor keeps in-flight typing across echo rebuilds', (
      tester,
    ) async {
      String? sent;
      await _pump(
        tester,
        PropTextEditor(initial: 'a', onChanged: (v) => sent = v),
      );
      await tester.enterText(find.byType(shadcn.TextField), 'ab');
      expect(sent, 'ab');
      // Store echo of our own edit: same value rebuild must not clobber text.
      await _pump(
        tester,
        PropTextEditor(initial: 'ab', onChanged: (v) => sent = v),
      );
      await tester.pump();
      expect(find.text('ab'), findsOneWidget);
      // Genuine external change (e.g. undo) still propagates.
      await _pump(
        tester,
        PropTextEditor(initial: 'xyz', onChanged: (v) => sent = v),
      );
      await tester.pump();
      expect(find.text('xyz'), findsOneWidget);
    });

    testWidgets('switch editor renders and reports', (tester) async {
      bool? seen;
      await _pump(
        tester,
        PropSwitchEditor(value: false, onChanged: (v) => seen = v),
      );
      expect(find.byType(shadcn.Switch), findsOneWidget);
      await tester.tap(find.byType(shadcn.Switch));
      await tester.pump();
      expect(seen, isTrue);
    });

    testWidgets('select editor renders options', (tester) async {
      await _pump(
        tester,
        PropSelectEditor(
          value: null,
          options: const ['a', 'b', 'c', 'd'],
          placeholderLabel: 'Pick it',
          onChanged: (_) {},
        ),
      );
      expect(find.byType(shadcn.Select<String>), findsOneWidget);
      expect(find.text('Pick it'), findsOneWidget);
    });

    testWidgets('segmented editor renders and reports taps', (tester) async {
      String? picked;
      await _pump(
        tester,
        PropSegmentedEditor(
          value: 'a',
          options: const ['a', 'b'],
          onChanged: (v) => picked = v,
        ),
      );
      expect(find.byType(shadcn.PrimaryButton), findsOneWidget);
      expect(find.byType(shadcn.OutlineButton), findsOneWidget);
      await tester.tap(find.text('b'));
      await tester.pump();
      expect(picked, 'b');
    });

    testWidgets('unranged number editor renders a stepper without a slider', (
      tester,
    ) async {
      final seen = <double>[];
      await _pump(
        tester,
        PropNumberEditor(
          value: 2,
          step: 1,
          isInt: true,
          onChanged: seen.add,
        ),
      );
      expect(find.byType(shadcn.Slider), findsNothing);
      // The editor is stateless: each nudge is computed from the pinned
      // `value: 2`, so both reports derive from 2 (the parent owns state and
      // rebuilds with the new value after each patch).
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(seen, [3.0]);
      await tester.tap(find.text('−'));
      await tester.pump();
      expect(seen, [3.0, 1.0]);
    });

    testWidgets('ranged number editor renders a slider', (tester) async {
      await _pump(
        tester,
        PropNumberEditor(
          value: 0.5,
          min: 0,
          max: 1,
          step: 0.05,
          onChanged: (_) {},
        ),
      );
      expect(find.byType(shadcn.Slider), findsOneWidget);
      expect(find.byType(shadcn.TextField), findsOneWidget);
    });

    testWidgets('color editor renders token dropdown plus hex field', (
      tester,
    ) async {
      await _pump(
        tester,
        PropColorEditor(value: 'primary', onChanged: (_) {}),
      );
      expect(find.byType(shadcn.Select<String>), findsOneWidget);
      expect(find.byType(shadcn.TextField), findsOneWidget);
      expect(find.text('#rrggbb'), findsOneWidget);
    });

    testWidgets('slot editor renders a read-only chip', (tester) async {
      await _pump(tester, const PropSlotEditor(label: 'child: avatar'));
      expect(find.text('child: avatar'), findsOneWidget);
      expect(find.byType(shadcn.SecondaryBadge), findsOneWidget);
    });
  });

  group('inspector wiring', () {
    testWidgets('enum edit persists to the store', (tester) async {
      final (store, nodeId, itemId) = _storeWithButton();
      await _pump(
        tester,
        InspectorPanel(store: store, nodeId: nodeId, itemId: itemId),
      );
      final selects = tester.widgetList<shadcn.Select<String>>(
        find.byType(shadcn.Select<String>),
      );
      final variant = selects.singleWhere((s) => s.value == 'primary');
      variant.onChanged!('secondary');
      await tester.pump();
      expect(
        store.doc.nodes
            .singleWhere((n) => n.id == nodeId)
            .items
            .singleWhere((i) => i.id == itemId)
            .props['variant'],
        'secondary',
      );
    });

    testWidgets('reset-override restores the default and clears the badge', (
      tester,
    ) async {
      final (store, nodeId, itemId) = _storeWithButton();
      await _pump(
        tester,
        InspectorPanel(store: store, nodeId: nodeId, itemId: itemId),
      );
      expect(find.text('modified'), findsNothing);

      await tester.enterText(find.byType(shadcn.TextField), 'Pay now');
      await tester.pump();
      Map<String, dynamic> props() => store.doc.nodes
          .singleWhere((n) => n.id == nodeId)
          .items
          .singleWhere((i) => i.id == itemId)
          .props;
      expect(props()['label'], 'Pay now');
      expect(find.text('modified'), findsOneWidget);

      await tester.tap(find.text('reset'));
      await tester.pump();
      expect(props()['label'], 'Button');
      expect(find.text('modified'), findsNothing);
      // DOCUMENTED LIMITATION: patchItem merges props and offers no
      // key-deletion path, so reset writes the default value back instead of
      // removing the key (true sparse delete needs a store clear-path).
      expect(
        props().containsKey('label'),
        isTrue,
        reason:
            'sparse-delete compromise: key remains with the default value; '
            'see inspector_panel.dart library docs',
      );
    });
  });

  group('dictated W3 params (landed in working tree)', () {
    // The W2 brief expected these patchNode params to be missing (W3-owned).
    // They have since landed in the working tree (`CanvasNode.mainAxis` /
    // `crossAxis` / `expand` / `flex` + matching patchNode params), so the
    // inspector wires them for real instead of parking TODO chips. These
    // tests pin the landed contract; if W3 reshapes the params, they fail
    // here first.
    CanvasNode rowOf(CanvasStore store, String rowId) =>
        store.doc.nodes.singleWhere((n) => n.id == rowId);

    test('patchNode persists container params and undo restores them', () {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      expect(rowOf(store, rowId).mainAxis, isNull);
      expect(rowOf(store, rowId).flex, isNull);

      store.patchNode(rowId, mainAxis: 'center', crossAxis: 'stretch');
      expect(rowOf(store, rowId).mainAxis, 'center');
      expect(rowOf(store, rowId).crossAxis, 'stretch');

      store.patchNode(rowId, expand: 'expanded', flex: 2);
      expect(rowOf(store, rowId).expand, 'expanded');
      expect(rowOf(store, rowId).flex, 2);

      expect(store.undo(), isTrue);
      expect(rowOf(store, rowId).expand, isNull);
      expect(rowOf(store, rowId).flex, isNull);
      expect(rowOf(store, rowId).mainAxis, 'center');

      expect(store.undo(), isTrue);
      expect(rowOf(store, rowId).mainAxis, isNull);
      expect(rowOf(store, rowId).crossAxis, isNull);

      // DOCUMENTED LIMITATION: null params are "leave unchanged" (all-null
      // is a no-op), so patchNode cannot clear a value back to null — the
      // alignment editors offer no reset affordance for this reason.
      store.patchNode(rowId, mainAxis: 'end');
      store.patchNode(rowId);
      expect(rowOf(store, rowId).mainAxis, 'end');
    });

    test('kExpandOptions matches the patchNode contract', () {
      expect(kExpandOptions, orderedEquals(['none', 'flex', 'expanded']));
    });

    testWidgets('row alignment + child flex editors write through patchNode', (
      tester,
    ) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      // No store reparent API exists at this runtime, so the child node is
      // seeded via replaceDoc (parentId = rowId).
      final base = store.doc;
      store.replaceDoc(
        ScreenDoc(
          screens: base.screens,
          nodes: [
            ...base.nodes,
            CanvasNode(
              id: 'c1',
              screenId: 's1',
              x: 0,
              y: 0,
              items: const [],
              parentId: rowId,
            ),
          ],
          theme: base.theme,
          meta: base.meta,
        ),
      );
      await _pump(tester, InspectorPanel(store: store, nodeId: rowId));
      expect(find.text('1 child'), findsOneWidget);
      expect(find.text('child layout'), findsOneWidget);
      expect(find.text('Default (start)'), findsOneWidget);
      expect(find.text('Default (center)'), findsOneWidget);

      String? placeholderOf(shadcn.Select<String> s) {
        final placeholder = s.placeholder;
        return placeholder is Text ? placeholder.data : null;
      }

      final selects = tester.widgetList<shadcn.Select<String>>(
        find.byType(shadcn.Select<String>),
      );
      selects
          .singleWhere(
            (s) => placeholderOf(s) == 'Default (start)',
          )
          .onChanged!('center');
      await tester.pump();
      expect(rowOf(store, rowId).mainAxis, 'center');

      selects
          .singleWhere(
            (s) => placeholderOf(s) == 'Default (center)',
          )
          .onChanged!('stretch');
      await tester.pump();
      expect(rowOf(store, rowId).crossAxis, 'stretch');

      selects
          .singleWhere(
            (s) => placeholderOf(s) == 'Default (none)',
          )
          .onChanged!('expanded');
      await tester.pump();
      expect(rowOf(store, rowId).expand, isNull);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == 'c1').expand,
        'expanded',
      );

      tester
          .widgetList<PropNumberEditor>(find.byType(PropNumberEditor))
          .single
          .onChanged(3.0);
      await tester.pump();
      expect(store.doc.nodes.singleWhere((n) => n.id == 'c1').flex, 3);

      // The gap stepper keeps working alongside the new editors.
      await tester.tap(find.text('+').first);
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      expect(rowOf(store, rowId).gap, 12.0);
    });
  });
}
