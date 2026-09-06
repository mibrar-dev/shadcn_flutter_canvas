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

/// Minimal 3-screen chain doc: Showcase → Display → Controls → Showcase.
/// Item labels stay distinct from screen names so `find.text` on a header
/// name is unambiguous (the player bar shows `current?.name`).
ScreenDoc _chainDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Showcase', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Display', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's3', 'name': 'Controls', 'x': 960.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'To Display',
              'action': {'to': 's2', 'transition': 'slide'},
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's2',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i2',
              'kind': 'button',
              'label': 'To Controls',
              'action': {'to': 's3', 'transition': 'slide'},
            },
          ],
        },
        {
          'id': 'n3',
          'screenId': 's3',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i3',
              'kind': 'button',
              'label': 'To Showcase',
              'action': {'to': 's1', 'transition': 'slide'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Chain', 'brief': ''},
    });

/// Single screen whose only action points at a missing screen id.
ScreenDoc _unknownTargetDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Safe', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Ghost Link',
              'action': {'to': 'gone', 'transition': 'slide'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Unknown target', 'brief': ''},
    });

/// Home screen with an always-visible item plus a mobile-hidden node whose
/// item navigates to Away; Away carries a plain marker item.
ScreenDoc _tierNavDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Away', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i0', 'kind': 'button', 'label': 'Always Here'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 16.0,
          'y': 200.0,
          'hiddenOn': ['mobile'],
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Secret Next',
              'action': {'to': 's2', 'transition': 'slide'},
            },
          ],
        },
        {
          'id': 'n3',
          'screenId': 's2',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Arrived'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Tier nav', 'brief': ''},
    });

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PreviewPlayer(doc: doc))),
  );
}

/// Wide viewport so desktop stages (1100) are never clamped by the window.
void _wideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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

    testWidgets('chain navigates Showcase→Display→Controls→Showcase', (
      tester,
    ) async {
      await _pumpPreview(tester, _chainDoc());
      expect(find.text('Showcase'), findsOneWidget);
      expect(find.text('To Display'), findsOneWidget);

      await tester.tap(find.text('To Display'));
      await tester.pump();
      expect(find.text('Display'), findsOneWidget);
      expect(find.text('To Controls'), findsOneWidget);
      expect(find.text('To Display'), findsNothing);

      await tester.tap(find.text('To Controls'));
      await tester.pump();
      expect(find.text('Controls'), findsOneWidget);
      expect(find.text('To Showcase'), findsOneWidget);
      expect(find.text('To Controls'), findsNothing);

      await tester.tap(find.text('To Showcase'));
      await tester.pump();
      expect(find.text('Showcase'), findsOneWidget);
      expect(find.text('To Display'), findsOneWidget);
    });

    testWidgets('back mid-chain returns through the stack', (tester) async {
      var exited = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(doc: _chainDoc(), onExit: () => exited = true),
          ),
        ),
      );

      await tester.tap(find.text('To Display'));
      await tester.pump();
      await tester.tap(find.text('To Controls'));
      await tester.pump();
      expect(find.text('Controls'), findsOneWidget);

      // Back mid-chain returns to Display, then to Showcase.
      await tester.tap(find.text('‹ Back'));
      await tester.pump();
      expect(find.text('Display'), findsOneWidget);
      expect(find.text('To Controls'), findsOneWidget);

      await tester.tap(find.text('‹ Back'));
      await tester.pump();
      expect(find.text('Showcase'), findsOneWidget);
      expect(find.text('To Display'), findsOneWidget);
      expect(exited, isFalse);

      // Back at the root exits to the editor.
      await tester.tap(find.text('‹ Back'));
      await tester.pump();
      expect(exited, isTrue);
    });

    testWidgets('unknown target renders and taps safely without navigating', (
      tester,
    ) async {
      await _pumpPreview(tester, _unknownTargetDoc());
      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Ghost Link'), findsOneWidget);

      // The player ignores taps whose target screen is missing: no crash,
      // no navigation, still on the same screen.
      await tester.tap(find.text('Ghost Link'));
      await tester.pump();
      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Ghost Link'), findsOneWidget);
    });

    testWidgets('hidden-tier action is untappable until its tier is shown', (
      tester,
    ) async {
      _wideViewport(tester);
      await _pumpPreview(tester, _tierNavDoc());

      // Phone stage is the mobile tier: the mobile-hidden node (and its
      // navigation action) is not rendered, hence not tappable.
      expect(find.text('mobile · 390'), findsOneWidget);
      expect(find.text('Always Here'), findsOneWidget);
      expect(find.text('Secret Next'), findsNothing);

      // Desktop-fluid preset re-tiers to desktop: the node renders and its
      // action navigates to Away.
      await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
      await tester.pump();
      expect(find.text('desktop · 1100'), findsOneWidget);
      expect(find.text('Secret Next'), findsOneWidget);

      await tester.tap(find.text('Secret Next'));
      await tester.pump();
      expect(find.text('Away'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Secret Next'), findsNothing);
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
      final lightSurface =
          tester.widget<PhoneFrame>(find.byType(PhoneFrame)).screenColor;
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
