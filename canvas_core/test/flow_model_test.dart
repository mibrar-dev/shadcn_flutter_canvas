import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

/// Flow-layout model delta: parentId/isRow/gap, migrateToFlow ordering,
/// hierarchical prompt briefs, and Column/Row codegen.
ScreenDoc _flowDoc() => ScreenDoc.fromJson(<String, dynamic>{
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'r1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [],
          'parentId': null,
          'isRow': true,
          'gap': 8.0,
        },
        {
          'id': 'c1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'A', 'variant': 'primary'},
          ],
          'parentId': 'r1',
          'isRow': false,
          'gap': 8.0,
        },
        {
          'id': 'c2',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'B', 'variant': 'primary'},
          ],
          'parentId': 'r1',
          'isRow': false,
          'gap': 8.0,
        },
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 200.0,
          'items': [
            {'id': 'i3', 'kind': 'button', 'label': 'Top', 'variant': 'primary'},
          ],
          'parentId': null,
          'isRow': false,
          'gap': 8.0,
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Flow', 'brief': 'flow fixture'},
    });

/// Legacy doc: no flow keys at all, nodes listed out of (y, x) order.
Map<String, dynamic> _legacyRaw() => <String, dynamic>{
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16,
          'y': 200,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Low'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 100,
          'y': 50,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'High'},
          ],
        },
        {
          'id': 'n3',
          'screenId': 's1',
          'x': 16,
          'y': 50,
          'items': [
            {'id': 'i3', 'kind': 'button', 'label': 'HighLeft'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard'
      },
      'meta': {'title': 'Legacy', 'brief': 'absolute fixture'},
    };

void main() {
  group('flow consts', () {
    test('single-source spacing values', () {
      expect(kFlowScreenGap, 12.0);
      expect(kFlowScreenPadding, 16.0);
      expect(kFlowRowGapDefault, 8.0);
    });

    test('node gap defaults to the row-gap const', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
      );
      expect(node.parentId, isNull);
      expect(node.isRow, isFalse);
      expect(node.gap, kFlowRowGapDefault);
    });
  });

  group('model compat', () {
    test('fromJson fills flow defaults for old docs', () {
      final doc = ScreenDoc.fromJson(_legacyRaw());
      for (final node in doc.nodes) {
        expect(node.parentId, isNull);
        expect(node.isRow, isFalse);
        expect(node.gap, kFlowRowGapDefault);
      }
    });

    test('fromJson tolerates int gap (JSON-doubles trap)', () {
      final raw = _legacyRaw();
      ((raw['nodes'] as List).first as Map<String, dynamic>)['gap'] = 8;
      final doc = ScreenDoc.fromJson(raw);
      expect(doc.nodes.first.gap, 8.0);
    });

    test('toJson always writes parentId/isRow/gap and roundtrips', () {
      final doc = ScreenDoc.fromJson(_legacyRaw());
      final back =
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
      final node = (back['nodes'] as List).first as Map<String, dynamic>;
      expect(node.containsKey('parentId'), isTrue);
      expect(node.containsKey('isRow'), isTrue);
      expect(node.containsKey('gap'), isTrue);
      final again = ScreenDoc.fromJson(back);
      expect(again.nodes.first.parentId, isNull);
      expect(again.nodes.first.isRow, isFalse);
      expect(again.nodes.first.gap, 8.0);
    });

    test('roundtrip preserves explicit row structure', () {
      final doc = _flowDoc();
      final back = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      final row = back.nodes.firstWhere((n) => n.id == 'r1');
      expect(row.isRow, isTrue);
      expect(row.gap, 8.0);
      expect(
        back.nodes.where((n) => n.parentId == 'r1').map((n) => n.id),
        ['c1', 'c2'],
      );
    });
  });

  group('migrateToFlow', () {
    test('orders roots by (y, x) and preserves x/y values', () {
      final migrated = migrateToFlow(ScreenDoc.fromJson(_legacyRaw()));
      expect(
        [for (final n in migrated.nodes) n.id],
        ['n3', 'n2', 'n1'],
      );
      expect(
        [for (final n in migrated.nodes) [n.x, n.y]],
        [
          [16.0, 50.0],
          [100.0, 50.0],
          [16.0, 200.0],
        ],
      );
    });

    test('no auto-grouping: roots stay leaves, meta untouched', () {
      final doc = ScreenDoc.fromJson(_legacyRaw());
      final migrated = migrateToFlow(doc);
      for (final node in migrated.nodes) {
        expect(node.parentId, isNull);
        expect(node.isRow, isFalse);
      }
      expect(migrated.screens.single.id, 's1');
      expect(migrated.theme.paletteKey, 'slate');
      expect(migrated.meta.title, 'Legacy');
    });

    test('row children keep their relative order', () {
      final doc = _flowDoc();
      final scrambled = ScreenDoc(
        screens: doc.screens,
        nodes: [...doc.nodes.reversed],
        theme: doc.theme,
        meta: doc.meta,
      );
      final migrated = migrateToFlow(scrambled);
      expect(
        [for (final n in migrated.nodes) n.id],
        ['r1', 'n1', 'c2', 'c1'],
      );
    });
  });

  group('prompt hierarchy', () {
    test('row children indent one level under their row with gap noted', () {
      final prompt = buildPrompt(_flowDoc());
      final lines = prompt.split('\n');
      // Flow nodes carry no meaningful position: the row header and its
      // children print without the legacy "at (x, y)" suffix.
      final rowIdx = lines.indexWhere((l) => l == '- row (gap 8)');
      expect(rowIdx, isNot(-1));
      expect(lines[rowIdx + 1], '  - button "A" (variant primary)');
      expect(lines[rowIdx + 2], '  - button "B" (variant primary)');
    });

    test('leaf line format is unchanged', () {
      final prompt = buildPrompt(_flowDoc());
      expect(
        prompt,
        contains('- button "Top" (variant primary) at (16, 200)'),
      );
    });
  });

  group('codegen flow', () {
    test('screen root is Padding(16) > Column with gap separators', () {
      final out = buildSingleFile(_flowDoc(), const {});
      expect(out, contains('padding: const EdgeInsets.all(16),'));
      expect(out, contains('crossAxisAlignment: CrossAxisAlignment.start,'));
      expect(out, contains('const SizedBox(height: 12),'));
      // Wrapper order: Padding outside Column.
      expect(out.indexOf('Padding('), lessThan(out.indexOf('Column(')));
    });

    test('row nests inside the column with width separators', () {
      final out = buildSingleFile(_flowDoc(), const {});
      expect(out, contains('Row('));
      expect(out, contains('mainAxisAlignment: MainAxisAlignment.start,'));
      expect(out, contains('crossAxisAlignment: CrossAxisAlignment.center,'));
      expect(out, contains('const SizedBox(width: 8),'));
      // Nesting order: Column first, then Row, then row children labels.
      final columnIdx = out.indexOf('Column(');
      final rowIdx = out.indexOf('Row(');
      expect(rowIdx, greaterThan(columnIdx));
      expect(out.indexOf("'A'", rowIdx), greaterThan(rowIdx));
      expect(out.indexOf("'B'", rowIdx), greaterThan(rowIdx));
    });

    test('custom row gap is honored', () {
      final doc = _flowDoc();
      final wide = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'r1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: true,
                gap: 20.0,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final out = buildSingleFile(wide, const {});
      expect(out, contains('const SizedBox(width: 20),'));
    });
  });
}
