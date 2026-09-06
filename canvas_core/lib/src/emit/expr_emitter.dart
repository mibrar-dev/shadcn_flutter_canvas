/// G2 `code_builder` migration (Track G wave G2): Expression-based emission
/// for the ten layout primitives, behind the existing `_bundleX` signatures.
///
/// SHAPE (BUILD_SPEC §6.4, literal):
/// ```dart
/// abstract class AstEmitter {
///   String get type;
///   Expression emitExpr(item, node, children, ctx);
/// }
/// ```
///
/// WHAT MIGRATED vs WHAT WRAPPED (honest ledger — see `docs/BUILD_G2_*.md`):
/// * Migrated (10/97 kind emitters): the Track F layout primitives
///   (`container`, `column`, `row`, `stack`, `padding`, `center`, `align`,
///   `expanded`, `sized_box`, `spacer`). Each builds a real `code_builder`
///   invocation tree: constructor selection, named-arg presence/order, child
///   composition, responsive leaf wrapping, and the §6.2 color-XOR-decoration
///   branch are AST decisions. Canonical text comes from ONE `dart_style`
///   pass ([formatExpression]), so output is byte-identical to `dart format`
///   by construction (gate 3 direction).
/// * Wrapped (opaque [Code] leaves): `const` constructor calls and hex color
///   literals. `code_builder` cannot model `const` invocations, so const
///   values flow through the SINGLE-SOURCED string codecs
///   (`emit/value_codecs.dart`, also used by the legacy string path) wrapped
///   in [Code] — the collapse rules (§6.1) still have exactly one
///   implementation, and the string/AST paths cannot drift.
/// * Untouched (87/97): every kit-widget `_bundleX` emitter stays pure-string
///   until G3. Routing one through the formatter would COLLAPSE its pinned
///   multi-line shape (formatter joins short widgets to one line) and break
///   hundreds of F goldens — the cutover re-bases goldens post-format in G4
///   (per the G1 design doc §8), not here.
///
/// IMPORTS (priority (a)): emitters declare dependencies into
/// [EmitContext.imports] ([AstEmitter.collectImports]); the page
/// writer renders the header SOLELY from the collector — no hand-merged
/// per-kind import tables on the new path. [importDirectives] converts the
/// collector to `code_builder` [Directive]s (unit-pinned); page files render
/// the equivalent `collector.lines` strings for `buildPageFile` compat.
///
/// TOKENS (priority (b)): token colors compose the real property chain
/// `Theme.of(context).colorScheme.<token>` ([ColorValueX]); literals stay
/// `Color(0xFF…)` via the shared codec. The legacy bundle already routes
/// primitive colors this way (Track F); this file makes the AST path match.
///
/// Flutter-free (canvas_core rule §12.6): `code_builder` + `dart_style` are
/// pure Dart.
library;

import 'package:code_builder/code_builder.dart' hide EnumValue;
import 'package:dart_style/dart_style.dart';

import '../screen_doc.dart';
import 'emit_context.dart';
import 'project_writer.dart';
import 'tagged_value.dart';
import 'value_codecs.dart';
import 'widget_emitter.dart';

/// One emitter per registry type key, AST edition (§6.4).
///
/// Mirrors the legacy `_bundleX(props)` functions 1:1 (mechanical, not a
/// redesign). [emitExpr] returns the widget invocation; [ctx.emitChild] is
/// NOT used here — the page walker ([emitPrimitivePageFiles]) supplies
/// already-emitted child [Expression]s positionally, exactly like the legacy
/// `nested` blocks.
abstract class AstEmitter {
  /// Const base so implementations keep const constructors.
  const AstEmitter();

  /// Registry type key, e.g. `"container"`.
  String get type;

  /// Builds the widget expression, composing [children] positionally.
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  );

  /// Declares this kind's imports into [ctx]. Default: Flutter material
  /// (primitives are raw Flutter, kit-first exempt per §7.1).
  void collectImports(EmitContext ctx) {
    ctx.imports.add('package:flutter/material.dart');
  }
}

/// [TaggedValue] as a `code_builder` expression (priority (b)+(c)).
///
/// Collapse rules (§6.1) come from the parsed VALUE (single source: the
/// `TaggedValue` subtypes), never re-implemented: uniform insets pick the
/// collapsed constructor, named alignments pick the constant. `const`
/// constructor calls are opaque [Code] leaves built from [TaggedValue.toDart]
/// (verbatim single source — `code_builder` has no `const` invocation
/// model); everything else is structured AST off [theme].
extension TaggedValueExpr on TaggedValue {
  /// Structured form of [theme] (`Theme.of(context)` →
  /// `refer('Theme').property('of').call([refer('context')])`); any other
  /// accessor (tests use `'T'`) flows through opaquely but still composes.
  static Expression themeOf(String theme) {
    if (theme == kPrimTheme || theme == 'Theme.of(context)') {
      return refer('Theme')
          .property('of')
          .call([refer('context')]);
    }
    return CodeExpression(Code(theme));
  }

  /// AST edition of [TaggedValue.toDart].
  Expression toExpression(String theme) {
    final self = this;
    switch (self) {
      // Mirrors toDart exactly (no integral collapse: `16.0` stays `16.0`;
      // flow-number shortening lives in the dim codecs, not in values).
      case DoubleValue(value: final v):
        return literalNum(v);
      case IntValue(value: final v):
        return literalNum(v);
      case BoolValue(value: final v):
        return literalBool(v);
      // Quote style may differ from StringValue.quote (code_builder picks
      // quotes by content); both are valid Dart. v1 adapters emit no raw
      // strings, so no golden depends on this.
      case StringValue(value: final v):
        return literalString(v);
      case EnumValue(owner: final o, name: final n):
        return refer(o).property(n);
      case ColorValue(:final token):
        if (token != null) {
          return TaggedValueExpr.themeOf(theme)
              .property('colorScheme')
              .property(token);
        }
        // Hex literals: opaque single-source leaf (see above).
        return CodeExpression(Code(self.toDart(theme)));
      case EdgeInsetsValue(collapsedKind: 'zero'):
        // Already-const accessor: no `const` keyword (mirrors the legacy
        // codec, which emits bare `EdgeInsets.zero`).
        return CodeExpression(Code(self.toDart(theme)));
      case EdgeInsetsValue():
      case BorderRadiusValue():
        return CodeExpression(Code('const ${self.toDart(theme)}'));
      case AlignmentValue(namedConstant: final n?):
        return refer('Alignment').property(n);
      case AlignmentValue(x: final x, y: final y):
        return refer('Alignment').newInstance([
          CodeExpression(Code(formatPrimNum(x))),
          CodeExpression(Code(formatPrimNum(y))),
        ]);
      case SizeValue():
        throw UnsupportedError(
            'SizeValue shapes its parent; no expression form');
      case IconValue(name: final n):
        return refer('Icons').property(n);
      case AssetValue(path: final p):
        return literalString(p);
      case TextStyleValue(token: final t):
        return TaggedValueExpr.themeOf(theme).property('textTheme').property(t);
    }
  }
}

/// Prefixes a `const` invocation: `code_builder` has no const model, so the
/// ALREADY-BUILT inner source is wrapped (deterministic: inner source comes
/// from [DartEmitter], never hand-shaped).
Expression constOf(Expression inner) =>
    CodeExpression(Code('const ${inner.accept(DartEmitter())}'));

/// Whether [e] renders const-eligible source (gate 4 viral-const rule):
/// structured `code_builder` invocations never spell `const` (no const
/// model — see [constOf]), so a leading `const ` prefix marks EXACTLY the
/// const leaves (const templates + [constOf] results). Not heuristic: every
/// const emitter in this layer spells through those paths, so parents can
/// decide their own constness exactly from it. See [stripConst] for the
/// other half: a consting parent absorbs the keyword, children go bare.
bool isConstExpr(Expression e) =>
    e.accept(DartEmitter()).toString().startsWith('const ');

/// Strips the leading `const ` from a const-eligible source (gate 4
/// canonical-const rule): a consting parent absorbs the keyword into its
/// own const context, where the nested keyword would read as
/// `unnecessary_const` — `const` belongs on the OUTERMOST eligible
/// invocation only (`prefer_const_constructors` + `unnecessary_const`
/// together demand exactly that). Only the leading keyword goes: inner
/// keywords are absent by construction (composites strip-then-const
/// bottom-up, so an eligible composite's interior is already bare).
/// Non-const sources pass through untouched.
Expression stripConst(Expression e) {
  const prefix = 'const ';
  final src = e.accept(DartEmitter()).toString();
  if (!src.startsWith(prefix)) return e;
  return CodeExpression(Code(src.substring(prefix.length)));
}

/// Canonical source for [expression] at depth 0: single [DartEmitter] pass
/// wrapped in a dummy `final` so [DartFormatter] (= `dart format`) lays it
/// out, then unwrapped.
///
/// TRAILING-COMMA POLICY (measured, do not "simplify"): `code_builder`
/// emits trailing commas after every argument of a multi-arg invocation,
/// and the formatter treats them as hard splits — multi-arg widgets ALWAYS
/// take the full-split (+2 block) form, single-arg widgets stay one line
/// when short. Stripping the commas before formatting looks prettier for
/// short multis (minimal splits) but the result is NOT a formatter
/// fixpoint (reformat re-splits at a different indent), which would fail
/// gate 3 (`dart format --set-exit-if-changed`). Canonical + stable beats
/// compact: keep the commas.
///
/// Multi-line results carry depth-0 (2-space-nested) indentation; page
/// assembly shifts them (see [emitPage]).
String formatExpression(Expression expression) {
  final raw = expression.accept(DartEmitter()).toString();
  final formatted = DartFormatter().format('final _v = $raw;\n').trimRight();
  const prefix = 'final _v = ';
  assert(formatted.startsWith(prefix), 'formatter rewrote the stub: $raw');
  final body = formatted.substring(prefix.length);
  assert(body.endsWith(';'), 'formatter dropped the stub semi: $raw');
  return body.substring(0, body.length - 1);
}

/// Renders [collector] as `code_builder` import directives in collector
/// order (dart → package → relative, each sorted — the [ImportCollector.lines]
/// contract, G1-pinned). `as` prefixes survive (the `tabs` barrel case), as
/// do `show`/`hide` combinators (the §8.4 clash-hygiene case; overlong
/// lines arrive pre-wrapped and are flattened before parsing).
List<Directive> importDirectives(ImportCollector collector) {
  final out = <Directive>[];
  for (final line in collector.lines) {
    final flat = line.split(RegExp(r'\s+')).join(' ');
    final match = RegExp(
      r"^import '([^']+)'( as (\w+))?( show ([\w, ]+?))?( hide ([\w, ]+?))?;$",
    ).firstMatch(flat);
    if (match == null) continue;
    List<String> names(String? raw) => [
          for (final n in (raw ?? '').split(',')) n.trim(),
        ]..removeWhere((n) => n.isEmpty);
    out.add(Directive.import(
      match.group(1)!,
      as: match.group(3),
      show: names(match.group(5)),
      hide: names(match.group(7)),
    ));
  }
  return out;
}

/// Wraps [base] in the §8.4 responsive leaf when [node] overrides [prop] on
/// a page tier: values branch, subtrees never duplicate. Tablet feeds the
/// `md:` slot (mobile-first: base IS the mobile value); desktop is the
/// fallback tier. Unknown/unparseable overrides fall back to [base] — export
/// never crashes on hand-written docs. [renderMd] reuses the shared string
/// codecs on the override's raw value (single source with the base path).
///
/// The call itself is an opaque single-line template (like the `const`
/// leaves): `responsiveValue(context, base: <base>, md: <md>)` — exactly
/// the §8.4 spec shape, so short leaves stay one line. The AST owns the
/// decision (which arg, when wrapped); the template owns only punctuation.
Expression withTabletLeaf({
  required Expression base,
  required CanvasNode node,
  required String prop,
  required String? Function(Object? raw) renderMd,
}) {
  for (final tier in const ['tablet', 'desktop']) {
    final overrides = node.breakpointValues[tier];
    if (overrides == null || !overrides.containsKey(prop)) continue;
    final md = renderMd(overrides[prop]);
    if (md == null) return base;
    return leaf(
      'responsiveValue(context, base: ${base.accept(DartEmitter())}, md: $md)',
    );
  }
  return base;
}

/// Whether [node] carries a usable [prop] override on a page tier (drives
/// `const` elision: a responsive leaf is never const).
bool hasTabletOverride(CanvasNode node, String prop) {
  for (final tier in const ['tablet', 'desktop']) {
    final overrides = node.breakpointValues[tier];
    if (overrides != null && overrides.containsKey(prop)) return true;
  }
  return false;
}

/// Opaque value leaf from a shared string codec (single source with the
/// legacy path): [code] MUST come from `emit/value_codecs.dart`.
Expression leaf(String code) => CodeExpression(Code(code));

/// Gap separator between flow children (mirrors the legacy
/// `_bundlePrimChildren` rhythm exactly, incl. the `const`).
Expression gapLeaf(double gap, bool vertical) => leaf(
      vertical
          ? 'const SizedBox(height: ${formatPrimNum(gap)})'
          : 'const SizedBox(width: ${formatPrimNum(gap)})',
    );

/// Interleaves [gap] separators between [children] (none for 0/1 child).
List<Expression> withSeparators(
  List<Expression> children,
  double gap,
  bool vertical,
) {
  if (children.length < 2) return children;
  final sep = gapLeaf(gap, vertical);
  final out = <Expression>[children.first];
  for (final child in children.skip(1)) {
    out.addAll([sep, child]);
  }
  return out;
}

/// Single-slot `child:` composition (COMPOSITION.md §2.1, mirrors the legacy
/// `_bundlePrimChildArg` shapes): no child → omit; one → `child:`; several
/// → a min-Column with 12-gap separators (the below-fallback rhythm).
/// Const-propagating (gate 4 viral-const rule): the min-Column's own args
/// are unconditionally const-eligible (fixed enums), so an all-const child
/// set yields `const` exactly (see [constAwareColumn]).
Map<String, Expression> childArg(List<Expression> children) {
  if (children.isEmpty) return const {};
  if (children.length == 1) return {'child': children.single};
  return {
    'child': constAwareColumn(
      children,
      gap: 12,
      extraArgs: {
        'mainAxisSize': leaf('MainAxisSize.min'),
        'crossAxisAlignment': leaf('CrossAxisAlignment.start'),
      },
    ),
  };
}

/// Const-propagating multi-child `Column(children:)` over [blocks]
/// (gate 4 viral-const rule): the Column's own args are [extraArgs] (fixed
/// const-eligible enums at every call site) plus the children list, so an
/// all-const child set ([isConstExpr]) yields `const` exactly — now-const
/// children would otherwise make the eligible parent fire
/// `prefer_const_constructors`. The list itself stays BARE (implicitly const
/// inside the const invocation); consting absorbs the children's keywords
/// via [stripConst] so no nested `const` reads as `unnecessary_const`.
/// [gap] interleaves const gap separators (null = bare join, for
/// already-separated sources).
Expression constAwareColumn(
  List<Expression> blocks, {
  double? gap,
  bool vertical = true,
  Map<String, Expression> extraArgs = const {},
}) {
  final allConst = blocks.every(isConstExpr);
  var parts = gap == null ? blocks : withSeparators(blocks, gap, vertical);
  if (allConst) parts = [for (final p in parts) stripConst(p)];
  final joined = parts.map((b) => b.accept(DartEmitter())).join(',\n');
  var column = refer('Column').newInstance([], {
    ...extraArgs,
    'children': leaf('[$joined]'),
  });
  if (allConst) column = constOf(column);
  return column;
}

/// `children:` list composition with [gap] separators (column/row bodies).
/// Always a bare list: inside a consting parent it is implicitly const;
/// in a non-const parent an all-const list never arises (Column/Row const
/// themselves exactly when their children are all const — see below).
/// [strip] absorbs every part keyword (children AND gap separators) into
/// the consting parent's context ([stripConst] is idempotent, so
/// pre-stripped children pass through untouched).
Expression childrenList(
  List<Expression> children,
  double gap,
  bool vertical, {
  bool strip = false,
}) {
  var parts = withSeparators(children, gap, vertical);
  if (strip) parts = [for (final p in parts) stripConst(p)];
  final joined = parts.map((c) => c.accept(DartEmitter())).join(',\n');
  return leaf('[$joined]');
}

/// LinearGradient as AST (mirrors the [primGradient] rule: null when absent,
/// empty, or ANY stop unparseable — never a partial gradient; `stops` only
/// when the count matches). Value leaves reuse the shared codecs.
Expression? gradientExpr(Object? value) {
  if (value is! Map) return null;
  final colors = value['colors'];
  if (colors is! List || colors.isEmpty) return null;
  final parts = <String>[];
  var themed = false;
  for (final c in colors) {
    final part = primColor(c);
    if (part == null) return null;
    if (part.themed) themed = true;
    parts.add(part.code);
  }
  List<double>? stops;
  if (value['stops'] is List) {
    final raw = (value['stops'] as List).whereType<num>().toList();
    if (raw.length == parts.length) {
      stops = [for (final s in raw) s.toDouble()];
    }
  }
  var gradient = refer('LinearGradient').newInstance([], {
    'begin': leaf(primXy(value['begin'], 'Alignment.centerLeft')),
    'end': leaf(primXy(value['end'], 'Alignment.centerRight')),
    'colors': leaf('[${parts.map((p) => '$p,').join('\n')}]'),
    if (stops != null)
      'stops': leaf('[${stops.map(formatPrimNum).join(', ')}]'),
  });
  if (!themed) gradient = constOf(gradient);
  return gradient;
}

/// `boxShadow` list as AST (mirrors the [primShadows] rule: null when
/// absent/empty; unparseable entries skipped; `const` lives on the LIST iff
/// no stop is themed). Value leaves reuse the shared codecs.
Expression? shadowsExpr(Object? value) {
  if (value is! List || value.isEmpty) return null;
  final entries = <String>[];
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
    entries.add(
      'BoxShadow(color: ${color?.code ?? 'Color(0x40000000)'}, blurRadius: ${formatPrimNum(primDouble(s['blur']) ?? 0.0)}, spreadRadius: ${formatPrimNum(primDouble(s['spread']) ?? 0.0)}, offset: Offset(${formatPrimNum(ox)}, ${formatPrimNum(oy)}),),',
    );
  }
  if (entries.isEmpty) return null;
  return leaf('${themed ? '' : 'const '}[${entries.join('\n')}]');
}

/// §6.2 Container XOR as AST: color-only keeps the direct arg (the
/// hand-written form); radius/border/gradient/shadow fuse color into ONE
/// `BoxDecoration` (const iff no token inside — mirrors the legacy rule incl.
/// const placement, so parity is structural).
void containerDecoration({
  required Map<String, Expression> args,
  required Map<String, dynamic> props,
}) {
  final border = props['border'] is Map ? primBorder(props['border']) : null;
  final radius = primRadius(props['radius']);
  final shadows = props['shadow'] is List ? shadowsExpr(props['shadow']) : null;
  final gradient =
      props['gradient'] is Map ? gradientExpr(props['gradient']) : null;
  if (border == null && radius == null && shadows == null && gradient == null) {
    final color = primColor(props['color']);
    if (color != null) args['color'] = leaf(color.code);
    return;
  }
  final themed = (border?.themed ?? false) ||
      (primColor(props['color'])?.themed ?? false) ||
      _gradientThemed(props['gradient']) ||
      _shadowsThemed(props['shadow']);
  final decorationArgs = <String, Expression>{};
  final color = primColor(props['color']);
  if (color != null) decorationArgs['color'] = leaf(color.code);
  if (border != null) decorationArgs['border'] = leaf(border.code);
  if (radius != null) decorationArgs['borderRadius'] = leaf(radius);
  if (shadows != null) decorationArgs['boxShadow'] = shadows;
  if (gradient != null) decorationArgs['gradient'] = gradient;
  var decoration = refer('BoxDecoration').newInstance([], decorationArgs);
  if (!themed) decoration = constOf(decoration);
  args['decoration'] = decoration;
}

/// Whether the gradient carries a token-bound stop (mirrors the themed bit
/// of [primGradient] without rebuilding the lines).
bool _gradientThemed(Object? value) {
  if (value is! Map) return false;
  final colors = value['colors'];
  if (colors is! List) return false;
  return colors.any((c) => primColor(c)?.themed ?? false);
}

/// Whether any shadow stop is token-bound (mirrors [primShadows]).
bool _shadowsThemed(Object? value) {
  if (value is! List) return false;
  return value
      .any((s) => s is Map && (primColor(s['color'])?.themed ?? false));
}

// ---------------------------------------------------------------------------
// The ten layout-primitive emitters (Track F §7.1 kinds, 1:1 with the legacy
// `_bundleX` functions: same props, same defaults, same omission rules —
// only the mechanism changes from strings to AST).
// ---------------------------------------------------------------------------

/// `container`: dims, margin, padding, alignment + the §6.2 XOR branch.
class ContainerEmitter extends AstEmitter {
  const ContainerEmitter();

  @override
  String get type => 'container';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final args = <String, Expression>{};
    final width = primDim(item.props['width']);
    if (width != null) args['width'] = leaf(formatPrimNum(width));
    final height = primDim(item.props['height']);
    if (height != null) args['height'] = leaf(formatPrimNum(height));
    final margin = primEdge(item.props['margin']);
    if (margin != null) {
      args['margin'] = withTabletLeaf(
        base: leaf(margin),
        node: node,
        prop: 'margin',
        renderMd: primEdge,
      );
    }
    final padding = primEdge(item.props['padding']);
    if (padding != null) {
      args['padding'] = withTabletLeaf(
        base: leaf(padding),
        node: node,
        prop: 'padding',
        renderMd: primEdge,
      );
    }
    final alignment = primAlign(item.props['alignment']);
    if (alignment != null) args['alignment'] = leaf(alignment);
    containerDecoration(args: args, props: item.props);
    args.addAll(childArg(children));
    if (args.isEmpty) return leaf('const Container()');
    return refer('Container').newInstance([], args);
  }
}

/// `column`: axes + gap-separated children (gap 12 default).
/// Const-propagating (gate 4 viral-const rule): the axes are fixed enums
/// (unconditionally const-eligible), so an all-const child set yields
/// `const` exactly.
class ColumnEmitter extends AstEmitter {
  const ColumnEmitter();

  @override
  String get type => 'column';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final args = <String, Expression>{};
    final main = primMainAxis(item.props['mainAxis']);
    if (main != null) args['mainAxisAlignment'] = leaf(main);
    final cross = primCrossAxis(item.props['crossAxis']);
    if (cross != null) args['crossAxisAlignment'] = leaf(cross);
    // Const-absorb (gate 4 canonical-const rule): an all-const child set
    // consts the Column, and every part keyword (children + separators)
    // moves into its context via the stripped list.
    final allConst = children.every(isConstExpr);
    args['children'] = children.isEmpty
        ? leaf('const []')
        : childrenList(
            children,
            primGap(item.props, 12),
            true,
            strip: allConst,
          );
    var column = refer('Column').newInstance([], args);
    if (allConst) column = constOf(column);
    return column;
  }
}

/// `row`: axes + gap-separated children (gap 8 default).
/// Const-propagating (gate 4 viral-const rule — same shape as [ColumnEmitter]).
class RowEmitter extends AstEmitter {
  const RowEmitter();

  @override
  String get type => 'row';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final args = <String, Expression>{};
    final main = primMainAxis(item.props['mainAxis']);
    if (main != null) args['mainAxisAlignment'] = leaf(main);
    final cross = primCrossAxis(item.props['crossAxis']);
    if (cross != null) args['crossAxisAlignment'] = leaf(cross);
    // Const-absorb (gate 4 canonical-const rule — same shape as Column).
    final allConst = children.every(isConstExpr);
    args['children'] = children.isEmpty
        ? leaf('const []')
        : childrenList(
            children,
            primGap(item.props, 8),
            false,
            strip: allConst,
          );
    var row = refer('Row').newInstance([], args);
    if (allConst) row = constOf(row);
    return row;
  }
}

/// `stack`: alignment + fit + unseparated children.
/// Const-propagating (gate 4 viral-const rule): alignment leaves and the
/// fit enum are unconditionally const-eligible, so an all-const child set
/// yields `const` exactly.
class StackEmitter extends AstEmitter {
  const StackEmitter();

  @override
  String get type => 'stack';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final args = <String, Expression>{};
    final alignment = primAlign(item.props['alignment']);
    if (alignment != null) args['alignment'] = leaf(alignment);
    final fit = switch (item.props['fit']) {
      'expand' => 'StackFit.expand',
      'passthrough' => 'StackFit.passthrough',
      _ => null,
    };
    if (fit != null) args['fit'] = leaf(fit);
    // Const-absorb (gate 4 canonical-const rule — same shape as Column).
    final allConst = children.every(isConstExpr);
    final parts =
        allConst ? [for (final c in children) stripConst(c)] : children;
    args['children'] = parts.isEmpty
        ? leaf('const []')
        : leaf(
            '[${parts.map((c) => c.accept(DartEmitter())).join(',\n')}]',
          );
    var stack = refer('Stack').newInstance([], args);
    if (allConst) stack = constOf(stack);
    return stack;
  }
}

/// `padding`: padding (default `all(16)`) + child.
class PaddingEmitter extends AstEmitter {
  const PaddingEmitter();

  @override
  String get type => 'padding';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final padding = primEdge(item.props['padding']) ??
        'const EdgeInsets.all(16)';
    return refer('Padding').newInstance([], {
      'padding': withTabletLeaf(
        base: leaf(padding),
        node: node,
        prop: 'padding',
        renderMd: primEdge,
      ),
      ...childArg(children),
    });
  }
}

/// `center`: bare when childless.
class CenterEmitter extends AstEmitter {
  const CenterEmitter();

  @override
  String get type => 'center';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final args = childArg(children);
    if (args.isEmpty) return leaf('const Center()');
    return refer('Center').newInstance([], args);
  }
}

/// `align`: alignment (default center) + child.
class AlignEmitter extends AstEmitter {
  const AlignEmitter();

  @override
  String get type => 'align';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) =>
      refer('Align').newInstance([], {
        'alignment': leaf(primAlign(item.props['alignment']) ??
            'Alignment.center'),
        ...childArg(children),
      });
}

/// `expanded`: flex (omitted when 1) + child (`SizedBox.shrink` default).
/// Const-propagating (gate 4 viral-const rule): the flex int is
/// unconditionally const-eligible, so a const child yields `const` exactly.
class ExpandedEmitter extends AstEmitter {
  const ExpandedEmitter();

  @override
  String get type => 'expanded';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final flex = primFlex(item.props['flex']);
    final resolved =
        children.isEmpty ? [leaf('const SizedBox.shrink()')] : children;
    // Const-absorb (gate 4 canonical-const rule): the flex int is
    // unconditionally const-eligible, so a const child consts the Expanded
    // and its keyword moves into that context.
    final allConst = resolved.every(isConstExpr);
    final parts =
        allConst ? [for (final c in resolved) stripConst(c)] : resolved;
    var expanded = refer('Expanded').newInstance([], {
      if (flex != 1) 'flex': leaf('$flex'),
      ...childArg(parts),
    });
    if (allConst) expanded = constOf(expanded);
    return expanded;
  }
}

/// `sized_box`: dims + optional child; const-correct (responsive leaves and
/// composed children are never const — mirrors the legacy const rules).
class SizedBoxEmitter extends AstEmitter {
  const SizedBoxEmitter();

  @override
  String get type => 'sized_box';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    String? dimSrc(Object? raw) {
      final dim = primDim(raw);
      if (dim == null) return null;
      return formatPrimNum(dim);
    }

    final widthSrc = dimSrc(item.props['width']);
    final heightSrc = dimSrc(item.props['height']);
    final widthResponsive =
        widthSrc != null && hasTabletOverride(node, 'width');
    final heightResponsive =
        heightSrc != null && hasTabletOverride(node, 'height');
    Expression? dimValue(String? src, String prop) {
      if (src == null) return null;
      return withTabletLeaf(
        base: leaf(src),
        node: node,
        prop: prop,
        renderMd: (raw) {
          final dim = primDim(raw);
          return dim == null ? null : formatPrimNum(dim);
        },
      );
    }

    if (children.isEmpty) {
      if (widthSrc == null && heightSrc == null) {
        return leaf('const SizedBox.shrink()');
      }
      final widthRendered = widthSrc == null
          ? null
          : dimValue(widthSrc, 'width')!.accept(DartEmitter()).toString();
      final heightRendered = heightSrc == null
          ? null
          : dimValue(heightSrc, 'height')!.accept(DartEmitter()).toString();
      final dims = [
        if (widthRendered != null) 'width: $widthRendered',
        if (heightRendered != null) 'height: $heightRendered',
      ].join(', ');
      // Legacy const rule: dim-only leaves are const; responsive never is.
      if (!widthResponsive && !heightResponsive) {
        return leaf('const SizedBox($dims)');
      }
      return refer('SizedBox').newInstance([], {
        if (widthSrc != null) 'width': dimValue(widthSrc, 'width')!,
        if (heightSrc != null) 'height': dimValue(heightSrc, 'height')!,
      });
    }
    return refer('SizedBox').newInstance([], {
      if (widthSrc != null) 'width': dimValue(widthSrc, 'width')!,
      if (heightSrc != null) 'height': dimValue(heightSrc, 'height')!,
      ...childArg(children),
    });
  }
}

/// `spacer`: leaf, flex omitted when 1.
class SpacerEmitter extends AstEmitter {
  const SpacerEmitter();

  @override
  String get type => 'spacer';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final flex = primFlex(item.props['flex']);
    if (flex == 1) return leaf('const Spacer()');
    // The flex int is unconditionally const-eligible: always const.
    return leaf('const Spacer(flex: $flex)');
  }
}

/// All ten primitive emitters in registry order.
const List<AstEmitter> primitiveEmitters = [
  ContainerEmitter(),
  ColumnEmitter(),
  RowEmitter(),
  StackEmitter(),
  PaddingEmitter(),
  CenterEmitter(),
  AlignEmitter(),
  ExpandedEmitter(),
  SizedBoxEmitter(),
  SpacerEmitter(),
];

/// [AstEmitter] behind the G1 [WidgetEmitter] string contract: formats
/// the AST canonically. This is what populates [EmitterRegistry] (§8.2) —
/// the registry mechanics work today; the legacy bundle path is untouched.
class ExprAdapter implements WidgetEmitter {
  /// The AST emitter this adapter exposes as strings.
  final AstEmitter inner;

  const ExprAdapter(this.inner);

  @override
  String get type => inner.type;

  @override
  String emit(
    CanvasItem item,
    CanvasNode node,
    List<String> childExprs,
    EmitContext ctx,
  ) {
    inner.collectImports(ctx);
    return formatExpression(
      inner.emitExpr(
        item,
        node,
        [for (final c in childExprs) CodeExpression(Code(c))],
        ctx,
      ),
    );
  }
}

/// §8.2 registry pre-populated with the ten migrated primitives: each entry
/// declares its render path + emit path + correctness rules + model need.
/// A kind that cannot do both does not enter (drift becomes type-enforced).
EmitterRegistry primitiveRegistry() {
  final registry = EmitterRegistry();
  for (final emitter in primitiveEmitters) {
    registry.register(
      ExprAdapter(emitter),
      binding: KindBinding(
        type: emitter.type,
        isContainer: emitter.type != 'spacer',
        renderDescription: 'catalog build${_pascal(emitter.type)}',
        correctnessRules: _correctnessRulesFor(emitter.type),
      ),
    );
  }
  return registry;
}

List<String> _correctnessRulesFor(String type) {
  switch (type) {
    case 'container':
      return ['color XOR decoration (§6.2)', 'negative dims clamp to 0'];
    case 'column':
    case 'row':
      return ['gap separators', 'negative gaps clamp to 0'];
    case 'expanded':
    case 'spacer':
      return ['flex clamps to ≥ 1'];
    case 'sized_box':
      return ['responsive dims drop const', 'negative dims clamp to 0'];
    default:
      return [];
  }
}

String _pascal(String snake) => snake
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join();

// ---------------------------------------------------------------------------
// Page walker: ScreenDoc → page files via the AST emitters.
// ---------------------------------------------------------------------------

/// Primitive container kinds whose item consumes the node's child nodes
/// (mirrors the legacy `_bundleContainerKinds` subset owned by G2).
const Set<String> primitiveContainerKinds = {
  'container',
  'column',
  'row',
  'stack',
  'padding',
  'center',
  'align',
  'expanded',
  'sized_box',
};

/// One emitted block: its trace comment + widget expression.
typedef PageBlock = ({String comment, Expression expr});

/// Emits the §8.4 page files for [screen] through the AST emitters.
///
/// Walk rules (v1 — a migration vehicle, NOT a second exporter):
/// * Roots are nodes whose `parentId` is null/dangling, in (y, x) order;
///   child nodes attach to their parent's FIRST container-kind item, in
///   (y, x) order. Children of leaf kinds (and of unknown kinds) emit as
///   subsequent SIBLINGS (the legacy below-fallback spirit: never dropped).
/// * One block → bare body; several → a `Column(children:)` wrapper (legacy
///   root rhythm carries NO gap separators — mirrored, not redesigned).
/// * Unknown kinds emit [placeholderFor] (honest; G3 closes them). `isRow`
///   structural rows emit their items transparently (first-class `row`
///   covers new docs; legacy `_writeBundleRow` parity is G3).
/// * `hiddenOn` tiers add a trace comment (the `Visibility` wrapper is G3);
///   non-wired `breakpointValues` overrides are inert in v1 except the leaf
///   props each emitter wires ([withTabletLeaf]); cycles emit the legacy
///   cycle note and skip (never a hang).
/// * Imports come SOLELY from [EmitContext.imports] (priority (a)); model
///   split + responsive leaf via [emitPage] (priority (d)).
/// * [extraEmitters] (Track G3 — additive, defaults to none) registers
///   further leaf-kind emitters (e.g. the ten G3 kit kinds) under the same
///   walk rules; G2 callers pass nothing and see byte-identical output.
List<ProjectOutFile> emitPrimitivePageFiles({
  required ScreenDoc doc,
  required CanvasScreen screen,
  List<AstEmitter> extraEmitters = const [],
}) {
  final ctx = EmitContext();
  final byType = {
    for (final e in primitiveEmitters) e.type: e,
    for (final e in extraEmitters) e.type: e,
  };
  // Imports come ONLY from kinds the page actually uses (gates 4–5
  // DEFECT-1): collecting every extra emitter unconditionally drags the kit
  // barrel onto pages with zero kit widgets (whose `Column`/`Theme` uses
  // then read as ambiguous). Primitives declare only the shell-owned
  // material import, so primitive-only pages collect no extra lines at all.
  final kinds = pageKindsFor(doc, screen.id);
  for (final kind in kinds) {
    byType[kind]?.collectImports(ctx);
  }
  final nodeIds = {for (final n in doc.nodes) n.id};
  final screenNodes = [
    for (final n in doc.nodes)
      if (n.screenId == screen.id) n,
  ];
  final roots = [
    for (final n in screenNodes)
      if (n.parentId == null || !nodeIds.contains(n.parentId)) n,
  ]..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });

  List<CanvasNode> kidsOf(String id) => [
        for (final n in screenNodes)
          if (n.parentId == id) n,
      ]..sort((a, b) {
          final dy = a.y.compareTo(b.y);
          return dy != 0 ? dy : a.x.compareTo(b.x);
        });

  // Commentless composite of [node]'s subtree (nested emission drops trace
  // comments — they live at root level only, where the page assembler can
  // place them before the format pass).
  Expression compositeOf(CanvasNode node, Set<String> ancestors) {
    if (!ancestors.add(node.id)) {
      return leaf('SizedBox.shrink() /* ${_bundleCycleNote(node.id)} */');
    }
    final kids = kidsOf(node.id);
    final blocks = <Expression>[];
    var consumed = false;
    for (final item in node.items) {
      final emitter = byType[item.kind];
      if (emitter == null) {
        blocks.add(leaf(placeholderFor(item.kind)));
        continue;
      }
      var childExprs = const <Expression>[];
      if (!consumed &&
          kids.isNotEmpty &&
          primitiveContainerKinds.contains(item.kind)) {
        consumed = true;
        childExprs = [for (final k in kids) compositeOf(k, {...ancestors})];
      }
      blocks.add(emitter.emitExpr(item, node, childExprs, ctx));
    }
    // Children of leaf kinds (and itemless nodes) emit as subsequent
    // siblings — the legacy below-fallback spirit: never dropped.
    if (!consumed) {
      for (final k in kids) {
        blocks.add(compositeOf(k, {...ancestors}));
      }
    }
    if (blocks.isEmpty) return leaf('const SizedBox.shrink()');
    if (blocks.length == 1) return blocks.single;
    return constAwareColumn(blocks);
  }

  // Root-level blocks WITH trace comments. Rule mirrors [compositeOf], but
  // every item carries `// <kind> <id>.` (+ the hiddenOn trace suffix), and
  // leaf-child fallback nodes recurse here so THEIR items stay traced too.
  List<PageBlock> rootBlocks(CanvasNode node, Set<String> ancestors) {
    if (!ancestors.add(node.id)) {
      return [
        (
          comment: '// ${_bundleCycleNote(node.id)}',
          expr: leaf('SizedBox.shrink()'),
        ),
      ];
    }
    final kids = kidsOf(node.id);
    final out = <PageBlock>[];
    var consumed = false;
    for (final item in node.items) {
      final hiddenTiers = [...node.hiddenOn]..sort();
      final hidden = node.hiddenOn.isEmpty
          ? ''
          : " // hiddenOn: ${hiddenTiers.join(', ')} "
              '(responsive wrapper lands in G3).';
      // Quoted id mirrors the legacy `// kind 'label'.` trace convention.
      final comment = "// ${item.kind} '${item.id}'.$hidden";
      final emitter = byType[item.kind];
      if (emitter == null) {
        out.add((comment: comment, expr: leaf(placeholderFor(item.kind))));
        continue;
      }
      var childExprs = const <Expression>[];
      if (!consumed &&
          kids.isNotEmpty &&
          primitiveContainerKinds.contains(item.kind)) {
        consumed = true;
        childExprs = [for (final k in kids) compositeOf(k, {...ancestors})];
      }
      out.add((
        comment: comment,
        expr: emitter.emitExpr(item, node, childExprs, ctx),
      ));
    }
    if (!consumed) {
      for (final k in kids) {
        out.addAll(rootBlocks(k, {...ancestors}));
      }
    }
    if (node.items.isEmpty && kids.isEmpty) {
      out.add((
        comment: '// node ${node.id} (empty).',
        expr: leaf('SizedBox.shrink()'),
      ));
    }
    return out;
  }

  // Comments ride OUTSIDE the AST (a `//` inside single-line raw source
  // would comment out the rest): blocks pair comment + expression, and the
  // body assembler interleaves them before the single format pass.
  final annotated = <PageBlock>[];
  for (final root in roots) {
    annotated.addAll(rootBlocks(root, {}));
  }

  final Expression body;
  if (annotated.isEmpty) {
    body = leaf('SizedBox.shrink()');
  } else if (annotated.length == 1) {
    // Single block: the trace comment is dropped (it cannot ride `return`
    // on the same line, and buildPageFile owns the return site — see
    // [emitPage]). Multi-block pages keep per-item comments inside the
    // children list, where they are legal.
    body = annotated.single.expr;
  } else {
    // Root-level trace comments ride the children list (B-shape raw: each
    // comment pre-indented at list-item level so the format pass keeps it
    // with its item — column-0 comments misplace, see G2 notes).
    // Const-absorb (gate 4 canonical-const rule): comments are
    // formatter-whitespace, so an all-const block set still yields `const`
    // exactly, with the block keywords absorbed into its context.
    final allConst = annotated.every((b) => isConstExpr(b.expr));
    final blockSources = [
      for (final b in annotated)
        '\n  ${b.comment}\n  ${(allConst ? stripConst(b.expr) : b.expr).accept(DartEmitter())}',
    ];
    var root = refer('Column').newInstance([], {
      'children': leaf('[${blockSources.join(',')}\n]'),
    });
    if (allConst) root = constOf(root);
    body = root;
  }

  final plan = planModelFields(doc, screen.id, ctx.names);
  final pageBody = _shiftForReturn(formatExpression(body));
  // The shell material import is unnecessary (analyzer info) when every
  // name the body uses also resolves through the kit barrel as the SAME
  // element (the kit re-exports the Flutter framework wholesale): drop it
  // then, keep it otherwise. Kit-free pages always keep it (their only
  // Flutter source). The scan vocabulary is closed — bodies are generated.
  final hasKit = ctx.imports.lines.any(
    (l) => l.startsWith("import 'package:flutter_shadcn_kit/"),
  );
  final emitted = emitPage(
    slug: slugifyScreen(screen.name),
    kinds: kinds,
    body: pageBody,
    imports: ctx.imports,
    modelPlan: plan,
    includeMaterial: !hasKit || _bodyNeedsMaterial(pageBody),
  );
  final slug = slugifyScreen(screen.name);
  return [
    ProjectOutFile(pageFilePath(slug), emitted.page.content),
    if (emitted.model != null)
      ProjectOutFile(modelFilePath(slug), emitted.model!.content),
  ];
}

/// Cycle marker shared with the legacy bundle exporter (same message —
/// corrupt docs behave identically on both paths).
String _bundleCycleNote(String nodeId) =>
    'cycle: node $nodeId is its own ancestor (skipped)';

/// Whether an emitted page [body] references a Flutter-SDK name that keeps
/// the shell material import necessary on a kit-importing page: the
/// kit-hidden set ([kKitImportHide] — hidden on the kit import, so only
/// material provides them) plus `Icons` (material-only; no kit barrel
/// re-exports it). Every OTHER body name is either a kit constructor or
/// re-exported by the kit barrel as the same element. Closed vocabulary —
/// bodies are generated, never hand-written.
bool _bodyNeedsMaterial(String body) => RegExp(
      "\\b(${kKitImportHide.join('|')}|Icons)\\b",
    ).hasMatch(body);

/// Shifts canonical depth-0 [body] for the `return` site: first line bare
/// (follows `return `), every later line +4 (see [emitPage], which owns the
/// `return` prefix via [buildPageFile]).
String _shiftForReturn(String body) {
  final lines = body.split('\n');
  final out = <String>[lines.first];
  for (final line in lines.skip(1)) {
    out.add(line.isEmpty ? line : '    $line');
  }
  return out.join('\n');
}
