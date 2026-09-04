import 'dart:convert';
import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

void main() {
  test('ScreenDoc JSON roundtrip preserves screens, nodes, theme', () {
    const raw = {
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1', 'screenId': 's1', 'x': 16.0, 'y': 96.0,
          'items': [
            {
              'id': 'i1', 'kind': 'button', 'label': 'Pay',
              'variant': 'primary',
              'action': {'to': 's2', 'transition': 'slide'},
            },
          ],
        },
      ],
      'theme': {'paletteKey': 'slate', 'dark': false, 'shape': 'rounded', 'motion': 'standard'},
      'meta': {'title': 'Checkout', 'brief': '2-screen pay flow'},
    };
    final doc = ScreenDoc.fromJson(raw);
    final back = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
    expect(back['screens'], hasLength(1));
    expect((back['nodes'] as List).single['screenId'], 's1');
    expect((back['theme'] as Map)['paletteKey'], 'slate');
  });

  test('fromJson rejects unknown root shape', () {
    expect(() => ScreenDoc.fromJson({'nope': true}), throwsA(isA<FormatException>()));
  });
}
