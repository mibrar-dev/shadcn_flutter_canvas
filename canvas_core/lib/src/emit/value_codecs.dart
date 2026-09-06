/// G2 shared value codecs (Track G migration): §6.1 tagged-value collapse
/// rules + lenient raw-shape readers behind ONE implementation.
///
/// MOVED verbatim from `codegen_bundle.dart` (Track F `_bundlePrim*`
/// helpers): the bundle delegates to these (thin `_bundlePrim*` wrappers),
/// and the `code_builder` emitters in `expr_emitter.dart` compose the same
/// codecs — the string and AST emission paths cannot drift apart.
///
/// Pure Dart, Flutter-free, no dependencies beyond `tagged_value.dart`.
/// The prop-shape contract these codecs implement is documented above the
/// primitive emitters in `codegen_bundle.dart` (edgeInsets / color / radius
/// / border / gradient / shadow / alignment / axis shapes, §6.2 XOR rule).
library;

import 'tagged_value.dart';

/// Theme accessor used for token-bound values (never a raw hex — §6.1 rule).
const kPrimTheme = 'Theme.of(context)';

/// Whole flow doubles print without `.0`.
String formatPrimNum(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

/// Lenient double prop: raw num or tagged `{"$": "double", "v": …}` envelope.
double? primDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is Map && value[r'$'] == 'double' && value['v'] is num) {
    return (value['v'] as num).toDouble();
  }
  return null;
}

/// Lenient int prop with fallback.
int primInt(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

/// (`code`, `themed`) color expression from any color shape; null when
/// absent/unparseable. Map forms accept the tagged envelope AND the bare
/// `{kind: token|literal, …}` map (same leniency as the canvas builders —
/// canvas/codegen parity on hand-written docs).
({String code, bool themed})? primColor(Object? value) {
  final tagged = TaggedValue.parse(value);
  if (tagged is ColorValue) {
    return (
      code: tagged.toDart(kPrimTheme),
      themed: tagged.token != null
    );
  }
  if (value is Map) {
    if (value['kind'] == 'token' && value['token'] is String) {
      return (
        code: ColorValue.token(value['token'] as String).toDart(kPrimTheme),
        themed: true
      );
    }
    if (value['kind'] == 'literal' && value['argb'] is num) {
      return (
        code: ColorValue.literal((value['argb'] as num).toInt())
            .toDart(kPrimTheme),
        themed: false
      );
    }
    return null;
  }
  if (value is int) {
    return (
      code: ColorValue.literal(value).toDart(kPrimTheme),
      themed: false
    );
  }
  if (value is String) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    final full = hex.length == 6 ? 'FF$hex' : hex;
    final argb = full.length == 8 ? int.tryParse(full, radix: 16) : null;
    if (argb == null) return null;
    return (
      code: ColorValue.literal(argb).toDart(kPrimTheme),
      themed: false
    );
  }
  return null;
}

/// Collapsed `const EdgeInsets…` or null when absent/unparseable.
String? primEdge(Object? value) {
  final tagged = TaggedValue.parse(value);
  if (tagged is EdgeInsetsValue) {
    return 'const ${tagged.toDart(kPrimTheme)}';
  }
  if (value is num) {
    return 'const EdgeInsets.all(${formatPrimNum(value.toDouble())})';
  }
  if (value is Map) {
    if (value.keys.any((k) => k == 'l' || k == 't' || k == 'r' || k == 'b')) {
      double n(Object? x) => x is num ? x.toDouble() : 0.0;
      final parsed = EdgeInsetsValue(
        left: n(value['l']),
        top: n(value['t']),
        right: n(value['r']),
        bottom: n(value['b']),
      );
      return 'const ${parsed.toDart(kPrimTheme)}';
    }
  }
  return null;
}

/// Collapsed `BorderRadius…` (const-eligible, so callers add no prefix) or
/// null when absent/unparseable.
String? primRadius(Object? value) {
  final tagged = TaggedValue.parse(value);
  if (tagged is BorderRadiusValue) return tagged.toDart(kPrimTheme);
  if (value is num) {
    return 'BorderRadius.circular(${formatPrimNum(value.toDouble())})';
  }
  if (value is Map) {
    if (value.keys
        .any((k) => k == 'tl' || k == 'tr' || k == 'br' || k == 'bl')) {
      double n(Object? x) => x is num ? x.toDouble() : 0.0;
      final parsed = BorderRadiusValue(
        topLeft: n(value['tl']),
        topRight: n(value['tr']),
        bottomRight: n(value['br']),
        bottomLeft: n(value['bl']),
      );
      return parsed.toDart(kPrimTheme);
    }
  }
  return null;
}

/// Alignment expression (named-constant collapse) or null.
String? primAlign(Object? value) {
  final tagged = TaggedValue.parse(value);
  if (tagged is AlignmentValue) return tagged.toDart(kPrimTheme);
  if (value is String) {
    const names = {
      'topLeft',
      'topCenter',
      'topRight',
      'centerLeft',
      'center',
      'centerRight',
      'bottomLeft',
      'bottomCenter',
      'bottomRight',
    };
    if (names.contains(value)) return 'Alignment.$value';
    return null;
  }
  if (value is Map) {
    final x = value['x'];
    final y = value['y'];
    if (x is num && y is num) {
      return AlignmentValue(x.toDouble(), y.toDouble()).toDart(kPrimTheme);
    }
  }
  return null;
}

/// (`Border.all…`, `themed`) or null when absent/unparseable.
({String code, bool themed})? primBorder(Object? value) {
  if (value is! Map) return null;
  if (!value.containsKey('color') && !value.containsKey('width')) return null;
  final color = primColor(value['color']);
  final width = primDouble(value['width']) ?? 1.0;
  return (
    code: 'Border.all(color: ${color?.code ?? 'Color(0xFF000000)'}, '
        'width: ${formatPrimNum(width)})',
    themed: color?.themed ?? false,
  );
}

/// Alignment expression from a raw `{x,y}` map (gradient ends) with a named
/// fallback.
String primXy(Object? value, String fallback) {
  if (value is Map) {
    final x = value['x'];
    final y = value['y'];
    if (x is num && y is num) {
      return AlignmentValue(x.toDouble(), y.toDouble()).toDart(kPrimTheme);
    }
  }
  return fallback;
}

/// LinearGradient lines at decoration depth (4-space base) + themed flag, or
/// null when absent, empty, or unparseable (never a partial gradient).
({List<String> lines, bool themed})? primGradient(Object? value) {
  if (value is! Map) return null;
  final colors = value['colors'];
  if (colors is! List || colors.isEmpty) return null;
  final parts = <({String code, bool themed})>[];
  for (final c in colors) {
    final part = primColor(c);
    if (part == null) return null;
    parts.add(part);
  }
  List<double>? stops;
  if (value['stops'] is List) {
    final raw = (value['stops'] as List).whereType<num>().toList();
    if (raw.length == parts.length) {
      stops = [for (final s in raw) s.toDouble()];
    }
  }
  final themed = parts.any((p) => p.themed);
  final lines = <String>[
    '    gradient: ${themed ? '' : 'const '}LinearGradient(',
    '      begin: ${primXy(value['begin'], 'Alignment.centerLeft')},',
    '      end: ${primXy(value['end'], 'Alignment.centerRight')},',
    '      colors: [',
    for (final p in parts) '        ${p.code},',
    '      ],',
    if (stops != null)
      '      stops: [${stops.map(formatPrimNum).join(', ')}],',
    '    ),',
  ];
  return (lines: lines, themed: themed);
}

/// `boxShadow:` lines at decoration depth (4-space base) + themed flag, or
/// null when absent/empty (unparseable entries are skipped, never a crash).
/// Const lives on the list alone (`const` iff every stop is literal — a
/// `const` entry inside a themed list would trip `unnecessary_const` the
/// other way round, so entries never carry their own).
({List<String> lines, bool themed})? primShadows(Object? value) {
  if (value is! List || value.isEmpty) return null;
  final entries = <List<String>>[];
  var themed = false;
  for (final s in value) {
    if (s is! Map) continue;
    final color = primColor(s['color']);
    if (color?.themed ?? false) themed = true;
    double n(Object? x) => x is num ? x.toDouble() : 0.0;
    var ox = 0.0;
    var oy = 0.0;
    if (s['offset'] is Map) {
      ox = n((s['offset'] as Map)['x']);
      oy = n((s['offset'] as Map)['y']);
    }
    entries.add([
      '      BoxShadow(',
      '        color: ${color?.code ?? 'Color(0x40000000)'},',
      '        blurRadius: ${formatPrimNum(primDouble(s['blur']) ?? 0.0)},',
      '        spreadRadius: ${formatPrimNum(primDouble(s['spread']) ?? 0.0)},',
      '        offset: Offset(${formatPrimNum(ox)}, ${formatPrimNum(oy)}),',
      '      ),',
    ]);
  }
  if (entries.isEmpty) return null;
  return (
    lines: [
      '    boxShadow: ${themed ? '' : 'const '}[',
      for (final entry in entries) ...entry,
      '    ],',
    ],
    themed: themed,
  );
}

/// `mainAxisAlignment:` name or null when default/unparseable (omit).
String? primMainAxis(Object? value) {
  switch (value) {
    case 'center':
      return 'MainAxisAlignment.center';
    case 'end':
      return 'MainAxisAlignment.end';
    case 'spaceBetween':
      return 'MainAxisAlignment.spaceBetween';
    case 'spaceAround':
      return 'MainAxisAlignment.spaceAround';
    case 'spaceEvenly':
      return 'MainAxisAlignment.spaceEvenly';
    case 'start':
    default:
      return null;
  }
}

/// `crossAxisAlignment:` name or null when default/unparseable (omit).
String? primCrossAxis(Object? value) {
  switch (value) {
    case 'start':
      return 'CrossAxisAlignment.start';
    case 'end':
      return 'CrossAxisAlignment.end';
    case 'stretch':
      return 'CrossAxisAlignment.stretch';
    case 'center':
    default:
      return null;
  }
}

/// Gap prop with fallback, clamped to ≥ 0 (negative would crash layout).
double primGap(Map<String, dynamic> props, double fallback) {
  final gap = primDouble(props['gap']) ?? fallback;
  return gap < 0 ? 0 : gap;
}

/// Non-negative dim prop (negative would crash layout) or null when absent.
double? primDim(Object? value) {
  final parsed = primDouble(value);
  if (parsed == null) return null;
  return parsed < 0 ? 0 : parsed;
}

/// Flex prop clamped to ≥ 1 (Flutter asserts positive).
int primFlex(Object? value) {
  final flex = primInt(value, 1);
  return flex < 1 ? 1 : flex;
}
