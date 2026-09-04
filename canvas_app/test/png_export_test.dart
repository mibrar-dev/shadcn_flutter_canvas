import 'package:canvas_app/ui/png_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capturePng returns non-empty PNG bytes', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 390,
              height: 844,
              child: ColoredBox(color: Color(0xFF123456)),
            ),
          ),
        ),
      ),
    );

    // toImage completes via real engine async work, which needs runAsync
    // inside the fake-async widget-test zone.
    final bytes = await tester.runAsync(() => capturePng(key));
    expect(bytes, isNotNull);
    expect(bytes!, isNotEmpty);
    // PNG magic header.
    expect(
      bytes.sublist(0, 8),
      orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]),
    );
  });

  testWidgets('capturePng throws when boundary is not attached', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(
      () => capturePng(GlobalKey()),
      throwsStateError,
    );
  });
}
