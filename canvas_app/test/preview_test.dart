import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pay → Done fixture: one tap action from s1 to s2.
ScreenDoc _doc() => ScreenDoc.fromJson({
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
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Pay',
              'variant': 'primary',
              'action': {'to': 's2', 'transition': 'slide'},
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's2',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Paid'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Pay flow', 'brief': ''},
    });

Future<void> _pumpPreview(
  WidgetTester tester,
  ScreenDoc doc, {
  VoidCallback? onExit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PreviewPlayer(doc: doc, onExit: onExit)),
    ),
  );
}

void main() {
  testWidgets('item tap navigates, back pops, back at root exits', (
    tester,
  ) async {
    var exited = false;
    await _pumpPreview(tester, _doc(), onExit: () => exited = true);

    // Start screen only.
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);

    // Real tap on the widget pushes s2.
    await tester.tap(find.text('Pay'));
    await tester.pump();
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Pay'), findsNothing);
    expect(exited, isFalse);

    // Back pops to s1…
    await tester.tap(find.text('‹ Back'));
    await tester.pump();
    expect(find.text('Pay'), findsOneWidget);

    // …and back at the root returns to the editor.
    await tester.tap(find.text('‹ Back'));
    await tester.pump();
    expect(exited, isTrue);
  });

  testWidgets('action-less widgets render without a tap wrapper', (
    tester,
  ) async {
    await _pumpPreview(tester, _doc());
    await tester.tap(find.text('Pay'));
    await tester.pump();
    // s2's button has no action: tapping it navigates nowhere.
    await tester.tap(find.text('Paid'));
    await tester.pump();
    expect(find.text('Paid'), findsOneWidget);
  });
}
