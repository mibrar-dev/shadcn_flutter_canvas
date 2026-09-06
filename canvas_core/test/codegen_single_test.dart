import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

import 'fixtures/two_screen_doc.dart';

/// Minimal registry-source stub: keys only need to contain the kind needle
/// (`/button/`); the body carries a `class Button` plus directives the
/// exporter must strip. The real `kEmbeddedSources` map stays in canvas_app
/// (generated Flutter-app data, not shared logic).
const kTestSources = {
  'registry/components/button/button.dart': '''
import 'package:flutter/widgets.dart';
import '../relative.dart';

class Button extends StatelessWidget {
  const Button({super.key});
}
''',
};

/// Golden structure for [buildSingleFile] on [buildTwoScreenDoc].
///
/// Asserts shape (screen classes, labels, inlined bodies, pubspec comment,
/// no relative/kit imports) rather than exact string equality: embedded
/// bodies are large and regenerate independently of this exporter.
void main() {
  test('buildSingleFile inlines used kinds for two-screen doc', () {
    final out = buildSingleFile(buildTwoScreenDoc(), kTestSources);

    // Screen widget classes.
    expect(out, contains('class CanvasScreen_Pay'));
    expect(out, contains('class CanvasScreen_Done'));

    // Both node labels, via catalog-equivalent constructor calls.
    expect(out, contains("'Pay'"));
    expect(out, contains('Payment complete'));

    // Inlined Button body with a per-body source marker.
    expect(out, contains('class Button'));
    expect(out, contains('// from:'));

    // Merged pubspec deps comment (button/card need gap per plan).
    expect(out, contains('pubspec: gap'));

    // Single-file validity: no relative import/export/part directives and no
    // kit imports survives the inlining (bodies' own directives are stripped;
    // `$schema` string *data* inside bodies may still mention `../` — that is
    // inert string content, not an import).
    final relativeDirective = RegExp(
      r'''^\s*(import|export|part)\s+['"]\.''',
      multiLine: true,
    );
    expect(relativeDirective.hasMatch(out), isFalse);
    expect(RegExp(r'^\s*part\s+of\b', multiLine: true).hasMatch(out), isFalse);
    expect(out.contains("import 'package:flutter_shadcn_kit"), isFalse);
  });

  test('buildSingleFile never crashes on unknown kinds', () {
    final out = buildSingleFile(buildTwoScreenDoc(), const {});
    expect(out, contains('TODO(canvas): no source for kind "button"'));
    expect(out, contains('class CanvasScreen_Pay'));
  });

  test('hiddenOn emits a tier conditional hiding the node', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'hiddenOn': ['mobile'],
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Hidden', 'brief': ''},
    });
    final out = buildSingleFile(doc, kTestSources);
    expect(out, contains('LayoutBuilder'));
    expect(out, contains("tier == 'mobile'"));
    expect(out, contains('SizedBox.shrink'));
    expect(out, contains("'Pay'"));
  });

  test('node hidden on all tiers emits a bare shrink', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'hiddenOn': ['mobile', 'tablet', 'desktop'],
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Never'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Hidden', 'brief': ''},
    });
    final out = buildSingleFile(doc, kTestSources);
    expect(out, contains('const SizedBox.shrink()'));
    expect(out, isNot(contains('LayoutBuilder')));
  });

  test('breakpointValues merge per tier with a static default', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'breakpointValues': {
            'desktop': {'label': 'Wide Pay'},
          },
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Overrides', 'brief': ''},
    });
    final out = buildSingleFile(doc, kTestSources);
    expect(out, contains('LayoutBuilder'));
    expect(out, contains("tier == 'desktop'"));
    expect(out, contains("'Wide Pay'"));
    expect(out, contains("'Pay'"));
  });

  test('docs without responsive fields produce byte-identical output', () {
    expect(
      buildSingleFile(buildTwoScreenDoc(), kTestSources),
      kSingleFileGolden,
    );
  });

  test('category-name kinds never inline category bodies, no duplicates', () {
    // Real-shaped destinations: the button body lives under the control
    // category. A palette `control` node must NOT re-inline it (the old
    // substring match did, duplicating every class); `form` must match only
    // the form-component body, not every form-category body.
    const sources = {
      '{installPath}/components/control/button/button.dart':
          'class PrimaryButton extends StatelessWidget {}',
      '{installPath}/components/form/form/form.dart':
          'class FormBody extends StatelessWidget {}',
      '{installPath}/components/form/input/input.dart':
          'class InputBody extends StatelessWidget {}',
    };
    final doc = ScreenDoc.fromJson({
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
            {'id': 'i1', 'kind': 'button'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'control'},
          ],
        },
        {
          'id': 'n3',
          'screenId': 's1',
          'x': 0.0,
          'y': 96.0,
          'items': [
            {'id': 'i3', 'kind': 'form'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Categories', 'brief': ''},
    });
    final out = buildSingleFile(doc, sources);

    // Each body inlined exactly once (no cross-kind duplication).
    expect(
      '// from: {installPath}/components/control/button/button.dart'
          .allMatches(out)
          .length,
      1,
    );
    expect(
      '// from: {installPath}/components/form/form/form.dart'
          .allMatches(out)
          .length,
      1,
    );
    // `form` did not pull the input-category sibling; `control` (a category,
    // not a component) inlined nothing and warns instead.
    expect(out, isNot(contains('class InputBody')));
    expect(out, contains('TODO(canvas): no source for kind "control"'));
    expect(out, contains('class PrimaryButton'));
    expect(out, contains('class FormBody'));
  });

  test('pubspec comment covers deps of all embedded kinds', () {
    final doc = ScreenDoc.fromJson({
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
            {'id': 'i1', 'kind': 'avatar'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 0.0,
          'y': 48.0,
          'items': [
            {'id': 'i2', 'kind': 'checkbox'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Deps', 'brief': ''},
    });
    final out = buildSingleFile(doc, const {});
    expect(out, contains('gap'));
    expect(out, contains('data_widget'));
    expect(out, contains('animation_kit'));
  });

  test('button text variant renders TextButton (was PrimaryButton)', () {
    final doc = _singleItemDoc('button', {'label': 'TB', 'variant': 'text'});
    final out = buildSingleFile(doc, kTestSources);
    expect(out, contains('TextButton('));
    expect(out, contains("'TB'"));
    expect(out, isNot(contains('unknown:')));
  });

  test('input honors initialValue/readOnly only when non-default', () {
    final withProps = _singleItemDoc('input', {
      'placeholder': 'P',
      'initialValue': 'hi',
      'readOnly': true,
    });
    final out = buildSingleFile(withProps, kTestSources);
    expect(out, contains('TextField('));
    expect(out, contains("initialValue: 'hi'"));
    expect(out, contains('readOnly: true'));

    // Docs without those props keep the previous (byte-identical) emission.
    final plain = _singleItemDoc('input', {'placeholder': 'P'});
    final plainOut = buildSingleFile(plain, kTestSources);
    expect(plainOut, isNot(contains('initialValue')));
    expect(plainOut, isNot(contains('readOnly')));
  });

  test('every catalog kind plus EASY kinds emit real widgets, no unknown',
      () {
    for (final entry in _kKindCases.entries) {
      final out = buildSingleFile(
        _singleItemDoc(entry.key, entry.value.props),
        kTestSources,
      );
      expect(out, isNot(contains('unknown:')), reason: entry.key);
      for (final marker in entry.value.markers) {
        expect(out, contains(marker), reason: '${entry.key} lacks $marker');
      }
    }
  });

  test('responsive and tap interplay on new kinds', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Other', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'hiddenOn': ['mobile'],
          'items': [
            {'id': 'i1', 'kind': 'avatar', 'initials': 'CD'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 0.0,
          'y': 48.0,
          'breakpointValues': {
            'desktop': {'value': 0.9},
          },
          'items': [
            {'id': 'i2', 'kind': 'slider', 'value': 0.2},
          ],
        },
        {
          'id': 'n3',
          'screenId': 's1',
          'x': 0.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i3',
              'kind': 'checkbox',
              'value': true,
              'action': {'to': 's2', 'transition': 'slide'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Interplay', 'brief': ''},
    });
    final out = buildSingleFile(doc, kTestSources);
    // hiddenOn branch keeps the avatar expression.
    expect(out, contains('LayoutBuilder'));
    expect(out, contains("tier == 'mobile'"));
    expect(out, contains('Avatar('));
    expect(out, contains("'CD'"));
    // breakpointValues branch merges slider props statically.
    expect(out, contains("tier == 'desktop'"));
    expect(out, contains('Slider(value: 0.9'));
    expect(out, contains('Slider(value: 0.2'));
    // tap actions still comment above the new-kind expression.
    expect(out, contains('// taps -> s2'));
    expect(out, contains('Checkbox('));
  });

  test('known tap target wraps in a pushNamed GestureDetector', () {
    // buildTwoScreenDoc: the Pay button taps s2 (Done → route /done, slide).
    final out = buildSingleFile(buildTwoScreenDoc(), kTestSources);
    // The existing comment is kept verbatim.
    expect(out, contains('// taps -> s2'));
    // Bundle-equivalent navigation: GestureDetector + pushNamed, with the
    // transition as a comment since pushNamed carries none.
    expect(out, contains('GestureDetector('));
    expect(
      out,
      contains(
        "onTap: () => Navigator.of(context).pushNamed('/done'), "
        '// transition: slide',
      ),
    );
    expect(out, contains("pushNamed('/done')"));
  });

  test('unknown tap target keeps the comment with no navigation', () {
    final out = buildSingleFile(
      _singleItemDoc('button', {
        'label': 'Lost',
        'action': {'to': 'missing', 'transition': 'fade'},
      }),
      kTestSources,
    );
    expect(out, contains('// taps -> missing'));
    expect(out, contains('PrimaryButton('));
    // Never a crash, never navigation: no wrapper, no route push.
    expect(out, isNot(contains('pushNamed')));
    expect(out, isNot(contains('GestureDetector(')));
  });

  test('keyboard_shortcut adds the services import; others do not', () {
    final kb =
        buildSingleFile(_singleItemDoc('keyboard_shortcut'), kTestSources);
    expect(
      kb,
      contains("import 'package:flutter/services.dart';"),
    );
    expect(kb, contains('KeyboardDisplay('));
    expect(kb, contains('LogicalKeyboardKey.controlLeft'));

    final btn = buildSingleFile(_singleItemDoc('button'), kTestSources);
    expect(btn, isNot(contains('services.dart')));
  });

  test('stepper emits the shared stateful helper once', () {
    final out = buildSingleFile(_singleItemDoc('stepper'), kTestSources);
    expect(out, contains('CanvasStepperCell('));
    expect(out, contains('class CanvasStepperCell extends StatefulWidget'));
    expect(out, contains('StepperController(currentStep:'));
  });

  test('full-seed smoke: all 78 kinds, zero unknown markers', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        for (var k = 0; k < _kAllSmokeKinds.length; k++)
          {
            'id': 'n$k',
            'screenId': 's1',
            'x': 0.0,
            'y': k * 48.0,
            'items': [
              {'id': 'i$k', 'kind': _kAllSmokeKinds[k]},
            ],
          },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Smoke', 'brief': ''},
    });
    final out = buildSingleFile(doc, const {});
    expect(out, isNot(contains('unknown:')));
    // Helpers/conditional imports trigger on the kinds that need them.
    expect(out, contains('class CanvasStepperCell extends StatefulWidget'));
    expect(out, contains('ValidatorBuilder<String>'));
    expect(out, contains("import 'package:flutter/services.dart';"));
    // Merged pubspec deps cover the new-kind third-party deps.
    expect(out, contains('skeletonizer'));
    expect(out, contains('intl'));
    expect(out, contains('animation_kit'));
    expect(out, contains('email_validator'));
  });

  test('truly unknown kinds still fall back to a placeholder', () {
    final out = buildSingleFile(_singleItemDoc('frobnicate'), const {});
    expect(out, contains("Text('unknown: frobnicate')"));
  });

  group('closure emission (Track G1)', () {
    test('imports re-emitted once each; widgets never duplicated', () {
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        _closureSources,
        sharedSources: _closureShared,
        extraImports: const [
          'dart:async',
          'package:flutter/widgets.dart',
          'package:data_widget/data_widget.dart',
        ],
        partOf: _closureParts,
      );
      for (final uri in [
        'dart:async',
        'package:flutter/widgets.dart',
        'package:data_widget/data_widget.dart',
      ]) {
        expect(
          "import '$uri';".allMatches(out).length,
          1,
          reason: uri,
        );
      }
    });

    test('shared bodies present once; vendored copies deduped', () {
      final out = _closureOut(_singleItemDoc('aaa'));
      expect(out, contains('class Theme'));
      expect(out, contains('class Data'));
      // `twice` is declared identically in shared help.dart and in the
      // component vendored copy: the copy is carved, one definition stays.
      expect('int twice(int x) => x * 2;'.allMatches(out).length, 1);
      expect(out, contains('// from: r/shared/theme.dart'));
    });

    test('export-only barrels are skipped', () {
      final out = _closureOut(_singleItemDoc('aaa'));
      expect(out, isNot(contains('aaa_barrel.dart')));
    });

    test('parts assembled after their library; part-of stripped', () {
      final out = _closureOut(_singleItemDoc('aaa'));
      expect(out, contains('class PartA'));
      expect(out, isNot(contains('part of')));
      expect(
        out.indexOf('// from: r/components/cat/aaa/aaa.dart'),
        lessThan(
            out.indexOf('// from: r/components/cat/aaa/_impl/part_a.dart')),
      );
    });

    test('relative closure pulls unreferenced-kind deps', () {
      // No node names kind `alp`, yet aaa.dart imports it: the fixpoint
      // pulls it (the `alpha`/`async` family in the real closure).
      final out = _closureOut(_singleItemDoc('aaa'));
      expect(out, contains('class Alpha'));
    });

    test('orphan part pulls its library from the shared map', () {
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import '_impl/part_a.dart';

class Aaa {}
''',
        'r/components/cat/aaa/_impl/part_a.dart': '''
part of '../aaa.dart';

class PartA {}
''',
      };
      const shared = {
        // Library lives only in the shared map (mis-split caller style).
        'r/shared/aaa.dart': '''
part 'part_a.dart';

class AaaLib {}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {
          'r/components/cat/aaa/_impl/part_a.dart': 'r/shared/aaa.dart',
        },
      );
      expect(out, contains('class AaaLib'));
      expect(out, contains('class PartA'));
    });

    test('directive-lookalike code lines survive stripping', () {
      // `part ==` is code, not a directive (regression: the old prefix-only
      // stripper ate it and everything after it up to the next `;`).
      const sources = {
        'r/components/aaa/aaa.dart': '''
class Box {
  bool operator ==(Object other) {
    return other is Box &&
        part == other.part;
  }

  int get part => 1;
}
''',
      };
      final legacy = buildSingleFile(_singleItemDoc('aaa'), sources);
      expect(legacy, contains('part == other.part'));
      final closed = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect(closed, contains('part == other.part'));
    });

    test('sdk import aliases re-emitted; prefixed uses intact', () {
      const sources = {
        'r/components/aaa/aaa.dart': '''
import 'dart:math' as math;

double halfPi() => math.pi / 2;
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: const {},
        extraImports: const ['dart:math'],
        partOf: const {},
      );
      expect(out, contains("import 'dart:math';"));
      expect(out, contains("import 'dart:math' as math;"));
      expect(out, contains('math.pi'));
    });

    test('multi-prefix sdk imports canonicalize to one alias (K1 dedupe)', () {
      // The kit aliases material.dart three ways (`m`/`mat`/`material`):
      // the header keeps one bare + one aliased form (plus the distinct
      // shadow alias, covered elsewhere) and loser uses rebind to it.
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/material.dart' as m;

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => m.Text('a');
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/material.dart' as mat;

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => mat.Text('b');
}
''',
      };
      final out = buildSingleFile(
        _twoKindDoc(),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      // One bare + one aliased material line (keeper is the
      // lexicographically smallest prefix, `m`); the loser alias line is
      // gone and its use rebound to the keeper.
      final matLines = [
        for (final line in out.split('\n'))
          if (line.startsWith('import ') &&
              line.contains('flutter/material.dart'))
            line,
      ];
      expect(matLines, [
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart' as m;",
      ]);
      expect(out, isNot(contains('mat.')));
      expect(out, contains("m.Text('b')"));
      // No import line repeats, and nothing is silenced anymore.
      final lines = [
        for (final line in out.split('\n'))
          if (line.startsWith('import ')) line,
      ];
      expect(lines.toSet().length, lines.length);
      expect(out, isNot(contains('duplicate_import')));
    });

    test('shadowed prefix blocks canonicalization (keeps loser import)', () {
      // bbb's `mat` is a local (bare occurrences), so its `mat.*` uses may
      // not mean the import: the body is left untouched and the loser import
      // stays. aaa (two keeper uses, all qualifier-shaped) is unaffected.
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/material.dart' as m;

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) =>
      Column(children: [m.Text('a'), m.Text('b')]);
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/material.dart' as mat;

class Box {
  final String label;
  const Box(this.label);
}

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) {
    final mat = const Box('b');
    return m_scope_placeholder(mat.label);
  }
}

Widget m_scope_placeholder(String s) => Text(s);
''',
      };
      final out = buildSingleFile(
        _twoKindDoc(),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect(
        out,
        contains("import 'package:flutter/material.dart' as mat;"),
      );
      expect(out, contains("import 'package:flutter/material.dart' as m;"));
      expect(out, contains('final mat = const Box('));
      expect(out, contains('mat.label'));
    });

    test('relative import prefixes stripped when the target is claimed', () {
      final out = _closureOut(_singleItemDoc('aaa'));
      expect(out, isNot(contains('t.Theme')));
      expect(out, contains('Theme.of(context)'));
    });

    test('sdk-shadowed names qualified with a private alias', () {
      const sources = {
        'r/components/aaa/aaa.dart': '''
import 'package:flutter/material.dart';

Color brand() => Colors.red;
''',
      };
      const shared = {
        'r/shared/colors.dart': '''
class Colors {
  static const red = 1;
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: shared,
        extraImports: const ['package:flutter/material.dart'],
        partOf: const {},
      );
      expect(
        out,
        contains("import 'package:flutter/material.dart' as _shadowMaterial;"),
      );
      expect(out, contains('_shadowMaterial.Colors.red'));
    });

    test('hide-gated sdk names are left alone', () {
      const sources = {
        'r/components/aaa/aaa.dart': '''
import 'package:flutter/material.dart' hide Colors;

Color brand() => Colors.red;
''',
      };
      const shared = {
        'r/shared/colors.dart': '''
class Colors {
  static const red = 1;
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: shared,
        extraImports: const ['package:flutter/material.dart'],
        partOf: const {},
      );
      // `Colors` is hidden from the sdk import, so it means the kit class:
      // no shadow alias, no rewrite.
      expect(out, isNot(contains('_shadowMaterial')));
      expect(out, contains('Colors.red'));
    });

    test('rival extension members renamed with scope gating', () {
      // `tiny` is declared by ExtA and ExtB (both `on Widget`): the
      // more-used side keeps the name (tie → alphabetical, ExtA), ExtB's
      // declaration and its single-exposure uses are suffixed. `huge`
      // (ExtB only) is untouched.
      final doc = ScreenDoc.fromJson({
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
              {'id': 'i1', 'kind': 'aaa'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'bbb'},
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Kind', 'brief': ''},
      });
      final out = buildSingleFile(
        doc,
        _extSources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      // Keeper side untouched: the declaration and aaa's use.
      expect(out, contains('extension ExtA on Widget'));
      expect('.tiny();'.allMatches(out).length, 1);
      // Renamed side: ExtB's declaration plus bbb's single-exposure use.
      expect('.tiny__x1();'.allMatches(out).length, 1);
      expect(out, contains('tiny__x1() => this;'));
      // Non-rival member untouched everywhere.
      expect(out, contains('.huge();'));
      expect(out, isNot(contains('huge__')));
    });

    test('both-visible rival uses are left alone', () {
      // ccc.dart imports both rival extensions: no sound rewrite exists
      // (the kit could not compile it either), so the use stays an honest
      // residual instead of binding the wrong twin. (ExtB's declaration is
      // still renamed — only ccc's own section is asserted here.)
      final out = buildSingleFile(
        _singleItemDoc('ccc'),
        _extSources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect(out, contains('class Ccc'));
      final start = out.indexOf('// from: r/components/cat/ccc/ccc.dart');
      expect(start, isNot(-1));
      final next = out.indexOf('// from:', start + 10);
      final section = out.substring(start, next < 0 ? out.length : next);
      expect(section, contains('.tiny();'));
      expect(section, isNot(contains('__x1')));
    });

    test('duplicate FormKey unifies to a single declaration (H1)', () {
      // Shared minimal vs form superset (adds getValue): the subset decl is
      // dropped, leaving one `FormKey` with NO `__dup2` — interface crossings
      // (FormFieldHandle/ValidationResult vs form impls) cannot be satisfied
      // with two types.
      const sources = {
        'r/components/cat/form/form.dart': '''
import 'package:flutter/widgets.dart';

class FormBody extends StatelessWidget {
  const FormBody({super.key});
  Widget build(BuildContext context) =>
      const Text('f', key: FormKey<String>('a'));
}
''',
        'r/components/cat/form/_impl/form_key.dart': '''
import 'package:flutter/widgets.dart';

class FormKey<T> extends LocalKey {
  final Object key;
  const FormKey(this.key);
  T? getValue(Object values) => null;
}
''',
      };
      const shared = {
        'r/shared/form_key.dart': '''
import 'package:flutter/widgets.dart';

class FormKey<T> extends LocalKey {
  final Object key;
  const FormKey(this.key);
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('form'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect(out, contains('class FormKey<T>'));
      expect(out, contains('getValue'));
      expect(out, isNot(contains('FormKey__dup')));
      expect(out, contains("FormKey<String>('a')"));
    });

    test('then formal and Future.then are never suffixed (H1)', () {
      // Twin TextExtensions (same name/on-type, diverged `then` fallback so
      // both survive carving) plus a field formal and an SDK use: none may
      // gain `__text`. No qualifying Widget-ctor `.then` exists, so no keeper
      // exists either — suffixing would erase the plain name residuals need.
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class _TextThenWidget extends StatelessWidget {
  final Text text;
  final List<InlineSpan> then;
  const _TextThenWidget({required this.text, required this.then});
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> runIt(Future<int> future) => future.then((v) {});
''',
        'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension TextExtension on Widget {
  Widget then(InlineSpan span) {
    throw Exception('only text');
  }
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => const SizedBox();
}
''',
        'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension TextExtension on Widget {
  Widget then(InlineSpan span) {
    return RichText(text: TextSpan(children: [span]));
  }
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect(out, isNot(contains('then__text')));
      expect(out, contains('required this.then'));
      expect(out, contains('future.then('));
      expect(out, contains('Widget then(InlineSpan span)'));
    });

    test('Typography getters are never suffixed (H1)', () {
      // Twin TextExtensions disagree on an extra member each (neither subset,
      // so both survive) while sharing `sans`; a Typography class declares
      // its own `sans` field used via `theme.typography.sans`. The Typography
      // use must stay plain — it binds to the class, never the extensions.
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class Typography {
  final TextStyle sans;
  const Typography(this.sans);
}

void useIt(dynamic theme) {
  theme.typography.sans;
}
''',
        'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension TextExtension on Widget {
  Widget get sans => this;
  Widget get fooOnlyA => this;
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => const SizedBox();
}
''',
        'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension TextExtension on Widget {
  Widget get sans => this;
  Widget get barOnlyB => this;
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect(out, isNot(contains('sans__text')));
      expect(out, contains('theme.typography.sans'));
      expect(out, contains('final TextStyle sans;'));
    });

  group('single-file final mile (Track I1)', () {
    test('diverged top-level functions rename with scope-aware rebind', () {
      // `getBullet` is vendored twice with different bodies: the first home
      // keeps the name, the other becomes `getBullet__dup2`, and each file's
      // own use rebinds to its home (no silent cross-binding).
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => getBullet(context, 0, 6);
}

Widget getBullet(BuildContext context, int depth, double size) {
  return CustomPaint(size: Size(size, size));
}
''',
      };
      const shared = {
        'r/shared/help.dart': '''
import 'package:flutter/widgets.dart';

Widget getBullet(BuildContext context, int depth, double size) {
  return Center(child: Container(width: size, height: size));
}

class SharedUser extends StatelessWidget {
  const SharedUser({super.key});
  Widget build(BuildContext context) => getBullet(context, 1, 4);
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect(out, contains('Widget getBullet(BuildContext context'));
      expect(out, contains('Widget getBullet__dup2(BuildContext context'));
      expect('getBullet__dup2(context, 0, 6)'.allMatches(out).length, 1);
      expect('getBullet(context, 1, 4)'.allMatches(out).length, 1);
      expect(out, isNot(contains('getBullet__dup2(context, 1, 4)')));
    });

    test('shadowing files keep the honest residual instead of corrupting', () {
      // A loser-scope file declaring a same-named local is left alone (its
      // bare use still binds the keeper — no error — rather than renaming a
      // use that means the local).
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) {
    final getBullet = (int x) => x;
    return Text('\${getBullet(1)}');
  }
}

Widget getBullet(BuildContext context, int depth, double size) {
  return CustomPaint(size: Size(size, size));
}
''',
      };
      const shared = {
        'r/shared/help.dart': '''
import 'package:flutter/widgets.dart';

Widget getBullet(BuildContext context, int depth, double size) {
  return Center(child: Container(width: size, height: size));
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      // The shared keeper stays; the component copy is renamed (its own
      // declaration unambiguously means the top level)…
      expect(out, contains('Widget getBullet__dup2(BuildContext context'));
      // …but the shadowed local use is untouched.
      expect(out, contains('getBullet(1)'));
      expect(out, isNot(contains('getBullet__dup2(1)')));
    });

    test('typedefs differing only in positional names unify', () {
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => const SizedBox();
}

typedef FormPendingWidgetBuilder =
    Widget Function(
      BuildContext context,
      Map<String, Future<int?>> errors,
      Widget? child,
    );
''',
      };
      const shared = {
        'r/shared/help.dart': '''
import 'package:flutter/widgets.dart';

typedef FormPendingWidgetBuilder =
    Widget Function(
      BuildContext context,
      Map<String, Future<int?>> pending,
      Widget? child,
    );
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect('typedef FormPendingWidgetBuilder ='.allMatches(out).length, 1);
      expect(out, isNot(contains('__dup')));
    });

    test('diverged typedefs rename with scope-aware rebind', () {
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';

class Bbb extends StatelessWidget {
  final MyBuilder builder;
  const Bbb({required this.builder});
  Widget build(BuildContext context) => const SizedBox();
}

typedef MyBuilder = int Function(BuildContext context);
''',
      };
      const shared = {
        'r/shared/help.dart': '''
import 'package:flutter/widgets.dart';

typedef MyBuilder = Widget Function(BuildContext context);
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect(out, contains('typedef MyBuilder = Widget Function'));
      expect(out, contains('typedef MyBuilder__dup2 = int Function'));
      expect(out, contains('final MyBuilder__dup2 builder;'));
    });

    test('enums differing only in docs unify', () {
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
class Bbb {}

/// Validation timing.
enum FormValidationMode {
  /// Runs on creation.
  initial,

  /// Runs on change.
  changed,
}
''',
      };
      const shared = {
        'r/shared/help.dart': '''
enum FormValidationMode { initial, changed }
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect('enum FormValidationMode'.allMatches(out).length, 1);
      expect(out, isNot(contains('__dup')));
    });

    test('strict enum supersets unify when no switch exists', () {
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
class Bbb {
  Object? pos;
  Bbb() : pos = InputFeaturePosition.above;
}

enum InputFeaturePosition {
  leading,
  trailing,
  above,
  below,
}
''',
      };
      const shared = {
        'r/shared/help.dart': '''
enum InputFeaturePosition {
  leading,
  trailing,
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect('enum InputFeaturePosition'.allMatches(out).length, 1);
      expect(out, contains('above,'));
      expect(out, contains('InputFeaturePosition.above'));
      expect(out, isNot(contains('__dup')));
    });

    test('diverged enums with switches rename with rebind', () {
      // A `case` switch forces the rename path (a superset would break
      // exhaustiveness); each file keeps its own exhaustive view.
      const sources = {
        'r/components/cat/bbb/bbb.dart': '''
class Bbb {
  String where(InputFeaturePosition p) {
    switch (p) {
      case InputFeaturePosition.leading:
        return 'l';
      case InputFeaturePosition.trailing:
        return 't';
    }
  }
}

enum InputFeaturePosition {
  leading,
  trailing,
}
''',
      };
      const shared = {
        'r/shared/help.dart': '''
enum InputFeaturePosition {
  leading,
  trailing,
  above,
}
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('bbb'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {},
      );
      expect(out, contains('enum InputFeaturePosition {'));
      expect(out, contains('above,'));
      expect(out, contains('enum InputFeaturePosition__dup2 {'));
      expect(out, contains('case InputFeaturePosition__dup2.leading:'));
    });

    test('Widget-typed identifier receivers elect keepers', () {
      // `child` is a `Widget` param in aaa (ExtA scope) while bbb uses a
      // constructor: one vote each, tie breaks to ExtA, and bbb's use takes
      // the suffix.
      final out = buildSingleFile(
        _twoKindDoc(),
        _identSources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect('.tiny();'.allMatches(out).length, 1);
      expect('.tiny__x1();'.allMatches(out).length, 1);
      expect(out, contains('tiny__x1() => this;'));
    });

    test('field and widget receivers resolve through the class index', () {
      // Votes tie 1-1 per member (aaa constructors vs bbb `widget.`/field
      // paths), so the alphabetical keeper is ExtA throughout: bbb's
      // Widget-typed uses rewrite with one shared suffix. `h4` is ExtB-only
      // (never rival) and `StepSize.medium` (UpperCamel receiver) is never
      // suffixed.
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => Column(
        children: [
          const Text('x').large(),
          const Text('y').medium(),
        ],
      );
}
''',
        'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension ExtA on Widget {
  Widget large() => this;
  Widget medium() => this;
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

enum StepSize { small, medium, large }

class AppBar extends StatefulWidget {
  final Widget? title;
  const AppBar({super.key, this.title});
  @override
  State<AppBar> createState() => AppBarState();
}

class AppBarState extends State<AppBar> {
  @override
  Widget build(BuildContext context) => widget.title!.large();
}

class Card extends StatelessWidget {
  final Widget title;
  final Widget subtitle;
  const Card({super.key, required this.title, required this.subtitle});
  Widget build(BuildContext context) => Column(
        children: [
          title.h4(),
          subtitle.medium().withSize(StepSize.medium),
        ],
      );
}
''',
        'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension ExtB on Widget {
  Widget large() => this;
  Widget h4() => this;
  Widget medium() => this;
  Widget withSize(StepSize size) => this;
}
''',
      };
      final out = buildSingleFile(
        _twoKindDoc(),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      // Renamed parties: only (ExtB, bbb-group), so both members share __x1.
      expect(out, contains('widget.title!.large__x1()'));
      expect(out, contains('subtitle.medium__x1().withSize(StepSize.medium)'));
      expect(out, contains("Text('x').large()"));
      expect(out, contains("Text('y').medium()"));
      // Non-rivals and enum values keep plain members.
      expect(out, contains('title.h4()'));
      expect(out, isNot(contains('h4__')));
      expect(out, contains('StepSize.medium'));
      expect(out, isNot(contains('StepSize.medium__')));
      expect(out, contains('large__x1() => this;'));
      expect(out, contains('medium__x1() => this;'));
    });

    test('dynamic receivers never elect or rewrite', () {
      // The only `.normal()` use has a `dynamic` receiver: no keeper exists,
      // so both declarations stay plain (honest residual, never corruption).
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => const SizedBox();
}

void useIt(dynamic theme) {
  theme.normal();
}
''',
        'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension ExtA on Widget {
  Widget normal() => this;
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => const SizedBox();
}
''',
        'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension ExtB on Widget {
  Widget normal() => this;
}
''',
      };
      final out = buildSingleFile(
        _twoKindDoc(),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect(out, contains('theme.normal();'));
      expect(out, isNot(contains('normal__')));
    });

    test('subscript and inferred-locals receivers resolve', () {
      // `rows` is `List<FormField>`, `label` a `Widget` field, and `row` is
      // inferred from `this.rows[0]` — two bbb votes beat aaa's one, so the
      // keeper is ExtB: aaa's constructor use rewrites while bbb's stay
      // plain. (If inference failed the keeper would flip to ExtA instead.)
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => const Text('x').textSmall();
}
''',
        'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension ExtA on Widget {
  Widget textSmall() => this;
}
''',
        'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

class FormField extends StatelessWidget {
  final Widget label;
  const FormField({super.key, required this.label});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class Table extends StatelessWidget {
  final List<FormField> rows;
  const Table({super.key, required this.rows});
  @override
  Widget build(BuildContext context) {
    final row = this.rows[0];
    return Column(
      children: [
        rows[1].label.textSmall(),
        row.label.textSmall(),
      ],
    );
  }
}
''',
        'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension ExtB on Widget {
  Widget textSmall() => this;
}
''',
      };
      final out = buildSingleFile(
        _twoKindDoc(),
        sources,
        sharedSources: const {},
        extraImports: const [],
        partOf: const {},
      );
      expect('.textSmall__x1();'.allMatches(out).length, 1);
      expect(out, contains("Text('x').textSmall__x1()"));
      expect(out, contains('rows[1].label.textSmall()'));
      expect(out, contains('row.label.textSmall()'));
      expect(out, isNot(contains('textSmall__x1(),')));
      expect(out, contains('textSmall__x1() => this;'));
    });

    test('prefixed self-alias typedefs survive as keeper aliases (D2b)', () {
      // `typedef N = p.N;` in a part would strip to a self-cycle; with the
      // name dupe-renamed it must survive as `typedef N__dup2 = N;` while the
      // part's use rebinds to it.
      const sources = {
        'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '../../../shared/help.dart' as p;
part '_impl/part_a.dart';

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => const SizedBox();
}
''',
        'r/components/cat/aaa/_impl/part_a.dart': '''
part of '../aaa.dart';

typedef AliasFn = p.AliasFn;

class PartUser {
  final AliasFn fn;
  const PartUser(this.fn);
}
''',
      };
      const shared = {
        'r/shared/help.dart': '''
import 'package:flutter/widgets.dart';

typedef AliasFn = Widget Function(BuildContext context);
''',
      };
      final out = buildSingleFile(
        _singleItemDoc('aaa'),
        sources,
        sharedSources: shared,
        extraImports: const [],
        partOf: const {
          'r/components/cat/aaa/_impl/part_a.dart':
              'r/components/cat/aaa/aaa.dart',
        },
      );
      expect(out, contains('typedef AliasFn = Widget Function'));
      expect(out, contains('typedef AliasFn__dup2 = AliasFn;'));
      expect(out, contains('final AliasFn__dup2 fn;'));
    });
  });


    test('closure golden for a two-kind doc', () {      final doc = ScreenDoc.fromJson({
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
              {'id': 'i1', 'kind': 'aaa'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'bbb'},
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Kind', 'brief': ''},
      });
      expect(
        buildSingleFile(
          doc,
          _closureSources,
          sharedSources: _closureShared,
          extraImports: const ['package:data_widget/data_widget.dart'],
          partOf: _closureParts,
        ),
        kClosureGolden,
      );
    });
  });

  group('composition recursion (Track C3)', () {
    test('nested card>button splices the child into the card slot', () {
      final out = buildSingleFile(_c3Doc(_cardWithButtonNodes()), kTestSources);
      // The button renders INSIDE the card chrome: after the description,
      // before the column close — with a gap separator from the chrome.
      expect(out, contains('Card('));
      expect(out, contains("Text('Go')"));
      final cardIdx = out.indexOf('Card(');
      final descIdx = out.indexOf("'Card body'");
      final goIdx = out.indexOf("'Go'");
      expect(cardIdx, lessThan(descIdx));
      expect(descIdx, lessThan(goIdx));
      expect(out, contains('const SizedBox(height: 12),'));
    });

    test('nested card>button matches the exact golden', () {
      expect(
        buildSingleFile(_c3Doc(_cardWithButtonNodes()), kTestSources),
        kSingleNestedCardGolden,
      );
    });

    test('three-deep nesting composes slot inside slot', () {
      final out = buildSingleFile(_c3Doc(_threeDeepNodes()), kTestSources);
      expect(out, contains('Card('));
      expect(out, contains('ModalContainer('));
      expect(out, contains("Text('Deep')"));
      final cardIdx = out.indexOf('Card(');
      final dialogIdx = out.indexOf('ModalContainer(');
      final deepIdx = out.indexOf("'Deep'");
      expect(cardIdx, lessThan(dialogIdx));
      expect(dialogIdx, lessThan(deepIdx));
    });

    test('three-deep nesting matches the exact golden', () {
      expect(
        buildSingleFile(_c3Doc(_threeDeepNodes()), kTestSources),
        kSingleThreeDeepGolden,
      );
    });

    test('card-in-row emits the card inside the Row', () {
      final out = buildSingleFile(_c3Doc(_cardInRowNodes()), kTestSources);
      final rowIdx = out.indexOf('Row(');
      final cardIdx = out.indexOf('Card(');
      expect(rowIdx, isNot(-1));
      expect(cardIdx, isNot(-1));
      expect(rowIdx, lessThan(cardIdx));
      expect(out, contains("Text('Inner')"));
    });

    test('row-in-card emits a horizontal strip inside the card', () {
      final out = buildSingleFile(_c3Doc(_rowInCardNodes()), kTestSources);
      final cardIdx = out.indexOf('Card(');
      final rowIdx = out.indexOf('Row(');
      expect(cardIdx, isNot(-1));
      expect(rowIdx, isNot(-1));
      expect(cardIdx, lessThan(rowIdx));
      expect(out, contains("Text('A')"));
      expect(out, contains("Text('B')"));
      expect(out, contains('const SizedBox(width: 8),'));
    });

    test('leaf fallback stacks children below the own widget', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'button', 'label': 'Own'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
            ],
          },
        ]),
        kTestSources,
      );
      // Non-container leaves never splice chrome: own widget first, child
      // below, joined with the vertical-stack gap.
      expect(out, contains('Column('));
      final ownIdx = out.indexOf("'Own'");
      final kidIdx = out.indexOf("'Kid'");
      expect(ownIdx, lessThan(kidIdx));
      expect(out, contains('const SizedBox(height: 12),'));
    });

    test('multi-item container nodes fall back (single-item gate)', () {
      // Container-ness needs a single container-kind item (spec §1 names a
      // kind per node; nodes carry item lists). Multi-item nodes with
      // children stack below like leaves — pinned here.
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'T',
                'description': 'D',
              },
              {'id': 'i2', 'kind': 'button', 'label': 'Own'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i3', 'kind': 'button', 'label': 'Kid'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('Card('));
      expect(out, contains("'Kid'"));
    });

    test('hidden parent prunes the whole subtree', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'hiddenOn': ['mobile', 'tablet', 'desktop'],
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'Gone',
                'description': 'Gone body',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Buried'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('const SizedBox.shrink()'));
      expect(out, isNot(contains('Card(')));
      expect(out, isNot(contains("'Buried'")));
    });

    test('per-level tier conditionals nest', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'hiddenOn': ['mobile'],
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'T',
                'description': 'D',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'hiddenOn': ['tablet'],
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
            ],
          },
        ]),
        kTestSources,
      );
      // Each level keeps its own LayoutBuilder tier wrapper.
      expect('LayoutBuilder'.allMatches(out).length, 2);
      expect(out, contains("tier == 'mobile'"));
      expect(out, contains("tier == 'tablet'"));
      expect(out, contains("'Kid'"));
    });

    test('nested tap navigation wraps the child body', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'T',
                'description': 'D',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {
                'id': 'i2',
                'kind': 'button',
                'label': 'Go',
                'action': {'to': 's2', 'transition': 'slide'},
              },
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Nest', 'brief': ''},
      });
      final out = buildSingleFile(doc, kTestSources);
      expect(out, contains('Card('));
      expect(out, contains('// taps -> s2'));
      expect(out, contains("pushNamed('/done')"));
      // The navigation wraps the child INSIDE the card slot.
      expect(out.indexOf('Card('), lessThan(out.indexOf('GestureDetector(')));
    });

    test('responsive branch carries the nested subtree', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'breakpointValues': {
              'desktop': {'title': 'Wide'},
            },
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'T',
                'description': 'D',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('LayoutBuilder'));
      expect(out, contains("tier == 'desktop'"));
      // Both the override branch and the default branch carry the child.
      expect("'Kid'".allMatches(out).length, 2);
      expect(out, contains("'Wide'"));
    });

    test('duplicate-id cycle terminates with a comment', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'card',
                'title': 'T',
                'description': 'D',
              },
            ],
          },
          {
            // Corrupt twin: same id parented under itself — reachable only
            // through the duplicate edge, so the guard must comment + skip.
            'id': 'n1',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Loop'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('cycle: node n1 is its own ancestor (skipped)'));
    });

    test('pure parent cycle terminates without hanging', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'parentId': 'n2',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'button', 'label': 'A'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'B'},
            ],
          },
        ]),
        kTestSources,
      );
      // Neither node is a root (both parentIds resolve), so the screen is
      // empty — and emission terminates instead of hanging.
      expect(out, contains('// (empty screen)'));
    });

    test('row-only docs keep byte-identical rows', () {
      expect(
        buildSingleFile(_c3Doc(_rowOnlyNodes()), kTestSources),
        kSingleRowOnlyGolden,
      );
    });

    test('legacy docs stay stateless (no StatefulWidget, no tap methods)', () {
      final out = buildSingleFile(buildTwoScreenDoc(), kTestSources);
      expect(out, contains('extends StatelessWidget'));
      expect(out, contains("import 'package:flutter/widgets.dart';"));
      expect(out.contains('StatefulWidget'), isFalse);
      expect(out.contains('_onTap'), isFalse);
    });

    test('stateful screen holds fields, binding, and a 3-step action', () {
      final doc = ScreenDoc.fromJson({
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
            'items': [
              {
                'id': 'i1',
                'kind': 'button',
                'label': '=count',
                'action': {
                  'to': 's2',
                  'transition': 'slide',
                  'steps': [
                    {'kind': 'setState', 'variable': 'count', 'value': '1'},
                    {'kind': 'showSnackBar', 'message': 'Saved'},
                    {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
                  ],
                },
              },
            ],
          },
        ],
        'states': [
          {'name': 'count', 'type': 'number', 'default': 0},
          {'name': 'who', 'type': 'string', 'default': 'Ada'},
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Stateful', 'brief': ''},
      });
      final out = buildSingleFile(doc, kTestSources);

      // Stateful shape with one field per var.
      expect(out, contains('class CanvasScreen_Home extends StatefulWidget'));
      expect(out, contains('num _count = 0;'));
      expect(out, contains("String _who = 'Ada';"));

      // Binding reads the field via interpolation.
      expect(out, contains("Text('\${_count}')"));

      // The 3-step flow becomes one method: state, feedback, navigation.
      expect(out, contains('void _onTap_i1(BuildContext context) {'));
      expect(out, contains('setState(() {'));
      expect(out, contains('_count = 1;'));
      expect(out, contains('showSnackBar'));
      expect(out, contains("pushNamed('/done')"));
      expect(out, contains('onTap: () => _onTap_i1(context),'));
      expect(out, contains('// steps (3): setState count, snackBar, navigate s2'));

      // SnackBar needs material (a widgets superset), so the header swaps.
      expect(out, contains("import 'package:flutter/material.dart';"));
      expect(out.contains("import 'package:flutter/widgets.dart';"), isFalse);

      // Deterministic.
      expect(buildSingleFile(doc, kTestSources), out);
    });

    test('steps without vars make only their screen stateful', () {
      final doc = ScreenDoc.fromJson({
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
            'items': [
              {
                'id': 'i1',
                'kind': 'button',
                'label': 'Go',
                'action': {
                  'to': 's2',
                  'transition': 'slide',
                  'steps': [
                    {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
                  ],
                },
              },
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Steps only', 'brief': ''},
      });
      final out = buildSingleFile(doc, kTestSources);
      expect(out, contains('class CanvasScreen_Home extends StatefulWidget'));
      expect(out, contains('class CanvasScreen_Done extends StatelessWidget'));
      expect(out, contains("import 'package:flutter/widgets.dart';"));
    });

    test('nested export golden: card slots + 3-deep + row-in-card', () {
      final doc = _nestedExportDoc();
      final out = buildSingleFile(doc, kTestSources);

      // Slot splice: the input + button render INSIDE the card chrome after
      // the description (COMPOSITION.md §2 card slot).
      expect(out, contains('Card('));
      expect(out, contains('TextField('));
      expect(
        out.indexOf("'Shop body'"),
        lessThan(out.indexOf("'Name'")),
      );
      expect(out.indexOf("'Name'"), lessThan(out.indexOf("'Go'")));

      // 3-deep: card > dialog > button, each level spliced into its own slot.
      expect(out, contains('ModalContainer('));
      expect(
        out.indexOf("'Deep body'"),
        lessThan(out.indexOf("'Dlg body'")),
      );
      expect(out.indexOf("'Dlg body'"), lessThan(out.indexOf("'Deep Go'")));

      // Row-in-card: a horizontal strip inside the third card (search from
      // the strip card: the dialog above owns its own action Row).
      final stripIdx = out.indexOf("'Strip body'");
      final rowIdx = out.indexOf('Row(', stripIdx);
      expect(rowIdx, greaterThan(stripIdx));
      expect(out.indexOf("'A'", rowIdx), lessThan(out.indexOf("'B'", rowIdx)));
      expect(out, contains('const SizedBox(width: 8),'));

      // Per-level tiers: every responsive level keeps its own wrapper.
      expect('LayoutBuilder'.allMatches(out).length, 3);
      expect(out, contains("tier == 'mobile'"));
      expect(out, contains("tier == 'tablet'"));
      expect(out, contains("tier == 'desktop'"));
      expect(out, contains("'Wide Go'"));

      // Per-level taps: depth-1 and depth-2 buttons navigate (the desktop
      // override branch carries its own copy of the depth-2 tap).
      expect("pushNamed('/done')".allMatches(out).length, 3);
      expect(out, contains('// taps -> s2'));

      // Byte-stability: regeneration is deterministic and pinned.
      expect(buildSingleFile(doc, kTestSources), out);
      expect(out, kSingleNestedExportGolden);
    });

    test('nested chat>button splices the child into the bubble slot', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'chat', 'message': 'Hey'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Go'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('ChatBubble('));
      final msgIdx = out.indexOf("'Hey'");
      final goIdx = out.indexOf("'Go'");
      expect(msgIdx, isNot(-1));
      expect(goIdx, isNot(-1));
      expect(msgIdx, lessThan(goIdx));
      expect(out, contains('const SizedBox(height: 12),'));
    });

    test('nested toast>button splices the child after the message', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'toast',
                'title': 'TT',
                'message': 'TM',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Go'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('ToastEntry('));
      final msgIdx = out.indexOf("'TM'");
      final goIdx = out.indexOf("'Go'");
      expect(msgIdx, lessThan(goIdx));
      expect(out, contains('const SizedBox(height: 12),'));
    });

    test('nested validated>button splices the child before the error gap', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'validated',
                'placeholder': 'Name',
                'errorText': 'Req',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Go'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('Validated<String>('));
      final goIdx = out.indexOf("'Go'");
      // 'Req' appears twice: the validator construction, then the error
      // display text — the spliced child sits before the display copy.
      final errIdx = out.lastIndexOf("'Req'");
      expect(goIdx, isNot(-1));
      expect(errIdx, isNot(-1));
      // Child sits after the field (child!,) and before the error text.
      expect(out.indexOf('child!,'), lessThan(goIdx));
      expect(goIdx, lessThan(errIdx));
    });

    test('nested refresh_trigger>button appends rows after the prop rows', () {
      final out = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'refresh_trigger',
                'item1': 'R1',
                'item2': 'R2',
                'item3': 'R3',
              },
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Go'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(out, contains('RefreshTrigger('));
      final r3Idx = out.indexOf("'R3'");
      final goIdx = out.indexOf("'Go'");
      expect(r3Idx, lessThan(goIdx));
      expect(out, contains('const SizedBox(height: 12),'));
    });

    test('childless D1 containers keep the historical output', () {
      // Chat childless stays the single-line bubble.
      final chat = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'chat', 'message': 'Hi'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(chat, contains("ChatBubble(child: Text('Hi')),"));
      expect(chat, isNot(contains('const SizedBox(height: 12),')));
      // Toast childless keeps the Column chrome with no slot gap.
      final toast = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'toast',
                'title': 'TT',
                'message': 'TM',
              },
            ],
          },
        ]),
        kTestSources,
      );
      expect(toast, contains('ToastEntry('));
      expect(toast, contains("'TT'"));
      expect(toast, isNot(contains('const SizedBox(height: 12),')));
      // Validated childless keeps field + error gap with no slot gap.
      final validated = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'validated',
                'placeholder': 'Name',
                'errorText': 'Req',
              },
            ],
          },
        ]),
        kTestSources,
      );
      expect(validated, contains('Validated<String>('));
      expect(validated, contains('child!,'));
      expect(validated, isNot(contains('const SizedBox(height: 12),')));
      // Refresh-trigger childless keeps the three prop rows with no slot gap.
      final refresh = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {
                'id': 'i1',
                'kind': 'refresh_trigger',
                'item1': 'R1',
                'item2': 'R2',
                'item3': 'R3',
              },
            ],
          },
        ]),
        kTestSources,
      );
      expect(refresh, contains('RefreshTrigger('));
      expect(refresh, contains("'R3'"));
      expect(refresh, isNot(contains('const SizedBox(height: 12),')));
    });

    test('chat tap + responsive interplay nests per level', () {
      // Tap: the child navigation wraps inside the chat slot.
      final tapDoc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'chat', 'message': 'Hey'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {
                'id': 'i2',
                'kind': 'button',
                'label': 'Go',
                'action': {'to': 's2', 'transition': 'slide'},
              },
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Nest', 'brief': ''},
      });
      final tapOut = buildSingleFile(tapDoc, kTestSources);
      expect(tapOut, contains('ChatBubble('));
      expect(tapOut, contains('// taps -> s2'));
      expect(tapOut, contains("pushNamed('/done')"));
      expect(
        tapOut.indexOf('ChatBubble('),
        lessThan(tapOut.indexOf('GestureDetector(')),
      );
      // Responsive: both branches carry the spliced child.
      final respOut = buildSingleFile(
        _c3Doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'breakpointValues': {
              'desktop': {'message': 'Wide'},
            },
            'items': [
              {'id': 'i1', 'kind': 'chat', 'message': 'Hey'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'parentId': 'n1',
            'x': 0.0,
            'y': 48.0,
            'items': [
              {'id': 'i2', 'kind': 'button', 'label': 'Kid'},
            ],
          },
        ]),
        kTestSources,
      );
      expect(respOut, contains('LayoutBuilder'));
      expect(respOut, contains("tier == 'desktop'"));
      expect("'Kid'".allMatches(respOut).length, 2);
      expect(respOut, contains("'Wide'"));
    });
  });

  group('Track X2 fill parity (SizedBox + stretch Column + Expanded-when-h)', () {
    ScreenDoc x2Doc(List<Map<String, dynamic>> nodes) => ScreenDoc.fromJson({
          'screens': [
            {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          ],
          'nodes': nodes,
          'theme': {
            'paletteKey': 'clean-slate',
            'dark': true,
            'shape': 'rounded',
            'motion': 'standard',
          },
          'meta': {'title': 'Fill', 'brief': ''},
        });

    Map<String, dynamic> x2Leaf({
      required String id,
      double? w,
      double? h,
    }) => {
          'id': id,
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i$id', 'kind': 'button', 'label': 'Go'},
          ],
          if (w != null) 'w': w,
          if (h != null) 'h': h,
        };

    test('sized w+h emits fill box with stretch Column and Expanded', () {
      final out = buildSingleFile(
        x2Doc([x2Leaf(id: 'n1', w: 120, h: 80)]),
        const {},
      );
      expect(out, contains('width: 120,'));
      expect(out, contains('height: 80,'));
      expect(
        out,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch,'),
      );
      expect(out, contains('Expanded('));
      expect(out, contains("'Go'"));
      expect(
        out.indexOf('width: 120,'),
        lessThan(out.indexOf('CrossAxisAlignment.stretch')),
      );
      expect(
        out.indexOf('CrossAxisAlignment.stretch'),
        lessThan(out.indexOf('Expanded(')),
      );
      expect(out.indexOf('Expanded('), lessThan(out.indexOf("'Go'")));
    });

    test('w-only emits stretch without Expanded', () {
      final out = buildSingleFile(
        x2Doc([x2Leaf(id: 'n1', w: 200)]),
        const {},
      );
      expect(out, contains('width: 200,'));
      expect(
        out,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch,'),
      );
      expect(out, isNot(contains('height:')));
      expect(out, isNot(contains('Expanded(')));
    });

    test('h-only emits stretch with Expanded', () {
      final out = buildSingleFile(
        x2Doc([x2Leaf(id: 'n1', h: 90)]),
        const {},
      );
      expect(out, contains('height: 90,'));
      expect(
        out,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch,'),
      );
      expect(out, contains('Expanded('));
    });

    test('unsized docs emit no fill (byte-identical guard)', () {
      final out = buildSingleFile(x2Doc([x2Leaf(id: 'n1')]), const {});
      expect(out, isNot(contains('CrossAxisAlignment.stretch')));
      expect(out, isNot(contains('Expanded(')));
      expect(out, isNot(contains('width:')));
      // Unsized two-screen doc stays byte-identical to the golden.
      expect(buildSingleFile(buildTwoScreenDoc(), kTestSources), kSingleFileGolden);
    });
  });
}

/// Builds a one-screen doc from [nodes] for the C3 recursion tests.
ScreenDoc _c3Doc(List<Map<String, dynamic>> nodes) {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': nodes,
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'Nest', 'brief': ''},
  });
}

/// A card root with one button child (the canonical C3 fixture).
List<Map<String, dynamic>> _cardWithButtonNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {'id': 'i2', 'kind': 'button', 'label': 'Go'},
        ],
      },
    ];

/// Three-deep chain: card > dialog > button.
List<Map<String, dynamic>> _threeDeepNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {
            'id': 'i2',
            'kind': 'dialog',
            'title': 'Dlg',
            'message': 'Dlg body',
          },
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {'id': 'i3', 'kind': 'button', 'label': 'Deep'},
        ],
      },
    ];

/// A row root with a card child holding a button (card-in-row).
List<Map<String, dynamic>> _cardInRowNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {'id': 'i2', 'kind': 'button', 'label': 'Inner'},
        ],
      },
    ];

/// A card root with a row child holding two buttons (row-in-card).
List<Map<String, dynamic>> _rowInCardNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'T',
            'description': 'Card body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {'id': 'i3', 'kind': 'button', 'label': 'A'},
        ],
      },
      {
        'id': 'n4',
        'screenId': 's1',
        'parentId': 'n2',
        'x': 48.0,
        'y': 96.0,
        'items': [
          {'id': 'i4', 'kind': 'button', 'label': 'B'},
        ],
      },
    ];

/// Full nested-doc fixture for the Track D3 export golden (mirrors the
/// COMPOSITION.md contract): card{input + button→screen} with a per-level
/// mobile tier, a 3-deep card > dialog > button chain with per-level tablet /
/// desktop tiers plus a depth-2 tap, and a row-in-card strip.
List<Map<String, dynamic>> _nestedExportNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'hiddenOn': ['mobile'],
        'items': [
          {
            'id': 'i1',
            'kind': 'card',
            'title': 'Shop',
            'description': 'Shop body',
          },
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {
            'id': 'i2',
            'kind': 'input',
            'label': 'Name',
            'placeholder': 'Type here',
          },
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 96.0,
        'items': [
          {
            'id': 'i3',
            'kind': 'button',
            'label': 'Go',
            'action': {'to': 's2', 'transition': 'slide'},
          },
        ],
      },
      {
        'id': 'n4',
        'screenId': 's1',
        'x': 0.0,
        'y': 144.0,
        'items': [
          {
            'id': 'i4',
            'kind': 'card',
            'title': 'Deep',
            'description': 'Deep body',
          },
        ],
      },
      {
        'id': 'n5',
        'screenId': 's1',
        'parentId': 'n4',
        'x': 0.0,
        'y': 192.0,
        'hiddenOn': ['tablet'],
        'items': [
          {
            'id': 'i5',
            'kind': 'dialog',
            'title': 'Dlg',
            'message': 'Dlg body',
          },
        ],
      },
      {
        'id': 'n6',
        'screenId': 's1',
        'parentId': 'n5',
        'x': 0.0,
        'y': 240.0,
        'breakpointValues': {
          'desktop': {'label': 'Wide Go'},
        },
        'items': [
          {
            'id': 'i6',
            'kind': 'button',
            'label': 'Deep Go',
            'action': {'to': 's2', 'transition': 'fade'},
          },
        ],
      },
      {
        'id': 'n7',
        'screenId': 's1',
        'x': 0.0,
        'y': 288.0,
        'items': [
          {
            'id': 'i7',
            'kind': 'card',
            'title': 'Strip',
            'description': 'Strip body',
          },
        ],
      },
      {
        'id': 'n8',
        'screenId': 's1',
        'parentId': 'n7',
        'x': 0.0,
        'y': 336.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n9',
        'screenId': 's1',
        'parentId': 'n8',
        'x': 0.0,
        'y': 384.0,
        'items': [
          {'id': 'i9', 'kind': 'button', 'label': 'A'},
        ],
      },
      {
        'id': 'n10',
        'screenId': 's1',
        'parentId': 'n8',
        'x': 48.0,
        'y': 384.0,
        'items': [
          {'id': 'i10', 'kind': 'button', 'label': 'B'},
        ],
      },
    ];

/// Two-screen doc around [_nestedExportNodes]: `s2` is the tap target for
/// the nested buttons (kept empty so the golden stays focused on `s1`).
ScreenDoc _nestedExportDoc() {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': _nestedExportNodes(),
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'Nest', 'brief': ''},
  });
}

/// A row-only doc (no containers): pins the historical row emission.
List<Map<String, dynamic>> _rowOnlyNodes() => [
      {
        'id': 'n1',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        'isRow': true,
        'items': <Map<String, dynamic>>[],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {'id': 'i1', 'kind': 'button', 'label': 'A'},
        ],
      },
      {
        'id': 'n3',
        'screenId': 's1',
        'parentId': 'n1',
        'x': 48.0,
        'y': 48.0,
        'items': [
          {'id': 'i2', 'kind': 'button', 'label': 'B'},
        ],
      },
    ];

/// Two-kind doc (aaa + bbb) for the rival/identifier tests.
ScreenDoc _twoKindDoc() {
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
          {'id': 'i1', 'kind': 'aaa'},
        ],
      },
      {
        'id': 'n2',
        'screenId': 's1',
        'x': 0.0,
        'y': 48.0,
        'items': [
          {'id': 'i2', 'kind': 'bbb'},
        ],
      },
    ],
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'Kind', 'brief': ''},
  });
}

/// Twin extensions colliding on `tiny`; aaa's use has a `Widget`-typed
/// identifier receiver, bbb's a constructor receiver.
const _identSources = {
  'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class Aaa extends StatelessWidget {
  final Widget child;
  const Aaa({super.key, required this.child});
  Widget build(BuildContext context) => child.tiny();
}
''',
  'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension ExtA on Widget {
  Widget tiny() => this;
}
''',
  'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => const Text('y').tiny();
}
''',
  'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension ExtB on Widget {
  Widget tiny() => this;
}
''',
};

/// Builds a one-screen doc with a single item of [kind] carrying [props].
ScreenDoc _singleItemDoc(String kind,
    [Map<String, dynamic> props = const {}]) {
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
          {'id': 'i1', 'kind': kind, ...props},
        ],
      },
    ],
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'Kind', 'brief': ''},
  });
}

/// Per-kind emitter expectations: non-default props plus the widget-name and
/// prop-value markers the emission must contain.
class _KindCase {
  final Map<String, dynamic> props;
  final List<String> markers;

  const _KindCase(this.props, this.markers);
}

/// All 68 catalog kinds plus the 10 hand-verified EASY kinds, mirroring the
/// catalog defaults in `component_catalog.dart` / `component_registry.dart`.
const _kKindCases = <String, _KindCase>{
  'button': _KindCase(
    {'label': 'B', 'variant': 'secondary', 'size': 'lg', 'disabled': true},
    ['SecondaryButton', "'B'", 'ButtonSize.large', 'enabled: false'],
  ),
  'card': _KindCase(
    {'title': 'T', 'description': 'D', 'showFooter': true},
    ['Card(', "'T'", "'D'", "'Action'"],
  ),
  'input': _KindCase(
    {'label': 'L', 'placeholder': 'P'},
    ['TextField(', "'L'", "'P'"],
  ),
  'badge': _KindCase(
    {'label': 'New', 'variant': 'outline'},
    ['OutlineBadge', "'New'"],
  ),
  'switch': _KindCase(
    {'value': true},
    ['Switch(', 'value: true'],
  ),
  'accordion': _KindCase(
    {'title': 'FAQ', 'content': 'Answer', 'expanded': true},
    ['Accordion(', 'AccordionItem(', 'AccordionTrigger(', "'FAQ'"],
  ),
  'alert': _KindCase(
    {'title': 'Oops', 'content': 'Bad', 'destructive': true},
    ['Alert(', "'Oops'", 'destructive: true'],
  ),
  'alert_dialog': _KindCase(
    {'title': 'Sure?', 'message': 'Undo?'},
    ['AlertDialog(', "'Sure?'"],
  ),
  'avatar': _KindCase(
    {'initials': 'CD', 'size': 48},
    ['Avatar(', "'CD'", 'size: 48'],
  ),
  'basic': _KindCase(
    {'title': 'T', 'subtitle': 'S', 'content': 'C'},
    ['Basic(', "'T'"],
  ),
  'breadcrumb': _KindCase(
    {'home': 'Root', 'current': 'Leaf', 'separator': 'slash'},
    ['Breadcrumb(', 'slashSeparator', "'Root'"],
  ),
  'calendar': _KindCase(
    {'mode': 'range'},
    ['Calendar(', 'CalendarSelectionMode.range', 'CalendarView.now()'],
  ),
  'card_image': _KindCase(
    {'title': 'CT', 'subtitle': 'CS'},
    ['CardImage(', "'CT'"],
  ),
  'carousel': _KindCase(
    {'slides': 2},
    ['Carousel(', 'CarouselTransition.sliding', 'itemCount: 2'],
  ),
  'chat': _KindCase(
    {'message': 'Hi'},
    ['ChatBubble(', "'Hi'"],
  ),
  'checkbox': _KindCase(
    {'value': true, 'tristate': true},
    ['Checkbox(', 'CheckboxState.checked', 'tristate: true'],
  ),
  'chip': _KindCase(
    {'label': 'Tag'},
    ['Chip(', "'Tag'"],
  ),
  'circular_progress_indicator': _KindCase(
    {'value': 0.3},
    ['CircularProgressIndicator(', '0.3'],
  ),
  'clickable': _KindCase(
    {'label': 'Go'},
    ['Clickable(', "'Go'"],
  ),
  'code_snippet': _KindCase(
    {'code': 'x = 1'},
    ['CodeSnippet(', "'x = 1'"],
  ),
  'collapsible': _KindCase(
    {'trigger': 'More', 'content': 'Less', 'expanded': true},
    ['Collapsible(', 'CollapsibleTrigger(', "'More'"],
  ),
  'color_input': _KindCase(
    {'hex': '#FF0000'},
    ['ColorInput(', 'Color(0xFFFF0000)'],
  ),
  'color_picker': _KindCase(
    {'hex': '#00FF00'},
    ['ColorPicker(', 'Color(0xFF00FF00)'],
  ),
  'command': _KindCase(
    {'hint': 'Find', 'item1': 'A', 'item2': 'B'},
    ['CommandCategory(', 'CommandItem(', "'Find'"],
  ),
  'context_menu': _KindCase(
    {'hint': 'Right', 'item1': 'X', 'item2': 'Y'},
    ['ContextMenu(', "'Right'"],
  ),
  'date_picker': _KindCase(
    {'placeholder': 'Pick', 'label': 'When'},
    ['DatePicker(', "'Pick'", "'When'"],
  ),
  'dialog': _KindCase(
    {'title': 'DT', 'message': 'DM', 'showActions': false},
    ['ModalContainer(', "'DT'"],
  ),
  'divider': _KindCase(
    {'label': 'OR', 'thickness': 2},
    ['Divider(', "'OR'"],
  ),
  'dot_indicator': _KindCase(
    {'index': 1, 'length': 4},
    ['DotIndicator(', 'index: 1', 'length: 4'],
  ),
  'drawer': _KindCase(
    {'title': 'DT', 'content': 'DC', 'position': 'left'},
    ['DrawerWrapper(', 'OverlayPosition.left', "'DT'"],
  ),
  'dropdown_menu': _KindCase(
    {'heading': 'H', 'item1': 'A', 'item2': 'B'},
    ['DropdownMenu(', 'MenuLabel(', "'H'"],
  ),
  'empty_state': _KindCase(
    {'title': 'Empty', 'description': 'Nada'},
    ['EmptyState(', "'Empty'"],
  ),
  'feature_carousel': _KindCase(
    {
      'title1': 'F1',
      'description1': 'D1',
      'title2': 'F2',
      'description2': 'D2',
    },
    ['FeatureCardCarousel(', 'FeatureCarouselItem(', "'F1'"],
  ),
  'form': _KindCase(
    {'label': 'L', 'placeholder': 'P', 'submitLabel': 'Go'},
    ['FormTableLayout(', 'FormField<String>(', "'Go'"],
  ),
  'form_field': _KindCase(
    {'placeholder': 'Pick', 'value': 'V'},
    ['ObjectFormField<String>(', "'V'"],
  ),
  'formatted_input': _KindCase(
    {'label': 'Date'},
    ['FormattedInput(', 'FormattedValue(', "'Date'"],
  ),
  'hidden': _KindCase(
    {'label': 'Hid', 'hidden': true},
    ['Hidden(', 'hidden: true', "'Hid'"],
  ),
  'history': _KindCase(
    {'columns': 4},
    ['ColorHistoryGrid(', 'crossAxisCount: 4'],
  ),
  'hover_card': _KindCase(
    {'handle': 'Hov', 'title': 'T', 'body': 'B'},
    ['HoverCard(', "'Hov'"],
  ),
  'hsl': _KindCase(
    {'mode': 'sat'},
    ['HSLColorSlider(', 'HSLColorSliderType.sat'],
  ),
  'hsv': _KindCase(
    {'mode': 'val'},
    ['HSVColorSlider(', 'HSVColorSliderType.val'],
  ),
  'input_otp': _KindCase(
    {'length': 4},
    ['InputOTP(', 'InputOTPChild.character('],
  ),
  'keyboard_shortcut': _KindCase(
    {'keys': 'Ctrl+K'},
    ['KeyboardDisplay(', 'LogicalKeyboardKey.controlLeft'],
  ),
  'linear_progress_indicator': _KindCase(
    {'value': 0.2},
    ['LinearProgressIndicator(', '0.2'],
  ),
  'menu': _KindCase(
    {'heading': 'MH', 'item1': 'A', 'item2': 'B'},
    ['MenuGroup(', 'MenuPopup(', "'MH'"],
  ),
  'menubar': _KindCase(
    {'menu1': 'File', 'menu2': 'Edit'},
    ['Menubar(', "'File'"],
  ),
  'number_ticker': _KindCase(
    {'value': 7},
    ['NumberTicker(', 'number: 7'],
  ),
  'outlined_container': _KindCase(
    {'label': 'OL'},
    ['OutlinedContainer(', "'OL'"],
  ),
  'pagination': _KindCase(
    {'page': 2, 'totalPages': 7},
    ['Pagination(', 'page: 2', 'totalPages: 7'],
  ),
  'popover': _KindCase(
    {'trigger': 'Open', 'title': 'PT', 'body': 'PB'},
    ['ModalContainer(', "'Open'"],
  ),
  'popup': _KindCase(
    {'item1': 'A', 'item2': 'B', 'item3': 'C'},
    ['MenuPopup(', "'C'"],
  ),
  'progress': _KindCase(
    {'progress': 0.7},
    ['Progress(', '0.7'],
  ),
  'radio_group': _KindCase(
    {'option1': 'A', 'option2': 'B', 'value': 'B'},
    ['RadioGroup<String>(', 'RadioItem<String>(', "value: 'B'"],
  ),
  'refresh_trigger': _KindCase(
    {'item1': 'R1', 'item2': 'R2', 'item3': 'R3'},
    ['RefreshTrigger(', "'R1'"],
  ),
  'scaffold': _KindCase(
    {'title': 'App', 'body': 'Hi'},
    ['Scaffold(', 'AppBar(', "'App'"],
  ),
  'scrollbar': _KindCase(
    {'label': 'Scroll'},
    ['Scrollbar(', "'Scroll'"],
  ),
  'select': _KindCase(
    {
      'placeholder': 'PH',
      'option1': 'A',
      'option2': 'B',
      'value': 'A',
    },
    ['Select<String>(', "'PH'", "value: 'A'"],
  ),
  'selectable': _KindCase(
    {'text': 'Sel'},
    ['SelectableText(', "'Sel'"],
  ),
  'skeleton': _KindCase(
    {'label': 'Wait', 'enabled': true},
    ['.asSkeleton(', "'Wait'"],
  ),
  'slider': _KindCase(
    {'value': 0.4},
    ['Slider(', '0.4'],
  ),
  'star_rating': _KindCase(
    {'value': 4, 'max': 5},
    ['StarRating(', 'value: 4', 'max: 5'],
  ),
  'stepper': _KindCase(
    {
      'step1': 'S1',
      'detail1': 'D1',
      'step2': 'S2',
      'detail2': 'D2',
      'step3': 'S3',
      'detail3': 'D3',
      'step': 1,
    },
    ['CanvasStepperCell(', 'initialStep: 1', "'S1'"],
  ),
  'steps': _KindCase(
    {'step1': 'One', 'detail1': 'D1', 'step2': 'Two', 'detail2': 'D2'},
    ['Steps(', 'StepItem(', "'One'"],
  ),
  'swiper': _KindCase(
    {'hint': 'Swipe', 'content': 'Body'},
    ['Swiper(', 'SwiperHandler.sheet', "'Swipe'"],
  ),
  'tab_container': _KindCase(
    {'tab1': 'A', 'tab2': 'B', 'tab3': 'C', 'index': 1},
    ['TabContainer(', "'A'", 'selected: 1'],
  ),
  'tab_list': _KindCase(
    {'tab1': 'X', 'tab2': 'Y', 'index': 1},
    ['TabList(', 'index: 1', "'X'"],
  ),
  'tab_pane': _KindCase(
    {'tab1': 'A', 'tab2': 'B', 'tab3': 'C', 'focused': 2},
    ['TabPane<String>(', 'TabPaneData(', 'focused: 2'],
  ),
  'table': _KindCase(
    {
      'header1': 'H1',
      'header2': 'H2',
      'name1': 'N1',
      'role1': 'R1',
      'name2': 'N2',
      'role2': 'R2',
    },
    ['Table(', 'TableHeader(', "'H1'"],
  ),
  'tabs': _KindCase(
    {'tab1': 'T1', 'tab2': 'T2', 'index': 1, 'expand': true},
    ['Tabs(', 'expand: true', "'T1'"],
  ),
  'text_area': _KindCase(
    {'placeholder': 'Write', 'label': 'Bio', 'disabled': true},
    ['TextArea(', "'Write'", "'Bio'"],
  ),
  'time_picker': _KindCase(
    {'placeholder': 'TP', 'label': 'At'},
    ['TimePicker(', "'TP'"],
  ),
  'timeline': _KindCase(
    {
      'time1': '9',
      'title1': 'T1',
      'detail1': 'D1',
      'time2': '10',
      'title2': 'T2',
      'detail2': 'D2',
    },
    ['Timeline(', 'TimelineData(', "'T1'"],
  ),
  'toast': _KindCase(
    {'title': 'TT', 'message': 'TM', 'autoDismiss': true},
    ['ToastEntry(', 'autoDismiss: true', "'TT'"],
  ),
  'tooltip': _KindCase(
    {'label': 'L', 'tip': 'Tip!'},
    ['Tooltip(', 'TooltipContainer(', "'Tip!'"],
  ),
  'tracker': _KindCase(
    {'segments': 2, 'level': 'warning'},
    ['Tracker(', 'TrackerLevel.warning'],
  ),
  'tree': _KindCase(
    {'node1': 'N1', 'child1': 'C1', 'child2': 'C2', 'node2': 'N2'},
    ['TreeView<String>(', 'TreeItem(', "'N1'"],
  ),
  'triple_dots': _KindCase(
    {'count': 5},
    ['MoreDots(', 'count: 5'],
  ),
  'validated': _KindCase(
    {'placeholder': 'Name', 'errorText': 'Req'},
    ['Validated<String>(', 'ValidatorBuilder<String>(', "'Req'"],
  ),
};

/// Every kind the full-seed smoke doc touches: the 68 catalog kinds plus the
/// 10 hand-verified EASY kinds.
const _kAllSmokeKinds = [
  'button',
  'card',
  'input',
  'badge',
  'switch',
  'avatar',
  'checkbox',
  'divider',
  'progress',
  'tabs',
  'accordion',
  'select',
  'radio_group',
  'skeleton',
  'breadcrumb',
  'dialog',
  'tooltip',
  'toast',
  'drawer',
  'basic',
  'card_image',
  'scaffold',
  'collapsible',
  'steps',
  'timeline',
  'outlined_container',
  'hidden',
  'keyboard_shortcut',
  'tracker',
  'chat',
  'selectable',
  'star_rating',
  'clickable',
  'scrollbar',
  'pagination',
  'alert_dialog',
  'menu',
  'popover',
  'popup',
  'menubar',
  'dropdown_menu',
  'context_menu',
  'hover_card',
  'command',
  'swiper',
  'refresh_trigger',
  'tab_container',
  'tab_list',
  'tab_pane',
  'stepper',
  'slider',
  'input_otp',
  'calendar',
  'date_picker',
  'time_picker',
  'carousel',
  'tree',
  'table',
  'form',
  'form_field',
  'formatted_input',
  'validated',
  'color_picker',
  'color_input',
  'hsl',
  'hsv',
  'history',
  'feature_carousel',
  'alert',
  'chip',
  'circular_progress_indicator',
  'code_snippet',
  'dot_indicator',
  'empty_state',
  'linear_progress_indicator',
  'number_ticker',
  'text_area',
  'triple_dots',
];

/// Byte-identical golden for [buildSingleFile] on [buildTwoScreenDoc]
/// (responsive emission must not alter output for docs without
/// responsive fields). Regenerate only by reviewing the exporter diff.
///
/// Track K1: the Pay button's known-target tap (`s2`) is wrapped in the
/// bundle-equivalent `GestureDetector` navigation; the `// taps -> s2`
/// comment above it is kept verbatim.
const kSingleFileGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: gap, data_widget
// screens: Pay, Done

import 'package:flutter/widgets.dart';

class CanvasScreen_Pay extends StatelessWidget {
  const CanvasScreen_Pay({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // taps -> s2
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/done'), // transition: slide
            child: PrimaryButton(
              onPressed: () {},
              enabled: true,
              size: ButtonSize.normal,
              child: Text('Pay'),
            ),
          ),
        ],
      ),
    );
  }
}

class CanvasScreen_Done extends StatelessWidget {
  const CanvasScreen_Done({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Done'),
                const SizedBox(height: 4),
                Text('Payment complete'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// from: registry/components/button/button.dart

class Button extends StatelessWidget {
  const Button({super.key});
}

// TODO(canvas): no source for kind "card"
''';

/// Stub component sources for the closure group: paths mirror the
/// manifest-convention layout (`r/components/<category>/<kind>/…`,
/// `r/shared/…`) so kind matching and relative resolution behave like the
/// real maps at a tiny scale.
const _closureSources = {
  'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/part_a.dart';
import '../alp/alp.dart';
import '../../../shared/theme.dart' as t;

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => t.Theme.of(context).wrap(1);
}
''',
  'r/components/cat/aaa/_impl/part_a.dart': '''
part of '../aaa.dart';

class PartA {}
''',
  'r/components/cat/aaa/aaa_barrel.dart': '''
export 'aaa.dart';
''',
  'r/components/cat/alp/alp.dart': '''
class Alpha {}
''',
  'r/components/cat/bbb/bbb.dart': '''
class Bbb {}
''',
  // Byte-identical vendored copy of the shared helper (carve target).
  'r/components/cat/bbb/_impl/help_copy.dart': '''
int twice(int x) => x * 2;
''',
};

/// Stub shared sources for the closure group.
const _closureShared = {
  'r/shared/theme.dart': '''
import 'package:flutter/widgets.dart';

class Theme {
  static Theme of(BuildContext context) => Theme();
  Widget wrap(int x) => const SizedBox();
}

class Data {
  static Data of(BuildContext context) => Data();
  int get x => 1;
}
''',
  'r/shared/help.dart': '''
int twice(int x) => x * 2;
''',
};

/// Stub part map for the closure group.
const _closureParts = {
  'r/components/cat/aaa/_impl/part_a.dart': 'r/components/cat/aaa/aaa.dart',
};

/// Closure-path emission for [_singleItemDoc] over the stub maps.
String _closureOut(ScreenDoc doc) => buildSingleFile(
      doc,
      _closureSources,
      sharedSources: _closureShared,
      extraImports: const ['package:data_widget/data_widget.dart'],
      partOf: _closureParts,
    );

/// Stub sources for the rival-extension tests: ExtA and ExtB (both
/// `on Widget`) collide on `tiny`; `huge` is ExtB-only. ccc.dart imports
/// both rivals (both-visible residual case).
const _extSources = {
  'r/components/cat/aaa/aaa.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_a.dart';

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => const Text('x').tiny();
}
''',
  'r/components/cat/aaa/_impl/ext_a.dart': '''
import 'package:flutter/widgets.dart';

extension ExtA on Widget {
  Widget tiny() => this;
}
''',
  'r/components/cat/bbb/bbb.dart': '''
import 'package:flutter/widgets.dart';
import '_impl/ext_b.dart';

class Bbb extends StatelessWidget {
  const Bbb({super.key});
  Widget build(BuildContext context) => const Text('y').tiny();
  String big() => const Text('z').huge();
}
''',
  'r/components/cat/bbb/_impl/ext_b.dart': '''
import 'package:flutter/widgets.dart';

extension ExtB on Widget {
  Widget tiny() => this;
  String huge() => 'h';
}
''',
  'r/components/cat/ccc/ccc.dart': '''
import 'package:flutter/widgets.dart';
import '../aaa/_impl/ext_a.dart';
import '../bbb/_impl/ext_b.dart';

class Ccc extends StatelessWidget {
  const Ccc({super.key});
  Widget build(BuildContext context) => const Text('w').tiny();
}
''',
};

/// Byte-identical golden for the closure path on the two-kind stub doc.
/// Regenerate only by reviewing the exporter diff.
///
/// Track K1: the header ignore line no longer lists `duplicate_import` —
/// the header emits each distinct import line once (pass (S)
/// canonicalization plus line dedupe), so a duplicate would surface as an
/// honest analyzer warning instead of being silenced.
const kClosureGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: (none)
// screens: Home

import 'package:data_widget/data_widget.dart';
import 'package:flutter/widgets.dart';

// ignore_for_file: unnecessary_import, unused_import, unnecessary_null_comparison, dead_code, deprecated_member_use, use_null_aware_elements, sort_child_properties_last

class CanvasScreen_Home extends StatelessWidget {
  const CanvasScreen_Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('unknown: aaa'),
          const SizedBox(height: 12),
          Text('unknown: bbb'),
        ],
      ),
    );
  }
}

// from: r/shared/theme.dart

class Theme {
  static Theme of(BuildContext context) => Theme();
  Widget wrap(int x) => const SizedBox();
}

class Data {
  static Data of(BuildContext context) => Data();
  int get x => 1;
}

// from: r/shared/help.dart
int twice(int x) => x * 2;

// from: r/components/cat/aaa/aaa.dart

class Aaa extends StatelessWidget {
  const Aaa({super.key});
  Widget build(BuildContext context) => Theme.of(context).wrap(1);
}

// from: r/components/cat/aaa/_impl/part_a.dart

class PartA {}

// from: r/components/cat/bbb/bbb.dart
class Bbb {}

// from: r/components/cat/alp/alp.dart
class Alpha {}
''';

/// Byte-identical golden for the canonical C3 fixture: a card root with one
/// button child. The child splices into the card slot (after the
/// description, gap-separated); everything else matches the childless form.
const kSingleNestedCardGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: gap, data_widget
// screens: Home

import 'package:flutter/widgets.dart';

class CanvasScreen_Home extends StatelessWidget {
  const CanvasScreen_Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('T'),
                const SizedBox(height: 4),
                Text('Card body'),
                const SizedBox(height: 12),
                PrimaryButton(
                  onPressed: () {},
                  enabled: true,
                  size: ButtonSize.normal,
                  child: Text('Go'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// TODO(canvas): no source for kind "card"

// from: registry/components/button/button.dart

class Button extends StatelessWidget {
  const Button({super.key});
}
''';

/// Byte-identical golden for three-deep nesting (card > dialog > button):
/// each level splices into its own slot — the dialog (with its default
/// action row) lands inside the card slot, the button inside the dialog
/// slot after the message.
const kSingleThreeDeepGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: gap, data_widget
// screens: Home

import 'package:flutter/widgets.dart';

class CanvasScreen_Home extends StatelessWidget {
  const CanvasScreen_Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('T'),
                const SizedBox(height: 4),
                Text('Card body'),
                const SizedBox(height: 12),
                ModalContainer(
                  filled: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dlg'),
                      const SizedBox(height: 12),
                      Text('Dlg body'),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        onPressed: () {},
                        enabled: true,
                        size: ButtonSize.normal,
                        child: Text('Deep'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Spacer(),
                          OutlineButton(
                            onPressed: () {},
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// TODO(canvas): no source for kind "card"

// TODO(canvas): no source for kind "dialog"

// from: registry/components/button/button.dart

class Button extends StatelessWidget {
  const Button({super.key});
}
''';

/// Byte-identical golden for the Track D3 nested export doc
/// ([_nestedExportNodes]): card{input + button→screen} with a mobile tier,
/// a 3-deep card > dialog > button chain with tablet/desktop tiers plus a
/// depth-2 tap, and a row-in-card strip. Regenerate only by reviewing the
/// exporter diff.
const kSingleNestedExportGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: gap, data_widget
// screens: Home, Done

import 'package:flutter/widgets.dart';

class CanvasScreen_Home extends StatelessWidget {
  const CanvasScreen_Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // responsive (hidden on mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              final tier = constraints.maxWidth >= 1024 ? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';
              if (tier == 'mobile') return const SizedBox.shrink();
              return Card(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shop'),
                    const SizedBox(height: 4),
                    Text('Shop body'),
                    const SizedBox(height: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name'),
                        const SizedBox(height: 6),
                        TextField(
                      placeholder: Text('Type here'),
                      enabled: true,
                      obscureText: false,
                    ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // taps -> s2
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/done'), // transition: slide
                      child: PrimaryButton(
                        onPressed: () {},
                        enabled: true,
                        size: ButtonSize.normal,
                        child: Text('Go'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deep'),
                const SizedBox(height: 4),
                Text('Deep body'),
                const SizedBox(height: 12),
                // responsive (hidden on tablet)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tier = constraints.maxWidth >= 1024 ? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';
                    if (tier == 'tablet') return const SizedBox.shrink();
                    return ModalContainer(
                      filled: true,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dlg'),
                          const SizedBox(height: 12),
                          Text('Dlg body'),
                          const SizedBox(height: 12),
                          // responsive (overrides on desktop)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final tier = constraints.maxWidth >= 1024 ? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';
                              // taps -> s2
                              if (tier == 'desktop') return GestureDetector(
                                onTap: () => Navigator.of(context).pushNamed('/done'), // transition: fade
                                child: PrimaryButton(
                                  onPressed: () {},
                                  enabled: true,
                                  size: ButtonSize.normal,
                                  child: Text('Wide Go'),
                                ),
                              );
                              // taps -> s2
                              return GestureDetector(
                                onTap: () => Navigator.of(context).pushNamed('/done'), // transition: fade
                                child: PrimaryButton(
                                  onPressed: () {},
                                  enabled: true,
                                  size: ButtonSize.normal,
                                  child: Text('Deep Go'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Spacer(),
                              OutlineButton(
                                onPressed: () {},
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Strip'),
                const SizedBox(height: 4),
                Text('Strip body'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PrimaryButton(
                      onPressed: () {},
                      enabled: true,
                      size: ButtonSize.normal,
                      child: Text('A'),
                    ),
                    const SizedBox(width: 8),
                    PrimaryButton(
                      onPressed: () {},
                      enabled: true,
                      size: ButtonSize.normal,
                      child: Text('B'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CanvasScreen_Done extends StatelessWidget {
  const CanvasScreen_Done({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (empty screen)
        ],
      ),
    );
  }
}

// TODO(canvas): no source for kind "card"

// TODO(canvas): no source for kind "input"

// from: registry/components/button/button.dart

class Button extends StatelessWidget {
  const Button({super.key});
}

// TODO(canvas): no source for kind "dialog"
''';

/// Byte-identical golden for a row-only doc (no containers): pins the
/// historical row emission (alignment defaults, width separators) so C3
/// recursion cannot silently reshape it.
const kSingleRowOnlyGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: gap, data_widget
// screens: Home

import 'package:flutter/widgets.dart';

class CanvasScreen_Home extends StatelessWidget {
  const CanvasScreen_Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PrimaryButton(
                onPressed: () {},
                enabled: true,
                size: ButtonSize.normal,
                child: Text('A'),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                onPressed: () {},
                enabled: true,
                size: ButtonSize.normal,
                child: Text('B'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// from: registry/components/button/button.dart

class Button extends StatelessWidget {
  const Button({super.key});
}
''';
