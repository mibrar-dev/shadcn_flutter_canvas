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
/// SPEC-ONLY PROPS (Track I): several functional/layout constructor params
/// (e.g. `avatar.size`, `select.disabled`) have a [PropSpec] here but no
/// `component_catalog.dart` default — the catalog builders ignore them until
/// a kit-side wiring batch lands. [resolveProp] falls back to
/// [PropSpec.defaultValue] for these, so the inspector still shows a stable
/// default and edits persist through `patchItem`/`clearItemProps` (and into
/// codegen export, which reads `node.props` generically). Spec defaults for
/// these mirror what the builder currently renders (e.g. drawer's hardcoded
/// `OverlayPosition.end`), never the kit constructor default, so the
/// inspector never promises a preview the canvas does not show.
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
    // Spec-only (Track I): `TextField(initialValue:)` — the field's current
    // value. The catalog builder renders an uncontrolled field, so this
    // persists + exports without changing the preview yet.
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
    // Spec-only (Track I): `TextInput.readOnly` — functional state (focus +
    // select, no edits). Builder renders an editable field until wired.
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
    // Spec-only (Track I): `Avatar(size:)` layout param. Default mirrors the
    // kit theme default (`AvatarThemeDefaults.size = 40.0`); the catalog
    // builder renders theme sizing until wired.
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
    // Spec-only (Track I): `Checkbox(tristate:)` (constructor default
    // `false`) — enables indeterminate-state cycling. Builder ignores it.
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
    // Spec-only (Track I): `Divider(thickness:)` layout param. Default
    // mirrors the kit's resolved default (`1.0`); builder renders the theme
    // thickness until wired.
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
    // Spec-only (Track I): `Tabs(expand:)` layout flag (constructor default
    // `false`) — stretches tab headers across the available width. The
    // catalog builder renders the default (`false`) until wired.
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
    // Spec-only (Track I): `Select(enabled:)` open/disabled state, mirroring
    // the input kind's `disabled` convention. Builder renders enabled until
    // wired.
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
    // Spec-only (Track I): `RadioGroup(enabled:)` open/disabled state,
    // same convention as select above. Builder renders enabled until wired.
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
    // Spec-only (Track I): `Breadcrumb(separator:)` — the kit's two
    // built-in separators (`arrowSeparator` / `slashSeparator`). Default
    // mirrors the builder (arrow). Renders segmented (<= 3 options).
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
    // Spec-only (Track I): `ToastEntry(autoDismiss:)` open state. Default
    // mirrors the builder (`false`, so the canvas node never self-dismisses);
    // the kit constructor defaults to `true`.
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
    // Spec-only (Track I): `DrawerWrapper(position:)` layout edge. Options
    // mirror the kit `OverlayPosition` enum; default mirrors the builder's
    // hardcoded `OverlayPosition.end`.
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
