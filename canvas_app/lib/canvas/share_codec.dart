/// Share-link codec: `ScreenDoc` <-> base64url URL hash.
///
/// Pure Dart (`dart:convert` only, no Flutter imports, no `dart:io`) so the
/// codec compiles for Flutter web AND the pure-Dart CLI. Wire format:
/// base64url-encoded UTF-8 JSON carried in the URL fragment as `#d=<payload>`.
/// Deliberately uncompressed: `dart:convert` has no zlib codec and `dart:io`
/// is unavailable on web. The [kShareMaxUrlLength] guard (not compression)
/// is what keeps links shareable.
import 'dart:convert';

import 'screen_doc.dart';

/// URL fragment prefix for share links.
const String kShareFragmentPrefix = '#d=';

/// Max share-link length [encode] allows before throwing [StateError].
const int kShareMaxUrlLength = 6000;

/// Max decoded payload size [decode] accepts (200 KB).
const int kShareMaxPayloadBytes = 200 * 1024;

/// Encodes [doc] as a `#d=...` share-link fragment.
///
/// Throws [StateError] with `'doc too large for link; use file export'`
/// when the link exceeds [kShareMaxUrlLength] chars (safe URLs cap at ~8KB,
/// so large docs must use file export).
String encode(ScreenDoc doc) {
  final raw = utf8.encode(jsonEncode(doc.toJson()));
  final payload = base64Url.encode(raw);
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
/// throw [FormatException]), and rejects decoded payloads over
/// [kShareMaxPayloadBytes].
ScreenDoc decode(String link) {
  if (!link.startsWith(kShareFragmentPrefix)) {
    throw FormatException(
        'invalid share link: missing "$kShareFragmentPrefix" prefix');
  }
  final payload = link.substring(kShareFragmentPrefix.length);
  late final List<int> raw;
  try {
    raw = base64Url.decode(_normalizeBase64(payload));
  } on FormatException catch (e) {
    throw FormatException('invalid share payload: not base64url ($e)');
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
