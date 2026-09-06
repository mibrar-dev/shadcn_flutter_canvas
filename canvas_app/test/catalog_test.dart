import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog seeds five entries with labels and defaults', () {
    expect(
      kCatalog.map((e) => e.kind),
      containsAll([
        'button',
        'card',
        'input',
        'badge',
        'switch',
        'accordion',
        'select',
        'radio_group',
        'skeleton',
        'breadcrumb',
        'dialog',
        'tooltip',
        'toast',
        'drawer',
        // Track J additions (2026-09-05).
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
        // Track M additions (2026-09-05).
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
        // Track P additions (2026-09-05).
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
        // Track Y1 addition (2026-09-06).
        'navigation_bar',
        // Track FF2 additions (2026-09-06): placeholder blitz — the
        // form/input family plus the bare-capable display/layout/utility
        // batch (28 kinds).
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
      ]),
    );
    expect(kCatalog, hasLength(97));
    for (final entry in kCatalog) {
      expect(entry.label, isNotEmpty, reason: '${entry.kind} label');
      expect(entry.defaults, isNotEmpty, reason: '${entry.kind} defaults');
    }
    expect(findEntry('button'), isNotNull);
    expect(findEntry('nope'), isNull);
  });

  test('button defaults mirror plan Task 3 JSON', () {
    expect(findEntry('button')!.defaults, {
      'label': 'Button',
      'variant': 'primary',
      'size': 'md',
      'disabled': false,
    });
  });

  test('button builder maps variants to real widgets', () {
    // Track Z2 beauty cause: the builder now returns a min-height (48px)
    // ConstrainedBox shell over the variant button (childless shape change,
    // expected this track). Wiring assertions unwrap exactly one level, so
    // every variant mapping stays pinned.
    void expectVariant(String variant, Type type) {
      final built = buildCatalogItem('button', {
        'label': 'Go',
        'size': 'md',
        'disabled': false,
        'variant': variant,
      });
      expect(built, isA<ConstrainedBox>(), reason: 'Z2 48px shell ($variant)');
      expect(
        (built as ConstrainedBox).child.runtimeType,
        type,
        reason: 'variant wiring ($variant)',
      );
      expect(
        built.constraints.minHeight,
        48,
        reason: 'Z2 touch target ($variant)',
      );
    }

    expectVariant('primary', shadcn.PrimaryButton);
    expectVariant('secondary', shadcn.SecondaryButton);
    expectVariant('outline', shadcn.OutlineButton);
    expectVariant('ghost', shadcn.GhostButton);
    expectVariant('destructive', shadcn.DestructiveButton);
    expectVariant('link', shadcn.LinkButton);
    expectVariant('text', shadcn.TextButton);
    // Unknown variants fall back to primary, never crash.
    expectVariant('bogus', shadcn.PrimaryButton);
  });

  testWidgets('button renders label for every variant', (tester) async {
    for (final variant in [
      'primary',
      'secondary',
      'outline',
      'ghost',
      'destructive',
      'link',
      'text',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('button', {
              'label': 'Go',
              'variant': variant,
              'size': 'md',
              'disabled': false,
            }),
          ),
        ),
      );
      expect(find.text('Go'), findsOneWidget);
    }
  });

  testWidgets('card renders title, description, and optional footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('card', {
            'title': 'T',
            'description': 'D',
            'showFooter': true,
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.Card), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildCatalogItem('card', {'showFooter': false})),
      ),
    );
    expect(find.text('Action'), findsNothing);
  });

  testWidgets('input renders placeholder and optional label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('input', {
            'placeholder': 'Type here',
            'label': 'Email',
            'disabled': false,
            'obscure': false,
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.TextField), findsOneWidget);
    expect(find.text('Type here'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('badge renders every style', (tester) async {
    const styles = {
      'primary': shadcn.PrimaryBadge,
      'secondary': shadcn.SecondaryBadge,
      'destructive': shadcn.DestructiveBadge,
      'outline': shadcn.OutlineBadge,
    };
    for (final style in styles.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('badge', {
              'label': 'New',
              'variant': style.key,
            }),
          ),
        ),
      );
      expect(find.byType(style.value), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    }
  });

  testWidgets('switch renders and toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildCatalogItem('switch', {'value': false})),
      ),
    );
    expect(find.byType(shadcn.Switch), findsOneWidget);
    await tester.tap(find.byType(shadcn.Switch));
    await tester.pump();
    expect(tester.widget<shadcn.Switch>(find.byType(shadcn.Switch)).value, isTrue);
  });

  testWidgets('builders tolerate empty props (defaults kick in)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              buildCatalogItem('button', {}),
              buildCatalogItem('input', {}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Type here'), findsOneWidget);
  });

  testWidgets('dialog renders content card with optional action row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('dialog', {
            'title': 'T',
            'message': 'M',
            'showActions': true,
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.ModalContainer), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildCatalogItem('dialog', {'showActions': false})),
      ),
    );
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('tooltip renders the labeled control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('tooltip', {
            'label': 'Hover me',
            'tip': 'Helpful context',
          }),
        ),
      ),
    );
    // The tip only materializes on hover at runtime; canvas shows the
    // labeled control.
    expect(find.byType(shadcn.Tooltip), findsOneWidget);
    expect(find.text('Hover me'), findsOneWidget);
  });

  testWidgets('toast renders the notification row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('toast', {
            'title': 'Saved',
            'message': 'Saved successfully',
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.ToastEntry), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Saved successfully'), findsOneWidget);
  });

  testWidgets('drawer renders the side-panel mock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('drawer', {
            'title': 'Drawer',
            'content': 'Drawer content',
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.DrawerWrapper), findsOneWidget);
    expect(find.text('Drawer'), findsOneWidget);
    expect(find.text('Drawer content'), findsOneWidget);
  });

  testWidgets('overlay builders tolerate empty props (defaults kick in)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              buildCatalogItem('dialog', {}),
              buildCatalogItem('tooltip', {}),
              buildCatalogItem('toast', {}),
              buildCatalogItem('drawer', {}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Dialog title'), findsOneWidget);
    expect(find.text('Hover me'), findsOneWidget);
    expect(find.text('Saved successfully'), findsOneWidget);
    expect(find.text('Drawer content'), findsOneWidget);
  });

  testWidgets('fallbackBuilder renders placeholder plus kind label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildCatalogItem('mystery', {}))),
    );
    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.text('unknown: mystery'), findsOneWidget);
  });

  group('catalog defaults validate against block propsSchema', () {
    for (final entry in kCatalog) {
      test('${entry.kind} defaults exist in schema with matching types', () {
        final schema = kBlockSchemas[entry.kind];
        expect(schema, isNotNull, reason: 'no schema copy for ${entry.kind}');
        for (final defaultProp in entry.defaults.entries) {
          final prop = schema!.where((p) => p['name'] == defaultProp.key);
          expect(prop, hasLength(1), reason: '${entry.kind}.${defaultProp.key}');
          final type = prop.single['type'] as String;
          final value = defaultProp.value;
          switch (type) {
            case 'bool':
              expect(value, isA<bool>(), reason: '${entry.kind}.${defaultProp.key}');
            case 'string':
              expect(value, isA<String>(), reason: '${entry.kind}.${defaultProp.key}');
            case 'enum':
              final options = prop.single['enum'] as List<String>;
              expect(value, isA<String>(), reason: '${entry.kind}.${defaultProp.key}');
              expect(
                options,
                contains(value),
                reason: '${entry.kind}.${defaultProp.key} default not in $options',
              );
            case 'double':
              expect(value, isA<double>(), reason: '${entry.kind}.${defaultProp.key}');
            case 'int':
              expect(value, isA<int>(), reason: '${entry.kind}.${defaultProp.key}');
            default:
              fail('unknown schema type $type for ${entry.kind}.${defaultProp.key}');
          }
          // Shared keys must agree on the default value (block is the source
          // of truth for canvas-level content props).
          expect(
            value,
            prop.single['default'],
            reason: '${entry.kind}.${defaultProp.key} default drifted from block',
          );
        }
      });
    }

    test('switch intentionally omits the block-only label prop', () {
      // The switch canvas block declares a `label` prop, but `Switch` takes
      // no label (only `leading`/`trailing`) — reported as a follow-up
      // blocks finding, so the catalog stays constructor-true here.
      expect(findEntry('switch')!.defaults, {'value': false, 'disabled': false});
      expect(
        kBlockSchemas['switch']!.map((p) => p['name']),
        contains('label'),
      );
    });
  });
}

/// Compact copy of the canvas blocks' `propsSchema` for the nineteen catalog
/// kinds, transcribed from
/// `shadcn_flutter_kit/flutter_shadcn_kit/lib/registry/manifests/components.json`
/// (`components[].canvas.propsSchema`).
///
/// Tests cannot read kit files (the kit package is not a dependency of
/// canvas_app), so this copy is hard-coded — re-transcribe it if
/// `components.json` changes. The fourteen newer kinds have no canvas block in
/// the pinned kit rev; their copies mirror the invented catalog defaults
/// (marked inline) until real blocks land.
const Map<String, List<Map<String, Object?>>> kBlockSchemas = {
  'button': [
    {'name': 'label', 'type': 'string', 'default': 'Button'},
    {
      'name': 'variant',
      'type': 'enum',
      'enum': ['primary', 'secondary', 'outline', 'ghost', 'destructive', 'link'],
      'default': 'primary',
    },
    {
      'name': 'size',
      'type': 'enum',
      'enum': ['sm', 'md', 'lg', 'icon'],
      'default': 'md',
    },
    {'name': 'disabled', 'type': 'bool', 'default': false},
  ],
  'card': [
    {'name': 'title', 'type': 'string', 'default': 'Title'},
    {'name': 'description', 'type': 'string', 'default': 'Description'},
    {'name': 'showFooter', 'type': 'bool', 'default': false},
  ],
  'input': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Type here'},
    {'name': 'label', 'type': 'string', 'default': ''},
    // Track M: `initialValue`/`readOnly` promoted from spec-only into wired
    // builder props (mirrors the catalog defaults).
    {'name': 'initialValue', 'type': 'string', 'default': ''},
    {'name': 'disabled', 'type': 'bool', 'default': false},
    {'name': 'obscure', 'type': 'bool', 'default': false},
    {'name': 'readOnly', 'type': 'bool', 'default': false},
  ],
  'badge': [
    {'name': 'label', 'type': 'string', 'default': 'Badge'},
    {
      'name': 'variant',
      'type': 'enum',
      'enum': ['primary', 'secondary', 'outline', 'destructive'],
      'default': 'primary',
    },
  ],
  'switch': [
    {'name': 'label', 'type': 'string', 'default': ''},
    {'name': 'value', 'type': 'bool', 'default': false},
    {'name': 'disabled', 'type': 'bool', 'default': false},
  ],
  // No canvas blocks exist for these five kinds in the pinned kit rev, so
  // these copies mirror the (documented, invented) catalog defaults instead
  // of a block transcription. If real blocks land, re-transcribe and the
  // drift assertions above will flag any divergence for review.
  'avatar': [
    {'name': 'initials', 'type': 'string', 'default': 'AB'},
    // Track M: `size` promoted from spec-only into a wired builder prop.
    {'name': 'size', 'type': 'double', 'default': 40.0},
  ],
  'checkbox': [
    {'name': 'value', 'type': 'bool', 'default': false},
    {'name': 'disabled', 'type': 'bool', 'default': false},
    // Track M: `tristate` promoted from spec-only into a wired builder prop.
    {'name': 'tristate', 'type': 'bool', 'default': false},
  ],
  'divider': [
    {'name': 'label', 'type': 'string', 'default': ''},
    // Track M: `thickness` promoted from spec-only into a wired builder prop.
    {'name': 'thickness', 'type': 'double', 'default': 1.0},
  ],
  'progress': [
    {'name': 'progress', 'type': 'double', 'default': 0.5},
  ],
  'tabs': [
    {'name': 'tab1', 'type': 'string', 'default': 'Tab 1'},
    {'name': 'tab2', 'type': 'string', 'default': 'Tab 2'},
    {'name': 'index', 'type': 'int', 'default': 0},
    // Track M: `expand` promoted from spec-only into a wired builder prop.
    {'name': 'expand', 'type': 'bool', 'default': false},
  ],
  // No canvas blocks exist for these five kinds either (same pinned-kit
  // scan — no `canvas` key on any of the 134 components), so these copies
  // likewise mirror the invented catalog defaults until real blocks land.
  'accordion': [
    {'name': 'title', 'type': 'string', 'default': 'Section 1'},
    {'name': 'content', 'type': 'string', 'default': 'Content 1'},
    {'name': 'expanded', 'type': 'bool', 'default': false},
  ],
  'select': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Select an option'},
    {'name': 'option1', 'type': 'string', 'default': 'Option 1'},
    {'name': 'option2', 'type': 'string', 'default': 'Option 2'},
    {'name': 'value', 'type': 'string', 'default': ''},
    // Track M: `disabled` promoted from spec-only into a wired builder prop.
    {'name': 'disabled', 'type': 'bool', 'default': false},
  ],
  'radio_group': [
    {'name': 'option1', 'type': 'string', 'default': 'Option 1'},
    {'name': 'option2', 'type': 'string', 'default': 'Option 2'},
    {'name': 'value', 'type': 'string', 'default': 'Option 1'},
    // Track M: `disabled` promoted from spec-only into a wired builder prop.
    {'name': 'disabled', 'type': 'bool', 'default': false},
  ],
  'skeleton': [
    {'name': 'label', 'type': 'string', 'default': 'Loading'},
    {'name': 'enabled', 'type': 'bool', 'default': true},
  ],
  'breadcrumb': [
    {'name': 'home', 'type': 'string', 'default': 'Home'},
    {'name': 'current', 'type': 'string', 'default': 'Page'},
    // Track M: `separator` promoted from spec-only into a wired builder prop.
    {
      'name': 'separator',
      'type': 'enum',
      'enum': ['arrow', 'slash'],
      'default': 'arrow',
    },
  ],
  // No canvas blocks exist for these four kinds either (same pinned-kit
  // scan — no `canvas` key on any of the 134 components), so these copies
  // likewise mirror the invented catalog defaults until real blocks land.
  'dialog': [
    {'name': 'title', 'type': 'string', 'default': 'Dialog title'},
    {
      'name': 'message',
      'type': 'string',
      'default': 'Use dialogs for important confirmations.',
    },
    {'name': 'showActions', 'type': 'bool', 'default': true},
  ],
  'tooltip': [
    {'name': 'label', 'type': 'string', 'default': 'Hover me'},
    {'name': 'tip', 'type': 'string', 'default': 'Helpful context'},
  ],
  'toast': [
    {'name': 'title', 'type': 'string', 'default': 'Saved'},
    {'name': 'message', 'type': 'string', 'default': 'Saved successfully'},
    // Track M: `autoDismiss` promoted from spec-only into a wired prop.
    {'name': 'autoDismiss', 'type': 'bool', 'default': false},
  ],
  'drawer': [
    {'name': 'title', 'type': 'string', 'default': 'Drawer'},
    {'name': 'content', 'type': 'string', 'default': 'Drawer content'},
    // Track M: `position` promoted from spec-only into a wired builder prop.
    {
      'name': 'position',
      'type': 'enum',
      'enum': ['left', 'right', 'top', 'bottom', 'start', 'end'],
      'default': 'end',
    },
  ],
  // No canvas blocks exist for these seventeen kinds either (same pinned-kit
  // scan — no `canvas` key on any of the 134 components), so these copies
  // likewise mirror the invented catalog defaults until real blocks land.
  // (Track J additions, 2026-09-05.)
  'basic': [
    {'name': 'title', 'type': 'string', 'default': 'Title'},
    {'name': 'subtitle', 'type': 'string', 'default': 'Subtitle'},
    {'name': 'content', 'type': 'string', 'default': 'Content'},
    {'name': 'showLeading', 'type': 'bool', 'default': true},
    {'name': 'showTrailing', 'type': 'bool', 'default': true},
  ],
  'card_image': [
    {'name': 'title', 'type': 'string', 'default': 'Card title'},
    {'name': 'subtitle', 'type': 'string', 'default': 'Card subtitle'},
  ],
  'scaffold': [
    {'name': 'title', 'type': 'string', 'default': 'My App'},
    {'name': 'body', 'type': 'string', 'default': 'Welcome'},
  ],
  'collapsible': [
    {'name': 'trigger', 'type': 'string', 'default': 'Show more'},
    {'name': 'content', 'type': 'string', 'default': 'Hidden details'},
    {'name': 'expanded', 'type': 'bool', 'default': false},
  ],
  'steps': [
    {'name': 'step1', 'type': 'string', 'default': 'Step 1'},
    {'name': 'detail1', 'type': 'string', 'default': 'First step details'},
    {'name': 'step2', 'type': 'string', 'default': 'Step 2'},
    {'name': 'detail2', 'type': 'string', 'default': 'Second step details'},
  ],
  'timeline': [
    {'name': 'time1', 'type': 'string', 'default': '9:00 AM'},
    {'name': 'title1', 'type': 'string', 'default': 'Kickoff'},
    {'name': 'detail1', 'type': 'string', 'default': 'Project kickoff meeting'},
    {'name': 'time2', 'type': 'string', 'default': '2:00 PM'},
    {'name': 'title2', 'type': 'string', 'default': 'Review'},
    {'name': 'detail2', 'type': 'string', 'default': 'Design review session'},
  ],
  'outlined_container': [
    {'name': 'label', 'type': 'string', 'default': 'Outlined'},
  ],
  'hidden': [
    {'name': 'label', 'type': 'string', 'default': 'Hidden content'},
    {'name': 'hidden', 'type': 'bool', 'default': false},
  ],
  'keyboard_shortcut': [
    {'name': 'keys', 'type': 'string', 'default': 'Ctrl+K'},
  ],
  'tracker': [
    {'name': 'segments', 'type': 'int', 'default': 3},
    {
      'name': 'level',
      'type': 'enum',
      'enum': ['fine', 'warning', 'critical', 'unknown'],
      'default': 'fine',
    },
  ],
  'chat': [
    {'name': 'message', 'type': 'string', 'default': 'Hello!'},
  ],
  'selectable': [
    {'name': 'text', 'type': 'string', 'default': 'Select me'},
  ],
  'star_rating': [
    {'name': 'value', 'type': 'double', 'default': 3.0},
    {'name': 'max', 'type': 'double', 'default': 5.0},
  ],
  'clickable': [
    {'name': 'label', 'type': 'string', 'default': 'Tap me'},
  ],
  'scrollbar': [
    {'name': 'label', 'type': 'string', 'default': 'Scrollable content'},
  ],
  'pagination': [
    {'name': 'page', 'type': 'int', 'default': 1},
    {'name': 'totalPages', 'type': 'int', 'default': 5},
  ],
  'alert_dialog': [
    {'name': 'title', 'type': 'string', 'default': 'Are you sure?'},
    {
      'name': 'message',
      'type': 'string',
      'default': 'This action cannot be undone.',
    },
    {'name': 'showActions', 'type': 'bool', 'default': true},
  ],
  // No canvas blocks exist for these fifteen kinds either (same pinned-kit
  // scan — no `canvas` key on any of the 134 components), so these copies
  // likewise mirror the invented catalog defaults until real blocks land.
  // (Track M additions, 2026-09-05.)
  'menu': [
    {'name': 'heading', 'type': 'string', 'default': 'File'},
    {'name': 'item1', 'type': 'string', 'default': 'New'},
    {'name': 'item2', 'type': 'string', 'default': 'Open'},
  ],
  'popover': [
    {'name': 'trigger', 'type': 'string', 'default': 'Open Popover'},
    {'name': 'title', 'type': 'string', 'default': 'Popover title'},
    {
      'name': 'body',
      'type': 'string',
      'default': 'Use popovers for contextual helper content.',
    },
  ],
  'popup': [
    {'name': 'item1', 'type': 'string', 'default': 'Profile'},
    {'name': 'item2', 'type': 'string', 'default': 'Settings'},
    {'name': 'item3', 'type': 'string', 'default': 'Sign out'},
  ],
  'menubar': [
    {'name': 'menu1', 'type': 'string', 'default': 'File'},
    {'name': 'menu2', 'type': 'string', 'default': 'Edit'},
  ],
  'dropdown_menu': [
    {'name': 'heading', 'type': 'string', 'default': 'My Account'},
    {'name': 'item1', 'type': 'string', 'default': 'Profile'},
    {'name': 'item2', 'type': 'string', 'default': 'Settings'},
  ],
  'context_menu': [
    {'name': 'hint', 'type': 'string', 'default': 'Right-click me'},
    {'name': 'item1', 'type': 'string', 'default': 'Back'},
    {'name': 'item2', 'type': 'string', 'default': 'Reload'},
  ],
  'hover_card': [
    {'name': 'handle', 'type': 'string', 'default': 'Hover card'},
    {'name': 'title', 'type': 'string', 'default': 'Hover title'},
    {'name': 'body', 'type': 'string', 'default': 'Rich preview content.'},
  ],
  'command': [
    {'name': 'hint', 'type': 'string', 'default': 'Search commands...'},
    {'name': 'item1', 'type': 'string', 'default': 'Calendar'},
    {'name': 'item2', 'type': 'string', 'default': 'Settings'},
  ],
  'swiper': [
    {'name': 'hint', 'type': 'string', 'default': 'Swipe up from the bottom'},
    {'name': 'content', 'type': 'string', 'default': 'Swipe content'},
  ],
  'refresh_trigger': [
    {'name': 'item1', 'type': 'string', 'default': 'Row 1'},
    {'name': 'item2', 'type': 'string', 'default': 'Row 2'},
    {'name': 'item3', 'type': 'string', 'default': 'Row 3'},
  ],
  'tab_container': [
    {'name': 'tab1', 'type': 'string', 'default': 'Overview'},
    {'name': 'tab2', 'type': 'string', 'default': 'Details'},
    {'name': 'tab3', 'type': 'string', 'default': 'Reviews'},
    {'name': 'index', 'type': 'int', 'default': 0},
  ],
  'tab_list': [
    {'name': 'tab1', 'type': 'string', 'default': 'Tab 1'},
    {'name': 'tab2', 'type': 'string', 'default': 'Tab 2'},
    {'name': 'index', 'type': 'int', 'default': 0},
  ],
  'tab_pane': [
    {'name': 'tab1', 'type': 'string', 'default': 'Overview'},
    {'name': 'tab2', 'type': 'string', 'default': 'Analytics'},
    {'name': 'tab3', 'type': 'string', 'default': 'Settings'},
    {'name': 'focused', 'type': 'int', 'default': 0},
  ],
  'stepper': [
    {'name': 'step1', 'type': 'string', 'default': 'Details'},
    {'name': 'detail1', 'type': 'string', 'default': 'Provide your details.'},
    {'name': 'step2', 'type': 'string', 'default': 'Payment'},
    {
      'name': 'detail2',
      'type': 'string',
      'default': 'Choose a payment method.',
    },
    {'name': 'step3', 'type': 'string', 'default': 'Confirm'},
    {'name': 'detail3', 'type': 'string', 'default': 'Review and submit.'},
    {'name': 'step', 'type': 'int', 'default': 0},
  ],
  'slider': [
    {'name': 'value', 'type': 'double', 'default': 0.6},
  ],
  // No canvas blocks exist for these seventeen kinds either (same pinned-kit
  // scan — no `canvas` key on any of the 134 components), so these copies
  // likewise mirror the invented catalog defaults until real blocks land.
  // (Track P additions, 2026-09-05.)
  'input_otp': [
    {'name': 'length', 'type': 'int', 'default': 6},
  ],
  'calendar': [
    {
      'name': 'mode',
      'type': 'enum',
      'enum': ['single', 'range', 'multi', 'none'],
      'default': 'single',
    },
  ],
  'date_picker': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Select date'},
    {'name': 'label', 'type': 'string', 'default': ''},
  ],
  'time_picker': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Select time'},
    {'name': 'label', 'type': 'string', 'default': ''},
  ],
  'carousel': [
    {'name': 'slides', 'type': 'int', 'default': 3},
  ],
  'tree': [
    {'name': 'node1', 'type': 'string', 'default': 'Design'},
    {'name': 'child1', 'type': 'string', 'default': 'Research'},
    {'name': 'child2', 'type': 'string', 'default': 'Wireframes'},
    {'name': 'node2', 'type': 'string', 'default': 'Launch'},
  ],
  'table': [
    {'name': 'header1', 'type': 'string', 'default': 'Name'},
    {'name': 'header2', 'type': 'string', 'default': 'Role'},
    {'name': 'name1', 'type': 'string', 'default': 'Avery'},
    {'name': 'role1', 'type': 'string', 'default': 'Designer'},
    {'name': 'name2', 'type': 'string', 'default': 'Jordan'},
    {'name': 'role2', 'type': 'string', 'default': 'Engineer'},
  ],
  'form': [
    {'name': 'label', 'type': 'string', 'default': 'Name'},
    {'name': 'placeholder', 'type': 'string', 'default': 'Jane Doe'},
    {'name': 'submitLabel', 'type': 'string', 'default': 'Submit'},
  ],
  'form_field': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Select item'},
    {'name': 'value', 'type': 'string', 'default': ''},
  ],
  'formatted_input': [
    {'name': 'label', 'type': 'string', 'default': ''},
  ],
  'validated': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Name'},
    {'name': 'errorText', 'type': 'string', 'default': 'Required'},
  ],
  'color_picker': [
    {'name': 'hex', 'type': 'string', 'default': '#2196F3'},
  ],
  'color_input': [
    {'name': 'hex', 'type': 'string', 'default': '#2196F3'},
  ],
  'hsl': [
    {
      'name': 'mode',
      'type': 'enum',
      'enum': ['hue', 'sat', 'lum', 'alpha'],
      'default': 'hue',
    },
  ],
  'hsv': [
    {
      'name': 'mode',
      'type': 'enum',
      'enum': ['hue', 'sat', 'val', 'alpha'],
      'default': 'hue',
    },
  ],
  'history': [
    {'name': 'columns', 'type': 'int', 'default': 6},
  ],
  'feature_carousel': [
    {'name': 'title1', 'type': 'string', 'default': 'Palette Selector'},
    {
      'name': 'description1',
      'type': 'string',
      'default': 'Pick a palette to refine results.',
    },
    {'name': 'title2', 'type': 'string', 'default': 'Style Presets'},
    {
      'name': 'description2',
      'type': 'string',
      'default': 'Choose a curated style preset.',
    },
  ],
  // No canvas block exists for this kind either (same pinned-kit scan — no
  // `canvas` key on any of the 134 components), so this copy likewise
  // mirrors the invented catalog defaults until a real block lands.
  // (Track Y1 addition, 2026-09-06.)
  'navigation_bar': [
    {'name': 'tab1', 'type': 'string', 'default': 'Home'},
    {'name': 'tab2', 'type': 'string', 'default': 'Search'},
    {'name': 'tab3', 'type': 'string', 'default': 'Saved'},
    {'name': 'tab4', 'type': 'string', 'default': 'You'},
    {'name': 'index', 'type': 'int', 'default': 0},
  ],
  // No canvas blocks exist for these 28 kinds either (same pinned-kit scan —
  // no `canvas` key on any of the 134 components), so these copies likewise
  // mirror the invented catalog defaults until real blocks land.
  // (Track FF2 addition, 2026-09-06.)
  'phone_input': [
    {'name': 'label', 'type': 'string', 'default': ''},
    {'name': 'searchHint', 'type': 'string', 'default': 'Search countries...'},
  ],
  'chip_input': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Add a tag'},
    {'name': 'chip1', 'type': 'string', 'default': 'Design'},
    {'name': 'chip2', 'type': 'string', 'default': ''},
  ],
  'autocomplete': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Search...'},
    {'name': 'suggestion1', 'type': 'string', 'default': 'Apple'},
    {'name': 'suggestion2', 'type': 'string', 'default': 'Apricot'},
  ],
  'item_picker': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Select item'},
    {'name': 'option1', 'type': 'string', 'default': 'Option 1'},
    {'name': 'option2', 'type': 'string', 'default': 'Option 2'},
    {'name': 'value', 'type': 'string', 'default': ''},
  ],
  'multiple_choice': [
    {
      'name': 'mode',
      'type': 'enum',
      'enum': ['single', 'multiple'],
      'default': 'single',
    },
    {'name': 'option1', 'type': 'string', 'default': 'Option A'},
    {'name': 'option2', 'type': 'string', 'default': 'Option B'},
    {'name': 'option3', 'type': 'string', 'default': 'Option C'},
    {'name': 'value', 'type': 'string', 'default': 'Option A'},
    {'name': 'value2', 'type': 'string', 'default': 'Option B'},
  ],
  'object_input': [
    {
      'name': 'mode',
      'type': 'enum',
      'enum': ['date', 'time', 'duration'],
      'default': 'date',
    },
    {'name': 'placeholder', 'type': 'string', 'default': 'Select value'},
    {'name': 'label', 'type': 'string', 'default': ''},
  ],
  'text_field': [
    {'name': 'placeholder', 'type': 'string', 'default': 'Type here'},
    {'name': 'label', 'type': 'string', 'default': ''},
    {'name': 'disabled', 'type': 'bool', 'default': false},
    {'name': 'initialValue', 'type': 'string', 'default': ''},
  ],
  'markdown': [
    {'name': 'data', 'type': 'string', 'default': '# Title\n\nSome **rich** text.'},
  ],
  'text_animate': [
    {'name': 'text', 'type': 'string', 'default': 'Watch the words appear.'},
  ],
  'icon': [
    {
      'name': 'name',
      'type': 'enum',
      'enum': [
        'star',
        'heart',
        'home',
        'search',
        'settings',
        'check',
        'info',
        'image',
      ],
      'default': 'star',
    },
    {'name': 'size', 'type': 'double', 'default': 24.0},
  ],
  'navigation_menu': [
    {'name': 'menu1', 'type': 'string', 'default': 'Products'},
    {'name': 'item1', 'type': 'string', 'default': 'Web Apps'},
    {'name': 'detail1', 'type': 'string', 'default': 'Landing pages and dashboards.'},
    {'name': 'menu2', 'type': 'string', 'default': 'Company'},
    {'name': 'item2', 'type': 'string', 'default': 'About'},
    {'name': 'detail2', 'type': 'string', 'default': 'Team, culture, and careers.'},
  ],
  'dropzone': [
    {'name': 'hint', 'type': 'string', 'default': 'Drag files here'},
    {'name': 'action', 'type': 'string', 'default': 'Browse files'},
  ],
  'border_loading': [
    {'name': 'label', 'type': 'string', 'default': 'Loading'},
  ],
  'overflow_marquee': [
    {
      'name': 'text',
      'type': 'string',
      'default': 'This text scrolls when it overflows its parent.',
    },
  ],
  'focus_outline': [
    {'name': 'label', 'type': 'string', 'default': 'Focus me'},
    {'name': 'focused', 'type': 'bool', 'default': true},
  ],
  'switcher': [
    {
      'name': 'direction',
      'type': 'enum',
      'enum': ['left', 'right', 'up', 'down'],
      'default': 'left',
    },
    {'name': 'page1', 'type': 'string', 'default': 'Page 1'},
    {'name': 'page2', 'type': 'string', 'default': 'Page 2'},
  ],
  'scrollable': [
    {'name': 'text1', 'type': 'string', 'default': 'First line of scrollable content.'},
    {'name': 'text2', 'type': 'string', 'default': 'Second line of scrollable content.'},
    {'name': 'text3', 'type': 'string', 'default': 'Third line of scrollable content.'},
  ],
  'stage_container': [
    {'name': 'label', 'type': 'string', 'default': 'Stage content'},
  ],
  'media_query': [
    {'name': 'label', 'type': 'string', 'default': 'Wide content'},
    {'name': 'alternate', 'type': 'string', 'default': 'Narrow content'},
    {'name': 'minWidth', 'type': 'double', 'default': 0.0},
  ],
  'scrollview': [
    {'name': 'label', 'type': 'string', 'default': 'Middle-drag to scroll'},
  ],
  'hover': [
    {'name': 'label', 'type': 'string', 'default': 'Hover me'},
  ],
  'patch': [
    {'name': 'label', 'type': 'string', 'default': 'Tap me'},
  ],
  'text': [
    {'name': 'text', 'type': 'string', 'default': 'Styled text'},
  ],
  'filter_bar': [
    {'name': 'searchPlaceholder', 'type': 'string', 'default': 'Search'},
  ],
  'fade_scroll': [
    {'name': 'row1', 'type': 'string', 'default': 'Row 1'},
    {'name': 'row2', 'type': 'string', 'default': 'Row 2'},
    {'name': 'row3', 'type': 'string', 'default': 'Row 3'},
  ],
  'resizable': [
    {'name': 'pane1', 'type': 'string', 'default': 'Left pane'},
    {'name': 'pane2', 'type': 'string', 'default': 'Right pane'},
  ],
  'subfocus': [
    {'name': 'label', 'type': 'string', 'default': 'Focused scope'},
  ],
  'repeated_animation_builder': [
    {'name': 'label', 'type': 'string', 'default': 'Pulsing'},
  ],
};
