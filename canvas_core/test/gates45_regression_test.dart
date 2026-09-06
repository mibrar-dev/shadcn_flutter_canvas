/// Gates 4–5 defect regressions (DEFECT-1..4, `docs/BUILD_GATES45_EVIDENCE.md`
/// §5): the generated project must analyze clean (gate 4) and build for
/// the web (gate 5) with no post-generation `flutter create` step.
///
/// * DEFECT-1: no `ambiguous_import` shape in emitted pages — the kit
///   global barrel always carries the kit-side hide list, the Flutter
///   import hides kit-wins names per used kind, and kit-free pages import
///   no kit library at all.
/// * DEFECT-2: const-canonical emission (kit leaves, placeholders, theme).
/// * DEFECT-3: `main.dart` is a formatter fixpoint in both variants.
/// * DEFECT-4: the writer owns the `web/` scaffold (tool-author file set).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:canvas_core/canvas_core.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

/// Single-screen doc with one item per [kinds] (stacked roots, doc order).
/// [propsFor] optionally supplies item props per kind.
ScreenDoc _doc(
  List<String> kinds, [
  String name = 'Home',
  Map<String, Map<String, Object?>> propsFor = const {},
]) {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': name, 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': [
      for (var i = 0; i < kinds.length; i++)
        {
          'id': 'n$i',
          'screenId': 's1',
          'x': 0.0,
          'y': i * 48.0,
          'items': [
            {'id': 'i$i', 'kind': kinds[i], ...?propsFor[kinds[i]]},
          ],
        },
    ],
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'G45', 'brief': ''},
  });
}

/// Emitted page source for a single-screen [kinds] doc.
String _page(
  List<String> kinds, [
  Map<String, Map<String, Object?>> propsFor = const {},
]) {
  final doc = _doc(kinds, 'Home', propsFor);
  final files = emitPrimitivePageFiles(
    doc: doc,
    screen: doc.screens.single,
    extraEmitters: g3Emitters,
  );
  return files.singleWhere((f) => f.path.endsWith('_page.dart')).content;
}

/// The wrapped kit import every G3 page carries (over-80-col imports
/// arrive pre-wrapped exactly as `dart format` splits them — gate 3).
const _kitImportWrapped =
    "import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart'\n"
    '    hide Column, Expanded, Flex, Flexible, Positioned, Row,'
    ' Stack, Theme;';

/// The bare barrel: the ambiguous-import shape that must never appear.
const _kitImportBare =
    "import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart';";

/// PNG chunk walker: `(type, data)` pairs after signature validation.
List<(String, Uint8List)> _pngChunks(List<int> bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  expect(bytes.sublist(0, 8), signature, reason: 'PNG signature');
  final out = <(String, Uint8List)>[];
  var offset = 8;
  final data = Uint8List.fromList(bytes);
  int u32(int at) =>
      (data[at] << 24) |
      (data[at + 1] << 16) |
      (data[at + 2] << 8) |
      data[at + 3];
  while (offset < data.length) {
    final length = u32(offset);
    final type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
    out.add((type, data.sublist(offset + 8, offset + 8 + length)));
    offset += 12 + length;
    if (type == 'IEND') break;
  }
  return out;
}

void main() {
  group('DEFECT-1: no ambiguous-import shape in emitted pages', () {
    test('kit pages carry the kit-side hide list (Flutter wins)', () {
      for (final kinds in const [
        ['chip'],
        ['text_area'],
        ['circular_progress_indicator'],
        ['alert'],
      ]) {
        final page = _page(kinds);
        expect(page, contains(_kitImportWrapped), reason: '${kinds.single}');
        // The bare barrel (the ambiguous shape) never appears.
        expect(page, isNot(contains(_kitImportBare)),
            reason: '${kinds.single}');
      }
    });

    test('material omitted when the kit barrel covers every used name', () {
      // Single-kit-kind bodies reference only kit constructors + names the
      // kit re-exports as the same element: the shell material import would
      // read as `unnecessary_import`, so it is omitted.
      for (final kinds in const [
        ['chip'],
        ['alert'],
        ['triple_dots'],
      ]) {
        expect(
          _page(kinds),
          isNot(contains('package:flutter/material.dart')),
          reason: '${kinds.single}',
        );
      }
      // A Flutter-wins name anywhere in the body (here the empty column)
      // keeps material — with the used kinds' hides.
      final mixed = _page(['chip', 'column']);
      expect(
        mixed,
        contains("import 'package:flutter/material.dart' hide Chip;"),
      );
      expect(mixed, contains(_kitImportWrapped));
    });

    test('flutter hides stay scoped to the used kinds', () {
      final mixed = _page(['column', 'circular_progress_indicator']);
      expect(
        mixed,
        contains(
          "import 'package:flutter/material.dart'"
          ' hide CircularProgressIndicator;',
        ),
      );
      expect(mixed, isNot(contains('hide Chip')));
      // Scoping: a chip page hides Chip only — never unrelated kit names.
      expect(_page(['chip']), isNot(contains('CircularProgressIndicator')));
    });

    test('kit-free pages import no kit library at all', () {
      final page = _page(['container', 'column']);
      expect(page, isNot(contains('flutter_shadcn_kit')));
      expect(
        page,
        contains("import 'package:flutter/material.dart';\n"),
      );
    });

    test('collector unions hide sets across re-adds', () {
      final imports = ImportCollector()
        ..add('package:k/k.dart', hide: const ['B'])
        ..add('package:k/k.dart', hide: const ['A']);
      expect(imports.lines, ["import 'package:k/k.dart' hide A, B;"]);
      expect(imports.hideFor('package:k/k.dart'), {'A', 'B'});
      expect(imports.hideFor('package:missing/m.dart'), isEmpty);
    });
  });

  group('DEFECT-2: const-canonical emission', () {
    test('kit leaves + placeholders emit const', () {
      expect(_page(['chip']), contains('const Chip(child:'));
      expect(_page(['alert']), contains('const Alert('));
      expect(
        _page(['circular_progress_indicator']),
        contains('const CircularProgressIndicator('),
      );
      expect(_page(['triple_dots']), contains('const MoreDots('));
      expect(_page(['dot_indicator']), contains('const DotIndicator('));
      expect(_page(['empty_state']), contains('const EmptyState('));
      expect(_page(['code_snippet']), contains('const CodeSnippet('));
      expect(_page(['text_area']), contains('const TextArea('));
      // The non-empty label renders as a caption above the field: `const`
      // lives on the OUTERMOST eligible invocation only (canonical-const
      // rule — nested keywords would read as `unnecessary_const`).
      final captioned = _page(
        ['text_area'],
        {
          'text_area': {
            'label': 'About',
            'placeholder': 'Bio',
          },
        },
      );
      expect(captioned, contains('const Column('));
      expect(captioned, contains("Text('About')"));
      expect(captioned, isNot(contains("const Text('About')")));
      expect(captioned, isNot(contains('const TextArea(')));
      expect(
        _page(['scaffold']),
        contains("const Text('scaffold (not yet bridged)')"),
      );
    });

    test('number_ticker stays non-const (closure arg)', () {
      expect(_page(['number_ticker']), contains('NumberTicker('));
      expect(
        _page(['number_ticker']),
        isNot(contains('const NumberTicker(')),
      );
    });

    test('theme shell binds the scheme with const', () {
      final theme = buildAppTheme(
        const CanvasTheme(
          paletteKey: 'slate',
          dark: false,
          shape: 'rounded',
          motion: 'standard',
        ),
      );
      expect(theme, contains('const scheme = ColorScheme.light();'));
      expect(theme, isNot(contains('final scheme')));
    });
  });

  group('DEFECT-3: main.dart is format-clean in both variants', () {
    test('router + single-screen variants are formatter fixpoints', () {
      for (final hasRouter in [true, false]) {
        final main = buildMainDart(hasRouter: hasRouter);
        expect(
          DartFormatter().format(main),
          main,
          reason: 'hasRouter=$hasRouter',
        );
      }
    });

    test('blank line separates imports from void main', () {
      final router = buildMainDart(hasRouter: true);
      expect(
        router,
        contains(
          "import 'routes/app_router.dart';\n\nvoid main()",
        ),
      );
      final single = buildMainDart(hasRouter: false);
      expect(
        single,
        contains("import 'theme/app_theme.dart';\n\nvoid main()"),
      );
    });
  });

  group('DEFECT-4: writer-owned web/ scaffold', () {
    test('scaffoldProject emits the tool-author web/ file set', () {
      final doc = _doc(['container']);
      final paths =
          scaffoldProject(appName: 'demo', doc: doc).map((f) => f.path);
      expect(
        paths,
        containsAll([
          'web/index.html',
          'web/manifest.json',
          'web/favicon.png',
          'web/icons/Icon-192.png',
          'web/icons/Icon-512.png',
          'web/icons/Icon-maskable-192.png',
          'web/icons/Icon-maskable-512.png',
        ]),
      );
    });

    test('index.html interpolates the app name, keeps the base-href slot', () {
      final html = buildWebIndexHtml(appName: 'genproj');
      expect(html, contains('<title>genproj</title>'));
      expect(html, contains('content="genproj"'));
      expect(html, contains('<base href="\$FLUTTER_BASE_HREF">'));
      expect(html, contains('<script src="flutter_bootstrap.js" async>'));
    });

    test('manifest.json parses with the four declared icons', () {
      final manifest = jsonDecode(buildWebManifest(appName: 'genproj'))
          as Map<String, dynamic>;
      expect(manifest['name'], 'genproj');
      final icons = manifest['icons'] as List;
      expect(icons.length, 4);
      expect(
        [for (final i in icons) (i as Map)['src']],
        containsAll([
          'icons/Icon-192.png',
          'icons/Icon-512.png',
          'icons/Icon-maskable-192.png',
          'icons/Icon-maskable-512.png',
        ]),
      );
    });

    test('icons are valid PNGs at the manifest-declared sizes', () {
      int ihdrSize(Uint8List ihdr) =>
          (ihdr[0] << 24) | (ihdr[1] << 16) | (ihdr[2] << 8) | ihdr[3];
      for (final size in [16, 192, 512]) {
        final chunks = _pngChunks(webIconPng(size));
        expect(chunks.first.$1, 'IHDR');
        expect(chunks.last.$1, 'IEND');
        expect(chunks.any((c) => c.$1 == 'IDAT'), isTrue);
        final ihdr = chunks.first.$2;
        expect(ihdrSize(ihdr.sublist(0, 4)), size);
        expect(ihdrSize(ihdr.sublist(4, 8)), size);
        expect(ihdr[8], 8, reason: 'bit depth');
        expect(ihdr[9], 6, reason: 'color type RGBA');
      }
      // Deterministic: same input, same bytes.
      expect(webIconPng(16), webIconPng(16));
    });

    test('binary files ride bytes, text files ride content', () {
      final doc = _doc(['container']);
      final files = scaffoldProject(appName: 'demo', doc: doc);
      for (final f in files) {
        if (f.path.endsWith('.png')) {
          expect(f.isBinary, isTrue, reason: f.path);
          expect(f.bytes, isNotEmpty, reason: f.path);
        } else {
          expect(f.isBinary, isFalse, reason: f.path);
        }
      }
    });
  });
}
