/// Track R3 tests: per-check audit-engine unit tests (crafted docs) plus
/// Audit-tab widget tests (counts render, tap selects, updates on doc
/// change).
///
/// Engine tests build docs from [CanvasStore.emptyDoc] (valid theme/meta +
/// screen `s1`) so each test only spells out its own screens/nodes.
library;

import 'package:canvas_app/canvas/audit.dart';
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Base doc: `s1` ("Screen 1"), no nodes, valid theme/meta.
ScreenDoc _base() => CanvasStore.emptyDoc();

ScreenDoc _docWith({
  List<CanvasScreen>? screens,
  List<CanvasNode>? nodes,
}) {
  final base = _base();
  return ScreenDoc(
    screens: screens ?? base.screens,
    nodes: nodes ?? base.nodes,
    theme: base.theme,
    meta: base.meta,
  );
}

CanvasNode _node(
  String id, {
  String screenId = 's1',
  List<CanvasItem> items = const [],
  Set<String> hiddenOn = const {},
  Map<String, Map<String, dynamic>> breakpointValues = const {},
  bool isRow = false,
}) =>
    CanvasNode(
      id: id,
      screenId: screenId,
      x: 0,
      y: 0,
      items: items,
      isRow: isRow,
      hiddenOn: hiddenOn,
      breakpointValues: breakpointValues,
    );

CanvasItem _item(
  String id,
  String kind, {
  NodeAction? action,
}) =>
    CanvasItem(id: id, kind: kind, action: action);

/// Row containers carry no items by design — the scale-test workhorse that
/// trips no other check (no items → no unknown-kind/coverage noise when a
/// `catalogKinds` is passed, not a row → no empty-node).
List<CanvasNode> _rows(int count) => [
      for (var i = 0; i < count; i++) _node('r$i', isRow: true),
    ];

List<String> _codes(List<AuditIssue> issues) =>
    [for (final issue in issues) issue.code];

Future<void> _pumpAside(
  WidgetTester tester,
  CanvasStore store, {
  ValueChanged<String?>? onSelectNode,
  ValueChanged<String?>? onSelectScreen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: RightAside(
            store: store,
            onSelectNode: onSelectNode,
            onSelectScreen: onSelectScreen,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Opens the Audit tab from the default (Prompt) landing tab.
Future<void> _openAudit(WidgetTester tester) async {
  await tester.tap(find.textContaining('Audit'));
  await tester.pump();
}

void main() {
  group('audit engine', () {
    test('dangling tap targets reuse validateRefs verbatim, attributed', () {
      final doc = _docWith(
        nodes: [
          _node(
            'n1',
            items: [
              _item(
                'i1',
                'button',
                action: const NodeAction(to: 'gone', transition: 'slide'),
              ),
            ],
          ),
        ],
      );
      final expected = doc.validateRefs();
      expect(expected, ['dangling action i1 -> missing screen gone']);

      final issues = auditDoc(doc, catalogKinds: const {'button'});
      final dangling =
          issues.where((i) => i.code == 'dangling-action').toList();
      expect(dangling, hasLength(1));
      expect(dangling.single.severity, AuditSeverity.error);
      expect(dangling.single.message, expected.single);
      expect(dangling.single.nodeId, 'n1');
      expect(dangling.single.screenId, 's1');
    });

    test('no dangling refs means no dangling-action issues', () {
      final doc = _docWith(
        screens: const [
          CanvasScreen(id: 's1', name: 'A', x: 0, y: 0, bg: 'surface'),
          CanvasScreen(id: 's2', name: 'B', x: 0, y: 0, bg: 'surface'),
        ],
        nodes: [
          _node(
            'n1',
            items: [
              _item(
                'i1',
                'button',
                action: const NodeAction(to: 's2', transition: 'slide'),
              ),
            ],
          ),
        ],
      );
      expect(doc.validateRefs(), isEmpty);
      expect(
        auditDoc(doc, catalogKinds: const {'button'})
            .where((i) => i.code == 'dangling-action'),
        isEmpty,
      );
    });

    test('deleted-screen actions are covered by refs — no second code', () {
      // Regression guard for the spec's "covered by refs — skip": a stale
      // `to` from an imported doc surfaces exactly once, as dangling-action.
      final doc = _docWith(
        nodes: [
          _node(
            'n1',
            items: [
              _item(
                'i1',
                'button',
                action: const NodeAction(to: 'deleted', transition: 'slide'),
              ),
            ],
          ),
        ],
      );
      final issues = auditDoc(doc, catalogKinds: const {'button'});
      final mentioning = issues
          .where((i) => i.message.contains('deleted'))
          .toList();
      expect(mentioning, hasLength(1));
      expect(mentioning.single.code, 'dangling-action');
    });

    test('unknown kinds flag; skipped without a catalog surface', () {
      final doc = _docWith(
        nodes: [
          _node('n1', items: [_item('i1', 'frobnicate')]),
        ],
      );
      final flagged =
          auditDoc(doc, catalogKinds: const {'button'})
              .where((i) => i.code == 'unknown-kind')
              .toList();
      expect(flagged, hasLength(1));
      expect(flagged.single.severity, AuditSeverity.warning);
      expect(flagged.single.nodeId, 'n1');
      expect(flagged.single.screenId, 's1');
      expect(flagged.single.message, contains('frobnicate'));

      // No surface → the check is skipped, never guessed.
      expect(
        auditDoc(doc).where((i) => i.code == 'unknown-kind'),
        isEmpty,
      );
      // Known kinds are clean.
      expect(
        auditDoc(
          _docWith(
            nodes: [
              _node('n1', items: [_item('i1', 'button')]),
            ],
          ),
          catalogKinds: const {'button'},
        ).where((i) => i.code == 'unknown-kind'),
        isEmpty,
      );
    });

    test('nodes hidden on all tiers flag; subsets stay clean', () {
      final hidden = auditDoc(
        _docWith(
          nodes: [
            _node(
              'n1',
              items: [_item('i1', 'button')],
              hiddenOn: const {'mobile', 'tablet', 'desktop'},
            ),
          ],
        ),
        catalogKinds: const {'button'},
      ).where((i) => i.code == 'hidden-everywhere').toList();
      expect(hidden, hasLength(1));
      expect(hidden.single.severity, AuditSeverity.warning);
      expect(hidden.single.nodeId, 'n1');

      final partial = auditDoc(
        _docWith(
          nodes: [
            _node(
              'n1',
              items: [_item('i1', 'button')],
              hiddenOn: const {'mobile', 'tablet'},
            ),
          ],
        ),
        catalogKinds: const {'button'},
      ).where((i) => i.code == 'hidden-everywhere');
      expect(partial, isEmpty);
    });

    test('empty screens flag with their screen id', () {
      // Base doc: s1 with no nodes.
      final issues = auditDoc(_base());
      final empty =
          issues.where((i) => i.code == 'empty-screen').toList();
      expect(empty, hasLength(1));
      expect(empty.single.severity, AuditSeverity.warning);
      expect(empty.single.screenId, 's1');

      final filled = auditDoc(
        _docWith(nodes: [_node('n1', isRow: true)]),
      ).where((i) => i.code == 'empty-screen');
      expect(filled, isEmpty);
    });

    test('item-less non-rows flag; rows are exempt', () {
      final leaf = auditDoc(
        _docWith(nodes: [_node('n1')]),
      ).where((i) => i.code == 'empty-node').toList();
      expect(leaf, hasLength(1));
      expect(leaf.single.severity, AuditSeverity.warning);
      expect(leaf.single.nodeId, 'n1');

      // Rows legitimately carry no items — flagging them would be noise.
      final row = auditDoc(
        _docWith(nodes: [_node('n1', isRow: true)]),
      ).where((i) => i.code == 'empty-node');
      expect(row, isEmpty);
    });

    test('duplicate screen names flag later screens; case differs', () {
      const screens = [
        CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
        CanvasScreen(id: 's2', name: 'Home', x: 0, y: 0, bg: 'surface'),
        CanvasScreen(id: 's3', name: 'Home', x: 0, y: 0, bg: 'surface'),
      ];
      final dups = auditDoc(_docWith(screens: screens))
          .where((i) => i.code == 'duplicate-screen-name')
          .toList();
      expect(
        [for (final d in dups) d.screenId],
        ['s2', 's3'],
      );
      expect(dups.singleWhere((d) => d.screenId == 's2').message,
          contains('"Home"'));

      const cased = [
        CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
        CanvasScreen(id: 's2', name: 'home', x: 0, y: 0, bg: 'surface'),
      ];
      expect(
        auditDoc(_docWith(screens: cased))
            .where((i) => i.code == 'duplicate-screen-name'),
        isEmpty,
      );
    });

    test('breakpoint overrides on hidden tiers contradict; visible pass', () {
      final clash = auditDoc(
        _docWith(
          nodes: [
            _node(
              'n1',
              items: [_item('i1', 'button')],
              hiddenOn: const {'tablet'},
              breakpointValues: const {
                'tablet': {'columns': 2},
              },
            ),
          ],
        ),
        catalogKinds: const {'button'},
      ).where((i) => i.code == 'hidden-override').toList();
      expect(clash, hasLength(1));
      expect(clash.single.severity, AuditSeverity.warning);
      expect(clash.single.nodeId, 'n1');
      expect(clash.single.message, contains('tablet'));

      final clean = auditDoc(
        _docWith(
          nodes: [
            _node(
              'n1',
              items: [_item('i1', 'button')],
              hiddenOn: const {'mobile'},
              breakpointValues: const {
                'tablet': {'columns': 2},
              },
            ),
          ],
        ),
        catalogKinds: const {'button'},
      ).where((i) => i.code == 'hidden-override');
      expect(clean, isEmpty);
    });

    test('oversized thresholds: 100 clean, 101 warns, 301 errors', () {
      List<AuditIssue> oversized(int count) => auditDoc(
            _docWith(nodes: _rows(count)),
            catalogKinds: const {'button'},
          ).where((i) => i.code == 'oversized-doc').toList();

      expect(oversized(100), isEmpty);
      final warn = oversized(101);
      expect(warn, hasLength(1));
      expect(warn.single.severity, AuditSeverity.warning);
      expect(warn.single.message, contains('101'));
      expect(oversized(300).single.severity, AuditSeverity.warning);
      final error = oversized(301);
      expect(error, hasLength(1));
      expect(error.single.severity, AuditSeverity.error);
    });

    test('tap coverage is the single trailing info summary', () {
      final doc = _docWith(
        nodes: [
          _node(
            'n1',
            items: [
              _item('i1', 'button',
                  action: const NodeAction(to: 's1', transition: 'slide')),
              _item('i2', 'button'),
              _item('i3', 'button'),
            ],
          ),
        ],
      );
      final issues = auditDoc(doc, catalogKinds: const {'button'});
      final coverage =
          issues.where((i) => i.code == 'tap-coverage').toList();
      expect(coverage, hasLength(1));
      expect(coverage.single.severity, AuditSeverity.info);
      expect(
        coverage.single.message,
        'Tap coverage: 1/3 items have tap actions (33%).',
      );
      expect(issues.last.code, 'tap-coverage');

      final none = auditDoc(_base())
          .where((i) => i.code == 'tap-coverage')
          .toList();
      expect(none, hasLength(1));
      expect(none.single.message, 'Tap coverage: no items yet (0/0).');
    });

    test('checks run in catalog order, doc order within a check', () {
      const screens = [
        CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: 'surface'),
        CanvasScreen(id: 's2', name: 'Home', x: 0, y: 0, bg: 'surface'),
        CanvasScreen(id: 's3', name: 'Empty', x: 0, y: 0, bg: 'surface'),
      ];
      final doc = _docWith(
        screens: screens,
        nodes: [
          _node(
            'n1',
            items: [
              _item('i1', 'button',
                  action: const NodeAction(to: 'gone', transition: 'slide')),
            ],
          ),
          _node('n2', items: [_item('i2', 'frobnicate')]),
          _node(
            'n3',
            items: [_item('i3', 'button')],
            hiddenOn: const {'mobile', 'tablet', 'desktop'},
          ),
        ],
      );
      expect(
        _codes(auditDoc(doc, catalogKinds: const {'button'})),
        [
          'dangling-action',
          'unknown-kind',
          'hidden-everywhere',
          // s2 is both node-less and a duplicate name; s3 is node-less.
          'empty-screen',
          'empty-screen',
          'duplicate-screen-name',
          'tap-coverage',
        ],
      );
    });
  });

  group('audit panel', () {
    testWidgets('tab label counts render and issues group by severity',
        (tester) async {
      final store = CanvasStore();
      final itemId = store.uid();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: itemId,
            kind: 'button',
            action: const NodeAction(to: 'gone', transition: 'slide'),
          ),
        ],
      );
      expect(nodeId, isNotEmpty);

      await _pumpAside(tester, store);
      // Landed on Prompt; the Audit label already carries live counts.
      expect(find.text('Audit 1/0/1'), findsOneWidget);

      await _openAudit(tester);
      expect(find.text('Errors (1)'), findsOneWidget);
      expect(find.text('Infos (1)'), findsOneWidget);
      expect(find.text('Warnings (0)'), findsNothing);
      expect(
        find.text('dangling action $itemId -> missing screen gone'),
        findsOneWidget,
      );
      expect(
        find.text('Tap coverage: 1/1 items have tap actions (100%).'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a node issue selects the node', (tester) async {
      final store = CanvasStore();
      final itemId = store.uid();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: itemId,
            kind: 'button',
            action: const NodeAction(to: 'gone', transition: 'slide'),
          ),
        ],
      );
      String? selected;
      await _pumpAside(tester, store, onSelectNode: (id) => selected = id);
      await _openAudit(tester);

      await tester.tap(find.textContaining('dangling action'));
      await tester.pump();
      expect(selected, nodeId);
    });

    testWidgets('tapping a screen issue selects the screen', (tester) async {
      // Fresh store: s1 is empty → one screen-targeted empty-screen warning.
      final store = CanvasStore();
      String? selectedScreen;
      await _pumpAside(
        tester,
        store,
        onSelectScreen: (id) => selectedScreen = id,
      );
      await _openAudit(tester);

      expect(find.text('Audit 0/1/1'), findsOneWidget);
      await tester.tap(find.textContaining('has no nodes'));
      await tester.pump();
      expect(selectedScreen, 's1');
    });

    testWidgets('clean doc shows All clear; list updates on doc change',
        (tester) async {
      final store = CanvasStore();
      // One known-kind node keeps s1 non-empty without tripping any check.
      store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [CanvasItem(id: store.uid(), kind: 'button')],
      );
      await _pumpAside(tester, store);
      await _openAudit(tester);

      expect(find.text('Audit 0/0/1'), findsOneWidget);
      expect(find.text('All clear'), findsOneWidget);

      // Mutating the doc re-runs the audit with no button: the relay
      // rebuilds the aside and both the label and the list refresh.
      final itemId = store.uid();
      store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(
            id: itemId,
            kind: 'button',
            action: const NodeAction(to: 'gone', transition: 'slide'),
          ),
        ],
      );
      await tester.pump();

      expect(find.text('Audit 1/0/1'), findsOneWidget);
      expect(find.text('All clear'), findsNothing);
      expect(
        find.text('dangling action $itemId -> missing screen gone'),
        findsOneWidget,
      );
    });
  });
}
