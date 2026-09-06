/// Track U2 node sizing: model round-trip, backward compatibility, and the
/// responsive-choice pin (v1 fixed sizes + `hiddenOn` only — per-tier sizes
/// deferred; see the sizing table on [CanvasNode]).
library;

import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _nodeRaw({
  Object? w = _absent,
  Object? h = _absent,
  Map<String, dynamic>? extra,
}) => {
      'id': 'n1',
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'items': [
        {'id': 'i1', 'kind': 'button', 'label': 'Go'},
      ],
      if (w != _absent) 'w': w,
      if (h != _absent) 'h': h,
      ...?extra,
    };

/// Sentinel distinguishing "key absent" from "key present with null".
const _absent = Object();

CanvasNode _node(Map<String, dynamic> raw) => CanvasNode.fromJson(raw);

void main() {
  group('CanvasNode w/h defaults', () {
    test('const constructor defaults to null (auto)', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
      );
      expect(node.w, isNull);
      expect(node.h, isNull);
    });

    test('missing JSON keys parse to null (backward compatible)', () {
      final node = _node(_nodeRaw());
      expect(node.w, isNull);
      expect(node.h, isNull);
    });

    test('explicit nulls parse to null', () {
      final node = _node(_nodeRaw(w: null, h: null));
      expect(node.w, isNull);
      expect(node.h, isNull);
    });

    test('doubles parse verbatim', () {
      final node = _node(_nodeRaw(w: 120.5, h: 80.0));
      expect(node.w, 120.5);
      expect(node.h, 80.0);
    });

    test('ints parse as doubles (JSON-doubles trap, like gap)', () {
      final node = _node(_nodeRaw(w: 120, h: 80));
      expect(node.w, 120.0);
      expect(node.h, 80.0);
      expect(node.w, isA<double>());
    });
  });

  group('CanvasNode w/h toJson', () {
    test('omits nulls so unsized docs round-trip byte-identically', () {
      final json = _node(_nodeRaw()).toJson();
      expect(json.containsKey('w'), isFalse);
      expect(json.containsKey('h'), isFalse);
      final encoded = jsonEncode(json);
      expect(encoded, isNot(contains('"w"')));
      expect(encoded, isNot(contains('"h"')));
    });

    test('emits non-nulls and round-trips', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 1,
        y: 2,
        items: [],
        w: 120.0,
        h: 80.0,
      );
      final json = node.toJson();
      expect(json['w'], 120.0);
      expect(json['h'], 80.0);
      final back = CanvasNode.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back.w, 120.0);
      expect(back.h, 80.0);
    });

    test('partial sizes round-trip (w-only, h-only)', () {
      final wOnly = _node(_nodeRaw(w: 200));
      expect(wOnly.w, 200.0);
      expect(wOnly.h, isNull);
      expect(wOnly.toJson().containsKey('h'), isFalse);
      final hOnly = _node(_nodeRaw(h: 64));
      expect(hOnly.w, isNull);
      expect(hOnly.h, 64.0);
      expect(hOnly.toJson().containsKey('w'), isFalse);
    });

    test('full doc round-trip preserves sizes', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'S', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          _nodeRaw(w: 120, h: 80),
          _nodeRaw()..['id'] = 'n2',
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'T', 'brief': ''},
      });
      final back = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(back.nodes.singleWhere((n) => n.id == 'n1').w, 120.0);
      expect(back.nodes.singleWhere((n) => n.id == 'n1').h, 80.0);
      expect(back.nodes.singleWhere((n) => n.id == 'n2').w, isNull);
    });
  });

  group('responsive choice (v1 fixed + hiddenOn, per-tier deferred)', () {
    test('w/h keys inside breakpointValues stay inert item-prop overrides', () {
      // The deferred design: tier maps merge into ITEM props at every merge
      // site, so reserved-looking keys there must NOT resize the node. This
      // pins the decision — a future per-tier-sizes batch changes this test.
      final node = _node(
        _nodeRaw(
          extra: {
            'breakpointValues': {
              'tablet': {'w': 200, 'h': 100},
            },
          },
        ),
      );
      expect(node.w, isNull);
      expect(node.h, isNull);
      expect(node.breakpointValues['tablet'], {'w': 200, 'h': 100});
    });

    test('fixed sizes coexist with hiddenOn (tier-independent)', () {
      final node = _node(
        _nodeRaw(
          w: 120,
          extra: {
            'hiddenOn': ['mobile'],
          },
        ),
      );
      expect(node.w, 120.0);
      expect(node.hiddenOn, {'mobile'});
    });
  });

  group('size bound consts', () {
    test('documented UI bounds are sane and ordered', () {
      expect(kMinNodeSize, 48.0);
      expect(kMaxNodeWidth, 1440.0);
      expect(kMaxNodeHeight, 709.0);
      expect(kMinNodeSize, lessThan(kMaxNodeWidth));
      expect(kMinNodeSize, lessThan(kMaxNodeHeight));
    });
  });
}
