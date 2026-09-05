/// Track J registry builder tests: every newly-implemented builder pumps
/// under light + dark with defaults and with representative props.
///
/// Each test asserts no exception plus the expected text/key widget, so the
/// triage screenshot (`unknown: basic` / `unknown: card_image` broken-image
/// boxes) cannot regress: these kinds now resolve to real kit widgets.
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 17 Track J kinds: `basic`, `card_image`, `scaffold` (triage priority)
/// plus the palette-visible batch.
const _kNewKinds = [
  'basic',
  'card_image',
  'scaffold',
  'collapsible',
  'steps',
  'timeline',
  'outlined_container',
  'hidden',
  'keyboard_shortcut',
  'tracker',
  'chat',
  'selectable',
  'star_rating',
  'clickable',
  'scrollbar',
  'pagination',
  'alert_dialog',
];

Future<void> _pump(
  WidgetTester tester,
  Widget widget, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(body: widget),
    ),
  );
}

void main() {
  group('track J wiring', () {
    test('all new kinds are catalog entries bridged by the registry', () {
      expect(_kNewKinds, hasLength(17));
      for (final kind in _kNewKinds) {
        final entry = findEntry(kind);
        expect(entry, isNotNull, reason: 'no catalog entry $kind');
        expect(entry!.defaults, isNotEmpty, reason: '$kind defaults');
        final reg = findRegistryEntry(kind);
        expect(reg, isNotNull, reason: 'no registry entry $kind');
        expect(reg!.canvasReady, isTrue, reason: kind);
        expect(reg.label, entry.label, reason: kind);
      }
    });

    testWidgets('new builders never render the unknown-kind fallback', (
      tester,
    ) async {
      for (final kind in _kNewKinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
        expect(find.text('unknown: $kind'), findsNothing, reason: kind);
        expect(find.text('canvas-ready coming soon'), findsNothing);
      }
    });

    testWidgets('new builders tolerate empty props (defaults kick in)', (
      tester,
    ) async {
      for (final kind in _kNewKinds) {
        await _pump(
          tester,
          buildCatalogItem(kind, Map<String, dynamic>.of(
            findEntry(kind)!.defaults,
          )),
        );
      }
      for (final kind in _kNewKinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
      }
    });
  });

  group('basic', () {
    testWidgets('defaults render the flexible row (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('basic', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Basic), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Subtitle'), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      }
    });

    testWidgets('representative props incl. hidden slots (light + dark)', (
      tester,
    ) async {
      const props = {
        'title': 'Ada',
        'subtitle': 'Lovelace',
        'content': 'Analytical Engine',
        'showLeading': false,
        'showTrailing': false,
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('basic', props), dark: dark);
        expect(find.byType(shadcn.Basic), findsOneWidget);
        expect(find.text('Ada'), findsOneWidget);
        expect(find.text('Lovelace'), findsOneWidget);
        expect(find.text('Analytical Engine'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      }
    });
  });

  group('card_image', () {
    testWidgets('defaults render kit CardImage with theme art (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('card_image', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.CardImage), findsOneWidget);
        expect(find.text('Card title'), findsOneWidget);
        expect(find.text('Card subtitle'), findsOneWidget);
        // Triage trap: the kit preview uses Image.network (404 box) — the
        // catalog art is a theme-token container, never a network image.
        expect(find.byType(Image), findsNothing);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'title': 'Sunset', 'subtitle': 'Golden hour'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('card_image', props),
          dark: dark,
        );
        expect(find.byType(shadcn.CardImage), findsOneWidget);
        expect(find.text('Sunset'), findsOneWidget);
        expect(find.text('Golden hour'), findsOneWidget);
      }
    });
  });

  group('scaffold', () {
    testWidgets('defaults render the default app shell (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('scaffold', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Scaffold), findsOneWidget);
        expect(find.byType(shadcn.AppBar), findsOneWidget);
        expect(find.text('My App'), findsOneWidget);
        expect(find.text('Welcome'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'title': 'Shop', 'body': 'Products'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('scaffold', props),
          dark: dark,
        );
        expect(find.byType(shadcn.Scaffold), findsOneWidget);
        expect(find.text('Shop'), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
      }
    });
  });

  group('collapsible', () {
    testWidgets('defaults render trigger + content (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('collapsible', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Collapsible), findsOneWidget);
        expect(find.text('Show more'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'trigger': 'Details',
        'content': 'Extra info',
        'expanded': true,
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('collapsible', props),
          dark: dark,
        );
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Extra info'), findsOneWidget);
      }
    });
  });

  group('steps', () {
    testWidgets('defaults render two steps (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('steps', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Steps), findsOneWidget);
        expect(find.text('Step 1'), findsOneWidget);
        expect(find.text('First step details'), findsOneWidget);
        expect(find.text('Step 2'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'step1': 'Order',
        'detail1': 'Place the order',
        'step2': 'Pay',
        'detail2': 'Complete payment',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('steps', props),
          dark: dark,
        );
        expect(find.text('Order'), findsOneWidget);
        expect(find.text('Complete payment'), findsOneWidget);
      }
    });
  });

  group('timeline', () {
    testWidgets('defaults render two entries (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('timeline', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Timeline), findsOneWidget);
        expect(find.text('9:00 AM'), findsOneWidget);
        expect(find.text('Kickoff'), findsOneWidget);
        expect(find.text('Review'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'time1': '8:00 AM',
        'title1': 'Standup',
        'detail1': 'Daily sync',
        'time2': '5:00 PM',
        'title2': 'Demo',
        'detail2': 'Sprint demo',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('timeline', props),
          dark: dark,
        );
        expect(find.text('Standup'), findsOneWidget);
        expect(find.text('Sprint demo'), findsOneWidget);
      }
    });
  });

  group('outlined_container', () {
    testWidgets('defaults render the container (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('outlined_container', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.OutlinedContainer), findsOneWidget);
        expect(find.text('Outlined'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('outlined_container', {'label': 'Notice'}),
          dark: dark,
        );
        expect(find.text('Notice'), findsOneWidget);
      }
    });
  });

  group('hidden', () {
    testWidgets('visible by default (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hidden', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Hidden), findsOneWidget);
        expect(find.text('Hidden content'), findsOneWidget);
      }
    });

    testWidgets('hidden flag fades the child out (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hidden', {
            'label': 'Shh',
            'hidden': true,
          }),
          dark: dark,
        );
        expect(find.byType(shadcn.Hidden), findsOneWidget);
        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity).first,
        );
        expect(opacity.opacity, 0.0);
      }
    });
  });

  group('keyboard_shortcut', () {
    testWidgets('defaults render keycaps (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('keyboard_shortcut', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.KeyboardDisplay), findsOneWidget);
      }
    });

    testWidgets('representative + unknown keys never crash (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('keyboard_shortcut', {'keys': 'Shift+Alt+S'}),
          dark: dark,
        );
        expect(find.byType(shadcn.KeyboardDisplay), findsOneWidget);
        await _pump(
          tester,
          buildCatalogItem('keyboard_shortcut', {'keys': '???'}),
          dark: dark,
        );
        expect(find.byType(shadcn.KeyboardDisplay), findsOneWidget);
      }
    });
  });

  group('tracker', () {
    testWidgets('defaults render three segments (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tracker', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Tracker), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'segments': 5, 'level': 'critical'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tracker', props),
          dark: dark,
        );
        expect(find.byType(shadcn.Tracker), findsOneWidget);
      }
    });

    testWidgets('unknown level falls back to fine (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tracker', {'level': 'bogus'}),
          dark: dark,
        );
        expect(find.byType(shadcn.Tracker), findsOneWidget);
      }
    });
  });

  group('chat', () {
    testWidgets('defaults render the bubble (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('chat', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.ChatBubble), findsOneWidget);
        expect(find.text('Hello!'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('chat', {'message': 'On my way'}),
          dark: dark,
        );
        expect(find.text('On my way'), findsOneWidget);
      }
    });
  });

  group('selectable', () {
    testWidgets('defaults render selectable text (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('selectable', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.SelectableText), findsOneWidget);
        expect(find.text('Select me'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('selectable', {'text': 'Copy this'}),
          dark: dark,
        );
        expect(find.text('Copy this'), findsOneWidget);
      }
    });
  });

  group('star_rating', () {
    testWidgets('defaults render stars (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('star_rating', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.StarRating), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'value': 4.5, 'max': 5.0};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('star_rating', props),
          dark: dark,
        );
        final stars = tester.widget<shadcn.StarRating>(
          find.byType(shadcn.StarRating),
        );
        expect(stars.value, 4.5);
        expect(stars.max, 5.0);
      }
    });
  });

  group('clickable', () {
    testWidgets('defaults render the surface (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('clickable', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Clickable), findsOneWidget);
        expect(find.text('Tap me'), findsOneWidget);
      }
    });

    testWidgets('representative props + tap never crash (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('clickable', {'label': 'Press'}),
          dark: dark,
        );
        expect(find.text('Press'), findsOneWidget);
        await tester.tap(find.text('Press'));
        await tester.pump();
        expect(find.text('Press'), findsOneWidget);
      }
    });
  });

  group('scrollbar', () {
    testWidgets('defaults render the wrapper (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('scrollbar', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Scrollbar), findsOneWidget);
        expect(find.text('Scrollable content'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('scrollbar', {'label': 'Long list'}),
          dark: dark,
        );
        expect(find.text('Long list'), findsOneWidget);
      }
    });
  });

  group('pagination', () {
    testWidgets('defaults render page controls (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('pagination', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Pagination), findsOneWidget);
        expect(find.text('1'), findsWidgets);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'page': 2, 'totalPages': 7};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('pagination', props),
          dark: dark,
        );
        final pager = tester.widget<shadcn.Pagination>(
          find.byType(shadcn.Pagination),
        );
        expect(pager.page, 2);
        expect(pager.totalPages, 7);
      }
    });
  });

  group('alert_dialog', () {
    testWidgets('defaults render title + actions (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('alert_dialog', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.AlertDialog), findsOneWidget);
        expect(find.text('Are you sure?'), findsOneWidget);
        expect(find.text('This action cannot be undone.'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
      }
    });

    testWidgets('actions hide on demand (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('alert_dialog', {'showActions': false}),
          dark: dark,
        );
        expect(find.byType(shadcn.AlertDialog), findsOneWidget);
        expect(find.text('Close'), findsNothing);
      }
    });
  });

  group('triage regression', () {
    testWidgets('card description renders inside its Card', (tester) async {
      await _pump(tester, buildCatalogItem('card', {}));
      expect(
        find.descendant(
          of: find.byType(shadcn.Card),
          matching: find.text('Description'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(shadcn.Card),
          matching: find.text('Title'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('scaffold + card_image pump inside an unbounded canvas column', (
      tester,
    ) async {
      // Mirrors phone_frame.dart root columns (mainAxisSize.min, unbounded
      // height): the fixed-height shells keep the kit flexes bounded. The
      // scroll view mirrors the scrollable canvas surface (the shells sum
      // past the 600px test viewport).
      for (final dark in [false, true]) {
        await _pump(
          tester,
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildCatalogItem('scaffold', {}),
                buildCatalogItem('card_image', {}),
                buildCatalogItem('basic', {}),
              ],
            ),
          ),
          dark: dark,
        );
        expect(find.byType(shadcn.Scaffold), findsOneWidget);
        expect(find.byType(shadcn.CardImage), findsOneWidget);
        // CardImage embeds a Basic for its title block, plus the standalone
        // basic node below it.
        expect(find.byType(shadcn.Basic), findsNWidgets(2));
        expect(find.text('My App'), findsOneWidget);
        expect(find.text('Card title'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
      }
    });
  });
}
