/// Track K interactivity + export tests: the inspector "On tap" editor
/// assigns/clears actions, a picker-assigned action navigates in preview,
/// deleting a targeted screen is refused, and the screen surface bg follows
/// the components theme for `surface` (chrome otherwise).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two-screen store: a `Pay` button on `s1` (`Screen 1`), plus an empty
/// `Done` screen. Returns `(store, nodeId, itemId, doneScreenId)`.
(CanvasStore, String, String, String) _storeWithTwoScreens() {
  final store = CanvasStore();
  final doneId = store.addScreen(name: 'Done');
  const itemId = 'i1';
  final nodeId = store.addNode(
    screenId: 's1',
    x: 16,
    y: 96,
    items: const [
      CanvasItem(
        id: itemId,
        kind: 'button',
        props: {'label': 'Pay', 'variant': 'primary'},
      ),
    ],
  );
  return (store, nodeId, itemId, doneId);
}

NodeAction? _actionOf(CanvasStore store, String nodeId, String itemId) =>
    store.doc.nodes
        .singleWhere((n) => n.id == nodeId)
        .items
        .singleWhere((i) => i.id == itemId)
        .action;

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

const _componentsLight = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: false,
  shape: 'rounded',
  motion: 'standard',
);

const _componentsDark = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

/// Kit scheme background as a Material color (same `toARGB32` conversion
/// idiom the surface fix uses in `phone_frame.dart`).
Color _kitBackground(CanvasTheme theme) =>
    Color(resolveCanvasThemeData(theme).colorScheme.background.toARGB32());

Future<void> _pumpSurface(
  WidgetTester tester,
  CanvasTheme theme,
  String bg,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EditorTheme(
        colors: EditorColors.dark,
        child: Scaffold(
          body: ThemedCanvas(
            theme: theme,
            child: ScreenSurface(
              screen: CanvasScreen(
                id: 's1',
                name: 'Home',
                x: 0,
                y: 0,
                bg: bg,
              ),
              nodes: const [],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // resolveCanvasThemeData mutates the global InstalledThemePreset.current;
  // preserve it across tests.
  late shadcn.RegistryThemePreset prevPreset;
  setUp(() => prevPreset = shadcn.InstalledThemePreset.current);
  tearDown(() => shadcn.InstalledThemePreset.current = prevPreset);

  group('inspector On tap editor', () {
    testWidgets('target picker assigns the action (slide default)', (
      tester,
    ) async {
      final (store, nodeId, itemId, doneId) = _storeWithTwoScreens();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      expect(find.text('On tap'), findsOneWidget);
      expect(_actionOf(store, nodeId, itemId), isNull);

      tester
          .widget<shadcn.Select<String>>(
            find.byKey(const ValueKey('action-target')),
          )
          .onChanged!(doneId);
      await tester.pump();

      final action = _actionOf(store, nodeId, itemId);
      expect(action, isNotNull);
      expect(action!.to, doneId);
      expect(action.transition, 'slide');
    });

    testWidgets('transition select keeps the target, writes transition', (
      tester,
    ) async {
      final (store, nodeId, itemId, doneId) = _storeWithTwoScreens();
      store.setItemAction(
        nodeId,
        itemId,
        NodeAction(to: doneId, transition: 'slide'),
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      // Options are exactly the legal contract set (never invented).
      final transitionEditor = tester.widget<PropSelectEditor>(
        find.byKey(const ValueKey('action-transition')),
      );
      expect(
        transitionEditor.options,
        orderedEquals(kAiAllowedTransitions.toList()..sort()),
      );

      transitionEditor.onChanged!('fade');
      await tester.pump();

      final action = _actionOf(store, nodeId, itemId);
      expect(action, isNotNull);
      expect(action!.to, doneId);
      expect(action.transition, 'fade');
    });

    testWidgets('Clear action button clears (disabled without action)', (
      tester,
    ) async {
      final (store, nodeId, itemId, _) = _storeWithTwoScreens();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      // No action yet: the button is disabled.
      expect(
        tester
            .widget<shadcn.OutlineButton>(
              find.byKey(const ValueKey('action-clear')),
            )
            .onPressed,
        isNull,
      );

      store.setItemAction(
        nodeId,
        itemId,
        NodeAction(to: store.doc.screens.last.id, transition: 'slide'),
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('action-clear')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('action-clear')));
      await tester.pump();
      expect(_actionOf(store, nodeId, itemId), isNull);
    });

    testWidgets('dangling target shows a missing note, not a value', (
      tester,
    ) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: const [
          CanvasItem(id: 'i1', kind: 'button', props: {'label': 'Lost'}),
        ],
      );
      store.setItemAction(
        nodeId,
        'i1',
        const NodeAction(to: 'gone', transition: 'fade'),
      );
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: 'i1');

      expect(find.text('Target screen “gone” is missing.'), findsOneWidget);
      expect(
        tester
            .widget<shadcn.Select<String>>(
              find.byKey(const ValueKey('action-target')),
            )
            .value,
        isNull,
      );
    });
  });

  group('preview navigation', () {
    testWidgets('picker-assigned action navigates, back pops', (tester) async {
      final (store, nodeId, itemId, doneId) = _storeWithTwoScreens();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      tester
          .widget<shadcn.Select<String>>(
            find.byKey(const ValueKey('action-target')),
          )
          .onChanged!(doneId);
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(doc: store.doc)),
        ),
      );
      expect(find.text('Pay'), findsOneWidget);

      // Real tap on the widget pushes the Done screen.
      await tester.tap(find.text('Pay'));
      await tester.pump();
      expect(find.text('Pay'), findsNothing);
      expect(find.text('Done'), findsOneWidget);

      // Back pops to the start screen.
      await tester.tap(find.text('‹ Back'));
      await tester.pump();
      expect(find.text('Pay'), findsOneWidget);
    });
  });

  group('screen delete guard', () {
    test('deleting a targeted screen is refused until the action clears', () {
      final (store, nodeId, itemId, doneId) = _storeWithTwoScreens();
      store.setItemAction(
        nodeId,
        itemId,
        NodeAction(to: doneId, transition: 'slide'),
      );

      final dangling = store.deleteScreen(doneId);
      expect(dangling, isNotEmpty);
      expect(store.doc.screens.map((s) => s.id), contains(doneId));

      store.setItemAction(nodeId, itemId, null);
      expect(store.deleteScreen(doneId), isEmpty);
      expect(store.doc.screens.map((s) => s.id), isNot(contains(doneId)));
    });
  });

  group('screen surface background', () {
    testWidgets('surface follows components theme, other follows chrome', (
      tester,
    ) async {
      await _pumpSurface(tester, _componentsLight, 'surface');
      final lightSurface = tester
          .widget<PhoneFrame>(find.byType(PhoneFrame))
          .screenColor;
      expect(lightSurface, _kitBackground(_componentsLight));
      expect(lightSurface, isNot(EditorColors.dark.surface));

      await _pumpSurface(tester, _componentsLight, 'custom');
      expect(
        tester.widget<PhoneFrame>(find.byType(PhoneFrame)).screenColor,
        EditorColors.dark.surface,
      );

      await _pumpSurface(tester, _componentsDark, 'surface');
      expect(
        tester.widget<PhoneFrame>(find.byType(PhoneFrame)).screenColor,
        _kitBackground(_componentsDark),
      );
    });
  });
}
