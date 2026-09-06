import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

import 'fixtures/two_screen_doc.dart';

/// Minimal registry-source stub keyed by the exact bundle destination
/// templates. The real `kTestSources` map stays in canvas_app
/// (generated Flutter-app data, not shared logic).
const kTestSources = {
  '{installPath}/components/control/button/button.dart':
      'class Button extends StatelessWidget {}',
  '{installPath}/components/layout/card/card.dart':
      'class Card extends StatelessWidget {}',
};

/// Stub registry extended with the Track H2 supplemental non-kind files, so
/// wiring-emission tests can assert the seed + manifest entries without the
/// full embedded corpus (contents never parsed for directives here).
const kWiringSources = {
  ...kTestSources,
  '{installPath}/components/form/text_field/text_field.dart':
      'class TextField extends StatelessWidget {}',
  '{installPath}/components/utility/color/color.dart':
      'class ColorDerivative {}',
};

void main() {
  test('buildCleanBundle manifest has the Task 12 shape', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final manifest = jsonDecode(bundle.manifestJson) as Map<String, dynamic>;

    expect(manifest['screens'], ['pay', 'done']);
    expect(manifest['namespace'], 'shadcn');
    expect(manifest['root'], 'lib/ui/shadcn');
    expect(manifest['entry'], 'lib/ui/screens/pay_screen.dart');

    final files = manifest['files'] as List;
    expect(files, isNotEmpty);
    for (final f in files) {
      final entry = f as Map<String, dynamic>;
      expect(entry.keys, containsAll(['source', 'destination']));
      expect(entry['source'] as String, startsWith('registry/'));
      expect(
        entry['destination'] as String,
        startsWith('lib/ui/shadcn/'),
      );
    }

    final shared = manifest['shared'] as List;
    expect(shared, contains('theme'));

    final pubspec = manifest['pubspec'] as Map<String, dynamic>;
    final deps = pubspec['dependencies'] as Map<String, dynamic>;
    expect(deps.keys, contains('gap'));
  });

  test('buildCleanBundle files hold screens plus shadcn bodies', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);

    expect(
      bundle.files.keys,
      containsAll([
        'lib/ui/screens/pay_screen.dart',
        'lib/ui/screens/done_screen.dart',
      ]),
    );
    final shadcnPaths = bundle.files.keys
        .where((p) => p.startsWith('lib/ui/shadcn/'))
        .toList();
    expect(shadcnPaths, isNotEmpty);

    // Screens are minimal scaffolds referencing package imports, never
    // inlined component bodies (those ship as separate files).
    final payScreen = bundle.files['lib/ui/screens/pay_screen.dart']!;
    expect(payScreen, contains('package:flutter'));
    expect(payScreen, contains('PayScreen'));
    expect(payScreen, isNot(contains('class Button')));

    // At least one shipped body carries the real Button implementation.
    expect(
      bundle.files.values.any((c) => c.contains('class Button')),
      isTrue,
    );
  });

  test('buildCleanBundle zip decodes listing the same entries', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final archive = ZipDecoder().decodeBytes(bundle.zipBytes);
    final names = {for (final f in archive.files) f.name};

    expect(names, containsAll(bundle.files.keys));
    expect(names, containsAll(['manifest.json', 'pubspec_patch.yaml']));

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final expected = file.name == 'manifest.json'
          ? bundle.manifestJson
          : file.name == 'pubspec_patch.yaml'
              ? bundle.pubspecPatch
              : bundle.files[file.name];
      expect(utf8.decode(file.content as List<int>), expected);
    }
  });

  test('buildCleanBundle pubspec patch merges component dependencies', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    expect(bundle.pubspecPatch, contains('gap'));
    expect(bundle.pubspecPatch, contains('dependencies:'));
  });

  test('buildCleanBundle warns on unknown kinds instead of crashing', () {    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'not_a_component', 'label': '???'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Weird', 'brief': 'unknown kind doc'},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final manifest = jsonDecode(bundle.manifestJson) as Map<String, dynamic>;
    expect((manifest['warnings'] as List), isNotEmpty);
    expect(bundle.files.keys, contains('lib/ui/screens/pay_screen.dart'));
  });

  test('tap action emits a pushNamed navigation to the screen route', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final payScreen = bundle.files['lib/ui/screens/pay_screen.dart']!;

    // Vanilla StatefulWidget with no store dependency (easy adoption).
    expect(payScreen, contains('extends StatefulWidget'));
    expect(payScreen, contains('no store dependency'));
    expect(payScreen, isNot(contains('CanvasStore')));

    // The Pay button navigates to the Done route by name.
    expect(payScreen, contains('GestureDetector('));
    expect(payScreen, contains("pushNamed('/done')"));
    expect(payScreen, contains('// transition: slide'));

    // The Done screen has no actions: no navigation emitted there.
    final doneScreen = bundle.files['lib/ui/screens/done_screen.dart']!;
    expect(doneScreen, isNot(contains('pushNamed')));
    expect(doneScreen, isNot(contains('Navigator')));
  });

  test('unknown action target emits a comment and no navigation', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
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
              'label': 'Lost',
              'action': {'to': 'missing', 'transition': 'fade'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Dangling', 'brief': ''},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains("unknown target 'missing'"));
    expect(screen, isNot(contains('pushNamed')));
    expect(screen, isNot(contains('Navigator')));
  });

  test('hiddenOn emits a tier conditional in the bundle idiom', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'hiddenOn': ['mobile'],
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Hidden', 'brief': ''},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains('LayoutBuilder'));
    expect(screen, contains("tier == 'mobile'"));
    expect(screen, contains('SizedBox.shrink'));
    expect(screen, contains("'Pay'"));
  });

  test('breakpointValues merge per tier with a static default', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'breakpointValues': {
            'desktop': {'label': 'Wide Pay'},
          },
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Overrides', 'brief': ''},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains('LayoutBuilder'));
    expect(screen, contains("tier == 'desktop'"));
    expect(screen, contains("'Wide Pay'"));
    expect(screen, contains("'Pay'"));
  });

  test('docs without responsive/actions produce byte-identical output', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
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
              'label': 'Pay',
              'variant': 'primary',
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Plain', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kTestSources);
    expect(
      bundle.files['lib/ui/screens/home_screen.dart'],
      kBundleScreenGolden,
    );
  });

  test('labels with quotes and dollars are escaped in widget expressions', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': "O'Brien \$5"},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Escapes', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    // Escaped single-quote and dollar: still one valid string literal.
    expect(screen, contains("O\\'Brien \\\$5"));
    expect(screen, isNot(contains("Text('O'Brien")));
  });

  test('non-catalog kinds keep the comment plus placeholder byte-identical', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'chip', 'label': 'Hi'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Plain', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kTestSources);
    expect(
      bundle.files['lib/ui/screens/home_screen.dart'],
      kBundleNonCatalogGolden,
    );
  });

  test('barrel comments resolve to real kit entry files', () {
    // Install categories snapshotted from components.json destination
    // prefixes; filenames default to `<kind>.dart` with three verified
    // exceptions (see `_barrelFile` in codegen_bundle.dart — resolved by
    // reading the pinned kit checkout, NOT assumed; re-verify against a
    // newer kit on upgrade, then update this table).
    const categories = {
      'button': 'control',
      'card': 'layout',
      'input': 'form',
      'badge': 'display',
      'switch': 'form',
      'avatar': 'display',
      'checkbox': 'form',
      'divider': 'display',
      'progress': 'display',
      'tabs': 'navigation',
      'accordion': 'layout',
      'select': 'form',
      'radio_group': 'form',
      'skeleton': 'display',
      'breadcrumb': 'navigation',
      'dialog': 'overlay',
      'tooltip': 'overlay',
      'toast': 'overlay',
      'drawer': 'overlay',
      'chip': 'display',
      'alert': 'layout',
      'circular_progress_indicator': 'display',
      'linear_progress_indicator': 'display',
      'triple_dots': 'display',
      'dot_indicator': 'display',
      'empty_state': 'display',
      'code_snippet': 'display',
      'number_ticker': 'display',
      'text_area': 'form',
      'basic': 'layout',
      'card_image': 'layout',
      'scaffold': 'layout',
      'collapsible': 'layout',
      'steps': 'layout',
      'timeline': 'layout',
      'outlined_container': 'layout',
      'hidden': 'layout',
      'keyboard_shortcut': 'display',
      'tracker': 'display',
      'chat': 'display',
      'selectable': 'display',
      'star_rating': 'form',
      'clickable': 'control',
      'scrollbar': 'control',
      'pagination': 'navigation',
      'alert_dialog': 'overlay',
      'menu': 'overlay',
      'popover': 'overlay',
      'popup': 'overlay',
      'menubar': 'overlay',
      'dropdown_menu': 'overlay',
      'context_menu': 'overlay',
      'hover_card': 'overlay',
      'command': 'control',
      'swiper': 'overlay',
      'refresh_trigger': 'overlay',
      'tab_container': 'navigation',
      'tab_list': 'navigation',
      'tab_pane': 'navigation',
      'stepper': 'navigation',
      'slider': 'form',
      'input_otp': 'form',
      'calendar': 'display',
      'date_picker': 'form',
      'time_picker': 'form',
      'carousel': 'display',
      'tree': 'display',
      'table': 'layout',
      'form': 'form',
      'form_field': 'form',
      'formatted_input': 'form',
      'validated': 'form',
      'color_picker': 'form',
      'color_input': 'form',
      'hsl': 'form',
      'hsv': 'form',
      'history': 'form',
      'feature_carousel': 'display',
    };
    const entryFile = {
      'hsl': 'hsl_color_slider.dart',
      'hsv': 'hsv_color_slider.dart',
      'tab_list': '_impl/core/tab_list.dart',
    };
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            for (var i = 0; i < categories.keys.length; i++)
              {'id': 'i$i', 'kind': categories.keys.elementAt(i)},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'All', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    final emitted = <String, String>{};
    for (final line in screen.split('\n')) {
      final match = RegExp(r'^// - (\S+) -> (\S+)$').firstMatch(line);
      if (match != null) emitted[match.group(1)!] = match.group(2)!;
    }
    // Every known kind resolves, and only known kinds resolve.
    expect(emitted.keys.toSet(), categories.keys.toSet());
    for (final kind in categories.keys) {
      final file = entryFile[kind] ?? '$kind.dart';
      expect(
        emitted[kind],
        'lib/ui/shadcn/components/${categories[kind]}/$kind/$file',
        reason: kind,
      );
    }
    // The three historical bugs (assumed `<kind>/<kind>.dart` paths with no
    // such file in the kit) now point at real entry files.
    expect(emitted['hsl'], endsWith('/hsl_color_slider.dart'));
    expect(emitted['hsv'], endsWith('/hsv_color_slider.dart'));
    expect(emitted['tab_list'], endsWith('/tab_list/_impl/core/tab_list.dart'));
  });

  test('bodies mirror catalog props, defaults, and edge handling', () {
    String screenFor(String kind, [Map<String, dynamic> props = const {}]) {
      final bundle = buildCleanBundle(_singleKindDoc(kind, props), kTestSources);
      return bundle.files['lib/ui/screens/home_screen.dart']!;
    }

    // Seed five: variants, sizes, and footer/label wiring.
    expect(
      screenFor('button', {
        'label': 'Go',
        'variant': 'secondary',
        'size': 'sm',
        'disabled': true,
      }),
      contains(
        'SecondaryButton(\n'
        '        onPressed: () {},\n'
        '        enabled: false,\n'
        '        size: ButtonSize.small,\n'
        "        child: Text('Go'),",
      ),
    );
    // Unknown variant/size fall back (catalog honesty rule).
    final fallbackButton = screenFor('button', {
      'variant': 'weird',
      'size': 'xxl',
    });
    expect(fallbackButton, contains('PrimaryButton('));
    expect(fallbackButton, contains('ButtonSize.normal'));
    // The catalog's `text` variant (absent from the block enum) resolves.
    expect(screenFor('button', {'variant': 'text'}), contains('TextButton('));
    // Card defaults mirror the catalog ('Title', not single-file's titles).
    final card = screenFor('card', {'showFooter': true});
    expect(card, contains("Text('Title')"));
    expect(card, contains("child: Text('Action')"));
    expect(screenFor('card'), isNot(contains('Action')));
    // Input wires the catalog-only props (initialValue empty = uncontrolled).
    final input = screenFor('input', {
      'label': 'Name',
      'initialValue': 'Ada',
      'readOnly': true,
    });
    expect(input, contains("initialValue: 'Ada'"));
    expect(input, contains('readOnly: true'));
    expect(screenFor('input'), contains('initialValue: null'));
    expect(screenFor('badge', {'variant': 'destructive'}), contains('DestructiveBadge('));
    expect(
      screenFor('switch', {'disabled': true}),
      contains('Switch(value: false, onChanged: null),'),
    );
    // Unknown select values render unselected instead of crashing.
    expect(
      screenFor('select', {'value': 'Bogus'}),
      contains('value: null,'),
    );
    expect(
      screenFor('select', {'value': 'Option 1'}),
      contains("value: 'Option 1',"),
    );
    // Numeric clamps mirror the catalog domains.
    expect(screenFor('progress', {'progress': 99}), contains('Progress(progress: 1.0),'));
    expect(screenFor('avatar', {'size': 1000}), contains('size: 96.0'));
    expect(screenFor('star_rating', {'max': 99}), contains('max: 10.0'));
    expect(screenFor('slider', {'value': -1}), contains('Slider(value: 0.0,'));
    expect(
      screenFor('pagination', {'page': 99, 'totalPages': 5}),
      contains('Pagination(page: 5, totalPages: 5,'),
    );
    expect(screenFor('tabs', {'index': 7}), contains('index: 1,'));
    expect(screenFor('stepper', {'step': 9}), contains('currentStep: 2'));
    // Enum fallbacks mirror the catalog.
    expect(
      screenFor('calendar', {'mode': 'bogus'}),
      contains('CalendarSelectionMode.single'),
    );
    expect(
      screenFor('breadcrumb', {'separator': 'bogus'}),
      contains('Breadcrumb.arrowSeparator'),
    );
    expect(
      screenFor('drawer', {'position': 'bogus'}),
      contains('OverlayPosition.end'),
    );
    expect(screenFor('tracker', {'level': 'bogus'}), contains('TrackerLevel.fine'));
    expect(screenFor('hsl', {'mode': 'bogus'}), contains('HSLColorSliderType.hue'));
    // Malformed hex falls back to the kit-history blue, like the catalog.
    expect(
      screenFor('color_input', {'hex': 'zzz'}),
      contains('Color(0xFF2196F3)'),
    );
    expect(
      screenFor('color_picker', {'hex': '#F00'}),
      contains('Color(0xFFFF0000)'),
    );
    // Wrong-typed props fall back instead of crashing the exporter.
    expect(screenFor('button', {'label': 5}), contains("child: Text('Button'),"));
    expect(screenFor('progress', {'progress': 'x'}), contains('Progress(progress: 0.5),'));
    expect(
      screenFor('switch', {'value': 'yes'}),
      contains('Switch(value: false,'),
    );
  });

  test('every catalog kind emits its real widget body', () {
    // One token per catalog kind proving the real body rendered (per-kind
    // docs, so tokens never cross-match another kind's body).
    const tokens = {
      'button': 'PrimaryButton(',
      'card': 'Card(',
      'input': 'TextField(',
      'badge': 'PrimaryBadge(',
      'switch': 'Switch(',
      'avatar': 'Avatar(',
      'checkbox': 'Checkbox(',
      'divider': 'Divider(',
      'progress': 'Progress(',
      'tabs': 'Tabs(',
      'accordion': 'Accordion(',
      'select': 'Select<String>(',
      'radio_group': 'RadioGroup<String>(',
      'skeleton': '.asSkeleton(',
      'breadcrumb': 'Breadcrumb(',
      'dialog': 'ModalContainer(',
      'tooltip': 'Tooltip(',
      'toast': 'ToastEntry(',
      'drawer': 'DrawerWrapper(',
      'basic': 'Basic(',
      'card_image': 'CardImage(',
      'scaffold': 'Scaffold(',
      'collapsible': 'Collapsible(',
      'steps': 'Steps(',
      'timeline': 'Timeline(',
      'outlined_container': 'OutlinedContainer(',
      'hidden': 'Hidden(',
      'keyboard_shortcut': 'KeyboardDisplay(',
      'tracker': 'Tracker(',
      'chat': 'ChatBubble(',
      'selectable': 'SelectableText(',
      'star_rating': 'StarRating(',
      'clickable': 'Clickable(',
      'scrollbar': 'Scrollbar(',
      'pagination': 'Pagination(',
      'alert_dialog': 'AlertDialog(',
      'menu': 'MenuGroup(',
      'popover': 'Popover title',
      'popup': 'Sign out',
      'menubar': 'Menubar(',
      'dropdown_menu': 'DropdownMenu(',
      'context_menu': 'ContextMenu(',
      'hover_card': 'HoverCard(',
      'command': 'CommandCategory(',
      'swiper': 'Swiper(',
      'refresh_trigger': 'RefreshTrigger(',
      'tab_container': 'TabContainer(',
      // Track H2: the tab-list body renders the tabs barrel's family
      // (prefixed `as tabs`, mirroring the canvas catalog) — the standalone
      // tab_list barrel's `TabChild` is an uninstantiable mixin.
      'tab_list': 'tabs.TabItem(',
      'tab_pane': 'TabPane<String>(',
      'stepper': 'Stepper(',
      'slider': 'Slider(',
      'input_otp': 'InputOTP(',
      'calendar': 'Calendar(',
      'date_picker': 'DatePicker(',
      'time_picker': 'TimePicker(',
      'carousel': 'Carousel(',
      'tree': 'TreeView<String>(',
      // Track H2: the table/form/step bodies below compile only with the
      // disambiguated screen imports (Flutter `hide`s + `tabs` prefix) —
      // covered by the wiring tests further down.
      'table': 'Table(',
      'form': 'Form(',
      'form_field': 'ObjectFormField<String>(',
      'formatted_input': 'FormattedInput(',
      // Track H2: the validator rides the same-file `_CanvasRequiredValidator`
      // helper (never a bare `Validator(` construction) — see below.
      'validated': 'Validated<String>(',
      'color_picker': 'ColorPicker(',
      'color_input': 'ColorInput(',
      'hsl': 'HSLColorSlider(',
      'hsv': 'HSVColorSlider(',
      'history': 'ColorHistoryGrid(',
      'feature_carousel': 'FeatureCardCarousel(',
    };
    expect(tokens, hasLength(68));
    for (final entry in tokens.entries) {
      final bundle = buildCleanBundle(
        _singleKindDoc(entry.key),
        kTestSources,
      );
      final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
      expect(screen, contains(entry.value), reason: entry.key);
    }
  });

  test('tap actions wrap the real body in a GestureDetector', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final payScreen = bundle.files['lib/ui/screens/pay_screen.dart']!;
    expect(payScreen, contains('GestureDetector('));
    expect(payScreen, contains('child: PrimaryButton('));
    expect(payScreen, contains("pushNamed('/done')"));
    final doneScreen = bundle.files['lib/ui/screens/done_screen.dart']!;
    expect(doneScreen, contains('Card('));
    expect(doneScreen, isNot(contains('pushNamed')));
  });

  test('responsive branches carry bodies with statically merged props', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'breakpointValues': {
            'desktop': {'value': 'Option 2'},
          },
          'items': [
            {'id': 'i1', 'kind': 'select'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Overrides', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains('LayoutBuilder'));
    expect(
      screen,
      contains("if (tier == 'desktop') return Select<String>("),
    );
    expect(screen, contains("value: 'Option 2',"));
    expect(screen, contains('return Select<String>('));
    expect(screen, contains('value: null,'));
  });

  test('screens import material and services only when bodies need them', () {
    String screenFor(String kind) {
      final bundle = buildCleanBundle(_singleKindDoc(kind), kTestSources);
      return bundle.files['lib/ui/screens/home_screen.dart']!;
    }

    // Bodies with material-only APIs (Icons/Curves) switch the Flutter
    // import to material (a widgets superset).
    final basic = screenFor('basic');
    expect(basic, contains("import 'package:flutter/material.dart';"));
    expect(basic, isNot(contains("import 'package:flutter/widgets.dart';")));
    expect(basic, contains('const Icon(Icons.person)'));
    // Keyboard shortcuts add the services import for LogicalKeyboardKey.
    final shortcut = screenFor('keyboard_shortcut');
    expect(shortcut, contains("import 'package:flutter/widgets.dart';"));
    expect(shortcut, contains("import 'package:flutter/services.dart';"));
    expect(shortcut, contains('LogicalKeyboardKey.controlLeft'));
    // Plain bodies keep the exact old widgets-only header.
    final badge = screenFor('badge');
    expect(badge, contains("import 'package:flutter/widgets.dart';"));
    expect(badge, isNot(contains('material')));
    expect(badge, isNot(contains('services')));
    expect(badge, isNot(contains('dart:async')));
  });

  test('validated screens carry the async import and validator helper', () {
    final bundle = buildCleanBundle(
      _singleKindDoc('validated'),
      kTestSources,
    );
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains("import 'dart:async';"));
    expect(screen, contains('Validated<String>('));
    expect(
      screen,
      contains("validator: _CanvasRequiredValidator('Required'),"),
    );
    expect(screen, contains('class _CanvasRequiredValidator extends Validator<String>'));
    // Screens without validated fields carry no helper.
    final badgeBundle = buildCleanBundle(_singleKindDoc('badge'), kTestSources);
    expect(
      badgeBundle.files['lib/ui/screens/home_screen.dart']!,
      isNot(contains('_CanvasRequiredValidator')),
    );
  });

  test('screens import a barrel per used catalog kind plus wiring extras', () {
    String screenFor(String kind, [Map<String, dynamic> props = const {}]) {
      final bundle = buildCleanBundle(_singleKindDoc(kind, props), kTestSources);
      return bundle.files['lib/ui/screens/home_screen.dart']!;
    }

    // Direct kind barrel, resolved via the `_barrelFile` map.
    expect(
      screenFor('button'),
      contains("import '../shadcn/components/control/button/button.dart';"),
    );
    // Cross-kind extras: a card footer renders the button barrel's
    // `PrimaryButton`; input bodies render the text-field library's
    // `TextField` (a non-kind library the `input` barrel never re-exports).
    final card = screenFor('card', {'showFooter': true});
    expect(
      card,
      contains("import '../shadcn/components/layout/card/card.dart';"),
    );
    expect(
      card,
      contains("import '../shadcn/components/control/button/button.dart';"),
    );
    expect(card, contains('PrimaryButton('));
    final input = screenFor('input');
    expect(
      input,
      contains("import '../shadcn/components/form/input/input.dart';"),
    );
    expect(
      input,
      contains(
        "import '../shadcn/components/form/text_field/text_field.dart';",
      ),
    );
    expect(input, contains('TextField('));
    // Placeholder kinds reference no kit names: header comment only, no
    // import (so they can never clash with the Flutter SDK).
    final chip = screenFor('chip');
    expect(
      chip,
      contains('// - chip -> lib/ui/shadcn/components/display/chip/chip.dart'),
    );
    expect(chip, isNot(contains("import '../shadcn/")));
    expect(chip, isNot(contains('ignore_for_file')));
  });

  test('screen wiring extras ship their barrels', () {
    // A card-only doc still ships the button barrel its footer renders
    // (requireKind closure, same dependsOn policy as items).
    final card = buildCleanBundle(
      _singleKindDoc('card', {'showFooter': true}),
      kTestSources,
    );
    expect(
      card.files.keys,
      contains('lib/ui/shadcn/components/control/button/button.dart'),
    );
    // Supplemental non-kind files seed emission with manifest entries when
    // the source map carries them.
    final input = buildCleanBundle(_singleKindDoc('input'), kWiringSources);
    expect(
      input.files.keys,
      contains('lib/ui/shadcn/components/form/text_field/text_field.dart'),
    );
    final manifest = jsonDecode(input.manifestJson) as Map<String, dynamic>;
    final dests = {
      for (final f in manifest['files'] as List)
        (f as Map<String, dynamic>)['destination'] as String,
    };
    expect(
      dests,
      contains('lib/ui/shadcn/components/form/text_field/text_field.dart'),
    );
    // Minimal stubs without the supplemental template stay crash-free (the
    // screen still wires the import for real source maps).
    final stub = buildCleanBundle(_singleKindDoc('input'), kTestSources);
    expect(
      stub.files['lib/ui/screens/home_screen.dart']!,
      contains("import '../shadcn/components/form/text_field/text_field.dart';"),
    );
  });

  test('clash kinds disambiguate without private prefixes', () {
    String screenForKinds(List<String> kinds) {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 16.0,
            'y': 96.0,
            'items': [
              for (var i = 0; i < kinds.length; i++)
                {'id': 'i$i', 'kind': kinds[i]},
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'T', 'brief': ''},
      });
      final bundle = buildCleanBundle(doc, kTestSources);
      return bundle.files['lib/ui/screens/home_screen.dart']!;
    }

    // Kit-vs-Flutter: the Flutter names hide, call sites stay bare.
    final table = screenForKinds(['table']);
    expect(
      table,
      contains(
        "import 'package:flutter/widgets.dart' hide Table, TableCell, TableRow;",
      ),
    );
    expect(table, contains('Table('));
    final form = screenForKinds(['form']);
    expect(
      form,
      contains("import 'package:flutter/widgets.dart' hide Form, FormField;"),
    );
    expect(form, contains('Form('));
    expect(
      form,
      contains("import '../shadcn/components/control/button/button.dart';"),
    );
    final radio = screenForKinds(['radio_group']);
    expect(
      radio,
      contains("import 'package:flutter/widgets.dart' hide RadioGroup;"),
    );
    // Material-only names hide only on material screens (hiding them from
    // widgets would warn `undefined_hidden_name`).
    final tipPlain = screenForKinds(['tooltip']);
    expect(tipPlain, contains("import 'package:flutter/widgets.dart';"));
    expect(
      tipPlain,
      contains("import '../shadcn/components/overlay/tooltip/tooltip.dart';"),
    );
    expect(tipPlain, contains('Tooltip('));
    final tip = screenForKinds(['tooltip', 'basic']);
    expect(
      tip,
      contains("import 'package:flutter/material.dart' hide Tooltip;"),
    );
    final alert = screenForKinds(['alert_dialog']);
    expect(
      alert,
      contains("import 'package:flutter/widgets.dart';"),
    );
    final alertMaterial = screenForKinds(['alert_dialog', 'basic']);
    expect(
      alertMaterial,
      contains("import 'package:flutter/material.dart' hide AlertDialog;"),
    );
    final stepper = screenForKinds(['stepper', 'basic']);
    expect(
      stepper,
      contains("import 'package:flutter/material.dart' hide Step, Stepper;"),
    );
    expect(stepper, contains('Stepper('));
    final scaffold = screenForKinds(['scaffold', 'basic']);
    expect(
      scaffold,
      contains("import 'package:flutter/material.dart' hide AppBar, Scaffold;"),
    );
    // Kit-vs-kit tab family: the tabs barrel imports `as tabs` (the canvas
    // catalog's own convention) and its bodies qualify; every other tab
    // barrel stays bare, so no screen can import the same name twice.
    final tabs = screenForKinds(['tabs', 'tab_container', 'tab_list']);
    expect(
      tabs,
      contains(
        "import '../shadcn/components/navigation/tabs/tabs.dart' as tabs;",
      ),
    );
    expect(tabs, contains('tabs.Tabs('));
    expect(tabs, contains('tabs.TabItem('));
    expect(tabs, contains('TabContainer('));
    expect(tabs, contains('tabs.TabList('));
    // Kit-vs-kit menu family: the menu barrel hides its shadowed names
    // (the kit global barrel's own hide list) and renders the popup
    // barrel's `MenuPopup`, mirroring the catalog.
    final menu = screenForKinds(['menu']);
    expect(
      menu,
      contains(
        'hide Menubar, MenubarState, MenubarTheme, MenuPopup, MenuPopupTheme;',
      ),
    );
    expect(
      menu,
      contains("import '../shadcn/components/overlay/popup/popup.dart';"),
    );
    expect(menu, contains('MenuGroup('));
    // Private-prefix imports (`as _x`) are never emitted anywhere.
    for (final kinds in [
      ['table'],
      ['form'],
      ['tooltip', 'basic'],
      ['tabs', 'tab_container'],
      ['menu', 'popup'],
    ]) {
      expect(screenForKinds(kinds), isNot(contains(' as _')));
    }
  });

  test('validated screens wire the same-file validator helper', () {
    final bundle = buildCleanBundle(_singleKindDoc('validated'), kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    // The body references the per-file helper, never a bare `Validator(`.
    expect(screen, contains('validator: _CanvasRequiredValidator('));
    expect(screen, isNot(contains(' Validator(')));
    // ...whose `Validator` base rides the form barrel import.
    expect(
      screen,
      contains("import '../shadcn/components/form/form/form.dart';"),
    );
    expect(
      screen,
      contains('class _CanvasRequiredValidator extends Validator<String>'),
    );
  });

  test('every screen-relative import resolves within the files map', () {
    // Offline proxy for `undefined_identifier`: with stub sources carrying
    // every barrel template, each screen's relative imports must land on an
    // emitted file — for every catalog kind, every placeholder kind, empty
    // screens, and unknown kinds.
    const categories = {
      'button': 'control', 'card': 'layout', 'input': 'form',
      'badge': 'display', 'switch': 'form', 'avatar': 'display',
      'checkbox': 'form', 'divider': 'display', 'progress': 'display',
      'tabs': 'navigation', 'accordion': 'layout', 'select': 'form',
      'radio_group': 'form', 'skeleton': 'display',
      'breadcrumb': 'navigation', 'dialog': 'overlay', 'tooltip': 'overlay',
      'toast': 'overlay', 'drawer': 'overlay', 'chip': 'display',
      'alert': 'layout',
      'circular_progress_indicator': 'display',
      'linear_progress_indicator': 'display', 'triple_dots': 'display',
      'dot_indicator': 'display', 'empty_state': 'display',
      'code_snippet': 'display', 'number_ticker': 'display',
      'text_area': 'form', 'basic': 'layout', 'card_image': 'layout',
      'scaffold': 'layout', 'collapsible': 'layout', 'steps': 'layout',
      'timeline': 'layout', 'outlined_container': 'layout',
      'hidden': 'layout', 'keyboard_shortcut': 'display',
      'tracker': 'display', 'chat': 'display', 'selectable': 'display',
      'star_rating': 'form', 'clickable': 'control', 'scrollbar': 'control',
      'pagination': 'navigation', 'alert_dialog': 'overlay', 'menu': 'overlay',
      'popover': 'overlay', 'popup': 'overlay', 'menubar': 'overlay',
      'dropdown_menu': 'overlay', 'context_menu': 'overlay',
      'hover_card': 'overlay', 'command': 'control', 'swiper': 'overlay',
      'refresh_trigger': 'overlay', 'tab_container': 'navigation',
      'tab_list': 'navigation', 'tab_pane': 'navigation',
      'stepper': 'navigation', 'slider': 'form', 'input_otp': 'form',
      'calendar': 'display', 'date_picker': 'form', 'time_picker': 'form',
      'carousel': 'display', 'tree': 'display', 'table': 'layout',
      'form': 'form', 'form_field': 'form', 'formatted_input': 'form',
      'validated': 'form', 'color_picker': 'form', 'color_input': 'form',
      'hsl': 'form', 'hsv': 'form', 'history': 'form',
      'feature_carousel': 'display',
    };
    const entryFile = {
      'hsl': 'hsl_color_slider.dart',
      'hsv': 'hsv_color_slider.dart',
      'tab_list': '_impl/core/tab_list.dart',
    };
    final stubSources = <String, String>{
      for (final e in categories.entries)
        '{installPath}/components/${e.value}/${e.key}/${entryFile[e.key] ?? '${e.key}.dart'}':
            '',
      '{installPath}/components/form/text_field/text_field.dart': '',
      '{installPath}/components/utility/color/color.dart': '',
    };
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'All', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Empty', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            for (var i = 0; i < categories.keys.length; i++)
              {'id': 'i$i', 'kind': categories.keys.elementAt(i)},
            {'id': 'ix', 'kind': 'not_a_component'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'T', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, stubSources);
    final ref = RegExp(r"""^\s*import\s+'([^']+)'""", multiLine: true);
    var checked = 0;
    for (final entry in bundle.files.entries) {
      if (!entry.key.startsWith('lib/ui/screens/')) continue;
      checked++;
      final dir = entry.key.split('/')..removeLast();
      for (final match in ref.allMatches(entry.value)) {
        final uri = match.group(1)!;
        if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
        var cur = [...dir];
        for (final part in uri.split('/')) {
          if (part.isEmpty || part == '.') continue;
          if (part == '..') {
            cur.removeLast();
          } else {
            cur.add(part);
          }
        }
        expect(
          bundle.files.keys,
          contains(cur.join('/')),
          reason: '${entry.key} -> $uri',
        );
      }
      // No private-prefix imports (see the clash-convention test).
      expect(entry.value, isNot(contains(' as _')));
    }
    expect(checked, 2);
  });

  test('shared closure emits referenced files under shared destinations', () {
    final bundle = buildCleanBundle(_singleKindDoc('button'), kClosureSources);
    // Exact emitted set: the screen plus the kind barrel, its export, its
    // part, the referenced shared files, and the part back-edge pair.
    expect(
      bundle.files.keys.toSet(),
      {
        'lib/ui/screens/home_screen.dart',
        'lib/ui/shadcn/components/control/button/button.dart',
        'lib/ui/shadcn/components/control/button/_impl/core/button_widget.dart',
        'lib/ui/shadcn/components/control/button/_impl/core/button_part.dart',
        'lib/ui/shadcn/shared/extra/extra_lib.dart',
        'lib/ui/shadcn/shared/extra/extra_part.dart',
        'lib/ui/shadcn/shared/theme/theme.dart',
        'lib/ui/shadcn/shared/theme/_impl/core/theme_part.dart',
        'lib/ui/shadcn/shared/utils/constants.dart',
      },
    );
    // Manifest files[] carries the closure files with registry sources.
    final manifest = jsonDecode(bundle.manifestJson) as Map<String, dynamic>;
    final dests = {
      for (final f in manifest['files'] as List)
        (f as Map<String, dynamic>)['destination'] as String,
    };
    expect(
      dests,
      containsAll([
        'lib/ui/shadcn/shared/theme/theme.dart',
        'lib/ui/shadcn/shared/theme/_impl/core/theme_part.dart',
        'lib/ui/shadcn/shared/utils/constants.dart',
      ]),
    );
    final sources = {
      for (final f in manifest['files'] as List)
        (f as Map<String, dynamic>)['source'] as String,
    };
    expect(sources, contains('registry/shared/theme/theme.dart'));
  });

  test('every emitted relative URI resolves within the files map', () {
    final bundle = buildCleanBundle(_singleKindDoc('button'), kClosureSources);
    final ref = RegExp(
      r'''^\s*(?:import|export|part\s+of|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    final unresolved = <String>[];
    for (final entry in bundle.files.entries) {
      final dir = entry.key.split('/')..removeLast();
      for (final match in ref.allMatches(entry.value)) {
        final uri = match.group(1)!;
        if (uri.startsWith('dart:') ||
            uri.startsWith('package:') ||
            uri.startsWith('/')) {
          continue;
        }
        var cur = [...dir];
        var escapes = false;
        for (final part in uri.split('/')) {
          if (part.isEmpty || part == '.') continue;
          if (part == '..') {
            if (cur.isEmpty) {
              escapes = true;
              break;
            }
            cur.removeLast();
          } else {
            cur.add(part);
          }
        }
        if (escapes) continue;
        final target = cur.join('/');
        if (!bundle.files.containsKey(target)) {
          unresolved.add('${entry.key} -> $uri');
        }
      }
    }
    expect(unresolved, isEmpty);
  });

  test('barrels and parts co-emit in both directions', () {
    final bundle = buildCleanBundle(_singleKindDoc('button'), kClosureSources);
    // Library -> part: the barrel's `part` directive pulls the part file.
    expect(
      bundle.files.keys,
      contains('lib/ui/shadcn/components/control/button/_impl/core/button_part.dart'),
    );
    // Shared library -> part: the pulled shared barrel's `part` directive
    // pulls its part too (no orphaned parts).
    expect(
      bundle.files.keys,
      contains('lib/ui/shadcn/shared/theme/_impl/core/theme_part.dart'),
    );
    // Part -> library: the referenced part's `part of` pulls a library no
    // kind prefix and no other body named (it lives outside every prefix).
    expect(
      bundle.files.keys,
      contains('lib/ui/shadcn/shared/extra/extra_lib.dart'),
    );
    expect(
      bundle.files.keys,
      contains('lib/ui/shadcn/shared/extra/extra_part.dart'),
    );
  });

  test('closure skips unresolvable and foreign URIs without crashing', () {
    const sources = {
      '{installPath}/components/control/button/button.dart':
          "import 'dart:async';\n"
          "import 'package:gap/gap.dart';\n"
          "import '/absolute/path.dart';\n"
          "import '../../../../../escape.dart';\n"
          "import '../missing/missing.dart';\n"
          'class Button extends StatelessWidget {}\n',
    };
    final bundle = buildCleanBundle(_singleKindDoc('button'), sources);
    expect(
      bundle.files.keys.toSet(),
      {
        'lib/ui/screens/home_screen.dart',
        'lib/ui/shadcn/components/control/button/button.dart',
      },
    );
  });

  test('pubspec patch covers closure-implied deps', () {
    // `chip` snapshots gap-only in the kit metadata, but its closure ships
    // shared barrels importing data_widget (Track G2 dep extension).
    final chip = buildCleanBundle(_singleKindDoc('chip'), kTestSources);
    expect(chip.pubspecPatch, contains('data_widget'));
    expect(chip.pubspecPatch, contains('gap'));
    // `validated` declares no deps in the kit metadata, but its closure
    // pulls form (email_validator, data_widget, gap) and checkbox
    // (animation_kit) bodies.
    final validated = buildCleanBundle(_singleKindDoc('validated'), const {});
    for (final dep in ['animation_kit', 'data_widget', 'email_validator', 'gap']) {
      expect(validated.pubspecPatch, contains(dep));
    }
    final manifest = jsonDecode(validated.manifestJson) as Map<String, dynamic>;
    final deps =
        (manifest['pubspec'] as Map<String, dynamic>)['dependencies'] as Map;
    expect(deps.keys.toSet(), {'animation_kit', 'data_widget', 'email_validator', 'gap'});
  });

  group('composition recursion (Track C3)', () {
    test('nested card>button splices the child into the card slot', () {
      final screen = _c3bScreen(_c3bDoc(_bCardWithButtonNodes()));
      expect(screen, contains('Card('));
      expect(screen, contains("Text('Go')"));
      final cardIdx = screen.indexOf('Card(');
      final descIdx = screen.indexOf("'Card body'");
      final goIdx = screen.indexOf("'Go'");
      expect(cardIdx, lessThan(descIdx));
      expect(descIdx, lessThan(goIdx));
      expect(screen, contains('const SizedBox(height: 12),'));
    });

    test('nested card>button matches the exact golden', () {
      expect(_c3bScreen(_c3bDoc(_bCardWithButtonNodes())), kBundleNestedCardGolden);
    });

    test('three-deep nesting composes slot inside slot', () {
      final screen = _c3bScreen(_c3bDoc(_bThreeDeepNodes()));
      expect(screen, contains('Card('));
      expect(screen, contains('ModalContainer('));
      expect(screen, contains("Text('Deep')"));
      final cardIdx = screen.indexOf('Card(');
      final dialogIdx = screen.indexOf('ModalContainer(');
      final deepIdx = screen.indexOf("'Deep'");
      expect(cardIdx, lessThan(dialogIdx));
      expect(dialogIdx, lessThan(deepIdx));
    });

    test('three-deep nesting matches the exact golden', () {
      expect(_c3bScreen(_c3bDoc(_bThreeDeepNodes())), kBundleThreeDeepGolden);
    });

    test('card-in-row nests the card inside the Row', () {
      final screen = _c3bScreen(_c3bDoc(_bCardInRowNodes()));
      final rowIdx = screen.indexOf('Row(');
      final cardIdx = screen.indexOf('Card(');
      expect(rowIdx, isNot(-1));
      expect(cardIdx, isNot(-1));
      expect(rowIdx, lessThan(cardIdx));
      expect(screen, contains("Text('Inner')"));
    });

    test('row-in-card nests a horizontal strip inside the card', () {
      final screen = _c3bScreen(_c3bDoc(_bRowInCardNodes()));
      final cardIdx = screen.indexOf('Card(');
      final rowIdx = screen.indexOf('Row(');
      expect(cardIdx, isNot(-1));
      expect(rowIdx, isNot(-1));
      expect(cardIdx, lessThan(rowIdx));
      expect(screen, contains("Text('A')"));
      expect(screen, contains("Text('B')"));
      expect(screen, contains('const SizedBox(width: 8),'));
    });

    test('leaf fallback stacks children below the own widget', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Own'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
          ],
        },
      ]));
      expect(screen, contains('Column('));
      expect(
        screen.indexOf("'Own'"),
        lessThan(screen.indexOf("'Kid'")),
      );
    });

    test('hidden parent prunes the whole subtree', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'hiddenOn': ['mobile', 'tablet', 'desktop'],
          'items': [
            {
              'id': 'i1',
              'kind': 'card',
              'title': 'Gone',
              'description': 'Gone body',
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Buried'},
          ],
        },
      ]));
      expect(screen, contains('const SizedBox.shrink()'));
      expect(screen, isNot(contains('Card(')));
      expect(screen, isNot(contains("'Buried'")));
    });

    test('per-level tier conditionals nest', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'hiddenOn': ['mobile'],
          'items': [
            {
              'id': 'i1',
              'kind': 'card',
              'title': 'T',
              'description': 'D',
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'hiddenOn': ['tablet'],
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
          ],
        },
      ]));
      expect('LayoutBuilder'.allMatches(screen).length, 2);
      expect(screen, contains("tier == 'mobile'"));
      expect(screen, contains("tier == 'tablet'"));
      expect(screen, contains("'Kid'"));
    });

    test('nested tap navigation pushes the route inside the card', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'T',
                'description': 'D',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {
                'id': 'i2',
                'kind': 'button',
                'label': 'Go',
                'action': {'to': 's2', 'transition': 'slide'},
              },
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Nest', 'brief': ''},
      });
      final screen = buildCleanBundle(doc, kTestSources)
          .files['lib/ui/screens/home_screen.dart']!;
      expect(screen, contains('Card('));
      expect(screen, contains("pushNamed('/done')"));
      expect(
        screen.indexOf('Card('),
        lessThan(screen.indexOf('GestureDetector(')),
      );
    });

    test('stateful screen holds fields, binding, and a 3-step action', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'button',
                'label': '=count',
                'action': {
                  'to': 's2',
                  'transition': 'slide',
                  'steps': [
                    {'kind': 'setState', 'variable': 'count', 'value': '1'},
                    {'kind': 'showSnackBar', 'message': 'Saved'},
                    {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
                  ],
                },
              },
            ],
          },
        ],
        'states': [
          {'name': 'count', 'type': 'number', 'default': 0},
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Stateful', 'brief': ''},
      });
      final screen = buildCleanBundle(doc, kTestSources)
          .files['lib/ui/screens/home_screen.dart']!;
      expect(screen, contains('num _count = 0;'));
      expect(screen, contains("Text('\${_count}')"));
      expect(screen, contains('void _onTap_i1(BuildContext context) {'));
      expect(screen, contains('_count = 1;'));
      expect(screen, contains('showSnackBar'));
      expect(screen, contains("pushNamed('/done')"));
      expect(screen, contains('onTap: () => _onTap_i1(context),'));
      expect(
        screen,
        contains(
          "// button '=count' — 3 action steps "
          '(setState count, snackBar, navigate s2).',
        ),
      );
      // SnackBar steps pull the material import even for button-only docs.
      expect(screen, contains("import 'package:flutter/material.dart'"));
    });

    test('legacy bundle screens keep widgets-only headers', () {
      final screen = buildCleanBundle(buildTwoScreenDoc(), kTestSources)
          .files['lib/ui/screens/pay_screen.dart']!;
      expect(screen, contains("import 'package:flutter/widgets.dart';"));
      expect(screen.contains('_onTap'), isFalse);
    });

    test('responsive branch carries the nested subtree', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'breakpointValues': {
            'desktop': {'title': 'Wide'},
          },
          'items': [
            {
              'id': 'i1',
              'kind': 'card',
              'title': 'T',
              'description': 'D',
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
          ],
        },
      ]));
      expect(screen, contains('LayoutBuilder'));
      expect(screen, contains("tier == 'desktop'"));
      // Both the override branch and the default branch carry the child
      // body (each branch also repeats the child's doc comment above it).
      expect("Text('Kid')".allMatches(screen).length, 2);
      expect(screen, contains("'Wide'"));
    });

    test('nested kinds get barrel imports and services wiring', () {
      // A nested-only button still wires its barrel (wiring sees the whole
      // screen, not just roots).
      final card = _c3bScreen(_c3bDoc(_bCardWithButtonNodes()));
      expect(
        card,
        contains("import '../shadcn/components/control/button/button.dart';"),
      );
      expect(
        card,
        contains("import '../shadcn/components/layout/card/card.dart';"),
      );
      // A nested-only keyboard shortcut still pulls the services import.
      final keys = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'card',
              'title': 'T',
              'description': 'D',
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'keyboard_shortcut', 'keys': 'Ctrl+K'},
          ],
        },
      ]));
      expect(keys, contains("import 'package:flutter/services.dart';"));
      expect(keys, contains('LogicalKeyboardKey.controlLeft'));
    });

    test('duplicate-id cycle terminates with a comment', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'card',
              'title': 'T',
              'description': 'D',
            },
          ],
        },
        {
          'id': 'n1',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Loop'},
          ],
        },
      ]));
      expect(screen, contains('cycle: node n1 is its own ancestor (skipped)'));
    });

    test('pure parent cycle terminates without hanging', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'parentId': 'n2',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'A'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'B'},
          ],
        },
      ]));
      expect(screen, contains('// (empty screen).'));
    });

    test('nested export golden: card slots + 3-deep + row-in-card', () {
      final doc = _bNestedExportDoc();
      final screen = _c3bScreen(doc);

      // Barrel wiring covers every nested kind (nested-only kinds still
      // resolve: wiring sees the whole screen, not just roots).
      for (final line in [
        '// - button -> lib/ui/shadcn/components/control/button/button.dart',
        '// - card -> lib/ui/shadcn/components/layout/card/card.dart',
        '// - dialog -> lib/ui/shadcn/components/overlay/dialog/dialog.dart',
        '// - input -> lib/ui/shadcn/components/form/input/input.dart',
        "import '../shadcn/components/control/button/button.dart';",
        "import '../shadcn/components/layout/card/card.dart';",
        "import '../shadcn/components/overlay/dialog/dialog.dart';",
        "import '../shadcn/components/form/input/input.dart';",
      ]) {
        expect(screen, contains(line));
      }

      // Slot splice: the input + button render INSIDE the card chrome after
      // the description (COMPOSITION.md §2 card slot).
      expect(screen, contains('Card('));
      expect(screen, contains('TextField('));
      expect(
        screen.indexOf("'Shop body'"),
        lessThan(screen.indexOf("'Name'")),
      );
      expect(screen.indexOf("'Name'"), lessThan(screen.indexOf("'Go'")));

      // 3-deep: card > dialog > button, each level spliced into its own slot.
      expect(screen, contains('ModalContainer('));
      expect(
        screen.indexOf("'Deep body'"),
        lessThan(screen.indexOf("'Dlg body'")),
      );
      expect(
        screen.indexOf("'Dlg body'"),
        lessThan(screen.indexOf("'Deep Go'")),
      );

      // Row-in-card: a horizontal strip inside the third card (search from
      // the strip card: the dialog above owns its own action Row).
      final stripIdx = screen.indexOf("'Strip body'");
      final rowIdx = screen.indexOf('Row(', stripIdx);
      expect(rowIdx, greaterThan(stripIdx));
      expect(
        screen.indexOf("'A'", rowIdx),
        lessThan(screen.indexOf("'B'", rowIdx)),
      );
      expect(screen, contains('const SizedBox(width: 8),'));

      // Per-level tiers: every responsive level keeps its own wrapper.
      expect('LayoutBuilder'.allMatches(screen).length, 3);
      expect(screen, contains("tier == 'mobile'"));
      expect(screen, contains("tier == 'tablet'"));
      expect(screen, contains("tier == 'desktop'"));
      expect(screen, contains("'Wide Go'"));

      // Per-level taps: depth-1 and depth-2 buttons navigate (the desktop
      // override branch carries its own copy of the depth-2 tap).
      expect("pushNamed('/done')".allMatches(screen).length, 3);
      expect('pushes /done'.allMatches(screen).length, 3);

      // Byte-stability: regeneration is deterministic and pinned.
      expect(_c3bScreen(doc), screen);
      expect(screen, kBundleNestedExportGolden);
    });

    test('nested chat>button splices the child into the bubble slot', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'chat', 'message': 'Hey'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Go'},
          ],
        },
      ]));
      expect(screen, contains('ChatBubble('));
      expect(screen.indexOf("'Hey'"), lessThan(screen.indexOf("'Go'")));
      expect(screen, contains('const SizedBox(height: 12),'));
    });

    test('nested toast>button splices the child after the message', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'toast', 'title': 'TT', 'message': 'TM'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Go'},
          ],
        },
      ]));
      expect(screen, contains('ToastEntry('));
      expect(screen.indexOf("'TM'"), lessThan(screen.indexOf("'Go'")));
      expect(screen, contains('const SizedBox(height: 12),'));
    });

    test('nested validated>button splices the child before the error gap', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'validated',
              'placeholder': 'Name',
              'errorText': 'Req',
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Go'},
          ],
        },
      ]));
      expect(screen, contains('Validated<String>('));
      final goIdx = screen.indexOf("'Go'");
      // 'Req' appears twice: the validator construction, then the error
      // display text — the spliced child sits before the display copy.
      final errIdx = screen.lastIndexOf("'Req'");
      expect(screen.indexOf('child!,'), lessThan(goIdx));
      expect(goIdx, lessThan(errIdx));
    });

    test('nested refresh_trigger>button appends rows after the prop rows', () {
      final screen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'refresh_trigger',
              'item1': 'R1',
              'item2': 'R2',
              'item3': 'R3',
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Go'},
          ],
        },
      ]));
      expect(screen, contains('RefreshTrigger('));
      expect(screen.indexOf("'R3'"), lessThan(screen.indexOf("'Go'")));
      expect(screen, contains('const SizedBox(height: 12),'));
    });

    test('childless D1 containers keep the historical output', () {
      final chat = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'chat', 'message': 'Hi'},
          ],
        },
      ]));
      expect(chat, contains("ChatBubble(child: Text('Hi')),"));
      expect(chat, isNot(contains('const SizedBox(height: 12),')));
      final toast = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'toast', 'title': 'TT', 'message': 'TM'},
          ],
        },
      ]));
      expect(toast, contains('ToastEntry('));
      expect(toast, isNot(contains('const SizedBox(height: 12),')));
      final validated = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'validated',
              'placeholder': 'Name',
              'errorText': 'Req',
            },
          ],
        },
      ]));
      expect(validated, contains('Validated<String>('));
      expect(validated, contains('child!,'));
      expect(validated, isNot(contains('const SizedBox(height: 12),')));
      final refresh = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'refresh_trigger',
              'item1': 'R1',
              'item2': 'R2',
              'item3': 'R3',
            },
          ],
        },
      ]));
      expect(refresh, contains('RefreshTrigger('));
      expect(refresh, isNot(contains('const SizedBox(height: 12),')));
    });

    test('chat tap + responsive interplay nests per level', () {
      final tapDoc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'chat', 'message': 'Hey'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {
                'id': 'i2',
                'kind': 'button',
                'label': 'Go',
                'action': {'to': 's2', 'transition': 'slide'},
              },
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Nest', 'brief': ''},
      });
      final tapScreen = buildCleanBundle(
        tapDoc,
        kTestSources,
      ).files['lib/ui/screens/home_screen.dart']!;
      expect(tapScreen, contains('ChatBubble('));
      expect(tapScreen, contains("pushNamed('/done')"));
      expect(
        tapScreen.indexOf('ChatBubble('),
        lessThan(tapScreen.indexOf('GestureDetector(')),
      );
      final respScreen = _c3bScreen(_c3bDoc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'breakpointValues': {
            'desktop': {'message': 'Wide'},
          },
          'items': [
            {'id': 'i1', 'kind': 'chat', 'message': 'Hey'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'parentId': 'n1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
          ],
        },
      ]));
      expect(respScreen, contains('LayoutBuilder'));
      expect(respScreen, contains("tier == 'desktop'"));
      expect("Text('Kid')".allMatches(respScreen).length, 2);
      expect(respScreen, contains("'Wide'"));
    });
  });

  group('Track X2 fill parity (SizedBox + stretch Column + Expanded-when-h)', () {
    ScreenDoc x2bDoc(List<Map<String, dynamic>> nodes) => ScreenDoc.fromJson({
          'screens': [
            {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          ],
          'nodes': nodes,
          'theme': {
            'paletteKey': 'clean-slate',
            'dark': true,
            'shape': 'rounded',
            'motion': 'standard',
          },
          'meta': {'title': 'Fill', 'brief': ''},
        });

    Map<String, dynamic> x2bLeaf({
      required String id,
      double? w,
      double? h,
    }) => {
          'id': id,
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i$id', 'kind': 'button', 'label': 'Go'},
          ],
          if (w != null) 'w': w,
          if (h != null) 'h': h,
        };

    String x2bScreen(ScreenDoc doc) => buildCleanBundle(doc, const {})
        .files['lib/ui/screens/home_screen.dart']!;

    test('sized w+h emits fill box with stretch Column and Expanded', () {
      final screen = x2bScreen(x2bDoc([x2bLeaf(id: 'n1', w: 120, h: 80)]));
      expect(screen, contains('width: 120,'));
      expect(screen, contains('height: 80,'));
      expect(
        screen,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch,'),
      );
      expect(screen, contains('Expanded('));
      expect(screen, contains('Go'));
      expect(
        screen.indexOf('width: 120,'),
        lessThan(screen.indexOf('CrossAxisAlignment.stretch')),
      );
      expect(
        screen.indexOf('CrossAxisAlignment.stretch'),
        lessThan(screen.indexOf('Expanded(')),
      );
    });

    test('w-only emits stretch without Expanded', () {
      final screen = x2bScreen(x2bDoc([x2bLeaf(id: 'n1', w: 200)]));
      expect(screen, contains('width: 200,'));
      expect(
        screen,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch,'),
      );
      expect(screen, isNot(contains('height:')));
      expect(screen, isNot(contains('Expanded(')));
    });

    test('h-only emits stretch with Expanded', () {
      final screen = x2bScreen(x2bDoc([x2bLeaf(id: 'n1', h: 90)]));
      expect(screen, contains('height: 90,'));
      expect(
        screen,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch,'),
      );
      expect(screen, contains('Expanded('));
    });

    test('unsized docs emit no fill', () {
      final screen = x2bScreen(x2bDoc([x2bLeaf(id: 'n1')]));
      expect(screen, isNot(contains('CrossAxisAlignment.stretch')));
      expect(screen, isNot(contains('Expanded(')));
      expect(screen, isNot(contains('width:')));
    });
  });
}

/// Builds a one-screen doc from [nodes] for the C3 recursion tests.
ScreenDoc _c3bDoc(List<Map<String, dynamic>> nodes) {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': nodes,
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'Nest', 'brief': ''},
  });
}

/// Renders the home screen of [doc] with the shared stub sources.
String _c3bScreen(ScreenDoc doc) =>
    buildCleanBundle(doc, kTestSources).files['lib/ui/screens/home_screen.dart']!;

/// A card root with one button child (the canonical C3 fixture).
List<Map<String, dynamic>> _bCardWithButtonNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {'id': 'i2', 'kind': 'button', 'label': 'Go'},
        ],
      },
    ];

/// Three-deep chain: card > dialog > button.
List<Map<String, dynamic>> _bThreeDeepNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {
            'id': 'i2',
            'kind': 'dialog',
            'title': 'Dlg',
            'message': 'Dlg body',
          },
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {'id': 'i3', 'kind': 'button', 'label': 'Deep'},
        ],
      },
    ];

/// A row root with a card child holding a button (card-in-row).
List<Map<String, dynamic>> _bCardInRowNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {'id': 'i2', 'kind': 'button', 'label': 'Inner'},
        ],
      },
    ];

/// A card root with a row child holding two buttons (row-in-card).
List<Map<String, dynamic>> _bRowInCardNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {'id': 'i3', 'kind': 'button', 'label': 'A'},
        ],
      },
      {
        'id': 'n4',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 48.0,
        'y': 96.0,
        'items': [
          {'id': 'i4', 'kind': 'button', 'label': 'B'},
        ],
      },
    ];

/// Full nested-doc fixture for the Track D3 export golden (mirrors the
/// COMPOSITION.md contract — same shape as the single-file
/// `_nestedExportNodes`): card{input + button→screen} with a per-level
/// mobile tier, a 3-deep card > dialog > button chain with per-level tablet /
/// desktop tiers plus a depth-2 tap, and a row-in-card strip.
List<Map<String, dynamic>> _bNestedExportNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'hiddenOn': ['mobile'],
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'Shop',
            'description': 'Shop body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {
            'id': 'i2',
            'kind': 'input',
            'label': 'Name',
            'placeholder': 'Type here',
          },
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {
            'id': 'i3',
            'kind': 'button',
            'label': 'Go',
            'action': {'to': 's2', 'transition': 'slide'},
          },
        ],
      },
      {
        'id': 'n4',
        'screenId': 's1',
        'x': 0.0,
        'y': 144.0,
        'items': [
          {
            'id': 'i4',
            'kind': 'card',
            'title': 'Deep',
            'description': 'Deep body',
          },
        ],
      },
      {
        'id': 'n5',
        'screenId': 's1',
        'parentId': 'n4',
        'x': 0.0,
        'y': 192.0,
        'hiddenOn': ['tablet'],
        'items': [
          {
            'id': 'i5',
            'kind': 'dialog',
            'title': 'Dlg',
            'message': 'Dlg body',
          },
        ],
      },
      {
        'id': 'n6',
        'screenId': 's1',
        'parentId': 'n5',
        'x': 0.0,
        'y': 240.0,
        'breakpointValues': {
          'desktop': {'label': 'Wide Go'},
        },
        'items': [
          {
            'id': 'i6',
            'kind': 'button',
            'label': 'Deep Go',
            'action': {'to': 's2', 'transition': 'fade'},
          },
        ],
      },
      {
        'id': 'n7',
        'screenId': 's1',
        'x': 0.0,
        'y': 288.0,
        'items': [
          {
            'id': 'i7',
            'kind': 'card',
            'title': 'Strip',
            'description': 'Strip body',
          },
        ],
      },
      {
        'id': 'n8',
        'screenId': 's1',
        'parentId': 'n7',
        'x': 0.0,
        'y': 336.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n9',
        'screenId': 's1',
        'parentId': 'n8',
        'x': 0.0,
        'y': 384.0,
        'items': [
          {'id': 'i9', 'kind': 'button', 'label': 'A'},
        ],
      },
      {
        'id': 'n10',
        'screenId': 's1',
        'parentId': 'n8',
        'x': 48.0,
        'y': 384.0,
        'items': [
          {'id': 'i10', 'kind': 'button', 'label': 'B'},
        ],
      },
    ];

/// Two-screen doc around [_bNestedExportNodes]: `s2` is the tap target for
/// the nested buttons (kept empty so the golden stays focused on `s1`).
ScreenDoc _bNestedExportDoc() {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': _bNestedExportNodes(),
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'Nest', 'brief': ''},
  });
}

/// Stub registry with a shared/part closure: the button barrel exports an
/// impl file, parts a sibling file, imports the shared theme barrel, and
/// reaches a deep shared util plus a part back-edge pair — mirroring the
/// real kit's `{installPath}/shared/…` ≡ `{sharedPath}/…` layout.
const kClosureSources = {
  '{installPath}/components/control/button/button.dart':
      "import '../../../shared/theme/theme.dart';\n"
      "export '_impl/core/button_widget.dart';\n"
      "part '_impl/core/button_part.dart';\n"
      'class Button extends StatelessWidget {}\n',
  '{installPath}/components/control/button/_impl/core/button_widget.dart':
      "import '../../../../../shared/utils/constants.dart';\n"
      "import '../../../../../shared/extra/extra_part.dart';\n"
      'class ButtonWidget extends StatelessWidget {}\n',
  '{installPath}/components/control/button/_impl/core/button_part.dart':
      "part of '../../button.dart';\n"
      'class ButtonPart {}\n',
  '{sharedPath}/extra/extra_lib.dart':
      "part 'extra_part.dart';\n"
      'class ExtraLib {}\n',
  '{sharedPath}/extra/extra_part.dart':
      "part of 'extra_lib.dart';\n"
      'class Extra {}\n',
  '{sharedPath}/theme/theme.dart':
      "part '_impl/core/theme_part.dart';\n"
      'class Theme {}\n',
  '{sharedPath}/theme/_impl/core/theme_part.dart':
      "part of '../../theme.dart';\n"
      'class ThemePart {}\n',
  '{sharedPath}/utils/constants.dart':
      'const kDefaultDuration = Duration(milliseconds: 200);\n',
};

/// Single-kind doc builder for body/barrel spot tests: one screen, one
/// node, one item of [kind] with [props].
ScreenDoc _singleKindDoc(String kind, [Map<String, dynamic> props = const {}]) =>
    ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': kind, ...props},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'T', 'brief': ''},
    });

/// Byte-identical golden for the Track D3 nested export doc
/// ([_bNestedExportNodes]): card{input + button→screen} with a mobile tier,
/// a 3-deep card > dialog > button chain with tablet/desktop tiers plus a
/// depth-2 tap, and a row-in-card strip. Regenerate only by reviewing the
/// exporter diff.
const kBundleNestedExportGolden = '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// ignore_for_file: unused_import
// Screen: Home (id: s1). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
// - button -> lib/ui/shadcn/components/control/button/button.dart
// - card -> lib/ui/shadcn/components/layout/card/card.dart
// - dialog -> lib/ui/shadcn/components/overlay/dialog/dialog.dart
// - input -> lib/ui/shadcn/components/form/input/input.dart
import 'package:flutter/widgets.dart';
import '../shadcn/components/control/button/button.dart';
import '../shadcn/components/layout/card/card.dart';
import '../shadcn/components/overlay/dialog/dialog.dart';
import '../shadcn/components/form/input/input.dart';
import '../shadcn/components/form/text_field/text_field.dart';

/// Home screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      // responsive (hidden on mobile)
      LayoutBuilder(
        builder: (context, constraints) {
          final tier = constraints.maxWidth >= 1024 ? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';
          if (tier == 'mobile') return const SizedBox.shrink();
          // card 'Shop' (description Shop body).
          return Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop'),
                const SizedBox(height: 4),
                Text('Shop body'),
                const SizedBox(height: 12),
                // input 'Name'.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name'),
                    const SizedBox(height: 6),
                    TextField(
                      placeholder: Text('Type here'),
                      enabled: true,
                      obscureText: false,
                      initialValue: null,
                      readOnly: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // button 'Go' — pushes /done (transition: slide).
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/done'), // transition: slide
                  child: PrimaryButton(
                    onPressed: () {},
                    enabled: true,
                    size: ButtonSize.normal,
                    child: Text('Go'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      // card 'Deep' (description Deep body).
      Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deep'),
            const SizedBox(height: 4),
            Text('Deep body'),
            const SizedBox(height: 12),
            // responsive (hidden on tablet)
            LayoutBuilder(
              builder: (context, constraints) {
                final tier = constraints.maxWidth >= 1024 ? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';
                if (tier == 'tablet') return const SizedBox.shrink();
                // dialog 'Dlg' (message Dlg body).
                return ModalContainer(
                  filled: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dlg'),
                      const SizedBox(height: 12),
                      Text('Dlg body'),
                      const SizedBox(height: 12),
                      // responsive (overrides on desktop)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tier = constraints.maxWidth >= 1024 ? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';
                          // button 'Wide Go' — pushes /done (transition: fade).
                          if (tier == 'desktop') return GestureDetector(
                            onTap: () => Navigator.of(context).pushNamed('/done'), // transition: fade
                            child: PrimaryButton(
                              onPressed: () {},
                              enabled: true,
                              size: ButtonSize.normal,
                              child: Text('Wide Go'),
                            ),
                          );
                          // button 'Deep Go' — pushes /done (transition: fade).
                          return GestureDetector(
                            onTap: () => Navigator.of(context).pushNamed('/done'), // transition: fade
                            child: PrimaryButton(
                              onPressed: () {},
                              enabled: true,
                              size: ButtonSize.normal,
                              child: Text('Deep Go'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Spacer(),
                          OutlineButton(
                            onPressed: () {},
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // card 'Strip' (description Strip body).
      Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Strip'),
            const SizedBox(height: 4),
            Text('Strip body'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // button 'A'.
                PrimaryButton(
                  onPressed: () {},
                  enabled: true,
                  size: ButtonSize.normal,
                  child: Text('A'),
                ),
                const SizedBox(width: 8),
                // button 'B'.
                PrimaryButton(
                  onPressed: () {},
                  enabled: true,
                  size: ButtonSize.normal,
                  child: Text('B'),
                ),
              ],
            ),
          ],
        ),
      ),
      ],
    );
  }
}
''';

/// Byte-identical golden for the bundle screen scaffold on a plain doc (no
/// actions, no responsive fields): responsive/action emission must not alter
/// output for such docs. Regenerate only by reviewing the exporter diff.
///
/// Track F3 rewrite (2026-09-05): the old golden pinned `Text('Pay')` for a
/// `button` item — the missing-bodies bug itself (screen files were wiring
/// scaffolds with `Text` placeholders for every known kind). The scaffold,
/// header, and comment shape are unchanged; only the item expression is now
/// the real catalog-mirroring body.
///
/// Track H2 rewrite (2026-09-06): the F3 golden still encoded the
/// missing-wiring bug — the `PrimaryButton`/`ButtonSize` body referenced kit
/// names with no import (`undefined_identifier` under analyze). The scaffold,
/// header, comment, and body shape are unchanged; the file now carries the
/// `unused_import` silence line plus the `button` barrel import.
const kBundleScreenGolden = '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// ignore_for_file: unused_import
// Screen: Home (id: s1). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
// - button -> lib/ui/shadcn/components/control/button/button.dart
import 'package:flutter/widgets.dart';
import '../shadcn/components/control/button/button.dart';

/// Home screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      // button 'Pay' (variant primary).
      PrimaryButton(
        onPressed: () {},
        enabled: true,
        size: ButtonSize.normal,
        child: Text('Pay'),
      ),
      ],
    );
  }
}
''';

/// Byte-identical golden for a known-but-non-catalog kind (`chip` ships
/// bodies under `lib/ui/shadcn/` but has no catalog builder): the screen
/// keeps the explicit doc comment plus the `Text` placeholder, widgets-only
/// import, never a crash. Guards Track F3's "unknown/non-catalog kinds keep
/// the placeholder" rule.
const kBundleNonCatalogGolden = '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// Screen: Home (id: s1). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
// - chip -> lib/ui/shadcn/components/display/chip/chip.dart
import 'package:flutter/widgets.dart';

/// Home screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      // chip 'Hi'.
      Text('Hi'),
      ],
    );
  }
}
''';

/// Byte-identical golden for the canonical C3 fixture: a card root with one
/// button child. The child splices into the card slot (after the
/// description, gap-separated, with its own doc comment); nested kinds keep
/// their barrel comments and imports.
const kBundleNestedCardGolden = '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// ignore_for_file: unused_import
// Screen: Home (id: s1). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
// - button -> lib/ui/shadcn/components/control/button/button.dart
// - card -> lib/ui/shadcn/components/layout/card/card.dart
import 'package:flutter/widgets.dart';
import '../shadcn/components/control/button/button.dart';
import '../shadcn/components/layout/card/card.dart';

/// Home screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      // card 'T' (description Card body).
      Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('T'),
            const SizedBox(height: 4),
            Text('Card body'),
            const SizedBox(height: 12),
            // button 'Go'.
            PrimaryButton(
              onPressed: () {},
              enabled: true,
              size: ButtonSize.normal,
              child: Text('Go'),
            ),
          ],
        ),
      ),
      ],
    );
  }
}
''';

/// Byte-identical golden for three-deep nesting (card > dialog > button):
/// each level splices into its own slot — the dialog (with its default
/// action row) lands inside the card slot, the button inside the dialog
/// slot after the message.
const kBundleThreeDeepGolden = '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// ignore_for_file: unused_import
// Screen: Home (id: s1). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
// - button -> lib/ui/shadcn/components/control/button/button.dart
// - card -> lib/ui/shadcn/components/layout/card/card.dart
// - dialog -> lib/ui/shadcn/components/overlay/dialog/dialog.dart
import 'package:flutter/widgets.dart';
import '../shadcn/components/control/button/button.dart';
import '../shadcn/components/layout/card/card.dart';
import '../shadcn/components/overlay/dialog/dialog.dart';

/// Home screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      // card 'T' (description Card body).
      Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('T'),
            const SizedBox(height: 4),
            Text('Card body'),
            const SizedBox(height: 12),
            // dialog 'Dlg' (message Dlg body).
            ModalContainer(
              filled: true,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dlg'),
                  const SizedBox(height: 12),
                  Text('Dlg body'),
                  const SizedBox(height: 12),
                  // button 'Deep'.
                  PrimaryButton(
                    onPressed: () {},
                    enabled: true,
                    size: ButtonSize.normal,
                    child: Text('Deep'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Spacer(),
                      OutlineButton(
                        onPressed: () {},
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ],
    );
  }
}
''';
