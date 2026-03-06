import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:flutter/material.dart';
import 'package:fluvie_flutter_shadcn_cli_intro/videos/flutter_shadcn_cli_intro_composition.dart';

void main() {
  runApp(const IntroVideoRenderApp());
}

class IntroVideoRenderApp extends StatelessWidget {
  const IntroVideoRenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: IntroVideoRenderPage());
  }
}

class IntroVideoRenderPage extends StatefulWidget {
  const IntroVideoRenderPage({super.key});

  @override
  State<IntroVideoRenderPage> createState() => _IntroVideoRenderPageState();
}

class _IntroVideoRenderPageState extends State<IntroVideoRenderPage> {
  static const _autoRender = bool.fromEnvironment(
    'AUTO_RENDER',
    defaultValue: false,
  );
  static const _autoExit = bool.fromEnvironment(
    'AUTO_EXIT',
    defaultValue: false,
  );

  final RenderController _controller = RenderController();
  final VideoComposition _composition = buildFlutterShadcnCliIntroComposition();

  bool _isRendering = false;
  String _status = 'Ready to render';

  @override
  void initState() {
    super.initState();
    if (_autoRender) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _renderVideo();
      });
    }
  }

  Future<void> _renderVideo() async {
    if (_isRendering) return;

    setState(() {
      _isRendering = true;
      _status = 'Rendering video...';
    });

    try {
      final config = _controller.config;
      if (config == null) {
        throw Exception('Render config is not ready yet.');
      }

      final service = RenderService();
      final renderedPath = await service.execute(
        config: config,
        repaintBoundaryKey: _controller.boundaryKey,
        onFrameUpdate: (frame) {
          _controller.setFrame(frame);
          WidgetsBinding.instance.scheduleFrame();
          if (mounted && frame % 12 == 0) {
            setState(() {
              _status =
                  'Rendering frame ${frame + 1}/${config.timeline.durationInFrames}...';
            });
          }
        },
      );

      final outputDir = Directory('output');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final finalOutputPath =
          '${outputDir.path}/flutter_shadcn_cli_intro_$timestamp.mp4';

      await File(renderedPath).copy(finalOutputPath);

      setState(() {
        _status = 'Done: $finalOutputPath';
      });
      if (_autoExit) {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          exit(0);
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Render failed: $e';
      });
      if (_autoExit) {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          exit(1);
        });
      }
    } finally {
      setState(() {
        _isRendering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1222),
      appBar: AppBar(
        title: const Text('Fluvie: flutter_shadcn_cli Intro Renderer'),
        backgroundColor: const Color(0xFF111B33),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                color: Colors.black,
                child: SizedBox(
                  width: _composition.width.toDouble(),
                  height: _composition.height.toDouble(),
                  child: RenderableComposition(
                    controller: _controller,
                    composition: _composition,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isRendering ? null : _renderVideo,
              child: Text(_isRendering ? 'Rendering...' : 'Render MP4'),
            ),
          ],
        ),
      ),
    );
  }
}
