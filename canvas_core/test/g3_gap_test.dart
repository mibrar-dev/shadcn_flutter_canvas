/// Track G3: the 10-kind gap, closed structurally (§8.2).
///
/// * `fixtures`: the ten hand-written `g3_*.json` → `.expected.dart` pairs
///   (written BEFORE the emitters existed, §6.5), byte-exact through the
///   page walker, plus whole-file reformat idempotence (gate-3 direction).
/// * `registry`: every G3 kind declares render + emit together
///   ([KindBinding]) with a real emitter — `driftKinds` is empty (gate 7
///   direction). This is the structural fix: drift is type-enforced, not
///   test-detected.
/// * `bundle`: the same single implementation behind the shipping bundle
///   path — real constructor bodies, barrel imports, zero placeholders.
/// * `edges`: hand-transcribed leniency branches (defaults, clamps,
///   escaping, label/disabled variants) — authored from the registry
///   builders, not pasted from emitter output.
library;

import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

/// The ten G3 kinds in gap order, with their real widget constructors.
const _g3Kinds = <String, String>{
  'chip': 'Chip(',
  'alert': 'Alert(',
  'circular_progress_indicator': 'CircularProgressIndicator(',
  'linear_progress_indicator': 'LinearProgressIndicator(',
  'triple_dots': 'MoreDots(',
  'dot_indicator': 'DotIndicator(',
  'empty_state': 'EmptyState(',
  'code_snippet': 'CodeSnippet(',
  'number_ticker': 'NumberTicker(',
  'text_area': 'TextArea(',
};

ScreenDoc _doc(String kind, Map<String, dynamic> itemProps) {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {'id': 'i1', 'kind': kind, ...itemProps},
        ],
      },
    ],
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'G3', 'brief': ''},
  });
}

ScreenDoc _fixtureDoc(String name) => ScreenDoc.fromJson(
      jsonDecode(
        File('test/fixtures/$name.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

/// Expected file content: the `.expected.dart` fixture minus its
/// non-compiled doc header (everything through the `library;` line — the
/// same mechanism as the G2 goldens, which the analyzer needs but emission
/// never produces).
String _fixtureExpected(String name) {
  final lines =
      File('test/fixtures/$name.expected.dart').readAsStringSync().split('\n');
  final lib = lines.indexWhere((l) => l == 'library;');
  expect(lib, greaterThanOrEqualTo(0));
  return lines.sublist(lib + 1).join('\n').trimLeft();
}

/// The emitted bundle screen body with the 6-space screen indent stripped
/// (the F3 harness: also pins the canonical-indentation invariant).
String _bundleBodyOf(ScreenDoc doc) {
  final bundle = buildCleanBundle(doc, const {});
  final path = bundle.files.keys.singleWhere(
    (k) => k.startsWith('lib/ui/screens/'),
  );
  final lines = bundle.files[path]!.split('\n');
  final start = lines.indexWhere((l) => l == '      children: [');
  expect(start, greaterThanOrEqualTo(0));
  const footer = ['      ],', '    );', '  }', '}', ''];
  expect(lines.sublist(lines.length - footer.length), footer);
  final body = lines.sublist(start + 1, lines.length - footer.length);
  for (final line in body) {
    expect(line.startsWith('      '), isTrue, reason: 'indent: $line');
  }
  return body.map((l) => l.substring(6)).join('\n');
}

String _bundleScreenOf(ScreenDoc doc) {
  final bundle = buildCleanBundle(doc, const {});
  final path = bundle.files.keys.singleWhere(
    (k) => k.startsWith('lib/ui/screens/'),
  );
  return bundle.files[path]!;
}

void main() {
  group('g3 fixtures (golden-first, byte-exact)', () {
    for (final name in [
      'g3_chip',
      'g3_alert',
      'g3_circular_progress_indicator',
      'g3_linear_progress_indicator',
      'g3_triple_dots',
      'g3_dot_indicator',
      'g3_empty_state',
      'g3_code_snippet',
      'g3_number_ticker',
    ]) {
      test('$name page matches the hand-written golden', () {
        final doc = _fixtureDoc(name);
        final screen = doc.screens.single;
        final files = emitPrimitivePageFiles(
          doc: doc,
          screen: screen,
          extraEmitters: g3Emitters,
        );
        expect(files.length, 1);
        expect(files.single.content, _fixtureExpected(name));
        // Gate-3 direction: canonical output reformats to itself.
        expect(
          DartFormatter().format(files.single.content),
          files.single.content,
        );
        // The kit umbrella rides the collector (the §8.1 package-dep
        // contract), behind the shell-owned material import.
        expect(
          files.single.content,
          contains(
            "import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart';",
          ),
        );
      });
    }

    test('g3_text_area page + model match the hand-written goldens', () {
      final doc = _fixtureDoc('g3_text_area');
      final screen = doc.screens.single;
      final files = emitPrimitivePageFiles(
        doc: doc,
        screen: screen,
        extraEmitters: g3Emitters,
      );
      expect(files.length, 2);
      final byPath = {for (final f in files) f.path: f.content};
      expect(byPath['lib/pages/home/home_page.dart'],
          _fixtureExpected('g3_text_area'));
      expect(byPath['lib/pages/home/home_model.dart'],
          _fixtureExpected('g3_text_area_model'));
      for (final f in files) {
        expect(DartFormatter().format(f.content), f.content, reason: f.path);
      }
    });
  });

  group('g3 registry (§8.2 one registry, both paths)', () {
    test('all ten gap kinds registered with bindings', () {
      final registry = g3Registry();
      expect(registry.emitterCount, 10);
      for (final kind in _g3Kinds.keys) {
        expect(registry.hasRealEmitter(kind), isTrue, reason: kind);
        expect(registry.boundKinds, contains(kind), reason: kind);
      }
    });

    test('driftKinds is empty (gate 7 structural)', () {
      expect(g3Registry().driftKinds, isEmpty);
    });

    test('bindings declare the render path + model need', () {
      final registry = g3Registry();
      const renderBuilders = {
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
      for (final kind in _g3Kinds.keys) {
        final binding = registry.bindingFor(kind);
        expect(binding, isNotNull, reason: kind);
        // Render path: the verified canvas registry builder this emitter
        // mirrors. Emit path: the registered adapter. A kind that cannot
        // do both does not enter (§8.2).
        expect(
          binding!.renderDescription,
          contains(renderBuilders[kind]!),
          reason: kind,
        );
        expect(binding.isContainer, isFalse, reason: kind);
        // Only the controller kind needs a {Page}Model (mirrors
        // kStatefulKinds, which already carries text_area).
        expect(binding.needsModel, kind == 'text_area', reason: kind);
        expect(registry.lookup(kind)?.type, kind);
      }
    });

    test('G2 callers without extras see byte-identical output', () {
      final doc = _doc('container', {});
      final screen = doc.screens.single;
      final files = emitPrimitivePageFiles(doc: doc, screen: screen);
      expect(files.length, 1);
      expect(files.single.content, contains('Container()'));
      expect(files.single.content, isNot(contains('flutter_shadcn_kit')));
    });
  });

  group('g3 bundle path (same implementation, shipping exporter)', () {
    for (final entry in _g3Kinds.entries) {
      test('${entry.key} emits a real ${entry.value} body', () {
        final doc = _doc(entry.key, const {});
        final body = _bundleBodyOf(doc);
        expect(body, contains(entry.value), reason: body);
        expect(body, isNot(contains('(not yet bridged)')), reason: body);
      });

      test('${entry.key} screen imports its kit barrel', () {
        final screen = _bundleScreenOf(_doc(entry.key, const {}));
        expect(
          screen,
          contains("import '../shadcn/components/"),
          reason: screen,
        );
        expect(screen, contains('// ignore_for_file: unused_import'));
      });
    }

    test('zero placeholder emissions across all ten kinds (gate 7)', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          for (var i = 0; i < _g3Kinds.keys.length; i++)
            {
              'id': 'n$i',
              'screenId': 's1',
              'x': 0.0,
              'y': i * 48.0,
              'items': [
                {'id': 'i$i', 'kind': _g3Kinds.keys.elementAt(i)},
              ],
            },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'G3', 'brief': ''},
      });
      final screen = _bundleScreenOf(doc);
      expect(screen, isNot(contains('(not yet bridged)')));
      for (final ctor in _g3Kinds.values) {
        expect(screen, contains(ctor), reason: ctor);
      }
    });
  });

  group('g3 edges (hand-transcribed leniency branches)', () {
    test('chip defaults + escaping', () {
      expect(
        _bundleBodyOf(_doc('chip', const {})),
        "// chip 'chip'.\n"
        "Chip(child: Text('Chip')),",
      );
      expect(
        _bundleBodyOf(_doc('chip', {'label': "O'Brien \$5"})),
        "// chip 'O'Brien \$5'.\n"
        "Chip(child: Text('O\\'Brien \\\$5')),",
      );
    });

    test('alert defaults', () {
      expect(
        _bundleBodyOf(_doc('alert', const {})),
        "// alert 'alert'.\n"
        'Alert(\n'
        "  title: Text('Alert'),\n"
        "  content: Text('Something happened.'),\n"
        '  destructive: false,\n'
        '),',
      );
    });

    test('progress values clamp into 0..1', () {
      expect(
        _bundleBodyOf(
          _doc('circular_progress_indicator', {'value': 9.9}),
        ),
        "// circular_progress_indicator "
        "'circular_progress_indicator' (value 9.9).\n"
        'CircularProgressIndicator(value: 1),',
      );
      expect(
        _bundleBodyOf(_doc('linear_progress_indicator', {'value': 1})),
        "// linear_progress_indicator "
        "'linear_progress_indicator' (value 1).\n"
        'LinearProgressIndicator(value: 1),',
      );
    });

    test('triple_dots count clamps + falls back', () {
      expect(
        _bundleBodyOf(_doc('triple_dots', {'count': 0})),
        "// triple_dots 'triple_dots' (count 0).\n"
        'MoreDots(count: 1),',
      );
      expect(
        _bundleBodyOf(_doc('triple_dots', {'count': 'many'})),
        "// triple_dots 'triple_dots' (count many).\n"
        'MoreDots(count: 3),',
      );
    });

    test('dot_indicator index clamps into the length range', () {
      expect(
        _bundleBodyOf(_doc('dot_indicator', {'index': 9, 'length': 3})),
        "// dot_indicator 'dot_indicator' (index 9, length 3).\n"
        'DotIndicator(\n'
        '  index: 2,\n'
        '  length: 3,\n'
        '),',
      );
    });

    test('empty_state + code_snippet defaults', () {
      expect(
        _bundleBodyOf(_doc('empty_state', const {})),
        "// empty_state 'empty_state'.\n"
        'EmptyState(\n'
        "  title: Text('No results'),\n"
        "  description: Text('Try adjusting your search.'),\n"
        '),',
      );
      expect(
        _bundleBodyOf(_doc('code_snippet', const {})),
        "// code_snippet 'code_snippet'.\n"
        "CodeSnippet(code: Text('const x = 1;')),",
      );
    });

    test('number_ticker defaults to a whole double', () {
      expect(
        _bundleBodyOf(_doc('number_ticker', const {})),
        "// number_ticker 'number_ticker'.\n"
        'NumberTicker(\n'
        '  number: 42,\n'
        '  formatter: (v) => v.toStringAsFixed(0),\n'
        '),',
      );
    });

    test('text_area bare + disabled branches', () {
      expect(
        _bundleBodyOf(_doc('text_area', {'placeholder': 'Bio'})),
        "// text_area 'Bio'.\n"
        'TextArea(\n'
        "  placeholder: Text('Bio'),\n"
        '  enabled: true,\n'
        '),',
      );
      expect(
        _bundleBodyOf(
          _doc('text_area', {'placeholder': 'Bio', 'disabled': true}),
        ),
        contains('enabled: false,'),
      );
    });
  });
}
