/// Track T narrow-width hardening: every catalog builder must survive a 320px
/// viewport (phone screens are 390 wide; nodes also render in narrow row
/// children) under light + dark with defaults + representative props.
///
/// Overflows throw in `flutter_test`, so bare pumping suffices to fail on
/// overflow; [tester.takeException] is still asserted explicitly so layout and
/// paint-phase errors (e.g. `RenderFlex overflowed`) fail loudly instead of
/// lingering as pending exceptions. Each builder is also pumped inside a
/// `Row > Expanded` child to catch unbounded-width crashes (the `command`
/// live shell's `IntrinsicWidth` trap from Track M).
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Representative (functional, non-default) props per kind — mirrors the
/// values already covered in `catalog_test.dart` / `registry_builders_test.dart`
/// so the narrow pass exercises the same states, plus boundary counts where
/// width scales with the count (OTP length, history columns).
const Map<String, Map<String, dynamic>> _representativeProps = {
  'button': {
    'label': 'Go',
    'variant': 'secondary',
    'size': 'lg',
    'disabled': false,
  },
  'card': {'title': 'T', 'description': 'D', 'showFooter': true},
  'input': {
    'placeholder': 'Type here',
    'label': 'Email',
    'initialValue': 'Ada',
    'disabled': false,
    'obscure': false,
    'readOnly': true,
  },
  'badge': {'label': 'New', 'variant': 'destructive'},
  'switch': {'value': true, 'disabled': false},
  'avatar': {'initials': 'CD', 'size': 64.0},
  'checkbox': {'value': true, 'disabled': false, 'tristate': true},
  'divider': {'label': 'Section', 'thickness': 4.0},
  'progress': {'progress': 0.75},
  'tabs': {'tab1': 'Home', 'tab2': 'Settings', 'index': 1, 'expand': true},
  'accordion': {'title': 'Details', 'content': 'Extra info', 'expanded': true},
  'select': {
    'placeholder': 'Pick one',
    'option1': 'Apple',
    'option2': 'Orange',
    'value': 'Apple',
    'disabled': false,
  },
  'radio_group': {
    'option1': 'Apple',
    'option2': 'Orange',
    'value': 'Orange',
    'disabled': false,
  },
  'skeleton': {'label': 'Loading results', 'enabled': true},
  'breadcrumb': {
    'home': 'Docs',
    'current': 'Getting started',
    'separator': 'slash',
  },
  'dialog': {
    'title': 'Confirm delete',
    'message': 'This will permanently remove the selected item.',
    'showActions': true,
  },
  'tooltip': {'label': 'More info', 'tip': 'Extra help text'},
  'toast': {
    'title': 'Upload complete',
    'message': '3 files uploaded successfully',
    'autoDismiss': false,
  },
  'drawer': {
    'title': 'Settings',
    'content': 'Adjust your preferences here',
    'position': 'left',
  },
  'basic': {
    'title': 'Ada',
    'subtitle': 'Lovelace',
    'content': 'Analytical Engine',
    'showLeading': true,
    'showTrailing': true,
  },
  'card_image': {'title': 'Sunset', 'subtitle': 'Golden hour'},
  'scaffold': {'title': 'Shop', 'body': 'Products'},
  'collapsible': {
    'trigger': 'Details',
    'content': 'Extra info',
    'expanded': true,
  },
  'steps': {
    'step1': 'Order',
    'detail1': 'Place the order',
    'step2': 'Pay',
    'detail2': 'Complete payment',
  },
  'timeline': {
    'time1': '8:00 AM',
    'title1': 'Standup',
    'detail1': 'Daily sync',
    'time2': '5:00 PM',
    'title2': 'Demo',
    'detail2': 'Sprint demo',
  },
  'outlined_container': {'label': 'Notice: maintenance window tonight'},
  'hidden': {'label': 'Shh', 'hidden': false},
  'keyboard_shortcut': {'keys': 'Shift+Alt+S'},
  'tracker': {'segments': 5, 'level': 'critical'},
  'chat': {'message': 'On my way, see you soon!'},
  'selectable': {'text': 'Copy this text for sharing'},
  'star_rating': {'value': 4.5, 'max': 5.0},
  'clickable': {'label': 'Press and hold to confirm'},
  'scrollbar': {'label': 'Long list content here'},
  'pagination': {'page': 2, 'totalPages': 7},
  'alert_dialog': {
    'title': 'Delete project?',
    'message': 'This action cannot be undone.',
    'showActions': true,
  },
  'menu': {'heading': 'Edit', 'item1': 'Cut', 'item2': 'Paste'},
  'popover': {
    'trigger': 'Details',
    'title': 'More info',
    'body': 'Extra context here.',
  },
  'popup': {'item1': 'Account', 'item2': 'Billing', 'item3': 'Logout'},
  'menubar': {'menu1': 'View', 'menu2': 'Tools'},
  'dropdown_menu': {'heading': 'Team', 'item1': 'Invite', 'item2': 'Leave'},
  'context_menu': {'hint': 'Options', 'item1': 'Cut', 'item2': 'Copy'},
  'hover_card': {
    'handle': '@canvas',
    'title': 'Preview',
    'body': 'Details on hover.',
  },
  'command': {'hint': 'Jump to...', 'item1': 'Mail', 'item2': 'Profile'},
  'swiper': {'hint': 'Swipe me', 'content': 'Sheet body'},
  'refresh_trigger': {'item1': 'Apples', 'item2': 'Oranges', 'item3': 'Pears'},
  'tab_container': {
    'tab1': 'Overview',
    'tab2': 'Details',
    'tab3': 'Reviews',
    'index': 1,
  },
  'tab_list': {'tab1': 'Home', 'tab2': 'Work', 'index': 1},
  'tab_pane': {'tab1': 'Home', 'tab2': 'Work', 'tab3': 'Play', 'focused': 1},
  'stepper': {
    'step1': 'Cart',
    'step2': 'Ship',
    'step3': 'Pay',
    'detail1': 'Items in cart',
    'detail2': 'Shipping address',
    'detail3': 'Payment method',
    'step': 1,
  },
  'slider': {'value': 0.25},
  'input_otp': {'length': 8},
  'calendar': {'mode': 'multi'},
  'date_picker': {'placeholder': 'Birthday', 'label': 'Date of birth'},
  'time_picker': {'placeholder': 'Alarm', 'label': 'Wake up'},
  'carousel': {'slides': 5},
  'tree': {
    'node1': 'Docs',
    'child1': 'Guide',
    'child2': 'API',
    'node2': 'Blog',
  },
  'table': {
    'header1': 'City',
    'header2': 'Country',
    'name1': 'Paris',
    'role1': 'France',
    'name2': 'Rome',
    'role2': 'Italy',
  },
  'form': {
    'label': 'Email',
    'placeholder': 'jane@example.com',
    'submitLabel': 'Send',
  },
  'form_field': {'placeholder': 'Pick one', 'value': 'Giraffe'},
  'formatted_input': {'label': 'Birthday'},
  'validated': {'placeholder': 'Email', 'errorText': 'Enter an email'},
  'color_picker': {'hex': '#FF5733'},
  'color_input': {'hex': '#4CAF50'},
  'hsl': {'mode': 'sat'},
  'hsv': {'mode': 'val'},
  'history': {'columns': 10},
  'feature_carousel': {
    'title1': 'Dark Mode',
    'description1': 'Easy on the eyes.',
    'title2': 'Widgets',
    'description2': 'Compose anything.',
  },
};

/// String prop keys that are enums/hex (not free text) — the long-text stress
/// variant must preserve them so it exercises layout width, not fallback paths.
const _kNonTextKeys = {
  'variant',
  'size',
  'mode',
  'position',
  'separator',
  'level',
  'hex',
};

/// Count extremes that only make sense as a stress case (beyond the
/// representative values above): full-page pagination and a maxed-out rating.
const Map<String, Map<String, dynamic>> _kStressCounts = {
  'pagination': {'page': 20, 'totalPages': 20},
  'star_rating': {'value': 10.0, 'max': 10.0},
};

const _kLongText =
    'A very long label value for narrow width testing 0123456789';

/// Long-text stress props: representative with every free-text string replaced
/// by a 60-char value (ellipsis/collapse handling must kick in) plus the
/// count extremes above.
Map<String, dynamic> _longProps(String kind) {
  final base = Map<String, dynamic>.of(
    _representativeProps[kind] ?? <String, dynamic>{},
  );
  for (final key in base.keys.toList()) {
    final value = base[key];
    if (value is String && !_kNonTextKeys.contains(key)) {
      base[key] = key == 'keys' ? 'Ctrl+Shift+Alt+K' : _kLongText;
    }
  }
  // Kinds with no string props still get their count extreme.
  base.addAll(_kStressCounts[kind] ?? const {});
  // Fill empty-string defaults that representative props leave empty (e.g.
  // input `label`, divider `label`): an absent caption must also survive when
  // a user types a long one.
  final entry = findEntry(kind);
  if (entry != null) {
    for (final d in entry.defaults.entries) {
      if (d.value is String &&
          (d.value as String).isEmpty &&
          !base.containsKey(d.key)) {
        base[d.key] = _kLongText;
      }
    }
  }
  return base;
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpChecked(
  WidgetTester tester,
  Widget widget, {
  required bool dark,
  required String reason,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(body: widget),
    ),
  );
  await tester.pump();
  final Object? error = tester.takeException();
  expect(error, isNull, reason: reason);
}

Future<void> _pumpBothLayouts(
  WidgetTester tester,
  String kind,
  Map<String, dynamic> props, {
  required bool dark,
  required String set,
}) async {
  await _pumpChecked(
    tester,
    buildCatalogItem(kind, props),
    dark: dark,
    reason: '$kind $set dark=$dark direct',
  );
  // Narrow row child: catches unbounded-width crashes (Track M `command`
  // shell precedent) — the builder must survive a tight 320px slice of a Row.
  await _pumpChecked(
    tester,
    Row(children: [Expanded(child: buildCatalogItem(kind, props))]),
    dark: dark,
    reason: '$kind $set dark=$dark row-expanded',
  );
}

void main() {
  group('narrow 320px (MediaQuery 320x800)', () {
    for (final entry in kCatalog) {
      testWidgets('${entry.kind} survives 320px', (tester) async {
        _setViewport(tester, const Size(320, 800));
        for (final dark in [false, true]) {
          await _pumpBothLayouts(
            tester,
            entry.kind,
            {},
            dark: dark,
            set: 'defaults',
          );
          await _pumpBothLayouts(
            tester,
            entry.kind,
            _representativeProps[entry.kind] ?? const {},
            dark: dark,
            set: 'representative',
          );
          await _pumpBothLayouts(
            tester,
            entry.kind,
            _longProps(entry.kind),
            dark: dark,
            set: 'long',
          );
        }
      });
    }

    test('representative map covers every catalog kind', () {
      for (final entry in kCatalog) {
        expect(
          _representativeProps,
          contains(entry.kind),
          reason: 'no representative props for ${entry.kind}',
        );
      }
    });
  });

  // Default-props rendering must stay pixel-identical at the normal 390px
  // phone width: these expectations mirror `catalog_test.dart` /
  // `registry_builders_test.dart`, so any Track T shell change that alters
  // normal-width rendering fails here rather than silently drifting.
  group('normal 390px unchanged', () {
    testWidgets('button + card + input keep their content', (tester) async {
      _setViewport(tester, const Size(390, 800));
      await _pumpChecked(
        tester,
        buildCatalogItem('button', {
          'label': 'Go',
          'variant': 'primary',
          'size': 'md',
          'disabled': false,
        }),
        dark: false,
        reason: 'button 390',
      );
      expect(find.text('Go'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('card', {
          'title': 'T',
          'description': 'D',
          'showFooter': true,
        }),
        dark: false,
        reason: 'card 390',
      );
      expect(find.byType(shadcn.Card), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('input', {
          'placeholder': 'Type here',
          'label': 'Email',
          'disabled': false,
          'obscure': false,
        }),
        dark: false,
        reason: 'input 390',
      );
      expect(find.byType(shadcn.TextField), findsOneWidget);
      expect(find.text('Type here'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('dialog + toast + drawer keep their content', (tester) async {
      _setViewport(tester, const Size(390, 800));
      await _pumpChecked(
        tester,
        buildCatalogItem('dialog', {
          'title': 'T',
          'message': 'M',
          'showActions': true,
        }),
        dark: false,
        reason: 'dialog 390',
      );
      expect(find.byType(shadcn.ModalContainer), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('toast', {
          'title': 'Saved',
          'message': 'Saved successfully',
        }),
        dark: false,
        reason: 'toast 390',
      );
      expect(find.byType(shadcn.ToastEntry), findsOneWidget);
      expect(find.text('Saved successfully'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('drawer', {
          'title': 'Drawer',
          'content': 'Drawer content',
        }),
        dark: false,
        reason: 'drawer 390',
      );
      expect(find.byType(shadcn.DrawerWrapper), findsOneWidget);
      expect(find.text('Drawer content'), findsOneWidget);
    });

    testWidgets('scaffold + carousel + command keep their shells', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 800));
      await _pumpChecked(
        tester,
        buildCatalogItem('scaffold', {}),
        dark: false,
        reason: 'scaffold 390',
      );
      expect(find.byType(shadcn.Scaffold), findsOneWidget);
      expect(find.byType(shadcn.AppBar), findsOneWidget);
      expect(find.text('My App'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('carousel', {}),
        dark: false,
        reason: 'carousel 390',
      );
      expect(find.byType(shadcn.Carousel), findsOneWidget);
      expect(find.byType(shadcn.DotIndicator), findsOneWidget);
      expect(find.text('Slide 1'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('command', {}),
        dark: false,
        reason: 'command 390',
      );
      expect(find.byType(shadcn.TextField), findsOneWidget);
      expect(find.byType(shadcn.CommandCategory), findsOneWidget);
      expect(find.byType(shadcn.CommandItem), findsNWidgets(2));
      expect(find.text('Search commands...'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('tooltip + feature_carousel keep their content (dark)', (
      tester,
    ) async {
      _setViewport(tester, const Size(390, 800));
      await _pumpChecked(
        tester,
        buildCatalogItem('tooltip', {
          'label': 'Hover me',
          'tip': 'Helpful context',
        }),
        dark: true,
        reason: 'tooltip 390 dark',
      );
      expect(find.byType(shadcn.Tooltip), findsOneWidget);
      expect(find.text('Hover me'), findsOneWidget);

      await _pumpChecked(
        tester,
        buildCatalogItem('feature_carousel', {}),
        dark: true,
        reason: 'feature_carousel 390 dark',
      );
      expect(find.byType(shadcn.FeatureCardCarousel), findsOneWidget);
      expect(find.text('Palette Selector'), findsOneWidget);
    });
  });
}
