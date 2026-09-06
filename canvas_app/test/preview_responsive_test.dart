import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responsive render-filtering tests for [PreviewPlayer] (Track D).
///
/// The stage width IS the breakpoint: the default phone stage (390) resolves
/// the mobile tier, switching to a desktop preset re-tiers to desktop, so
/// each test pumps once on mobile then taps the desktop-fluid preset.
ScreenDoc _doc(List<Map<String, dynamic>> nodes) => ScreenDoc.fromJson(
      <String, dynamic>{
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': nodes,
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Responsive', 'brief': ''},
      },
    );

Future<void> _pumpPreview(WidgetTester tester, ScreenDoc doc) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PreviewPlayer(doc: doc))),
  );
}

/// Wide viewport so desktop stages (1100/1440) are never clamped.
void _wideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _goDesktop(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.desktop_windows_outlined));
  await tester.pump();
}

void main() {
  testWidgets('node hidden on mobile is visible on desktop', (tester) async {
    _wideViewport(tester);
    await _pumpPreview(
      tester,
      _doc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Always Here'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 16.0,
          'y': 200.0,
          'hiddenOn': ['mobile'],
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Desktop Only'},
          ],
        },
      ]),
    );

    expect(find.text('Always Here'), findsOneWidget);
    expect(find.text('Desktop Only'), findsNothing);
    expect(find.text('mobile · 390'), findsOneWidget);

    await _goDesktop(tester);

    expect(find.text('Always Here'), findsOneWidget);
    expect(find.text('Desktop Only'), findsOneWidget);
    expect(find.text('desktop · 1100'), findsOneWidget);
  });

  testWidgets('hidden row hides its children', (tester) async {
    _wideViewport(tester);
    await _pumpPreview(
      tester,
      _doc([
        {
          'id': 'row1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'isRow': true,
          'hiddenOn': ['mobile'],
          'items': [],
        },
        {
          'id': 'c1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'parentId': 'row1',
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Nested Child'},
          ],
        },
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i2', 'kind': 'button', 'label': 'Root Control'},
          ],
        },
      ]),
    );

    // The row is hidden on mobile, so its individually-visible child hides
    // with it; the unrelated root leaf still renders.
    expect(find.text('Root Control'), findsOneWidget);
    expect(find.text('Nested Child'), findsNothing);

    await _goDesktop(tester);

    expect(find.text('Root Control'), findsOneWidget);
    expect(find.text('Nested Child'), findsOneWidget);
  });

  testWidgets('breakpointValues override applies per tier', (tester) async {
    _wideViewport(tester);
    await _pumpPreview(
      tester,
      _doc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'breakpointValues': {
            'desktop': {'label': 'Wide Label'},
          },
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Base Label'},
          ],
        },
      ]),
    );

    expect(find.text('Base Label'), findsOneWidget);
    expect(find.text('Wide Label'), findsNothing);

    await _goDesktop(tester);

    expect(find.text('Wide Label'), findsOneWidget);
    expect(find.text('Base Label'), findsNothing);
  });

  testWidgets('slots allowlist renders named items, ignores unknown keys', (
    tester,
  ) async {
    _wideViewport(tester);
    await _pumpPreview(
      tester,
      _doc([
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'slots': {'i1': 'main'},
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Slot One'},
            {'id': 'i2', 'kind': 'button', 'label': 'Slot Two'},
          ],
        },
        {
          'id': 'n2',
          'screenId': 's1',
          'x': 16.0,
          'y': 200.0,
          'slots': {'unknown-key': 'x'},
          'items': [
            {'id': 'i3', 'kind': 'button', 'label': 'Free Item'},
          ],
        },
      ]),
    );

    // `i1` is named by a slot key, so only it renders; the unknown slot key
    // on n2 is ignored and its item renders normally.
    expect(find.text('Slot One'), findsOneWidget);
    expect(find.text('Slot Two'), findsNothing);
    expect(find.text('Free Item'), findsOneWidget);
  });

  group('node w/h sizing (Track U2 follow-up)', () {
    testWidgets('sized node renders at pinned width in preview', (tester) async {
      await _pumpPreview(
        tester,
        _doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'w': 200.0,
            'items': [
              {'id': 'i1', 'kind': 'button', 'label': 'Pinned'},
            ],
          },
        ]),
      );
      final box = tester.widget<SizedBox>(
        find.ancestor(
          of: find.text('Pinned'),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 200.0,
          ),
        ).first,
      );
      expect(box.width, 200.0);
    });

    testWidgets('unsized node has no pinning SizedBox', (tester) async {
      await _pumpPreview(
        tester,
        _doc([
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'i1', 'kind': 'button', 'label': 'Auto'},
            ],
          },
        ]),
      );
      // Stage chrome itself uses SizedBoxes, so pin absence of the exact
      // pinning size rather than of SizedBox in general.
      expect(
        find.ancestor(
          of: find.text('Auto'),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 200.0,
          ),
        ),
        findsNothing,
      );
    });
  });
}
