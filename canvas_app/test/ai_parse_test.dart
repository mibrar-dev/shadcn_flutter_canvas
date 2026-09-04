import 'package:canvas_app/canvas/ai/ai_parse.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _validJson = '''
{"screens": [{"id": "s1", "name": "Pay", "x": 0, "y": 0, "bg": "surface"}],
"nodes": [{"id": "n1", "screenId": "s1", "x": 16, "y": 96,
"items": [{"id": "i1", "kind": "button", "label": "Pay", "variant": "primary"}]}],
"theme": {"paletteKey": "slate", "dark": false, "shape": "rounded", "motion": "standard"},
"meta": {"title": "Checkout", "brief": "2-screen pay flow"}}
''';

void main() {
  test('valid doc parses and passes the contract', () {
    final doc = parseAiJson(_validJson);
    expect(doc.screens.single.name, 'Pay');
    expect(doc.nodes.single.items.single.kind, 'button');
    expect(doc.meta.brief, '2-screen pay flow');
  });

  test('fenced and prose-wrapped reply parses', () {
    const wrapped = 'Here is your design:\n```json\n'
        '$_validJson'
        '```\nHope this helps!';
    final doc = parseAiJson(wrapped);
    expect(doc.screens, hasLength(1));
    expect(checkContract(doc.toJson()), isEmpty);
  });

  test('missing top-level key throws listing it', () {
    const missing = '''
{"screens": [], "nodes": [],
"meta": {"title": "T", "brief": "B"}}''';
    expect(
      () => parseAiJson(missing),
      throwsA(
        isA<AiParseException>().having(
          (e) => e.message,
          'message',
          contains('"theme"'),
        ),
      ),
    );
  });

  test('bad transition throws listing value and allowed set', () {
    final bad = _validJson.replaceFirst('"variant": "primary"',
        '"variant": "primary", "action": {"to": "s1", "transition": "zoom"}');
    expect(
      () => parseAiJson(bad),
      throwsA(
        isA<AiParseException>().having(
          (e) => e.problems.join(' '),
          'problems',
          allOf(contains('"zoom"'), contains('slide')),
        ),
      ),
    );
  });

  test('dangling action ref throws and never returns a partial doc', () {
    final dangling = _validJson.replaceFirst(
        '"variant": "primary"',
        '"variant": "primary", "action": {"to": "s9", "transition": "slide"}');
    // throwsA proves no ScreenDoc escapes: parse either returns valid or throws.
    expect(
      () => parseAiJson(dangling),
      throwsA(
        isA<AiParseException>().having(
          (e) => e.message,
          'message',
          contains('dangling action i1 -> missing screen s9'),
        ),
      ),
    );
  });
}
