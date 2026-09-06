/// Web file-download facade (Track R2).
///
/// `dart:js_interop` (and therefore `dart:html`/`package:web`) does not
/// compile on the Flutter VM test platform, so the real browser
/// implementation lives in `export_download_web.dart` behind this
/// conditional export: web builds (`dart.library.js_interop`) get the
/// Blob+anchor download, while VM tests and non-web builds get
/// `export_download_stub.dart`, whose members throw [UnsupportedError]
/// carrying [kNonWebDownloadMessage]. Dialogs additionally guard with a
/// `kIsWeb` check so the message renders inline instead of surfacing as an
/// exception on the happy path.
library;

export 'export_download_stub.dart'
    if (dart.library.js_interop) 'export_download_web.dart';

/// Inline notice rendered when a download or file pick is requested off-web.
///
/// Downloads/picks need the browser's Blob/anchor/file-input mechanism (see
/// `export_download_web.dart`); copy actions work on every platform.
const kNonWebDownloadMessage =
    'File downloads need a web build — copy works everywhere.';
