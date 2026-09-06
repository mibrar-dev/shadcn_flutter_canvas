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
}

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
          PrimaryButton(
            onPressed: () {},
            enabled: true,
            size: ButtonSize.normal,
            child: Text('Pay'),
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
const kClosureGolden = '''// generated by shadcn canvas — DO NOT EDIT.
// pubspec: (none)
// screens: Home

import 'package:data_widget/data_widget.dart';
import 'package:flutter/widgets.dart';

// ignore_for_file: duplicate_import, unnecessary_import, unused_import, unnecessary_null_comparison, dead_code, deprecated_member_use, use_null_aware_elements, sort_child_properties_last

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
