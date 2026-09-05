/// Deterministic ScreenDoc → paste-into-AI prompt exporter.
///
/// Pure Dart: no Flutter imports, so the CLI can reuse it.
import 'screen_doc.dart';

/// Builds the paste-into-AI prompt for [doc].
///
/// Section order: title/brief → target → palette hex rows → theme lines →
/// per-screen layout → behavior → per-kind style notes → general rules.
/// Throws [StateError] when [ScreenDoc.validateRefs] reports dangling actions.
String buildPrompt(ScreenDoc doc) {
  final dangling = doc.validateRefs();
  if (dangling.isNotEmpty) {
    throw StateError('ScreenDoc has dangling actions: ${dangling.join(', ')}');
  }
  final sections = <String>[
    '# ${doc.meta.title}\n\n${doc.meta.brief}',
    'Target: 390x844 logical pixels, Android and iOS, ThemeMode.system.',
    _paletteSection(doc),
    _themeSection(doc),
    _screensSection(doc),
    _behaviorSection(doc),
    _styleNotesSection(doc),
    _rulesSection(),
  ];
  return '${sections.join('\n\n')}\n';
}

/// Editable override: a non-blank [override] (the `promptEdit` text) wins,
/// mirroring m3e `effectivePrompt`.
String effectivePrompt(ScreenDoc doc, {String? override}) {
  if (override != null && override.trim().isNotEmpty) return override;
  return buildPrompt(doc);
}

const _palettes = <String, Map<String, String>>{
  'slate-light': {
    'background': '#FFFFFF',
    'foreground': '#020617',
    'primary': '#334155',
    'muted': '#F1F5F9',
  },
  'slate-dark': {
    'background': '#020617',
    'foreground': '#F8FAFC',
    'primary': '#94A3B8',
    'muted': '#1E293B',
  },
  'indigo-light': {
    'background': '#FFFFFF',
    'foreground': '#1E1B4B',
    'primary': '#4F46E5',
    'muted': '#EEF2FF',
  },
  'indigo-dark': {
    'background': '#0B0A24',
    'foreground': '#E0E7FF',
    'primary': '#818CF8',
    'muted': '#1E1B4B',
  },
  'emerald-light': {
    'background': '#FFFFFF',
    'foreground': '#022C22',
    'primary': '#059669',
    'muted': '#ECFDF5',
  },
  'emerald-dark': {
    'background': '#022C22',
    'foreground': '#D1FAE5',
    'primary': '#34D399',
    'muted': '#064E3B',
  },
};

const _radii = <String, String>{
  'rounded': '0.625rem',
  'sharp': '0',
  'pill': '9999px',
};

const _styleNotes = <String, String>{
  'badge':
      'use Badge with label and variant from props.',
  'button':
      'use Button with the theme variant; map disabled to enabled=false.',
  'card': 'use Card with title and description slots.',
  'checkbox': 'use Checkbox with label; bind value to state.',
  'input':
      'use TextField with placeholder and label; obscure for passwords.',
  'switch': 'use Switch bound to a bool value.',
};

String _paletteSection(ScreenDoc doc) {
  final key = doc.theme.paletteKey;
  final mode = doc.theme.dark ? 'dark' : 'light';
  final rows = _palettes['$key-$mode'] ?? _palettes['slate-$mode']!;
  final lines = [for (final e in rows.entries) '- ${e.key}: ${e.value}'];
  return 'Palette ($key, $mode):\n${lines.join('\n')}';
}

String _themeSection(ScreenDoc doc) {
  final theme = doc.theme;
  final radius = _radii[theme.shape] ?? '0.625rem';
  final mode = theme.dark ? 'dark' : 'light';
  return 'Theme:\n'
      '- shape: ${theme.shape} (radius $radius, shadcn preset)\n'
      '- mode: $mode\n'
      '- motion: ${theme.motion}';
}

String _screensSection(ScreenDoc doc) {
  final blocks = <String>[];
  for (final screen in doc.screens) {
    // Orphans (parentId pointing at a missing node) render as roots so the
    // brief never silently drops nodes.
    final ids = {for (final n in doc.nodes) n.id};
    final roots = [
      for (final n in doc.nodes)
        if (n.screenId == screen.id &&
            (n.parentId == null || !ids.contains(n.parentId))) n,
    ]..sort((a, b) {
        final dy = a.y.compareTo(b.y);
        return dy != 0 ? dy : a.x.compareTo(b.x);
      });
    final rows = [
      for (final n in roots) ..._nodeRows(doc, n, 0),
    ];
    blocks.add(
      '## ${_routeOf(screen.name)} (${screen.name})\n'
      '${rows.isEmpty ? '- (empty)' : rows.join('\n')}',
    );
  }
  return 'Screens:\n\n${blocks.join('\n\n')}';
}

/// Brief lines for [node] at indent [level].
///
/// Leaf items keep the exact legacy `- kind "label" (...) at (x, y)` format.
/// Row containers add one header line noting their gap, with their own items
/// and row children indented one level underneath (recurses for nesting).
List<String> _nodeRows(ScreenDoc doc, CanvasNode node, int level) {
  final pad = '  ' * level;
  if (!node.isRow) {
    // Root leaves keep the legacy positioned format; row children flow, so
    // their stored x/y would be noise.
    final positioned = node.parentId == null;
    return [
      for (final i in node.items)
        '$pad${_itemRow(node, i, positioned: positioned)}',
    ];
  }
  final header = StringBuffer('$pad- row (gap ${_num(node.gap)}');
  if (node.mainAxis != null) header.write(', main ${node.mainAxis}');
  if (node.crossAxis != null) header.write(', cross ${node.crossAxis}');
  header.write(')');
  final lines = <String>[header.toString()];
  for (final item in node.items) {
    lines.add('  $pad${_itemRow(node, item, positioned: false)}');
  }
  // Row children follow document (insertion) order: their x/y are flow
  // metadata, not positions.
  for (final child in doc.nodes) {
    if (child.parentId == node.id) {
      lines.addAll(_nodeRows(doc, child, level + 1));
    }
  }
  return lines;
}

String _behaviorSection(ScreenDoc doc) {
  final routes = {for (final s in doc.screens) s.id: _routeOf(s.name)};
  final lines = <String>[];
  for (final node in doc.nodes) {
    for (final item in node.items) {
      final to = item.action?.to;
      if (to != null) {
        lines.add('- Tapping ${_labelOf(item)} pushes ${routes[to] ?? '/$to'}.');
      }
    }
  }
  return 'Behavior:\n'
      '${lines.isEmpty ? '- No navigation actions.' : lines.join('\n')}';
}

String _styleNotesSection(ScreenDoc doc) {
  final kinds = {
    for (final n in doc.nodes)
      for (final i in n.items) i.kind,
  }.toList()
    ..sort();
  final lines = kinds.isEmpty
      ? const ['- (none)']
      : [for (final k in kinds) '- $k: ${_styleNoteFor(k)}'];
  return 'Style notes:\n${lines.join('\n')}';
}

String _rulesSection() => '''Rules:
- Follow flutter_lints.
- Read colors via Theme.of(context); no hard-coded colors.
- Add gap and data_widget to pubspec dependencies where used.
- Use real data with validation and empty states.''';

String _itemRow(CanvasNode node, CanvasItem item, {bool positioned = true}) {
  final detail = _detailOf(item);
  final at = positioned ? ' at (${_num(node.x)}, ${_num(node.y)})' : '';
  return '- ${item.kind} "${_labelOf(item)}"'
      '${detail.isEmpty ? '' : ' ($detail)'}$at';
}

String _labelOf(CanvasItem item) {
  for (final key in ['label', 'title', 'placeholder']) {
    final value = item.props[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return item.kind;
}

String _detailOf(CanvasItem item) {
  final keys = item.props.keys
      .where((k) => k != 'label' && k != 'title' && k != 'placeholder')
      .toList()
    ..sort();
  return keys.map((k) => '$k ${item.props[k]}').join(', ');
}

String _styleNoteFor(String kind) =>
    _styleNotes[kind] ?? 'use the $kind component with props from above.';

String _routeOf(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return '/${slug.isEmpty ? 'screen' : slug}';
}

String _num(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
