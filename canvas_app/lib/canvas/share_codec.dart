/// Share-link codec: `ScreenDoc` <-> LZ-compressed URL hash.
///
/// Pure Dart (Dart SDK core libs only, no Flutter imports) so the CLI can
/// reuse it alongside `screen_doc.dart`. Wire format: `ZLibCodec`-compressed
/// UTF-8 JSON, base64Url-encoded, carried in the URL fragment as
/// `#d=<payload>`.
///
/// NOTE: `ZLibCodec` lives in `dart:io` (there is no zlib codec in
/// `dart:convert`), so this file imports `dart:io` in addition to
/// `dart:convert`. That keeps the CLI-reuse property (the CLI runs on the
/// Dart VM) and keeps the no-Flutter-imports gate green.
import 'dart:convert';
import 'dart:io';

import 'screen_doc.dart';

/// URL fragment prefix for share links.
const String kShareFragmentPrefix = '#d=';

/// Max share-link length [encode] allows before throwing [StateError].
const int kShareMaxUrlLength = 6000;

/// Max decompressed payload size [decode] accepts (200 KB).
const int kShareMaxPayloadBytes = 200 * 1024;

/// Encodes [doc] as a `#d=...` share-link fragment.
///
/// Throws [StateError] with `'doc too large for link; use file export'`
/// when the link exceeds [kShareMaxUrlLength] chars (gzip+base64 inflates
/// ~33% and safe URLs cap at ~8KB, so large docs must use file export).
String encode(ScreenDoc doc) {
  final raw = utf8.encode(jsonEncode(doc.toJson()));
  final payload = base64Url.encode(ZLibCodec().encode(raw));
  final link = '$kShareFragmentPrefix$payload';
  if (link.length > kShareMaxUrlLength) {
    throw StateError('doc too large for link; use file export');
  }
  return link;
}

/// Decodes a `#d=...` share-link fragment back into a [ScreenDoc].
///
/// Validates shape via [ScreenDoc.fromJson] (throws [FormatException] on
/// bad JSON) plus [ScreenDoc.validateRefs] (dangling `action.to` targets
/// throw [FormatException]), and rejects decompressed payloads over
/// [kShareMaxPayloadBytes].
ScreenDoc decode(String link) {
  if (!link.startsWith(kShareFragmentPrefix)) {
    throw FormatException(
        'invalid share link: missing "$kShareFragmentPrefix" prefix');
  }
  final payload = link.substring(kShareFragmentPrefix.length);
  late final List<int> compressed;
  try {
    compressed = base64Url.decode(_normalizeBase64(payload));
  } on FormatException catch (e) {
    throw FormatException('invalid share payload: not base64url ($e)');
  }
  late final List<int> raw;
  try {
    raw = ZLibCodec().decode(compressed);
  } catch (e) {
    throw FormatException('invalid share payload: zlib decode failed ($e)');
  }
  if (raw.length > kShareMaxPayloadBytes) {
    throw FormatException(
        'share payload too large: ${raw.length} bytes '
        '(max $kShareMaxPayloadBytes)');
  }
  late final Map<String, dynamic> json;
  try {
    json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
  } catch (e) {
    throw FormatException('invalid share payload: bad ScreenDoc JSON ($e)');
  }
  final doc = ScreenDoc.fromJson(json);
  final dangling = doc.validateRefs();
  if (dangling.isNotEmpty) {
    throw FormatException('invalid share doc: ${dangling.join(', ')}');
  }
  return doc;
}

/// Restores `=` padding stripped from a base64url payload.
String _normalizeBase64(String s) {
  final mod = s.length % 4;
  if (mod == 1) {
    throw const FormatException('invalid base64url length');
  }
  return mod == 0 ? s : s + ('=' * (4 - mod));
}
