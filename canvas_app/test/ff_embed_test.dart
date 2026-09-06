/// Track FF3 (BUILD_SPEC §9.1-1d–1e): topbar-embedded device/zoom variants.
///
/// Covers [DevicePickerEmbed] and [ZoomControlsEmbed]: same presets, same
/// landscape math, same zoom bounds as the full-size controls, at the dense
/// [EditorMetrics.ffCompactButtonSize] targets. Asserts structure and
/// callbacks, NOT pixels (§12 rule 4). The full-size [DevicePicker] and
/// [ZoomControls] are UNCHANGED — their contracts stay pinned by
/// `preview_devices_test.dart` and the canvas header tests.
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/zoom_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _deviceHarness({
  int selectedIndex = 0,
  ValueChanged<int>? onSelect,
  bool landscape = false,
  ValueChanged<bool>? onLandscapeChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: EditorTheme(
        colors: EditorColors.light,
        child: DevicePickerEmbed(
          selectedIndex: selectedIndex,
          onSelect: onSelect ?? (_) {},
          landscape: landscape,
          onLandscapeChanged: onLandscapeChanged ?? (_) {},
        ),
      ),
    ),
  );
}

Widget _zoomHarness({
  double zoom = 1.0,
  VoidCallback? onZoomIn,
  VoidCallback? onZoomOut,
  VoidCallback? onFit,
  bool showGuides = true,
  ValueChanged<bool>? onShowGuidesChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: EditorTheme(
        colors: EditorColors.light,
        child: ZoomControlsEmbed(
          zoom: zoom,
          onZoomIn: onZoomIn ?? () {},
          onZoomOut: onZoomOut ?? () {},
          onFit: onFit ?? () {},
          showGuides: showGuides,
          onShowGuidesChanged: onShowGuidesChanged,
        ),
      ),
    ),
  );
}

void main() {
  group('DevicePickerEmbed', () {
    testWidgets('renders every preset glyph plus the rotate toggle',
        (tester) async {
      await tester.pumpWidget(_deviceHarness());
      await tester.pump();

      for (final device in kPreviewDevices) {
        expect(find.byIcon(device.icon), findsOneWidget);
      }
      expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
    });

    testWidgets('tapping a preset reports its index', (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        _deviceHarness(onSelect: (i) => selected = i),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tablet_mac));
      await tester.pump();
      expect(selected, 1);

      await tester.tap(find.byIcon(Icons.desktop_mac_outlined));
      await tester.pump();
      expect(selected, 3);
    });

    testWidgets('rotate toggle flips the landscape flag', (tester) async {
      var landscape = false;
      await tester.pumpWidget(
        _deviceHarness(
          landscape: false,
          onLandscapeChanged: (v) => landscape = v,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.screen_rotation));
      await tester.pump();
      expect(landscape, isTrue);
    });

    testWidgets('rotate disables itself on frameless desktop presets',
        (tester) async {
      var flips = 0;
      await tester.pumpWidget(
        _deviceHarness(
          selectedIndex: 2,
          onLandscapeChanged: (_) => flips++,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.screen_rotation));
      await tester.pump();
      expect(flips, 0);
    });

    testWidgets('compact buttons use the ff metric', (tester) async {
      await tester.pumpWidget(_deviceHarness());
      await tester.pump();

      expect(
        tester.getSize(find.byType(DevicePickerEmbed)).height,
        EditorMetrics.ffCompactButtonSize,
      );
    });
  });

  group('ZoomControlsEmbed', () {
    testWidgets('shows the percentage readout', (tester) async {
      await tester.pumpWidget(_zoomHarness(zoom: 0.5));
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('zoom in/out/fit fire on tap', (tester) async {
      var ins = 0;
      var outs = 0;
      var fits = 0;
      await tester.pumpWidget(
        _zoomHarness(
          onZoomIn: () => ins++,
          onZoomOut: () => outs++,
          onFit: () => fits++,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pump();
      expect(ins, 1);
      expect(outs, 1);
      expect(fits, 1);
    });

    testWidgets('zoom-out disables at the 0.25 floor', (tester) async {
      var outs = 0;
      await tester.pumpWidget(
        _zoomHarness(zoom: 0.25, onZoomOut: () => outs++),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(outs, 0);
    });

    testWidgets('zoom-in disables at the 4.0 ceiling', (tester) async {
      var ins = 0;
      await tester.pumpWidget(
        _zoomHarness(zoom: 4.0, onZoomIn: () => ins++),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(ins, 0);
    });

    testWidgets('guides toggle hides when unwired, flips when wired',
        (tester) async {
      await tester.pumpWidget(_zoomHarness());
      await tester.pump();
      expect(find.byIcon(Icons.grid_on), findsNothing);
      expect(find.byIcon(Icons.grid_off), findsNothing);

      var guides = true;
      await tester.pumpWidget(
        _zoomHarness(
          showGuides: true,
          onShowGuidesChanged: (v) => guides = v,
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pump();
      expect(guides, isFalse);
    });
  });
}
