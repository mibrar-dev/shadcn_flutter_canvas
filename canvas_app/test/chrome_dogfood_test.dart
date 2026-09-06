/// Track N (chrome dogfood): the web-app chrome builds from the shared
/// shadcn kit (`package:canvas_app/shadcn_ui.dart`), never raw Material
/// interactive widgets. Representative coverage: rail tooltips + selection,
/// palette search filter, layers rename-dialog + delete flow, open-dialog
/// import flow, and the prompt copy button.
///
/// Absence checks are scoped to each chrome subtree (the `MaterialApp` /
/// `Scaffold` harness itself owns `Material`s, which are exempt).
import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/open_dialog.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/prompt_panel.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): chrome columns overflow the default
/// 800x600 test surface.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Reads every kit tooltip label under [scope] by evaluating each
/// `shadcn.Tooltip` builder (the tip only materializes on hover at runtime,
/// so `find.text` cannot see it while idle).
List<String> _kitTipLabels(WidgetTester tester, Finder scope) {
  final context = tester.element(scope);
  final tips = tester.widgetList<shadcn.Tooltip>(
    find.descendant(
      of: scope,
      matching: find.byType(shadcn.Tooltip),
    ),
  );
  final labels = <String>[];
  for (final tip in tips) {
    final built = tip.tooltip(context);
    if (built is shadcn.TooltipContainer && built.child is Text) {
      labels.add((built.child as Text).data ?? '');
    }
  }
  return labels;
}

/// No raw Material interactive widgets may remain under [scope].
void _expectNoRawChrome(WidgetTester tester, Finder scope) {
  for (final type in [Tooltip, IconButton, TextButton, TextField, AlertDialog]) {
    expect(
      find.descendant(of: scope, matching: find.byType(type)),
      findsNothing,
      reason: 'raw Material $type under $scope',
    );
  }
  expect(
    find.descendant(of: scope, matching: find.byType(InkWell)),
    findsNothing,
    reason: 'raw Material InkWell under $scope',
  );
}

void main() {
  // Y6 cutover (FORGE.md §1-2d): the icon rail is deleted; Layers lives
  // behind the shell's Library|Layers pills and theme panels live in the
  // bottom Theme disclosure. The rail dogfood test is removed with it —
  // intent preserved by keeping the segmented/icon-button kit coverage below.
  group('editor buttons dogfood', () {
    testWidgets('segmented + icon button tooltips come from the kit',
        (tester) async {
      var selected = 0;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EditorSegmented(
                  items: const [
                    EditorSegmentItem(icon: Icons.near_me, tooltip: 'Select'),
                    EditorSegmentItem(icon: Icons.pan_tool, tooltip: 'Pan'),
                  ],
                  selectedIndex: selected,
                  onSelect: (i) => selected = i,
                ),
                EditorIconButton(
                  icon: Icons.undo,
                  tooltip: 'Undo',
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final scope = find.byType(Column);
      _expectNoRawChrome(tester, scope);
      expect(
        _kitTipLabels(tester, scope),
        containsAll(['Select', 'Pan', 'Undo']),
      );

      await tester.tap(find.byIcon(Icons.pan_tool));
      await tester.pump();
      expect(selected, 1);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('parts palette dogfood', () {
    testWidgets('search filters tiles through the kit field', (tester) async {
      _useReferenceViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PartsPalette())),
      );
      await tester.pump();

      final scope = find.byType(PartsPalette);
      _expectNoRawChrome(tester, scope);
      expect(
        find.descendant(
          of: scope,
          matching: find.byType(shadcn.TextField),
        ),
        findsOneWidget,
      );

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

    testWidgets('collapse button still fires', (tester) async {
      _useReferenceViewport(tester);
      var collapsed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PartsPalette(onCollapse: () => collapsed++)),
        ),
      );
      await tester.pump();

      expect(
        _kitTipLabels(tester, find.byType(PartsPalette)),
        contains('Collapse'),
      );
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(collapsed, 1);
    });
  });

  group('layers panel dogfood', () {
    Widget harness(
      CanvasStore store, {
      String? selectedNodeId,
      ValueChanged<String?>? onSelectNode,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: LayersPanel(
            store: store,
            selectedNodeId: selectedNodeId,
            onSelectNode: onSelectNode ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('rename dialog flow renames via kit controls', (tester) async {
      final store = CanvasStore();
      await tester.pumpWidget(harness(store));
      await tester.pump();

      final scope = find.byType(LayersPanel);
      _expectNoRawChrome(tester, scope);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(shadcn.AlertDialog), findsOneWidget);
      final field = find.byType(shadcn.TextField);
      expect(field, findsOneWidget);
      expect(
        tester.widget<shadcn.TextField>(field).controller!.text,
        'Screen 1',
      );

      await tester.enterText(field, 'Gallery');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(shadcn.AlertDialog), findsNothing);
      expect(find.text('Gallery'), findsOneWidget);
      expect(store.doc.screens.single.name, 'Gallery');

      // Empty Save is a no-op close: dialog dismisses, name untouched.
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(shadcn.TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Gallery'), findsOneWidget);
      expect(store.doc.screens.single.name, 'Gallery');
    });

    testWidgets('row delete removes the node; edge moves disable',
        (tester) async {
      final store = CanvasStore();
      final id = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(id: store.uid(), kind: 'button', props: const {}),
        ],
      );
      String? selected;
      await tester.pumpWidget(
        harness(store, onSelectNode: (v) => selected = v),
      );
      await tester.pump();

      // Row tap still selects.
      await tester.tap(find.textContaining(id));
      await tester.pump();
      expect(selected, id);

      Finder actionFor(IconData icon, int at) => find.ancestor(
            of: find.byIcon(icon).at(at),
            matching: find.byType(shadcn.IconButton),
          );
      // Single row: both z-order edges disabled, never hidden.
      expect(
        tester.widget<shadcn.IconButton>(actionFor(Icons.arrow_upward, 0))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<shadcn.IconButton>(actionFor(Icons.arrow_downward, 0))
            .onPressed,
        isNull,
      );

      // Header delete comes first in tree order; the row delete is last.
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump();
      expect(store.doc.nodes, isEmpty);
    });
  });

  group('open dialog dogfood', () {
    testWidgets('pasted doc JSON imports and closes', (tester) async {
      final store = CanvasStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOpenDialog(context, store),
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(find.byType(shadcn.AlertDialog), findsOneWidget);

      final dialog = find.byType(shadcn.AlertDialog);
      _expectNoRawChrome(tester, dialog);

      // Bad input errors inline and keeps the dialog open.
      await tester.enterText(find.byType(shadcn.TextField), 'not json');
      await tester.tap(find.text('Import'));
      await tester.pump();
      expect(find.textContaining('Could not open'), findsOneWidget);
      expect(find.byType(shadcn.AlertDialog), findsOneWidget);

      // Valid doc JSON imports and closes.
      await tester.enterText(
        find.byType(shadcn.TextField),
        jsonEncode(CanvasStore().doc.toJson()),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.byType(shadcn.AlertDialog), findsNothing);
    });
  });

  group('prompt panel dogfood', () {
    testWidgets('copy button confirms inline', (tester) async {
      // The test binding answers no platform channels by default; without
      // this mock `Clipboard.setData` never completes and `_copy` stalls
      // before its confirmation `setState`.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        return null;
      });
      final store = CanvasStore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PromptPanel(doc: store.doc))),
      );
      await tester.pump();

      final scope = find.byType(PromptPanel);
      _expectNoRawChrome(tester, scope);
      expect(
        find.descendant(
          of: scope,
          matching: find.byType(shadcn.TextButton),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Copy'));
      // `_copy` awaits the (mocked) clipboard before `setState`, so one
      // pump flushes the platform future and a second rebuilds with it.
      await tester.pump();
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
    });
  });
}
