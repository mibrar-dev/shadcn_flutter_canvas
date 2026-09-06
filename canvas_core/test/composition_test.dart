import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

/// C0 composition helpers: `childrenOf` / `descendants` / `isAncestorOf` /
/// `validateNesting` over generalized `parentId` nesting (any node may
/// parent — see `canvas/COMPOSITION.md`).
CanvasNode _node(
  String id, {
  String screenId = 's1',
  String? parentId,
  bool isRow = false,
}) =>
    CanvasNode(
      id: id,
      screenId: screenId,
      x: 0,
      y: 0,
      items: const [],
      parentId: parentId,
      isRow: isRow,
    );

ScreenDoc _doc(
  List<CanvasNode> nodes, {
  List<String> screens = const ['s1'],
}) =>
    ScreenDoc(
      screens: [
        for (final s in screens)
          CanvasScreen(id: s, name: s, x: 0, y: 0, bg: 'surface'),
      ],
      nodes: nodes,
      theme: const CanvasTheme(
        paletteKey: 'slate',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
      ),
      meta: const DocMeta(title: 't', brief: 'b'),
    );

List<String> _ids(List<CanvasNode> nodes) =>
    [for (final n in nodes) n.id];

void main() {
  group('childrenOf', () {
    test('returns direct children only, in doc order', () {
      final doc = _doc([
        _node('r1', isRow: true),
        _node('c2', parentId: 'r1'),
        _node('c1', parentId: 'r1'),
        _node('g1', parentId: 'c1'),
        _node('root2'),
      ]);
      expect(_ids(childrenOf(doc, 'r1')), ['c2', 'c1']);
      expect(_ids(childrenOf(doc, 'c1')), ['g1']);
      expect(childrenOf(doc, 'c2'), isEmpty);
      expect(childrenOf(doc, 'root2'), isEmpty);
    });

    test('non-row nodes may parent (generalized nesting)', () {
      final doc = _doc([
        _node('card'),
        _node('input', parentId: 'card'),
        _node('button', parentId: 'card'),
      ]);
      expect(_ids(childrenOf(doc, 'card')), ['input', 'button']);
    });

    test('unknown node and empty doc yield empty', () {
      final doc = _doc([_node('a')]);
      expect(childrenOf(doc, 'nope'), isEmpty);
      expect(childrenOf(_doc(const []), 'a'), isEmpty);
    });
  });

  group('descendants', () {
    test('deep chain resolves transitively in breadth-first doc order', () {
      final doc = _doc([
        _node('a'),
        _node('b', parentId: 'a'),
        _node('c', parentId: 'b'),
        _node('d', parentId: 'c'),
      ]);
      expect(_ids(descendants(doc, 'a')), ['b', 'c', 'd']);
      expect(_ids(descendants(doc, 'b')), ['c', 'd']);
      expect(_ids(descendants(doc, 'd')), isEmpty);
    });

    test('branching subtree fans out level by level', () {
      final doc = _doc([
        _node('r1', isRow: true),
        _node('c1', parentId: 'r1'),
        _node('c2', parentId: 'r1'),
        _node('g1', parentId: 'c1'),
        _node('g2', parentId: 'c2'),
      ]);
      expect(
        _ids(descendants(doc, 'r1')),
        ['c1', 'c2', 'g1', 'g2'],
      );
    });

    test('ten-deep chain terminates with all descendants', () {
      final nodes = [_node('n0')];
      for (var i = 1; i < 10; i++) {
        nodes.add(_node('n$i', parentId: 'n${i - 1}'));
      }
      final found = _ids(descendants(_doc(nodes), 'n0'));
      expect(found, [for (var i = 1; i < 10; i++) 'n$i']);
    });

    test('cycle A->B->A terminates and excludes the start node', () {
      final doc = _doc([
        _node('a', parentId: 'b'),
        _node('b', parentId: 'a'),
      ]);
      expect(_ids(descendants(doc, 'a')), ['b']);
      expect(_ids(descendants(doc, 'b')), ['a']);
    });

    test('self-parent terminates with empty', () {
      final doc = _doc([_node('a', parentId: 'a')]);
      expect(descendants(doc, 'a'), isEmpty);
    });

    test('unknown node and empty doc yield empty', () {
      expect(descendants(_doc([_node('a')]), 'nope'), isEmpty);
      expect(descendants(_doc(const []), 'a'), isEmpty);
    });
  });

  group('isAncestorOf', () {
    test('direct and transitive ancestors', () {
      final doc = _doc([
        _node('a'),
        _node('b', parentId: 'a'),
        _node('c', parentId: 'b'),
      ]);
      expect(isAncestorOf(doc, 'a', 'b'), isTrue);
      expect(isAncestorOf(doc, 'a', 'c'), isTrue);
      expect(isAncestorOf(doc, 'b', 'c'), isTrue);
      expect(isAncestorOf(doc, 'b', 'a'), isFalse);
      expect(isAncestorOf(doc, 'c', 'a'), isFalse);
    });

    test('strict in acyclic docs: a node is not its own ancestor', () {
      final doc = _doc([_node('a')]);
      expect(isAncestorOf(doc, 'a', 'a'), isFalse);
    });

    test('self-parented node is its own ancestor by construction', () {
      final doc = _doc([_node('a', parentId: 'a')]);
      expect(isAncestorOf(doc, 'a', 'a'), isTrue);
    });

    test('cycle members are mutual ancestors', () {
      final doc = _doc([
        _node('a', parentId: 'b'),
        _node('b', parentId: 'a'),
      ]);
      expect(isAncestorOf(doc, 'a', 'b'), isTrue);
      expect(isAncestorOf(doc, 'b', 'a'), isTrue);
    });

    test('unknown ids and dangling edges yield false', () {
      final doc = _doc([
        _node('a', parentId: 'ghost'),
        _node('b'),
      ]);
      expect(isAncestorOf(doc, 'ghost', 'a'), isFalse);
      expect(isAncestorOf(doc, 'a', 'nope'), isFalse);
      expect(isAncestorOf(doc, 'nope', 'a'), isFalse);
      expect(isAncestorOf(_doc(const []), 'a', 'b'), isFalse);
    });
  });

  group('validateNesting', () {
    test('clean flat and row docs validate with no problems', () {
      final doc = _doc([
        _node('r1', isRow: true),
        _node('c1', parentId: 'r1'),
        _node('c2', parentId: 'r1'),
        _node('leaf'),
      ]);
      expect(validateNesting(doc), isEmpty);
    });

    test('deep valid nesting (rows and non-rows) is fine', () {
      final doc = _doc([
        _node('card'),
        _node('row', parentId: 'card', isRow: true),
        _node('button', parentId: 'row'),
        _node('input', parentId: 'card'),
      ]);
      expect(validateNesting(doc), isEmpty);
    });

    test('unknown parent message is stable', () {
      final doc = _doc([_node('a', parentId: 'ghost')]);
      expect(
        validateNesting(doc),
        ['unknown parent ghost for node a'],
      );
    });

    test('cross-screen parent is refused with a stable message', () {
      final doc = _doc(
        [
          _node('a'),
          _node('b', screenId: 's2', parentId: 'a'),
        ],
        screens: ['s1', 's2'],
      );
      expect(
        validateNesting(doc),
        ['cross-screen parent a for node b'],
      );
    });

    test('self-parent is refused with a stable message', () {
      final doc = _doc([_node('a', parentId: 'a')]);
      expect(validateNesting(doc), ['self-parent a']);
    });

    test('two-cycle A->B->A reports both members in doc order', () {
      final doc = _doc([
        _node('a', parentId: 'b'),
        _node('b', parentId: 'a'),
      ]);
      expect(
        validateNesting(doc),
        [
          'cycle: node a is its own ancestor',
          'cycle: node b is its own ancestor',
        ],
      );
    });

    test('three-cycle reports every member once', () {
      final doc = _doc([
        _node('a', parentId: 'c'),
        _node('b', parentId: 'a'),
        _node('c', parentId: 'b'),
      ]);
      expect(
        validateNesting(doc),
        [
          'cycle: node a is its own ancestor',
          'cycle: node b is its own ancestor',
          'cycle: node c is its own ancestor',
        ],
      );
    });

    test('branch below a cycle is fine; only cycle members report', () {
      final doc = _doc([
        _node('a', parentId: 'b'),
        _node('b', parentId: 'a'),
        _node('leaf', parentId: 'a'),
      ]);
      expect(
        validateNesting(doc),
        [
          'cycle: node a is its own ancestor',
          'cycle: node b is its own ancestor',
        ],
      );
    });

    test('multiple problems stay in doc order, one per node', () {
      final doc = _doc([
        _node('ok'),
        _node('bad1', parentId: 'ghost'),
        _node('bad2', parentId: 'bad2'),
      ]);
      expect(
        validateNesting(doc),
        [
          'unknown parent ghost for node bad1',
          'self-parent bad2',
        ],
      );
    });

    test('empty doc validates clean', () {
      expect(validateNesting(_doc(const [])), isEmpty);
    });

    test('row-into-leaf is allowed (kind-agnostic validator)', () {
      final doc = _doc([
        _node('leaf'),
        _node('row', parentId: 'leaf', isRow: true),
      ]);
      expect(validateNesting(doc), isEmpty);
    });
  });

  group('nesting round-trip', () {
    test('non-row parenting survives JSON round-trip (no schema change)', () {
      final doc = _doc([
        _node('card'),
        _node('input', parentId: 'card'),
      ]);
      final back = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(back.nodes.singleWhere((n) => n.id == 'input').parentId, 'card');
      expect(validateNesting(back), isEmpty);
    });
  });
}
