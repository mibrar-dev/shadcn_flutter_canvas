/// G1 scaffold (Track G prep): tagged property values per BUILD_SPEC §6.1.
///
/// Props carry their **type and origin**, not bare JSON: `{ "$": "color",
/// "v": {...} }` instead of `"#FF0000"`. This file is Flutter-free
/// (canvas_core stays Flutter-free per §12 rule 6) and dependency-free:
/// G2 keeps these types verbatim and only swaps the `toDart` string surface
/// for `code_builder` expressions where the emitter needs AST structure.
///
/// Collapse rules (§6.1) live here because they are pure value logic:
/// `fromLTRB`→`.all`/`.symmetric`, uniform radius→`.circular`,
/// alignment→named constant. They are what make output read hand-written.
library;

/// Envelope tag names (the `$` field of a tagged prop).
abstract final class TaggedKind {
  static const doubleTag = 'double';
  static const intTag = 'int';
  static const boolTag = 'bool';
  static const stringTag = 'string';
  static const enumTag = 'enum';
  static const colorTag = 'color';
  static const edgeInsetsTag = 'edgeInsets';
  static const borderRadiusTag = 'borderRadius';
  static const alignmentTag = 'alignment';
  static const sizeTag = 'size';
  static const iconTag = 'icon';
  static const assetTag = 'asset';
  static const textStyleTag = 'textStyle';
}

/// A typed property value parsed from a `{ "$": tag, "v": ... }` envelope.
///
/// Parse with [TaggedValue.parse]; unknown tags or malformed envelopes yield
/// null so callers fall back to raw-prop handling (never a throw — export
/// must not crash on hand-written JSON).
sealed class TaggedValue {
  const TaggedValue();

  /// Parses one tagged envelope. Returns null when [json] is not a tagged
  /// envelope or the tag is unknown.
  static TaggedValue? parse(Object? json) {
    if (json is! Map) return null;
    final tag = json[r'$'];
    final v = json['v'];
    if (tag is! String) return null;
    switch (tag) {
      case TaggedKind.doubleTag:
        if (v is num) return DoubleValue(v.toDouble());
      case TaggedKind.intTag:
        if (v is num) return IntValue(v.toInt());
      case TaggedKind.boolTag:
        if (v is bool) return BoolValue(v);
      case TaggedKind.stringTag:
        if (v is String) return StringValue(v);
      case TaggedKind.enumTag:
        if (v is Map && v['owner'] is String && v['name'] is String) {
          return EnumValue(v['owner'] as String, v['name'] as String);
        }
      case TaggedKind.colorTag:
        return ColorValue.parse(v);
      case TaggedKind.edgeInsetsTag:
        return EdgeInsetsValue.parse(v);
      case TaggedKind.borderRadiusTag:
        return BorderRadiusValue.parse(v);
      case TaggedKind.alignmentTag:
        return AlignmentValue.parse(v);
      case TaggedKind.sizeTag:
        return SizeValue.parse(v);
      case TaggedKind.iconTag:
        if (v is String) return IconValue(v);
      case TaggedKind.assetTag:
        if (v is String) return AssetValue(v);
      case TaggedKind.textStyleTag:
        if (v is Map && v['token'] is String) {
          return TextStyleValue(v['token'] as String);
        }
    }
    return null;
  }

  /// Emits the Dart source for this value.
  ///
  /// [theme] is the theme accessor expression (normally
  /// `EmitContext.themeExpr`, i.e. `Theme.of(context)`): token-bound values
  /// resolve through it, never to a raw hex (§6.1 rule).
  String toDart(String theme);
}

/// `{"$": "double", "v": 16}` → `16.0`.
final class DoubleValue extends TaggedValue {
  final double value;
  const DoubleValue(this.value);

  @override
  String toDart(String theme) => '$value';
}

/// `{"$": "int", "v": 2}` → `2`.
final class IntValue extends TaggedValue {
  final int value;
  const IntValue(this.value);

  @override
  String toDart(String theme) => '$value';
}

/// `{"$": "bool", "v": true}` → `true`.
final class BoolValue extends TaggedValue {
  final bool value;
  const BoolValue(this.value);

  @override
  String toDart(String theme) => '$value';
}

/// `{"$": "string", "v": "Hello"}` → `'Hello'` (single-quoted, escaped).
final class StringValue extends TaggedValue {
  final String value;
  const StringValue(this.value);

  @override
  String toDart(String theme) => _quote(value);

  /// Single-quotes [s], escaping backslashes, single quotes, and newlines.
  static String _quote(String s) {
    final escaped = s
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
    return "'$escaped'";
  }

  /// Public alias for emitter use on raw (untagged) strings.
  static String quote(String s) => _quote(s);
}

/// `{"$": "enum", "v": {"owner": "MainAxisAlignment", "name": "start"}}`
/// → `MainAxisAlignment.start`.
final class EnumValue extends TaggedValue {
  final String owner;
  final String name;
  const EnumValue(this.owner, this.name);

  @override
  String toDart(String theme) => '$owner.$name';
}

/// `{"$": "color", "v": {...}}`.
///
/// Token form resolves to an accessor, never a hex:
/// `{ "kind": "token", "token": "primary" }` →
/// `Theme.of(context).colorScheme.primary`.
/// Literal form emits ARGB: `{ "kind": "literal", "argb": 0xFFEF4444 }` →
/// `Color(0xFFEF4444)`.
final class ColorValue extends TaggedValue {
  final String? token;
  final int? argb;
  const ColorValue.token(this.token) : argb = null;
  const ColorValue.literal(this.argb) : token = null;

  static ColorValue? parse(Object? v) {
    if (v is! Map) return null;
    if (v['kind'] == 'token' && v['token'] is String) {
      return ColorValue.token(v['token'] as String);
    }
    if (v['kind'] == 'literal' && v['argb'] is num) {
      return ColorValue.literal((v['argb'] as num).toInt());
    }
    return null;
  }

  @override
  String toDart(String theme) {
    if (token != null) return '$theme.colorScheme.$token';
    final hex = argb!.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return 'Color(0x${hex.toUpperCase()})';
  }
}

/// `{"$": "edgeInsets", "v": {"l":16,"t":8,"r":16,"b":8}}`.
///
/// Collapse rules (§6.1): uniform → `.all`, mirrored pairs →
/// `.symmetric`, otherwise `.fromLTRB`. Uniform zero → `.zero`.
final class EdgeInsetsValue extends TaggedValue {
  final double left;
  final double top;
  final double right;
  final double bottom;
  const EdgeInsetsValue({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  static double _num(Object? v) => v is num ? v.toDouble() : 0.0;

  static EdgeInsetsValue? parse(Object? v) {
    if (v is! Map) return null;
    return EdgeInsetsValue(
      left: _num(v['l']),
      top: _num(v['t']),
      right: _num(v['r']),
      bottom: _num(v['b']),
    );
  }

  /// Collapsed constructor name: `all`, `symmetric`, `zero`, or `fromLTRB`.
  String get collapsedKind {
    if (left == 0 && top == 0 && right == 0 && bottom == 0) return 'zero';
    if (left == top && top == right && right == bottom) return 'all';
    if (left == right && top == bottom) return 'symmetric';
    return 'fromLTRB';
  }

  static String _n(double d) =>
      d == d.truncateToDouble() ? d.toInt().toString() : '$d';

  @override
  String toDart(String theme) {
    switch (collapsedKind) {
      case 'zero':
        return 'EdgeInsets.zero';
      case 'all':
        return 'EdgeInsets.all(${_n(left)})';
      case 'symmetric':
        return 'EdgeInsets.symmetric(horizontal: ${_n(left)}, '
            'vertical: ${_n(top)})';
      case 'fromLTRB':
        return 'EdgeInsets.fromLTRB('
            '${_n(left)}, ${_n(top)}, ${_n(right)}, ${_n(bottom)})';
    }
    throw StateError('unreachable');
  }
}

/// `{"$": "borderRadius", "v": {"tl":12,"tr":12,"br":12,"bl":12}}` →
/// `BorderRadius.circular(12)` when uniform, else
/// `BorderRadius.only(topLeft: Radius.circular(..), ...)`.
final class BorderRadiusValue extends TaggedValue {
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;
  const BorderRadiusValue({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  static BorderRadiusValue? parse(Object? v) {
    if (v is! Map) return null;
    return BorderRadiusValue(
      topLeft: EdgeInsetsValue._num(v['tl']),
      topRight: EdgeInsetsValue._num(v['tr']),
      bottomRight: EdgeInsetsValue._num(v['br']),
      bottomLeft: EdgeInsetsValue._num(v['bl']),
    );
  }

  bool get isUniform =>
      topLeft == topRight &&
      topRight == bottomRight &&
      bottomRight == bottomLeft;

  @override
  String toDart(String theme) {
    if (isUniform) {
      return 'BorderRadius.circular(${EdgeInsetsValue._n(topLeft)})';
    }
    String corner(String name, double d) =>
        '$name: Radius.circular(${EdgeInsetsValue._n(d)})';
    return 'BorderRadius.only(${corner('topLeft', topLeft)}, '
        '${corner('topRight', topRight)}, '
        '${corner('bottomLeft', bottomLeft)}, '
        '${corner('bottomRight', bottomRight)})';
  }
}

/// `{"$": "alignment", "v": {"x": 0.0, "y": -1.0}}` → `Alignment.topCenter`
/// when the pair matches a named constant, else `Alignment(x, y)`.
final class AlignmentValue extends TaggedValue {
  final double x;
  final double y;
  const AlignmentValue(this.x, this.y);

  static AlignmentValue? parse(Object? v) {
    if (v is! Map) return null;
    return AlignmentValue(
      EdgeInsetsValue._num(v['x']),
      EdgeInsetsValue._num(v['y']),
    );
  }

  static const _named = <String, (double, double)>{
    'topLeft': (-1.0, -1.0),
    'topCenter': (0.0, -1.0),
    'topRight': (1.0, -1.0),
    'centerLeft': (-1.0, 0.0),
    'center': (0.0, 0.0),
    'centerRight': (1.0, 0.0),
    'bottomLeft': (-1.0, 1.0),
    'bottomCenter': (0.0, 1.0),
    'bottomRight': (1.0, 1.0),
  };

  /// Named constant (`topCenter`) or null when custom.
  String? get namedConstant {
    for (final entry in _named.entries) {
      if (entry.value.$1 == x && entry.value.$2 == y) return entry.key;
    }
    return null;
  }

  @override
  String toDart(String theme) {
    final named = namedConstant;
    if (named != null) return 'Alignment.$named';
    return 'Alignment(${EdgeInsetsValue._n(x)}, ${EdgeInsetsValue._n(y)})';
  }
}

/// Sizing intent (§7.2 vocabulary, emitter-side read):
/// `{ "mode": "fixed"|"expand"|"hug", "value": 120 }`.
/// fixed → width/height argument; expand → `Expanded` wrapper (flex on the
/// child node); hug → omit (intrinsic).
final class SizeValue extends TaggedValue {
  final String mode;
  final double? value;
  const SizeValue(this.mode, [this.value]);

  static SizeValue? parse(Object? v) {
    if (v is! Map) return null;
    final mode = v['mode'];
    if (mode is! String) return null;
    if (mode != 'fixed' && mode != 'expand' && mode != 'hug') return null;
    final raw = v['value'];
    return SizeValue(mode, raw is num ? raw.toDouble() : null);
  }

  @override
  String toDart(String theme) =>
      throw UnsupportedError('SizeValue shapes its parent; no literal form');
}

/// `{"$": "icon", "v": "add"}` → `Icons.add`.
final class IconValue extends TaggedValue {
  final String name;
  const IconValue(this.name);

  @override
  String toDart(String theme) => 'Icons.$name';
}

/// `{"$": "asset", "v": "assets/logo.png"}` → quoted path; the project
/// writer adds the matching `assets/` entry to the emitted pubspec.
final class AssetValue extends TaggedValue {
  final String path;
  const AssetValue(this.path);

  @override
  String toDart(String theme) => StringValue.quote(path);
}

/// `{"$": "textStyle", "v": {"token": "titleLarge"}}` →
/// `Theme.of(context).textTheme.titleLarge` (see §6.3 worked example).
final class TextStyleValue extends TaggedValue {
  final String token;
  const TextStyleValue(this.token);

  @override
  String toDart(String theme) => '$theme.textTheme.$token';
}
