// Seeds the Wander travel-app demo as a ScreenDoc JSON file for the
// Forge-redesign showcase + screenshots.
//
// Usage: `dart run tool/seed_wander.dart <out.json>` from canvas_app/.
// Writes a single ScreenDoc JSON file to <out.json>.
// Plain `dart run` (no Flutter imports): like tool/seed_login_journey.dart
// this script only imports dart:convert, dart:io, and package:canvas_core.
//
// What it builds (one complete valid ScreenDoc, 3 screens, 18 nodes):
// - Home `Wander` (phone, bg surface): avatar header (initials 'WD') + basic
//   header (title 'Wander', subtitle 'Explore') + hero card_image ('Kyoto in
//   autumn' + rating/saves stats) + input search stub (read-only) + a row
//   container with 3 stat badges ('12 trips', '48 saved', '9 countries') +
//   primary CTA button ('Explore stays' -> Search, 'slide') + bottom
//   navigation_bar (index 0 -> Search, 'fade').
// - Search (phone, bg surface): input ('Search' / 'Try Kyoto or Lisbon') +
//   3 basic destination rows (Kyoto, Lisbon, Marrakech) + bottom
//   navigation_bar (index 1 -> Saved, 'fade').
// - Saved (phone, bg surface): 2 saved-trip cards + bottom navigation_bar
//   (index 2 -> Home, 'fade').
//
// The bottom bar is the Track Y1 `navigation_bar` builder (real kit
// `NavigationBar` + 4 `NavigationItem` destinations: Home/Search/Saved/You).
// Tap granularity note: canvas items carry a single tap action (the
// preview-player wraps the whole node in one tap catcher — the same
// single-action-per-node contract as the tabs builder), so each screen's
// bar node wires ONE action; the three bar actions form a Home -> Search ->
// Saved -> Home cycle (plus the Explore CTA), keeping the tap graph
// connected. Per-destination actions would need player-level support and are
// out of scope. The 4th destination ('You') has no screen by design.
//
// Theme: clean-slate dark, no chrome — matching the current editor default
// (CanvasStore.emptyDoc) so the demo screenshots well on today's chrome.
// A Forge-light re-theme is a documented follow-up, not part of this seed.
//
// Node props follow the exact canvas drop path in
// lib/ui/design_canvas.dart (onAccept): `findEntry(kind)` from
// lib/canvas/component_catalog.dart, then
// `Map<String, dynamic>.of(entry.defaults)`, or `{}` when the kind has
// no catalog entry. [_catalogDefaults] below mirrors those
// `CatalogEntry.defaults` maps verbatim for the eight kinds used here;
// [_dropProps] mirrors the `entry == null ? {} : copy` branch. Only the
// props named in the spec are overridden; everything else keeps the real
// catalog default (honest props — no invented names). The `row` container
// takes the drop path's row branch (a container node with no items, like
// `CanvasStore.addRow` creates); the 3 badges attach via `parentId`.
//
// Self-validation (no checked-in JSON, no test file — seed-script
// convention, same as seed_login_journey.dart): the script validates refs,
// writes the file, reads it back through ScreenDoc.fromJson, and asserts
// equal screens/nodes/items/actions counts, globally unique ids, zero
// placeholder/unknown kinds (every used kind is asserted to have a real
// builder — see [_realBuilderKinds]), and a connected tap graph (all 3
// screens reachable from Home). Any violation fails non-zero.
import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';

/// Home screen id.
const _homeScreenId = 's1';

/// Search screen id.
const _searchScreenId = 's2';

/// Saved screen id.
const _savedScreenId = 's3';

/// Kinds with real builders used by this demo.
///
/// Verified canvas-ready on 2026-09-06: every kind below resolves via
/// `findEntry(kind)` in lib/canvas/component_catalog.dart (real bare-widget
/// builder, no placeholder) — including `navigation_bar` (Track Y1 builder:
/// kit `NavigationBar` + `NavigationItem`s). The `row` container is
/// structural (isRow, no items; registry canvasReady structural builder).
/// Anything else fails validation as a placeholder/unknown kind.
const _realBuilderKinds = <String>{
  'avatar',
  'basic',
  'card_image',
  'input',
  'badge',
  'button',
  'card',
  'navigation_bar',
};

/// Catalog defaults for the eight kinds used by this demo.
///
/// Mirrors `findEntry(kind)?.defaults` in
/// lib/canvas/component_catalog.dart (the `kCatalog` entries) verbatim.
const _catalogDefaults = <String, Map<String, dynamic>>{
  'avatar': {'initials': 'AB', 'size': 40.0},
  'basic': {
    'title': 'Title',
    'subtitle': 'Subtitle',
    'content': 'Content',
    'showLeading': true,
    'showTrailing': true,
  },
  'card_image': {'title': 'Card title', 'subtitle': 'Card subtitle'},
  'input': {
    'placeholder': 'Type here',
    'label': '',
    'initialValue': '',
    'disabled': false,
    'obscure': false,
    'readOnly': false,
  },
  'badge': {'label': 'Badge', 'variant': 'primary'},
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
  'navigation_bar': {
    'tab1': 'Home',
    'tab2': 'Search',
    'tab3': 'Saved',
    'tab4': 'You',
    'index': 0,
  },
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
    [NodeAction? action, String? parentId]) {
  return CanvasNode(
    id: _nextId(),
    screenId: screenId,
    x: 0.0,
    y: row * 48.0,
    parentId: parentId,
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

Map<String, dynamic> _mixed(String kind, Map<String, Object> overrides) {
  final props = _dropProps(kind);
  props.addAll(overrides);
  return props;
}

/// Clean-slate dark, no chrome override (mirrors CanvasStore.emptyDoc and
/// the current editor default — screenshots well on today's chrome; the
/// Forge-light re-theme is a follow-up).
const _wanderTheme = CanvasTheme(
  paletteKey: 'clean-slate',
  dark: true,
  shape: 'rounded',
  motion: 'standard',
);

const _homeScreen = CanvasScreen(
  id: _homeScreenId,
  name: 'Home',
  x: 0.0,
  y: 0.0,
  bg: 'surface',
  device: 'phone',
);

const _searchScreen = CanvasScreen(
  id: _searchScreenId,
  name: 'Search',
  x: 420.0,
  y: 0.0,
  bg: 'surface',
  device: 'phone',
);

const _savedScreen = CanvasScreen(
  id: _savedScreenId,
  name: 'Saved',
  x: 840.0,
  y: 0.0,
  bg: 'surface',
  device: 'phone',
);

/// Builds the full Wander demo doc.
ScreenDoc buildWander() {
  _uidCounter = 0;
  final nodes = <CanvasNode>[];

  // Home screen.
  var row = 0;
  nodes.add(_node(
      _homeScreenId, row++, 'avatar', _labeled('avatar', {'initials': 'WD'})));
  nodes.add(_node(
      _homeScreenId,
      row++,
      'basic',
      _mixed('basic', {
        'title': 'Wander',
        'subtitle': 'Explore',
        'content': 'Near and far',
        'showLeading': false,
        'showTrailing': false,
      })));
  nodes.add(_node(
      _homeScreenId,
      row++,
      'card_image',
      _labeled('card_image', {
        'title': 'Kyoto in autumn',
        'subtitle': '4.9 rating · 2.3k saves',
      })));
  nodes.add(_node(
      _homeScreenId,
      row++,
      'input',
      _mixed('input', {
        'placeholder': 'Search destinations',
        'readOnly': true,
      })));
  // 3-stat row: structural row container + 3 parented badge tiles.
  final statsRowId = _nextId();
  nodes.add(CanvasNode(
    id: statsRowId,
    screenId: _homeScreenId,
    x: 0.0,
    y: row++ * 48.0,
    items: const [],
    isRow: true,
  ));
  for (final stat in ['12 trips', '48 saved', '9 countries']) {
    nodes.add(_node(_homeScreenId, row++, 'badge',
        _labeled('badge', {'label': stat}), null, statsRowId));
  }
  nodes.add(_node(
      _homeScreenId,
      row++,
      'button',
      _labeled('button', {'label': 'Explore stays'}),
      const NodeAction(to: _searchScreenId, transition: 'slide')));
  nodes.add(_node(
      _homeScreenId,
      row++,
      'navigation_bar',
      _mixed('navigation_bar', {'index': 0}),
      const NodeAction(to: _searchScreenId, transition: 'fade')));

  // Search screen.
  row = 0;
  nodes.add(_node(
      _searchScreenId,
      row++,
      'input',
      _labeled('input', {
        'label': 'Search',
        'placeholder': 'Try Kyoto or Lisbon',
      })));
  for (final dest in [
    ('Kyoto', 'Japan', '4.9 · 2.3k saves'),
    ('Lisbon', 'Portugal', '4.8 · 1.9k saves'),
    ('Marrakech', 'Morocco', '4.7 · 1.1k saves'),
  ]) {
    nodes.add(_node(
        _searchScreenId,
        row++,
        'basic',
        _mixed('basic', {
          'title': dest.$1,
          'subtitle': dest.$2,
          'content': dest.$3,
          'showLeading': false,
        })));
  }
  nodes.add(_node(
      _searchScreenId,
      row++,
      'navigation_bar',
      _mixed('navigation_bar', {'index': 1}),
      const NodeAction(to: _savedScreenId, transition: 'fade')));

  // Saved screen.
  row = 0;
  for (final saved in [
    ('Kyoto in autumn', 'Saved 2 days ago'),
    ('Lisbon weekends', 'Saved last week'),
  ]) {
    nodes.add(_node(
        _savedScreenId,
        row++,
        'card',
        _labeled('card', {
          'title': saved.$1,
          'description': saved.$2,
        })));
  }
  nodes.add(_node(
      _savedScreenId,
      row++,
      'navigation_bar',
      _mixed('navigation_bar', {'index': 2}),
      const NodeAction(to: _homeScreenId, transition: 'fade')));

  return ScreenDoc(
    screens: const [_homeScreen, _searchScreen, _savedScreen],
    nodes: nodes,
    theme: _wanderTheme,
    meta: const DocMeta(
      title: 'Wander demo',
      brief:
          'Wander travel-app demo: Home (hero + stats + Explore CTA), Search (destination rows), Saved (trip cards), bottom-tab wired.',
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
  stderr.writeln('seed_wander: $message');
  exit(1);
}

Set<String> _kindsOn(ScreenDoc doc, String screenId) => {
      for (final node in doc.nodes)
        if (node.screenId == screenId)
          for (final item in node.items) item.kind,
    };

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/seed_wander.dart <out.json>');
    exit(2);
  }

  final doc = buildWander();
  const fileName = 'wander.json';

  // 1. Refs clean (node screens, action targets, row parentIds).
  final refs = doc.validateRefs();
  if (refs.isNotEmpty) {
    _fail('dangling refs:\n${refs.join('\n')}');
  }

  // 2. Write + round-trip through ScreenDoc.fromJson.
  final out = File(args[0]);
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
    _fail('round-trip parse failed: $e');
  }
  if (back.screens.length != doc.screens.length) {
    _fail('round-trip screens mismatch');
  }
  if (back.nodes.length != doc.nodes.length) {
    _fail('round-trip nodes mismatch: ${back.nodes.length} != '
        '${doc.nodes.length}');
  }
  if (_itemCount(back) != _itemCount(doc)) {
    _fail('round-trip items mismatch');
  }
  if (_actionCount(back) != _actionCount(doc)) {
    _fail('round-trip actions mismatch');
  }
  if (back.validateRefs().isNotEmpty) {
    _fail('round-trip refs mismatch: ${back.validateRefs().join(', ')}');
  }

  // 3. Globally unique ids across screens, nodes, and items.
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
    _fail('duplicate ids: ${duplicates.join(', ')}');
  }

  // 4. Zero placeholder/unknown kinds: every item kind must have a real
  // builder (CatalogEntry or bare registry builder — see
  // [_realBuilderKinds]); row containers are structural (isRow, no items).
  for (final node in back.nodes) {
    if (node.isRow) {
      if (node.items.isNotEmpty) {
        _fail('row container ${node.id} must carry no items');
      }
      continue;
    }
    for (final item in node.items) {
      if (!_realBuilderKinds.contains(item.kind)) {
        _fail('item ${item.id} uses placeholder/unknown kind ${item.kind}');
      }
    }
  }

  // 5. Shape: 3 phone/surface screens, 18 nodes (incl. 1 row container),
  // 17 items, 4 actions.
  if (back.screens.length != 3) {
    _fail('expected 3 screens, found ${back.screens.length}');
  }
  for (final screen in back.screens) {
    if (screen.device != 'phone' || screen.bg != 'surface') {
      _fail('screen ${screen.name} should be phone/surface');
    }
  }
  if (back.nodes.length != 18) {
    _fail('expected 18 nodes, found ${back.nodes.length}');
  }
  if (_itemCount(back) != 17) {
    _fail('expected 17 items, found ${_itemCount(back)}');
  }
  if (_actionCount(back) != 4) {
    _fail('expected 4 actions, found ${_actionCount(back)}');
  }
  if (back.theme.chrome != null ||
      back.theme.paletteKey != 'clean-slate' ||
      !back.theme.dark) {
    _fail('theme should be clean-slate dark with no chrome');
  }

  // 6. Per-screen composition.
  final homeKinds = _kindsOn(back, _homeScreenId);
  if (!homeKinds.containsAll({
    'avatar',
    'basic',
    'card_image',
    'input',
    'badge',
    'button',
    'navigation_bar',
  })) {
    _fail('Home kinds incomplete: ${homeKinds.join(', ')}');
  }
  if ([
        for (final node in back.nodes)
          if (node.screenId == _homeScreenId)
            for (final item in node.items)
              if (item.kind == 'badge') item,
      ].length !=
      3) {
    _fail('Home should hold exactly 3 stat badges');
  }
  final searchKinds = _kindsOn(back, _searchScreenId);
  if (!searchKinds.containsAll({'input', 'basic', 'navigation_bar'})) {
    _fail('Search kinds incomplete: ${searchKinds.join(', ')}');
  }
  if ([
        for (final node in back.nodes)
          if (node.screenId == _searchScreenId)
            for (final item in node.items)
              if (item.kind == 'basic') item,
      ].length !=
      3) {
    _fail('Search should hold exactly 3 destination rows');
  }
  final savedKinds = _kindsOn(back, _savedScreenId);
  if (!savedKinds.containsAll({'card', 'navigation_bar'})) {
    _fail('Saved kinds incomplete: ${savedKinds.join(', ')}');
  }

  // 7. Wiring: Explore CTA (Home -> Search, slide) + bottom-bar cycle with
  // correct per-screen selected indices.
  bool hasAction(String from, String to, String transition) => back.nodes.any(
        (node) =>
            node.screenId == from &&
            node.items.any((item) =>
                item.action?.to == to && item.action?.transition == transition),
      );
  String navIndex(String screenId) {
    for (final node in back.nodes) {
      if (node.screenId != screenId) continue;
      for (final item in node.items) {
        if (item.kind == 'navigation_bar') return '${item.props['index']}';
      }
    }
    _fail('no navigation_bar on $screenId');
  }

  if (!hasAction(_homeScreenId, _searchScreenId, 'slide')) {
    _fail('Explore CTA leg (Home -> Search, slide) missing');
  }
  if (!hasAction(_homeScreenId, _searchScreenId, 'fade') ||
      !hasAction(_searchScreenId, _savedScreenId, 'fade') ||
      !hasAction(_savedScreenId, _homeScreenId, 'fade')) {
    _fail('bottom-bar cycle (Home -> Search -> Saved -> Home) missing');
  }
  if (navIndex(_homeScreenId) != '0' ||
      navIndex(_searchScreenId) != '1' ||
      navIndex(_savedScreenId) != '2') {
    _fail('bottom-bar selected indices should be 0/1/2 per screen');
  }

  // 8. Tap graph connected: every screen reachable from Home.
  final targets = <String, Set<String>>{};
  for (final node in back.nodes) {
    for (final item in node.items) {
      final to = item.action?.to;
      if (to != null) {
        targets.putIfAbsent(node.screenId, () => <String>{}).add(to);
      }
    }
  }
  final reached = <String>{_homeScreenId};
  final queue = [_homeScreenId];
  while (queue.isNotEmpty) {
    for (final next in targets[queue.removeLast()] ?? const <String>{}) {
      if (reached.add(next)) queue.add(next);
    }
  }
  if (reached.length != back.screens.length) {
    _fail('tap graph disconnected: reached ${reached.join(', ')}');
  }

  stdout.writeln(
    '$fileName: ${back.screens.length} screens, '
    '${back.nodes.length} nodes '
    '(${_itemCount(back)} items), '
    '${_actionCount(back)} actions '
    '(refs clean, round-trip ok, kinds real, tap graph connected)',
  );
}
