import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

/// Track F: separate app-chrome theme (`CanvasTheme.chrome`).
///
/// Chrome is editor-only and never leaks into export; null = chrome follows
/// the main (components) theme. Schema entry point is [checkContract]
/// (there is no `validateAiDoc` in screen_doc_schema.dart).
Map<String, dynamic> _docRaw(Map<String, dynamic> theme) =>
    <String, dynamic>{
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Go', 'variant': 'primary'},
          ],
        },
      ],
      'theme': theme,
      'meta': {'title': 'T', 'brief': 'chrome fixture'},
    };

Map<String, dynamic> _themeRaw() => <String, dynamic>{
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    };

void main() {
  group('chrome theme', () {
    test('round-trip with chrome set', () {
      const theme = CanvasTheme(
        paletteKey: 'slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
        chrome: CanvasTheme(
          paletteKey: 'indigo',
          dark: true,
          shape: 'pill',
          motion: 'expressive',
        ),
      );
      final back = CanvasTheme.fromJson(
        jsonDecode(jsonEncode(theme.toJson())) as Map<String, dynamic>,
      );
      expect(back.chrome, isNotNull);
      expect(back.chrome!.paletteKey, 'indigo');
      expect(back.chrome!.dark, isTrue);
      expect(back.chrome!.shape, 'pill');
      expect(back.chrome!.motion, 'expressive');
      expect(back.effectiveChrome.paletteKey, 'indigo');
      // Full doc round-trip preserves chrome.
      final doc = ScreenDoc.fromJson(_docRaw(theme.toJson()));
      final docBack = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(docBack.theme.chrome!.paletteKey, 'indigo');
      expect(docBack.theme.effectiveChrome.dark, isTrue);
    });

    test('round-trip without chrome has NO chrome key', () {
      const theme = CanvasTheme(
        paletteKey: 'slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
      );
      expect(theme.toJson().containsKey('chrome'), isFalse);
      final back = CanvasTheme.fromJson(
        jsonDecode(jsonEncode(theme.toJson())) as Map<String, dynamic>,
      );
      expect(back.chrome, isNull);
      expect(identical(back.effectiveChrome, back), isTrue);
    });

    test('old 4-key JSON loads with chrome null + effectiveChrome is self',
        () {
      final theme =
          CanvasTheme.fromJson(_themeRaw()..remove('chrome'));
      expect(theme.chrome, isNull);
      expect(theme.effectiveChrome.paletteKey, 'slate');
      expect(identical(theme.effectiveChrome, theme), isTrue);
      final doc = ScreenDoc.fromJson(_docRaw(_themeRaw()));
      expect(doc.theme.chrome, isNull);
      expect(identical(doc.theme.effectiveChrome, doc.theme), isTrue);
    });

    test('malformed chrome (non-object) throws + schema problem', () {
      final raw = _themeRaw()..['chrome'] = 'nope';
      expect(
        () => CanvasTheme.fromJson(raw),
        throwsA(isA<FormatException>()),
      );
      final problems = checkContract(_docRaw(Map.of(raw)));
      expect(
        problems.any((p) => p.contains('theme.chrome')),
        isTrue,
      );
    });

    test('malformed chrome (missing keys) throws + schema problem', () {
      final raw = _themeRaw()..['chrome'] = {'paletteKey': 'slate'};
      expect(
        () => CanvasTheme.fromJson(
          Map<String, dynamic>.from(raw),
        ),
        throwsA(isA<FormatException>()),
      );
      final problems = checkContract(
        _docRaw(Map<String, dynamic>.from(raw)),
      );
      expect(
        problems.any((p) => p.contains('theme.chrome')),
        isTrue,
      );
    });

    test('missing chrome key is schema-OK', () {
      expect(checkContract(_docRaw(_themeRaw())), isEmpty);
    });

    test('nested chrome-of-chrome forced null', () {
      final raw = _themeRaw()
        ..['chrome'] = {
          'paletteKey': 'indigo',
          'dark': true,
          'shape': 'pill',
          'motion': 'expressive',
          'chrome': {
            'paletteKey': 'emerald',
            'dark': false,
            'shape': 'sharp',
            'motion': 'standard',
          },
        };
      final theme =
          CanvasTheme.fromJson(Map<String, dynamic>.from(raw));
      expect(theme.chrome, isNotNull);
      expect(theme.chrome!.paletteKey, 'indigo');
      expect(theme.chrome!.chrome, isNull);
    });

    test('export describes components theme, ignores chrome', () {
      const plain = CanvasTheme(
        paletteKey: 'slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
      );
      const withChrome = CanvasTheme(
        paletteKey: 'slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
        chrome: CanvasTheme(
          paletteKey: 'emerald',
          dark: true,
          shape: 'sharp',
          motion: 'standard',
        ),
      );
      ScreenDoc docFor(CanvasTheme t) => ScreenDoc(
            screens: const [
              CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
            ],
            nodes: const [
              CanvasNode(
                id: 'n1',
                screenId: 's1',
                x: 16,
                y: 96,
                items: [CanvasItem(id: 'i1', kind: 'button')],
              ),
            ],
            theme: t,
            meta: const DocMeta(title: 'T', brief: 'b'),
          );
      expect(
        buildPrompt(docFor(withChrome)),
        buildPrompt(docFor(plain)),
      );
    });
  });
}
