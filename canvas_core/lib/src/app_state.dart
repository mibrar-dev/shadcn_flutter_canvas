/// Typed app-state variables, prop bindings, and multi-step tap actions.
///
/// Track R1 (FlutterFlow parity, minimal coherent version): production
/// builders revolve around typed app-state variables, prop bindings, and
/// multi-step action flows with stateful codegen. This file is the pure-Dart
/// core of that (no Flutter imports — `canvas_core` stays Flutter-free so the
/// CLI reuses it):
///
/// * [AppStateVar]: a typed variable (`string`/`number`/`bool`) with a
///   type-matching default.
/// * Bindings: text-ish prop values starting with `=` reference a var
///   (`=cartCount`). Helpers here ([isStateBinding], [bindingNameOf],
///   [stringifyStateValue]) are shared by the catalog (preview/editor
///   resolution), the store (rename rewrites), and codegen (field reads).
///   Only string-typed props bind: a `=name` on a numeric/bool prop is left
///   as the raw string (documented v1 limitation — the catalog resolves
///   per-spec, codegen interpolates text positions only).
/// * [ActionStep]: one ordered step (`navigate`, `setState`, `showSnackBar`,
///   `showDialog`, `condition`, `apiCall`). A `setState` value is a type literal
///   (`1`, `true`, `hello`) or a var reference (`=otherVar`, same-type by
///   convention — the inspector only offers same-type refs). A `condition`
///   runs its `then` steps when `stringify(value) == equals`; a guard on an
///   unknown var is false (the step is skipped, never a crash).
/// * Execution order ("navigation last"): [partitionSteps] runs every
///   non-navigation step in order first (conditions evaluated against the
///   live values, navigations inside branches hoisted), then all
///   navigations in order. Preview and codegen share this semantics, so a
///   `setState` + `showSnackBar` + `navigate` flow updates state and shows
///   feedback before leaving the screen.
///
/// Session values (`Map<String, dynamic>`) are intentionally NOT part of the
/// doc: the store keeps them session-only (never persisted — see
/// `canvas_store.dart`), preview owns a local copy, and codegen fields
/// initialize from defaults.
library;

/// Value types for [AppStateVar.type].
const Set<String> kAppStateTypes = {'string', 'number', 'bool'};

/// Identifier syntax for state var names. Shared by bindings (`=name`),
/// step `variable` refs, and codegen field names (`_<name>`), so a valid
/// var name is always a valid Dart identifier suffix.
final RegExp kAppStateName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Action step kinds (single source of truth for model, inspector, runtime,
/// codegen, and the AI-contract validator).
const Set<String> kActionStepKinds = {
  'navigate',
  'setState',
  'showSnackBar',
  'showDialog',
  'condition',
  'apiCall',
};

/// HTTP methods an [ActionStep.apiCall] may use (minimal REST subset).
const Set<String> kApiCallMethods = {'GET', 'POST'};

/// Timeout for `apiCall` steps (preview executor and generated code share
/// this budget: 10s, documented in both places).
const Duration kApiCallTimeout = Duration(seconds: 10);

/// Whether [url] is a usable `apiCall` target (http/https with a host).
/// Trims surrounding whitespace first; never throws.
bool isApiCallUrlValid(String url) {
  try {
    final uri = Uri.parse(url.trim());
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Whether an `apiCall` header pair is well-formed (minimal check: non-empty
/// trimmed name without `:`/line-breaks, value without line-breaks).
bool isApiHeaderValid(String name, String value) {
  final key = name.trim();
  if (key.isEmpty) return false;
  if (key.contains(':') || key.contains('\n') || key.contains('\r')) {
    return false;
  }
  return !value.contains('\n') && !value.contains('\r');
}

/// Whether any step (recursing into conditions) is an `apiCall` (the
/// generated tap method must then be `async` and import `package:http`).
bool stepsNeedHttp(List<ActionStep> steps) {
  for (final s in steps) {
    if (s.kind == 'apiCall') return true;
    if (s.kind == 'condition' && stepsNeedHttp(s.thenSteps)) return true;
  }
  return false;
}

/// Dart map literal for `apiCall` [headers] (sorted keys, deterministic).
String apiHeadersDart(Map<String, String> headers) {
  final keys = headers.keys.toList()..sort();
  final pairs = [
    for (final k in keys) '${dartStringLiteral(k)}: ${dartStringLiteral(headers[k]!)}',
  ];
  return '<String, String>{${pairs.join(', ')}}';
}

/// Whether [value] is a state binding reference (`=varName`).
///
/// A lone `=` is raw text, not a binding (there is no empty var name).
bool isStateBinding(Object? value) =>
    value is String && value.length > 1 && value.startsWith('=');

/// The referenced var name, or null when [value] is not a binding.
String? bindingNameOf(Object? value) {
  if (!isStateBinding(value)) return null;
  return (value as String).substring(1);
}

/// Readable rendering of a session value: `'$value'` for bool/num/String
/// (`true`, `3`, `Ada`). Used by condition guards, text bindings, and the
/// prompt exporter. `null` renders as `'null'` (hand-docs with a null
/// default compare against that — store-added vars always carry a
/// type-matching non-null default, so this only bites hand-written docs).
String stringifyStateValue(Object? value) => '$value';

/// Dart single-quoted string literal for [value] (same escapes as the
/// single-file exporter's `_str`: backslash, quote, newline, CR, `$`).
String dartStringLiteral(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
  return "'$escaped'";
}

/// Interpolation expression reading state field [field] in a String
/// position (`'${_count}'` — always String-typed, so text slots stay safe
/// for string/number/bool vars alike).
String boundTextExpr(String field) => "'\${$field}'";

/// A typed app-state variable with its default value.
class AppStateVar {
  final String name;
  final String type;
  final Object? defaultValue;

  const AppStateVar({
    required this.name,
    required this.type,
    this.defaultValue,
  });

  factory AppStateVar.fromJson(Map<String, dynamic> json) {
    for (final key in ['name', 'type']) {
      if (!json.containsKey(key)) {
        throw FormatException('AppStateVar missing required key: $key');
      }
    }
    return AppStateVar(
      name: json['name'] as String,
      type: json['type'] as String,
      // Missing key parses to null (backward compat); [validateAppStateVars]
      // flags it as a missing default.
      defaultValue: json.containsKey('default') ? json['default'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'default': defaultValue,
      };

  /// Same name/type/default with a new [name] (rename keeps type+default;
  /// changing those is delete + re-add, so defaults never need migration).
  AppStateVar renamed(String next) =>
      AppStateVar(name: next, type: type, defaultValue: defaultValue);

  @override
  bool operator ==(Object other) =>
      other is AppStateVar &&
      other.name == name &&
      other.type == type &&
      other.defaultValue == defaultValue;

  @override
  int get hashCode => Object.hash(name, type, defaultValue);
}

/// Semantic validation for a var list (unique names, identifier syntax,
/// known types, type-matching non-null defaults).
///
/// Returns human-readable problems (empty means OK). Never throws.
List<String> validateAppStateVars(List<AppStateVar> vars) {
  final problems = <String>[];
  final seen = <String>{};
  for (final v in vars) {
    if (!kAppStateName.hasMatch(v.name)) {
      problems.add('state var "${v.name}" is not a valid identifier');
    }
    if (!seen.add(v.name)) {
      problems.add('duplicate state var "${v.name}"');
    }
    if (!kAppStateTypes.contains(v.type)) {
      problems.add('state var "${v.name}" has unknown type "${v.type}"');
    } else if (!_defaultMatches(v.type, v.defaultValue)) {
      problems.add(
        'state var "${v.name}" default ${v.defaultValue} '
        'does not match type ${v.type}',
      );
    }
  }
  return problems;
}

/// Whether [def] is a valid default for [type] (null never matches — a
/// default is required; codegen substitutes the type zero-value for
/// hand-docs that omit it).
bool _defaultMatches(String type, Object? def) {
  switch (type) {
    case 'string':
      return def is String;
    case 'number':
      return def is num;
    case 'bool':
      return def is bool;
  }
  return false;
}

/// One ordered tap-action step.
///
/// Single class with a [kind] discriminator (not subclasses) so JSON stays
/// flat and every consumer (inspector, executor, codegen) switches in one
/// place. Only the fields for [kind] are meaningful; the rest are empty:
/// * `navigate`: [to] + [transition] (same shape as legacy `NodeAction`).
/// * `setState`: [variable] + [value] (type literal or `=otherVar`).
/// * `showSnackBar`: [message] (whole-value `=var` bindings resolve).
/// * `showDialog`: [title] + [message] (same binding rule).
/// * `condition`: [variable] + [equals] + [thenSteps] (runs `thenSteps`
///   when `stringify(value) == equals`).
/// * `apiCall`: [url] + [method] (`GET`/`POST`) + [headers] + [body] +
///   [saveTo] (optional var name receiving the response body string).
///   Secrets note: headers/bodies live in the doc like any other prop (no
///   vault — documented, not solved).
class ActionStep {
  final String kind;
  final String to;
  final String transition;
  final String variable;
  final String value;
  final String message;
  final String title;
  final String equals;
  final List<ActionStep> thenSteps;
  final String url;
  final String method;
  final Map<String, String> headers;
  final String body;
  final String saveTo;

  const ActionStep._({
    required this.kind,
    this.to = '',
    this.transition = 'slide',
    this.variable = '',
    this.value = '',
    this.message = '',
    this.title = '',
    this.equals = '',
    this.thenSteps = const [],
    this.url = '',
    this.method = 'GET',
    this.headers = const {},
    this.body = '',
    this.saveTo = '',
  });

  const ActionStep.navigate({required String to, String transition = 'slide'})
      : this._(kind: 'navigate', to: to, transition: transition);

  const ActionStep.setState({required String variable, required String value})
      : this._(kind: 'setState', variable: variable, value: value);

  const ActionStep.snackBar({required String message})
      : this._(kind: 'showSnackBar', message: message);

  const ActionStep.dialog({required String title, required String message})
      : this._(kind: 'showDialog', title: title, message: message);

  const ActionStep.condition({
    required String variable,
    required String equals,
    List<ActionStep> then = const [],
  }) : this._(kind: 'condition', variable: variable, equals: equals, thenSteps: then);

  const ActionStep.apiCall({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    String body = '',
    String saveTo = '',
  }) : this._(
          kind: 'apiCall',
          url: url,
          method: method,
          headers: headers,
          body: body,
          saveTo: saveTo,
        );

  factory ActionStep.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    if (kind == null || !kActionStepKinds.contains(kind)) {
      throw FormatException('ActionStep has unknown kind: $kind');
    }
    switch (kind) {
      case 'navigate':
        return ActionStep.navigate(
          to: json['to'] as String? ?? '',
          transition: json['transition'] as String? ?? 'slide',
        );
      case 'setState':
        return ActionStep.setState(
          variable: json['variable'] as String? ?? '',
          value: json['value'] as String? ?? '',
        );
      case 'showSnackBar':
        return ActionStep.snackBar(
          message: json['message'] as String? ?? '',
        );
      case 'showDialog':
        return ActionStep.dialog(
          title: json['title'] as String? ?? '',
          message: json['message'] as String? ?? '',
        );
      case 'condition':
        return ActionStep.condition(
          variable: json['variable'] as String? ?? '',
          equals: json['equals'] as String? ?? '',
          then: (json['then'] as List?)
                  ?.map((s) => ActionStep.fromJson(s as Map<String, dynamic>))
                  .toList() ??
              const [],
        );
      case 'apiCall':
        final headersRaw = json['headers'];
        final headers = <String, String>{};
        if (headersRaw is Map) {
          for (final entry in headersRaw.entries) {
            headers['${entry.key}'] = '${entry.value ?? ''}';
          }
        }
        return ActionStep.apiCall(
          url: json['url'] as String? ?? '',
          method: json['method'] as String? ?? 'GET',
          headers: headers,
          body: json['body'] as String? ?? '',
          saveTo: json['saveTo'] as String? ?? '',
        );
    }
    throw FormatException('ActionStep has unknown kind: $kind');
  }

  Map<String, dynamic> toJson() {
    switch (kind) {
      case 'navigate':
        return {'kind': kind, 'to': to, 'transition': transition};
      case 'setState':
        return {'kind': kind, 'variable': variable, 'value': value};
      case 'showSnackBar':
        return {'kind': kind, 'message': message};
      case 'showDialog':
        return {'kind': kind, 'title': title, 'message': message};
      case 'condition':
        return {
          'kind': kind,
          'variable': variable,
          'equals': equals,
          'then': [for (final s in thenSteps) s.toJson()],
        };
      case 'apiCall':
        return {
          'kind': kind,
          'url': url,
          'method': method,
          'headers': {for (final e in headers.entries) e.key: e.value},
          'body': body,
          'saveTo': saveTo,
        };
    }
    return {'kind': kind};
  }

  /// Copy with var [old] renamed to [next]: rewrites the step's own
  /// `variable` plus exact `=old` refs in `value`/`message`, recursing
  /// into [thenSteps]. An `apiCall` [saveTo] target renames like `variable`
  /// (it names a var); `url`/`body`/headers carry no bindings in v1.
  ActionStep withVariableRenamed(String old, String next) {
    String rewrite(String raw) => raw == '=$old' ? '=$next' : raw;
    return ActionStep._(
      kind: kind,
      to: to,
      transition: transition,
      variable: variable == old ? next : variable,
      value: rewrite(value),
      message: rewrite(message),
      title: title,
      equals: equals,
      thenSteps: [for (final s in thenSteps) s.withVariableRenamed(old, next)],
      url: url,
      method: method,
      headers: Map<String, String>.from(headers),
      body: body,
      saveTo: saveTo == old ? next : saveTo,
    );
  }

  /// Copy with bindings to deleted var [name] cleared to raw: exact
  /// `=name` refs in `value`/`message` become the bare `name` literal.
  /// `variable` refs are left intact (the executor skips unknown vars —
  /// see [partitionSteps]) — deleting a var never silently drops steps.
  /// An `apiCall` [saveTo] is left intact for the same reason (the executor
  /// runs the request and discards the response when the var is gone).
  ActionStep withBindingCleared(String name) {
    String clear(String raw) => raw == '=$name' ? name : raw;
    return ActionStep._(
      kind: kind,
      to: to,
      transition: transition,
      variable: variable,
      value: clear(value),
      message: clear(message),
      title: title,
      equals: equals,
      thenSteps: [for (final s in thenSteps) s.withBindingCleared(name)],
      url: url,
      method: method,
      headers: Map<String, String>.from(headers),
      body: body,
      saveTo: saveTo,
    );
  }

  bool _thenEquals(List<ActionStep> other) {
    if (thenSteps.length != other.length) return false;
    for (var i = 0; i < thenSteps.length; i++) {
      if (thenSteps[i] != other[i]) return false;
    }
    return true;
  }

  bool _headersEqual(Map<String, String> other) {
    if (headers.length != other.length) return false;
    for (final key in headers.keys) {
      if (!other.containsKey(key) || other[key] != headers[key]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ActionStep &&
      other.kind == kind &&
      other.to == to &&
      other.transition == transition &&
      other.variable == variable &&
      other.value == value &&
      other.message == message &&
      other.title == title &&
      other.equals == equals &&
      other.url == url &&
      other.method == method &&
      _headersEqual(other.headers) &&
      other.body == body &&
      other.saveTo == saveTo &&
      _thenEquals(other.thenSteps);

  @override
  int get hashCode {
    final sortedHeaders = headers.keys.toList()..sort();
    return Object.hash(
      kind,
      to,
      transition,
      variable,
      value,
      message,
      title,
      equals,
      url,
      method,
      Object.hashAll([for (final k in sortedHeaders) Object.hash(k, headers[k])]),
      body,
      saveTo,
      Object.hashAll(thenSteps),
    );
  }
}

/// Short summary for code comments (`setState count`, `navigate s2`).
String stepSummary(ActionStep step) {
  switch (step.kind) {
    case 'navigate':
      return 'navigate ${step.to}';
    case 'setState':
      return 'setState ${step.variable}';
    case 'showSnackBar':
      return 'snackBar';
    case 'showDialog':
      return 'dialog';
    case 'condition':
      return 'if ${step.variable}';
    case 'apiCall':
      if (step.url.isEmpty) return 'apiCall';
      return 'apiCall ${step.method} ${step.url}';
  }
  return step.kind;
}

/// Every navigate target in [steps], recursing into conditions (document
/// order). Used by ref-integrity checks and legacy-`to` syncing.
List<String> navigateTargetsOf(List<ActionStep> steps) {
  final out = <String>[];
  for (final s in steps) {
    if (s.kind == 'navigate') {
      out.add(s.to);
    } else if (s.kind == 'condition') {
      out.addAll(navigateTargetsOf(s.thenSteps));
    }
  }
  return out;
}

/// Semantic validation for step lists (unknown navigate targets, unknown
/// vars, mistyped literals).
///
/// [screenIds] are the legal navigate targets; [vars] the known state vars.
/// `setState` values that are bindings (`=other`) are only checked for
/// shape, not type (the session decides at runtime). Never throws.
List<String> validateActionSteps(
  List<ActionStep> steps, {
  required Set<String> screenIds,
  required Map<String, AppStateVar> vars,
}) {
  final problems = <String>[];
  void walk(List<ActionStep> list) {
    for (final s in list) {
      switch (s.kind) {
        case 'navigate':
          if (!screenIds.contains(s.to)) {
            problems.add('action navigates to unknown screen "${s.to}"');
          }
        case 'setState':
          final target = vars[s.variable];
          if (target == null) {
            problems.add('action sets unknown state "${s.variable}"');
          } else if (bindingNameOf(s.value) == null &&
              parseStateLiteral(s.value, target.type) == null) {
            problems.add(
              'action value "${s.value}" does not match '
              '${target.type} state "${s.variable}"',
            );
          }
        case 'condition':
          if (!vars.containsKey(s.variable)) {
            problems.add('action condition reads unknown state "${s.variable}"');
          }
          walk(s.thenSteps);
        case 'apiCall':
          if (!isApiCallUrlValid(s.url)) {
            problems.add('action apiCall has invalid URL "${s.url}"');
          }
          if (!kApiCallMethods.contains(s.method)) {
            problems.add('action apiCall has unknown method "${s.method}"');
          }
          for (final entry in s.headers.entries) {
            if (!isApiHeaderValid(entry.key, entry.value)) {
              problems.add('action apiCall has invalid header "${entry.key}"');
            }
          }
          if (s.saveTo.isNotEmpty) {
            final target = vars[s.saveTo];
            if (target == null) {
              problems.add('action apiCall saves to unknown state "${s.saveTo}"');
            } else if (target.type != 'string') {
              problems.add(
                'action apiCall saves to non-string state "${s.saveTo}" '
                '(response stored as text)',
              );
            }
          }
        case 'showSnackBar':
        case 'showDialog':
          break;
      }
    }
  }

  walk(steps);
  return problems;
}

/// Whether the condition [step] holds under [values]: the var must exist
/// and `stringify(value) == equals`. Unknown vars are false (skip, never
/// crash).
bool conditionHolds(ActionStep step, Map<String, dynamic> values) {
  if (!values.containsKey(step.variable)) return false;
  return stringifyStateValue(values[step.variable]) == step.equals;
}

/// Execution plan: [immediate] steps run first in order (conditions already
/// evaluated against [values], their taken branches flattened inline),
/// then [navigate] steps in order (navigation-last semantics — see the
/// library docs). Steps referencing unknown vars vanish here (conditions
/// are false; `setState` on an unknown var is dropped, not kept — the
/// executor only receives known-var writes).
StepPlan partitionSteps(
  List<ActionStep> steps,
  Map<String, dynamic> values, {
  required Set<String> knownVars,
}) {
  final immediate = <ActionStep>[];
  final navigate = <ActionStep>[];
  void walk(List<ActionStep> list) {
    for (final s in list) {
      switch (s.kind) {
        case 'navigate':
          navigate.add(s);
        case 'condition':
          if (conditionHolds(s, values)) walk(s.thenSteps);
        case 'setState':
          if (knownVars.contains(s.variable)) immediate.add(s);
        case 'apiCall':
          // Immediate like the other non-navigation steps: runs in order
          // before navigations (conditions already flattened above). The
          // response save is best-effort — an unknown [saveTo] discards at
          // runtime instead of dropping the request here.
          immediate.add(s);
        case 'showSnackBar':
        case 'showDialog':
          immediate.add(s);
      }
    }
  }

  walk(steps);
  return StepPlan(immediate: immediate, navigate: navigate);
}

/// Ordered execution plan from [partitionSteps].
class StepPlan {
  final List<ActionStep> immediate;
  final List<ActionStep> navigate;

  const StepPlan({required this.immediate, required this.navigate});
}

/// Parses a `setState` literal for [type]: strings accept anything,
/// numbers try-parse, bools accept `true`/`false` (trimmed,
/// case-insensitive). Null when unparseable (caller keeps the current
/// value) — never throws.
Object? parseStateLiteral(String raw, String type) {
  switch (type) {
    case 'string':
      return raw;
    case 'number':
      return num.tryParse(raw.trim());
    case 'bool':
      final t = raw.trim().toLowerCase();
      if (t == 'true') return true;
      if (t == 'false') return false;
      return null;
  }
  return null;
}

/// Coerces a session value [v] to [type] (binding refs across types):
/// strings stringify anything non-null; numbers take nums, bools as 1/0,
/// and parseable strings; bools take bools, nonzero nums, and
/// `true`/`false` strings. Null when uncoercible — never throws.
Object? coerceStateValue(Object? v, String type) {
  switch (type) {
    case 'string':
      return v == null ? null : stringifyStateValue(v);
    case 'number':
      if (v is num) return v;
      if (v is bool) return v ? 1 : 0;
      if (v is String) return num.tryParse(v.trim());
      return null;
    case 'bool':
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true') return true;
        if (t == 'false') return false;
      }
      return null;
  }
  return null;
}

/// Resolves a `setState` [raw] value against the live [values]: `=other`
/// refs coerce the referenced value to the target type; literals parse by
/// type. Null when unresolvable (caller keeps the current value).
Object? resolveActionValue({
  required String raw,
  required AppStateVar target,
  required Map<String, dynamic> values,
}) {
  final ref = bindingNameOf(raw);
  if (ref != null) {
    if (!values.containsKey(ref)) return null;
    return coerceStateValue(values[ref], target.type);
  }
  return parseStateLiteral(raw, target.type);
}

/// Resolves display/message text: a whole-value `=var` binding reads the
/// referenced session value (stringified; unknown refs fall back to the
/// raw string), anything else passes through.
String resolveStepText(String raw, Map<String, dynamic> values) {
  final ref = bindingNameOf(raw);
  if (ref == null) return raw;
  if (!values.containsKey(ref)) return raw;
  return stringifyStateValue(values[ref]);
}

/// Field names for codegen (`name` → `_name`; names are identifier-safe by
/// [validateAppStateVars], so the field is always a valid identifier).
Map<String, String> stateFieldsFor(List<AppStateVar> vars) =>
    {for (final v in vars) v.name: '_${v.name}'};

/// Stateful field declaration with its default (`String _name = 'Ada';`).
/// Unknown types and null defaults fall back to the type zero-value
/// (`''`/`0`/`false`) so hand-docs never emit invalid Dart.
String stateFieldDecl(AppStateVar v) {
  switch (v.type) {
    case 'number':
      final def = v.defaultValue;
      return 'num _${v.name} = ${def is num ? '$def' : '0'};';
    case 'bool':
      final def = v.defaultValue;
      return 'bool _${v.name} = ${def is bool ? '$def' : 'false'};';
    case 'string':
    default:
      final def = v.defaultValue;
      return 'String _${v.name} = ${dartStringLiteral(def is String ? def : '')};';
  }
}

/// Dart assignment RHS for a `setState` [raw] value: same-type refs copy
/// the field directly; cross-type refs coerce (string targets stringify,
/// number targets parse-or-default, bool targets compare); literals parse
/// with the default as fallback. Always a valid expression given a
/// consistent [fields]/[vars] pair; unknown refs self-assign (compiles to
/// a no-op — the runtime skips them instead).
String stateAssignExpr({
  required String raw,
  required AppStateVar target,
  required Map<String, String> fields,
  required Map<String, AppStateVar> vars,
}) {
  final own = fields[target.name] ?? '_${target.name}';
  final ref = bindingNameOf(raw);
  if (ref != null) {
    final field = fields[ref];
    if (field == null) return own;
    final source = vars[ref];
    if (source == null || source.type == target.type) return field;
    if (target.type == 'string') return '$field.toString()';
    if (target.type == 'number') {
      if (source.type == 'bool') return '$field ? 1 : 0';
      return 'num.tryParse($field.toString()) ?? ${_numDefault(target)}';
    }
    if (source.type == 'number') return '$field != 0';
    return "($field.toString() == 'true')";
  }
  switch (target.type) {
    case 'number':
      return '${num.tryParse(raw.trim()) ?? _numDefault(target)}';
    case 'bool':
      final parsed = parseStateLiteral(raw, 'bool');
      if (parsed is bool) return '$parsed';
      return '${target.defaultValue is bool ? target.defaultValue : false}';
    case 'string':
    default:
      return dartStringLiteral(raw);
  }
}

/// Dart expression for message/title text: known `=var` bindings read the
/// field via interpolation, everything else is a quoted literal.
String stepTextExpr(String raw, Map<String, String> fields) {
  final ref = bindingNameOf(raw);
  if (ref != null && fields.containsKey(ref)) {
    return boundTextExpr(fields[ref]!);
  }
  return dartStringLiteral(raw);
}

/// Dart boolean expression for a condition step: uniform string comparison
/// (`'${_flag}' == 'true'`), mirroring [conditionHolds]. Unknown vars emit
/// `false` (skip, never crash).
String conditionDartExpr(ActionStep step, Map<String, String> fields) {
  final field = fields[step.variable];
  if (field == null) {
    return 'false /* unknown state "${step.variable}" */';
  }
  return "'\${$field}' == ${dartStringLiteral(step.equals)}";
}

num _numDefault(AppStateVar target) =>
    target.defaultValue is num ? target.defaultValue as num : 0;

/// Emits one method-body statement list for [steps] (shared by the
/// single-file and bundle exporters so runtime and codegen agree).
///
/// Dart assignment RHS for an `apiCall` response [bodyVar] (always a
/// runtime `String`): string targets take it directly, number targets parse
/// with the default as fallback, bool targets compare case-insensitively.
String apiAssignExpr(String bodyVar, AppStateVar target) {
  switch (target.type) {
    case 'number':
      return 'num.tryParse($bodyVar.trim()) ?? ${_numDefault(target)}';
    case 'bool':
      return "($bodyVar.trim().toLowerCase() == 'true')";
    case 'string':
    default:
      return bodyVar;
  }
}

/// [routeOf] maps a navigate target to its route (null = unknown — a
/// comment, never a crash). Statements use `setState`/`ScaffoldMessenger`/
/// `showDialog`/`Navigator`, so single-file screens that emit them need
/// the material import (see `_needsMaterialSteps` there). `apiCall` steps
/// emit `package:http` calls (the enclosing tap method must be `async` —
/// see [stepsNeedHttp]) with a 10s timeout ([kApiCallTimeout]); transport
/// errors are swallowed with a comment, and the response body string feeds
/// [saveTo] (coerced per type via [apiAssignExpr], discarded when empty or
/// unknown).
List<String> emitStepStatements({
  required List<ActionStep> steps,
  required Map<String, AppStateVar> vars,
  required Map<String, String> fields,
  required String? Function(String to) routeOf,
  String indent = '    ',
}) {
  final out = <String>[];
  var apiIndex = 0;
  void walk(List<ActionStep> list, String pad) {
    for (final s in list) {
      switch (s.kind) {
        case 'setState':
          final target = vars[s.variable];
          if (target == null) {
            out.add('$pad// unknown state "${s.variable}": skipped.');
            continue;
          }
          final own = fields[s.variable] ?? '_${s.variable}';
          out.add('${pad}setState(() {');
          out.add(
            '$pad  $own = ${stateAssignExpr(raw: s.value, target: target, fields: fields, vars: vars)};',
          );
          out.add('$pad});');
        case 'showSnackBar':
          out.add(
            '${pad}ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(${stepTextExpr(s.message, fields)})));',
          );
        case 'showDialog':
          out.add(
            '${pad}showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(',
          );
          out.add('$pad  title: Text(${stepTextExpr(s.title, fields)}),');
          out.add('$pad  content: Text(${stepTextExpr(s.message, fields)}),');
          out.add('$pad));');
        case 'condition':
          out.add('${pad}if (${conditionDartExpr(s, fields)}) {');
          walk(s.thenSteps, '$pad  ');
          out.add('$pad}');
        case 'apiCall':
          if (!isApiCallUrlValid(s.url)) {
            final safe = s.url.replaceAll('\n', ' ').replaceAll('\r', ' ');
            out.add('$pad// apiCall skipped: invalid URL "$safe".');
            continue;
          }
          if (!kApiCallMethods.contains(s.method)) {
            out.add('$pad// apiCall skipped: unknown method "${s.method}".');
            continue;
          }
          final idx = apiIndex++;
          final uriVar = '_apiUri$idx';
          final respVar = '_apiResp$idx';
          final bodyVar = '_apiBody$idx';
          out.add('${pad}try {');
          out.add('$pad  final $uriVar = Uri.parse(${dartStringLiteral(s.url)});');
          final headersExpr =
              s.headers.isEmpty ? null : apiHeadersDart(s.headers);
          if (s.method == 'POST') {
            final args = <String>[
              if (headersExpr != null) 'headers: $headersExpr',
              if (s.body.isNotEmpty) 'body: ${dartStringLiteral(s.body)}',
            ];
            final argText = args.isEmpty ? '' : ', ${args.join(', ')}';
            out.add(
              '$pad  final $respVar = await http.post($uriVar$argText).timeout(const Duration(seconds: 10));',
            );
          } else {
            final argText =
                headersExpr == null ? '' : ', headers: $headersExpr';
            out.add(
              '$pad  final $respVar = await http.get($uriVar$argText).timeout(const Duration(seconds: 10));',
            );
          }
          out.add('$pad  final $bodyVar = $respVar.body;');
          if (s.saveTo.isEmpty) {
            out.add('$pad  // apiCall response discarded (no saveTo).');
          } else {
            final target = vars[s.saveTo];
            if (target == null) {
              out.add(
                '$pad  // unknown state "${s.saveTo}": response discarded.',
              );
            } else {
              final own = fields[s.saveTo] ?? '_${s.saveTo}';
              out.add('${pad}  setState(() {');
              out.add('$pad    $own = ${apiAssignExpr(bodyVar, target)};');
              out.add('$pad  });');
            }
          }
          out.add('$pad} catch (_) {');
          out.add('$pad  // apiCall failed: skipped.');
          out.add('$pad}');
        case 'navigate':
          final route = routeOf(s.to);
          if (route == null) {
            out.add("$pad// unknown target '${s.to}': no navigation.");
          } else {
            out.add(
              "${pad}Navigator.of(context).pushNamed('$route'); // transition: ${s.transition}",
            );
          }
      }
    }
  }

  walk(steps, indent);
  return out;
}

/// Whether any step (recursing into conditions) needs material-only APIs
/// (`showSnackBar`/`showDialog` — `setState`/`navigate` are widgets-level).
bool stepsNeedMaterial(List<ActionStep> steps) {
  for (final s in steps) {
    if (s.kind == 'showSnackBar' || s.kind == 'showDialog') return true;
    if (s.kind == 'condition' && stepsNeedMaterial(s.thenSteps)) return true;
  }
  return false;
}

/// Sanitizes an item id into a method-name suffix (`i-1` → `i_1`).
String methodNameFor(String prefix, String itemId) {
  final cleaned = itemId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  final safe = cleaned.isEmpty ? 'item' : cleaned;
  final head = RegExp(r'^[0-9]').hasMatch(safe) ? '_$safe' : safe;
  return '${prefix}_$head';
}
