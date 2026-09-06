/// Track S1: preview `apiCall` execution (injectable client, never real
/// network in tests) plus [executeApiCall] unit coverage.
library;

import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ScreenDoc _doc({
  required List<Map<String, dynamic>> states,
  required List<Map<String, dynamic>> items,
}) =>
    ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': items,
        },
      ],
      'states': states,
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'API', 'brief': ''},
    });

int _previewKey = 0;

Future<void> _pumpPreview(
  WidgetTester tester,
  ScreenDoc doc, {
  http.Client? client,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PreviewPlayer(
          key: ValueKey(_previewKey++),
          doc: doc,
          httpClient: client,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('executeApiCall', () {
    test('GET returns the body string', () async {
      final client = MockClient((_) async => http.Response('hello', 200));
      const step = ActionStep.apiCall(url: 'https://a.b/items');
      expect(await executeApiCall(step, client: client), 'hello');
    });

    test('POST sends headers and body', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('ok', 201);
      });
      const step = ActionStep.apiCall(
        url: 'https://a.b/items',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: '{"a":1}',
      );
      expect(await executeApiCall(step, client: client), 'ok');
      expect(seen?.method, 'POST');
      expect(seen!.headers['Content-Type'], 'application/json');
      expect(seen!.body, '{"a":1}');
    });

    test('invalid URL and unknown method skip without network', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('x', 200);
      });
      expect(
        await executeApiCall(
          const ActionStep.apiCall(url: 'notaurl'),
          client: client,
        ),
        isNull,
      );
      expect(
        await executeApiCall(
          const ActionStep.apiCall(url: 'https://a.b/', method: 'PUT'),
          client: client,
        ),
        isNull,
      );
      expect(called, isFalse);
    });

    test('transport errors and timeouts skip (no throw)', () async {
      final failing =
          MockClient((_) async => throw http.ClientException('down'));
      expect(
        await executeApiCall(
          const ActionStep.apiCall(url: 'https://a.b/'),
          client: failing,
        ),
        isNull,
      );

      final slow = MockClient(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('late', 200);
        },
      );
      expect(
        await executeApiCall(
          const ActionStep.apiCall(url: 'https://a.b/'),
          client: slow,
          timeout: const Duration(milliseconds: 10),
        ),
        isNull,
      );
    });
  });

  group('preview apiCall flow', () {
    testWidgets('success saves the body into the bound var', (tester) async {
      final client = MockClient((_) async => http.Response('Ada', 200));
      final doc = _doc(
        states: [
          {'name': 'result', 'type': 'string', 'default': ''},
        ],
        items: [
          {'id': 'show', 'kind': 'badge', 'label': '=result'},
          {
            'id': 'load',
            'kind': 'button',
            'label': 'Load',
            'action': {
              'to': 's1',
              'transition': 'slide',
              'steps': [
                {
                  'kind': 'apiCall',
                  'url': 'https://a.b/items',
                  'method': 'GET',
                  'headers': {},
                  'body': '',
                  'saveTo': 'result',
                },
              ],
            },
          },
        ],
      );
      await _pumpPreview(tester, doc, client: client);

      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();

      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('failure skips the step without crashing', (tester) async {
      final client = MockClient(
        (_) async => throw http.ClientException('down'),
      );
      final doc = _doc(
        states: [
          {'name': 'result', 'type': 'string', 'default': 'keep'},
        ],
        items: [
          {'id': 'show', 'kind': 'badge', 'label': '=result'},
          {
            'id': 'load',
            'kind': 'button',
            'label': 'Load',
            'action': {
              'to': 's1',
              'transition': 'slide',
              'steps': [
                {
                  'kind': 'apiCall',
                  'url': 'https://a.b/items',
                  'method': 'GET',
                  'headers': {},
                  'body': '',
                  'saveTo': 'result',
                },
              ],
            },
          },
        ],
      );
      await _pumpPreview(tester, doc, client: client);

      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();

      // Session kept its value; the tap itself never crashed.
      expect(find.text('keep'), findsOneWidget);
      expect(find.text('Load'), findsOneWidget);
    });

    testWidgets('unknown saveTo discards the response safely', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response('body', 200));
      final doc = _doc(
        states: const [],
        items: [
          {
            'id': 'load',
            'kind': 'button',
            'label': 'Load',
            'action': {
              'to': 's1',
              'transition': 'slide',
              'steps': [
                {
                  'kind': 'apiCall',
                  'url': 'https://a.b/items',
                  'method': 'GET',
                  'headers': {},
                  'body': '',
                  'saveTo': 'ghost',
                },
              ],
            },
          },
        ],
      );
      await _pumpPreview(tester, doc, client: client);

      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();

      expect(find.text('Load'), findsOneWidget);
    });
  });
}
