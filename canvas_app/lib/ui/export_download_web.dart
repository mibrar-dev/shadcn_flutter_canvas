/// Browser implementation of the download facade (see `export_download.dart`).
///
/// Compiled only for web builds (`dart.library.js_interop`), so
/// `dart:js_interop` never reaches the VM test platform. Written against the
/// SDK's `dart:js_interop` + `dart:js_interop_unsafe` only (no `package:web`:
/// the pinned transitive copy is newer than this SDK's interop surface).
/// Only [downloadBytes] and [pickTextFile] run here, and only behind the
/// dialogs' `kIsWeb` guard.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [filename].
///
/// A `Blob` + object URL + programmatic `<a download>` click (the canonical
/// Flutter-web download; `png_export.dart` only captures PNG bytes and has
/// no download path to mirror), revoked after the click.
Future<void> downloadBytes(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  final parts = <JSAny>[Uint8List.fromList(bytes).toJS];
  final options = JSObject()..['type'] = mimeType.toJS;
  final blobCtor = globalContext['Blob']! as JSFunction;
  final blob = blobCtor.callAsConstructor<JSObject>(parts.toJS, options);
  final urlApi = globalContext['URL']! as JSObject;
  final href =
      (urlApi.callMethod<JSString>('createObjectURL'.toJS, blob)).toDart;
  try {
    final document = globalContext['document']! as JSObject;
    final anchor =
        document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
    anchor['href'] = href.toJS;
    anchor['download'] = filename.toJS;
    // `body` is virtually always present in a Flutter web app; the null-aware
    // call keeps a detached document from crashing (the click still fires).
    document.getProperty<JSObject?>('body'.toJS)?.callMethod(
          'appendChild'.toJS,
          anchor,
        );
    try {
      anchor.callMethod('click'.toJS);
    } finally {
      anchor.callMethod('remove'.toJS);
    }
  } finally {
    urlApi.callMethod('revokeObjectURL'.toJS, href.toJS);
  }
}

/// Lets the user pick a `.json` text file; null when cancelled.
///
/// A temporary `<input type=file>` plus `FileReader.readAsText`, completed
/// through the input's change event (a dismissal with no file settles null).
Future<String?> pickTextFile() {
  final completer = Completer<String?>();
  void settle(String? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  void fail(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }

  final document = globalContext['document']! as JSObject;
  final input =
      document.callMethod<JSObject>('createElement'.toJS, 'input'.toJS);
  input['type'] = 'file'.toJS;
  input['accept'] = 'application/json,.json'.toJS;
  input['onchange'] = ((JSAny? _) {
    final files = input.getProperty<JSObject?>('files'.toJS);
    final file = files?.callMethod<JSObject?>('item'.toJS, 0.toJS);
    if (file == null) {
      settle(null);
      return;
    }
    final readerCtor = globalContext['FileReader']! as JSFunction;
    final reader = readerCtor.callAsConstructor<JSObject>();
    reader['onload'] = ((JSAny? _) {
      settle(reader.getProperty<JSAny?>('result'.toJS)?.dartify() as String?);
    }).toJS;
    reader['onerror'] = ((JSAny? _) {
      fail(StateError('Could not read that file.'));
    }).toJS;
    reader.callMethod('readAsText'.toJS, file);
  }).toJS;
  input.callMethod('click'.toJS);
  return completer.future;
}
