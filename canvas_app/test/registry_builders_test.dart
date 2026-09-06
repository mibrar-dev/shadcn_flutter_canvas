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

/// The 28 Track FF2 kinds: the form/input family the user hit
/// (`unknown: phone_input` triage screenshot) plus the bare-capable
/// display/layout/utility batch.
const _kTrackFF2Kinds = [
  'phone_input',
  'chip_input',
  'autocomplete',
  'item_picker',
  'multiple_choice',
  'object_input',
  'text_field',
  'markdown',
  'text_animate',
  'icon',
  'navigation_menu',
  'dropzone',
  'border_loading',
  'overflow_marquee',
  'focus_outline',
  'switcher',
  'scrollable',
  'stage_container',
  'media_query',
  'scrollview',
  'hover',
  'patch',
  'text',
  'filter_bar',
  'fade_scroll',
  'resizable',
  'subfocus',
  'repeated_animation_builder',
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

/// The 4 Track D1 promoted kinds: leaves with a kit-verified generic
/// single-child slot (`ChatBubble.child`, `ToastEntry.child`,
/// `Validated.child`, `RefreshTrigger.child`).
const _kTrackD1Kinds = ['chat', 'toast', 'validated', 'refresh_trigger'];

/// The 10 Track U1 kinds: hand-verified EASY registry builders with real
/// bare widgets but no `CatalogEntry`. Before U1, `buildCatalogItem`
/// consulted `kCatalog` only, so these rendered `unknown: <kind>` + X-box
/// on canvas and in preview even though the palette lists them and drops
/// accept them. U1 routes catalog misses through the registry fallback
/// (`_buildRegistryFallback` in `component_catalog.dart`); this list pins
/// the unified render path. No old-fallback test asserted `unknown:` for
/// these kinds, so there is nothing to invert in place — the triage group
/// below documents the behavior change instead.
const _kTrackU1Kinds = [
  'alert',
  'chip',
  'circular_progress_indicator',
  'code_snippet',
  'dot_indicator',
  'empty_state',
  'linear_progress_indicator',
  'number_ticker',
  'text_area',
  'triple_dots',
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

  group('track D1 promotion', () {
    test('promoted kinds are migrated builders in the container set', () {
      expect(_kTrackD1Kinds, hasLength(4));
      for (final kind in _kTrackD1Kinds) {
        final entry = findEntry(kind);
        expect(entry, isNotNull, reason: 'no catalog entry $kind');
        // Migrated 2-arg shape: buildCatalogItem recovers these via
        // `is NodeBuilder`, so container children splice inside the chrome.
        expect(entry!.build is NodeBuilder, isTrue, reason: kind);
        expect(kContainerKinds.contains(kind), isTrue, reason: kind);
      }
      // Track F: 14 + the nine primitive containers (`spacer` is a leaf).
      expect(kContainerKinds, hasLength(23));
    });

    /// The promoted chrome per kind (`Validated<String>` never equals the raw
    /// `Validated` type object, so `byType` cannot match it — predicate on
    /// the generic family instead, same idiom as the tab_pane test above).
    Finder chromeOf(String kind) {
      if (kind == 'validated') {
        return find.byWidgetPredicate((w) => w is shadcn.Validated);
      }
      if (kind == 'chat') return find.byType(shadcn.ChatBubble);
      if (kind == 'toast') return find.byType(shadcn.ToastEntry);
      return find.byType(shadcn.RefreshTrigger);
    }

    /// Historical chrome prose that must survive every splice.
    const labels = {
      'chat': 'Hello!',
      'toast': 'Saved',
      'validated': 'Name',
      'refresh_trigger': 'Row 1',
    };

    /// `skipOffstage: false` on BOTH finders: the refresh_trigger splice lands
    /// in the 140px scroll shell, so rows past the viewport are built but
    /// offstage — and the inner `matching` finder applies its own offstage
    /// filter, so the outer descendant flag alone is not enough. Ancestry is
    /// still strict (descendant of the chrome), which is what placement
    /// proves.
    Finder kidIn(String kind, String kid) => find.descendant(
      of: chromeOf(kind),
      matching: find.text(kid, skipOffstage: false),
      skipOffstage: false,
    );

    for (final kind in _kTrackD1Kinds) {
      group(kind, () {
        testWidgets('0 children renders the historical tree (light + dark)', (
          tester,
        ) async {
          for (final dark in [false, true]) {
            await _pump(
              tester,
              buildCatalogItem(kind, {}),
              dark: dark,
            );
            expect(chromeOf(kind), findsOneWidget);
            expect(find.text(labels[kind]!), findsOneWidget);
            expect(find.text('D1 kid 1'), findsNothing);
            expect(find.text('D1 kid 2'), findsNothing);
          }
        });

        testWidgets('1 child splices inside chrome (light + dark)', (
          tester,
        ) async {
          for (final dark in [false, true]) {
            await _pump(
              tester,
              buildCatalogItem(kind, {}, [const Text('D1 kid 1')]),
              dark: dark,
            );
            expect(chromeOf(kind), findsOneWidget);
            expect(kidIn(kind, 'D1 kid 1'), findsOneWidget);
            expect(find.text(labels[kind]!), findsOneWidget);
          }
        });

        testWidgets('2 children stack inside chrome (light + dark)', (
          tester,
        ) async {
          for (final dark in [false, true]) {
            await _pump(
              tester,
              buildCatalogItem(kind, {}, const [
                Text('D1 kid 1'),
                Text('D1 kid 2'),
              ]),
              dark: dark,
            );
            expect(chromeOf(kind), findsOneWidget);
            expect(kidIn(kind, 'D1 kid 1'), findsOneWidget);
            expect(kidIn(kind, 'D1 kid 2'), findsOneWidget);
            expect(find.text(labels[kind]!), findsOneWidget);
          }
        });
      });
    }
  });

  group('track U1 wiring', () {
    test('registry-only kinds are bridged without catalog entries', () {
      expect(_kTrackU1Kinds, hasLength(10));
      for (final kind in _kTrackU1Kinds) {
        // No catalog entry BY DESIGN: the U1 fallback bridges the registry,
        // so these kinds need no CatalogEntry and kCatalog stays at 68
        // (renderability no longer equals catalog membership).
        expect(findEntry(kind), isNull, reason: 'U1 keeps $kind out of kCatalog');
        final reg = findRegistryEntry(kind);
        expect(reg, isNotNull, reason: 'no registry entry $kind');
        expect(reg!.canvasReady, isTrue, reason: kind);
      }
    });

    testWidgets('triage: EASY kinds never render the unknown-kind fallback', (
      tester,
    ) async {
      // Pre-U1, every kind below rendered `unknown: <kind>` + X-box because
      // buildCatalogItem consulted kCatalog only. This test deliberately
      // asserts the inverted expectation: the registry fallback now renders
      // their real builders (see _buildRegistryFallback).
      for (final kind in _kTrackU1Kinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
        expect(find.text('unknown: $kind'), findsNothing, reason: kind);
        expect(find.text('canvas-ready coming soon'), findsNothing);
      }
    });

    testWidgets('registry builders tolerate empty props (defaults kick in)', (
      tester,
    ) async {
      for (final kind in _kTrackU1Kinds) {
        await _pump(tester, buildCatalogItem(kind, {}));
      }
    });
  });

  group('alert', () {
    testWidgets('defaults render title + content (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('alert', {}), dark: dark);
        expect(find.byType(shadcn.Alert), findsOneWidget);
        expect(find.text('Alert'), findsOneWidget);
        expect(find.text('Something happened.'), findsOneWidget);
      }
    });

    testWidgets('representative props incl. destructive (light + dark)', (
      tester,
    ) async {
      const props = {
        'title': 'Boom',
        'content': 'Outage',
        'destructive': true,
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('alert', props), dark: dark);
        expect(find.byType(shadcn.Alert), findsOneWidget);
        expect(find.text('Boom'), findsOneWidget);
        expect(find.text('Outage'), findsOneWidget);
        expect(
          tester.widget<shadcn.Alert>(find.byType(shadcn.Alert)).destructive,
          isTrue,
        );
      }
    });
  });

  group('chip', () {
    testWidgets('defaults render the label (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('chip', {}), dark: dark);
        expect(find.byType(shadcn.Chip), findsOneWidget);
        expect(find.text('Chip'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('chip', {'label': 'Beta'}),
          dark: dark,
        );
        expect(find.byType(shadcn.Chip), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);
      }
    });
  });

  group('circular_progress_indicator', () {
    testWidgets('defaults render the determinate spinner (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('circular_progress_indicator', {}),
          dark: dark,
        );
        expect(
          find.byType(shadcn.CircularProgressIndicator),
          findsOneWidget,
        );
        expect(
          tester
              .widget<shadcn.CircularProgressIndicator>(
                find.byType(shadcn.CircularProgressIndicator),
              )
              .value,
          0.6,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('circular_progress_indicator', {'value': 0.2}),
          dark: dark,
        );
        expect(
          tester
              .widget<shadcn.CircularProgressIndicator>(
                find.byType(shadcn.CircularProgressIndicator),
              )
              .value,
          0.2,
        );
      }
    });
  });

  group('code_snippet', () {
    testWidgets('defaults render the code text (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('code_snippet', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.CodeSnippet), findsOneWidget);
        expect(find.text('const x = 1;'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('code_snippet', {'code': 'void main() {}'}),
          dark: dark,
        );
        expect(find.byType(shadcn.CodeSnippet), findsOneWidget);
        expect(find.text('void main() {}'), findsOneWidget);
      }
    });
  });

  group('dot_indicator', () {
    testWidgets('defaults render three dots (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('dot_indicator', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.DotIndicator), findsOneWidget);
        final dots = tester.widget<shadcn.DotIndicator>(
          find.byType(shadcn.DotIndicator),
        );
        expect(dots.index, 0);
        expect(dots.length, 3);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'index': 2, 'length': 5};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('dot_indicator', props),
          dark: dark,
        );
        final dots = tester.widget<shadcn.DotIndicator>(
          find.byType(shadcn.DotIndicator),
        );
        expect(dots.index, 2);
        expect(dots.length, 5);
      }
    });
  });

  group('empty_state', () {
    testWidgets('defaults render title + description (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('empty_state', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.EmptyState), findsOneWidget);
        expect(find.text('No results'), findsOneWidget);
        expect(find.text('Try adjusting your search.'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'title': 'Empty', 'description': 'Nothing here'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('empty_state', props),
          dark: dark,
        );
        expect(find.byType(shadcn.EmptyState), findsOneWidget);
        expect(find.text('Empty'), findsOneWidget);
        expect(find.text('Nothing here'), findsOneWidget);
      }
    });
  });

  group('linear_progress_indicator', () {
    testWidgets('defaults render the determinate bar (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('linear_progress_indicator', {}),
          dark: dark,
        );
        expect(
          find.byType(shadcn.LinearProgressIndicator),
          findsOneWidget,
        );
        expect(
          tester
              .widget<shadcn.LinearProgressIndicator>(
                find.byType(shadcn.LinearProgressIndicator),
              )
              .value,
          0.6,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('linear_progress_indicator', {'value': 0.2}),
          dark: dark,
        );
        expect(
          tester
              .widget<shadcn.LinearProgressIndicator>(
                find.byType(shadcn.LinearProgressIndicator),
              )
              .value,
          0.2,
        );
      }
    });
  });

  group('number_ticker', () {
    testWidgets('defaults render the pinned value (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('number_ticker', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.NumberTicker), findsOneWidget);
        expect(
          tester
              .widget<shadcn.NumberTicker>(find.byType(shadcn.NumberTicker))
              .number,
          42,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('number_ticker', {'value': 7}),
          dark: dark,
        );
        expect(find.byType(shadcn.NumberTicker), findsOneWidget);
        expect(
          tester
              .widget<shadcn.NumberTicker>(find.byType(shadcn.NumberTicker))
              .number,
          7,
        );
      }
    });
  });

  group('text_area', () {
    testWidgets('defaults render the placeholder (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text_area', {}), dark: dark);
        expect(find.byType(shadcn.TextArea), findsOneWidget);
        expect(find.text('Type here'), findsOneWidget);
      }
    });

    testWidgets('representative props incl. label + disabled (light + dark)', (
      tester,
    ) async {
      const props = {
        'placeholder': 'Bio',
        'label': 'About',
        'disabled': true,
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text_area', props), dark: dark);
        expect(find.byType(shadcn.TextArea), findsOneWidget);
        expect(find.text('Bio'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
        expect(
          tester.widget<shadcn.TextArea>(find.byType(shadcn.TextArea)).enabled,
          isFalse,
        );
      }
    });
  });

  group('triple_dots', () {
    testWidgets('defaults render three dots (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('triple_dots', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.MoreDots), findsOneWidget);
        expect(
          tester.widget<shadcn.MoreDots>(find.byType(shadcn.MoreDots)).count,
          3,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('triple_dots', {'count': 7}),
          dark: dark,
        );
        expect(find.byType(shadcn.MoreDots), findsOneWidget);
        expect(
          tester.widget<shadcn.MoreDots>(find.byType(shadcn.MoreDots)).count,
          7,
        );
      }
    });
  });

  group('track U1 fallback tail', () {
    testWidgets('true-unknown kinds keep the unknown fallback', (
      tester,
    ) async {
      await _pump(tester, buildCatalogItem('definitely_not_a_kind', {}));
      expect(find.byType(Placeholder), findsOneWidget);
      expect(find.text('unknown: definitely_not_a_kind'), findsOneWidget);
    });

    testWidgets('placeholder registry kinds keep the unknown fallback', (
      tester,
    ) async {
      // Spot-check across sections: these have registry entries but
      // canvasReady false, so the U1 fallback must NOT promote them to
      // 'canvas-ready coming soon' cards — canvas keeps unknown + X exactly
      // as before U1. (`navigation_bar` left this list in Track Y1
      // (2026-09-06), `markdown`/`text`/`autocomplete`/`switcher` in Track
      // FF2 (2026-09-06): they now bridge to real catalog builders.)
      const placeholders = [
        'spinner',
      ];
      for (final kind in placeholders) {
        expect(findEntry(kind), isNull, reason: kind);
        final reg = findRegistryEntry(kind);
        expect(reg, isNotNull, reason: kind);
        expect(reg!.canvasReady, isFalse, reason: kind);
        await _pump(tester, buildCatalogItem(kind, {}));
        expect(find.text('unknown: $kind'), findsOneWidget, reason: kind);
        expect(find.byType(Placeholder), findsOneWidget, reason: kind);
        expect(
          find.text('canvas-ready coming soon'),
          findsNothing,
          reason: kind,
        );
      }
    });

    testWidgets('row pseudo-kind renders its structural preview', (
      tester,
    ) async {
      // Track F promotion: `row` is a first-class catalog entry now (real
      // `Row` builder + empty-state ghost), so it renders the catalog Row
      // instead of the old registry structural preview. Rows laid out via
      // `isRow` never route item props here; `items: [row]` nodes do.
      await _pump(tester, buildCatalogItem('row', {}));
      expect(find.text('unknown: row'), findsNothing);
      expect(find.byType(Row), findsOneWidget);
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('registry fallback honors the props/children contract', (
      tester,
    ) async {
      // Children are ignored (no U1 kind is a container) without crashing —
      // the renderers' below-fallback keeps owning them, as today.
      await _pump(
        tester,
        buildCatalogItem('chip', {}, [const Text('U1 kid')]),
      );
      expect(find.byType(shadcn.Chip), findsOneWidget);
      expect(find.text('unknown: chip'), findsNothing);
      // Schema-less kinds keep bound props raw (never a crash).
      await _pump(
        tester,
        buildCatalogItem('chip', {
          'label': '=nick',
        }, const [], {'nick': 'Ada'}),
      );
      expect(find.byType(shadcn.Chip), findsOneWidget);
      expect(find.text('=nick'), findsOneWidget);
    });
  });

  group('track BB slots', () {
    /// The 13 splice-container kinds: the BB `content` slot complements (never
    /// replaces) the C1 children splice — slot first, then spliced children.
    const contentKinds = [
      'card',
      'dialog',
      'alert_dialog',
      'drawer',
      'form',
      'outlined_container',
      'hidden',
      'clickable',
      'scrollbar',
      'chat',
      'toast',
      'validated',
      'refresh_trigger',
    ];

    test('kNodeSlots pins the slot registry (16 kinds, 19 slots)', () {
      expect(kNodeSlots, hasLength(16));
      expect(kNodeSlots['scaffold'], ['appBar', 'body', 'footer']);
      expect(kNodeSlots['card_image'], ['image']);
      expect(kNodeSlots['basic'], ['leading', 'trailing']);
      for (final kind in contentKinds) {
        expect(kNodeSlots[kind], ['content'], reason: kind);
      }
      // Every registered kind resolves to a real catalog builder (slots never
      // dangle), and every registered builder honors its slots (pinned below).
      for (final kind in kNodeSlots.keys) {
        expect(findEntry(kind), isNotNull, reason: 'no catalog entry $kind');
      }
    });

    testWidgets('content slots render when provided, vanish when not', (
      tester,
    ) async {
      for (final kind in contentKinds) {
        // The refresh_trigger splice lands in the 140px scroll shell, so
        // trailing rows are built but offstage (same idiom as the D1 kidIn).
        Finder slot() => kind == 'refresh_trigger'
            ? find.text('BB slot', skipOffstage: false)
            : find.text('BB slot');
        await _pump(
          tester,
          buildCatalogItem(kind, {
            'content': const Text('BB slot'),
          }),
        );
        expect(slot(), findsOneWidget, reason: '$kind renders');
        await _pump(tester, buildCatalogItem(kind, {}));
        expect(find.text('BB slot'), findsNothing, reason: '$kind absent');
        // Explicit null equals absent (the renderers' empty-slot copy).
        await _pump(
          tester,
          buildCatalogItem(kind, {
            'content': null,
          }),
        );
        expect(find.text('BB slot'), findsNothing, reason: '$kind null');
      }
    });

    testWidgets('content slots complement spliced children (slot first)', (
      tester,
    ) async {
      for (final kind in contentKinds) {
        await _pump(
          tester,
          buildCatalogItem(kind, {
            'content': const Text('BB slot'),
          }, const [Text('BB kid')]),
        );
        // The refresh_trigger splice lands in the 140px scroll shell, so
        // rows past the viewport are built but offstage (same idiom as the
        // D1 kidIn + the render/absent pin above).
        final slot = kind == 'refresh_trigger'
            ? find.text('BB slot', skipOffstage: false)
            : find.text('BB slot');
        expect(slot, findsOneWidget, reason: '$kind slot');
        // The refresh_trigger splice lands in the 140px scroll shell, so the
        // trailing kid is built but offstage (same idiom as the D1 kidIn).
        final kid = kind == 'refresh_trigger'
            ? find.text('BB kid', skipOffstage: false)
            : find.text('BB kid');
        expect(kid, findsOneWidget, reason: '$kind kid');
      }
    });

    testWidgets('non-Widget slot values collapse to the default', (
      tester,
    ) async {
      // Stray hand-written values must never crash: [_slotOf] only honors
      // Widgets (see kNodeSlots docs).
      await _pump(
        tester,
        buildCatalogItem('card', {
          'content': 'not-a-widget',
        }),
      );
      expect(find.text('Title'), findsOneWidget);
      await _pump(tester, buildCatalogItem('scaffold', {'body': 42}));
      expect(find.text('Welcome'), findsOneWidget);
    });

    group('scaffold slots', () {
      testWidgets('appBar/body/footer render when provided (light + dark)', (
        tester,
      ) async {
        const props = {
          'appBar': Text('BB bar'),
          'body': Text('BB body'),
          'footer': Text('BB foot'),
        };
        for (final dark in [false, true]) {
          await _pump(
            tester,
            buildCatalogItem('scaffold', props),
            dark: dark,
          );
          expect(find.byType(shadcn.Scaffold), findsOneWidget);
          expect(find.text('BB bar'), findsOneWidget);
          expect(find.text('BB body'), findsOneWidget);
          expect(find.text('BB foot'), findsOneWidget);
          // The default chrome is replaced/shadowed, not duplicated.
          expect(find.text('My App'), findsNothing);
          expect(find.text('Welcome'), findsNothing);
          // The appBar renders above the body.
          final barY = tester.getTopLeft(find.text('BB bar')).dy;
          final bodyY = tester.getTopLeft(find.text('BB body')).dy;
          expect(barY, lessThan(bodyY), reason: 'dark=$dark');
        }
      });

      testWidgets('absent slots keep the default shell (light + dark)', (
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
          // No footer chrome without a footer slot.
          expect(find.text('BB foot'), findsNothing);
        }
      });

      testWidgets('body slot complements spliced children (light + dark)', (
        tester,
      ) async {
        for (final dark in [false, true]) {
          await _pump(
            tester,
            buildCatalogItem('scaffold', {
              'body': const Text('BB body'),
            }, const [Text('BB kid')]),
            dark: dark,
          );
          expect(find.text('BB body'), findsOneWidget);
          expect(find.text('BB kid'), findsOneWidget);
          expect(find.text('Welcome'), findsNothing);
        }
      });
    });

    group('card_image slots + art cap', () {
      testWidgets('image slot replaces the default art (light + dark)', (
        tester,
      ) async {
        final art = find.byWidgetPredicate(
          (w) => w is AspectRatio && w.aspectRatio == 16 / 9,
        );
        for (final dark in [false, true]) {
          await _pump(
            tester,
            buildCatalogItem('card_image', {
              'image': const Text('BB art'),
            }),
            dark: dark,
          );
          expect(find.byType(shadcn.CardImage), findsOneWidget);
          expect(find.text('BB art'), findsOneWidget);
          expect(art, findsNothing, reason: 'default art replaced');
          expect(find.text('Card title'), findsOneWidget);
          await _pump(
            tester,
            buildCatalogItem('card_image', {}),
            dark: dark,
          );
          expect(art, findsOneWidget, reason: 'default art kept');
          expect(find.text('BB art'), findsNothing);
        }
      });

      testWidgets('art keeps 16:9 below the cap at narrow widths', (
        tester,
      ) async {
        await _pump(
          tester,
          SizedBox(
            width: 300,
            child: buildCatalogItem('card_image', {
              'title': 'Sunset',
              'subtitle': 'Golden hour',
            }),
          ),
        );
        final art = find.byWidgetPredicate(
          (w) => w is AspectRatio && w.aspectRatio == 16 / 9,
        );
        expect(art, findsOneWidget);
        // Ratio is always exact; the size is width-driven up to ~1.5px of
        // proportional shrink when the title block exceeds the 76px text
        // budget (see _kCardImageTextBudget — shrink, never overflow).
        final size = tester.getSize(art);
        expect(size.width / size.height, moreOrLessEquals(16 / 9));
        expect(size.height, lessThanOrEqualTo(300 * 9 / 16 + 0.5));
        expect(size.height, greaterThan(160));
        final cardWidth = tester.getSize(find.byType(shadcn.CardImage)).width;
        expect(cardWidth - size.width, lessThanOrEqualTo(4.0));
      });

      testWidgets('art caps at 200px and centers on wide cards', (
        tester,
      ) async {
        await _pump(
          tester,
          SizedBox(
            width: 600,
            child: buildCatalogItem('card_image', {
              'title': 'Sunset',
              'subtitle': 'Golden hour',
            }),
          ),
        );
        final art = find.byWidgetPredicate(
          (w) => w is AspectRatio && w.aspectRatio == 16 / 9,
        );
        expect(art, findsOneWidget);
        final size = tester.getSize(art);
        expect(size.height, moreOrLessEquals(200, epsilon: 1.5));
        expect(size.width / size.height, moreOrLessEquals(16 / 9));
        // The cap is engaged (not filling) and the card itself still spans
        // the full node width with the art centered inside it.
        final card = find.byType(shadcn.CardImage);
        final cardWidth = tester.getSize(card).width;
        expect(cardWidth, moreOrLessEquals(600, epsilon: 2.0));
        expect(cardWidth - size.width, greaterThan(10.0));
        final cardLeft = tester.getTopLeft(card).dx;
        final artLeft = tester.getTopLeft(art).dx;
        expect(
          artLeft - cardLeft,
          moreOrLessEquals((cardWidth - size.width) / 2, epsilon: 2.0),
        );
      });
    });

    group('basic slots', () {
      testWidgets('leading/trailing replace the default chrome', (
        tester,
      ) async {
        for (final dark in [false, true]) {
          await _pump(
            tester,
            buildCatalogItem('basic', {
              'leading': const Text('BB lead'),
              'trailing': const Text('BB trail'),
            }),
            dark: dark,
          );
          expect(find.byType(shadcn.Basic), findsOneWidget);
          expect(find.text('BB lead'), findsOneWidget);
          expect(find.text('BB trail'), findsOneWidget);
          expect(find.byIcon(Icons.person), findsNothing);
          expect(find.byIcon(Icons.chevron_right), findsNothing);
        }
      });

      testWidgets('absent slots keep the bool chrome (light + dark)', (
        tester,
      ) async {
        for (final dark in [false, true]) {
          await _pump(
            tester,
            buildCatalogItem('basic', {}),
            dark: dark,
          );
          expect(find.byIcon(Icons.person), findsOneWidget);
          expect(find.byIcon(Icons.chevron_right), findsOneWidget);
          expect(find.text('BB lead'), findsNothing);
          expect(find.text('BB trail'), findsNothing);
        }
      });
    });
  });

/// FF2 loop pump: [_pump] plus a markdown settle. Markdown parses in an
/// isolate behind a progressive-chunk `Timer.periodic`, so a plain pump
/// leaves a pending timer that trips the test binding's teardown invariant —
/// settling drains it (every other FF2 builder is timer-clean on plain
/// pumps, pinned by the per-kind tests below).
Future<void> _pumpFF2(
  WidgetTester tester,
  String kind,
  Map<String, dynamic> props,
) async {
  await _pump(tester, buildCatalogItem(kind, props));
  if (kind == 'markdown') await tester.pumpAndSettle();
}

  group('track FF2 wiring', () {
    test('all new kinds are catalog entries bridged by the registry', () {
      expect(_kTrackFF2Kinds, hasLength(28));
      for (final kind in _kTrackFF2Kinds) {
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
      for (final kind in _kTrackFF2Kinds) {
        await _pumpFF2(tester, kind, const {});
        expect(find.text('unknown: $kind'), findsNothing, reason: kind);
        expect(find.text('canvas-ready coming soon'), findsNothing);
      }
    });

    testWidgets('new builders tolerate empty props (defaults kick in)', (
      tester,
    ) async {
      for (final kind in _kTrackFF2Kinds) {
        await _pumpFF2(
          tester,
          kind,
          Map<String, dynamic>.of(findEntry(kind)!.defaults),
        );
      }
      for (final kind in _kTrackFF2Kinds) {
        await _pumpFF2(tester, kind, const {});
      }
    });
  });

  group('phone_input', () {
    testWidgets('defaults render the real PhoneInput (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('phone_input', {}), dark: dark);
        expect(find.byType(shadcn.PhoneInput), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Work phone', 'searchHint': 'Find country'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('phone_input', props), dark: dark);
        expect(find.byType(shadcn.PhoneInput), findsOneWidget);
        expect(find.text('Work phone'), findsOneWidget);
      }
    });
  });

  group('chip_input', () {
    testWidgets('defaults seed the first chip (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('chip_input', {}), dark: dark);
        // Chips embed as span children one frame after attach.
        await tester.pump();
        expect(
          find.byType(shadcn.ChipInput<String>),
          findsOneWidget,
        );
        expect(find.text('Design'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'placeholder': 'Add attendee',
        'chip1': 'Ada',
        'chip2': 'Grace',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('chip_input', props), dark: dark);
        await tester.pump();
        expect(find.text('Ada'), findsOneWidget);
        expect(find.text('Grace'), findsOneWidget);
      }
    });
  });

  group('autocomplete', () {
    testWidgets('defaults render the field (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('autocomplete', {}), dark: dark);
        expect(find.byType(shadcn.AutoComplete), findsOneWidget);
        expect(find.byType(shadcn.TextField), findsOneWidget);
        expect(find.text('Search...'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'placeholder': 'Pick a fruit',
        'suggestion1': 'Mango',
        'suggestion2': 'Melon',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('autocomplete', props),
          dark: dark,
        );
        expect(find.byType(shadcn.AutoComplete), findsOneWidget);
        expect(find.text('Pick a fruit'), findsOneWidget);
      }
    });
  });

  group('item_picker', () {
    testWidgets('defaults render the trigger (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('item_picker', {}), dark: dark);
        expect(
          find.byType(shadcn.ItemPicker<String>),
          findsOneWidget,
        );
        expect(find.text('Select item'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'placeholder': 'Pick a color',
        'option1': 'Red',
        'option2': 'Blue',
        'value': 'Blue',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('item_picker', props), dark: dark);
        expect(find.text('Blue'), findsOneWidget);
      }
    });
  });

  group('multiple_choice', () {
    testWidgets('defaults render single-select chips (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('multiple_choice', {}),
          dark: dark,
        );
        expect(
          find.byType(shadcn.MultipleChoice<String>),
          findsOneWidget,
        );
        expect(find.text('Option A'), findsOneWidget);
        expect(find.text('Option B'), findsOneWidget);
        expect(find.text('Option C'), findsOneWidget);
      }
    });

    testWidgets('taps switch the single selection (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('multiple_choice', {}),
          dark: dark,
        );
        await tester.tap(find.text('Option B'));
        await tester.pump();
        expect(find.byType(shadcn.MultipleChoice<String>), findsOneWidget);
      }
    });

    testWidgets('multiple mode renders the answer set (light + dark)', (
      tester,
    ) async {
      const props = {
        'mode': 'multiple',
        'option1': 'Apple',
        'option2': 'Banana',
        'option3': 'Orange',
        'value': 'Apple',
        'value2': 'Orange',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('multiple_choice', props),
          dark: dark,
        );
        expect(
          find.byType(shadcn.MultipleAnswer<String>),
          findsOneWidget,
        );
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Orange'), findsOneWidget);
      }
    });
  });

  group('object_input', () {
    testWidgets('defaults render the date editor (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('object_input', {}), dark: dark);
        expect(find.byType(shadcn.DateInput), findsOneWidget);
      }
    });

    testWidgets('time and duration modes (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('object_input', {
            'mode': 'time',
            'placeholder': 'Alarm',
            'label': 'Wake up',
          }),
          dark: dark,
        );
        expect(find.byType(shadcn.TimeInput), findsOneWidget);
        expect(find.text('Wake up'), findsOneWidget);
        await _pump(
          tester,
          buildCatalogItem('object_input', {
            'mode': 'duration',
            'placeholder': 'Length',
          }),
          dark: dark,
        );
        expect(find.byType(shadcn.DurationInput), findsOneWidget);
      }
    });
  });

  group('text_field', () {
    testWidgets('defaults render the rich field (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text_field', {}), dark: dark);
        expect(find.byType(shadcn.TextField), findsOneWidget);
        expect(find.text('Type here'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'placeholder': 'Nickname',
        'label': 'Profile',
        'disabled': false,
        'initialValue': 'Ada',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text_field', props), dark: dark);
        expect(find.byType(shadcn.TextField), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      }
    });
  });

  group('markdown', () {
    testWidgets('defaults render inline markdown (light + dark)', (
      tester,
    ) async {
      // Async parse: the document settles after attach.
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('markdown', {}), dark: dark);
        await tester.pumpAndSettle();
        expect(find.byType(shadcn.Markdown), findsOneWidget);
        expect(
          find.textContaining('Title', findRichText: true),
          findsWidgets,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'data': '# Hello\n\nCanvas *markdown* here.',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('markdown', props), dark: dark);
        await tester.pumpAndSettle();
        expect(find.byType(shadcn.Markdown), findsOneWidget);
        expect(
          find.textContaining('Hello', findRichText: true),
          findsWidgets,
        );
      }
    });
  });

  group('text_animate', () {
    testWidgets('defaults render the streaming text (light + dark)', (
      tester,
    ) async {
      // Progressive reveal: only the widget type pins (the full sentence
      // settles after the animation, never on the first frame).
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text_animate', {}), dark: dark);
        expect(find.byType(shadcn.StreamingText), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'text': 'Typing out loud.'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('text_animate', props),
          dark: dark,
        );
        expect(find.byType(shadcn.StreamingText), findsOneWidget);
      }
    });
  });

  group('icon', () {
    testWidgets('defaults render the wrapped star (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('icon', {}), dark: dark);
        expect(find.byType(shadcn.WrappedIcon), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'name': 'heart', 'size': 32.0};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('icon', props), dark: dark);
        expect(find.byType(shadcn.WrappedIcon), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
      }
    });
  });

  group('navigation_menu', () {
    testWidgets('defaults render the menu bar (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('navigation_menu', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.NavigationMenu), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
        expect(find.text('Company'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'menu1': 'Docs',
        'item1': 'Guide',
        'detail1': 'Start here.',
        'menu2': 'Blog',
        'item2': 'News',
        'detail2': 'Latest posts.',
      };
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('navigation_menu', props),
          dark: dark,
        );
        expect(find.text('Docs'), findsOneWidget);
        expect(find.text('Blog'), findsOneWidget);
      }
    });
  });

  group('dropzone', () {
    testWidgets('defaults render the drop surface (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('dropzone', {}), dark: dark);
        expect(find.byType(shadcn.FileDropzone), findsOneWidget);
        expect(find.text('Browse files'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'hint': 'Drop photos', 'action': 'Choose photos'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('dropzone', props), dark: dark);
        expect(find.byType(shadcn.FileDropzone), findsOneWidget);
        expect(find.text('Choose photos'), findsOneWidget);
      }
    });
  });

  group('border_loading', () {
    testWidgets('defaults render the ring (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('border_loading', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.BorderLoading), findsOneWidget);
        expect(find.text('Loading'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Syncing'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('border_loading', props),
          dark: dark,
        );
        expect(find.text('Syncing'), findsOneWidget);
      }
    });
  });

  group('overflow_marquee', () {
    testWidgets('defaults render the marquee (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('overflow_marquee', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.OverflowMarquee), findsOneWidget);
        expect(
          find.text('This text scrolls when it overflows its parent.'),
          findsOneWidget,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'text': 'Breaking news ticker'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('overflow_marquee', props),
          dark: dark,
        );
        expect(find.text('Breaking news ticker'), findsOneWidget);
      }
    });
  });

  group('focus_outline', () {
    testWidgets('defaults render the ringed button (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('focus_outline', {}), dark: dark);
        expect(find.byType(shadcn.FocusOutline), findsOneWidget);
        expect(find.text('Focus me'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Search box', 'focused': false};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('focus_outline', props),
          dark: dark,
        );
        expect(find.text('Search box'), findsOneWidget);
      }
    });
  });

  group('switcher', () {
    testWidgets('defaults render the first page (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('switcher', {}), dark: dark);
        expect(find.byType(shadcn.Switcher), findsOneWidget);
        expect(find.text('Page 1'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'direction': 'up',
        'page1': 'Cover',
        'page2': 'Back',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('switcher', props), dark: dark);
        expect(find.byType(shadcn.Switcher), findsOneWidget);
        expect(find.text('Cover'), findsOneWidget);
      }
    });
  });

  group('scrollable', () {
    testWidgets('defaults render the faded viewport (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('scrollable', {}), dark: dark);
        expect(find.byType(shadcn.FadedScrollableViewport), findsOneWidget);
        expect(
          find.text('First line of scrollable content.'),
          findsOneWidget,
        );
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {
        'text1': 'Alpha',
        'text2': 'Beta',
        'text3': 'Gamma',
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('scrollable', props), dark: dark);
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Gamma'), findsOneWidget);
      }
    });
  });

  group('stage_container', () {
    testWidgets('defaults render the stage (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('stage_container', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.StageContainer), findsOneWidget);
        expect(find.text('Stage content'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Hero section'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('stage_container', props),
          dark: dark,
        );
        expect(find.text('Hero section'), findsOneWidget);
      }
    });
  });

  group('media_query', () {
    testWidgets('defaults show the in-range child (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('media_query', {}), dark: dark);
        expect(find.byType(shadcn.MediaQueryVisibility), findsOneWidget);
        expect(find.text('Wide content'), findsOneWidget);
      }
    });

    testWidgets('a tall breakpoint shows the alternate (light + dark)', (
      tester,
    ) async {
      const props = {
        'label': 'Desktop',
        'alternate': 'Mobile',
        'minWidth': 2000.0,
      };
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('media_query', props), dark: dark);
        expect(find.text('Mobile'), findsOneWidget);
        expect(find.text('Desktop'), findsNothing);
      }
    });
  });

  group('scrollview', () {
    testWidgets('defaults render the interceptor (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('scrollview', {}), dark: dark);
        expect(find.byType(shadcn.ScrollViewInterceptor), findsOneWidget);
        expect(find.text('Middle-drag to scroll'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Drag canvas'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('scrollview', props), dark: dark);
        expect(find.text('Drag canvas'), findsOneWidget);
      }
    });
  });

  group('hover', () {
    testWidgets('defaults render the hover surface (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('hover', {}), dark: dark);
        expect(find.byType(shadcn.HoverActivity), findsOneWidget);
        expect(find.text('Hover me'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Hover the card'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('hover', props), dark: dark);
        expect(find.text('Hover the card'), findsOneWidget);
      }
    });
  });

  group('patch', () {
    testWidgets('defaults render the click surface (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('patch', {}), dark: dark);
        expect(find.byType(shadcn.ClickDetector), findsOneWidget);
        expect(find.text('Tap me'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Double-tap me'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('patch', props), dark: dark);
        expect(find.text('Double-tap me'), findsOneWidget);
      }
    });
  });

  group('text', () {
    testWidgets('defaults render the wrapped text (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text', {}), dark: dark);
        expect(find.byType(shadcn.WrappedText), findsOneWidget);
        expect(find.text('Styled text'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'text': 'Hello, canvas'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('text', props), dark: dark);
        expect(find.text('Hello, canvas'), findsOneWidget);
      }
    });
  });

  group('filter_bar', () {
    testWidgets('defaults render the search row (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('filter_bar', {}), dark: dark);
        expect(find.byType(shadcn.FilterBar), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'searchPlaceholder': 'Filter orders'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('filter_bar', props), dark: dark);
        expect(find.byType(shadcn.FilterBar), findsOneWidget);
        expect(find.text('Filter orders'), findsOneWidget);
      }
    });
  });

  group('fade_scroll', () {
    testWidgets('defaults render the faded list (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('fade_scroll', {}), dark: dark);
        expect(find.byType(shadcn.FadeScroll), findsOneWidget);
        expect(find.text('Row 1'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'row1': 'Apples', 'row2': 'Oranges', 'row3': 'Pears'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('fade_scroll', props), dark: dark);
        expect(find.text('Apples'), findsOneWidget);
        expect(find.text('Pears'), findsOneWidget);
      }
    });
  });

  group('resizable', () {
    testWidgets('defaults render two panes (light + dark)', (tester) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('resizable', {}), dark: dark);
        expect(find.byType(shadcn.ResizablePanel), findsOneWidget);
        expect(find.text('Left pane'), findsOneWidget);
        expect(find.text('Right pane'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'pane1': 'Editor', 'pane2': 'Preview'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('resizable', props), dark: dark);
        expect(find.text('Editor'), findsOneWidget);
        expect(find.text('Preview'), findsOneWidget);
      }
    });
  });

  group('subfocus', () {
    testWidgets('defaults render the scope child (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('subfocus', {}), dark: dark);
        expect(find.byType(shadcn.SubFocus), findsOneWidget);
        expect(find.text('Focused scope'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'Form section'};
      for (final dark in [false, true]) {
        await _pump(tester, buildCatalogItem('subfocus', props), dark: dark);
        expect(find.text('Form section'), findsOneWidget);
      }
    });
  });

  group('repeated_animation_builder', () {
    testWidgets('defaults render the pulse wrapper (light + dark)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('repeated_animation_builder', {}),
          dark: dark,
        );
        expect(find.byType(shadcn.PulsingAnimation), findsOneWidget);
        expect(find.text('Pulsing'), findsOneWidget);
      }
    });

    testWidgets('representative props (light + dark)', (tester) async {
      const props = {'label': 'New badge'};
      for (final dark in [false, true]) {
        await _pump(
          tester,
          buildCatalogItem('repeated_animation_builder', props),
          dark: dark,
        );
        expect(find.text('New badge'), findsOneWidget);
      }
    });
  });

  // Track FF2 narrow smoke (2026-09-06): every new builder must survive a
  // 320px viewport (direct + tight row slice) since the shared narrow suite
  // cannot list them until the coordinator updates its pins (reported).
  group('track FF2 narrow 320px smoke', () {
    testWidgets('every FF2 kind survives 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final kind in _kTrackFF2Kinds) {
        await _pumpFF2(tester, kind, const {});
        expect(tester.takeException(), isNull, reason: '$kind defaults 320');
        await _pumpFF2(
          tester,
          kind,
          Map<String, dynamic>.of(findEntry(kind)!.defaults),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '$kind explicit-defaults 320',
        );
        // Narrow row child: tight 320px slice of a Row (the command-shell
        // precedent) — the builder must survive unbounded-height slices too.
        await _pump(
          tester,
          Row(
            children: [Expanded(child: buildCatalogItem(kind, const {}))],
          ),
        );
        if (kind == 'markdown') await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$kind row-slice 320');
      }
    });
  });
}
