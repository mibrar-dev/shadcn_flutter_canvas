/// Schema-driven property metadata (Storybook `argTypes` style).
///
/// Each [PropSpec] describes one editable prop: its value [type], the editor
/// [control] to render, its inspector [group], enum [options] or numeric
/// `min`/`max`/`step` bounds, and the [defaultValue] used by override
/// resolution. Specs are seeded from the pre-W2 `kInspectorSchemas` data plus
/// the `defaults` in `component_catalog.dart` (same 19 catalog kinds, plus the
/// `row` container kind) — no new component kinds are invented here.
///
/// OVERRIDE MODEL (Figma-style): resolution is
/// `schema default <- kind defaults (catalog) <- node.props (sparse diff)`.
/// See [resolveProp] / [isPropOverridden].
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

/// Per-kind schemas. Defaults mirror `component_catalog.dart` `defaults`
/// (reconciled 2026-09-04/05); enum option lists mirror the pre-W2
/// `kInspectorSchemas` data, including the known block-vs-constructor notes
/// (button `size` lists `icon` though `ButtonSize` has no icon member).
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
  ],
  'divider': [
    PropSpec(
      name: 'label',
      type: 'string',
      control: 'text',
      group: 'content',
      defaultValue: '',
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
