// Seeds a 4-step login-page user journey as ScreenDoc JSON files for
// screenshot verification plus a full-journey PDF.
//
// Usage: `dart run tool/seed_login_journey.dart <out-dir>` from canvas_app/.
// Writes login_step1.json … login_step4.json into <out-dir>.
// Plain `dart run` (no Flutter imports): like tool/seed_full_palette.dart
// this script only imports dart:convert, dart:io, and package:canvas_core.
//
// What it builds (each step is a complete valid ScreenDoc; later steps
// superset earlier ones with stable ids):
// - Step 1 `Empty canvas`: one screen 'Login' (phone, bg surface), zero
//   nodes. Theme clean-slate dark, no chrome.
// - Step 2 `Scaffold + card`: same screen + a scaffold node (title 'Login')
//   + a card node (title 'Welcome back', description 'Sign in to continue').
// - Step 3 `Inputs + button`: + an input node (label 'Email', placeholder
//   'you@example.com'), an input node (label 'Password', placeholder
//   '••••••••'), and a button node (label 'Sign in'); plus a second screen
//   'Home' (phone) with a basic node (title 'Home', content
//   'You are signed in.') — NOT yet wired (no actions).
// - Step 4 `Wired + themed`: the Sign-in button gets a tap action to Home
//   (transition 'slide'); Home gets a button 'Back to Login' to Login
//   ('fade'). Theme: components supabase light (paletteKey 'supabase', dark
//   false) with a clean-slate dark chrome override — demonstrating the
//   components/chrome split.
//
// Node props follow the exact canvas drop path in
// lib/ui/design_canvas.dart (onAccept): `findEntry(kind)` from
// lib/canvas/component_catalog.dart, then
// `Map<String, dynamic>.of(entry.defaults)`, or `{}` when the kind has
// no catalog entry. [_catalogDefaults] below mirrors those
// `CatalogEntry.defaults` maps verbatim for the five kinds used here;
// [_dropProps] mirrors the `entry == null ? {} : copy` branch. Only the
// props named in the step spec are overridden; everything else keeps the
// real catalog default (honest props — no invented names). The honest
// prop sets were verified against the builders: [_buildScaffold] reads
// `title`/`body`, [_buildCard] reads `title`/`description`/`showFooter`,
// [_buildInput] reads
// `label`/`placeholder`/`disabled`/`obscure`/`initialValue`/`readOnly`,
// [_buildButton] reads `label`/`variant`/`size`/`disabled`, and
// [_buildBasic] reads
// `title`/`subtitle`/`content`/`showLeading`/`showTrailing`.
//
// Self-validation (no checked-in JSON, no test file — see below): per
// step the script validates refs, writes the file, reads it back through
// ScreenDoc.fromJson, and asserts equal screens/nodes/items/actions
// counts, globally unique ids, plus per-step assertions (step 1: 1
// screen / 0 nodes; step 2: scaffold + card present; step 3: 2 screens,
// inputs + button present, NO actions; step 4: exactly 2 actions forming
// the Login <-> Home cycle, theme split present). Any violation fails
// non-zero. A test file was deliberately skipped: tool/ scripts run under
// plain `dart run` outside the flutter_test harness, and asserting on
// checked-in JSON snapshots would rot; the script's own round-trip + refs
// + shape checks are the verification, run on every seed.
import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';

/// Login screen id (stable across all four steps).
const _loginScreenId = 's1';

/// Home screen id (steps 3–4 only).
const _homeScreenId = 's2';

/// Catalog defaults for the five kinds used by this journey.
///
/// Mirrors `findEntry(kind)?.defaults` in
/// lib/canvas/component_catalog.dart (the `kCatalog` entries) verbatim.
const _catalogDefaults = <String, Map<String, dynamic>>{
  'button': {
    'label': 'Button',
    'variant': 'primary',
    'size': 'md',
    'disabled': false,
  },
  'card': {
    'title': 'Title',
    'description': 'Description',
    'showFooter': false,
  },
  'input': {
    'placeholder': 'Type here',
    'label': '',
    'initialValue': '',
    'disabled': false,
    'obscure': false,
    'readOnly': false,
  },
  'basic': {
    'title': 'Title',
    'subtitle': 'Subtitle',
    'content': 'Content',
    'showLeading': true,
    'showTrailing': true,
  },
  'scaffold': {'title': 'My App', 'body': 'Welcome'},
};

/// Drop-path props copy (design_canvas.dart onAccept):
/// `entry == null ? {} : Map.of(entry.defaults)`.
Map<String, dynamic> _dropProps(String kind) {
  final defaults = _catalogDefaults[kind];
  if (defaults == null) return <String, dynamic>{};
  return Map<String, dynamic>.of(defaults);
}

int _uidCounter = 0;

/// Unique node/item id in the store's `u<N>` scheme.
String _nextId() => 'u${++_uidCounter}';

/// One node with a single item of [kind] on [screenId] at flow row [row].
CanvasNode _node(
    String screenId, int row, String kind, Map<String, dynamic> props,
    [NodeAction? action]) {
  return CanvasNode(
    id: _nextId(),
    screenId: screenId,
    x: 0.0,
    y: row * 48.0,
    items: [
      CanvasItem(
        id: _nextId(),
        kind: kind,
        props: props,
        action: action,
      ),
    ],
  );
}

Map<String, dynamic> _labeled(String kind, Map<String, String> overrides) {
  final props = _dropProps(kind);
  props.addAll(overrides);
  return props;
}

/// Clean-slate dark, no chrome override (mirrors CanvasStore.emptyDoc).
const _emptyTheme = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

/// Step 4 split theme: supabase light components + clean-slate dark chrome.
const _splitTheme = CanvasTheme(
  paletteKey: 'supabase',
  dark: false,
  shape: 'rounded',
  motion: 'standard',
  chrome: CanvasTheme(
    paletteKey: 'clean-slate',
    dark: true,
    shape: 'rounded',
    motion: 'standard',
  ),
);

const _loginScreen = CanvasScreen(
  id: _loginScreenId,
  name: 'Login',
  x: 0.0,
  y: 0.0,
  bg: 'surface',
  device: 'phone',
);

const _homeScreen = CanvasScreen(
  id: _homeScreenId,
  name: 'Home',
  x: 420.0,
  y: 0.0,
  bg: 'surface',
  device: 'phone',
);

/// Step 1: empty canvas — the Login screen with zero nodes.
ScreenDoc buildLoginStep1() {
  _uidCounter = 0;
  return const ScreenDoc(
    screens: [_loginScreen],
    nodes: [],
    theme: _emptyTheme,
    meta: DocMeta(
      title: 'Login journey',
      brief: 'Step 1 — Empty canvas: a Login screen with no nodes yet.',
    ),
  );
}

/// Step 2: scaffold + card on the Login screen.
ScreenDoc buildLoginStep2() {
  _uidCounter = 0;
  return ScreenDoc(
    screens: const [_loginScreen],
    nodes: [
      _node(_loginScreenId, 0, 'scaffold',
          _labeled('scaffold', {'title': 'Login'})),
      _node(
          _loginScreenId,
          1,
          'card',
          _labeled('card', {
            'title': 'Welcome back',
            'description': 'Sign in to continue',
          })),
    ],
    theme: _emptyTheme,
    meta: const DocMeta(
      title: 'Login journey',
      brief: 'Step 2 — Scaffold + card: app shell with a welcome card.',
    ),
  );
}

/// Shared Login-screen form rows for steps 3–4 (construction order is the
/// id-stability contract: later steps superset earlier ones with the same
/// prefix ids).
List<CanvasNode> _loginFormNodes({NodeAction? signInAction}) {
  return [
    _node(_loginScreenId, 0, 'scaffold',
        _labeled('scaffold', {'title': 'Login'})),
    _node(
        _loginScreenId,
        1,
        'card',
        _labeled('card', {
          'title': 'Welcome back',
          'description': 'Sign in to continue',
        })),
    _node(
        _loginScreenId,
        2,
        'input',
        _labeled('input', {
          'label': 'Email',
          'placeholder': 'you@example.com',
        })),
    _node(
        _loginScreenId,
        3,
        'input',
        _labeled('input', {
          'label': 'Password',
          'placeholder': '••••••••',
        })),
    _node(_loginScreenId, 4, 'button', _labeled('button', {'label': 'Sign in'}),
        signInAction),
  ];
}

/// Step 3: inputs + button on Login, plus an unwired Home screen.
ScreenDoc buildLoginStep3() {
  _uidCounter = 0;
  return ScreenDoc(
    screens: const [_loginScreen, _homeScreen],
    nodes: [
      ..._loginFormNodes(),
      _node(
          _homeScreenId,
          0,
          'basic',
          _labeled('basic', {
            'title': 'Home',
            'content': 'You are signed in.',
          })),
    ],
    theme: _emptyTheme,
    meta: const DocMeta(
      title: 'Login journey',
      brief:
          'Step 3 — Inputs + button: sign-in form plus an unwired Home screen.',
    ),
  );
}

/// Step 4: wired cycle + split theme.
ScreenDoc buildLoginStep4() {
  _uidCounter = 0;
  return ScreenDoc(
    screens: const [_loginScreen, _homeScreen],
    nodes: [
      ..._loginFormNodes(
        signInAction: NodeAction(to: _homeScreenId, transition: 'slide'),
      ),
      _node(
          _homeScreenId,
          0,
          'basic',
          _labeled('basic', {
            'title': 'Home',
            'content': 'You are signed in.',
          })),
      _node(
          _homeScreenId,
          1,
          'button',
          _labeled('button', {'label': 'Back to Login'}),
          const NodeAction(to: _loginScreenId, transition: 'fade')),
    ],
    theme: _splitTheme,
    meta: const DocMeta(
      title: 'Login journey',
      brief:
          'Step 4 — Wired + themed: sign-in cycle with a split supabase/clean-slate theme.',
    ),
  );
}

int _itemCount(ScreenDoc doc) =>
    doc.nodes.fold(0, (sum, node) => sum + node.items.length);

int _actionCount(ScreenDoc doc) => doc.nodes.fold(
      0,
      (sum, node) =>
          sum + node.items.where((item) => item.action != null).length,
    );

Never _fail(String message) {
  stderr.writeln('seed_login_journey: $message');
  exit(1);
}

/// Round-trip + invariant checks shared by every step.
ScreenDoc _checkStep(ScreenDoc doc, String fileName) {
  final refs = doc.validateRefs();
  if (refs.isNotEmpty) {
    _fail('$fileName dangling refs:\n${refs.join('\n')}');
  }

  final out = File(fileName);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(doc.toJson())}\n',
  );

  late ScreenDoc back;
  try {
    back = ScreenDoc.fromJson(
      jsonDecode(out.readAsStringSync()) as Map<String, dynamic>,
    );
  } on FormatException catch (e) {
    _fail('$fileName round-trip parse failed: $e');
  }
  if (back.screens.length != doc.screens.length) {
    _fail(
      '$fileName round-trip screens mismatch: '
      '${back.screens.length} != ${doc.screens.length}',
    );
  }
  if (back.nodes.length != doc.nodes.length) {
    _fail(
      '$fileName round-trip nodes mismatch: '
      '${back.nodes.length} != ${doc.nodes.length}',
    );
  }
  if (_itemCount(back) != _itemCount(doc)) {
    _fail(
      '$fileName round-trip items mismatch: '
      '${_itemCount(back)} != ${_itemCount(doc)}',
    );
  }
  if (_actionCount(back) != _actionCount(doc)) {
    _fail(
      '$fileName round-trip actions mismatch: '
      '${_actionCount(back)} != ${_actionCount(doc)}',
    );
  }
  if (back.validateRefs().isNotEmpty) {
    _fail(
      '$fileName round-trip refs mismatch: '
      '${back.validateRefs().join(', ')}',
    );
  }

  // Global id uniqueness across screens, nodes, and items.
  final seen = <String>{};
  final duplicates = <String>[];
  void take(String id) {
    if (!seen.add(id)) duplicates.add(id);
  }

  for (final screen in back.screens) {
    take(screen.id);
  }
  for (final node in back.nodes) {
    take(node.id);
    for (final item in node.items) {
      take(item.id);
    }
  }
  if (duplicates.isNotEmpty) {
    _fail('$fileName duplicate ids: ${duplicates.join(', ')}');
  }

  if (back.meta.title != 'Login journey') {
    _fail('$fileName meta.title should be Login journey');
  }
  return back;
}

Set<String> _kindsOn(ScreenDoc doc, String screenId) => {
      for (final node in doc.nodes)
        if (node.screenId == screenId)
          for (final item in node.items) item.kind,
    };

String _prop(ScreenDoc doc, String screenId, String kind, String key) {
  for (final node in doc.nodes) {
    if (node.screenId != screenId) continue;
    for (final item in node.items) {
      if (item.kind == kind && item.props.containsKey(key)) {
        return '${item.props[key]}';
      }
    }
  }
  _fail('prop $key on $kind ($screenId) missing');
}

bool _hasAction(ScreenDoc doc, String from, String to, String transition) =>
    doc.nodes.any(
      (node) =>
          node.screenId == from &&
          node.items.any((item) =>
              item.action?.to == to && item.action?.transition == transition),
    );

void _checkStep1(ScreenDoc back) {
  if (back.screens.length != 1 || back.nodes.isNotEmpty) {
    _fail(
      'step1 expected 1 screen / 0 nodes, found '
      '${back.screens.length} screens / ${back.nodes.length} nodes',
    );
  }
  final screen = back.screens.single;
  if (screen.name != 'Login' || screen.bg != 'surface') {
    _fail('step1 screen should be Login/surface');
  }
  if (screen.device != 'phone') {
    _fail('step1 screen device should be phone');
  }
  if (back.theme.chrome != null ||
      back.theme.paletteKey != 'clean-slate' ||
      !back.theme.dark) {
    _fail('step1 theme should be clean-slate dark with no chrome');
  }
}

void _checkStep2(ScreenDoc back) {
  if (back.screens.length != 1 || back.nodes.length != 2) {
    _fail(
      'step2 expected 1 screen / 2 nodes, found '
      '${back.screens.length} screens / ${back.nodes.length} nodes',
    );
  }
  final kinds = _kindsOn(back, _loginScreenId);
  if (!kinds.containsAll({'scaffold', 'card'})) {
    _fail('step2 scaffold+card missing: ${kinds.join(', ')}');
  }
  if (_prop(back, _loginScreenId, 'scaffold', 'title') != 'Login') {
    _fail('step2 scaffold title should be Login');
  }
  if (_prop(back, _loginScreenId, 'card', 'title') != 'Welcome back' ||
      _prop(back, _loginScreenId, 'card', 'description') !=
          'Sign in to continue') {
    _fail('step2 card title/description mismatch');
  }
  if (_actionCount(back) != 0) {
    _fail('step2 should have no actions');
  }
}

void _checkStep3(ScreenDoc back) {
  if (back.screens.length != 2 || back.nodes.length != 6) {
    _fail(
      'step3 expected 2 screens / 6 nodes, found '
      '${back.screens.length} screens / ${back.nodes.length} nodes',
    );
  }
  final loginKinds = _kindsOn(back, _loginScreenId);
  if (!loginKinds.containsAll({'scaffold', 'card', 'input', 'button'})) {
    _fail('step3 login kinds incomplete: ${loginKinds.join(', ')}');
  }
  final emailNodes = [
    for (final node in back.nodes)
      if (node.screenId == _loginScreenId)
        for (final item in node.items)
          if (item.kind == 'input') item,
  ];
  if (emailNodes.length != 2) {
    _fail('step3 expected 2 inputs, found ${emailNodes.length}');
  }
  final labels = {for (final item in emailNodes) '${item.props['label']}'};
  if (!labels.containsAll({'Email', 'Password'})) {
    _fail('step3 input labels mismatch: ${labels.join(', ')}');
  }
  if (_kindsOn(back, _homeScreenId).single != 'basic') {
    _fail('step3 Home should hold only the basic node');
  }
  if (_prop(back, _homeScreenId, 'basic', 'title') != 'Home' ||
      _prop(back, _homeScreenId, 'basic', 'content') != 'You are signed in.') {
    _fail('step3 Home basic title/content mismatch');
  }
  if (_actionCount(back) != 0) {
    _fail('step3 should have NO actions (not yet wired)');
  }
}

void _checkStep4(ScreenDoc back) {
  if (back.screens.length != 2 || back.nodes.length != 7) {
    _fail(
      'step4 expected 2 screens / 7 nodes, found '
      '${back.screens.length} screens / ${back.nodes.length} nodes',
    );
  }
  if (_actionCount(back) != 2) {
    _fail('step4 expected exactly 2 actions, found ${_actionCount(back)}');
  }
  if (!_hasAction(back, _loginScreenId, _homeScreenId, 'slide')) {
    _fail('step4 Sign-in leg (Login -> Home, slide) missing');
  }
  if (!_hasAction(back, _homeScreenId, _loginScreenId, 'fade')) {
    _fail('step4 Back leg (Home -> Login, fade) missing');
  }
  if (back.theme.paletteKey != 'supabase' ||
      back.theme.dark ||
      back.theme.chrome == null ||
      back.theme.chrome!.paletteKey != 'clean-slate' ||
      !back.theme.chrome!.dark) {
    _fail('step4 theme split (supabase light + clean-slate dark) missing');
  }
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/seed_login_journey.dart <out-dir>',
    );
    exit(2);
  }

  final steps = <String, ScreenDoc>{
    'login_step1.json': buildLoginStep1(),
    'login_step2.json': buildLoginStep2(),
    'login_step3.json': buildLoginStep3(),
    'login_step4.json': buildLoginStep4(),
  };
  final checks = <String, void Function(ScreenDoc)>{
    'login_step1.json': _checkStep1,
    'login_step2.json': _checkStep2,
    'login_step3.json': _checkStep3,
    'login_step4.json': _checkStep4,
  };

  for (final entry in steps.entries) {
    final path = '${args[0]}/${entry.key}';
    final back = _checkStep(entry.value, path);
    checks[entry.key]!(back);
    stdout.writeln(
      '${entry.key}: ${back.screens.length} screens, '
      '${back.nodes.length} nodes '
      '(${_itemCount(back)} items), '
      '${_actionCount(back)} actions '
      '(refs clean, round-trip ok)',
    );
  }
}
