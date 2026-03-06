import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluvie/fluvie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_flutter_shadcn_cli_intro/videos/flutter_shadcn_cli_intro_composition.dart';

void main() {
  testWidgets('renders flutter_shadcn_cli intro video', (tester) async {
    final controller = RenderController();
    final composition = buildFlutterShadcnCliIntroComposition();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: composition.width.toDouble(),
              height: composition.height.toDouble(),
              child: RenderableComposition(
                controller: controller,
                composition: composition,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final frameDir = Directory('output/frames');
    if (frameDir.existsSync()) {
      frameDir.deleteSync(recursive: true);
    }
    frameDir.createSync(recursive: true);

    for (int frame = 0; frame < composition.durationInFrames; frame++) {
      if (frame % 12 == 0) {
        debugPrint('Capturing frame: $frame/${composition.durationInFrames}');
      }
      controller.setFrame(frame);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final boundary =
          controller.boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      expect(boundary, isNotNull);
      if (boundary!.debugNeedsPaint) {
        await tester.pump();
      }

      final image = await boundary
          .toImage(pixelRatio: 1.0)
          .timeout(const Duration(seconds: 5));
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);

      final bytes = byteData!.buffer.asUint8List();
      final framePath =
          '${frameDir.path}/frame_${frame.toString().padLeft(4, '0')}.png';
      await File(framePath).writeAsBytes(bytes, flush: true);
    }

    final outputDir = Directory('output');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final outputPath =
        '${outputDir.path}/flutter_shadcn_cli_intro_$timestamp.mp4';

    final ffmpegResult = await Process.run('ffmpeg', [
      '-y',
      '-framerate',
      composition.fps.toString(),
      '-i',
      '${frameDir.path}/frame_%04d.png',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      outputPath,
    ]);

    if (ffmpegResult.exitCode != 0) {
      fail('FFmpeg failed: ${ffmpegResult.stderr}');
    }

    expect(File(outputPath).existsSync(), isTrue);

    frameDir.deleteSync(recursive: true);
    debugPrint('Rendered video copied to: $outputPath');
  });
}
