/// Track F3: codegen goldens for the ten layout primitives — golden-first.
///
/// The hand-written goldens are `test/fixtures/primitives_screen.json` +
/// `primitives_screen.expected.dart` (F1, written before any emitter
/// existed). This suite makes the emitters match: exact per-kind 0/1/2
/// children blocks through the bundle exporter, exact rule fragments for
/// the §7.5 fixture through both exporters, and the zero-placeholder gate.
///
/// Expected blocks below are hand-transcribed from the §6.1–§6.2 contract
/// (collapse rules, BoxDecoration merge, token accessors, const insertion),
/// not pasted from emitter output: every line was adjudicated against the
/// F1 golden before the emitters ran.
library;

import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

ScreenDoc _primDoc(
  String kind,
  Map<String, dynamic> itemProps, [
  List<String> kidTexts = const [],
]) {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'P', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': [
      {
        'id': 'n0',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {'id': 'i0', 'kind': kind, ...itemProps},
        ],
      },
      for (var i = 0; i < kidTexts.length; i++)
        {
          'id': 'k$i',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'parentId': 'n0',
          'items': [
            {'id': 'ik$i', 'kind': 'text', 'text': kidTexts[i]},
          ],
        },
    ],
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'P', 'brief': ''},
  });
}

/// The emitted screen body with the 6-space screen indent stripped, so
/// expectations read at depth 0. Also pins the canonical-indentation
/// invariant (gate 3): every body line carries the screen indent.
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

ScreenDoc _fixtureDoc() => ScreenDoc.fromJson(
      jsonDecode(
        File('test/fixtures/primitives_screen.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

/// Leading-whitespace-insensitive form: per-kind exact tests above pin
/// absolute indentation at depth 0; fixture fragments below assert rule
/// content at nesting depth, so both sides normalize indent first.
String _norm(String s) =>
    s.split('\n').map((l) => l.trimLeft()).join('\n');

void main() {
  group('f3 container goldens (0/1/2 children)', () {
    test('childless, propless container is bare', () {
      expect(
        _bundleBodyOf(_primDoc('container', {})),
        "// container 'container'.\n"
        'Container(),',
      );
    });

    test('one child splices into child:', () {
      expect(
        _bundleBodyOf(_primDoc('container', {}, ['A'])),
        "// container 'container'.\n"
        'Container(\n'
        "  // text 'text' (text A).\n"
        "  child: WrappedText(child: Text('A')),\n"
        '),',
      );
    });

    test('two children wrap in a min Column', () {
      expect(
        _bundleBodyOf(_primDoc('container', {}, ['A', 'B'])),
        "// container 'container'.\n"
        'Container(\n'
        '  child: Column(\n'
        '    mainAxisSize: MainAxisSize.min,\n'
        '    crossAxisAlignment: CrossAxisAlignment.start,\n'
        '    children: [\n'
        "      // text 'text' (text A).\n"
        "      WrappedText(child: Text('A')),\n"
        '      const SizedBox(height: 12),\n'
        "      // text 'text' (text B).\n"
        "      WrappedText(child: Text('B')),\n"
        '    ],\n'
        '  ),\n'
        '),',
      );
    });

    test('color-only container keeps the direct color arg', () {
      expect(
        _bundleBodyOf(_primDoc('container', {
          'color': {
            '\$': 'color',
            'v': {
              'kind': 'token',
              'token': 'primary',
            },
          },
        })),
        contains('  color: Theme.of(context).colorScheme.primary,\n'),
      );
    });

    test('full style props fuse into one BoxDecoration', () {
      final body = _bundleBodyOf(_primDoc('container', {
        'width': 200,
        'margin': 8,
        'padding': {'l': 20, 't': 20, 'r': 20, 'b': 20},
        'color': {'kind': 'token', 'token': 'primaryContainer'},
        'radius': 16.0,
        'border': {
          'color': '#FF000000',
          'width': 2,
        },
        'shadow': [
          {
            'color': '#40000000',
            'blur': 8,
            'offset': {'x': 0, 'y': 2},
          },
        ],
      }));
      expect(
        body,
        contains(
          'Container(\n'
          '  width: 200,\n'
          '  margin: const EdgeInsets.all(8),\n'
          '  padding: const EdgeInsets.all(20),\n'
          '  decoration: BoxDecoration(\n'
          '    color: Theme.of(context).colorScheme.primaryContainer,\n'
          '    border: Border.all(color: Color(0xFF000000), width: 2),\n'
          '    borderRadius: BorderRadius.circular(16),\n'
          '    boxShadow: const [\n'
          '      BoxShadow(\n'
          '        color: Color(0x40000000),\n'
          '        blurRadius: 8,\n'
          '        spreadRadius: 0,\n'
          '        offset: Offset(0, 2),\n'
          '      ),\n'
          '    ],\n'
          '  ),\n'
          '),',
        ),
      );
    });
  });

  group('f3 column goldens (0/1/2 children)', () {
    test('childless column is bare', () {
      expect(
        _bundleBodyOf(_primDoc('column', {})),
        "// column 'column'.\n"
        'Column(\n'
        '  children: [],\n'
        '),',
      );
    });

    test('one child, no separators', () {
      expect(
        _bundleBodyOf(_primDoc('column', {'gap': 4}, ['A'])),
        "// column 'column' (gap 4).\n"
        'Column(\n'
        '  children: [\n'
        "    // text 'text' (text A).\n"
        "    WrappedText(child: Text('A')),\n"
        '  ],\n'
        '),',
      );
    });

    test('two children join with gap separators + axis lines', () {
      expect(
        _bundleBodyOf(_primDoc('column', {
          'mainAxis': 'end',
          'crossAxis': 'start',
        }, ['A', 'B'])),
        "// column 'column' (crossAxis start, mainAxis end).\n"
        'Column(\n'
        '  mainAxisAlignment: MainAxisAlignment.end,\n'
        '  crossAxisAlignment: CrossAxisAlignment.start,\n'
        '  children: [\n'
        "    // text 'text' (text A).\n"
        "    WrappedText(child: Text('A')),\n"
        '    const SizedBox(height: 12),\n'
        "    // text 'text' (text B).\n"
        "    WrappedText(child: Text('B')),\n"
        '  ],\n'
        '),',
      );
    });
  });

  group('f3 row-kind goldens (0/1/2 children)', () {
    test('childless row-kind is bare', () {
      expect(
        _bundleBodyOf(_primDoc('row', {})),
        "// row 'row'.\n"
        'Row(\n'
        '  children: [],\n'
        '),',
      );
    });

    test('children join with width separators', () {
      expect(
        _bundleBodyOf(_primDoc('row', {'gap': 8.0}, ['A', 'B'])),
        "// row 'row' (gap 8.0).\n"
        'Row(\n'
        '  children: [\n'
        "    // text 'text' (text A).\n"
        "    WrappedText(child: Text('A')),\n"
        '    const SizedBox(width: 8),\n'
        "    // text 'text' (text B).\n"
        "    WrappedText(child: Text('B')),\n"
        '  ],\n'
        '),',
      );
    });
  });

  group('f3 stack goldens (0/1/2 children)', () {
    test('childless stack is bare', () {
      expect(
        _bundleBodyOf(_primDoc('stack', {})),
        "// stack 'stack'.\n"
        'Stack(\n'
        '  children: [],\n'
        '),',
      );
    });

    test('children overlay with no separators + alignment/fit', () {
      expect(
        _bundleBodyOf(_primDoc('stack', {
          'alignment': 'topLeft',
          'fit': 'expand',
        }, ['A', 'B'])),
        "// stack 'stack' (alignment topLeft, fit expand).\n"
        'Stack(\n'
        '  alignment: Alignment.topLeft,\n'
        '  fit: StackFit.expand,\n'
        '  children: [\n'
        "    // text 'text' (text A).\n"
        "    WrappedText(child: Text('A')),\n"
        "    // text 'text' (text B).\n"
        "    WrappedText(child: Text('B')),\n"
        '  ],\n'
        '),',
      );
    });
  });

  group('f3 padding/center/align goldens (0/1/2 children)', () {
    test('padding defaults to all(16); num collapses to .all', () {
      expect(
        _bundleBodyOf(_primDoc('padding', {})),
        "// padding 'padding'.\n"
        'Padding(\n'
        '  padding: const EdgeInsets.all(16),\n'
        '),',
      );
      expect(
        _bundleBodyOf(_primDoc('padding', {'padding': 24}, ['A'])),
        "// padding 'padding' (padding 24).\n"
        'Padding(\n'
        '  padding: const EdgeInsets.all(24),\n'
        "  // text 'text' (text A).\n"
        "  child: WrappedText(child: Text('A')),\n"
        '),',
      );
    });

    test('padding wraps two children like container', () {
      expect(
        _bundleBodyOf(_primDoc('padding', {'padding': 8}, ['A', 'B'])),
        contains(
          '  child: Column(\n'
          '    mainAxisSize: MainAxisSize.min,\n',
        ),
      );
    });

    test('center is bare when childless', () {
      expect(
        _bundleBodyOf(_primDoc('center', {})),
        "// center 'center'.\n"
        'Center(),',
      );
      expect(
        _bundleBodyOf(_primDoc('center', {}, ['A', 'B'])),
        contains('  child: Column(\n'),
      );
    });

    test('align always emits its alignment', () {
      expect(
        _bundleBodyOf(_primDoc('align', {})),
        "// align 'align'.\n"
        'Align(\n'
        '  alignment: Alignment.center,\n'
        '),',
      );
      expect(
        _bundleBodyOf(_primDoc('align', {
          'alignment': {
            '\$': 'alignment',
            'v': {'x': 1.0, 'y': 1.0},
          },
        }, ['A'])),
        contains('  alignment: Alignment.bottomRight,\n'),
      );
    });
  });

  group('f3 expanded/sized_box/spacer goldens', () {
    test('childless expanded shrinks its child', () {
      expect(
        _bundleBodyOf(_primDoc('expanded', {})),
        "// expanded 'expanded'.\n"
        'Expanded(\n'
        '  child: SizedBox.shrink(),\n'
        '),',
      );
    });

    test('expanded carries non-default flex', () {
      expect(
        _bundleBodyOf(_primDoc('expanded', {'flex': 2}, ['A'])),
        "// expanded 'expanded' (flex 2).\n"
        'Expanded(\n'
        '  flex: 2,\n'
        "  // text 'text' (text A).\n"
        "  child: WrappedText(child: Text('A')),\n"
        '),',
      );
    });

    test('sized_box pins dims const; dimless is shrink', () {
      expect(
        _bundleBodyOf(_primDoc('sized_box', {'height': 24})),
        "// sized_box 'sized_box' (height 24).\n"
        'const SizedBox(height: 24),',
      );
      expect(
        _bundleBodyOf(_primDoc('sized_box', {})),
        "// sized_box 'sized_box'.\n"
        'const SizedBox.shrink(),',
      );
      expect(
        _bundleBodyOf(_primDoc('sized_box', {'width': 80, 'height': 24}, ['A'])),
        contains(
          'SizedBox(\n'
          '  width: 80,\n'
          '  height: 24,\n',
        ),
      );
    });

    test('spacer is const when flex is default', () {
      expect(
        _bundleBodyOf(_primDoc('spacer', {'flex': 1})),
        "// spacer 'spacer' (flex 1).\n"
        'const Spacer(),',
      );
      expect(
        _bundleBodyOf(_primDoc('spacer', {'flex': 3})),
        "// spacer 'spacer' (flex 3).\n"
        'Spacer(flex: 3),',
      );
    });
  });

  group('f3 §7.5 fixture goldens (both exporters)', () {
    test('bundle: hero container demonstrates every rule', () {
      final body = _norm(_bundleBodyOf(_fixtureDoc()));
      // §6.1 collapse rules.
      expect(body, contains('padding: const EdgeInsets.all(20),\n'));
      expect(body, contains('borderRadius: BorderRadius.circular(16),\n'));
      expect(body, contains('begin: Alignment.centerLeft,\n'));
      expect(body, contains('end: Alignment.centerRight,\n'));
      // §6.2 merge: one BoxDecoration holds color + radius + gradient.
      expect(
        body,
        contains(
          _norm(
            'decoration: BoxDecoration(\n'
            '  color: Theme.of(context).colorScheme.primaryContainer,\n'
            '  borderRadius: BorderRadius.circular(16),\n'
            '  gradient: LinearGradient(\n',
          ),
        ),
      );
      // Token accessors, never hexes (this fixture carries zero literals).
      expect(body, contains('colorScheme.primary,\n'));
      expect(body, contains('colorScheme.secondary,\n'));
      expect(body, isNot(contains('Color(0x')));
      // Structure: hero, gap, expanded cards in order.
      expect(
        body.indexOf('const EdgeInsets.all(20)'),
        lessThan(body.indexOf('const SizedBox(height: 24),')),
      );
      expect(
        body.indexOf('const SizedBox(height: 24),'),
        lessThan(body.indexOf('Expanded(')),
      );
      expect('Card('.allMatches(body).length, 3);
    });

    test('bundle: zero placeholder emissions for the fixture', () {
      final body = _bundleBodyOf(_fixtureDoc());
      expect(body, isNot(contains('unknown:')));
      expect(body, isNot(contains('not yet bridged')));
      expect(body, isNot(contains('SizedBox.shrink(),\n  child:')));
    });

    test('bundle: row children, separators, and flex roles', () {
      final body = _norm(_bundleBodyOf(_fixtureDoc()));
      expect(
        body,
        contains(
          _norm(
            'Row(\n'
            '  mainAxisAlignment: MainAxisAlignment.start,\n'
            '  crossAxisAlignment: CrossAxisAlignment.center,\n',
          ),
        ),
      );
      expect('const SizedBox(width: 8),'.allMatches(body).length, 3);
      expect(body, contains("Avatar(initials: 'AK', size: 40.0),\n"));
      expect(body, contains('SecondaryBadge(child: Text(\'Pro\')),\n'));
      expect(body, contains('const Spacer(),\n'));
      expect(body, contains('const SizedBox(height: 4),\n'));
    });

    test('single-file: same rules, material header, no placeholders', () {
      final out = buildSingleFile(_fixtureDoc(), const {});
      expect(
        out,
        contains("import 'package:flutter/material.dart';"),
      );
      expect(out, contains('padding: const EdgeInsets.all(20),\n'));
      expect(
        out,
        contains(
          '  color: Theme.of(context).colorScheme.primaryContainer,\n',
        ),
      );
      expect(out, contains('begin: Alignment.centerLeft,\n'));
      expect(out, contains('borderRadius: BorderRadius.circular(16),\n'));
      expect(out, contains('const Spacer(),\n'));
      expect(out, contains('const SizedBox(height: 24),\n'));
      expect(out, isNot(contains('unknown:')));
      expect(out, isNot(contains('not yet bridged')));
      expect(out, isNot(contains('Color(0x')));
    });
  });
}
