/// Documents and validates the LLM output contract for AI ScreenDoc generation.
///
/// The model must emit a single JSON object shaped like a [ScreenDoc]:
/// top-level `screens` / `nodes` / `theme` / `meta`, where every node item
/// carries `id` + `kind` and every `action.transition` is one of
/// [kAiAllowedTransitions]. Documents are capped at [kAiMaxNodes] nodes and
/// [kAiMaxRawBytes] bytes so invalid output never reaches codegen.
/// [checkContract] enforces all of this without throwing: it returns
/// human-readable violations (empty means OK).
library;

import 'dart:convert';

/// Allowed `action.transition` values in AI-emitted ScreenDocs.
const Set<String> kAiAllowedTransitions = {
  'slide',
  'slideLeft',
  'slideUp',
  'slideDown',
  'fade',
  'expand',
  'none',
};

/// Required top-level keys of an AI-emitted ScreenDoc.
const List<String> kAiRequiredTopKeys = ['screens', 'nodes', 'theme', 'meta'];

/// Maximum number of nodes an AI-emitted doc may carry.
const int kAiMaxNodes = 50;

/// Maximum size of an AI-emitted doc (200 KB, same budget as share links).
const int kAiMaxRawBytes = 200 * 1024;

/// The fixed contract block embedded in the AI system prompt.
///
/// Single source of truth for what the model may emit: top-level keys, the
/// minimal kind catalog (2-3 props each), two valid `action` examples, the
/// allowed transitions, the size caps, and the JSON-only rule.
String describeAiContract() => '''
Top-level keys (all required): screens, nodes, theme, meta.
- screens: [{"id": "s1", "name": "Pay", "x": 0, "y": 0, "bg": "surface"}]
- nodes: [{"id": "n1", "screenId": "s1", "x": 16, "y": 96, "items": [...]}]
- theme: {"paletteKey": "slate", "dark": false, "shape": "rounded", "motion": "standard"}
- meta: {"title": "Checkout", "brief": "<the user brief>"}

Kind catalog (every item needs "id" and "kind"; use only these props):
- button: label (string), variant (primary|secondary|outline|ghost|destructive|link), disabled (bool)
- card: title (string), description (string), showFooter (bool)
- input: placeholder (string), label (string), disabled (bool)
- badge: label (string), variant (primary|secondary|outline|destructive)
- switch: label (string), value (bool), disabled (bool)

Navigation actions (optional per item; "to" must match a screen id):
- {"id": "i1", "kind": "button", "label": "Pay", "variant": "primary", "action": {"to": "s2", "transition": "slide"}}
- {"id": "i9", "kind": "button", "label": "Back", "variant": "ghost", "action": {"to": "s1", "transition": "fade"}}

Allowed transitions: ${kAiAllowedTransitions.join('|')}.
Limits: at most $kAiMaxNodes nodes, whole document under ${kAiMaxRawBytes ~/ 1024}KB.

Reply with the JSON object only: no prose, no markdown fences.''';

/// Validates decoded model output against the AI ScreenDoc contract.
///
/// Returns human-readable violations (empty means OK). Never throws:
/// every shape mismatch, including wrong types, becomes a violation string
/// so [parseAiJson] can report ALL problems at once.
List<String> checkContract(Map<String, dynamic> json) {
  final problems = <String>[];

  for (final key in kAiRequiredTopKeys) {
    if (!json.containsKey(key)) {
      problems.add('missing required top-level key: "$key"');
    }
  }

  final screens = json['screens'];
  if (screens != null) {
    if (screens is! List) {
      problems.add('"screens" must be an array');
    } else {
      for (var i = 0; i < screens.length; i++) {
        final screen = screens[i];
        if (screen is! Map) {
          problems.add('screens[$i] must be an object');
          continue;
        }
        for (final key in ['id', 'name']) {
          final value = screen[key];
          if (value is! String || value.isEmpty) {
            problems.add('screens[$i] is missing required key "$key"');
          }
        }
      }
    }
  }

  final nodes = json['nodes'];
  if (nodes != null) {
    if (nodes is! List) {
      problems.add('"nodes" must be an array');
    } else {
      if (nodes.length > kAiMaxNodes) {
        problems.add('too many nodes: ${nodes.length} (max $kAiMaxNodes)');
      }
      for (var i = 0; i < nodes.length; i++) {
        problems.addAll(_checkNode(nodes[i], i));
      }
    }
  }

  final theme = json['theme'];
  if (theme != null) {
    if (theme is! Map) {
      problems.add('"theme" must be an object');
    } else {
      for (final key in ['paletteKey', 'dark', 'shape', 'motion']) {
        if (!theme.containsKey(key)) {
          problems.add('theme is missing required key "$key"');
        }
      }
    }
  }

  final meta = json['meta'];
  if (meta != null) {
    if (meta is! Map) {
      problems.add('"meta" must be an object');
    } else {
      for (final key in ['title', 'brief']) {
        if (!meta.containsKey(key)) {
          problems.add('meta is missing required key "$key"');
        }
      }
    }
  }

  try {
    final bytes = utf8.encode(jsonEncode(json)).length;
    if (bytes > kAiMaxRawBytes) {
      problems.add(
        'document too large: $bytes bytes (max $kAiMaxRawBytes)',
      );
    }
  } catch (_) {
    problems.add('document is not JSON-encodable');
  }

  return problems;
}

/// Validates one `nodes[i]` entry (node keys, items, and actions).
List<String> _checkNode(Object? node, int index) {
  final problems = <String>[];
  if (node is! Map) {
    return ['nodes[$index] must be an object'];
  }
  for (final key in ['id', 'screenId']) {
    final value = node[key];
    if (value is! String || value.isEmpty) {
      problems.add('nodes[$index] is missing required key "$key"');
    }
  }
  final items = node['items'];
  if (items == null) {
    problems.add('nodes[$index] is missing required key "items"');
    return problems;
  }
  if (items is! List) {
    return [...problems, 'nodes[$index].items must be an array'];
  }
  for (var j = 0; j < items.length; j++) {
    problems.addAll(_checkItem(items[j], index, j));
  }
  return problems;
}

/// Validates one `nodes[i].items[j]` entry (id/kind + action transition).
List<String> _checkItem(Object? item, int nodeIndex, int itemIndex) {
  final ctx = 'nodes[$nodeIndex].items[$itemIndex]';
  if (item is! Map) {
    return ['$ctx must be an object'];
  }
  final problems = <String>[];
  for (final key in ['id', 'kind']) {
    final value = item[key];
    if (value is! String || value.isEmpty) {
      problems.add('$ctx is missing required key "$key"');
    }
  }
  final action = item['action'];
  if (action != null) {
    if (action is! Map) {
      problems.add('$ctx.action must be an object');
    } else {
      final to = action['to'];
      if (to is! String || to.isEmpty) {
        problems.add('$ctx.action is missing required key "to"');
      }
      final transition = action['transition'];
      if (transition is! String ||
          !kAiAllowedTransitions.contains(transition)) {
        problems.add(
          '$ctx.action.transition "$transition" is not one of: '
          '${kAiAllowedTransitions.join(', ')}',
        );
      }
    }
  }
  return problems;
}
