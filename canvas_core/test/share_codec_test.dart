import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _smallRaw() => {
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's9', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Pay',
              'variant': 'primary',
              'action': {'to': 's9', 'transition': 'slide'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Checkout', 'brief': '2-screen pay flow'},
    };

/// Deterministic pseudo-random printable string (avoids highly repetitive
/// input so the over-limit test cannot pass by accident).
String _noise(int seed, int length) {
  var s = seed;
  final codes = List<int>.generate(length, (_) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return 33 + (s % 94);
  });
  return String.fromCharCodes(codes);
}

ScreenDoc _hugeDoc() {
  final screens = [
    {'id': 's1', 'name': 'Big', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
  ];
  final nodes = List<Map<String, dynamic>>.generate(
    100,
    (i) => {
      'id': 'n$i',
      'screenId': 's1',
      'x': (i * 8.0),
      'y': (i * 4.0),
      'items': [
        {'id': 'i$i', 'kind': 'button', 'label': _noise(i + 1, 150)},
      ],
    },
  );
  return ScreenDoc.fromJson({
    'screens': screens,
    'nodes': nodes,
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard'
    },
    'meta': {'title': 'Huge', 'brief': _noise(999, 9000)},
  });
}

void main() {
  test('roundtrip preserves screens, nodes, theme', () {
    final doc = ScreenDoc.fromJson(_smallRaw());
    final link = encode(doc);
    expect(link, startsWith('#d='));
    expect(link.length, lessThanOrEqualTo(kShareMaxUrlLength));

    final back = decode(link);
    expect(back.screens, hasLength(2));
    expect(back.nodes.single.screenId, 's1');
    expect(back.nodes.single.items.single.action?.to, 's9');
    expect(back.theme.paletteKey, 'slate');
    expect(back.meta.title, 'Checkout');
  });

  test('decode rejects garbage and bad shapes', () {
    expect(() => decode('not-a-link'), throwsFormatException);
    expect(() => decode('#d=!!!not-base64!!!'), throwsFormatException);

    final badShape = '#d=' + base64Url.encode(utf8.encode('{"nope":true}'));
    expect(() => decode(badShape), throwsFormatException);
  });

  test('decode rejects dangling action refs', () {
    final raw = _smallRaw();
    final items =
        ((raw['nodes'] as List).single as Map)['items'] as List<dynamic>;
    (items.single as Map<String, dynamic>)['action'] = {
      'to': 'missing',
      'transition': 'slide'
    };
    final link = encode(ScreenDoc.fromJson(raw));
    expect(
      () => decode(link),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('dangling action i1 -> missing screen missing'),
        ),
      ),
    );
  });

  test('decode rejects payloads over 200KB', () {
    final raw = _smallRaw();
    raw['nodes'] = [];
    (raw['meta'] as Map<String, dynamic>)['brief'] = 'a' * (210 * 1024);
    final link = '#d=' + base64Url.encode(utf8.encode(jsonEncode(raw)));
    expect(
      () => decode(link),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('too large'),
        ),
      ),
    );
  });

  test('encode throws StateError when URL exceeds 6000 chars', () {
    final doc = _hugeDoc();
    expect(
      () => encode(doc),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'doc too large for link; use file export',
        ),
      ),
    );
  });
}
