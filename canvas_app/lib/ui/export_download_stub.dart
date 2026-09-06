/// Non-web stub for the download facade (see `export_download.dart`).
///
/// Compiled into VM tests and non-web builds; every member throws
/// [UnsupportedError] so a missed `kIsWeb` guard fails loudly instead of
/// silently doing nothing. Tests inject their own sinks and never reach here.
library;

import 'export_download.dart' show kNonWebDownloadMessage;

/// Throws [UnsupportedError] (non-web builds cannot download files).
Future<void> downloadBytes(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  throw UnsupportedError(kNonWebDownloadMessage);
}

/// Throws [UnsupportedError] (non-web builds cannot pick files).
Future<String?> pickTextFile() async {
  throw UnsupportedError(kNonWebDownloadMessage);
}
