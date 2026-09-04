/// BYO-key direct-to-provider AI client: brief in, validated [ScreenDoc] out.
///
/// There is no server in between: the author's own key is POSTed straight to
/// an OpenAI-compatible `/chat/completions` endpoint (or Anthropic's
/// `/v1/messages` when [AiSettings.provider] is `'claude'`), mirroring the
/// m3e `complete` helper. Every call uses the fixed [buildSystemPrompt] and
/// the fixed generation shape; the reply text goes through [parseAiJson] so
/// invalid JSON never reaches codegen. The key lives in [PrefsAiStore] only
/// and is never logged. Pure Dart (only `package:http`), no Flutter imports.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:canvas_core/canvas_core.dart';

import 'ai_parse.dart';

/// Settings for direct-to-provider AI calls.
class AiSettings {
  /// `'openai'` (or any OpenAI-compatible endpoint) or `'claude'`.
  final String provider;
  final String baseUrl;
  final String model;

  /// BYO key, stored on-device only via [PrefsAiStore]. Never logged.
  final String apiKey;

  const AiSettings({
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  /// Tolerant decode: unknown/missing fields fall back to openai defaults.
  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
        provider: json['provider'] as String? ?? 'openai',
        baseUrl: json['baseUrl'] as String? ?? '',
        model: json['model'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'baseUrl': baseUrl,
        'model': model,
        'apiKey': apiKey,
      };
}

/// Minimal key/value string storage port, defined locally in `ai/` so this
/// client stays independent of the canvas store's `persistence.dart`.
abstract class PrefsPort {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
}

/// Loads/saves [AiSettings] under [storeKey] (`canvas:ai`).
class PrefsAiStore {
  static const String storeKey = 'canvas:ai';

  static const AiSettings defaults = AiSettings(
    provider: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    model: '',
    apiKey: '',
  );

  final PrefsPort prefs;

  const PrefsAiStore(this.prefs);

  /// Loads settings; missing/corrupt entries fall back to [defaults].
  Future<AiSettings> load() async {
    final raw = await prefs.read(storeKey);
    if (raw == null || raw.isEmpty) return defaults;
    try {
      return AiSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save(AiSettings settings) =>
      prefs.write(storeKey, jsonEncode(settings.toJson()));
}

/// Fixed system prompt: ScreenDoc contract + JSON-only rule.
///
/// Deterministic — identical for every call — so golden prompt→doc pairs
/// stay reproducible.
String buildSystemPrompt() => '''
You help a designer sketch a Flutter phone app. The author describes screens; you emit the design.

${describeAiContract()}''';

/// Generates a validated [ScreenDoc] for [brief] via the configured provider.
///
/// Throws [AiException] on transport failures (non-2xx, empty model, text
/// extraction failure) and [AiParseException] when the reply is not a valid
/// doc. Error messages never include the API key.
Future<ScreenDoc> generateScreen({
  required String brief,
  required AiSettings settings,
  required http.Client client,
}) async {
  final model = settings.model.trim();
  if (model.isEmpty) {
    throw const AiException('ai model is empty; set it in AI settings');
  }
  final base = settings.baseUrl.trim();
  if (base.isEmpty) {
    throw const AiException('ai base URL is empty; set it in AI settings');
  }
  final system = buildSystemPrompt();
  final user = 'Design a ScreenDoc for this brief:\n$brief';
  final text = settings.provider == 'claude'
      ? await _completeClaude(client, base, model, settings.apiKey, system, user)
      : await _completeOpenAi(
          client, base, model, settings.apiKey, system, user);
  return parseAiJson(text);
}

/// One OpenAI-compatible round trip: fixed messages, temperature 0.2.
Future<String> _completeOpenAi(
  http.Client client,
  String base,
  String model,
  String apiKey,
  String system,
  String user,
) async {
  final key = apiKey.trim();
  late final http.Response res;
  try {
    res = await client.post(
      Uri.parse('${_trimSlash(base)}/chat/completions'),
      headers: {
        'content-type': 'application/json',
        if (key.isNotEmpty) 'authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'temperature': 0.2,
        'max_tokens': 4000,
      }),
    );
  } catch (e) {
    throw AiException('ai request failed: $e');
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw AiException('ai request failed: ${res.statusCode} ${_short(res.body)}');
  }
  late final Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (e) {
    throw AiException('ai response was not JSON: $e');
  }
  final choices = body['choices'];
  Object? content;
  if (choices is List && choices.isNotEmpty) {
    final message = (choices.first as Map?)?['message'];
    content = message is Map ? message['content'] : null;
  }
  if (content is String) return content;
  if (content is List) {
    return content.map((p) => (p as Map)['text']?.toString() ?? '').join();
  }
  throw const AiException('ai response had no text content');
}

/// One Anthropic round trip (BYO key in `x-api-key`, version pinned).
Future<String> _completeClaude(
  http.Client client,
  String base,
  String model,
  String apiKey,
  String system,
  String user,
) async {
  late final http.Response res;
  try {
    res = await client.post(
      Uri.parse('${_trimSlash(base)}/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 4000,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
  } catch (e) {
    throw AiException('ai request failed: $e');
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw AiException('ai request failed: ${res.statusCode} ${_short(res.body)}');
  }
  late final Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (e) {
    throw AiException('ai response was not JSON: $e');
  }
  if (body['stop_reason'] == 'refusal') {
    throw const AiException('ai provider refused the request');
  }
  final blocks = body['content'] as List?;
  final text = (blocks ?? [])
      .where((b) => (b as Map)['type'] == 'text')
      .map((b) => (b as Map)['text']?.toString() ?? '')
      .join();
  if (text.isEmpty) throw const AiException('ai response had no text content');
  return text;
}

String _trimSlash(String url) => url.replaceAll(RegExp(r'/+$'), '');

/// Truncates provider error bodies so failures stay readable.
String _short(String s) => s.length <= 300 ? s : '${s.substring(0, 300)}…';
