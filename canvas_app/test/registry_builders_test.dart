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
// Direct import: `TabList`/`TabItem` live in the tabs barrel, whose
// `TabChild` family is hidden from the kit barrel (see component_catalog).
import 'package:flutter_shadcn_kit/registry/components/navigation/tabs/tabs.dart'
    as tabs;
// Direct import: `Table`/`TableRow` are hidden from the kit barrel
// (material conflicts), so the `shadcn.` prefix resolves to material's
// `Table` instead of the kit's (see component_catalog).
import 'package:flutter_shadcn_kit/registry/components/layout/table/table.dart'
    as table;

/// The 17 Track P kinds: pickers (input_otp, calendar, date/time, carousel,
/// color), grids (tree, table), form shells, color shells, and the
/// feature carousel.
const _kTrackPKinds = [
  'input_otp',
  'calendar',
  'date_picker',
  'time_picker',
  'carousel',
  'tree',
  'table',
  'form',
  'form_field',
  'formatted_input',
  'validated',
  'color_picker',
  'color_input',
  'hsl',
  'hsv',
  'history',
  'feature_carousel',
];

/// The 15 Track M kinds: 10 overlay-driven inline forms plus the
/// tab-controller trio, stepper, and slider.
const _kTrackMKinds = [
  'menu',
  'popover',
  'popup',
  'menubar',
  'dropdown_menu',
  'context_menu',
  'hover_card',
  'command',
  'swiper',
  'refresh_trigger',
  'tab_container',
  'tab_list',
  'tab_pane',
  'stepper',
  'slider',
];

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

  group('track M wiring', () {
    test('all new kinds are catalog entries bridged by the registry', () {
      expect(_kTrackMKinds, hasLength(15));
      for (final kind in _kTrackMKinds) {
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
      for (final kind in _kTrackMKinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
        expect(find.text('unknown: $kind'), findsNothing, reason: kind);
        expect(find.text('canvas-ready coming soon'), findsNothing);
      }
    });

    testWidgets('new builders tolerate empty props (defaults kick in)', (
      tester,
    ) async {
      for (final kind in _kTrackMKinds) {
        await _pump(
          tester,
          buildCatalogItem(kind, Map<String, dynamic>.of(
            findEntry(kind)!.defaults,
          )),
        );
      }
      for (final kind in _kTrackMKinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
      }
    });
  });

  group('menu', () {
    testWidgets('defaults render the inline popup (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('menu', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.MenuPopup), findsOneWidget);
        expect(find.text('File'), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'heading': 'Edit', 'item1': 'Cut', 'item2': 'Paste'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('menu', props), dark: dark);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Cut'), findsOneWidget);
        expect(find.text('Paste'), findsOneWidget);
      }
    });
  });

  group('popover', () {
    testWidgets('defaults render trigger + inline content (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('popover', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.PrimaryButton), findsOneWidget);
        expect(find.byType(shadcn.ModalContainer), findsOneWidget);
        expect(find.text('Open Popover'), findsOneWidget);
        expect(find.text('Popover title'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'trigger': 'Details',
        'title': 'More info',
        'body': 'Extra context here.',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('popover', props), dark: dark);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('More info'), findsOneWidget);
        expect(find.text('Extra context here.'), findsOneWidget);
      }
    });
  });

  group('popup', () {
    testWidgets('defaults render the styled container (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('popup', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.MenuPopup), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'item1': 'Account', 'item2': 'Billing', 'item3': 'Logout'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('popup', props), dark: dark);
        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Billing'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
      }
    });
  });

  group('menubar', () {
    testWidgets('defaults render the desktop bar (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('menubar', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Menubar), findsOneWidget);
        expect(find.text('File'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'menu1': 'View', 'menu2': 'Tools'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('menubar', props), dark: dark);
        expect(find.text('View'), findsOneWidget);
        expect(find.text('Tools'), findsOneWidget);
      }
    });
  });

  group('dropdown_menu', () {
    testWidgets('defaults render the menu list (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('dropdown_menu', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.DropdownMenu), findsOneWidget);
        expect(find.text('My Account'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'heading': 'Team',
        'item1': 'Invite',
        'item2': 'Leave',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('dropdown_menu', props),
          dark: dark,
        );
        expect(find.text('Team'), findsOneWidget);
        expect(find.text('Invite'), findsOneWidget);
        expect(find.text('Leave'), findsOneWidget);
      }
    });
  });

  group('context_menu', () {
    testWidgets('defaults render the trigger child (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('context_menu', {}),
          dark: dark,
        );
        // The menu items live in the right-click overlay; canvas shows the
        // trigger child (same honest-static convention as tooltip).
        expect(find.byType(shadcn.ContextMenu), findsOneWidget);
        expect(find.text('Right-click me'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'hint': 'Options', 'item1': 'Cut', 'item2': 'Copy'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('context_menu', props),
          dark: dark,
        );
        expect(find.text('Options'), findsOneWidget);
      }
    });
  });

  group('hover_card', () {
    testWidgets('defaults render the handle (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hover_card', {}),
          dark: dark,
        );
        // The rich preview lives in the hover overlay; canvas shows the
        // handle (same honest-static convention as tooltip).
        expect(find.byType(shadcn.HoverCard), findsOneWidget);
        expect(find.text('Hover card'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'handle': '@canvas',
        'title': 'Preview',
        'body': 'Details on hover.',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('hover_card', props), dark: dark);
        expect(find.text('@canvas'), findsOneWidget);
      }
    });
  });

  group('command', () {
    testWidgets('defaults render the static query form (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('command', {}),
          dark: dark,
        );
        // The live `Command` shell cannot render inline (see the builder
        // docs); canvas shows the search row plus the real result parts.
        expect(find.byType(shadcn.TextField), findsOneWidget);
        expect(find.byType(shadcn.CommandCategory), findsOneWidget);
        expect(find.byType(shadcn.CommandItem), findsNWidgets(2));
        expect(find.text('Search commands...'), findsOneWidget);
        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'hint': 'Jump to...',
        'item1': 'Mail',
        'item2': 'Profile',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('command', props), dark: dark);
        expect(find.text('Jump to...'), findsOneWidget);
        expect(find.text('Mail'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      }
    });
  });

  group('swiper', () {
    testWidgets('defaults render the swipe trigger (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('swiper', {}),
          dark: dark,
        );
        // The swipe sheet lives in the gesture overlay; canvas shows the
        // trigger child (same honest-static convention as tooltip).
        expect(find.byType(shadcn.Swiper), findsOneWidget);
        expect(find.text('Swipe up from the bottom'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'hint': 'Swipe me', 'content': 'Sheet body'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('swiper', props), dark: dark);
        expect(find.text('Swipe me'), findsOneWidget);
      }
    });
  });

  group('refresh_trigger', () {
    testWidgets('defaults render the scrollable rows (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('refresh_trigger', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.RefreshTrigger), findsOneWidget);
        expect(find.text('Row 1'), findsOneWidget);
        expect(find.text('Row 2'), findsOneWidget);
        expect(find.text('Row 3'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'item1': 'Apples', 'item2': 'Oranges', 'item3': 'Pears'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('refresh_trigger', props),
          dark: dark,
        );
        expect(find.text('Apples'), findsOneWidget);
        expect(find.text('Pears'), findsOneWidget);
      }
    });
  });

  group('tab_container', () {
    testWidgets('defaults render coordinated tabs (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tab_container', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.TabContainer), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Reviews'), findsOneWidget);
      }
    });

    testWidgets('tapping switches the selected tab (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        // Fresh key per iteration: pumpWidget preserves State for same-type
        // trees, so without this the tap below would leak into the next
        // iteration's "initial" assertion.
        await _pump(
          tester,
          KeyedSubtree(
            key: ValueKey('tab-container-$dark'),
            child: buildCatalogItem('tab_container', {}),
          ),
          dark: dark,
        );
        expect(find.text('Selected tab: 1'), findsOneWidget);
        await tester.tap(find.text('Details'));
        await tester.pump();
        expect(find.text('Selected tab: 2'), findsOneWidget);
      }
    });
  });

  group('tab_list', () {
    testWidgets('defaults render the header row (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tab_list', {}),
          dark: dark,
        );
        expect(find.byType(tabs.TabList), findsOneWidget);
        expect(find.text('Tab 1'), findsOneWidget);
        expect(find.text('Tab 2'), findsOneWidget);
      }
    });

    testWidgets('tapping switches the active tab (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        // Fresh key per iteration (same State-preservation trap as the
        // tab_container tap test above).
        await _pump(
          tester,
          KeyedSubtree(
            key: ValueKey('tab-list-$dark'),
            child: buildCatalogItem('tab_list', {}),
          ),
          dark: dark,
        );
        await tester.tap(find.text('Tab 2'));
        await tester.pump();
        final list = tester.widget<tabs.TabList>(find.byType(tabs.TabList));
        expect(list.index, 1);
      }
    });
  });

  group('tab_pane', () {
    testWidgets('defaults render strip + content (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tab_pane', {}),
          dark: dark,
        );
        // `TabPane<String>` never equals the raw `TabPane` type object, so
        // `byType` cannot match it — predicate on the generic family instead.
        expect(
          find.byWidgetPredicate((w) => w is shadcn.TabPane),
          findsOneWidget,
        );
        expect(find.text('Overview'), findsWidgets);
        expect(find.text('Content: Overview'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'tab1': 'Home', 'tab2': 'Work', 'tab3': 'Play'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('tab_pane', props), dark: dark);
        expect(find.text('Content: Home'), findsOneWidget);
      }
    });
  });

  group('stepper', () {
    testWidgets('defaults render three steps (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('stepper', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Stepper), findsOneWidget);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Payment'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'step1': 'Cart', 'step2': 'Ship', 'step3': 'Pay'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('stepper', props), dark: dark);
        expect(find.text('Cart'), findsOneWidget);
        expect(find.text('Pay'), findsOneWidget);
      }
    });
  });

  group('slider', () {
    testWidgets('defaults render the static value (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('slider', {}),
          dark: dark,
        );
        final slider = tester.widget<shadcn.Slider>(
          find.byType(shadcn.Slider),
        );
        expect(slider.value, 0.6);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('slider', {'value': 0.25}),
          dark: dark,
        );
        final slider = tester.widget<shadcn.Slider>(
          find.byType(shadcn.Slider),
        );
        expect(slider.value, 0.25);
      }
    });
  });

  group('track P wiring', () {
    test('all new kinds are catalog entries bridged by the registry', () {
      expect(_kTrackPKinds, hasLength(17));
      for (final kind in _kTrackPKinds) {
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
      for (final kind in _kTrackPKinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
        expect(find.text('unknown: $kind'), findsNothing, reason: kind);
        expect(find.text('canvas-ready coming soon'), findsNothing);
      }
    });

    testWidgets('new builders tolerate empty props (defaults kick in)', (
      tester,
    ) async {
      for (final kind in _kTrackPKinds) {
        await _pump(
          tester,
          buildCatalogItem(kind, Map<String, dynamic>.of(
            findEntry(kind)!.defaults,
          )),
        );
      }
      for (final kind in _kTrackPKinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
      }
    });
  });

  group('input_otp', () {
    testWidgets('defaults render the six-box row (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('input_otp', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.InputOTP), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('input_otp', {'length': 4}),
          dark: dark,
        );
        expect(find.byType(shadcn.InputOTP), findsOneWidget);
      }
    });
  });

  group('calendar', () {
    testWidgets('defaults render the static month grid (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('calendar', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Calendar), findsOneWidget);
        final calendar = tester.widget<shadcn.Calendar>(
          find.byType(shadcn.Calendar),
        );
        expect(
          calendar.selectionMode,
          shadcn.CalendarSelectionMode.single,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('calendar', {'mode': 'multi'}),
          dark: dark,
        );
        final calendar = tester.widget<shadcn.Calendar>(
          find.byType(shadcn.Calendar),
        );
        expect(
          calendar.selectionMode,
          shadcn.CalendarSelectionMode.multi,
        );
      }
    });

    testWidgets('unknown mode falls back to single (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('calendar', {'mode': 'bogus'}),
          dark: dark,
        );
        final calendar = tester.widget<shadcn.Calendar>(
          find.byType(shadcn.Calendar),
        );
        expect(
          calendar.selectionMode,
          shadcn.CalendarSelectionMode.single,
        );
      }
    });
  });

  group('date_picker', () {
    testWidgets('defaults render the trigger (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('date_picker', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.DatePicker), findsOneWidget);
        expect(find.text('Select date'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'placeholder': 'Birthday', 'label': 'Date of birth'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('date_picker', props),
          dark: dark,
        );
        expect(find.text('Birthday'), findsOneWidget);
        expect(find.text('Date of birth'), findsOneWidget);
      }
    });
  });

  group('time_picker', () {
    testWidgets('defaults render the trigger (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('time_picker', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.TimePicker), findsOneWidget);
        expect(find.text('Select time'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'placeholder': 'Alarm', 'label': 'Wake up'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('time_picker', props),
          dark: dark,
        );
        expect(find.text('Alarm'), findsOneWidget);
        expect(find.text('Wake up'), findsOneWidget);
      }
    });
  });

  group('carousel', () {
    testWidgets('defaults render first page + dots (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('carousel', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Carousel), findsOneWidget);
        expect(find.byType(shadcn.DotIndicator), findsOneWidget);
        expect(find.text('Slide 1'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('carousel', {'slides': 5}),
          dark: dark,
        );
        expect(find.byType(shadcn.Carousel), findsOneWidget);
        final dots = tester.widget<shadcn.DotIndicator>(
          find.byType(shadcn.DotIndicator),
        );
        expect(dots.length, 5);
      }
    });
  });

  group('tree', () {
    testWidgets('defaults render the two-level list (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('tree', {}),
          dark: dark,
        );
        // `TreeView<String>` never equals the raw `TreeView` type object, so
        // `byType` cannot match it — predicate on the generic family instead
        // (same idiom as the tab_pane test above).
        expect(
          find.byWidgetPredicate((w) => w is shadcn.TreeView),
          findsOneWidget,
        );
        expect(find.text('Design'), findsOneWidget);
        expect(find.text('Research'), findsOneWidget);
        expect(find.text('Wireframes'), findsOneWidget);
        expect(find.text('Launch'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'node1': 'Docs',
        'child1': 'Guide',
        'child2': 'API',
        'node2': 'Blog',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('tree', props), dark: dark);
        expect(find.text('Docs'), findsOneWidget);
        expect(find.text('Guide'), findsOneWidget);
        expect(find.text('API'), findsOneWidget);
        expect(find.text('Blog'), findsOneWidget);
      }
    });
  });

  group('table', () {
    testWidgets('defaults render header + two rows (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('table', {}),
          dark: dark,
        );
        // The kit `Table` is imported directly (barrel hides it behind
        // material's name) — `table.` disambiguates, like `tabs.` above.
        expect(find.byType(table.Table), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Role'), findsOneWidget);
        expect(find.text('Avery'), findsOneWidget);
        expect(find.text('Designer'), findsOneWidget);
        expect(find.text('Jordan'), findsOneWidget);
        expect(find.text('Engineer'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'header1': 'City',
        'header2': 'Country',
        'name1': 'Paris',
        'role1': 'France',
        'name2': 'Rome',
        'role2': 'Italy',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('table', props), dark: dark);
        expect(find.text('City'), findsOneWidget);
        expect(find.text('Paris'), findsOneWidget);
        expect(find.text('Italy'), findsOneWidget);
      }
    });
  });

  group('form', () {
    testWidgets('defaults render shell + field + submit (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('form', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.Form), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Jane Doe'), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'label': 'Email',
        'placeholder': 'jane@example.com',
        'submitLabel': 'Send',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('form', props), dark: dark);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('jane@example.com'), findsOneWidget);
        expect(find.text('Send'), findsOneWidget);
      }
    });
  });

  group('form_field', () {
    testWidgets('defaults render the placeholder trigger (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('form_field', {}),
          dark: dark,
        );
        expect(
          find.byWidgetPredicate((w) => w is shadcn.ObjectFormField),
          findsOneWidget,
        );
        expect(find.text('Select item'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'placeholder': 'Pick one', 'value': 'Giraffe'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('form_field', props),
          dark: dark,
        );
        expect(find.text('Giraffe'), findsOneWidget);
      }
    });
  });

  group('formatted_input', () {
    testWidgets('defaults render the date mask (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('formatted_input', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.FormattedInput), findsOneWidget);
        expect(find.text('MM'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('formatted_input', {'label': 'Birthday'}),
          dark: dark,
        );
        expect(find.byType(shadcn.FormattedInput), findsOneWidget);
        expect(find.text('Birthday'), findsOneWidget);
      }
    });
  });

  group('validated', () {
    testWidgets('defaults render field + attach-time error (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('validated', {}),
          dark: dark,
        );
        expect(
          find.byWidgetPredicate((w) => w is shadcn.Validated),
          findsOneWidget,
        );
        expect(find.byType(shadcn.TextField), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        // The kit validates on attach, so canvas shows that initial error
        // state (later validation executes at runtime only).
        expect(find.text('Required'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'placeholder': 'Email', 'errorText': 'Enter an email'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('validated', props),
          dark: dark,
        );
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Enter an email'), findsOneWidget);
      }
    });
  });

  group('color_picker', () {
    testWidgets('defaults render sliders + hex label (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('color_picker', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.ColorPicker), findsOneWidget);
        expect(find.text('#2196F3'), findsOneWidget);
      }
    });

    testWidgets('representative + malformed hex never crash (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('color_picker', {'hex': '#FF5733'}),
          dark: dark,
        );
        expect(find.byType(shadcn.ColorPicker), findsOneWidget);
        expect(find.text('#FF5733'), findsOneWidget);
        await _pump(
          tester,
          buildCatalogItem('color_picker', {'hex': 'not-a-color'}),
          dark: dark,
        );
        expect(find.byType(shadcn.ColorPicker), findsOneWidget);
      }
    });
  });

  group('color_input', () {
    testWidgets('defaults render the swatch trigger (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('color_input', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.ColorInput), findsOneWidget);
        // The kit trigger renders the hex in lowercase (`colorToHex`).
        expect(
          find.textContaining(RegExp('2196f3', caseSensitive: false)),
          findsOneWidget,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('color_input', {'hex': '#4CAF50'}),
          dark: dark,
        );
        expect(find.byType(shadcn.ColorInput), findsOneWidget);
        expect(
          find.textContaining(RegExp('4caf50', caseSensitive: false)),
          findsOneWidget,
        );
      }
    });
  });

  group('hsl', () {
    testWidgets('defaults render hue slider + swatch (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hsl', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.HSLColorSlider), findsOneWidget);
        expect(find.text('#2196F3'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hsl', {'mode': 'sat'}),
          dark: dark,
        );
        final slider = tester.widget<shadcn.HSLColorSlider>(
          find.byType(shadcn.HSLColorSlider),
        );
        expect(slider.sliderType, shadcn.HSLColorSliderType.sat);
      }
    });
  });

  group('hsv', () {
    testWidgets('defaults render hue slider + swatch (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hsv', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.HSVColorSlider), findsOneWidget);
        expect(find.text('#2196F3'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('hsv', {'mode': 'val'}),
          dark: dark,
        );
        final slider = tester.widget<shadcn.HSVColorSlider>(
          find.byType(shadcn.HSVColorSlider),
        );
        expect(slider.sliderType, shadcn.HSVColorSliderType.val);
      }
    });
  });

  group('history', () {
    testWidgets('defaults render the color grid (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('history', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.ColorHistoryGrid), findsOneWidget);
        final grid = tester.widget<shadcn.ColorHistoryGrid>(
          find.byType(shadcn.ColorHistoryGrid),
        );
        expect(grid.crossAxisCount, 6);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('history', {'columns': 4}),
          dark: dark,
        );
        final grid = tester.widget<shadcn.ColorHistoryGrid>(
          find.byType(shadcn.ColorHistoryGrid),
        );
        expect(grid.crossAxisCount, 4);
      }
    });
  });

  group('feature_carousel', () {
    testWidgets('defaults render the first page (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('feature_carousel', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.FeatureCardCarousel), findsOneWidget);
        expect(find.text('Palette Selector'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'title1': 'Dark Mode',
        'description1': 'Easy on the eyes.',
        'title2': 'Widgets',
        'description2': 'Compose anything.',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('feature_carousel', props),
          dark: dark,
        );
        // The centered first card shows its title + description; the second
        // item renders as a ghost card, so only its data is asserted via the
        // first card's content.
        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('Easy on the eyes.'), findsOneWidget);
      }
    });
  });

  group('track P unbounded canvas columns', () {
    testWidgets('heavy kinds pump inside an unbounded canvas column', (
      tester,
    ) async {
      // Mirrors phone_frame.dart root columns (mainAxisSize.min, unbounded
      // height): the fixed-height shells (carousel), shrink-wrapped lists
      // (tree), and self-sized widgets (table, form, color kinds, feature
      // carousel) must all stay bounded. The scroll view mirrors the
      // scrollable canvas surface.
      for (final dark in [false, true]) {
        await _pump(
          tester,
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildCatalogItem('input_otp', {}),
                buildCatalogItem('calendar', {}),
                buildCatalogItem('carousel', {}),
                buildCatalogItem('tree', {}),
                buildCatalogItem('table', {}),
                buildCatalogItem('form', {}),
                buildCatalogItem('color_picker', {}),
                buildCatalogItem('history', {}),
                buildCatalogItem('feature_carousel', {}),
              ],
            ),
          ),
          dark: dark,
        );
        expect(find.byType(shadcn.InputOTP), findsOneWidget);
        expect(find.byType(shadcn.Calendar), findsOneWidget);
        expect(find.byType(shadcn.Carousel), findsOneWidget);
        expect(find.byType(table.Table), findsOneWidget);
        expect(find.byType(shadcn.Form), findsOneWidget);
        expect(find.byType(shadcn.ColorPicker), findsOneWidget);
        expect(find.byType(shadcn.ColorHistoryGrid), findsOneWidget);
        expect(
          find.byType(shadcn.FeatureCardCarousel),
          findsOneWidget,
        );
      }
    });
  });

  group('spec wiring', () {
    testWidgets('input honors initialValue + readOnly', (tester) async {
      await _pump(
        tester,
        buildCatalogItem('input', {
          'initialValue': 'Ada',
          'readOnly': true,
        }),
      );
      final field = tester.widget<shadcn.TextField>(
        find.byType(shadcn.TextField),
      );
      expect(field.initialValue, 'Ada');
      expect(field.readOnly, isTrue);
    });

    testWidgets('avatar honors size', (tester) async {
      await _pump(tester, buildCatalogItem('avatar', {'size': 64.0}));
      final avatar = tester.widget<shadcn.Avatar>(
        find.byType(shadcn.Avatar),
      );
      expect(avatar.size, 64.0);
    });

    testWidgets('checkbox honors tristate', (tester) async {
      await _pump(tester, buildCatalogItem('checkbox', {'tristate': true}));
      final box = tester.widget<shadcn.Checkbox>(
        find.byType(shadcn.Checkbox),
      );
      expect(box.tristate, isTrue);
    });

    testWidgets('divider honors thickness', (tester) async {
      await _pump(tester, buildCatalogItem('divider', {'thickness': 4.0}));
      final divider = tester.widget<shadcn.Divider>(
        find.byType(shadcn.Divider),
      );
      expect(divider.thickness, 4.0);
    });

    testWidgets('tabs honors expand', (tester) async {
      await _pump(tester, buildCatalogItem('tabs', {'expand': true}));
      final tabsWidget = tester.widget<tabs.Tabs>(find.byType(tabs.Tabs));
      expect(tabsWidget.expand, isTrue);
    });

    testWidgets('select honors disabled', (tester) async {
      await _pump(tester, buildCatalogItem('select', {'disabled': true}));
      final select = tester.widget<shadcn.Select<String>>(
        find.byType(shadcn.Select<String>),
      );
      expect(select.enabled, isFalse);
    });

    testWidgets('radio_group honors disabled', (tester) async {
      await _pump(tester, buildCatalogItem('radio_group', {'disabled': true}));
      final group = tester.widget<shadcn.RadioGroup<String>>(
        find.byType(shadcn.RadioGroup<String>),
      );
      expect(group.enabled, isFalse);
    });

    testWidgets('breadcrumb slash separator renders', (tester) async {
      await _pump(
        tester,
        buildCatalogItem('breadcrumb', {'separator': 'slash'}),
      );
      expect(find.byType(shadcn.Breadcrumb), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
    });

    testWidgets('toast honors autoDismiss', (tester) async {
      await _pump(tester, buildCatalogItem('toast', {'autoDismiss': true}));
      final toast = tester.widget<shadcn.ToastEntry>(
        find.byType(shadcn.ToastEntry),
      );
      expect(toast.autoDismiss, isTrue);
    });

    testWidgets('drawer honors position', (tester) async {
      await _pump(tester, buildCatalogItem('drawer', {'position': 'left'}));
      final drawer = tester.widget<shadcn.DrawerWrapper>(
        find.byType(shadcn.DrawerWrapper),
      );
      expect(drawer.position, shadcn.OverlayPosition.left);
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
