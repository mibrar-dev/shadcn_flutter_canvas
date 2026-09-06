/// Track G3 — the 10-kind gap, closed structurally (§8.2, not 10 loose
/// functions).
///
/// Closes `_bundlePlaceholderKinds`: `chip`, `alert`,
/// `circular_progress_indicator`, `linear_progress_indicator`,
/// `triple_dots`, `dot_indicator`, `empty_state`, `code_snippet`,
/// `number_ticker`, `text_area`. Each kind gets ONE implementation here (an
/// [AstEmitter]) consumed by BOTH paths: the bundle string path (via
/// [g3BundleLines], used by `codegen_bundle.dart`'s `_bundleX` wrappers) and
/// the page walker (via [g3Emitters] / [g3Registry], whose [KindBinding]
/// entries declare render + emit together so drift is type-enforced).
///
/// ORACLE: every emitter mirrors its canvas registry builder in
/// `canvas_app/lib/canvas/component_registry.dart` (`buildXEntry`)
/// prop-for-prop with the same defaults and edge handling — statically
/// snapshotted for export (stateful cells render their initial value with
/// no-op-free static forms, exactly like the kit bundle convention).
/// Golden-first (§6.5): `test/fixtures/g3_<kind>.json` +
/// `.expected.dart` were hand-written from those builders BEFORE this file
/// existed; this file must produce them.
///
/// CONSTRUCTION LEDGER (honest — cf. G2's migrated-vs-wrapped ledger):
/// * Structured AST (constructor choice + named-arg presence/order are AST
///   decisions; the single `dart_style` pass lays them out): `alert`,
///   `dot_indicator`, `empty_state`, `number_ticker`, `text_area`.
///   Value leaves are opaque [Code] from the single-sourced helpers below
///   (the G2 pattern — collapse rules are not re-implemented).
/// * Opaque single-line leaves (the whole invocation is one short arg, so
///   there is no layout decision for the AST to own): `chip`,
///   `circular_progress_indicator`, `linear_progress_indicator`,
///   `triple_dots`, `code_snippet`. The leaf bytes come from the same
///   helpers — never hand punctuation elsewhere.
///
/// LENIENCY: props read leniently (missing/wrong-typed values fall back to
/// the registry default, `num`-parsed because `jsonDecode` yields `int` for
/// whole numbers, clamped into the builder's domain) so hand-written docs
/// never crash the exporter.
///
/// V1 GAP (documented, not silent): `=var` state bindings inside G3 text
/// props emit the quoted literal (the same fallback the legacy path uses
/// for unknown vars) — live interpolation for these ten kinds is future
/// work. Placeholders never interpolated either, so this is strictly
/// better than the bridged output it replaces.
///
/// Flutter-free (canvas_core rule §12.6): `code_builder` + `dart_style`
/// are pure Dart (reached via `expr_emitter.dart`).
library;

import 'package:code_builder/code_builder.dart' hide EnumValue;

import '../screen_doc.dart';
import 'emit_context.dart';
import 'expr_emitter.dart';
import 'value_codecs.dart';
import 'widget_emitter.dart';

/// Kit umbrella import for generated project pages using these kinds
/// (the §8.1 package-dep contract — cf. §4.2's `flutter_shadcn_kit` shape).
const kG3KitImport = 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart';

/// Lenient string prop: missing/non-string values fall back (never crash).
String g3Str(Map<String, dynamic> props, String key, String fallback) {
  final value = props[key];
  return value is String ? value : fallback;
}

/// Lenient bool prop: missing/non-bool values fall back (never crash).
bool g3Bool(Map<String, dynamic> props, String key, bool fallback) {
  final value = props[key];
  return value is bool ? value : fallback;
}

/// Lenient `num`-parsed double prop with fallback (no clamping).
double g3Num(Map<String, dynamic> props, String key, double fallback) {
  final value = props[key];
  return value is num ? value.toDouble() : fallback;
}

/// Lenient `num`-parsed double prop clamped into `[min, max]` (mirrors the
/// registry builders' clamp-into-domain edge handling).
double g3Double(
  Map<String, dynamic> props,
  String key,
  double fallback,
  double min,
  double max,
) =>
    g3Num(props, key, fallback).clamp(min, max).toDouble();

/// Lenient `num`-parsed int prop clamped into `[min, max]`.
int g3Int(
  Map<String, dynamic> props,
  String key,
  int fallback,
  int min,
  int max,
) {
  final value = props[key];
  final parsed = value is num ? value.toInt() : fallback;
  return parsed.clamp(min, max);
}

/// Dart single-quoted string literal for [value]; mirrors `_bundleStr` in
/// `codegen_bundle.dart` (backslash / quote / newline / CR / `$` escaping)
/// so labels can never break compilation of the emitted screen.
String g3Quote(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
  return "'$escaped'";
}

/// `Text('…')` value leaf from a canvas-level string prop.
Expression g3Text(String value) => leaf('Text(${g3Quote(value)})');

/// `chip`: `label` renders as the child `Text` (mirrors `buildChipEntry`).
class ChipEmitter extends AstEmitter {
  const ChipEmitter();

  @override
  String get type => 'chip';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) =>
      leaf("Chip(child: Text(${g3Quote(g3Str(item.props, 'label', 'Chip'))}))");

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `alert`: title / content `Text`s + `destructive` (mirrors
/// `buildAlertEntry`).
class AlertEmitter extends AstEmitter {
  const AlertEmitter();

  @override
  String get type => 'alert';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) =>
      refer('Alert').newInstance([], {
        'title': g3Text(g3Str(item.props, 'title', 'Alert')),
        'content': g3Text(
          g3Str(item.props, 'content', 'Something happened.'),
        ),
        'destructive':
            leaf(g3Bool(item.props, 'destructive', false) ? 'true' : 'false'),
      });

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `circular_progress_indicator`: determinate value, `num`-parsed + clamped
/// (mirrors `buildCircularProgressEntry`).
class CircularProgressEmitter extends AstEmitter {
  const CircularProgressEmitter();

  @override
  String get type => 'circular_progress_indicator';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final value = formatPrimNum(g3Double(item.props, 'value', 0.6, 0.0, 1.0));
    return leaf('CircularProgressIndicator(value: $value)');
  }

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `linear_progress_indicator`: determinate value, `num`-parsed + clamped
/// (mirrors `buildLinearProgressEntry`).
class LinearProgressEmitter extends AstEmitter {
  const LinearProgressEmitter();

  @override
  String get type => 'linear_progress_indicator';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final value = formatPrimNum(g3Double(item.props, 'value', 0.6, 0.0, 1.0));
    return leaf('LinearProgressIndicator(value: $value)');
  }

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `triple_dots`: the kit constructor is `MoreDots`; `count` parses via
/// `num` and clamps 1..9 (mirrors `buildTripleDotsEntry`).
class TripleDotsEmitter extends AstEmitter {
  const TripleDotsEmitter();

  @override
  String get type => 'triple_dots';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final count = g3Int(item.props, 'count', 3, 1, 9);
    return leaf('MoreDots(count: $count)');
  }

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `dot_indicator`: `index` + `length` ints, index clamped into the length
/// range so hand-written docs never crash (mirrors
/// `buildDotIndicatorEntry`).
class DotIndicatorEmitter extends AstEmitter {
  const DotIndicatorEmitter();

  @override
  String get type => 'dot_indicator';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final length = g3Int(item.props, 'length', 3, 1, 9);
    final index = g3Int(item.props, 'index', 0, 0, length - 1);
    return refer('DotIndicator').newInstance([], {
      'index': leaf('$index'),
      'length': leaf('$length'),
    });
  }

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `empty_state`: title / description `Text`s (mirrors
/// `buildEmptyStateEntry`).
class EmptyStateEmitter extends AstEmitter {
  const EmptyStateEmitter();

  @override
  String get type => 'empty_state';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) =>
      refer('EmptyState').newInstance([], {
        'title': g3Text(g3Str(item.props, 'title', 'No results')),
        'description': g3Text(
          g3Str(item.props, 'description', 'Try adjusting your search.'),
        ),
      });

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `code_snippet`: the `code` string renders as the child `Text` (mirrors
/// `buildCodeSnippetEntry`).
class CodeSnippetEmitter extends AstEmitter {
  const CodeSnippetEmitter();

  @override
  String get type => 'code_snippet';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) =>
      leaf("CodeSnippet(code: Text(${g3Quote(g3Str(item.props, 'code', 'const x = 1;'))}))");

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `number_ticker`: plain integer formatter pinned, value `num`-parsed
/// (mirrors `buildNumberTickerEntry`). Static snapshot: initial value +
/// pure formatter closure, never a dangling builder reference.
class NumberTickerEmitter extends AstEmitter {
  const NumberTickerEmitter();

  @override
  String get type => 'number_ticker';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) =>
      refer('NumberTicker').newInstance([], {
        'number': leaf(formatPrimNum(g3Num(item.props, 'value', 42.0))),
        'formatter': leaf('(v) => v.toStringAsFixed(0)'),
      });

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// `text_area`: all-optional kit params; a non-empty `label` renders as a
/// caption above the field (mirrors `buildTextAreaEntry` and the input
/// catalog builder's caption rhythm). Static snapshot with no controller
/// reference — the `{Page}Model` shell owns the controller (see
/// `planModelFields`, which already allocates `text_area` controllers).
class TextAreaEmitter extends AstEmitter {
  const TextAreaEmitter();

  @override
  String get type => 'text_area';

  @override
  Expression emitExpr(
    CanvasItem item,
    CanvasNode node,
    List<Expression> children,
    EmitContext ctx,
  ) {
    final field = refer('TextArea').newInstance([], {
      'placeholder':
          g3Text(g3Str(item.props, 'placeholder', 'Type here')),
      'enabled':
          leaf(g3Bool(item.props, 'disabled', false) ? 'false' : 'true'),
    });
    final label = g3Str(item.props, 'label', '');
    if (label.isEmpty) return field;
    return refer('Column').newInstance([], {
      'mainAxisSize': leaf('MainAxisSize.min'),
      'crossAxisAlignment': leaf('CrossAxisAlignment.start'),
      // Trailing comma after the last element: canonical multi-element list
      // form (the G2 trailing-comma policy — a formatter fixpoint, gate 3).
      'children': leaf(
        "[Text(${g3Quote(label)}),\nconst SizedBox(height: 6),\n${field.accept(DartEmitter())},\n]",
      ),
    });
  }

  @override
  void collectImports(EmitContext ctx) {
    ctx.imports.add(kG3KitImport);
  }
}

/// All ten G3 emitters in `_bundlePlaceholderKinds` order (the gap they
/// close).
const List<AstEmitter> g3Emitters = [
  ChipEmitter(),
  AlertEmitter(),
  CircularProgressEmitter(),
  LinearProgressEmitter(),
  TripleDotsEmitter(),
  DotIndicatorEmitter(),
  EmptyStateEmitter(),
  CodeSnippetEmitter(),
  NumberTickerEmitter(),
  TextAreaEmitter(),
];

/// Synthetic leaf node for the bundle string path: G3 kinds are leaves and
/// wire no responsive overrides in v1, so the node is never read — the
/// bundle `_bundleX` wrappers (which only hold the item) pass this instead
/// of threading a node through every call site.
const CanvasNode g3LeafNode = CanvasNode(
  id: '',
  screenId: '',
  x: 0.0,
  y: 0.0,
  items: [],
);

/// Bundle-path body lines for [emitter] + [item]: the canonical
/// [formatExpression] output split into unindented depth-0 lines with the
/// trailing comma the bundle convention requires on the last line.
///
/// This is the mechanical step that keeps ONE implementation behind both
/// paths (§8.2): the AST program is identical to the page-walker output;
/// only the line-splitting + trailing comma adapt it to the bundle shape.
List<String> g3BundleLines(AstEmitter emitter, CanvasItem item) {
  final ctx = EmitContext();
  final out = ExprAdapter(emitter).emit(item, g3LeafNode, const [], ctx);
  final lines = out.split('\n');
  lines[lines.length - 1] = '${lines.last},';
  return lines;
}

/// §8.2 registry for the ten G3 kinds: each entry declares its render path
/// + emit path + correctness rules + model need. A kind that cannot do both
/// does not enter — `driftKinds` is empty by construction and pinned by
/// `test/g3_gap_test.dart` (gate 7 direction).
EmitterRegistry g3Registry() {
  final registry = EmitterRegistry();
  for (final emitter in g3Emitters) {
    registry.register(
      ExprAdapter(emitter),
      binding: KindBinding(
        type: emitter.type,
        isContainer: false,
        renderDescription: 'registry ${_registryBuilderFor(emitter.type)}',
        correctnessRules: _correctnessRulesFor(emitter.type),
        needsModel: emitter.type == 'text_area',
      ),
    );
  }
  return registry;
}

/// Canvas registry builder each G3 emitter mirrors (the render path half of
/// the §8.2 binding — verified `buildXEntry` functions, not catalog stubs).
String _registryBuilderFor(String type) {
  switch (type) {
    case 'chip':
      return 'buildChipEntry';
    case 'alert':
      return 'buildAlertEntry';
    case 'circular_progress_indicator':
      return 'buildCircularProgressEntry';
    case 'linear_progress_indicator':
      return 'buildLinearProgressEntry';
    case 'triple_dots':
      return 'buildTripleDotsEntry';
    case 'dot_indicator':
      return 'buildDotIndicatorEntry';
    case 'empty_state':
      return 'buildEmptyStateEntry';
    case 'code_snippet':
      return 'buildCodeSnippetEntry';
    case 'number_ticker':
      return 'buildNumberTickerEntry';
    case 'text_area':
      return 'buildTextAreaEntry';
    default:
      throw ArgumentError('unknown G3 kind: $type');
  }
}

List<String> _correctnessRulesFor(String type) {
  switch (type) {
    case 'chip':
      return ['label renders as the child Text'];
    case 'alert':
      return ['title/content render as Text widgets'];
    case 'circular_progress_indicator':
    case 'linear_progress_indicator':
      return ['value parses via num, clamped 0..1'];
    case 'triple_dots':
      return [
        'kit constructor is MoreDots (name differs from kind)',
        'count parses via num, clamped 1..9',
      ];
    case 'dot_indicator':
      return ['index clamped into the length range'];
    case 'empty_state':
      return ['title/description render as Text widgets'];
    case 'code_snippet':
      return ['code string renders as the child Text'];
    case 'number_ticker':
      return [
        'plain integer formatter pinned',
        'value parses via num (unclamped, mirrors builder)',
      ];
    case 'text_area':
      return [
        'non-empty label renders as a caption Column (input-builder rhythm)',
        'static snapshot: no controller reference (model shell owns it)',
      ];
    default:
      return [];
  }
}
