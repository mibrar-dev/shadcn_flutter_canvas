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
}

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
