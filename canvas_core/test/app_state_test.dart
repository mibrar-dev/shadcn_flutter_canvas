/// Track R1: app-state vars, bindings, action steps, and their codegen
/// helpers (validation + JSON round-trip + execution semantics).
library;

import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

ScreenDoc _docWith({List<Map<String, dynamic>> states = const [], List<Map<String, dynamic>> items = const []}) =>
    ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Done', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': items,
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'T', 'brief': ''},
      if (states.isNotEmpty) 'states': states,
    });

void main() {
  group('AppStateVar', () {
    test('round-trips through JSON', () {
      const v = AppStateVar(name: 'count', type: 'number', defaultValue: 3);
      final back = AppStateVar.fromJson(
        jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>,
      );
      expect(back, v);
      expect(back.toJson(), {'name': 'count', 'type': 'number', 'default': 3});
    });

    test('missing default parses to null', () {
      final v = AppStateVar.fromJson({'name': 'x', 'type': 'string'});
      expect(v.defaultValue, isNull);
    });

    test('missing name/type throws', () {
      expect(
        () => AppStateVar.fromJson({'name': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('valid list passes', () {
      expect(
        validateAppStateVars(const [
          AppStateVar(name: 'count', type: 'number', defaultValue: 0),
          AppStateVar(name: 'label', type: 'string', defaultValue: 'hi'),
          AppStateVar(name: 'flag', type: 'bool', defaultValue: false),
          AppStateVar(name: '_x1', type: 'number', defaultValue: 1.5),
        ]),
        isEmpty,
      );
    });

    test('flags bad identifiers, duplicates, types, defaults', () {
      final problems = validateAppStateVars(const [
        AppStateVar(name: '9bad', type: 'number', defaultValue: 0),
        AppStateVar(name: 'ok', type: 'number', defaultValue: 0),
        AppStateVar(name: 'ok', type: 'string', defaultValue: 'x'),
        AppStateVar(name: 'weird', type: 'date', defaultValue: 'x'),
        AppStateVar(name: 's', type: 'string', defaultValue: 3),
        AppStateVar(name: 'n', type: 'number', defaultValue: 'x'),
        AppStateVar(name: 'b', type: 'bool', defaultValue: 1),
        AppStateVar(name: 'missing', type: 'bool'),
      ]);
      expect(problems, hasLength(7));
      expect(problems.any((p) => p.contains('"9bad"')), isTrue);
      expect(problems.any((p) => p.contains('duplicate')), isTrue);
      expect(problems.any((p) => p.contains('unknown type')), isTrue);
      expect(problems.where((p) => p.contains('does not match')).length, 4);
      expect(problems.any((p) => p.contains('"missing"')), isTrue);
    });
  });

  group('ScreenDoc.states', () {
    test('missing key parses to empty (backward compat)', () {
      final doc = _docWith();
      expect(doc.states, isEmpty);
    });

    test('toJson always emits states', () {
      expect(_docWith().toJson(), contains('states'));
      expect(_docWith().toJson()['states'], isEmpty);
    });

    test('round-trips vars', () {
      final doc = _docWith(states: [
        {'name': 'count', 'type': 'number', 'default': 2},
        {'name': 'label', 'type': 'string', 'default': 'hi'},
      ]);
      final back = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(back.states, doc.states);
    });
  });

  group('NodeAction.steps', () {
    test('missing key parses to empty', () {
      const action = NodeAction(to: 's2', transition: 'slide');
      expect(action.steps, isEmpty);
    });

    test('toJson omits steps when empty (byte-identical legacy)', () {
      expect(
        const NodeAction(to: 's2', transition: 'slide').toJson(),
        {'to': 's2', 'transition': 'slide'},
      );
    });

    test('round-trips nested steps', () {
      const action = NodeAction(
        to: 's2',
        transition: 'slide',
        steps: [
          ActionStep.setState(variable: 'count', value: '1'),
          ActionStep.condition(
            variable: 'flag',
            equals: 'true',
            then: [ActionStep.navigate(to: 's2')],
          ),
        ],
      );
      final back = NodeAction.fromJson(
        jsonDecode(jsonEncode(action.toJson())) as Map<String, dynamic>,
      );
      expect(back, isNotNull);
      expect(back.steps, action.steps);
      expect(back.toJson(), action.toJson());
    });

    test('unknown step kind throws', () {
      expect(
        () => ActionStep.fromJson({'kind': 'teleport'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('effectiveActionSteps', () {
    test('null action runs nothing', () {
      expect(effectiveActionSteps(null), isEmpty);
    });

    test('legacy action becomes one navigate step', () {
      final steps = effectiveActionSteps(
        const NodeAction(to: 's2', transition: 'fade'),
      );
      expect(steps, hasLength(1));
      expect(steps.single.kind, 'navigate');
      expect(steps.single.to, 's2');
      expect(steps.single.transition, 'fade');
    });

    test('steps win over legacy to', () {
      const action = NodeAction(
        to: 's1',
        transition: 'slide',
        steps: [ActionStep.snackBar(message: 'hi')],
      );
      expect(effectiveActionSteps(action), action.steps);
    });
  });

  group('validateRefs with steps', () {
    test('checks navigate steps, ignores legacy to when stepped', () {
      final doc = _docWith(items: [
        {
          'id': 'i1',
          'kind': 'button',
          'label': 'Go',
          'action': {
            'to': 'gone-legacy',
            'transition': 'slide',
            'steps': [
              {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
            ],
          },
        },
        {
          'id': 'i2',
          'kind': 'button',
          'label': 'Bad',
          'action': {
            'to': 's2',
            'transition': 'slide',
            'steps': [
              {'kind': 'navigate', 'to': 'gone', 'transition': 'fade'},
            ],
          },
        },
      ]);
      expect(doc.validateRefs(), [
        'dangling action i2 -> missing screen gone',
      ]);
    });
  });

  group('bindings', () {
    test('isStateBinding / bindingNameOf table', () {
      expect(isStateBinding('=count'), isTrue);
      expect(bindingNameOf('=count'), 'count');
      expect(isStateBinding('='), isFalse);
      expect(bindingNameOf('='), isNull);
      expect(isStateBinding('plain'), isFalse);
      expect(isStateBinding(3), isFalse);
      expect(isStateBinding(null), isFalse);
    });

    test('stringifyStateValue renders bool/num/string', () {
      expect(stringifyStateValue(true), 'true');
      expect(stringifyStateValue(3), '3');
      expect(stringifyStateValue('hi'), 'hi');
    });
  });

  group('partitionSteps (navigation last)', () {
    const vars = {'count', 'flag'};

    test('runs immediates in order, navigations last', () {
      final plan = partitionSteps(
        const [
          ActionStep.navigate(to: 's2'),
          ActionStep.setState(variable: 'count', value: '1'),
          ActionStep.snackBar(message: 'saved'),
        ],
        {'count': 0},
        knownVars: vars,
      );
      expect(plan.immediate.map((s) => s.kind), ['setState', 'showSnackBar']);
      expect(plan.navigate.map((s) => s.to), ['s2']);
    });

    test('true condition inlines its branch', () {
      final plan = partitionSteps(
        const [
          ActionStep.condition(
            variable: 'flag',
            equals: 'true',
            then: [
              ActionStep.setState(variable: 'count', value: '9'),
              ActionStep.navigate(to: 's2'),
            ],
          ),
        ],
        {'flag': true, 'count': 0},
        knownVars: vars,
      );
      expect(plan.immediate.map((s) => s.kind), ['setState']);
      expect(plan.navigate.map((s) => s.to), ['s2']);
    });

    test('false condition and unknown vars are skipped', () {
      final plan = partitionSteps(
        const [
          ActionStep.condition(
            variable: 'flag',
            equals: 'true',
            then: [ActionStep.navigate(to: 's2')],
          ),
          ActionStep.condition(
            variable: 'ghost',
            equals: 'x',
            then: [ActionStep.navigate(to: 's2')],
          ),
          ActionStep.setState(variable: 'ghost', value: '1'),
        ],
        {'flag': false},
        knownVars: vars,
      );
      expect(plan.immediate, isEmpty);
      expect(plan.navigate, isEmpty);
    });
  });

  group('resolveActionValue', () {
    const count = AppStateVar(name: 'count', type: 'number', defaultValue: 0);
    const label = AppStateVar(name: 'label', type: 'string', defaultValue: '');
    const flag = AppStateVar(name: 'flag', type: 'bool', defaultValue: false);

    test('parses literals by type', () {
      expect(
        resolveActionValue(raw: '12', target: count, values: const {}),
        12,
      );
      expect(
        resolveActionValue(raw: '1.5', target: count, values: const {}),
        1.5,
      );
      expect(
        resolveActionValue(raw: 'nope', target: count, values: const {}),
        isNull,
      );
      expect(
        resolveActionValue(raw: 'TRUE', target: flag, values: const {}),
        isTrue,
      );
      expect(
        resolveActionValue(raw: 'anything', target: label, values: const {}),
        'anything',
      );
    });

    test('resolves =other refs with coercion', () {
      const values = {'n': 4, 's': '7', 'b': true};
      expect(
        resolveActionValue(raw: '=n', target: count, values: values),
        4,
      );
      expect(
        resolveActionValue(raw: '=s', target: count, values: values),
        7,
      );
      expect(
        resolveActionValue(raw: '=b', target: label, values: values),
        'true',
      );
      expect(
        resolveActionValue(raw: '=missing', target: count, values: values),
        isNull,
      );
      expect(
        resolveActionValue(raw: '=s', target: flag, values: values),
        isNull,
      );
    });
  });

  group('validateActionSteps', () {
    final vars = {
      'count': const AppStateVar(name: 'count', type: 'number', defaultValue: 0),
    };

    test('flags unknown screens, vars, and mistyped values', () {
      final problems = validateActionSteps(
        const [
          ActionStep.navigate(to: 'gone'),
          ActionStep.setState(variable: 'ghost', value: '1'),
          ActionStep.setState(variable: 'count', value: 'abc'),
          ActionStep.condition(variable: 'ghost', equals: '1'),
        ],
        screenIds: const {'s1'},
        vars: vars,
      );
      expect(problems, hasLength(4));
    });

    test('accepts valid flows incl. =refs', () {
      expect(
        validateActionSteps(
          const [
            ActionStep.setState(variable: 'count', value: '=count'),
            ActionStep.setState(variable: 'count', value: '3'),
            ActionStep.condition(
              variable: 'count',
              equals: '3',
              then: [ActionStep.navigate(to: 's1')],
            ),
          ],
          screenIds: const {'s1'},
          vars: vars,
        ),
        isEmpty,
      );
    });
  });

  group('codegen helpers', () {
    test('stateFieldDecl covers types and null-default fallback', () {
      expect(
        stateFieldDecl(
          const AppStateVar(name: 'n', type: 'string', defaultValue: 'Ada'),
        ),
        "String _n = 'Ada';",
      );
      expect(
        stateFieldDecl(
          const AppStateVar(name: 'c', type: 'number', defaultValue: 3),
        ),
        'num _c = 3;',
      );
      expect(
        stateFieldDecl(
          const AppStateVar(name: 'f', type: 'bool', defaultValue: true),
        ),
        'bool _f = true;',
      );
      expect(stateFieldDecl(const AppStateVar(name: 'x', type: 'number')), 'num _x = 0;');
    });

    test('dartStringLiteral escapes quotes, dollars, newlines', () {
      expect(dartStringLiteral("it's \$5\n"), r"'it\'s \$5\n'");
    });

    test('stateAssignExpr copies same-type refs, coerces across types', () {
      const count = AppStateVar(name: 'count', type: 'number', defaultValue: 0);
      const total = AppStateVar(name: 'total', type: 'number', defaultValue: 0);
      const label = AppStateVar(name: 'label', type: 'string', defaultValue: '');
      const flag = AppStateVar(name: 'flag', type: 'bool', defaultValue: false);
      const vars = {'count': count, 'total': total, 'label': label, 'flag': flag};
      const fields = {'count': '_count', 'total': '_total', 'label': '_label', 'flag': '_flag'};
      expect(
        stateAssignExpr(raw: '=count', target: total, fields: fields, vars: vars),
        '_count',
      );
      expect(
        stateAssignExpr(raw: '5', target: total, fields: fields, vars: vars),
        '5',
      );
      expect(
        stateAssignExpr(raw: '=count', target: label, fields: fields, vars: vars),
        '_count.toString()',
      );
      expect(
        stateAssignExpr(raw: '=ghost', target: total, fields: fields, vars: vars),
        '_total',
      );
      expect(
        stateAssignExpr(raw: '=flag', target: total, fields: fields, vars: vars),
        '_flag ? 1 : 0',
      );
    });

    test('stepTextExpr interpolates known bindings only', () {
      expect(stepTextExpr('=count', const {'count': '_count'}), "'\${_count}'");
      expect(stepTextExpr('=ghost', const {'count': '_count'}), "'=ghost'");
      expect(stepTextExpr('plain', const {'count': '_count'}), "'plain'");
    });

    test('conditionDartExpr compares stringified field', () {
      expect(
        conditionDartExpr(
          const ActionStep.condition(variable: 'flag', equals: 'true'),
          const {'flag': '_flag'},
        ),
        "'\${_flag}' == 'true'",
      );
      expect(
        conditionDartExpr(
          const ActionStep.condition(variable: 'ghost', equals: 'x'),
          const {},
        ),
        'false /* unknown state "ghost" */',
      );
    });

    test('emitStepStatements orders setState/feedback/navigation', () {
      const vars = {
        'count': AppStateVar(name: 'count', type: 'number', defaultValue: 0),
      };
      const fields = {'count': '_count'};
      final lines = emitStepStatements(
        steps: const [
          ActionStep.setState(variable: 'count', value: '1'),
          ActionStep.snackBar(message: 'saved'),
          ActionStep.dialog(title: 'Hi', message: 'body'),
          ActionStep.condition(
            variable: 'count',
            equals: '1',
            then: [ActionStep.navigate(to: 's2')],
          ),
          ActionStep.navigate(to: 'gone'),
        ],
        vars: vars,
        fields: fields,
        routeOf: (to) => to == 's2' ? '/done' : null,
      );
      expect(lines.join('\n'), contains('setState(() {'));
      expect(lines.join('\n'), contains('_count = 1;'));
      expect(lines.join('\n'), contains('showSnackBar'));
      expect(lines.join('\n'), contains('showDialog<void>'));
      expect(lines.join('\n'), contains("if ('\${_count}' == '1') {"));
      expect(lines.join('\n'), contains("pushNamed('/done')"));
      expect(lines.join('\n'), contains("// unknown target 'gone'"));
    });

    test('stepsNeedMaterial detects snackBar/dialog incl. nested', () {
      expect(stepsNeedMaterial(const [ActionStep.snackBar(message: 'x')]), isTrue);
      expect(
        stepsNeedMaterial(
          const [
            ActionStep.condition(
              variable: 'a',
              equals: 'b',
              then: [ActionStep.dialog(title: 't', message: 'm')],
            ),
          ],
        ),
        isTrue,
      );
      expect(
        stepsNeedMaterial(const [ActionStep.navigate(to: 's1')]),
        isFalse,
      );
    });

    test('methodNameFor sanitizes item ids', () {
      expect(methodNameFor('_onTap', 'i1'), '_onTap_i1');
      expect(methodNameFor('_onTap', 'a-b c'), '_onTap_a_b_c');
    });
  });
}
