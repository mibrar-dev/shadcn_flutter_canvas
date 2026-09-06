import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/phone_frame.dart';
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
    // Y4 (FORGE.md §1-3g): the canvas ScreenLabel row is dropped — screen
    // names move to the Forge header breadcrumb at the Y6 cutover — so count
    // phone frames instead of label text.
    expect(find.byType(PhoneFrame), findsOneWidget);
    // The toolbar tip is a kit tooltip now (invisible to `find.byTooltip`),
    // so tap the toolbar's add-screen glyph directly.
    await tester.tap(
      find.descendant(
        of: find.byType(CanvasToolbar),
        matching: find.byIcon(Icons.add_to_photos),
      ),
    );
    await tester.pump();
    expect(find.byType(PhoneFrame), findsNWidgets(2));
  });
}
