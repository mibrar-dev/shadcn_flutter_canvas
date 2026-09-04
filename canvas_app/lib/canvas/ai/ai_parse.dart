/// Parses raw LLM output into a validated [ScreenDoc].
///
/// Repair strategy (ported from the m3e `parseJsonObject` helper):
/// strip ``` fences, then extract the FIRST balanced `{...}` block so
/// surrounding prose never reaches `jsonDecode`. The decoded map goes
/// through [checkContract], [ScreenDoc.fromJson], and [ScreenDoc.validateRefs]
/// with every problem collected. Either a fully valid doc is returned or
/// an [AiParseException] listing ALL problems is thrown — never a partial doc.
library;

import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';

/// Base failure for the AI ScreenDoc pipeline.
///
/// [AiParseException] extends this for malformed model output; the HTTP
/// client in `ai_client.dart` reuses it for transport failures so callers
/// only catch one type.
class AiException implements Exception {
  /// Human-readable failure; never contains the API key.
  final String message;

  const AiException(this.message);

  @override
  String toString() => 'AiException: $message';
}

/// Thrown by [parseAiJson] when model output cannot become a valid doc.
///
/// [problems] lists every violation found (contract, shape, dangling refs);
/// [message] joins them so a single catch surfaces the full report.
class AiParseException extends AiException {
  final List<String> problems;

  AiParseException(this.problems) : super(problems.join('; '));
}

/// Extracts the FIRST balanced `{...}` block from [text].
///
/// ``` fences are stripped first so fenced replies parse; brace matching is
/// string-aware (braces inside `"..."` and `\` escapes don't count).
/// Returns null when there is no balanced object.
String? extractJsonObject(String text) {
  final cleaned = text.replaceAll('```', '');
  final start = cleaned.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < cleaned.length; i++) {
    final c = cleaned[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
    } else if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return cleaned.substring(start, i + 1);
    }
  }
  return null;
}

/// Parses raw model output into a fully validated [ScreenDoc].
///
/// Throws [AiParseException] (message lists ALL problems) when the text
/// holds no JSON object, the JSON is malformed, the contract fails, the
/// shape is wrong, or action refs dangle. Never returns a partial doc.
ScreenDoc parseAiJson(String text) {
  final block = extractJsonObject(text);
  if (block == null) {
    throw AiParseException(['no JSON object found in model output']);
  }
  late final Object? decoded;
  try {
    decoded = jsonDecode(block);
  } catch (e) {
    throw AiParseException(['model output is not valid JSON: $e']);
  }
  if (decoded is! Map<String, dynamic>) {
    throw AiParseException(['model output JSON must be an object']);
  }

  final problems = <String>[...checkContract(decoded)];
  ScreenDoc? doc;
  try {
    doc = ScreenDoc.fromJson(decoded);
  } catch (e) {
    problems.add('invalid ScreenDoc shape: $e');
  }
  if (doc != null) {
    problems.addAll(doc.validateRefs());
  }
  if (problems.isNotEmpty) {
    throw AiParseException(problems);
  }
  return doc!;
}
