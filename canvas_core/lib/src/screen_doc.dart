/// Pure-Dart ScreenDoc model (no Flutter imports — reused by the CLI).
///
/// Manual `toJson`/`fromJson`, no codegen. Every double parses via
/// `(v as num).toDouble()` because `jsonDecode` yields `int` for whole
/// numbers and `as double` would crash on those.
library;

/// Flow layout spacing (single source of truth; canvas_app imports these,
/// canvas_core stays Flutter-free so the CLI can share it).
///
/// The screen root is an implicit vertical Column: [kFlowScreenGap] is the
/// vertical gap between root children and [kFlowScreenPadding] the inner
/// screen padding. Row containers space their children with the node's own
/// `gap`, which defaults to [kFlowRowGapDefault].
const double kFlowScreenGap = 12.0;
const double kFlowScreenPadding = 16.0;
const double kFlowRowGapDefault = 8.0;

/// Responsive tiers known to the doc model (single source of truth; the
/// app-side [Tier] enum mirrors these names in `canvas_app/lib/ui/responsive.dart`).
const Set<String> kResponsiveTiers = {'mobile', 'tablet', 'desktop'};

/// Migrates a legacy absolute-layout doc to flow layout.
///
/// Pure function: root nodes (`parentId == null`, i.e. every node in a
/// legacy doc) are rewritten in `(y, x)` order so list order becomes the
/// flow order; `x`/`y` values are PRESERVED as metadata (the flow renderer
/// ignores them). `theme`/`meta`/`screens` are untouched, and row-child
/// nodes (`parentId != null`) keep their original relative order.
///
/// Row detection is explicitly OUT of scope for v1: no auto-grouping is
/// attempted. Heuristic grouping (e.g. "nodes sharing a baseline form a
/// row") guesses intent from pixels and corrupts layouts often enough that
/// rows must be created explicitly by the user instead.
ScreenDoc migrateToFlow(ScreenDoc doc) {
  final roots = [
    for (final n in doc.nodes)
      if (n.parentId == null) n,
  ]..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });
  final children = [
    for (final n in doc.nodes)
      if (n.parentId != null) n,
  ];
  return ScreenDoc(
    screens: doc.screens,
    nodes: [...roots, ...children],
    theme: doc.theme,
    meta: doc.meta,
  );
}

/// Top-level canvas document.
class ScreenDoc {
  final List<CanvasScreen> screens;
  final List<CanvasNode> nodes;
  final CanvasTheme theme;
  final DocMeta meta;

  const ScreenDoc({
    required this.screens,
    required this.nodes,
    required this.theme,
    required this.meta,
  });

  factory ScreenDoc.fromJson(Map<String, dynamic> json) {
    for (final key in ['screens', 'nodes', 'theme', 'meta']) {
      if (!json.containsKey(key)) {
        throw FormatException('ScreenDoc missing required key: $key');
      }
    }
    return ScreenDoc(
      screens: (json['screens'] as List)
          .map((s) => CanvasScreen.fromJson(s as Map<String, dynamic>))
          .toList(),
      nodes: (json['nodes'] as List)
          .map((n) => CanvasNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      theme: CanvasTheme.fromJson(json['theme'] as Map<String, dynamic>),
      meta: DocMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'screens': screens.map((s) => s.toJson()).toList(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'theme': theme.toJson(),
        'meta': meta.toJson(),
      };

  /// Pure ref-integrity check: every `action.to` must match a screen id.
  List<String> validateRefs() {
    final ids = {for (final s in screens) s.id};
    final dangling = <String>[];
    for (final node in nodes) {
      for (final item in node.items) {
        final to = item.action?.to;
        if (to != null && !ids.contains(to)) {
          dangling.add('dangling action ${item.id} -> missing screen $to');
        }
      }
    }
    return dangling;
  }
}

/// A phone screen on the canvas.
///
/// [device] is the per-screen preview device id (`phone` / `tablet` /
/// `desktop-fluid` / `desktop-wide`, mirroring the `PreviewDeviceSpec` ids in
/// `canvas_app/lib/ui/device_picker.dart`); null means the phone default.
/// A missing JSON key parses to null so old docs stay phone-width, and
/// [toJson] omits the key when null (backward-compatible round-trip).
class CanvasScreen {
  final String id;
  final String name;
  final double x;
  final double y;
  final String bg;
  final String? device;

  const CanvasScreen({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.bg,
    this.device,
  });

  factory CanvasScreen.fromJson(Map<String, dynamic> json) => CanvasScreen(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        bg: json['bg'] as String,
        device: json['device'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'bg': bg,
        if (device != null) 'device': device,
      };
}

/// A flow-layout container of items on a screen.
///
/// `parentId == null` means the node sits in the screen-root vertical flow.
/// `isRow == true` makes the node a horizontal container whose children are
/// the nodes with `parentId == id`; `gap` is that row spacing (ignored for
/// leaves). `x`/`y` are kept as metadata for legacy docs; the flow renderer
/// ignores them and uses list order instead.
///
/// W3 container alignment/flex:
/// `mainAxis` (`start|center|end|spaceBetween|spaceAround|spaceEvenly`,
/// null = Flutter default start) and `crossAxis`
/// (`start|center|end|stretch`, null = default center for rows) live on the
/// ROW container. `expand` (`none|flex|expanded`, null/none = default) and
/// `flex` (default 1 when expand is flex/expanded and flex is null) live on
/// the CHILD node.
///
/// Responsive visibility/overrides (FlutterFlow parity):
/// `hiddenOn` lists the tiers the node is hidden on (subset of
/// [kResponsiveTiers], empty = always visible); `breakpointValues` holds
/// per-tier prop overrides keyed by tier name
/// (e.g. `{'tablet': {'columns': 2}}`); `slots` holds per-tier slot
/// overrides mapping slot name → item id or value
/// (e.g. `{'tablet': 'item-id'}`). Render-time filtering and inspector
/// editing of these fields are app-side concerns (later batch); the model
/// only stores, validates, and round-trips them.
class CanvasNode {
  final String id;
  final String screenId;
  final double x;
  final double y;
  final List<CanvasItem> items;
  final String? parentId;
  final bool isRow;
  final double gap;
  final String? mainAxis;
  final String? crossAxis;
  final String? expand;
  final int? flex;

  /// Tiers this node is hidden on (subset of [kResponsiveTiers]).
  ///
  /// Serialized as a sorted list under JSON key `hiddenOn`; a missing key
  /// parses to empty (always visible). Unknown tier strings throw
  /// [FormatException] (fail fast).
  final Set<String> hiddenOn;

  /// Per-tier prop overrides keyed by tier name.
  ///
  /// Serialized as a map under JSON key `breakpointValues`; a missing key
  /// parses to empty (no overrides).
  final Map<String, Map<String, dynamic>> breakpointValues;

  /// Per-tier slot overrides mapping slot name → item id or value.
  ///
  /// Serialized as a map under JSON key `slots`; a missing key parses to
  /// empty (no overrides).
  final Map<String, String> slots;

  const CanvasNode({
    required this.id,
    required this.screenId,
    required this.x,
    required this.y,
    required this.items,
    this.parentId,
    this.isRow = false,
    this.gap = kFlowRowGapDefault,
    this.mainAxis,
    this.crossAxis,
    this.expand,
    this.flex,
    this.hiddenOn = const {},
    this.breakpointValues = const {},
    this.slots = const {},
  });

  factory CanvasNode.fromJson(Map<String, dynamic> json) {
    final hiddenRaw = (json['hiddenOn'] as List?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];
    for (final tier in hiddenRaw) {
      if (!kResponsiveTiers.contains(tier)) {
        throw FormatException('CanvasNode unknown hiddenOn tier: $tier');
      }
    }
    final breakpointRaw =
        (json['breakpointValues'] as Map?) ?? const <String, dynamic>{};
    final slotsRaw = (json['slots'] as Map?) ?? const <String, dynamic>{};
    return CanvasNode(
      id: json['id'] as String,
      screenId: json['screenId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      items: (json['items'] as List)
          .map((i) => CanvasItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      // Backward compatible: old docs lack these keys.
      parentId: json['parentId'] as String?,
      isRow: (json['isRow'] as bool?) ?? false,
      gap: (json['gap'] as num?)?.toDouble() ?? kFlowRowGapDefault,
      mainAxis: json['mainAxis'] as String?,
      crossAxis: json['crossAxis'] as String?,
      expand: json['expand'] as String?,
      flex: (json['flex'] as num?)?.toInt(),
      hiddenOn: hiddenRaw.toSet(),
      breakpointValues: {
        for (final entry in breakpointRaw.entries)
          entry.key as String:
              Map<String, dynamic>.from(entry.value as Map),
      },
      slots: {
        for (final entry in slotsRaw.entries)
          entry.key as String: entry.value as String,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'screenId': screenId,
        'x': x,
        'y': y,
        'items': items.map((i) => i.toJson()).toList(),
        'parentId': parentId,
        'isRow': isRow,
        'gap': gap,
        'mainAxis': mainAxis,
        'crossAxis': crossAxis,
        'expand': expand,
        'flex': flex,
        'hiddenOn': (hiddenOn.toList()..sort()),
        'breakpointValues': {
          for (final entry in breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        'slots': Map<String, String>.from(slots),
      };
}

/// A single component instance. All keys besides `id`/`kind`/`action`
/// are component props (e.g. `label`, `variant`).
class CanvasItem {
  final String id;
  final String kind;
  final Map<String, dynamic> props;
  final NodeAction? action;

  const CanvasItem({
    required this.id,
    required this.kind,
    this.props = const {},
    this.action,
  });

  factory CanvasItem.fromJson(Map<String, dynamic> json) {
    final rest = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('kind')
      ..remove('action');
    return CanvasItem(
      id: json['id'] as String,
      kind: json['kind'] as String,
      props: rest,
      action: json['action'] == null
          ? null
          : NodeAction.fromJson(json['action'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        ...props,
        if (action != null) 'action': action!.toJson(),
      };

  CanvasItem copyWith({
    String? id,
    String? kind,
    Map<String, dynamic>? props,
    NodeAction? Function()? action,
  }) =>
      CanvasItem(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        props: props ?? Map<String, dynamic>.from(this.props),
        action: action == null ? this.action : action(),
      );
}

/// Tap behavior: navigate to another screen.
class NodeAction {
  final String to;
  final String transition;

  const NodeAction({required this.to, required this.transition});

  factory NodeAction.fromJson(Map<String, dynamic> json) => NodeAction(
        to: json['to'] as String,
        transition: json['transition'] as String,
      );

  Map<String, dynamic> toJson() => {'to': to, 'transition': transition};
}

/// Canvas-wide theme selection.
///
/// `chrome` is the optional app-chrome (editor shell) theme override; null
/// means the chrome follows the main (components) theme (current behavior,
/// backward compatible). Chrome is editor-only and never leaks into export
/// (prompt_builder/codegen keep using the main/components theme).
/// Chrome-of-chrome is not supported: a nested chrome's own `chrome` is
/// always null (fromJson forces it).
class CanvasTheme {
  final String paletteKey;
  final bool dark;
  final String shape;
  final String motion;

  /// The app-chrome theme override; null = chrome follows the main theme.
  final CanvasTheme? chrome;

  const CanvasTheme({
    required this.paletteKey,
    required this.dark,
    required this.shape,
    required this.motion,
    this.chrome,
  });

  factory CanvasTheme.fromJson(Map<String, dynamic> json) {
    for (final key in ['paletteKey', 'dark', 'shape', 'motion']) {
      if (!json.containsKey(key)) {
        throw FormatException('CanvasTheme missing required key: $key');
      }
    }
    CanvasTheme? chrome;
    if (json.containsKey('chrome') && json['chrome'] != null) {
      final raw = json['chrome'];
      if (raw is! Map) {
        throw FormatException('CanvasTheme chrome must be an object');
      }
      final cmap = Map<String, dynamic>.from(raw);
      for (final key in ['paletteKey', 'dark', 'shape', 'motion']) {
        if (!cmap.containsKey(key)) {
          throw FormatException(
            'CanvasTheme chrome missing required key: $key',
          );
        }
      }
      // Chrome-of-chrome is not supported: nested chrome forced null.
      chrome = CanvasTheme(
        paletteKey: cmap['paletteKey'] as String,
        dark: cmap['dark'] as bool,
        shape: cmap['shape'] as String,
        motion: cmap['motion'] as String,
      );
    }
    return CanvasTheme(
      paletteKey: json['paletteKey'] as String,
      dark: json['dark'] as bool,
      shape: json['shape'] as String,
      motion: json['motion'] as String,
      chrome: chrome,
    );
  }

  Map<String, dynamic> toJson() => {
        'paletteKey': paletteKey,
        'dark': dark,
        'shape': shape,
        'motion': motion,
        if (chrome != null) 'chrome': chrome!.toJson(),
      };

  /// Effective chrome theme: the override when set, else the main theme.
  CanvasTheme get effectiveChrome => chrome ?? this;
}

/// Document title/brief.
class DocMeta {
  final String title;
  final String brief;

  const DocMeta({required this.title, required this.brief});

  factory DocMeta.fromJson(Map<String, dynamic> json) => DocMeta(
        title: json['title'] as String,
        brief: json['brief'] as String,
      );

  Map<String, dynamic> toJson() => {'title': title, 'brief': brief};
}
