import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toolbar add-screen adds a second phone', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: EditorShell(store: CanvasStore())));
    await tester.pump();
    expect(find.text('Screen 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Add screen'));
    await tester.pump();
    expect(find.text('Screen 2'), findsOneWidget);
  });
}
