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
}
