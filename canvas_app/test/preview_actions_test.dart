/// Track R1: preview executes multi-step action flows (setState + navigate,
/// conditionals, feedback) and resolves `=var` bindings live.
library;

import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenDoc _doc({
  required List<Map<String, dynamic>> states,
  required List<Map<String, dynamic>> items,
  List<Map<String, dynamic>>? s2Items,
}) =>
    ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Done', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': items,
        },
        if (s2Items != null)
          {
            'id': 'n2',
            'screenId': 's2',
            'x': 16.0,
            'y': 96.0,
            'items': s2Items,
          },
      ],
      'states': states,
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Actions', 'brief': ''},
    });

int _previewKey = 0;

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  // Fresh key per pump: PreviewPlayer is stateful (nav stack + session),
  // so re-pumps with a new doc must remount instead of reusing state.
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PreviewPlayer(key: ValueKey(_previewKey++), doc: doc),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('setState updates a bound label in place', (tester) async {
    final doc = _doc(
      states: [
        {'name': 'count', 'type': 'number', 'default': 0},
      ],
      items: [
        {'id': 'show', 'kind': 'badge', 'label': '=count'},
        {
          'id': 'inc',
          'kind': 'button',
          'label': 'Inc',
          'action': {
            'to': 's1',
            'transition': 'slide',
            'steps': [
              {'kind': 'setState', 'variable': 'count', 'value': '1'},
            ],
          },
        },
      ],
    );
    await _pumpPreview(tester, doc);

    expect(find.text('0'), findsOneWidget);
    await _tapText(tester, 'Inc');
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('setState from =other and literal by type', (tester) async {
    final doc = _doc(
      states: [
        {'name': 'who', 'type': 'string', 'default': 'Ada'},
        {'name': 'nick', 'type': 'string', 'default': ''},
      ],
      items: [
        {'id': 'show', 'kind': 'badge', 'label': '=nick'},
        {
          'id': 'copy',
          'kind': 'button',
          'label': 'Copy',
          'action': {
            'to': 's1',
            'transition': 'slide',
            'steps': [
              {'kind': 'setState', 'variable': 'nick', 'value': '=who'},
            ],
          },
        },
      ],
    );
    await _pumpPreview(tester, doc);
    await _tapText(tester, 'Copy');
    expect(find.text('Ada'), findsOneWidget); // the badge now reads nick
  });

  testWidgets('tap runs setState then navigates (navigation last)', (
    tester,
  ) async {
    final doc = _doc(
      states: [
        {'name': 'who', 'type': 'string', 'default': 'Ada'},
      ],
      items: [
        {'id': 'greet', 'kind': 'badge', 'label': '=who'},
        {
          'id': 'go',
          'kind': 'button',
          'label': 'Next',
          'action': {
            'to': 's1',
            'transition': 'slide',
            'steps': [
              {'kind': 'setState', 'variable': 'who', 'value': 'Bob'},
              {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
            ],
          },
        },
      ],
      s2Items: [
        {'id': 'back', 'kind': 'badge', 'label': 'Done here'},
      ],
    );
    await _pumpPreview(tester, doc);

    await _tapText(tester, 'Next');
    // Navigated…
    expect(find.text('Done here'), findsOneWidget);
    // …and the state stuck (visible after popping back).
    await tester.tap(find.text('‹ Back'));
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('true condition branches, false condition stays', (
    tester,
  ) async {
    ScreenDoc docWith(Object? flag) => _doc(
          states: [
            {'name': 'flag', 'type': 'bool', 'default': flag},
          ],
          items: [
            {
              'id': 'maybe',
              'kind': 'button',
              'label': 'Maybe',
              'action': {
                'to': 's1',
                'transition': 'slide',
                'steps': [
                  {
                    'kind': 'condition',
                    'variable': 'flag',
                    'equals': 'true',
                    'then': [
                      {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
                    ],
                  },
                ],
              },
            },
          ],
          s2Items: [
            {'id': 'there', 'kind': 'badge', 'label': 'Arrived'},
          ],
        );

    await _pumpPreview(tester, docWith(true));
    await _tapText(tester, 'Maybe');
    expect(find.text('Arrived'), findsOneWidget);

    await _pumpPreview(tester, docWith(false));
    await _tapText(tester, 'Maybe');
    expect(find.text('Arrived'), findsNothing);
    expect(find.text('Maybe'), findsOneWidget);
  });

  testWidgets('snackbar step shows feedback and stays put', (tester) async {
    final doc = _doc(
      states: const [],
      items: [
        {
          'id': 'save',
          'kind': 'button',
          'label': 'Save',
          'action': {
            'to': 's1',
            'transition': 'slide',
            'steps': [
              {'kind': 'showSnackBar', 'message': 'Saved!'},
            ],
          },
        },
      ],
    );
    await _pumpPreview(tester, doc);
    await _tapText(tester, 'Save');
    expect(find.text('Saved!'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    // No navigation happened.
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('dialog step shows title and message', (tester) async {
    final doc = _doc(
      states: [
        {'name': 'who', 'type': 'string', 'default': 'Ada'},
      ],
      items: [
        {
          'id': 'info',
          'kind': 'button',
          'label': 'Info',
          'action': {
            'to': 's1',
            'transition': 'slide',
            'steps': [
              {
                'kind': 'showDialog',
                'title': 'Hello',
                'message': '=who',
              },
            ],
          },
        },
      ],
    );
    await _pumpPreview(tester, doc);
    await _tapText(tester, 'Info');
    expect(find.text('Hello'), findsWidgets);
    // Whole-value =who binding resolves inside the dialog message.
    expect(find.text('Ada'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('unknown-var steps are skipped, navigation still runs', (
    tester,
  ) async {
    final doc = _doc(
      states: const [],
      items: [
        {
          'id': 'go',
          'kind': 'button',
          'label': 'Go',
          'action': {
            'to': 's1',
            'transition': 'slide',
            'steps': [
              {'kind': 'setState', 'variable': 'ghost', 'value': '1'},
              {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
            ],
          },
        },
      ],
      s2Items: [
        {'id': 'there', 'kind': 'badge', 'label': 'Arrived'},
      ],
    );
    await _pumpPreview(tester, doc);
    await _tapText(tester, 'Go');
    expect(find.text('Arrived'), findsOneWidget);
  });

  testWidgets('unresolvable bindings render raw', (tester) async {
    final doc = _doc(
      states: const [],
      items: [
        {'id': 'myst', 'kind': 'badge', 'label': '=ghost'},
      ],
    );
    await _pumpPreview(tester, doc);
    expect(find.text('=ghost'), findsOneWidget);
  });

  testWidgets('legacy single-nav taps still navigate', (tester) async {
    final doc = _doc(
      states: const [],
      items: [
        {
          'id': 'go',
          'kind': 'button',
          'label': 'Go',
          'action': {'to': 's2', 'transition': 'slide'},
        },
      ],
      s2Items: [
        {'id': 'there', 'kind': 'badge', 'label': 'Arrived'},
      ],
    );
    await _pumpPreview(tester, doc);
    await _tapText(tester, 'Go');
    expect(find.text('Arrived'), findsOneWidget);
  });
}
