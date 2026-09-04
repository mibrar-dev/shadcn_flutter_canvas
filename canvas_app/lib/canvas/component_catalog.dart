/// Seed catalog mapping canvas kinds to real registry widgets.
///
/// Builders take stringly-typed props so canvas nodes instantiate without
/// generated code. Each entry's construction REFERENCE is that component's
/// `preview.dart` — previews are never embedded here (they render full
/// `Scaffold`s; nested Scaffolds inside canvas frames break
/// `ScaffoldMessenger`/safe-area behavior). Builders construct bare widgets.
///
/// Widget names are discovered per kind, never assumed (`Shad*` names do not
/// exist in this repo):
/// `grep -rn "^class .* extends .*Widget" <component>/_impl/ | head`
/// Verified: button → `Button` family (`PrimaryButton`, …), card → `Card`,
/// input → `TextField`, badge → `*Badge`, switch → `Switch`.
///
/// Prop defaults mirror the canvas blocks' `propsSchema` in `components.json`
/// (reconciled 2026-09-04; entry labels mirror `components.json`
/// descriptions); badge/switch defaults match the discovered constructors.
/// Known block-vs-constructor mismatches live in the kit's `components.json`
/// (NOT patched here) and are tracked as follow-up findings: button `size`
/// enum lists `icon` but `ButtonSize` has no icon member (falls back to
/// normal); button `variant` enum omits `text` though `ButtonVariance.text` /
/// `TextButton` exist (builder supports it anyway); switch schema has a
/// `label` prop but `Switch` takes no label (only `leading`/`trailing`), so
/// the catalog intentionally omits it.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;

/// Builds a canvas node widget from stringly-typed props.
typedef NodeBuilder = Widget Function(Map<String, dynamic> props);

/// One draggable component kind.
class CatalogEntry {
  final String kind;
  final String label;
  final Map<String, dynamic> defaults;
  final NodeBuilder build;

  const CatalogEntry({
    required this.kind,
    required this.label,
    required this.defaults,
    required this.build,
  });
}

shadcn.ButtonSize _buttonSize(String? size) {
  return switch (size) {
    'sm' => shadcn.ButtonSize.small,
    'lg' => shadcn.ButtonSize.large,
    // 'md' (default) and anything unknown fall back to normal.
    // NOTE: plan Task 3 lists an `icon` size, but `ButtonSize` has no icon
    // member (`IconButton` is a separate widget) — deviation, reported.
    _ => shadcn.ButtonSize.normal,
  };
}

Widget _buildButton(Map<String, dynamic> props) {
  final label = (props['label'] ?? 'Button') as String;
  final variant = (props['variant'] ?? 'primary') as String;
  final size = _buttonSize(props['size'] as String?);
  final disabled = (props['disabled'] ?? false) as bool;
  final child = Text(label);
  // `enabled: false` renders the disabled state; onPressed stays non-null.
  switch (variant) {
    case 'secondary':
      return shadcn.SecondaryButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
    case 'outline':
      return shadcn.OutlineButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
    case 'ghost':
      return shadcn.GhostButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
    case 'destructive':
      return shadcn.DestructiveButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
    case 'link':
      return shadcn.LinkButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
    case 'text':
      // `ButtonVariance.text` / `TextButton` exist in the kit, though the
      // button canvas block's variant enum omits `text` (reported follow-up).
      return shadcn.TextButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
    case 'primary':
    default:
      return shadcn.PrimaryButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
  }
}

Widget _buildCard(Map<String, dynamic> props) {
  // Fallbacks mirror the card canvas block's propsSchema defaults
  // (`components.json`): `Card` takes a bare child, so title/description are
  // canvas-level content props with no constructor counterpart.
  final title = (props['title'] ?? 'Title') as String;
  final description = (props['description'] ?? 'Description') as String;
  final showFooter = (props['showFooter'] ?? false) as bool;
  return shadcn.Card(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 4),
        Text(description),
        if (showFooter) ...[
          const SizedBox(height: 12),
          shadcn.PrimaryButton(
            size: shadcn.ButtonSize.small,
            onPressed: () {},
            child: const Text('Action'),
          ),
        ],
      ],
    ),
  );
}

Widget _buildInput(Map<String, dynamic> props) {
  // `TextField` has no `label` param — render it as a caption above.
  final label = (props['label'] ?? '') as String;
  final placeholder = (props['placeholder'] ?? 'Type here') as String;
  final disabled = (props['disabled'] ?? false) as bool;
  final obscure = (props['obscure'] ?? false) as bool;
  final field = shadcn.TextField(
    placeholder: Text(placeholder),
    enabled: !disabled,
    obscureText: obscure,
  );
  if (label.isEmpty) return field;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 6),
      field,
    ],
  );
}

Widget _buildBadge(Map<String, dynamic> props) {
  final label = (props['label'] ?? 'Badge') as String;
  final variant = (props['variant'] ?? 'primary') as String;
  final child = Text(label);
  // No generic `Badge` class exists — one widget per style.
  switch (variant) {
    case 'secondary':
      return shadcn.SecondaryBadge(child: child);
    case 'destructive':
      return shadcn.DestructiveBadge(child: child);
    case 'outline':
      return shadcn.OutlineBadge(child: child);
    case 'primary':
    default:
      return shadcn.PrimaryBadge(child: child);
  }
}

/// Local toggle state for the catalog switch (builders are stateless).
class _SwitchCell extends StatefulWidget {
  final bool initialValue;
  final bool disabled;

  const _SwitchCell({required this.initialValue, required this.disabled});

  @override
  State<_SwitchCell> createState() => _SwitchCellState();
}

class _SwitchCellState extends State<_SwitchCell> {
  late bool _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return shadcn.Switch(
      value: _value,
      onChanged: widget.disabled ? null : (v) => setState(() => _value = v),
    );
  }
}

Widget _buildSwitch(Map<String, dynamic> props) {
  final value = (props['value'] ?? false) as bool;
  final disabled = (props['disabled'] ?? false) as bool;
  return _SwitchCell(initialValue: value, disabled: disabled);
}

/// Seed entries. Labels mirror `components.json` descriptions.
final List<CatalogEntry> kCatalog = [
  CatalogEntry(
    kind: 'button',
    label: 'Shadcn-style button system with variants, toggles, and groups.',
    defaults: const {
      'label': 'Button',
      'variant': 'primary',
      'size': 'md',
      'disabled': false,
    },
    build: _buildButton,
  ),
  CatalogEntry(
    kind: 'card',
    label: 'Card container with optional surface blur variant.',
    defaults: const {
      'title': 'Title',
      'description': 'Description',
      'showFooter': false,
    },
    build: _buildCard,
  ),
  CatalogEntry(
    kind: 'input',
    label:
        'Single-line text input with feature hooks, popovers, and controller integration.',
    defaults: const {
      'placeholder': 'Type here',
      'label': '',
      'disabled': false,
      'obscure': false,
    },
    build: _buildInput,
  ),
  CatalogEntry(
    kind: 'badge',
    label: 'Compact label/status components built on button styles.',
    defaults: const {'label': 'Badge', 'variant': 'primary'},
    build: _buildBadge,
  ),
  CatalogEntry(
    kind: 'switch',
    label: 'Toggle control for boolean values with themed styling.',
    defaults: const {'value': false, 'disabled': false},
    build: _buildSwitch,
  ),
];

/// Looks up a catalog entry by kind, or null when unknown.
CatalogEntry? findEntry(String kind) {
  for (final entry in kCatalog) {
    if (entry.kind == kind) return entry;
  }
  return null;
}

/// Builds the widget for [kind] with [props], or [fallbackBuilder] output for
/// unknown kinds. Builders tolerate missing keys (each prop has a fallback),
/// so hand-written docs without full defaults still render.
Widget buildCatalogItem(String kind, Map<String, dynamic> props) {
  final entry = findEntry(kind);
  if (entry == null) return fallbackBuilder(kind);
  return entry.build(props);
}

/// Never crash on unknown kinds: placeholder plus the offending kind label.
Widget fallbackBuilder(String kind) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Placeholder(fallbackWidth: 120, fallbackHeight: 48),
      const SizedBox(height: 4),
      Text('unknown: $kind'),
    ],
  );
}
