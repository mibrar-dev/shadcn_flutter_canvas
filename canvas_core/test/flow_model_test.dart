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

  group('W3 container alignment model', () {
    test('new fields default to null', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 0,
        y: 0,
        items: [],
      );
      expect(node.mainAxis, isNull);
      expect(node.crossAxis, isNull);
      expect(node.expand, isNull);
      expect(node.flex, isNull);
    });

    test('fromJson fills nulls for old docs', () {
      final doc = ScreenDoc.fromJson(_legacyRaw());
      for (final node in doc.nodes) {
        expect(node.mainAxis, isNull);
        expect(node.crossAxis, isNull);
        expect(node.expand, isNull);
        expect(node.flex, isNull);
      }
    });

    test('fromJson parses new fields and tolerates numeric flex', () {
      final raw = _legacyRaw();
      final first = (raw['nodes'] as List).first as Map<String, dynamic>;
      first['mainAxis'] = 'center';
      first['crossAxis'] = 'stretch';
      first['expand'] = 'expanded';
      first['flex'] = 2;
      final doc = ScreenDoc.fromJson(raw);
      expect(doc.nodes.first.mainAxis, 'center');
      expect(doc.nodes.first.crossAxis, 'stretch');
      expect(doc.nodes.first.expand, 'expanded');
      expect(doc.nodes.first.flex, 2);
    });

    test('toJson always writes new keys and roundtrips', () {
      const node = CanvasNode(
        id: 'n',
        screenId: 's',
        x: 1,
        y: 2,
        items: [],
        mainAxis: 'spaceBetween',
        crossAxis: 'stretch',
        expand: 'flex',
        flex: 3,
      );
      final json = node.toJson();
      expect(json.containsKey('mainAxis'), isTrue);
      expect(json.containsKey('crossAxis'), isTrue);
      expect(json.containsKey('expand'), isTrue);
      expect(json.containsKey('flex'), isTrue);
      final back = CanvasNode.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back.mainAxis, 'spaceBetween');
      expect(back.crossAxis, 'stretch');
      expect(back.expand, 'flex');
      expect(back.flex, 3);
    });

    test('roundtrip preserves explicit alignment subtree', () {
      final doc = _flowDoc();
      final aligned = ScreenDoc(
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
                gap: n.gap,
                mainAxis: 'center',
                crossAxis: 'stretch',
              )
            else if (n.id == 'c1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'expanded',
                flex: 2,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final back = ScreenDoc.fromJson(
        jsonDecode(jsonEncode(aligned.toJson())) as Map<String, dynamic>,
      );
      expect(back.nodes.firstWhere((n) => n.id == 'r1').mainAxis, 'center');
      expect(
        back.nodes.firstWhere((n) => n.id == 'r1').crossAxis,
        'stretch',
      );
      expect(back.nodes.firstWhere((n) => n.id == 'c1').expand, 'expanded');
      expect(back.nodes.firstWhere((n) => n.id == 'c1').flex, 2);
      expect(back.nodes.firstWhere((n) => n.id == 'c2').expand, isNull);
    });
  });

  group('W3 prompt alignment', () {
    test('row header gains main/cross when non-null', () {
      final doc = _flowDoc();
      final aligned = ScreenDoc(
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
                gap: n.gap,
                mainAxis: 'center',
                crossAxis: 'stretch',
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final prompt = buildPrompt(aligned);
      expect(prompt, contains('- row (gap 8, main center, cross stretch)'));
    });

    test('row header with only main set', () {
      final doc = _flowDoc();
      final aligned = ScreenDoc(
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
                gap: n.gap,
                mainAxis: 'spaceBetween',
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      expect(buildPrompt(aligned), contains('- row (gap 8, main spaceBetween)'));
    });

    test('leaf format unchanged when expand is set', () {
      final doc = _flowDoc();
      final expanded = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'expanded',
                flex: 2,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final prompt = buildPrompt(expanded);
      expect(prompt, contains('  - button "A" (variant primary)'));
      expect(
        prompt,
        contains('- button "Top" (variant primary) at (16, 200)'),
      );
    });
  });

  group('W3 codegen alignment/flex', () {
    test('row maps main/cross strings to const names', () {
      final doc = _flowDoc();
      final aligned = ScreenDoc(
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
                gap: n.gap,
                mainAxis: 'center',
                crossAxis: 'stretch',
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final out = buildSingleFile(aligned, const {});
      expect(out, contains('mainAxisAlignment: MainAxisAlignment.center,'));
      expect(out, contains('crossAxisAlignment: CrossAxisAlignment.stretch,'));
    });

    test('all main/cross values map', () {
      final cases = {
        'start': 'MainAxisAlignment.start',
        'center': 'MainAxisAlignment.center',
        'end': 'MainAxisAlignment.end',
        'spaceBetween': 'MainAxisAlignment.spaceBetween',
        'spaceAround': 'MainAxisAlignment.spaceAround',
        'spaceEvenly': 'MainAxisAlignment.spaceEvenly',
      };
      for (final entry in cases.entries) {
        final doc = _flowDoc();
        final aligned = ScreenDoc(
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
                  gap: n.gap,
                  mainAxis: entry.key,
                )
              else
                n,
          ],
          theme: doc.theme,
          meta: doc.meta,
        );
        expect(
          buildSingleFile(aligned, const {}),
          contains('mainAxisAlignment: ${entry.value},'),
        );
      }
    });

    test('expanded child wraps in Expanded with flex', () {
      final doc = _flowDoc();
      final wrapped = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c1')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'expanded',
                flex: 2,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final out = buildSingleFile(wrapped, const {});
      expect(out, contains('Expanded('));
      expect(out, contains('flex: 2,'));
      // Deterministic order: Expanded for A precedes B's label.
      expect(out.indexOf('Expanded('), lessThan(out.indexOf("'B'")));
    });

    test('flex child wraps in Flexible and defaults flex to 1', () {
      final doc = _flowDoc();
      final wrapped = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'c2')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                parentId: n.parentId,
                isRow: n.isRow,
                gap: n.gap,
                expand: 'flex',
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final out = buildSingleFile(wrapped, const {});
      expect(out, contains('Flexible('));
      expect(out, contains('flex: 1,'));
    });

    test('null expand emits no wrapper (pre-W3 output)', () {
      final out = buildSingleFile(_flowDoc(), const {});
      expect(out, contains('Row('));
      expect(out, isNot(contains('Expanded(')));
      expect(out, isNot(contains('Flexible(')));
    });
  });
}
