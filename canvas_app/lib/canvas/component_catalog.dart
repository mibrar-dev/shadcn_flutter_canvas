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
/// input → `TextField`, badge → `*Badge`, switch → `Switch`,
/// avatar → `Avatar`, checkbox → `Checkbox` (+ `CheckboxState`),
/// divider → `Divider`, progress → `Progress`,
/// tabs → `Tabs` + `TabItem` (concrete `TabChild`),
/// accordion → `Accordion` + `AccordionItem` + `AccordionTrigger`,
/// select → `Select<T>` + `SelectPopup`/`SelectItemList`/`SelectItemButton`,
/// radio_group → `RadioGroup<T>` + `RadioItem<T>`,
/// skeleton → `SkeletonExtension.asSkeleton()` on any widget (the kit ships
/// no bare `Skeleton` widget — only `ShadcnSkeletonizerConfigLayer` plus the
/// extension; the catalog wraps a `Text` label),
/// breadcrumb → `Breadcrumb` (+ `arrowSeparator`/`slashSeparator`),
/// dialog → `ModalContainer` (the kit ships no bare `Dialog` widget — only
/// `showDialog`/`showAlertDialog` context APIs plus `ModalContainer` /
/// `ModalBackdrop` primitives; the catalog renders the preview's dialog
/// content — title + body + action row — inside a `ModalContainer`),
/// tooltip → `Tooltip` + `TooltipContainer` (hover-triggered overlay; builds
/// bare, the tip shows on hover at runtime),
/// toast → `ToastEntry` (overlay-driven via `ToastController.show`, but the
/// entry itself builds bare; `autoDismiss: false` keeps the canvas node
/// stable and `dismissDirections` stays empty),
/// drawer → `DrawerWrapper` + `OverlayPosition` (overlay-driven via
/// `openDrawer`, but the wrapper builds bare — the layer lookup is
/// null-safe; `draggable: false` renders a plain themed container, so the
/// catalog wraps a fixed-width column as the side-panel mock).
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
/// No canvas blocks (`components[].canvas.propsSchema`) exist for avatar,
/// checkbox, divider, progress, tabs, accordion, select, radio_group,
/// skeleton, breadcrumb, dialog, tooltip, toast, or drawer in the pinned
/// kit's `components.json` (verified by scan 2026-09-05 — no `canvas` key on
/// any of the 134 components), so those fourteen defaults are invented,
/// documented per builder below, and use only bool/string/num prop types
/// already established by the seed kinds.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
// Direct component-library import: the barrel exports `TabItem`/`TabChild`
// from three navigation libraries (`tabs`, `tab_container`, `tab_list`), so
// the prefixed barrel names do not resolve to the `Tabs`-compatible ones.
// Only `Tabs` itself is unique to this library.
import 'package:flutter_shadcn_kit/registry/components/navigation/tabs/tabs.dart'
    as tabs;

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

Widget _buildAvatar(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. `Avatar`
  // requires `initials`; color/size/badge/theme all fall back to theme
  // defaults, so a bare initials-only construction is canvas-true.
  final initials = (props['initials'] ?? 'AB') as String;
  return shadcn.Avatar(initials: initials);
}

/// Local state for the catalog checkbox (builders are stateless).
/// `Checkbox` is controlled (`state` + `onChanged`, both required params),
/// so the cell owns a `CheckboxState` exactly like `_SwitchCell` owns a bool.
class _CheckboxCell extends StatefulWidget {
  final bool initialValue;
  final bool disabled;

  const _CheckboxCell({required this.initialValue, required this.disabled});

  @override
  State<_CheckboxCell> createState() => _CheckboxCellState();
}

class _CheckboxCellState extends State<_CheckboxCell> {
  late shadcn.CheckboxState _state = widget.initialValue
      ? shadcn.CheckboxState.checked
      : shadcn.CheckboxState.unchecked;

  @override
  Widget build(BuildContext context) {
    return shadcn.Checkbox(
      state: _state,
      // Null `onChanged` renders the disabled state (auto-detected).
      onChanged: widget.disabled ? null : (s) => setState(() => _state = s),
    );
  }
}

Widget _buildCheckbox(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented to mirror the
  // switch kind's bool-pair convention (`value` + `disabled`).
  final value = (props['value'] ?? false) as bool;
  final disabled = (props['disabled'] ?? false) as bool;
  return _CheckboxCell(initialValue: value, disabled: disabled);
}

Widget _buildDivider(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. `Divider` takes
  // an optional `child`, so the canvas-level `label` prop renders as that
  // child (mirrors the input builder's label-caption pattern).
  final label = (props['label'] ?? '') as String;
  return shadcn.Divider(child: label.isEmpty ? null : Text(label));
}

Widget _buildProgress(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. `Progress`
  // asserts `progress` lies within [min, max], so hand-written docs are
  // clamped instead of crashing. Parsed via `num` because `jsonDecode`
  // yields `int` for whole numbers (same trap as §6's JSON doubles note).
  final value = ((props['progress'] as num?)?.toDouble() ?? 0.5).clamp(
    0.0,
    1.0,
  );
  return shadcn.Progress(progress: value);
}

/// Local tab-index state for the catalog tabs (builders are stateless).
/// Headers only — content panes are app-level (`IndexedStack` in the
/// component's own preview) and have no canvas counterpart.
class _TabsCell extends StatefulWidget {
  final int initialIndex;
  final String firstLabel;
  final String secondLabel;

  const _TabsCell({
    required this.initialIndex,
    required this.firstLabel,
    required this.secondLabel,
  });

  @override
  State<_TabsCell> createState() => _TabsCellState();
}

class _TabsCellState extends State<_TabsCell> {
  late int _index = widget.initialIndex.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    return tabs.Tabs(
      index: _index,
      onChanged: (i) => setState(() => _index = i.clamp(0, 1)),
      children: [
        // `TabItem` is the concrete `TabChild` (per the kit's preview).
        tabs.TabItem(child: Text(widget.firstLabel)),
        tabs.TabItem(child: Text(widget.secondLabel)),
      ],
    );
  }
}

Widget _buildTabs(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two tab labels
  // plus the selected index (parsed via `num`, see _buildProgress).
  final index = (props['index'] as num?)?.toInt() ?? 0;
  final first = (props['tab1'] ?? 'Tab 1') as String;
  final second = (props['tab2'] ?? 'Tab 2') as String;
  return _TabsCell(
    initialIndex: index,
    firstLabel: first,
    secondLabel: second,
  );
}

Widget _buildAccordion(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: one trigger
  // label, one content body, and the initial expanded flag. `AccordionItem`
  // owns its own expansion state, so no cell is needed (mirrors _buildCard).
  final title = (props['title'] ?? 'Section 1') as String;
  final content = (props['content'] ?? 'Content 1') as String;
  final expanded = (props['expanded'] ?? false) as bool;
  return shadcn.Accordion(
    items: [
      shadcn.AccordionItem(
        trigger: shadcn.AccordionTrigger(child: Text(title)),
        content: Text(content),
        expanded: expanded,
      ),
    ],
  );
}

/// Local selection state for the catalog select (builders are stateless).
/// Mirrors `_TabsCell`: two options plus the selected value. A value absent
/// from the options renders as unselected (placeholder) instead of crashing.
class _SelectCell extends StatefulWidget {
  final String placeholder;
  final String firstOption;
  final String secondOption;
  final String initialValue;

  const _SelectCell({
    required this.placeholder,
    required this.firstOption,
    required this.secondOption,
    required this.initialValue,
  });

  @override
  State<_SelectCell> createState() => _SelectCellState();
}

class _SelectCellState extends State<_SelectCell> {
  late String? _value =
      widget.initialValue.isEmpty ? null : widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final options = [widget.firstOption, widget.secondOption];
    final value = options.contains(_value) ? _value : null;
    return shadcn.Select<String>(
      value: value,
      placeholder: Text(widget.placeholder),
      itemBuilder: (context, item) => Text(item),
      onChanged: (v) => setState(() => _value = v),
      popup: shadcn.SelectPopup(
        items: shadcn.SelectItemList(
          children: [
            for (final option in options)
              shadcn.SelectItemButton(value: option, child: Text(option)),
          ],
        ),
      ).call,
    );
  }
}

Widget _buildSelect(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a placeholder
  // plus two options and the selected value (empty = unselected, mirrors the
  // input builder's empty-label convention).
  final placeholder = (props['placeholder'] ?? 'Select an option') as String;
  final first = (props['option1'] ?? 'Option 1') as String;
  final second = (props['option2'] ?? 'Option 2') as String;
  final value = (props['value'] ?? '') as String;
  return _SelectCell(
    placeholder: placeholder,
    firstOption: first,
    secondOption: second,
    initialValue: value,
  );
}

/// Local selection state for the catalog radio group (builders are
/// stateless). Mirrors `_TabsCell`: two options plus the selected value.
class _RadioGroupCell extends StatefulWidget {
  final String firstOption;
  final String secondOption;
  final String initialValue;

  const _RadioGroupCell({
    required this.firstOption,
    required this.secondOption,
    required this.initialValue,
  });

  @override
  State<_RadioGroupCell> createState() => _RadioGroupCellState();
}

class _RadioGroupCellState extends State<_RadioGroupCell> {
  late String? _value =
      widget.initialValue.isEmpty ? null : widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return shadcn.RadioGroup<String>(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          shadcn.RadioItem<String>(
            value: widget.firstOption,
            leading: Text(widget.firstOption),
          ),
          const SizedBox(height: 8),
          shadcn.RadioItem<String>(
            value: widget.secondOption,
            leading: Text(widget.secondOption),
          ),
        ],
      ),
    );
  }
}

Widget _buildRadioGroup(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two options
  // plus the selected value (first option pre-selected, mirrors the kit's
  // own preview which starts at `'starter'`).
  final first = (props['option1'] ?? 'Option 1') as String;
  final second = (props['option2'] ?? 'Option 2') as String;
  final value = (props['value'] ?? 'Option 1') as String;
  return _RadioGroupCell(
    firstOption: first,
    secondOption: second,
    initialValue: value,
  );
}

Widget _buildSkeleton(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The kit ships
  // no bare `Skeleton` widget (only `ShadcnSkeletonizerConfigLayer`, which
  // needs a `ThemeData`, plus the `SkeletonExtension.asSkeleton()` helper
  // used by the component's own preview), so the catalog wraps a `Text`
  // label exactly like the preview does.
  final label = (props['label'] ?? 'Loading') as String;
  final enabled = (props['enabled'] ?? true) as bool;
  return Text(label).asSkeleton(enabled: enabled);
}

Widget _buildBreadcrumb(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a parent crumb
  // and the current page (plain `Text` children; the kit's preview uses
  // `LinkButton`s, but bare text keeps the canvas node dependency-free).
  final home = (props['home'] ?? 'Home') as String;
  final current = (props['current'] ?? 'Page') as String;
  return shadcn.Breadcrumb(children: [Text(home), Text(current)]);
}

Widget _buildDialog(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/dialog/preview.dart`), whose
  // `showDialog` builder content is a padded title + body + Close action
  // row. The kit ships no bare `Dialog` widget (`showDialog` needs a
  // `BuildContext` + overlay), so the catalog renders that same content
  // inside the real `ModalContainer` primitive (bare-capable: its only
  // context read is a null-safe `Model.maybeOf`).
  final title = (props['title'] ?? 'Dialog title') as String;
  final message =
      (props['message'] ?? 'Use dialogs for important confirmations.')
          as String;
  final showActions = (props['showActions'] ?? true) as bool;
  return shadcn.ModalContainer(
    filled: true,
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 12),
        Text(message),
        if (showActions) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Spacer(),
              shadcn.OutlineButton(
                onPressed: () {},
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

Widget _buildTooltip(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/tooltip/preview.dart`: a labeled
  // control with a `TooltipContainer` tip). The real `Tooltip` builds bare
  // (overlay handlers attach on hover at runtime); the tip text only
  // materializes on hover, so canvas shows the labeled control. Qualified
  // as `shadcn.Tooltip`: material's `Tooltip` is also imported here.
  final label = (props['label'] ?? 'Hover me') as String;
  final tip = (props['tip'] ?? 'Helpful context') as String;
  return shadcn.Tooltip(
    tooltip: (context) => shadcn.TooltipContainer(child: Text(tip)),
    child: shadcn.OutlineButton(onPressed: () {}, child: Text(label)),
  );
}

Widget _buildToast(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: an icon + title
  // + message notification row (the kit's preview shows a bare `Text` via
  // `ToastController.show`; the entry takes any child). The real
  // `ToastEntry` builds bare; `autoDismiss: false` disables the dismiss
  // timer so the canvas node never self-dismisses, and the empty default
  // `dismissDirections` disables swipe handling.
  final title = (props['title'] ?? 'Saved') as String;
  final message = (props['message'] ?? 'Saved successfully') as String;
  return shadcn.ToastEntry(
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 200),
    animationCurve: Curves.easeOut,
    onDismissed: () {},
    autoDismiss: false,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 20),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title), Text(message)],
        ),
      ],
    ),
  );
}

Widget _buildDrawer(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a title plus
  // body content. The real `DrawerWrapper` builds bare (its overlay-layer
  // lookup is null-safe and it owns its `AnimationController`); with
  // `draggable: false` it renders a plain themed container, so the catalog
  // wraps a fixed-width column as the side-panel mock. `size` is required
  // but only feeds drag math — the visible width comes from the `SizedBox`.
  final title = (props['title'] ?? 'Drawer') as String;
  final content = (props['content'] ?? 'Drawer content') as String;
  return shadcn.DrawerWrapper(
    position: shadcn.OverlayPosition.end,
    size: const Size(240, 480),
    stackIndex: 0,
    draggable: false,
    showDragHandle: false,
    child: SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 16),
          Text(content),
        ],
      ),
    ),
  );
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
  CatalogEntry(
    kind: 'avatar',
    label: 'Initials/photo avatar with badge and group support.',
    defaults: const {'initials': 'AB'},
    build: _buildAvatar,
  ),
  CatalogEntry(
    kind: 'checkbox',
    label: 'Animated checkbox with tri-state support and controllers.',
    defaults: const {'value': false, 'disabled': false},
    build: _buildCheckbox,
  ),
  CatalogEntry(
    kind: 'divider',
    label: 'Horizontal and vertical separators with optional label support.',
    defaults: const {'label': ''},
    build: _buildDivider,
  ),
  CatalogEntry(
    kind: 'progress',
    label: 'Normalized linear progress bar with theme overrides.',
    defaults: const {'progress': 0.5},
    build: _buildProgress,
  ),
  CatalogEntry(
    kind: 'tabs',
    label: 'Tabbed navigation primitives with lists and panes.',
    defaults: const {'tab1': 'Tab 1', 'tab2': 'Tab 2', 'index': 0},
    build: _buildTabs,
  ),
  CatalogEntry(
    kind: 'accordion',
    label: 'Single-expansion accordion with configurable triggers and theming.',
    defaults: const {
      'title': 'Section 1',
      'content': 'Content 1',
      'expanded': false,
    },
    build: _buildAccordion,
  ),
  CatalogEntry(
    kind: 'select',
    label:
        'Dropdown/select control with popup menus, grouped items, and keyboard navigation.',
    defaults: const {
      'placeholder': 'Select an option',
      'option1': 'Option 1',
      'option2': 'Option 2',
      'value': '',
    },
    build: _buildSelect,
  ),
  CatalogEntry(
    kind: 'radio_group',
    label: 'Exclusive selection group with radio items and cards.',
    defaults: const {
      'option1': 'Option 1',
      'option2': 'Option 2',
      'value': 'Option 1',
    },
    build: _buildRadioGroup,
  ),
  CatalogEntry(
    kind: 'skeleton',
    label: 'Skeletonizer helpers with theme-aware config and extensions.',
    defaults: const {'label': 'Loading', 'enabled': true},
    build: _buildSkeleton,
  ),
  CatalogEntry(
    kind: 'breadcrumb',
    label:
        'Horizontal breadcrumb trail with arrow/slash separators and overflow handling.',
    defaults: const {'home': 'Home', 'current': 'Page'},
    build: _buildBreadcrumb,
  ),
  CatalogEntry(
    kind: 'dialog',
    label: 'Modal dialog primitives with alert dialog and overlay handlers.',
    defaults: const {
      'title': 'Dialog title',
      'message': 'Use dialogs for important confirmations.',
      'showActions': true,
    },
    build: _buildDialog,
  ),
  CatalogEntry(
    kind: 'tooltip',
    label: 'Hover-triggered tooltip overlays with themed containers.',
    defaults: const {'label': 'Hover me', 'tip': 'Helpful context'},
    build: _buildTooltip,
  ),
  CatalogEntry(
    kind: 'toast',
    label: 'Overlay toast notifications with configurable timing.',
    defaults: const {'title': 'Saved', 'message': 'Saved successfully'},
    build: _buildToast,
  ),
  CatalogEntry(
    kind: 'drawer',
    label: 'Sliding drawer and sheet overlays with drag support.',
    defaults: const {'title': 'Drawer', 'content': 'Drawer content'},
    build: _buildDrawer,
  ),
];

/// Container (layout) tiles for the flow canvas.
///
/// These are NOT [CatalogEntry]s: a row has no registry widget and renders
/// structurally in `ScreenSurface` (a horizontal container of its child
/// nodes), so there is nothing for `build` to construct. The parts palette
/// resolves these when a section kind is absent from [kCatalog] and renders
/// them with the same tile chrome (`Draggable` data = kind). Record shape is
/// `({String label, IconData icon})`.
const Map<String, ({String label, IconData icon})> kContainerTiles = {
  'row': (label: 'Row', icon: Icons.view_column),
};

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

/// Bridge for the generated palette registry (`component_registry.dart`):
/// builds [kind] with a copy of its catalog defaults, so registry tiles and
/// standalone previews render without duplicating builders. Unknown kinds
/// use [fallbackBuilder], exactly like [buildCatalogItem].
Widget buildCatalogWithDefaults(String kind) {
  final entry = findEntry(kind);
  if (entry == null) return fallbackBuilder(kind);
  return entry.build(Map<String, dynamic>.of(entry.defaults));
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
