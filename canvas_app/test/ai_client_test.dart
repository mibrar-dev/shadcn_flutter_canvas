import 'dart:convert';

import 'package:canvas_app/canvas/ai/ai_client.dart';
import 'package:canvas_app/canvas/ai/ai_parse.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fixture-shaped two-screen pay flow (mirrors two_screen_doc.dart).
const _twoScreenJson = '''
{"screens": [{"id": "s1", "name": "Pay", "x": 0, "y": 0, "bg": "surface"},
{"id": "s2", "name": "Done", "x": 420, "y": 0, "bg": "surface"}],
"nodes": [{"id": "n1", "screenId": "s1", "x": 16, "y": 96,
"items": [{"id": "i1", "kind": "button", "label": "Pay", "variant": "primary",
"action": {"to": "s2", "transition": "slide"}}]},
{"id": "n2", "screenId": "s2", "x": 16, "y": 96,
"items": [{"id": "i2", "kind": "card", "title": "Done", "description": "Payment complete"}]}],
"theme": {"paletteKey": "slate", "dark": false, "shape": "rounded", "motion": "standard"},
"meta": {"title": "Checkout", "brief": "2-screen pay flow"}}
''';

const _openAiSettings = AiSettings(
  provider: 'openai',
  baseUrl: 'https://api.openai.com/v1',
  model: 'test-model',
  apiKey: 'test-key',
);

/// In-memory PrefsPort for store tests.
class _MemoryPrefs implements PrefsPort {
  final _box = <String, String>{};

  @override
  Future<String?> read(String key) async => _box[key];

  @override
  Future<void> write(String key, String value) async {
    _box[key] = value;
  }
}

void main() {
  test('openai-shape success posts chat/completions and returns a doc', () async {
    late final http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': _twoScreenJson},
            },
          ],
        }),
        200,
      );
    });

    final doc = await generateScreen(
      brief: '2-screen pay flow',
      settings: _openAiSettings,
      client: client,
    );

    expect(seen.url.toString(), endsWith('/chat/completions'));
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['model'], 'test-model');
    expect(body['temperature'], 0.2);
    expect(body['max_tokens'], 4000);
    expect((body['messages'] as List).first['role'], 'system');
    expect(seen.headers['authorization'], 'Bearer test-key');
    expect(doc.screens, hasLength(2));
    expect(doc.nodes.singleWhere((n) => n.id == 'n1').screenId, 's1');
  });

  test('claude-shape success posts v1/messages with pinned version', () async {
    late final http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': _twoScreenJson},
          ],
          'stop_reason': 'end_turn',
        }),
        200,
      );
    });

    const claude = AiSettings(
      provider: 'claude',
      baseUrl: 'https://api.anthropic.com',
      model: 'test-model',
      apiKey: 'test-key',
    );
    final doc = await generateScreen(
      brief: '2-screen pay flow',
      settings: claude,
      client: client,
    );

    expect(seen.url.toString(), endsWith('/v1/messages'));
    expect(seen.headers['anthropic-version'], '2023-06-01');
    expect(seen.headers['x-api-key'], 'test-key');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['max_tokens'], 4000);
    expect(body['system'], isNotEmpty);
    expect(doc.meta.title, 'Checkout');
  });

  test('HTTP-500 throws AiException', () async {
    final client = MockClient((_) async => http.Response('boom', 500));
    expect(
      generateScreen(
        brief: '2-screen pay flow',
        settings: _openAiSettings,
        client: client,
      ),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('500'),
        ),
      ),
    );
  });

  test('golden pair: brief 2-screen pay flow yields a buildPrompt-able doc',
      () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': _twoScreenJson},
              },
            ],
          }),
          200,
        ));

    final doc = await generateScreen(
      brief: '2-screen pay flow',
      settings: _openAiSettings,
      client: client,
    );
    final prompt = buildPrompt(doc);
    expect(prompt, contains('## /pay (Pay)'));
    expect(prompt, contains('## /done (Done)'));
    expect(prompt, contains('Tapping Pay pushes /done.'));
  });

  test('PrefsAiStore roundtrips settings under canvas:ai', () async {
    final prefs = _MemoryPrefs();
    final store = PrefsAiStore(prefs);
    expect(await store.load(), isA<AiSettings>());
    await store.save(_openAiSettings);
    expect(prefs._box.keys, singleEquals(PrefsAiStore.storeKey));
    final back = await store.load();
    expect(back.provider, 'openai');
    expect(back.baseUrl, 'https://api.openai.com/v1');
    expect(back.model, 'test-model');
    expect(back.apiKey, 'test-key');
  });
}

/// Matches a single-element iterable holding [value].
Matcher singleEquals(Object? value) =>
    predicate<Iterable>((it) => it.length == 1 && it.single == value,
        'single element $value');
