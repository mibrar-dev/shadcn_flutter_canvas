import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('topbar add-screen adds a second phone (Y6 cutover)',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(MaterialApp(home: EditorShell(store: CanvasStore())));
    await tester.pump();
    // Y4 (FORGE.md §1-3g): the canvas ScreenLabel row is dropped — screen
    // names move to the Forge header breadcrumb at the Y6 cutover — so count
    // phone frames instead of label text.
    expect(find.byType(PhoneFrame), findsOneWidget);
    // Y6: the old floating-toolbar add glyph is gone; "+" lives in the Forge
    // topbar tabs row (kit tooltip 'Add screen', invisible to find.byTooltip).
    // FF7: the spec'd topbar zoom-in button reuses the add glyph, so scope
    // the tap to the page selector's 'Add screen' button.
    await tester.tap(
      find.descendant(
        of: find.byType(ForgeTopbar),
        matching: find.byWidgetPredicate(
          (w) => w is EditorIconButton && w.tooltip == 'Add screen',
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PhoneFrame), findsNWidgets(2));
  });
}
