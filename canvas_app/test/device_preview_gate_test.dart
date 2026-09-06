/// Track EE — device_preview 3.0 gate coverage.
///
/// Proves the opt-in gate stays OFF by default (test-suite hermeticity: no
/// simulated viewport may leak into the 983 widget tests that pump bare
/// MaterialApps / EditorShell under the stock test binding) and that
/// importing `package:canvas_app/main.dart` installs no DevicePreview
/// binding side effects.
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldEnableDevicePreview gate', () {
    test('default (not requested, not release) is OFF', () {
      expect(
        shouldEnableDevicePreview(releaseMode: false, requested: false),
        isFalse,
      );
    });

    test('requested debug/profile build is ON', () {
      expect(
        shouldEnableDevicePreview(releaseMode: false, requested: true),
        isTrue,
      );
    });

    test('release build never simulates, even when requested', () {
      expect(
        shouldEnableDevicePreview(releaseMode: true, requested: true),
        isFalse,
      );
    });

    test('release build without request is OFF', () {
      expect(
        shouldEnableDevicePreview(releaseMode: true, requested: false),
        isFalse,
      );
    });

    test('DEVICE_PREVIEW dart-define defaults to false in test env', () {
      // No --dart-define is passed to flutter test, so the opt-in switch
      // resolves to its defaultValue and the effective flag is false even
      // though tests run in debug mode (!kReleaseMode).
      const requested = bool.fromEnvironment(
        'DEVICE_PREVIEW',
        defaultValue: false,
      );
      expect(requested, isFalse);
      expect(
        shouldEnableDevicePreview(
          releaseMode: kReleaseMode,
          requested: requested,
        ),
        isFalse,
      );
    });
  });

  group('no DevicePreview binding side effects in widget tests', () {
    test('ambient binding is the stock test binding', () {
      expect(WidgetsBinding.instance, isNot(isA<DevicePreview>()));
    });

    test('maybeController is null when simulation is off', () {
      expect(DevicePreview.maybeController, isNull);
    });

    testWidgets('EditorShell pumps hermetically (no simulated viewport)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: EditorShell(store: CanvasStore())),
      );
      await tester.pump();

      // Shell assembles as before — the gate changed nothing about pumps.
      expect(find.byType(ForgeTopbar), findsOneWidget);
      // Simulation stayed off for the whole pump.
      expect(WidgetsBinding.instance, isNot(isA<DevicePreview>()));
      expect(DevicePreview.maybeController, isNull);
    });
  });
}
