import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

/// Batch B: per-node responsive visibility promoted to the doc model
/// (`hiddenOn` / `breakpointValues` / `slots` on [CanvasNode]).
Map<String, dynamic> _docRaw(Map<String, dynamic> node) =>
    <String, dynamic>{
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [node],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Responsive', 'brief': 'visibility fixture'},
    };

Map<String, dynamic> _nodeRaw() => <String, dynamic>{
      'id': 'n1',
      'screenId': 's1',
      'x': 16.0,
      'y': 96.0,
      'items': [
        {'id': 'i1', 'kind': 'button', 'label': 'Pay', 'variant': 'primary'},
      ],
    };

void main() {
  group('responsive defaults', () {
    test('new fields default to empty', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
      );
      expect(node.hiddenOn, isEmpty);
      expect(node.breakpointValues, isEmpty);
      expect(node.slots, isEmpty);
    });
  });

  group('hiddenOn', () {
    test('round-trips and serializes as a sorted list', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
        hiddenOn: {'tablet', 'mobile'},
      );
      final json = node.toJson();
      expect(json['hiddenOn'], ['mobile', 'tablet']);
      final back = CanvasNode.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back.hiddenOn, {'mobile', 'tablet'});
    });

    test('unknown tier string throws FormatException', () {
      final raw = _nodeRaw()..['hiddenOn'] = ['mobile', 'watch'];
      expect(
        () => CanvasNode.fromJson(raw),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('breakpointValues/slots', () {
    test('round-trip preserves per-tier overrides', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
        breakpointValues: {
          'tablet': {'columns': 2, 'label': 'Hi'},
          'desktop': {'columns': 3},
        },
        slots: {'tablet': 'i2', 'desktop': 'i3'},
      );
      final back = CanvasNode.fromJson(
        jsonDecode(jsonEncode(node.toJson())) as Map<String, dynamic>,
      );
      expect(back.breakpointValues['tablet'], {'columns': 2, 'label': 'Hi'});
      expect(back.breakpointValues['desktop'], {'columns': 3});
      expect(back.slots, {'tablet': 'i2', 'desktop': 'i3'});
    });
  });

  group('backward compat', () {
    test('old JSON without the keys loads with empties', () {
      final doc = ScreenDoc.fromJson(_docRaw(_nodeRaw()));
      final node = doc.nodes.single;
      expect(node.hiddenOn, isEmpty);
      expect(node.breakpointValues, isEmpty);
      expect(node.slots, isEmpty);
    });

    test('old doc re-serializes with the new keys and reloads', () {
      final doc = ScreenDoc.fromJson(_docRaw(_nodeRaw()));
      final back = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      final node = back.nodes.single;
      expect(node.hiddenOn, isEmpty);
      expect(node.breakpointValues, isEmpty);
      expect(node.slots, isEmpty);
      final nodeJson =
          (back.toJson()['nodes'] as List).single as Map<String, dynamic>;
      expect(nodeJson.containsKey('hiddenOn'), isTrue);
      expect(nodeJson.containsKey('breakpointValues'), isTrue);
      expect(nodeJson.containsKey('slots'), isTrue);
    });

    test('flow/row fields still parse alongside the new keys', () {
      final raw = _nodeRaw()
        ..['parentId'] = null
        ..['isRow'] = true
        ..['gap'] = 8
        ..['mainAxis'] = 'center'
        ..['hiddenOn'] = ['desktop']
        ..['breakpointValues'] = {
          'mobile': {'columns': 1},
        }
        ..['slots'] = {'mobile': 'i1'};
      final node = CanvasNode.fromJson(raw);
      expect(node.isRow, isTrue);
      expect(node.gap, 8.0);
      expect(node.mainAxis, 'center');
      expect(node.hiddenOn, {'desktop'});
      expect(node.breakpointValues['mobile'], {'columns': 1});
      expect(node.slots, {'mobile': 'i1'});
    });
  });

  group('validateRefs', () {
    test('unaffected by the new fields', () {
      final node = _nodeRaw()
        ..['hiddenOn'] = ['mobile']
        ..['breakpointValues'] = {
          'tablet': {'columns': 2},
        }
        ..['slots'] = {'tablet': 'i1'}
        ..['items'] = [
          {
            'id': 'i1',
            'kind': 'button',
            'label': 'Go',
            'action': {'to': 'missing', 'transition': 'slide'},
          },
        ];
      final doc = ScreenDoc.fromJson(_docRaw(node));
      expect(
        doc.validateRefs(),
        ['dangling action i1 -> missing screen missing'],
      );
    });
  });
}
