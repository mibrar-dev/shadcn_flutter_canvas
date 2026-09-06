/// Track S1: inspector `apiCall` step editor (widget tests).
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

(CanvasStore, String, String) _storeWithButton() {
  final store = CanvasStore();
  store.addVar(
    const AppStateVar(name: 'result', type: 'string', defaultValue: ''),
  );
  final nodeId = store.addNode(
    screenId: 's1',
    x: 16,
    y: 96,
    items: const [
      CanvasItem(
        id: 'i1',
        kind: 'button',
        props: {'label': 'Go', 'variant': 'primary'},
      ),
    ],
  );
  return (store, nodeId, 'i1');
}

CanvasItem _item(CanvasStore store, String nodeId, String itemId) =>
    store.doc.nodes
        .singleWhere((n) => n.id == nodeId)
        .items
        .singleWhere((i) => i.id == itemId);

Future<void> _pumpInspector(
  WidgetTester tester,
  CanvasStore store, {
  String? nodeId,
  String? itemId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InspectorPanel(store: store, nodeId: nodeId, itemId: itemId),
      ),
    ),
  );
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('apiCall step editor', () {
    testWidgets('add defaults to GET with empty url/saveTo', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);

      await _tapKey(tester, 'step-add-apiCall');

      final step = _item(store, nodeId, itemId).action!.steps.single;
      expect(step.kind, 'apiCall');
      expect(step.method, 'GET');
      expect(step.url, isEmpty);
      expect(step.saveTo, isEmpty);
      expect(find.textContaining('API call'), findsOneWidget);
      expect(find.byKey(const ValueKey('step-0-url')), findsOneWidget);
      expect(find.byKey(const ValueKey('step-0-method')), findsOneWidget);
      // GET hides the body field.
      expect(find.byKey(const ValueKey('step-0-body')), findsNothing);
    });

    testWidgets('url + method + body edit round-trip', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-apiCall');

      await tester.enterText(
        find.byKey(const ValueKey('step-0-url')),
        'https://api.example.com/items',
      );
      await tester.pump();
      tester
          .widget<PropSegmentedEditor>(
            find.byKey(const ValueKey('step-0-method')),
          )
          .onChanged('POST');
      await tester.pump();

      // POST reveals the body field.
      expect(find.byKey(const ValueKey('step-0-body')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('step-0-body')),
        '{"a":1}',
      );
      await tester.pump();

      final step = _item(store, nodeId, itemId).action!.steps.single;
      expect(step.url, 'https://api.example.com/items');
      expect(step.method, 'POST');
      expect(step.body, '{"a":1}');
    });

    testWidgets('headers add/edit/delete rows', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-apiCall');

      await _tapKey(tester, 'step-0-header-add');
      expect(find.byKey(const ValueKey('step-0-header-key-0')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('step-0-header-key-0')),
        'Content-Type',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('step-0-header-value-0')),
        'application/json',
      );
      await tester.pump();

      expect(
        _item(store, nodeId, itemId).action!.steps.single.headers,
        {'Content-Type': 'application/json'},
      );

      await _tapKey(tester, 'step-0-header-delete-0');
      expect(
        _item(store, nodeId, itemId).action!.steps.single.headers,
        isEmpty,
      );
    });

    testWidgets('saveTo picker writes and clears', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-apiCall');

      tester
          .widget<shadcn.Select<String>>(
            find.byKey(const ValueKey('step-0-saveTo')),
          )
          .onChanged!('result');
      await tester.pump();
      expect(
        _item(store, nodeId, itemId).action!.steps.single.saveTo,
        'result',
      );

      await _tapKey(tester, 'step-0-saveTo-clear');
      expect(
        _item(store, nodeId, itemId).action!.steps.single.saveTo,
        isEmpty,
      );
    });

    testWidgets('invalid URL shows a validation note', (tester) async {
      _tallViewport(tester);
      final (store, nodeId, itemId) = _storeWithButton();
      await _pumpInspector(tester, store, nodeId: nodeId, itemId: itemId);
      await _tapKey(tester, 'step-add-apiCall');

      // Empty URL prompts for input.
      expect(find.textContaining('Enter an http(s) URL'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('step-0-url')),
        'notaurl',
      );
      await tester.pump();
      expect(find.textContaining('Invalid URL'), findsOneWidget);
    });
  });
}
