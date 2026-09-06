/// Track S1: `apiCall` action step — model round-trip, validation, ordering,
/// and shared codegen helpers. Core stays Flutter-free AND http-free (plain
/// data + code strings only).
library;

import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

void main() {
  group('apiCall model', () {
    test('round-trips through JSON', () {
      const step = ActionStep.apiCall(
        url: 'https://api.example.com/items',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: '{"a":1}',
        saveTo: 'result',
      );
      final back = ActionStep.fromJson(
        jsonDecode(jsonEncode(step.toJson())) as Map<String, dynamic>,
      );
      expect(back, step);
      expect(back.toJson(), {
        'kind': 'apiCall',
        'url': 'https://api.example.com/items',
        'method': 'POST',
        'headers': {'Content-Type': 'application/json'},
        'body': '{"a":1}',
        'saveTo': 'result',
      });
    });

    test('missing optionals default (GET, empty headers/body/saveTo)', () {
      final step = ActionStep.fromJson({
        'kind': 'apiCall',
        'url': 'https://x.test/',
      });
      expect(step.method, 'GET');
      expect(step.headers, isEmpty);
      expect(step.body, isEmpty);
      expect(step.saveTo, isEmpty);
    });

    test('unknown kind still rejects', () {
      expect(
        () => ActionStep.fromJson({'kind': 'teleport'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('kActionStepKinds contains apiCall', () {
      expect(kActionStepKinds, contains('apiCall'));
    });

    test('saveTo renames with the var; bindings clear leaves it intact', () {
      const step = ActionStep.apiCall(
        url: 'https://x.test/',
        saveTo: 'old',
      );
      expect(step.withVariableRenamed('old', 'next').saveTo, 'next');
      expect(step.withVariableRenamed('other', 'next').saveTo, 'old');
      expect(step.withBindingCleared('old').saveTo, 'old');
    });

    test('headers equality is order-independent', () {
      const a = ActionStep.apiCall(
        url: 'https://x.test/',
        headers: {'A': '1', 'B': '2'},
      );
      const b = ActionStep.apiCall(
        url: 'https://x.test/',
        headers: {'B': '2', 'A': '1'},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('apiCall validation', () {
    final vars = {
      'result': const AppStateVar(
        name: 'result',
        type: 'string',
        defaultValue: '',
      ),
      'count': const AppStateVar(
        name: 'count',
        type: 'number',
        defaultValue: 0,
      ),
    };

    test('accepts a valid GET with string saveTo', () {
      expect(
        validateActionSteps(
          const [
            ActionStep.apiCall(
              url: 'https://api.example.com/items',
              saveTo: 'result',
            ),
          ],
          screenIds: const {'s1'},
          vars: vars,
        ),
        isEmpty,
      );
    });

    test('flags bad URL, method, headers, and saveTo (warn, never throw)', () {
      final problems = validateActionSteps(
        const [
          ActionStep.apiCall(url: 'not-a-url', saveTo: 'result'),
          ActionStep.apiCall(url: 'ftp://x.test/', method: 'PUT'),
          ActionStep.apiCall(
            url: 'https://x.test/',
            headers: {'': 'v'},
            saveTo: 'ghost',
          ),
          ActionStep.apiCall(
            url: 'https://x.test/',
            saveTo: 'count',
          ),
        ],
        screenIds: const {'s1'},
        vars: vars,
      );
      expect(problems.any((p) => p.contains('invalid URL')), isTrue);
      expect(problems.any((p) => p.contains('unknown method')), isTrue);
      expect(problems.any((p) => p.contains('invalid header')), isTrue);
      expect(
        problems.any((p) => p.contains('unknown state "ghost"')),
        isTrue,
      );
      expect(
        problems.any((p) => p.contains('non-string state "count"')),
        isTrue,
      );
    });

    test('URL helper table', () {
      expect(isApiCallUrlValid('https://a.b/c'), isTrue);
      expect(isApiCallUrlValid('http://localhost:8080/x'), isTrue);
      expect(isApiCallUrlValid('  https://a.b/  '), isTrue);
      expect(isApiCallUrlValid(''), isFalse);
      expect(isApiCallUrlValid('ftp://a.b/'), isFalse);
      expect(isApiCallUrlValid('https://'), isFalse);
      expect(isApiCallUrlValid('notaurl'), isFalse);
    });
  });

  group('apiCall ordering', () {
    test('partitionSteps runs apiCall as immediate before navigations', () {
      final plan = partitionSteps(
        const [
          ActionStep.navigate(to: 's2'),
          ActionStep.apiCall(url: 'https://a.b/'),
          ActionStep.setState(variable: 'result', value: 'x'),
        ],
        {'result': ''},
        knownVars: const {'result'},
      );
      expect(
        plan.immediate.map((s) => s.kind),
        ['apiCall', 'setState'],
      );
      expect(plan.navigate.map((s) => s.to), ['s2']);
    });

    test('apiCall inside a taken condition branch is hoisted to immediate', () {
      final plan = partitionSteps(
        const [
          ActionStep.condition(
            variable: 'flag',
            equals: 'true',
            then: [
              ActionStep.apiCall(url: 'https://a.b/'),
              ActionStep.navigate(to: 's2'),
            ],
          ),
        ],
        {'flag': true},
        knownVars: const {'flag'},
      );
      expect(plan.immediate.map((s) => s.kind), ['apiCall']);
      expect(plan.navigate.map((s) => s.to), ['s2']);
    });

    test('stepsNeedHttp detects apiCall incl. nested', () {
      expect(
        stepsNeedHttp(const [ActionStep.apiCall(url: 'https://a.b/')]),
        isTrue,
      );
      expect(
        stepsNeedHttp(
          const [
            ActionStep.condition(
              variable: 'f',
              equals: 'x',
              then: [ActionStep.apiCall(url: 'https://a.b/')],
            ),
          ],
        ),
        isTrue,
      );
      expect(
        stepsNeedHttp(const [ActionStep.navigate(to: 's1')]),
        isFalse,
      );
    });
  });

  group('apiCall codegen helpers', () {
    test('apiHeadersDart sorts keys and escapes', () {
      expect(
        apiHeadersDart(const {'B': '2', 'A': "x'y"}),
        "<String, String>{'A': 'x\\'y', 'B': '2'}",
      );
      expect(apiHeadersDart(const {}), '<String, String>{}');
    });

    test('apiAssignExpr coerces per target type', () {
      const s = AppStateVar(name: 'r', type: 'string', defaultValue: '');
      const n = AppStateVar(name: 'c', type: 'number', defaultValue: 0);
      const b = AppStateVar(name: 'f', type: 'bool', defaultValue: false);
      expect(apiAssignExpr('_apiBody0', s), '_apiBody0');
      expect(
        apiAssignExpr('_apiBody0', n),
        'num.tryParse(_apiBody0.trim()) ?? 0',
      );
      expect(
        apiAssignExpr('_apiBody0', b),
        "(_apiBody0.trim().toLowerCase() == 'true')",
      );
    });

    test('emitStepStatements emits try/catch http GET with saveTo', () {
      const vars = {
        'result': AppStateVar(name: 'result', type: 'string', defaultValue: ''),
      };
      const fields = {'result': '_result'};
      final lines = emitStepStatements(
        steps: const [
          ActionStep.apiCall(
            url: 'https://a.b/items',
            saveTo: 'result',
          ),
        ],
        vars: vars,
        fields: fields,
        routeOf: (_) => null,
      );
      final text = lines.join('\n');
      expect(text, contains('try {'));
      expect(text, contains("Uri.parse('https://a.b/items')"));
      expect(text, contains('await http.get(_apiUri0)'));
      expect(text, contains('.timeout(const Duration(seconds: 10))'));
      expect(text, contains('_result = _apiBody0;'));
      expect(text, contains('catch (_) {'));
    });

    test('emitStepStatements emits POST with headers/body, skips bad URL', () {
      const vars = {
        'result': AppStateVar(name: 'result', type: 'string', defaultValue: ''),
      };
      const fields = {'result': '_result'};
      final lines = emitStepStatements(
        steps: const [
          ActionStep.apiCall(
            url: 'https://a.b/items',
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: '{"a":1}',
            saveTo: '',
          ),
          ActionStep.apiCall(url: 'nope'),
        ],
        vars: vars,
        fields: fields,
        routeOf: (_) => null,
      );
      final text = lines.join('\n');
      expect(text, contains('await http.post('));
      expect(text, contains('Content-Type'));
      expect(text, contains('response discarded (no saveTo)'));
      expect(text, contains('// apiCall skipped: invalid URL "nope".'));
    });
  });
}
