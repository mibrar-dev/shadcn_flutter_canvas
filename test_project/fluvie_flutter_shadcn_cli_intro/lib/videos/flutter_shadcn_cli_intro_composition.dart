import 'dart:math' as math;

import 'package:fluvie/fluvie.dart';
import 'package:flutter/material.dart';

VideoComposition buildFlutterShadcnCliIntroComposition() {
  return VideoComposition(
    fps: 24,
    durationInFrames: 96,
    width: 960,
    height: 540,
    child: Stack(
      children: [
        Sequence(
          startFrame: 0,
          durationInFrames: 96,
          child: const _AnimatedBackdrop(),
        ),
        const _AlwaysVisibleBrandLayer(),
        Sequence(
          startFrame: 0,
          durationInFrames: 26,
          child: const _IntroTitle(),
        ),
        Sequence(
          startFrame: 26,
          durationInFrames: 24,
          child: const _ValueScene(),
        ),
        Sequence(
          startFrame: 50,
          durationInFrames: 30,
          child: const _CommandScene(),
        ),
        Sequence(
          startFrame: 80,
          durationInFrames: 16,
          child: const _OutroScene(),
        ),
      ],
    ),
  );
}

class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop();

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final t = frame / 96;
        final shift = math.sin(t * math.pi * 2) * 0.12;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + shift, -1),
              end: Alignment(1 - shift, 1),
              colors: const [
                Color(0xFF0B1220),
                Color(0xFF111B33),
                Color(0xFF1D2E54),
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.9),
                radius: 1.2,
                colors: [
                  const Color(0xFF3B67D8).withValues(alpha: 0.30),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlwaysVisibleBrandLayer extends StatelessWidget {
  const _AlwaysVisibleBrandLayer();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'flutter_shadcn_cli',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroTitle extends StatelessWidget {
  const _IntroTitle();

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final local = (frame.clamp(0, 26) / 26).toDouble();
        final opacity = Curves.easeOut.transform(local);
        final dy = (1 - Curves.easeOutCubic.transform(local)) * 20;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Meet flutter_shadcn_cli',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Build shadcn-style Flutter UI faster',
                    style: TextStyle(
                      color: Color(0xFFD5E3FF),
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ValueScene extends StatelessWidget {
  const _ValueScene();

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final inFrame = (frame - 26).clamp(0, 24);
        final p = (inFrame / 24).toDouble();

        return Opacity(
          opacity: Curves.easeOut.transform(p),
          child: Center(
            child: Container(
              width: 760,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1730).withValues(alpha: 0.82),
                border: Border.all(color: const Color(0xFF4D73CC), width: 1.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why teams use it',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Scaffold shadcn components in seconds\n'
                    '• Keep shared tokens and utilities synced\n'
                    '• Move from prototype to production faster',
                    style: TextStyle(
                      color: Color(0xFFE5EEFF),
                      fontSize: 22,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommandScene extends StatelessWidget {
  const _CommandScene();

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final inFrame = (frame - 50).clamp(0, 30);
        final p = (inFrame / 30).toDouble();
        final slide = (1 - Curves.easeOutCubic.transform(p)) * 24;

        return Opacity(
          opacity: Curves.easeOut.transform(p),
          child: Transform.translate(
            offset: Offset(0, slide),
            child: Center(
              child: Container(
                width: 820,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1328),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF3C67C7), width: 1),
                ),
                child: const DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFFD5E3FF),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$ dart pub global activate --source path ./shadcn_flutter_cli',
                      ),
                      Text(
                        '\$ flutter_shadcn init --yes --install-icons --install-fonts',
                      ),
                      Text(
                        '\$ flutter_shadcn add @shadcn/button @shadcn/input',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OutroScene extends StatelessWidget {
  const _OutroScene();

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final inFrame = (frame - 80).clamp(0, 16);
        final p = (inFrame / 16).toDouble();

        return Opacity(
          opacity: Curves.easeOut.transform(p),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start building with flutter_shadcn_cli',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Faster setup. Consistent UI. Cleaner workflow.',
                  style: TextStyle(color: Color(0xFFD3E3FF), fontSize: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
