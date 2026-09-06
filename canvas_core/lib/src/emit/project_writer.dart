/// G1 scaffold (Track G prep): `out/` project writer per BUILD_SPEC §8.4.
///
/// ```
/// out/
/// ├─ pubspec.yaml              # flutter_shadcn_kit + only what's used
/// ├─ analysis_options.yaml     # flutter_lints
/// ├─ web/                      # index.html + manifest.json + icons (gate 5)
/// ├─ lib/
/// │  ├─ main.dart              # MaterialApp.router + theme
/// │  ├─ theme/app_theme.dart   # tokens from the doc's theme
/// │  ├─ routes/app_router.dart # go_router, one route per screen
/// │  └─ pages/<screen>/<screen>_page.dart (+ _model.dart when stateful)
/// └─ assets/
/// ```
///
/// Widget/Model split (§2.2.3, §8.4): stateless pages are `StatelessWidget`
/// with NO model file (never an empty model class); stateful pages
/// (any text_field / switch / checkbox / tabs / page-controller) get a
/// `StatefulWidget` + `{Page}Model` with `initState`/`dispose`.
///
/// Responsive leaf-value rule (§8.4): differences collapse to
/// `responsiveValue(context, base:, md:)` at the leaf — never duplicated
/// subtrees. [responsiveLeaf] is the single constructor for that call.
///
/// This file emits static project shells as text (pubspec, router, theme);
/// page BODIES delegate to the [EmitterRegistry] in G2. Shell text is
/// scaffolding, not goldens: golden-first (§6.5) applies to emitter output,
/// and no golden is ever generated from an emitter.
library;

import 'package:archive/archive.dart';

import '../screen_doc.dart';
import 'emit_context.dart';

/// One file of the emitted project.
///
/// Text files carry [content]; binary files (web icons) carry [bytes] with
/// an empty [content] — writers branch on [isBinary]. The constructor stays
/// positional for text so every existing call site is untouched.
class ProjectOutFile {
  final String path;
  final String content;

  /// Raw bytes for binary files (see [isBinary]).
  final List<int>? bytes;

  const ProjectOutFile(this.path, this.content, {this.bytes});

  /// Whether this file must be written as bytes, not text.
  bool get isBinary => bytes != null;
}

/// The §8.4 Flutter import owned by the page shell (never by the collector).
/// The shell skips collector lines starting with `import '<this>'` — the
/// bare line and every combinator variant share that prefix.
const _kFlutterMaterial = 'package:flutter/material.dart';

/// Kinds whose presence anywhere on a page forces a `{Page}Model`
/// (StatefulWidget + initState/dispose — §8.4).
///
/// The certain core (spec text): text_field, switch, checkbox, tabs.
/// Provisional page-controller set (G2 verifies each against the migrated
/// emitter before pinning): carousel, swiper, tab_container. `text_area`
/// is a TextField variant (controller) — G3 confirms when its emitter
/// migrates.
const Set<String> kStatefulKinds = {
  'text_field',
  'text_area',
  'switch',
  'checkbox',
  'tabs',
  'tab_container',
  'carousel',
  'swiper',
};

/// Kinds certain per the spec text (no provisional members).
const Set<String> kCertainStatefulKinds = {
  'text_field',
  'switch',
  'checkbox',
  'tabs',
};

/// Whether a page using [kinds] needs a `{Page}Model`.
bool needsModel(Iterable<String> kinds) =>
    kinds.any(kStatefulKinds.contains);

/// Whole-screen item kinds for [screenId] in document order, deduped.
///
/// Mirrors the legacy screen walk: roots AND nested children count — a
/// `text_field` nested inside a `container` still forces a model. THAT is
/// the primitives-aware part of detection: layout wrappers never hide
/// stateful leaves from [needsModel].
List<String> pageKindsFor(ScreenDoc doc, String screenId) {
  final seen = <String>[];
  for (final node in doc.nodes) {
    if (node.screenId != screenId) continue;
    for (final item in node.items) {
      if (!seen.contains(item.kind)) seen.add(item.kind);
    }
  }
  return seen;
}

/// Planned `{Page}Model` fields: text controllers + bool state fields.
typedef PageModelPlan = ({
  List<String> controllers,
  List<String> bools,
});

/// Allocates model field names for a screen's stateful items (doc order,
/// via [names] so repeated ids stay unique): `text_field`/`text_area` gain
/// a `<id>Controller`, `switch`/`checkbox` gain a `<id>` bool.
///
/// `tabs`/`tab_container`/`carousel`/`swiper` force a model via [needsModel]
/// but get NO fields in v1 — their controllers arrive with the kit emitters
/// in G3 (a stateful page with an empty plan still emits its model shell so
/// the page's `model` reference resolves).
PageModelPlan planModelFields(
  ScreenDoc doc,
  String screenId,
  NameAllocator names,
) {
  final controllers = <String>[];
  final bools = <String>[];
  for (final node in doc.nodes) {
    if (node.screenId != screenId) continue;
    for (final item in node.items) {
      switch (item.kind) {
        case 'text_field':
        case 'text_area':
          controllers.add(names.allocate('${item.id}Controller'));
        case 'switch':
        case 'checkbox':
          bools.add(names.allocate(item.id));
      }
    }
  }
  return (controllers: controllers, bools: bools);
}

/// The §8.4 responsive leaf over doc tiers: values branch, subtrees never
/// duplicate. Mobile-first: [base] IS the mobile value; `tablet` feeds the
/// `md:` slot, `desktop` is the fallback. Tiers beyond one `md:` override
/// (and non-leaf subtree branching) are G3 — this stays the single
/// constructor for the call.
String responsiveLeafValue({
  required String base,
  required Map<String, String> tierCodes,
}) {
  final md = tierCodes['tablet'] ?? tierCodes['desktop'];
  return responsiveLeaf(base: base, md: md);
}

/// An emitted page: the page file, plus the model file when stateful.
typedef EmittedPage = ({ProjectOutFile page, ProjectOutFile? model});

/// Assembles one §8.4 page from caller-supplied [body] (canonical depth-0
/// widget source: first line bare after `return `, later lines +4 — see
/// `expr_emitter._shiftForReturn`).
///
/// Wiring done HERE so callers cannot get it wrong: [needsModel] over [kinds]
/// picks Stateless vs Stateful+Model; [imports] (an [ImportCollector] the
/// emitters wrote to — priority (a)) supplies every header line beyond the
/// shell-owned material import; [modelPlan] (or an empty plan) feeds the
/// model shell. Stateless pages get NO model file (no empty-model ceremony).
///
/// Clash hygiene (gates 4–5 DEFECT-1): the shell owns the single material
/// import, but the HIDES on it come from the collector (kit-wins names the
/// used G3 kinds registered via `ImportCollector.add(..., hide:)`), read via
/// [ImportCollector.hideFor] — the collector stays the single source of
/// clash knowledge; callers never hand-merge hide lists. [includeMaterial]
/// drops the material import entirely on pages where every used name also
/// resolves through the kit barrel (the analyzer's `unnecessary_import`
/// rule — the walker computes this from the closed body vocabulary, see
/// `expr_emitter`); it defaults to true so bare-collector callers keep the
/// historical header byte-identically.
EmittedPage emitPage({
  required String slug,
  required Iterable<String> kinds,
  required String body,
  ImportCollector? imports,
  PageModelPlan? modelPlan,
  bool includeMaterial = true,
}) {
  final flag = needsModel(kinds);
  final importLines = <String>[];
  var flutterHide = const <String>[];
  if (imports != null) {
    flutterHide = imports.hideFor(_kFlutterMaterial).toList()..sort();
    for (final line in imports.lines) {
      // The shell owns the material import (see buildPageFile); the
      // collector still declares it (adapters add it, G3 kinds add hides
      // to it) so Directive rendering and kind-level auditing stay
      // complete. Prefix-match: the collector line may carry combinators
      // (this prefix matches only the material URL's own lines — every
      // other URL sorts elsewhere in the collector).
      if (line.startsWith("import '$_kFlutterMaterial'")) continue;
      importLines.add(line);
    }
  }
  final page = ProjectOutFile(
    pageFilePath(slug),
    buildPageFile(
      slug: slug,
      needsModelFlag: flag,
      body: body,
      importLines: importLines,
      flutterHide: flutterHide,
      includeMaterial: includeMaterial,
    ),
  );
  if (!flag) return (page: page, model: null);
  final plan =
      modelPlan ?? (controllers: const <String>[], bools: const <String>[]);
  return (
    page: page,
    model: ProjectOutFile(
      modelFilePath(slug),
      buildModelFile(
        slug: slug,
        controllerNames: plan.controllers,
        boolFields: plan.bools,
      ),
    ),
  );
}

/// `Login Screen` → `login_screen`; guards leading digits and empties.
String slugifyScreen(String name) {
  var slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (slug.isEmpty) slug = 'screen';
  if (RegExp(r'^[0-9]').hasMatch(slug)) slug = 'screen_$slug';
  return slug;
}

/// `login_screen` → `LoginScreenPage`.
String pageClassName(String slug) =>
    '${_pascal(slug)}Page';

/// `login_screen` → `LoginScreenModel`.
String modelClassName(String slug) => '${_pascal(slug)}Model';

String _pascal(String slug) => slug
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join();

/// `pages/login_screen/login_screen_page.dart`.
String pageFilePath(String slug) => 'lib/pages/$slug/${slug}_page.dart';

/// `pages/login_screen/login_screen_model.dart`.
String modelFilePath(String slug) => 'lib/pages/$slug/${slug}_model.dart';

/// Builds the single responsive leaf call (§8.4): differences live in the
/// VALUE, never in duplicated subtrees.
String responsiveLeaf({required String base, String? md}) {
  if (md == null || md == base) return base;
  return 'responsiveValue(context, base: $base, md: $md)';
}

/// Emitted pubspec: `flutter_shadcn_kit` always; `go_router` only when the
/// project has >1 screen (only what's used — §8.4).
String buildPubspec({
  required String appName,
  required int screenCount,
  Set<String> assets = const {},
}) {
  final buffer = StringBuffer()
    ..writeln('name: $appName')
    ..writeln('description: Generated by the Canvas visual builder.')
    ..writeln('publish_to: none')
    ..writeln('version: 0.1.0')
    ..writeln()
    ..writeln('environment:')
    ..writeln("  sdk: '>=3.3.0 <4.0.0'")
    ..writeln()
    ..writeln('dependencies:')
    ..writeln('  flutter:')
    ..writeln('    sdk: flutter')
    ..writeln('  flutter_shadcn_kit: ^1.0.0');
  if (screenCount > 1) buffer.writeln('  go_router: ^14.0.0');
  if (assets.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('flutter:')
      ..writeln('  assets:');
    final sorted = assets.toList()..sort();
    for (final a in sorted) {
      buffer.writeln('    - $a');
    }
  }
  buffer
    ..writeln()
    ..writeln('dev_dependencies:')
    ..writeln('  flutter_lints: ^4.0.0');
  return buffer.toString();
}

/// Emitted analysis options: `flutter_lints`, zero-issue gate (§11.4).
String buildAnalysisOptions() =>
    'include: package:flutter_lints/flutter.yaml\n';

/// Emitted theme shell: tokens come from the doc's theme in G2
/// (`CanvasTheme.paletteKey/dark/shape/motion`); G1 pins the structure.
/// Const-correct (gate 4 `prefer_const_declarations`): the scheme binds
/// with `const`, not `final … = const …`.
String buildAppTheme(CanvasTheme theme) => '''
import 'package:flutter/material.dart';

/// Generated theme shell (tokens from palette `${theme.paletteKey}`,
/// ${theme.dark ? 'dark' : 'light'}). G2 binds real token values.
ThemeData buildAppTheme() {
  const scheme = ${theme.dark ? 'ColorScheme.dark()' : 'ColorScheme.light()'};
  return ThemeData(colorScheme: scheme, useMaterial3: true);
}
''';

/// Emitted router shell: go_router, one route per screen (§8.4).
String buildAppRouter(List<CanvasScreen> screens) {
  final buffer = StringBuffer()
    ..writeln("import 'package:go_router/go_router.dart';");
  for (final s in screens) {
    final slug = slugifyScreen(s.name);
    buffer.writeln(
      "import '../pages/$slug/${slug}_page.dart';",
    );
  }
  buffer
    ..writeln()
    ..writeln('final appRouter = GoRouter(')
    ..writeln('  initialLocation: \'/${slugifyScreen(screens.first.name)}\',')
    ..writeln('  routes: [');
  for (final s in screens) {
    final slug = slugifyScreen(s.name);
    buffer
      ..writeln('    GoRoute(')
      ..writeln("      path: '/$slug',")
      ..writeln(
        '      builder: (context, state) => const ${pageClassName(slug)}(),',
      )
      ..writeln('    ),');
  }
  buffer
    ..writeln('  ],')
    ..writeln(');');
  return buffer.toString();
}

/// Emitted main.dart shell: `MaterialApp.router` + theme (§8.4).
/// Format-canonical (gate 3): a blank line separates the import block from
/// `void main()` in BOTH variants (the router import is conditional, so the
/// blank line is structural, not templated adjacency — DEFECT-3).
String buildMainDart({required bool hasRouter}) {
  final buffer = StringBuffer()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln("import 'theme/app_theme.dart';");
  if (hasRouter) buffer.writeln("import 'routes/app_router.dart';");
  buffer
    ..writeln()
    ..writeln('void main() => runApp(const GeneratedApp());')
    ..writeln()
    ..writeln('class GeneratedApp extends StatelessWidget {')
    ..writeln('  const GeneratedApp({super.key});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Widget build(BuildContext context) {')
    ..writeln(
      hasRouter
          ? '    return MaterialApp.router(routerConfig: appRouter, theme: buildAppTheme());'
          : '    return MaterialApp(theme: buildAppTheme());',
    )
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}

/// Page shell. [body] is the emitted widget tree (G2 supplies it via the
/// emitter registry); [needsModel] selects Stateless vs Stateful+Model.
/// Stateless pages get NO model file (§8.4 — no empty-model ceremony).
/// [flutterHide] renders the `hide` clause on the shell-owned material
/// import (kit-wins names from the used kinds — gates 4–5 DEFECT-1); empty
/// keeps the bare import byte-identical. [includeMaterial] false omits the
/// material import (kit-covered pages — the analyzer flags the leftover as
/// `unnecessary_import`, so the shell must not emit it).
String buildPageFile({
  required String slug,
  required bool needsModelFlag,
  required String body,
  required List<String> importLines,
  List<String> flutterHide = const [],
  bool includeMaterial = true,
}) {
  final page = pageClassName(slug);
  final buffer = StringBuffer();
  if (includeMaterial) {
    if (flutterHide.isEmpty) {
      buffer.writeln("import 'package:flutter/material.dart';");
    } else {
      final sorted = [...flutterHide]..sort();
      buffer.writeln(
        "import 'package:flutter/material.dart' hide ${sorted.join(', ')};",
      );
    }
  }
  for (final line in importLines) {
    buffer.writeln(line);
  }
  if (needsModelFlag) {
    buffer.writeln("import '${slug}_model.dart';");
  }
  buffer.writeln();
  if (!needsModelFlag) {
    buffer
      ..writeln('class $page extends StatelessWidget {')
      ..writeln('  const $page({super.key});')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Widget build(BuildContext context) {')
      ..writeln('    return $body;')
      ..writeln('  }')
      ..writeln('}');
    return buffer.toString();
  }
  final model = modelClassName(slug);
  buffer
    ..writeln('class $page extends StatefulWidget {')
    ..writeln('  const $page({super.key});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  State<$page> createState() => _${page}State();')
    ..writeln('}')
    ..writeln()
    ..writeln('class _${page}State extends State<$page> {')
    ..writeln('  late final $model model;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void initState() {')
    ..writeln('    super.initState();')
    ..writeln('    model = $model();')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void dispose() {')
    ..writeln('    model.dispose();')
    ..writeln('    super.dispose();')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Widget build(BuildContext context) {')
    ..writeln('    return $body;')
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}

/// `{Page}Model` shell: controllers + initState/dispose (§8.4 example).
/// [controllerNames] are pre-allocated via [NameAllocator] in G2.
String buildModelFile({
  required String slug,
  required List<String> controllerNames,
  required List<String> boolFields,
}) {
  final model = modelClassName(slug);
  final buffer = StringBuffer()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('class $model extends ChangeNotifier {');
  for (final c in controllerNames) {
    buffer.writeln('  final $c = TextEditingController();');
  }
  for (final b in boolFields) {
    buffer.writeln('  bool $b = false;');
  }
  buffer
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void dispose() {');
  for (final c in controllerNames) {
    buffer.writeln('    $c.dispose();');
  }
  buffer
    ..writeln('    super.dispose();')
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}

/// Assembles the static project shells (G1): pubspec, analysis options,
/// main, theme, router, plus the `web/` scaffold (gate 5 — see
/// [buildWebScaffold]). Page files arrive in G2 with emitter bodies.
List<ProjectOutFile> scaffoldProject({
  required String appName,
  required ScreenDoc doc,
  Set<String> assets = const {},
}) {
  final screens = doc.screens;
  final package = slugifyScreen(
    doc.meta.title.isEmpty ? appName : doc.meta.title,
  );
  final hasRouter = screens.length > 1;
  return [
    ProjectOutFile(
      'pubspec.yaml',
      buildPubspec(
        appName: package,
        screenCount: screens.length,
        assets: assets,
      ),
    ),
    const ProjectOutFile(
      'analysis_options.yaml',
      'include: package:flutter_lints/flutter.yaml\n',
    ),
    ProjectOutFile('lib/main.dart', buildMainDart(hasRouter: hasRouter)),
    ProjectOutFile('lib/theme/app_theme.dart', buildAppTheme(doc.theme)),
    if (hasRouter)
      ProjectOutFile('lib/routes/app_router.dart', buildAppRouter(screens)),
    ...buildWebScaffold(appName: package),
  ];
}

// ---------------------------------------------------------------------------
// web/ scaffold (gate 5 — DEFECT-4).
// ---------------------------------------------------------------------------

/// `web/` scaffold mirror: the exact file SET `flutter create --platforms
/// web` produces on the measured SDK (Flutter 3.47.2) — `index.html`,
/// `manifest.json`, `favicon.png`, and the four `icons/Icon-*.png` files
/// the manifest references — so raw writer output runs `flutter build web`
/// with no extra `flutter create` step.
///
/// `index.html`/`manifest.json` mirror the tool-author shape with the
/// project [appName] interpolated (title, apple-touch title, manifest
/// name/short_name). Icons are deterministic solid-color PNGs synthesized
/// by [webIconPng] at the manifest-declared sizes in the manifest's own
/// theme blue (`#0175C2` — full-bleed solid is maskable-safe); they are
/// launch placeholders, not brand assets, exactly like the tool's
/// Flutter-logo defaults. `flutter_bootstrap.js` is deliberately NOT
/// emitted — the build generates it (everything the tool derives at build
/// time stays out of the writer).
List<ProjectOutFile> buildWebScaffold({required String appName}) => [
      ProjectOutFile(
        'web/index.html',
        buildWebIndexHtml(appName: appName),
      ),
      ProjectOutFile(
        'web/manifest.json',
        buildWebManifest(appName: appName),
      ),
      ProjectOutFile('web/favicon.png', '', bytes: webIconPng(16)),
      ProjectOutFile(
        'web/icons/Icon-192.png',
        '',
        bytes: webIconPng(192),
      ),
      ProjectOutFile(
        'web/icons/Icon-512.png',
        '',
        bytes: webIconPng(512),
      ),
      ProjectOutFile(
        'web/icons/Icon-maskable-192.png',
        '',
        bytes: webIconPng(192),
      ),
      ProjectOutFile(
        'web/icons/Icon-maskable-512.png',
        '',
        bytes: webIconPng(512),
      ),
    ];

/// `web/index.html`: the tool-author bootstrap shape
/// (`$FLUTTER_BASE_HREF` placeholder, `flutter_bootstrap.js` loader),
/// with the project name + generated description interpolated.
String buildWebIndexHtml({required String appName}) => '''
<!DOCTYPE html>
<html>
<head>
  <!--
    If you are serving your web app in a path other than the root, change the
    href value below to reflect the base path you are serving from.

    The path provided below has to start and end with a slash "/" in order for
    it to work correctly.

    For more details:
    * https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base

    This is a placeholder for base href that will be replaced by the value of
    the `--base-href` argument provided to `flutter build`.
  -->
  <base href="\$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Generated by the Canvas visual builder.">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="$appName">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>$appName</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

/// `web/manifest.json`: the tool-author manifest shape (standalone,
/// portrait-primary, theme blue `#0175C2`) with the project name +
/// generated description interpolated. Icon entries reference the
/// [buildWebScaffold] PNGs at their declared sizes.
String buildWebManifest({required String appName}) => '''
{
    "name": "$appName",
    "short_name": "$appName",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#0175C2",
    "theme_color": "#0175C2",
    "description": "Generated by the Canvas visual builder.",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ]
}
''';

/// Deterministic solid-color PNG (8-bit RGBA, filter-none scanlines,
/// zlib IDAT via `package:archive` — the dependency `codegen_bundle.dart`
/// already uses, so no new dependency and no `dart:io`, keeping
/// `canvas_core` web-safe) at [size]×[size] for the web icons. The default
/// color is the manifest theme blue. Validated by the format's own
/// structure (signature + IHDR dimensions are test-pinned).
List<int> webIconPng(int size, {int r = 0x01, int g = 0x75, int b = 0xC2}) {
  final raw = <int>[];
  for (var y = 0; y < size; y++) {
    raw.add(0);
    for (var x = 0; x < size; x++) {
      raw.addAll([r, g, b, 0xFF]);
    }
  }
  final compressed = const ZLibEncoder().encode(raw);

  final ihdr = <int>[
    ..._u32be(size),
    ..._u32be(size),
    8, // bit depth
    6, // color type: truecolor with alpha
    0, // compression: deflate
    0, // filter: adaptive (scanlines already carry filter 0)
    0, // interlace: none
  ];
  return [
    137, 80, 78, 71, 13, 10, 26, 10, // PNG signature
    ..._pngChunk('IHDR', ihdr),
    ..._pngChunk('IDAT', compressed),
    ..._pngChunk('IEND', const []),
  ];
}

/// Big-endian 4-byte encoding for PNG length/CRC/IHDR fields.
List<int> _u32be(int v) =>
    [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

/// One PNG chunk: length + type + data + CRC32 over type+data.
List<int> _pngChunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final crc = _crc32([...typeBytes, ...data]);
  return [..._u32be(data.length), ...typeBytes, ...data, ..._u32be(crc)];
}

/// Bitwise CRC32 (IEEE): table-free so the encoder stays dependency-free;
/// generation is a one-shot per export, so the bitwise cost (~1M simple
/// ops for the 512px icon) never sits on a hot path.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
