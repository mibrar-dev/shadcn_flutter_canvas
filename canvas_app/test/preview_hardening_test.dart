/// Track FF3 (preview production pass) hardening tests for [PreviewPlayer].
///
/// - Throwing-node isolation: a crashing catalog builder renders an inline
///   error card (kind + message) while siblings still render. Injection goes
///   through the test-only [PreviewPlayer.debugItemBuilder] hook (documented
///   on the widget; reset in tearDown) — the least invasive seam, since
///   catalog builders tolerate bad props by design and no bad doc can be
///   relied on to throw.
/// - Empty states: zero-screen docs and zero-node screens render designed
///   kit states (not blank stages) in both brightnesses; fully-hidden tiers
///   name the tier.
/// - Device default: the stage honors the CURRENT screen's `device` (not
///   always phone); a manual picker choice sticks across navigations.
/// - Chrome consistency: back bar (Back + screen name), hairline divider,
///   device picker, and tier chip stay mounted in light + dark.
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenDoc _doc({
  List<Map<String, dynamic>> screens = const [
    {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
  ],
  List<Map<String, dynamic>> nodes = const [],
  bool dark = false,
}) =>
    ScreenDoc.fromJson({
      'screens': screens,
      'nodes': nodes,
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': dark,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Hardening', 'brief': ''},
    });

Map<String, dynamic> _buttonNode(
  String nodeId,
  String screenId,
  String label, {
  String? to,
}) =>
    {
      'id': nodeId,
      'screenId': screenId,
      'x': 16.0,
      'y': 96.0,
      'items': [
        {
          'id': 'i-$nodeId',
          'kind': 'button',
          'label': label,
          if (to != null) 'action': {'to': to, 'transition': 'slide'},
        },
      ],
    };

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PreviewPlayer(doc: doc))),
  );
}

/// Wide viewport so tablet/desktop stages are never clamped.
void _wideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

double _stageWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('previewStage'))).width;

void main() {
  tearDown(() {
    PreviewPlayer.debugItemBuilder = null;
  });

  group('throwing-node isolation', () {
    testWidgets('crashing widget renders an inline card, siblings survive',
        (tester) async {
      PreviewPlayer.debugItemBuilder = (kind, props, children, scope) {
        if (kind == 'boom') throw StateError('boom failed');
        return buildCatalogItem(kind, props, children, scope);
      };
      await _pumpPreview(
        tester,
        _doc(nodes: [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 16.0,
            'y': 96.0,
            'items': [
              {'id': 'i1', 'kind': 'boom', 'label': 'Crash'},
            ],
          },
          _buttonNode('n2', 's1', 'Survivor'),
        ]),
      );

      // Inline error card names the kind and carries the message…
      expect(find.text('Preview error: boom'), findsOneWidget);
      expect(find.textContaining('boom failed'), findsOneWidget);
      // …while the healthy sibling still renders and the stage is intact.
      expect(find.text('Survivor'), findsOneWidget);
      expect(find.byKey(const ValueKey('previewStage')), findsOneWidget);
    });

    testWidgets('unknown kinds keep the honest catalog fallback', (
      tester,
    ) async {
      await _pumpPreview(
        tester,
        _doc(nodes: [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 16.0,
            'y': 96.0,
            'items': [
              {'id': 'i1', 'kind': 'definitely_not_a_kind'},
            ],
          },
          _buttonNode('n2', 's1', 'Survivor'),
        ]),
      );

      // Unknown is not a crash: no error card, catalog fallback preserved.
      expect(find.textContaining('Preview error'), findsNothing);
      expect(
        find.text('unknown: definitely_not_a_kind'),
        findsOneWidget,
      );
      expect(find.text('Survivor'), findsOneWidget);
    });
  });

  group('empty states', () {
    for (final dark in [false, true]) {
      testWidgets('zero-screen doc renders a designed state (dark=$dark)', (
        tester,
      ) async {
        await _pumpPreview(tester, _doc(screens: [], dark: dark));

        expect(find.text('No screens yet'), findsOneWidget);
        expect(
          find.text('Add a screen in the editor to preview it here.'),
          findsOneWidget,
        );
        // Chrome stays mounted around the state.
        expect(find.text('‹ Back'), findsOneWidget);
        expect(find.text('No screens'), findsOneWidget);
        expect(find.byKey(const ValueKey('previewStage')), findsOneWidget);
      });

      testWidgets('zero-node screen renders a designed state (dark=$dark)', (
        tester,
      ) async {
        await _pumpPreview(tester, _doc(dark: dark));

        expect(find.text('This screen is empty'), findsOneWidget);
        expect(
          find.text('Add components on the canvas — they will appear here.'),
          findsOneWidget,
        );
        expect(find.text('Home'), findsOneWidget);
        expect(find.byKey(const ValueKey('previewStage')), findsOneWidget);
      });
    }

    testWidgets('fully-hidden tier names the tier', (tester) async {
      await _pumpPreview(
        tester,
        _doc(nodes: [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 16.0,
            'y': 96.0,
            'hiddenOn': ['mobile'],
            'items': [
              {'id': 'i1', 'kind': 'button', 'label': 'Hidden Away'},
            ],
          },
        ]),
      );

      // Default phone stage is the mobile tier: content filtered, state shown.
      expect(find.text('Hidden Away'), findsNothing);
      expect(find.text('Nothing to show on mobile'), findsOneWidget);
    });
  });

  group('device default follows the current screen', () {
    ScreenDoc twoScreenDoc() => _doc(
          screens: const [
            {
              'id': 's1',
              'name': 'Tablet Home',
              'x': 0.0,
              'y': 0.0,
              'bg': 'surface',
              'device': 'tablet',
            },
            {
              'id': 's2',
              'name': 'Phone Done',
              'x': 480.0,
              'y': 0.0,
              'bg': 'surface',
            },
          ],
          nodes: [
            _buttonNode('n1', 's1', 'Go', to: 's2'),
            _buttonNode('n2', 's2', 'Arrived'),
          ],
        );

    testWidgets('stage opens on the start screen device, follows navigation',
        (tester) async {
      _wideViewport(tester);
      await _pumpPreview(tester, twoScreenDoc());

      // s1 stores tablet: stage honors it instead of always opening phone.
      expect(_stageWidth(tester), 768);
      expect(find.text('tablet · 768'), findsOneWidget);

      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(find.text('Arrived'), findsOneWidget);
      expect(_stageWidth(tester), 390);
      expect(find.text('mobile · 390'), findsOneWidget);

      await tester.tap(find.text('‹ Back'));
      await tester.pump();
      expect(find.text('Go'), findsOneWidget);
      expect(_stageWidth(tester), 768);
    });

    testWidgets('startScreenId device is honored', (tester) async {
      _wideViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(doc: twoScreenDoc(), startScreenId: 's2'),
          ),
        ),
      );

      expect(find.text('Arrived'), findsOneWidget);
      expect(_stageWidth(tester), 390);
    });

    testWidgets('manual picker choice sticks across navigations', (
      tester,
    ) async {
      _wideViewport(tester);
      await _pumpPreview(tester, twoScreenDoc());

      await tester.tap(find.byIcon(Icons.desktop_mac_outlined));
      await tester.pump();
      expect(_stageWidth(tester), 1440);

      // Navigate: the manual pick wins over the all-phone s2 default.
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(find.text('Arrived'), findsOneWidget);
      expect(_stageWidth(tester), 1440);
      expect(find.text('desktop · 1440'), findsOneWidget);
    });
  });

  group('chrome consistency', () {
    for (final dark in [false, true]) {
      testWidgets('top bar, divider, picker, tier chip mount (dark=$dark)', (
        tester,
      ) async {
        _wideViewport(tester);
        await _pumpPreview(
          tester,
          _doc(
            dark: dark,
            nodes: [_buttonNode('n1', 's1', 'Hello')],
          ),
        );

        expect(find.text('‹ Back'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('previewChromeDivider')),
          findsOneWidget,
        );
        // Device picker strip + landscape toggle.
        expect(find.byIcon(Icons.smartphone), findsOneWidget);
        expect(find.byIcon(Icons.tablet_mac), findsOneWidget);
        expect(
          find.byIcon(Icons.desktop_windows_outlined),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
        // Tier chip keeps its "<tier> · <width>" contract.
        expect(find.text('mobile · 390'), findsOneWidget);
        expect(find.text('Hello'), findsOneWidget);
      });
    }
  });
}
