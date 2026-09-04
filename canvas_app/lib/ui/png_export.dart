import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the [RepaintBoundary] attached to [key] as PNG bytes.
///
/// [key] is a plain [GlobalKey] placed on a [RepaintBoundary] widget
/// (`GlobalKey<RepaintBoundary>` does not compile: `GlobalKey` is bounded
/// on `State`). Throws [StateError] when the key is not attached to a
/// [RepaintBoundary].
Future<Uint8List> capturePng(GlobalKey key, {double pixelRatio = 2.0}) async {
  final context = key.currentContext;
  if (context == null) {
    throw StateError('capturePng: RepaintBoundary is not attached');
  }
  final object = context.findRenderObject();
  if (object is! RenderRepaintBoundary) {
    throw StateError('capturePng: key does not resolve to a RepaintBoundary');
  }
  final ui.Image image = await object.toImage(pixelRatio: pixelRatio);
  try {
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('capturePng: PNG encoding produced no bytes');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
