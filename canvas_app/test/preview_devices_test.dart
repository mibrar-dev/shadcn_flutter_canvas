import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device-toggle tests for [PreviewPlayer].
///
/// Toggle is internal state (default mobile); the constructor is unchanged so
/// existing `preview_test.dart` cases compile untouched.
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
            {'id': 'i2', 'kind': 'button', 'label': 'Info'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's2',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i3', 'kind': 'button', 'label': 'Paid'},
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

double _stageWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('previewStage'))).width;

void main() {
  testWidgets('toggle defaults to mobile and switches stage constraint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpPreview(tester, _doc());

    // Default is mobile: 390pt stage centered on the surface.
    expect(_stageWidth(tester), kPreviewMobileMaxWidth);

    // Switch to web: frameless fluid stage capped at 1100.
    await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
    await tester.pump();
    expect(_stageWidth(tester), kPreviewWebMaxWidth);

    // And back to mobile.
    await tester.tap(find.byIcon(Icons.smartphone));
    await tester.pump();
    expect(_stageWidth(tester), kPreviewMobileMaxWidth);
  });

  testWidgets('content item counts are identical on both devices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpPreview(tester, _doc());

    int count(String text) =>
        tester.widgetList(find.text(text)).length;
    final mobilePay = count('Pay');
    final mobileInfo = count('Info');
    expect(mobilePay, 1);
    expect(mobileInfo, 1);

    await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
    await tester.pump();

    // Same tree both modes (one-tree rule): counts must match exactly.
    expect(count('Pay'), mobilePay);
    expect(count('Info'), mobileInfo);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('back navigation still works with the toggle present', (
    tester,
  ) async {
    var exited = false;
    await _pumpPreview(tester, _doc(), onExit: () => exited = true);

    // Toggle chrome is visible alongside Back.
    expect(find.byIcon(Icons.smartphone), findsOneWidget);
    expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);

    await tester.tap(find.text('Pay'));
    await tester.pump();
    expect(find.text('Paid'), findsOneWidget);

    await tester.tap(find.text('‹ Back'));
    await tester.pump();
    expect(find.text('Pay'), findsOneWidget);
    expect(exited, isFalse);

    await tester.tap(find.text('‹ Back'));
    await tester.pump();
    expect(exited, isTrue);
  });
}
