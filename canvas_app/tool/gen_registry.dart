// Generates lib/canvas/component_registry.dart from the kit manifest.
//
// Reads `components.json` (id + description + category per component) and
// emits one [RegistryEntry] per kit component id plus the `row` pseudo-kind.
// Entry builders are NOT generated from previews (previews render full
// `Scaffold`s — see component_catalog.dart): the 19 catalog kinds bridge to
// `buildCatalogWithDefaults`, 10 hand-verified EASY kinds get bare-widget
// builders (sources embedded below, each verified by grepping the kit
// `_impl/` sources for a ctor taking only string/num/bool/enum/child
// params), and everything else gets the documented placeholder builder.
//
// Mirrors tool/embed_sources.dart style: kit root defaults to a
// `shadcn_flutter_kit` checkout sitting next to this repo; pass it
// explicitly to override:
// `dart run tool/gen_registry.dart /path/to/shadcn_flutter_kit`.
import 'dart:convert';
import 'dart:io';

/// Palette section per kit category, in palette order.
const _sectionsByCategory = <String, String>{
  'layout': 'Layout & Structure',
  'display': 'Display',
  'form': 'Forms & Inputs',
  'control': 'Controls',
  'navigation': 'Navigation',
  'overlay': 'Overlays',
  'utility': 'Utilities',
};

const _sectionOrder = <String>[
  'Layout Primitives',
  'Layout & Structure',
  'Display',
  'Forms & Inputs',
  'Controls',
  'Navigation',
  'Overlays',
  'Utilities',
];

/// Utility ids with no visual canvas footprint. They stay in the generated
/// registry (coverage requirement) but the palette hides them from the
/// Utilities section: alpha (transparency painter), async (value helper),
/// debug (layout overlays), locale_utils (formatting helpers),
/// shadcn_localizations* (l10n delegates), error_system (error mapping),
/// wrapper (structural conditional wrapper).
const _hiddenUtilities = <String>{
  'alpha',
  'async',
  'debug',
  'locale_utils',
  'shadcn_localizations',
  'shadcn_localizations_en',
  'shadcn_localizations_extensions',
  'error_system',
  'wrapper',
};

/// The 19 catalog kinds: registry builders delegate to
/// `catalog.buildCatalogWithDefaults` (no duplication).
const _bridgeKinds = <String>{
  'button',
  'card',
  'input',
  'badge',
  'switch',
  'avatar',
  'checkbox',
  'divider',
  'progress',
  'tabs',
  'accordion',
  'select',
  'radio_group',
  'skeleton',
  'breadcrumb',
  'dialog',
  'tooltip',
  'toast',
  'drawer',
};

/// Hand-verified EASY kinds with real bare-widget builders below
/// (kind -> builder function name).
const _readyKinds = <String, String>{
  'chip': 'buildChipEntry',
  'alert': 'buildAlertEntry',
  'circular_progress_indicator': 'buildCircularProgressEntry',
  'linear_progress_indicator': 'buildLinearProgressEntry',
  'triple_dots': 'buildTripleDotsEntry',
  'dot_indicator': 'buildDotIndicatorEntry',
  'empty_state': 'buildEmptyStateEntry',
  'code_snippet': 'buildCodeSnippetEntry',
  'number_ticker': 'buildNumberTickerEntry',
  'text_area': 'buildTextAreaEntry',
};

/// Nearest Icons.* constant per kit component id (fallback: Icons.widgets).
const _icons = <String, String>{
  'button': 'Icons.smart_button',
  'clickable': 'Icons.touch_app',
  'command': 'Icons.terminal',
  'hover': 'Icons.mouse',
  'patch': 'Icons.fingerprint',
  'scrollbar': 'Icons.swap_vert',
  'scrollview': 'Icons.swipe',
  'avatar': 'Icons.account_circle',
  'badge': 'Icons.label',
  'border_loading': 'Icons.blur_circular',
  'calendar': 'Icons.calendar_month',
  'carousel': 'Icons.slideshow',
  'chat': 'Icons.chat_bubble_outline',
  'chip': 'Icons.local_offer',
  'circular_progress_indicator': 'Icons.autorenew',
  'code_snippet': 'Icons.code',
  'divider': 'Icons.horizontal_rule',
  'dot_indicator': 'Icons.fiber_manual_record',
  'empty_state': 'Icons.inbox',
  'feature_carousel': 'Icons.view_carousel',
  'file_diff_viewer': 'Icons.compare',
  'icon': 'Icons.insert_emoticon',
  'keyboard_shortcut': 'Icons.keyboard',
  'linear_progress_indicator': 'Icons.bar_chart',
  'markdown': 'Icons.article',
  'number_ticker': 'Icons.timer',
  'progress': 'Icons.linear_scale',
  'selectable': 'Icons.select_all',
  'skeleton': 'Icons.blur_on',
  'spinner': 'Icons.refresh',
  'text': 'Icons.text_format',
  'text_animate': 'Icons.animation',
  'tracker': 'Icons.track_changes',
  'tree': 'Icons.account_tree',
  'triple_dots': 'Icons.more_horiz',
  'autocomplete': 'Icons.auto_awesome',
  'checkbox': 'Icons.check_box',
  'chip_input': 'Icons.new_label',
  'color_input': 'Icons.colorize',
  'color_picker': 'Icons.palette',
  'control': 'Icons.handyman',
  'date_picker': 'Icons.date_range',
  'dropzone': 'Icons.upload_file',
  'file_input': 'Icons.attach_file',
  'file_picker': 'Icons.folder_open',
  'form': 'Icons.assignment',
  'form_field': 'Icons.edit_note',
  'formatted_input': 'Icons.text_snippet',
  'formatter': 'Icons.format_bold',
  'history': 'Icons.history',
  'hsl': 'Icons.gradient',
  'hsv': 'Icons.color_lens',
  'input': 'Icons.text_fields',
  'input_otp': 'Icons.dialpad',
  'item_picker': 'Icons.checklist',
  'multiple_choice': 'Icons.ballot',
  'object_input': 'Icons.event',
  'phone_input': 'Icons.phone',
  'radio_group': 'Icons.radio_button_checked',
  'select': 'Icons.arrow_drop_down_circle',
  'slider': 'Icons.tune',
  'star_rating': 'Icons.star',
  'switch': 'Icons.toggle_on',
  'text_area': 'Icons.subject',
  'text_field': 'Icons.short_text',
  'time_picker': 'Icons.schedule',
  'validated': 'Icons.verified',
  'accordion': 'Icons.expand_more',
  'alert': 'Icons.warning_amber',
  'app': 'Icons.apps',
  'basic': 'Icons.view_agenda',
  'card': 'Icons.crop_square',
  'card_image': 'Icons.image',
  'collapsible': 'Icons.unfold_more',
  'fade_scroll': 'Icons.unfold_less',
  'filter_bar': 'Icons.filter_list',
  'flex': 'Icons.view_stream',
  'group': 'Icons.group',
  'hidden': 'Icons.visibility_off',
  'media_query': 'Icons.devices',
  'outlined_container': 'Icons.check_box_outline_blank',
  'overflow_marquee': 'Icons.wrap_text',
  'resizable': 'Icons.open_in_full',
  'scaffold': 'Icons.view_quilt',
  'scrollable': 'Icons.import_export',
  'scrollable_client': 'Icons.zoom_out_map',
  'sortable': 'Icons.sort',
  'stage_container': 'Icons.desktop_windows',
  'steps': 'Icons.format_list_numbered',
  'table': 'Icons.table_chart',
  'timeline': 'Icons.timeline',
  'window': 'Icons.web',
  'breadcrumb': 'Icons.chevron_right',
  'navigation_bar': 'Icons.navigation',
  'navigation_menu': 'Icons.menu',
  'pagination': 'Icons.last_page',
  'stepper': 'Icons.directions_walk',
  'subfocus': 'Icons.center_focus_strong',
  'switcher': 'Icons.tab_unselected',
  'tab_container': 'Icons.view_module',
  'tab_list': 'Icons.view_list',
  'tab_pane': 'Icons.dock',
  'tabs': 'Icons.tab',
  'alert_dialog': 'Icons.error_outline',
  'context_menu': 'Icons.more_vert',
  'dialog': 'Icons.web_asset',
  'drawer': 'Icons.menu_open',
  'dropdown_menu': 'Icons.arrow_drop_down',
  'eye_dropper': 'Icons.brush',
  'gooey_toast': 'Icons.notification_add',
  'hover_card': 'Icons.preview',
  'menu': 'Icons.list',
  'menubar': 'Icons.view_headline',
  'overlay': 'Icons.layers',
  'popover': 'Icons.chat_bubble',
  'popup': 'Icons.launch',
  'refresh_trigger': 'Icons.refresh',
  'swiper': 'Icons.gesture',
  'toast': 'Icons.notifications',
  'tooltip': 'Icons.help_outline',
  'alpha': 'Icons.grid_on',
  'async': 'Icons.sync',
  'color': 'Icons.format_color_fill',
  'debug': 'Icons.bug_report',
  'error_system': 'Icons.error',
  'focus_outline': 'Icons.crop',
  'image': 'Icons.photo_library',
  'locale_utils': 'Icons.language',
  'repeated_animation_builder': 'Icons.loop',
  'shadcn_localizations': 'Icons.translate',
  'shadcn_localizations_en': 'Icons.abc',
  'shadcn_localizations_extensions': 'Icons.g_translate',
  'timeline_animation': 'Icons.movie',
  'wrapper': 'Icons.widgets',
};

/// Bare-widget builder sources for [_readyKinds]. Widget names were
/// discovered per kind, never assumed
/// (`grep -rn "^class .* extends .*Widget" <component>/ | grep -v preview`):
/// chip -> `Chip` (display/chip/chip.dart: required child, optional
/// leading/trailing/onPressed); alert -> `Alert` (layout/alert/alert.dart:
/// optional leading/title/content/trailing/destructive); _impl theme/config
/// files also declare `*Theme` classes, so matches there are ignored.
/// circular_progress_indicator -> `CircularProgressIndicator` (optional
/// value/size/color/backgroundColor/strokeWidth); linear_progress_indicator
/// -> `LinearProgressIndicator` (optional value/backgroundColor/minHeight/
/// color/showSparks); triple_dots -> `MoreDots` (direction/count/size/color/
/// spacing/padding, all defaulted); dot_indicator -> `DotIndicator`
/// (required index/length); empty_state -> `EmptyState` (all optional —
/// title/description/icon/actions fall back to variant defaults);
/// code_snippet -> `CodeSnippet` (required code Widget, typically a Text);
/// number_ticker -> `NumberTicker` (required number/formatter); text_area -> `TextArea`
/// (extends TextInputStatefulWidget — all super params optional, mirrors the
/// input catalog builder's placeholder/enabled pattern).
/// Material-name collisions (Chip, CircularProgressIndicator,
/// LinearProgressIndicator) resolve via the `shadcn.` prefix.
const _builderSources = <String, String>{
  'chip': r'''
const kChipEntryDefaults = <String, dynamic>{'label': 'Chip'};

/// Verified: `Chip` (`display/chip/chip.dart`) takes a required child plus
/// optional leading/trailing widgets — the canvas-level `label` prop renders
/// as that child (mirrors the badge catalog builder).
Widget buildChipEntry(Map<String, dynamic> props) {
  final label = (props['label'] ?? 'Chip') as String;
  return shadcn.Chip(child: Text(label));
}
''',
  'alert': r'''
const kAlertEntryDefaults = <String, dynamic>{
  'title': 'Alert',
  'content': 'Something happened.',
  'destructive': false,
};

/// Verified: `Alert` (`layout/alert/alert.dart`) takes optional leading/
/// title/content/trailing widgets plus `destructive` — canvas-level string
/// props render as the title/content Texts.
Widget buildAlertEntry(Map<String, dynamic> props) {
  final title = (props['title'] ?? 'Alert') as String;
  final content = (props['content'] ?? 'Something happened.') as String;
  final destructive = (props['destructive'] ?? false) as bool;
  return shadcn.Alert(
    title: Text(title),
    content: Text(content),
    destructive: destructive,
  );
}
''',
  'circular_progress_indicator': r'''
const kCircularProgressEntryDefaults = <String, dynamic>{'value': 0.6};

/// Verified: `CircularProgressIndicator`
/// (`display/circular_progress_indicator/`) takes an optional `value`
/// (null = indeterminate). Parsed via `num` because `jsonDecode` yields
/// `int` for whole numbers, and clamped like the progress catalog builder.
Widget buildCircularProgressEntry(Map<String, dynamic> props) {
  final value = ((props['value'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0);
  return shadcn.CircularProgressIndicator(value: value);
}
''',
  'linear_progress_indicator': r'''
const kLinearProgressEntryDefaults = <String, dynamic>{'value': 0.6};

/// Verified: `LinearProgressIndicator`
/// (`display/linear_progress_indicator/`) takes an optional `value` plus
/// color/minHeight/spark overrides — canvas pins the determinate value
/// (same `num`-parse + clamp idiom as the progress catalog builder).
Widget buildLinearProgressEntry(Map<String, dynamic> props) {
  final value = ((props['value'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0);
  return shadcn.LinearProgressIndicator(value: value);
}
''',
  'triple_dots': r'''
const kTripleDotsEntryDefaults = <String, dynamic>{'count': 3};

/// Verified: `MoreDots` (`display/triple_dots/triple_dots.dart`) takes
/// direction/count/size/color/spacing/padding, all defaulted — the
/// canvas-level `count` prop is an int (parsed via `num`, clamped to a
/// sane range).
Widget buildTripleDotsEntry(Map<String, dynamic> props) {
  final count = ((props['count'] as num?)?.toInt() ?? 3).clamp(1, 9);
  return shadcn.MoreDots(count: count);
}
''',
  'dot_indicator': r'''
const kDotIndicatorEntryDefaults = <String, dynamic>{'index': 0, 'length': 3};

/// Verified: `DotIndicator` (`display/dot_indicator/dot_indicator.dart`)
/// requires `index` + `length` ints (parsed via `num`, index clamped into
/// range so hand-written docs never crash).
Widget buildDotIndicatorEntry(Map<String, dynamic> props) {
  final length = ((props['length'] as num?)?.toInt() ?? 3).clamp(1, 9);
  final index = ((props['index'] as num?)?.toInt() ?? 0).clamp(0, length - 1);
  return shadcn.DotIndicator(index: index, length: length);
}
''',
  'empty_state': r'''
const kEmptyStateEntryDefaults = <String, dynamic>{
  'title': 'No results',
  'description': 'Try adjusting your search.',
};

/// Verified: `EmptyState` (`display/empty_state/_impl/core/empty_state.dart`)
/// is all-optional (icon/title/description/actions fall back to per-variant
/// defaults) — canvas-level string props render as the title/description
/// Texts, mirroring the card catalog builder's content-prop pattern.
Widget buildEmptyStateEntry(Map<String, dynamic> props) {
  final title = (props['title'] ?? 'No results') as String;
  final description =
      (props['description'] ?? 'Try adjusting your search.') as String;
  return shadcn.EmptyState(
    title: Text(title),
    description: Text(description),
  );
}
''',
  'code_snippet': r'''
const kCodeSnippetEntryDefaults = <String, dynamic>{'code': 'const x = 1;'};

/// Verified: `CodeSnippet` (`display/code_snippet/code_snippet.dart`) takes
/// a required `code` Widget plus optional constraints/actions — the
/// canvas-level `code` string prop renders as that child (same content-prop
/// pattern as the card catalog builder; default invented, documented here).
Widget buildCodeSnippetEntry(Map<String, dynamic> props) {
  final code = (props['code'] ?? 'const x = 1;') as String;
  return shadcn.CodeSnippet(code: Text(code));
}
''',
  'number_ticker': r'''
const kNumberTickerEntryDefaults = <String, dynamic>{'value': 42};

/// Verified: `NumberTicker` (`display/number_ticker/number_ticker.dart`)
/// requires `number` + `formatter` (or a builder) — canvas pins a plain
/// integer formatter; the value parses via `num` (default invented,
/// documented here).
Widget buildNumberTickerEntry(Map<String, dynamic> props) {
  final value = (props['value'] as num?)?.toDouble() ?? 42;
  return shadcn.NumberTicker(
    number: value,
    formatter: (v) => v.toStringAsFixed(0),
  );
}
''',
  'text_area': r'''
const kTextAreaEntryDefaults = <String, dynamic>{
  'placeholder': 'Type here',
  'label': '',
  'disabled': false,
};

/// Verified: `TextArea` (`form/text_area/text_area.dart`) extends
/// `TextInputStatefulWidget` with all-optional params — mirrors the input
/// catalog builder (`TextField` has no `label` param either, so it renders
/// as a caption above).
Widget buildTextAreaEntry(Map<String, dynamic> props) {
  final placeholder = (props['placeholder'] ?? 'Type here') as String;
  final label = (props['label'] ?? '') as String;
  final disabled = (props['disabled'] ?? false) as bool;
  final field = shadcn.TextArea(
    placeholder: Text(placeholder),
    enabled: !disabled,
  );
  if (label.isEmpty) return field;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 6),
      field,
    ],
  );
}
''',
};

/// Dart-escapes a manifest string for a double-quoted literal (`$` would
/// otherwise interpolate — JSON escapes never emit `$`, so every `$` here
/// is a literal content char; same trick as tool/embed_sources.dart).
String _dartStr(String s) => jsonEncode(s).replaceAll(r'$', r'\$');

void main(List<String> args) {
  // Kit root defaults to a `shadcn_flutter_kit` checkout sitting next to this
  // repo (the app itself resolves the kit from GitHub; only regeneration
  // needs a local checkout). Pass it explicitly to override:
  // `dart run tool/gen_registry.dart /path/to/shadcn_flutter_kit`.
  final kitRoot = args.isNotEmpty
      ? args[0]
      : '${File(Platform.script.toFilePath()).parent.parent.parent.path}/shadcn_flutter_kit';
  final manifest = jsonDecode(File(
    '$kitRoot/flutter_shadcn_kit/lib/registry/manifests/components.json',
  ).readAsStringSync()) as Map<String, dynamic>;
  final components = [
    for (final c in manifest['components'] as List) c as Map<String, dynamic>,
  ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  for (final c in components) {
    final category = c['category'] as String;
    if (!_sectionsByCategory.containsKey(category)) {
      stderr.writeln('unknown category $category for ${c['id']}');
      exit(1);
    }
  }
  final missingIcons = [
    for (final c in components)
      if (!_icons.containsKey(c['id'])) c['id'],
  ];
  if (missingIcons.isNotEmpty) {
    stderr.writeln('missing icons for $missingIcons');
    exit(1);
  }
  final unknownReady = [
    for (final kind in _readyKinds.keys)
      if (!components.any((c) => c['id'] == kind)) kind,
  ];
  if (unknownReady.isNotEmpty) {
    stderr.writeln('ready kinds absent from manifest: $unknownReady');
    exit(1);
  }

  final out = StringBuffer()
    ..writeln('// GENERATED by tool/gen_registry.dart — DO NOT EDIT.')
    ..writeln('// Source: flutter_shadcn_kit '
        'lib/registry/manifests/components.json '
        '(${components.length} components).')
    ..writeln('//')
    ..writeln('// One entry per kit component id plus the `row` pseudo-kind.')
    ..writeln('// `canvasReady` is true only where a real bare-widget builder')
    ..writeln('// exists: the 19 catalog kinds bridge to')
    ..writeln('// `catalog.buildCatalogWithDefaults` (no duplication), the 10')
    ..writeln('// hand-verified EASY kinds below build real widgets, and the')
    ..writeln('// `row` pseudo-kind renders its structural Row (rows carry no')
    ..writeln('// items and lay out in ScreenSurface). Every other kind gets')
    ..writeln('// [RegistryPlaceholder]: a dashed-border card with the label +')
    ..writeln("// 'canvas-ready coming soon' — the palette lists them anyway")
    ..writeln('// (product requirement), rendering honestly.')
    ..writeln('// Widget names were discovered per kind via')
    ..writeln('// `grep -rn "^class .* extends .*Widget" <component>/_impl/`,')
    ..writeln('// never assumed. Preview files are never embedded.')
    ..writeln('library;')
    ..writeln()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln("import 'package:canvas_app/canvas/component_catalog.dart' as catalog;")
    ..writeln("import 'package:canvas_app/shadcn_ui.dart' as shadcn;")
    ..writeln()
    ..writeln('/// One palette/canvas registry entry.')
    ..writeln('///')
    ..writeln('/// [kind] is the kit component id (or the `row` pseudo-kind).')
    ..writeln('/// [label] mirrors the manifest description (the palette tile shows')
    ..writeln('/// the humanized kind; the label is the tooltip + search text).')
    ..writeln('/// [section] is one of [kRegistrySectionOrder]. [build] constructs')
    ..writeln('/// the canvas widget with entry defaults (bridged kinds delegate to')
    ..writeln('/// the catalog, so drop/drop-target behavior is unchanged).')
    ..writeln('/// [canvasReady] is true only for real bare-widget builders.')
    ..writeln('class RegistryEntry {')
    ..writeln('  final String kind;')
    ..writeln('  final String label;')
    ..writeln('  final String section;')
    ..writeln('  final IconData icon;')
    ..writeln('  final WidgetBuilder build;')
    ..writeln('  final bool canvasReady;')
    ..writeln()
    ..writeln('  const RegistryEntry({')
    ..writeln('    required this.kind,')
    ..writeln('    required this.label,')
    ..writeln('    required this.section,')
    ..writeln('    required this.icon,')
    ..writeln('    required this.build,')
    ..writeln('    required this.canvasReady,')
    ..writeln('  });')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Palette sections in display order.')
    ..writeln('const kRegistrySectionOrder = <String>[');
  for (final section in _sectionOrder) {
    out.writeln('  ${_dartStr(section)},');
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('/// Utility ids with no visual canvas footprint. Present in')
    ..writeln('/// [kRegistry] (coverage) but hidden from the Utilities palette')
    ..writeln('/// section by [registrySectionEntries].')
    ..writeln('const kHiddenUtilityKinds = <String>{');
  for (final kind in _hiddenUtilities.toList()..sort()) {
    out.writeln('  ${_dartStr(kind)},');
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('/// Word-start matcher shared by the palette and its regression')
    ..writeln('/// tests: every whitespace-separated query token must prefix-match')
    ..writeln('/// a word start in the entry kind id or label. Substring hits like')
    ..writeln("/// 'row' in Breadcrumb's 'arrow' separator text no longer match.")
    ..writeln('bool registryMatchesQuery(RegistryEntry entry, String query) {')
    ..writeln('  final tokens = query')
    ..writeln('      .trim()')
    ..writeln('      .toLowerCase()')
    ..writeln("      .split(RegExp(r'\\s+'))")
    ..writeln('      .where((t) => t.isNotEmpty)')
    ..writeln('      .toList();')
    ..writeln('  if (tokens.isEmpty) return true;')
    ..writeln('  final words = <String>[')
    ..writeln('    ...entry.kind.toLowerCase().split(RegExp(r\'[^a-z0-9]+\')),')
    ..writeln('    ...entry.label.toLowerCase().split(RegExp(r\'[^a-z0-9]+\')),')
    ..writeln('  ].where((w) => w.isNotEmpty).toList();')
    ..writeln(
      '  return tokens.every((t) => words.any((w) => w.startsWith(t)));')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Visible entries for [section] in registry order (hidden')
    ..writeln('/// utilities excluded — the palette renders sections from this).')
    ..writeln('List<RegistryEntry> registrySectionEntries(String section) {')
    ..writeln('  return [')
    ..writeln('    for (final entry in kRegistry)')
    ..writeln('      if (entry.section == section &&')
    ..writeln('          !kHiddenUtilityKinds.contains(entry.kind))')
    ..writeln('        entry,')
    ..writeln('  ];')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Looks up a registry entry by kind, or null when unknown.')
    ..writeln('RegistryEntry? findRegistryEntry(String kind) {')
    ..writeln('  for (final entry in kRegistry) {')
    ..writeln('    if (entry.kind == kind) return entry;')
    ..writeln('  }')
    ..writeln('  return null;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Honest placeholder for kinds with no bare-widget builder yet:')
    ..writeln('/// dashed-border card with the component label plus the')
    ..writeln("// 'canvas-ready coming soon' note.")
    ..writeln('class RegistryPlaceholder extends StatelessWidget {')
    ..writeln('  final String kind;')
    ..writeln('  final String label;')
    ..writeln()
    ..writeln('  const RegistryPlaceholder({')
    ..writeln('    super.key,')
    ..writeln('    required this.kind,')
    ..writeln('    required this.label,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Widget build(BuildContext context) {')
    ..writeln('    final outline = Theme.of(context).colorScheme.outline;')
    ..writeln('    return CustomPaint(')
    ..writeln('      painter: _DashPainter(color: outline),')
    ..writeln('      child: Padding(')
    ..writeln('        padding: const EdgeInsets.symmetric(')
    ..writeln('          horizontal: 12,')
    ..writeln('          vertical: 10,')
    ..writeln('        ),')
    ..writeln('        child: Column(')
    ..writeln('          mainAxisSize: MainAxisSize.min,')
    ..writeln('          children: [')
    ..writeln('            Text(label, textAlign: TextAlign.center),')
    ..writeln("            const SizedBox(height: 4),")
    ..writeln("            const Text('canvas-ready coming soon'),")
    ..writeln('          ],')
    ..writeln('        ),')
    ..writeln('      ),')
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Dashed rounded-rectangle painter for [RegistryPlaceholder].')
    ..writeln('class _DashPainter extends CustomPainter {')
    ..writeln('  final Color color;')
    ..writeln()
    ..writeln('  const _DashPainter({required this.color});')
    ..writeln()
    ..writeln('  static const _dash = 5.0;')
    ..writeln('  static const _gap = 3.0;')
    ..writeln('  static const _radius = 8.0;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void paint(Canvas canvas, Size size) {')
    ..writeln('    final paint = Paint()')
    ..writeln('      ..color = color')
    ..writeln('      ..style = PaintingStyle.stroke')
    ..writeln('      ..strokeWidth = 1;')
    ..writeln('    final rect = Offset.zero & size;')
    ..writeln('    final path = Path()')
    ..writeln(
      '      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_radius)));')
    ..writeln('    final metrics = path.computeMetrics().single;')
    ..writeln('    var distance = 0.0;')
    ..writeln('    while (distance < metrics.length) {')
    ..writeln('      final end = (distance + _dash).clamp(0.0, metrics.length);')
    ..writeln(
      '      canvas.drawPath(metrics.extractPath(distance, end), paint);')
    ..writeln('      distance += _dash + _gap;')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  bool shouldRepaint(covariant _DashPainter oldDelegate) =>')
    ..writeln('      oldDelegate.color != color;')
    ..writeln('}');

  for (final kind in _readyKinds.keys.toList()..sort()) {
    out.writeln(_builderSources[kind]);
  }

  out
    ..writeln('/// Full registry: every kit component id plus the `row`')
    ..writeln('/// pseudo-kind, grouped by [kRegistrySectionOrder] (kinds')
    ..writeln('/// alphabetical within a section).')
    ..writeln('final List<RegistryEntry> kRegistry = [');

  // Row pseudo-kind first (Layout Primitives).
  out
    ..writeln("  // Layout Primitives.")
    ..writeln('  RegistryEntry(')
    ..writeln("    kind: 'row',")
    ..writeln("    label: 'Row',")
    ..writeln("    section: 'Layout Primitives',")
    ..writeln('    icon: Icons.view_column,')
    ..writeln('    // Rows carry no items and lay out structurally in')
    ..writeln('    // ScreenSurface (see kContainerTiles); this builder renders')
    ..writeln('    // the same horizontal structure for standalone previews.')
    ..writeln('    build: (_) => const Row(')
    ..writeln('      mainAxisSize: MainAxisSize.min,')
    ..writeln('      children: [')
    ..writeln('        Icon(Icons.view_column, size: 20),')
    ..writeln('        SizedBox(width: 8),')
    ..writeln("        Text('Row'),")
    ..writeln('      ],')
    ..writeln('    ),')
    ..writeln('    canvasReady: true,')
    ..writeln('  ),');

  // Kit components grouped by section order, alphabetical within.
  final bySection = <String, List<Map<String, dynamic>>>{};
  for (final c in components) {
    final section = _sectionsByCategory[c['category'] as String]!;
    (bySection[section] ??= []).add(c);
  }
  for (final section in _sectionOrder.skip(1)) {
    final kinds = bySection[section] ?? [];
    out.writeln('  // $section.');
    for (final c in kinds) {
      final kind = c['id'] as String;
      final label = c['description'] as String;
      final icon = _icons[kind]!;
      final build = _bridgeKinds.contains(kind)
          ? "(context) => catalog.buildCatalogWithDefaults(${_dartStr(kind)})"
          : _readyKinds.containsKey(kind)
              ? '(context) => ${_readyKinds[kind]!}(${_defaultsRef(kind)})'
              : '(context) => RegistryPlaceholder(kind: ${_dartStr(kind)}, label: ${_dartStr(label)})';
      final ready = _bridgeKinds.contains(kind) || _readyKinds.containsKey(kind);
      out
        ..writeln('  RegistryEntry(')
        ..writeln('    kind: ${_dartStr(kind)},')
        ..writeln('    label: ${_dartStr(label)},')
        ..writeln('    section: ${_dartStr(section)},')
        ..writeln('    icon: $icon,')
        ..writeln('    build: $build,')
        ..writeln('    canvasReady: $ready,')
        ..writeln('  ),');
    }
  }
  out.writeln('];');

  // Output always lands in this package's lib/, wherever the kit was read from.
  final appRoot = File(Platform.script.toFilePath()).parent.parent;
  File('${appRoot.path}/lib/canvas/component_registry.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(out.toString());
  final ready =
      _bridgeKinds.length + _readyKinds.length + 1; // +1 for row.
  stdout.writeln(
    'emitted ${components.length + 1} entries ($ready canvas-ready)',
  );
}

/// Defaults-map reference for a [_readyKinds] builder call.
String _defaultsRef(String kind) {
  return switch (kind) {
    'chip' => 'kChipEntryDefaults',
    'alert' => 'kAlertEntryDefaults',
    'circular_progress_indicator' => 'kCircularProgressEntryDefaults',
    'linear_progress_indicator' => 'kLinearProgressEntryDefaults',
    'triple_dots' => 'kTripleDotsEntryDefaults',
    'dot_indicator' => 'kDotIndicatorEntryDefaults',
    'empty_state' => 'kEmptyStateEntryDefaults',
    'code_snippet' => 'kCodeSnippetEntryDefaults',
    'number_ticker' => 'kNumberTickerEntryDefaults',
    'text_area' => 'kTextAreaEntryDefaults',
    _ => throw ArgumentError('no defaults for $kind'),
  };
}
