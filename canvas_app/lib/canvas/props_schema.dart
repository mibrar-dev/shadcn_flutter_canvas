/// Schema-driven property metadata (Storybook `argTypes` style).
///
/// Each [PropSpec] describes one editable prop: its value [type], the editor
/// [control] to render, its inspector [group], enum [options] or numeric
/// `min`/`max`/`step` bounds, and the [defaultValue] used by override
/// resolution. Specs are seeded from the pre-W2 `kInspectorSchemas` data plus
/// the `defaults` in `component_catalog.dart` (same 36 catalog kinds, plus the
/// `row` container kind) — no new component kinds are invented here.
///
/// OVERRIDE MODEL (Figma-style): resolution is
/// `schema default <- kind defaults (catalog) <- node.props (sparse diff)`.
/// See [resolveProp] / [isPropOverridden].
///
/// PROMOTED PROPS (Track I specs, Track M wiring): the functional/layout
/// constructor params below (e.g. `avatar.size`, `select.disabled`) were
/// spec-only in Track I and are wired into the catalog builders since Track
/// M — spec default and catalog default agree (verified against each kit
/// constructor; see `component_catalog.dart`), so the inspector never
/// promises a preview the canvas does not show. [resolveProp] still falls
/// back to [PropSpec.defaultValue] when a kind default is absent, and edits
/// persist through `patchItem`/`clearItemProps` (and into codegen export,
/// which reads `node.props` generically).
///
/// NOTE: the field is called [PropSpec.defaultValue], not `default` —
/// `default` is a reserved word in Dart and cannot be a field name.
library;

import 'package:canvas_core/canvas_core.dart';

/// One editable prop. Mirrors one Storybook `argTypes` entry.
class PropSpec {
  /// Prop key inside `CanvasItem.props` (or the row-container field name for
  /// container kinds such as `gap`/`mainAxis`/`crossAxis`).
  final String name;

  /// Value type: `'string'`, `'number'`, `'bool'`, `'enum'`, `'color'`,
  /// `'slot'`. (`'number'` covers both `int` and `double` — see below.)
  final String type;

  /// Editor to render: `'text'`, `'stepper'` (unranged number),
  /// `'slider'` (ranged number), `'switch'`, `'select'`, `'segmented'`
  /// (enum with <= 3 options), `'color'`, `'slot'` (read-only child chip).
  final String control;

  /// Inspector section: `'content'`, `'style'`, `'state'`, `'layout'`.
  final String group;

  /// Allowed values when [type] is `'enum'` (or token keys for `'color'`).
  final List<String> options;

  /// Numeric bounds / step for `'number'` controls; null when unbounded.
  final double? min;
  final double? max;
  final double? step;

  /// Schema default. `int` vs `double` for `'number'` props is inferred from
  /// the runtime type of this value (e.g. tabs `index` defaults to `0`,
  /// progress defaults to `0.5`). `null` means "no schema default" (used by
  /// nullable container props such as `mainAxis`, where null maps to the
  /// Flutter framework default).
  final Object? defaultValue;

  /// Whether an explicit null is a legal value (container alignment props).
  final bool nullable;

  const PropSpec({
    required this.name,
    required this.type,
    required this.control,
    required this.group,
    this.options = const [],
    this.min,
    this.max,
    this.step,
    this.defaultValue,
    this.nullable = false,
  });

  /// True for `'number'` specs whose default is an `int` (stepper math and
  /// store writes stay integral).
  bool get isInt => defaultValue is int;
}

/// `mainAxis` options for the `row` container (W3 `CanvasNode.mainAxis`).
const kMainAxisOptions = [
  'start',
  'center',
  'end',
  'spaceBetween',
  'spaceAround',
  'spaceEvenly',
];

/// `crossAxis` options for the `row` container (W3 `CanvasNode.crossAxis`).
const kCrossAxisOptions = ['start', 'center', 'end', 'stretch'];

/// `expand` options for a row child node (W3 `CanvasNode.expand`, written via
/// `patchNode(nodeId, expand: ...)`). `null`/`none` both mean the default.
const kExpandOptions = ['none', 'flex', 'expanded'];

/// Per-kind schemas. Catalog-covered defaults mirror `component_catalog.dart`
/// `defaults` (reconciled 2026-09-04/05); enum option lists mirror the pre-W2
/// `kInspectorSchemas` data, including the known block-vs-constructor notes
/// (button `size` lists `icon` though `ButtonSize` has no icon member).
/// Track I functional/layout additions are spec-only (documented per spec):
/// the schema is a superset of the catalog defaults, never a new kind.
const kPropSchemas = <String, List<PropSpec>>{
  'button': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Button',
    ),
    PropSpec(
      name: 'variant',
      type: 'enum',
      control: 'select',
      group: 'style',
      options: ['primary', 'secondary', 'outline', 'ghost', 'destructive', 'link'],
      defaultValue: 'primary',
    ),
    PropSpec(
      name: 'size',
      type: 'enum',
      control: 'select',
      group: 'style',
      options: ['sm', 'md', 'lg', 'icon'],
      defaultValue: 'md',
    ),
    PropSpec(
      name: 'disabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'card': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Title',
    ),
    PropSpec(
      name: 'description',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Description',
    ),
    PropSpec(
      name: 'showFooter',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'input': [
    PropSpec(
      name: 'placeholder',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Type here',
    ),
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: '',
    ),
    // Track M: wired — `TextField(initialValue:)` (empty canvas string =
    // uncontrolled, null). Persists + exports through the builder.
    PropSpec(
      name: 'initialValue',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: '',
    ),
    PropSpec(
      name: 'disabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
    PropSpec(
      name: 'obscure',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
    // Track M: wired — `TextInput.readOnly` (focus + select, no edits).
    PropSpec(
      name: 'readOnly',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'badge': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Badge',
    ),
    PropSpec(
      name: 'variant',
      type: 'enum',
      control: 'select',
      group: 'style',
      options: ['primary', 'secondary', 'destructive', 'outline'],
      defaultValue: 'primary',
    ),
  ],
  'switch': [
    PropSpec(
      name: 'value',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
    PropSpec(
      name: 'disabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'avatar': [
    PropSpec(
      name: 'initials',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'AB',
    ),
    // Track M: wired — `Avatar(size:)` layout param. Default mirrors the
    // kit theme default (`AvatarThemeDefaults.size = 40.0`).
    PropSpec(
      name: 'size',
      type: 'number',
      control: 'stepper',
      group: 'layout',
      min: 16,
      max: 96,
      step: 4,
      defaultValue: 40.0,
    ),
  ],
  'checkbox': [
    PropSpec(
      name: 'value',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
    PropSpec(
      name: 'disabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
    // Track M: wired — `Checkbox(tristate:)` (constructor default `false`)
    // enables indeterminate-state cycling.
    PropSpec(
      name: 'tristate',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'divider': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: '',
    ),
    // Track M: wired — `Divider(thickness:)` layout param. Default mirrors
    // the kit's resolved default (`1.0`).
    PropSpec(
      name: 'thickness',
      type: 'number',
      control: 'stepper',
      group: 'layout',
      min: 1,
      max: 8,
      step: 1,
      defaultValue: 1.0,
    ),
  ],
  'progress': [
    PropSpec(
      name: 'progress',
      type: 'number',
      control: 'slider',
      group: 'state',
      min: 0,
      max: 1,
      step: 0.05,
      defaultValue: 0.5,
    ),
  ],
  'tabs': [
    PropSpec(
      name: 'tab1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Tab 1',
    ),
    PropSpec(
      name: 'tab2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Tab 2',
    ),
    // Present in the catalog `defaults` (`index: 0`) but absent from the
    // pre-W2 inspector schemas; seeded here so schema and catalog agree.
    PropSpec(
      name: 'index',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 0,
      max: 1,
      step: 1,
      defaultValue: 0,
    ),
    // Track M: wired — `Tabs(expand:)` layout flag (constructor default
    // `false`) stretches tab headers across the available width.
    PropSpec(
      name: 'expand',
      type: 'bool',
      control: 'switch',
      group: 'layout',
      defaultValue: false,
    ),
  ],
  'accordion': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Section 1',
    ),
    PropSpec(
      name: 'content',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Content 1',
    ),
    PropSpec(
      name: 'expanded',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'select': [
    PropSpec(
      name: 'placeholder',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Select an option',
    ),
    PropSpec(
      name: 'option1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Option 1',
    ),
    PropSpec(
      name: 'option2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Option 2',
    ),
    PropSpec(
      name: 'value',
      type: 'string',
      control: 'text',
      group: 'state',
      defaultValue: '',
    ),
    // Track M: wired — `Select(enabled:)` open/disabled state, mirroring
    // the input kind's `disabled` convention (`enabled: !disabled`).
    PropSpec(
      name: 'disabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'radio_group': [
    PropSpec(
      name: 'option1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Option 1',
    ),
    PropSpec(
      name: 'option2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Option 2',
    ),
    PropSpec(
      name: 'value',
      type: 'string',
      control: 'text',
      group: 'state',
      defaultValue: 'Option 1',
    ),
    // Track M: wired — `RadioGroup(enabled:)` open/disabled state, same
    // convention as select above (`enabled: !disabled`).
    PropSpec(
      name: 'disabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'skeleton': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Loading',
    ),
    PropSpec(
      name: 'enabled',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: true,
    ),
  ],
  'breadcrumb': [
    PropSpec(
      name: 'home',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Home',
    ),
    PropSpec(
      name: 'current',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Page',
    ),
    // Track M: wired — `Breadcrumb(separator:)` maps onto the kit's two
    // built-in separators (`arrowSeparator` / `slashSeparator`).
    PropSpec(
      name: 'separator',
      type: 'enum',
      control: 'select',
      group: 'style',
      options: ['arrow', 'slash'],
      defaultValue: 'arrow',
    ),
  ],
  'dialog': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Dialog title',
    ),
    PropSpec(
      name: 'message',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Use dialogs for important confirmations.',
    ),
    PropSpec(
      name: 'showActions',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: true,
    ),
  ],
  'tooltip': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Hover me',
    ),
    PropSpec(
      name: 'tip',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Helpful context',
    ),
  ],
  'toast': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Saved',
    ),
    PropSpec(
      name: 'message',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Saved successfully',
    ),
    // Track M: wired — `ToastEntry(autoDismiss:)`. Default `false` keeps
    // the canvas node stable; the kit constructor defaults to `true`.
    PropSpec(
      name: 'autoDismiss',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'drawer': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Drawer',
    ),
    PropSpec(
      name: 'content',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Drawer content',
    ),
    // Track M: wired — `DrawerWrapper(position:)` layout edge. Options
    // mirror the kit `OverlayPosition` enum; default `end`.
    PropSpec(
      name: 'position',
      type: 'enum',
      control: 'select',
      group: 'layout',
      options: ['left', 'right', 'top', 'bottom', 'start', 'end'],
      defaultValue: 'end',
    ),
  ],
  // Track J additions (2026-09-05): specs for the 17 newly-implemented
  // catalog kinds. Defaults mirror `component_catalog.dart` (invented,
  // documented per builder there); only bool/string/num/enum prop types
  // already established by the seed kinds are used.
  'basic': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Title',
    ),
    PropSpec(
      name: 'subtitle',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Subtitle',
    ),
    PropSpec(
      name: 'content',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Content',
    ),
    PropSpec(
      name: 'showLeading',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: true,
    ),
    PropSpec(
      name: 'showTrailing',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: true,
    ),
  ],
  'card_image': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Card title',
    ),
    PropSpec(
      name: 'subtitle',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Card subtitle',
    ),
  ],
  'scaffold': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'My App',
    ),
    PropSpec(
      name: 'body',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Welcome',
    ),
  ],
  'collapsible': [
    PropSpec(
      name: 'trigger',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Show more',
    ),
    PropSpec(
      name: 'content',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Hidden details',
    ),
    PropSpec(
      name: 'expanded',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'steps': [
    PropSpec(
      name: 'step1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Step 1',
    ),
    PropSpec(
      name: 'detail1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'First step details',
    ),
    PropSpec(
      name: 'step2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Step 2',
    ),
    PropSpec(
      name: 'detail2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Second step details',
    ),
  ],
  'timeline': [
    PropSpec(
      name: 'time1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: '9:00 AM',
    ),
    PropSpec(
      name: 'title1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Kickoff',
    ),
    PropSpec(
      name: 'detail1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Project kickoff meeting',
    ),
    PropSpec(
      name: 'time2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: '2:00 PM',
    ),
    PropSpec(
      name: 'title2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Review',
    ),
    PropSpec(
      name: 'detail2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Design review session',
    ),
  ],
  'outlined_container': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Outlined',
    ),
  ],
  'hidden': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Hidden content',
    ),
    PropSpec(
      name: 'hidden',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: false,
    ),
  ],
  'keyboard_shortcut': [
    PropSpec(
      name: 'keys',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Ctrl+K',
    ),
  ],
  'tracker': [
    PropSpec(
      name: 'segments',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 1,
      max: 5,
      step: 1,
      defaultValue: 3,
    ),
    PropSpec(
      name: 'level',
      type: 'enum',
      control: 'select',
      group: 'style',
      options: ['fine', 'warning', 'critical', 'unknown'],
      defaultValue: 'fine',
    ),
  ],
  'chat': [
    PropSpec(
      name: 'message',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Hello!',
    ),
  ],
  'selectable': [
    PropSpec(
      name: 'text',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Select me',
    ),
  ],
  'star_rating': [
    PropSpec(
      name: 'value',
      type: 'number',
      control: 'slider',
      group: 'state',
      min: 0,
      max: 10,
      step: 0.5,
      defaultValue: 3.0,
    ),
    PropSpec(
      name: 'max',
      type: 'number',
      control: 'slider',
      group: 'state',
      min: 1,
      max: 10,
      step: 1,
      defaultValue: 5.0,
    ),
  ],
  'clickable': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Tap me',
    ),
  ],
  'scrollbar': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Scrollable content',
    ),
  ],
  'pagination': [
    PropSpec(
      name: 'page',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 1,
      max: 20,
      step: 1,
      defaultValue: 1,
    ),
    PropSpec(
      name: 'totalPages',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 1,
      max: 20,
      step: 1,
      defaultValue: 5,
    ),
  ],
  'alert_dialog': [
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Are you sure?',
    ),
    PropSpec(
      name: 'message',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'This action cannot be undone.',
    ),
    PropSpec(
      name: 'showActions',
      type: 'bool',
      control: 'switch',
      group: 'state',
      defaultValue: true,
    ),
  ],
  // Track M additions (2026-09-05): specs for the 15 newly-implemented
  // catalog kinds. Defaults mirror `component_catalog.dart` (invented,
  // documented per builder there); only bool/string/num prop types already
  // established by the seed kinds are used.
  'menu': [
    PropSpec(
      name: 'heading',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'File',
    ),
    PropSpec(
      name: 'item1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'New',
    ),
    PropSpec(
      name: 'item2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Open',
    ),
  ],
  'popover': [
    PropSpec(
      name: 'trigger',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Open Popover',
    ),
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Popover title',
    ),
    PropSpec(
      name: 'body',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Use popovers for contextual helper content.',
    ),
  ],
  'popup': [
    PropSpec(
      name: 'item1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Profile',
    ),
    PropSpec(
      name: 'item2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Settings',
    ),
    PropSpec(
      name: 'item3',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Sign out',
    ),
  ],
  'menubar': [
    PropSpec(
      name: 'menu1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'File',
    ),
    PropSpec(
      name: 'menu2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Edit',
    ),
  ],
  'dropdown_menu': [
    PropSpec(
      name: 'heading',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'My Account',
    ),
    PropSpec(
      name: 'item1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Profile',
    ),
    PropSpec(
      name: 'item2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Settings',
    ),
  ],
  'context_menu': [
    PropSpec(
      name: 'hint',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Right-click me',
    ),
    PropSpec(
      name: 'item1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Back',
    ),
    PropSpec(
      name: 'item2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Reload',
    ),
  ],
  'hover_card': [
    PropSpec(
      name: 'handle',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Hover card',
    ),
    PropSpec(
      name: 'title',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Hover title',
    ),
    PropSpec(
      name: 'body',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Rich preview content.',
    ),
  ],
  'command': [
    PropSpec(
      name: 'hint',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Search commands...',
    ),
    PropSpec(
      name: 'item1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Calendar',
    ),
    PropSpec(
      name: 'item2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Settings',
    ),
  ],
  'swiper': [
    PropSpec(
      name: 'hint',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Swipe up from the bottom',
    ),
    PropSpec(
      name: 'content',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Swipe content',
    ),
  ],
  'refresh_trigger': [
    PropSpec(
      name: 'item1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Row 1',
    ),
    PropSpec(
      name: 'item2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Row 2',
    ),
    PropSpec(
      name: 'item3',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Row 3',
    ),
  ],
  'tab_container': [
    PropSpec(
      name: 'tab1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Overview',
    ),
    PropSpec(
      name: 'tab2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Details',
    ),
    PropSpec(
      name: 'tab3',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Reviews',
    ),
    PropSpec(
      name: 'index',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 0,
      max: 2,
      step: 1,
      defaultValue: 0,
    ),
  ],
  'tab_list': [
    PropSpec(
      name: 'tab1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Tab 1',
    ),
    PropSpec(
      name: 'tab2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Tab 2',
    ),
    PropSpec(
      name: 'index',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 0,
      max: 1,
      step: 1,
      defaultValue: 0,
    ),
  ],
  'tab_pane': [
    PropSpec(
      name: 'tab1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Overview',
    ),
    PropSpec(
      name: 'tab2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Analytics',
    ),
    PropSpec(
      name: 'tab3',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Settings',
    ),
    PropSpec(
      name: 'focused',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 0,
      max: 2,
      step: 1,
      defaultValue: 0,
    ),
  ],
  'stepper': [
    PropSpec(
      name: 'step1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Details',
    ),
    PropSpec(
      name: 'detail1',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Provide your details.',
    ),
    PropSpec(
      name: 'step2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Payment',
    ),
    PropSpec(
      name: 'detail2',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Choose a payment method.',
    ),
    PropSpec(
      name: 'step3',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Confirm',
    ),
    PropSpec(
      name: 'detail3',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: 'Review and submit.',
    ),
    PropSpec(
      name: 'step',
      type: 'number',
      control: 'stepper',
      group: 'state',
      min: 0,
      max: 2,
      step: 1,
      defaultValue: 0,
    ),
  ],
  'slider': [
    PropSpec(
      name: 'value',
      type: 'number',
      control: 'slider',
      group: 'state',
      min: 0,
      max: 1,
      step: 0.05,
      defaultValue: 0.6,
    ),
  ],
  // Container kinds are not catalog entries (a row has no registry widget)
  // but are inspector-editable all the same.
  'row': [
    PropSpec(
      name: 'gap',
      type: 'number',
      control: 'stepper',
      group: 'layout',
      min: 0,
      max: 32,
      step: 4,
      defaultValue: kFlowRowGapDefault,
    ),
    // Dictated W3 params (`CanvasNode.mainAxis`/`crossAxis`, landed in the
    // working tree). Defaults are null, meaning "Flutter framework default"
    // (`MainAxisAlignment.start` / `CrossAxisAlignment.center`). NOTE:
    // `patchNode` treats a null param as "leave unchanged" (all-null is a
    // no-op), so there is no reset-to-null path — once set, a value sticks
    // until overwritten. The inspector therefore offers no reset affordance
    // for these two.
    PropSpec(
      name: 'mainAxis',
      type: 'enum',
      control: 'select',
      group: 'layout',
      options: kMainAxisOptions,
      nullable: true,
    ),
    PropSpec(
      name: 'crossAxis',
      type: 'enum',
      control: 'select',
      group: 'layout',
      options: kCrossAxisOptions,
      nullable: true,
    ),
  ],
};

/// Looks up the [PropSpec] for ([kind], [name]), or null when unknown.
PropSpec? findSpec(String kind, String name) {
  final specs = kPropSchemas[kind];
  if (specs == null) return null;
  for (final spec in specs) {
    if (spec.name == name) return spec;
  }
  return null;
}

/// Figma-style resolution: `schema default <- kind defaults <- props`.
///
/// [kindDefaults] is the catalog entry's `defaults` for [kind] (the middle
/// layer); [props] is the sparse instance diff. A missing key resolves to
/// the middle layer, then to the schema default.
Object? resolveProp(
  String kind,
  String name,
  Map<String, dynamic> props, [
  Map<String, dynamic>? kindDefaults,
]) {
  if (props.containsKey(name)) return props[name];
  if (kindDefaults != null && kindDefaults.containsKey(name)) {
    return kindDefaults[name];
  }
  return findSpec(kind, name)?.defaultValue;
}

/// True when [props] carries an instance override that differs from the
/// resolved default (schema default, or [kindDefaults] when provided).
/// A key present with a value equal to the default counts as NOT overridden,
/// which is what makes the "reset writes the default value" compromise (see
/// inspector_panel.dart) display correctly: after a reset the badge clears.
bool isPropOverridden(
  String kind,
  String name,
  Map<String, dynamic> props, [
  Map<String, dynamic>? kindDefaults,
]) {
  if (!props.containsKey(name)) return false;
  final baseline = kindDefaults != null && kindDefaults.containsKey(name)
      ? kindDefaults[name]
      : findSpec(kind, name)?.defaultValue;
  return props[name] != baseline;
}
