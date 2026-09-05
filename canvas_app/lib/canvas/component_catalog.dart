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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
// Direct component-library import: the barrel exports `TabItem`/`TabChild`
// from three navigation libraries (`tabs`, `tab_container`, `tab_list`), so
// the prefixed barrel names do not resolve to the `Tabs`-compatible ones.
// Only `Tabs` itself is unique to this library.
import 'package:flutter_shadcn_kit/registry/components/navigation/tabs/tabs.dart'
    as tabs;
// Direct component-library import: the barrel hides `Table`/`TableRow`
// (material conflicts), so the `shadcn.` prefix resolves to material's
// `Table` instead of the kit's — same trap as the `tabs` import above.
import 'package:flutter_shadcn_kit/registry/components/layout/table/table.dart'
    as table;

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
  // Track M: `initialValue` (empty canvas string = uncontrolled, null) and
  // `readOnly` wire straight into the `TextInputStatefulWidget` super params
  // (`text_field_widget.dart`: `super.initialValue`, `super.readOnly`).
  final label = (props['label'] ?? '') as String;
  final placeholder = (props['placeholder'] ?? 'Type here') as String;
  final disabled = (props['disabled'] ?? false) as bool;
  final obscure = (props['obscure'] ?? false) as bool;
  final initialValue = (props['initialValue'] ?? '') as String;
  final readOnly = (props['readOnly'] ?? false) as bool;
  final field = shadcn.TextField(
    placeholder: Text(placeholder),
    enabled: !disabled,
    obscureText: obscure,
    initialValue: initialValue.isEmpty ? null : initialValue,
    readOnly: readOnly,
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
  // requires `initials`; color/badge/theme fall back to theme defaults.
  // Track M: `size` wires into the nullable `Avatar(size:)` layout param
  // (parsed via `num`; the 40.0 fallback equals the kit theme default
  // `AvatarThemeDefaults.size`, so default rendering is unchanged).
  final initials = (props['initials'] ?? 'AB') as String;
  final size = ((props['size'] as num?)?.toDouble() ?? 40.0).clamp(16.0, 96.0);
  return shadcn.Avatar(initials: initials, size: size);
}

/// Local state for the catalog checkbox (builders are stateless).
/// `Checkbox` is controlled (`state` + `onChanged`, both required params),
/// so the cell owns a `CheckboxState` exactly like `_SwitchCell` owns a bool.
class _CheckboxCell extends StatefulWidget {
  final bool initialValue;
  final bool disabled;
  final bool tristate;

  const _CheckboxCell({
    required this.initialValue,
    required this.disabled,
    required this.tristate,
  });

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
      // Track M: `tristate` wires into `Checkbox(tristate:)` (ctor default
      // false), enabling indeterminate-state cycling on tap.
      tristate: widget.tristate,
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
  final tristate = (props['tristate'] ?? false) as bool;
  return _CheckboxCell(
    initialValue: value,
    disabled: disabled,
    tristate: tristate,
  );
}

Widget _buildDivider(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. `Divider` takes
  // an optional `child`, so the canvas-level `label` prop renders as that
  // child (mirrors the input builder's label-caption pattern).
  // Track M: `thickness` wires into the nullable `Divider(thickness:)` layout
  // param (parsed via `num`; the 1.0 fallback equals the kit's resolved
  // default, so default rendering is unchanged).
  final label = (props['label'] ?? '') as String;
  final thickness = ((props['thickness'] as num?)?.toDouble() ?? 1.0).clamp(
    1.0,
    8.0,
  );
  return shadcn.Divider(
    thickness: thickness,
    child: label.isEmpty ? null : Text(label),
  );
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
  final bool expand;

  const _TabsCell({
    required this.initialIndex,
    required this.firstLabel,
    required this.secondLabel,
    required this.expand,
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
      // Track M: `expand` wires into `Tabs(expand:)` (ctor default false),
      // stretching headers across the available width.
      expand: widget.expand,
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
  final expand = (props['expand'] ?? false) as bool;
  return _TabsCell(
    initialIndex: index,
    firstLabel: first,
    secondLabel: second,
    expand: expand,
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
  final bool disabled;

  const _SelectCell({
    required this.placeholder,
    required this.firstOption,
    required this.secondOption,
    required this.initialValue,
    required this.disabled,
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
      // Track M: `disabled` wires into `Select(enabled:)` (nullable; null
      // means "enabled when onChanged is non-null"). `enabled: !disabled`
      // renders identically to the old null when enabled, and the nulled
      // callback matches the switch/checkbox disabled idiom.
      enabled: !widget.disabled,
      onChanged: widget.disabled ? null : (v) => setState(() => _value = v),
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
  final disabled = (props['disabled'] ?? false) as bool;
  return _SelectCell(
    placeholder: placeholder,
    firstOption: first,
    secondOption: second,
    initialValue: value,
    disabled: disabled,
  );
}

/// Local selection state for the catalog radio group (builders are
/// stateless). Mirrors `_TabsCell`: two options plus the selected value.
class _RadioGroupCell extends StatefulWidget {
  final String firstOption;
  final String secondOption;
  final String initialValue;
  final bool disabled;

  const _RadioGroupCell({
    required this.firstOption,
    required this.secondOption,
    required this.initialValue,
    required this.disabled,
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
      // Track M: `disabled` wires into `RadioGroup(enabled:)` (nullable;
      // null means "enabled when onChanged is non-null") — same idiom as the
      // select cell above.
      enabled: !widget.disabled,
      onChanged: widget.disabled ? null : (v) => setState(() => _value = v),
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
  final disabled = (props['disabled'] ?? false) as bool;
  return _RadioGroupCell(
    firstOption: first,
    secondOption: second,
    initialValue: value,
    disabled: disabled,
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
  // Track M: `separator` maps the canvas-level 'arrow'/'slash' enum onto the
  // kit's two built-in separators (`Breadcrumb.arrowSeparator` /
  // `slashSeparator`); unknown values fall back to arrow, matching the kit's
  // own default (`separator ?? theme ?? arrowSeparator`).
  final home = (props['home'] ?? 'Home') as String;
  final current = (props['current'] ?? 'Page') as String;
  final separator = switch (props['separator']) {
    'slash' => shadcn.Breadcrumb.slashSeparator,
    _ => shadcn.Breadcrumb.arrowSeparator,
  };
  return shadcn.Breadcrumb(
    separator: separator,
    children: [Text(home), Text(current)],
  );
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
  // `ToastEntry` builds bare. Track M: `autoDismiss` wires into
  // `ToastEntry(autoDismiss:)` — the false default disables the dismiss
  // timer so the canvas node never self-dismisses (the kit ctor defaults to
  // true); the empty default `dismissDirections` disables swipe handling.
  final title = (props['title'] ?? 'Saved') as String;
  final message = (props['message'] ?? 'Saved successfully') as String;
  final autoDismiss = (props['autoDismiss'] ?? false) as bool;
  return shadcn.ToastEntry(
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 200),
    animationCurve: Curves.easeOut,
    onDismissed: () {},
    autoDismiss: autoDismiss,
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
  // Track M: `position` maps the canvas-level edge enum onto `OverlayPosition`
  // (unknown values fall back to `end`, matching the old hardcoded value).
  final title = (props['title'] ?? 'Drawer') as String;
  final content = (props['content'] ?? 'Drawer content') as String;
  final position = switch (props['position']) {
    'left' => shadcn.OverlayPosition.left,
    'right' => shadcn.OverlayPosition.right,
    'top' => shadcn.OverlayPosition.top,
    'bottom' => shadcn.OverlayPosition.bottom,
    'start' => shadcn.OverlayPosition.start,
    _ => shadcn.OverlayPosition.end,
  };
  return shadcn.DrawerWrapper(
    position: position,
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

/// Empty canvas-level strings map to null so optional slots collapse instead
/// of rendering empty gaps (mirrors the input builder's empty-label
/// convention).
Widget? _textOrNull(String value) => value.isEmpty ? null : Text(value);

/// Localization-free required-field validator (see [_buildValidated]).
class _CanvasRequiredValidator extends shadcn.Validator<String> {
  final String message;

  const _CanvasRequiredValidator([this.message = 'Required']);

  @override
  FutureOr<shadcn.ValidationResult?> validate(
    BuildContext context,
    String? value,
    shadcn.FormValidationMode lifecycle,
  ) {
    if (value == null || value.isEmpty) {
      return shadcn.InvalidResult(message, state: lifecycle);
    }
    return null;
  }
}

Widget _buildBasic(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`layout/basic/preview.dart`: person leading,
  // name title, email subtitle, chevron trailing). The real `Basic` builds
  // bare (all slots optional, theme fallbacks for every metric); its
  // internal `Expanded` row only ever sees bounded width (row containers
  // wrap children in `Flexible` — see phone_frame.dart).
  final title = (props['title'] ?? 'Title') as String;
  final subtitle = (props['subtitle'] ?? 'Subtitle') as String;
  final content = (props['content'] ?? 'Content') as String;
  final showLeading = (props['showLeading'] ?? true) as bool;
  final showTrailing = (props['showTrailing'] ?? true) as bool;
  return shadcn.Basic(
    leading: showLeading ? const Icon(Icons.person) : null,
    title: _textOrNull(title),
    subtitle: _textOrNull(subtitle),
    content: _textOrNull(content),
    trailing: showTrailing ? const Icon(Icons.chevron_right) : null,
  );
}

/// Theme-token art for the card-image `image` slot: a tonal container with a
/// centered glyph. The kit's own preview uses `Image.network` (a 404 trap on
/// canvas — the triage screenshot's broken-image box), so the catalog never
/// uses network/asset images here.
class _CardImageArt extends StatelessWidget {
  const _CardImageArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image, size: 32, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

Widget _buildCardImage(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a title plus a
  // subtitle (the required `image` slot is the theme-token art above). The
  // real `CardImage` builds bare; its vertical `Flex` holds a `Flexible`
  // image, which needs bounded height — root canvas columns are unbounded,
  // so the catalog pins a fixed height exactly like the drawer builder pins
  // a fixed width.
  final title = (props['title'] ?? 'Card title') as String;
  final subtitle = (props['subtitle'] ?? 'Card subtitle') as String;
  return SizedBox(
    height: 240,
    child: shadcn.CardImage(
      image: const _CardImageArt(),
      title: _textOrNull(title),
      subtitle: _textOrNull(subtitle),
    ),
  );
}

Widget _buildScaffold(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: an app title
  // plus a body line. Dropping a scaffold yields the default app shell —
  // the real kit `Scaffold` (its `Overlay` + `DrawerOverlay` build bare)
  // with a default `AppBar` titled from props and the body text as the
  // content slot. Colors stay null so the components theme supplies the
  // default background (`ScaffoldTheme.backgroundColor` then
  // `colorScheme.background`). The fixed height mirrors the drawer
  // builder's fixed width: the kit flex needs bounded height, which root
  // canvas columns do not provide.
  final title = (props['title'] ?? 'My App') as String;
  final body = (props['body'] ?? 'Welcome') as String;
  return SizedBox(
    height: 320,
    child: shadcn.Scaffold(
      headers: [shadcn.AppBar(title: Text(title))],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(body),
      ),
    ),
  );
}

Widget _buildCollapsible(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented, mirroring the
  // accordion builder (trigger/content/expanded). The real `Collapsible`
  // owns its expansion state; trigger + content mirror the component's own
  // preview (`layout/collapsible/preview.dart`).
  final trigger = (props['trigger'] ?? 'Show more') as String;
  final content = (props['content'] ?? 'Hidden details') as String;
  final expanded = (props['expanded'] ?? false) as bool;
  return shadcn.Collapsible(
    isExpanded: expanded,
    children: [
      shadcn.CollapsibleTrigger(child: Text(trigger)),
      shadcn.CollapsibleContent(child: Text(content)),
    ],
  );
}

Widget _buildSteps(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two step
  // titles plus their detail bodies. The real `Steps` takes `StepItem`
  // children (`title` + `content` widgets, both required); numbering and
  // connectors render from the children themselves.
  final step1 = (props['step1'] ?? 'Step 1') as String;
  final detail1 = (props['detail1'] ?? 'First step details') as String;
  final step2 = (props['step2'] ?? 'Step 2') as String;
  final detail2 = (props['detail2'] ?? 'Second step details') as String;
  return shadcn.Steps(
    children: [
      shadcn.StepItem(title: Text(step1), content: [Text(detail1)]),
      shadcn.StepItem(title: Text(step2), content: [Text(detail2)]),
    ],
  );
}

Widget _buildTimeline(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two
  // time/title/detail entries. The real `Timeline` takes `TimelineData`
  // (`time` + `title` required, `content` optional); colors stay null so the
  // theme supplies indicator/connector defaults.
  final time1 = (props['time1'] ?? '9:00 AM') as String;
  final title1 = (props['title1'] ?? 'Kickoff') as String;
  final detail1 = (props['detail1'] ?? 'Project kickoff meeting') as String;
  final time2 = (props['time2'] ?? '2:00 PM') as String;
  final title2 = (props['title2'] ?? 'Review') as String;
  final detail2 = (props['detail2'] ?? 'Design review session') as String;
  return shadcn.Timeline(
    data: [
      shadcn.TimelineData(
        time: Text(time1),
        title: Text(title1),
        content: _textOrNull(detail1),
      ),
      shadcn.TimelineData(
        time: Text(time2),
        title: Text(title2),
        content: _textOrNull(detail2),
      ),
    ],
  );
}

Widget _buildOutlinedContainer(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `OutlinedContainer` requires only `child`; the canvas-level `label` prop
  // renders as that child (same content-prop pattern as the card builder).
  final label = (props['label'] ?? 'Outlined') as String;
  return shadcn.OutlinedContainer(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(label),
    ),
  );
}

Widget _buildHidden(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `Hidden` needs `hidden` + `child` (durations/curves all defaulted); the
  // canvas-level `label` prop renders as that child so the visible state is
  // obvious on canvas.
  final label = (props['label'] ?? 'Hidden content') as String;
  final hidden = (props['hidden'] ?? false) as bool;
  return shadcn.Hidden(hidden: hidden, child: Text(label));
}

/// Parses a canvas-level shortcut string (`'Ctrl+K'`, `'Shift+Alt+S'`) into
/// logical keys for [shadcn.KeyboardDisplay]. Unknown tokens are skipped; a
/// fully-unknown string falls back to `keyK` instead of crashing (single
/// letters/digits map via their ASCII key ids, which equal the logical ids).
List<LogicalKeyboardKey> _parseShortcutKeys(String raw) {
  final mapped = <LogicalKeyboardKey>[];
  for (final token in raw.split(RegExp(r'[+\s]+'))) {
    final key = _shortcutToken(token);
    if (key != null) mapped.add(key);
  }
  return mapped.isEmpty ? [LogicalKeyboardKey.keyK] : mapped;
}

LogicalKeyboardKey? _shortcutToken(String token) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return null;
  switch (t) {
    case 'ctrl':
    case 'control':
      return LogicalKeyboardKey.controlLeft;
    case 'shift':
      return LogicalKeyboardKey.shiftLeft;
    case 'alt':
    case 'option':
      return LogicalKeyboardKey.altLeft;
    case 'meta':
    case 'cmd':
    case 'command':
    case 'win':
      return LogicalKeyboardKey.metaLeft;
    case 'enter':
    case 'return':
      return LogicalKeyboardKey.enter;
    case 'space':
      return LogicalKeyboardKey.space;
    case 'tab':
      return LogicalKeyboardKey.tab;
    case 'esc':
    case 'escape':
      return LogicalKeyboardKey.escape;
    case 'backspace':
      return LogicalKeyboardKey.backspace;
    case 'delete':
    case 'del':
      return LogicalKeyboardKey.delete;
  }
  if (t.length == 1) {
    final c = t.codeUnitAt(0);
    if ((c >= 97 && c <= 122) || (c >= 48 && c <= 57)) {
      return LogicalKeyboardKey(c);
    }
  }
  return null;
}

Widget _buildKeyboardShortcut(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `KeyboardDisplay` needs `List<LogicalKeyboardKey>`; the canvas-level
  // `keys` string prop parses via [_parseShortcutKeys] (same stringly-typed
  // convention as the rest of the catalog). Key glyphs resolve through a
  // default `KeyboardShortcutDisplayMapper`, which the key widgets require
  // as a `Data` ancestor (it also renders the Ctrl/Shift/Alt/Cmd labels).
  final keys = (props['keys'] ?? 'Ctrl+K') as String;
  return shadcn.KeyboardShortcutDisplayMapper(
    child: shadcn.KeyboardDisplay(keys: _parseShortcutKeys(keys)),
  );
}

Widget _buildTracker(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a segment
  // count plus one level applied to every segment. The real `Tracker` takes
  // `TrackerData` (`tooltip` + `level`, both required); tooltips are plain
  // segment labels and the level maps to the kit's `TrackerLevel` set.
  // (Qualified: material's `Tooltip` is also imported here, but `Tracker`
  // is kit-unique.)
  final segments = ((props['segments'] as num?)?.toInt() ?? 3).clamp(1, 5);
  final level = (props['level'] ?? 'fine') as String;
  final resolved = switch (level) {
    'warning' => shadcn.TrackerLevel.warning,
    'critical' => shadcn.TrackerLevel.critical,
    'unknown' => shadcn.TrackerLevel.unknown,
    _ => shadcn.TrackerLevel.fine,
  };
  return shadcn.Tracker(
    data: [
      for (var i = 0; i < segments; i++)
        shadcn.TrackerData(
          tooltip: Text('Segment ${i + 1}'),
          level: resolved,
        ),
    ],
  );
}

Widget _buildChat(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `ChatBubble` requires only `child` (type/color/alignment all fall back
  // to the chat theme); the canvas-level `message` prop renders as that
  // child (same content-prop pattern as the card builder).
  final message = (props['message'] ?? 'Hello!') as String;
  return shadcn.ChatBubble(child: Text(message));
}

Widget _buildSelectable(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real kit
  // `SelectableText` takes a positional string (qualified: material's
  // `SelectableText` is also imported here); cursor/selection styling falls
  // back to the theme.
  final text = (props['text'] ?? 'Select me') as String;
  return shadcn.SelectableText(text);
}

/// Local rating state for the catalog star rating (builders are stateless).
/// `StarRating` is controlled (`value` + `onChanged`), so the cell owns a
/// double exactly like `_SwitchCell` owns a bool.
class _StarRatingCell extends StatefulWidget {
  final double initialValue;
  final double max;

  const _StarRatingCell({required this.initialValue, required this.max});

  @override
  State<_StarRatingCell> createState() => _StarRatingCellState();
}

class _StarRatingCellState extends State<_StarRatingCell> {
  late double _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return shadcn.StarRating(
      value: _value,
      max: widget.max,
      onChanged: (v) =>
          setState(() => _value = v.clamp(0.0, widget.max).toDouble()),
    );
  }
}

Widget _buildStarRating(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a value plus
  // the star count. Both parse via `num` (`jsonDecode` yields `int` for
  // whole numbers) and clamp so hand-written docs never crash.
  final max = (((props['max'] as num?)?.toDouble() ?? 5).clamp(1, 10)).toDouble();
  final value =
      (((props['value'] as num?)?.toDouble() ?? 3).clamp(0, max)).toDouble();
  return _StarRatingCell(initialValue: value, max: max);
}

Widget _buildClickable(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `Clickable` is a state-aware gesture surface requiring only `child`
  // (all hover/focus/press handling defaults to the theme); the
  // canvas-level `label` prop renders as that child. `onPressed` stays a
  // no-op so the canvas node never navigates.
  final label = (props['label'] ?? 'Tap me') as String;
  return shadcn.Clickable(onPressed: () {}, child: Text(label));
}

Widget _buildScrollbar(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real kit
  // `Scrollbar` (qualified: material's `Scrollbar` is also imported here)
  // requires only `child`; the canvas-level `label` prop renders inside a
  // fixed-height box so the wrapper has a visible footprint on canvas.
  final label = (props['label'] ?? 'Scrollable content') as String;
  return shadcn.Scrollbar(
    child: SizedBox(height: 64, child: Text(label)),
  );
}

/// Local page state for the catalog pagination (builders are stateless).
/// Mirrors `_TabsCell`: the current page plus the total page count.
class _PaginationCell extends StatefulWidget {
  final int initialPage;
  final int totalPages;

  const _PaginationCell({
    required this.initialPage,
    required this.totalPages,
  });

  @override
  State<_PaginationCell> createState() => _PaginationCellState();
}

class _PaginationCellState extends State<_PaginationCell> {
  late int _page = widget.initialPage;

  @override
  Widget build(BuildContext context) {
    return shadcn.Pagination(
      page: _page,
      totalPages: widget.totalPages,
      onPageChanged: (p) =>
          setState(() => _page = p.clamp(1, widget.totalPages)),
    );
  }
}

Widget _buildPagination(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: the current
  // page plus the total page count (both parsed via `num`, clamped into
  // range). Button labels come from `ShadcnLocalizations.of`, which falls
  // back to English without a delegate, so the node builds bare.
  final total = ((props['totalPages'] as num?)?.toInt() ?? 5).clamp(1, 20);
  final page = ((props['page'] as num?)?.toInt() ?? 1).clamp(1, total);
  return _PaginationCell(initialPage: page, totalPages: total);
}

Widget _buildAlertDialog(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/alert_dialog/preview.dart`: a title,
  // a message, and a Close action). The real `AlertDialog` (qualified:
  // material's `AlertDialog` is also imported here) is all-optional and
  // builds bare on the same `ModalBackdrop`/`ModalContainer` primitives as
  // the dialog catalog builder.
  final title = (props['title'] ?? 'Are you sure?') as String;
  final message =
      (props['message'] ?? 'This action cannot be undone.') as String;
  final showActions = (props['showActions'] ?? true) as bool;
  return shadcn.AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      if (showActions)
        shadcn.OutlineButton(onPressed: () {}, child: const Text('Close')),
    ],
  );
}

/// Track M overlay-driven inline forms (2026-09-05): no live overlay context
/// exists on canvas, so each renders its INLINE form statically — the trigger
/// plus the inline content a user would see — documented per builder. Never a
/// `preview.dart` embed (those render full `Scaffold`s); never network/asset
/// images; theme-token styling only.
Widget _buildMenu(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/menu/preview.dart`: label + buttons in
  // a popup). The kit barrel hides `menu.dart`'s own `MenuPopup`, so the
  // inline form uses the exported `popup.dart` `MenuPopup` (same styled
  // container idiom). `MenuLabel`/`MenuButton` assert a `MenuGroupData`
  // ancestor ("must be a child of MenuGroup"), so the items render inside a
  // real `MenuGroup` whose builder lays them in the popup (exactly how
  // `DropdownMenu` composes them internally); `autofocus: false` keeps canvas
  // focus stable. `MenuButton`s carry no `onPressed`, rendering as
  // non-interactive rows exactly like the preview's.
  final heading = (props['heading'] ?? 'File') as String;
  final item1 = (props['item1'] ?? 'New') as String;
  final item2 = (props['item2'] ?? 'Open') as String;
  return shadcn.MenuGroup(
    direction: Axis.vertical,
    autofocus: false,
    builder: (context, children) => shadcn.MenuPopup(children: children),
    children: [
      shadcn.MenuLabel(child: Text(heading)),
      shadcn.MenuButton(child: Text(item1)),
      shadcn.MenuButton(child: Text(item2)),
    ],
  );
}

Widget _buildPopover(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/popover/preview.dart`: trigger button
  // + title/body builder content). The kit ships no bare `Popover` widget
  // (only the `showPopover` context API plus `PopoverOverlayWidget`, which
  // requires an `anchorContext`), so the catalog renders the trigger plus the
  // builder content statically — the content in a real `ModalContainer`,
  // mirroring the dialog catalog builder's inline-content precedent.
  final trigger = (props['trigger'] ?? 'Open Popover') as String;
  final title = (props['title'] ?? 'Popover title') as String;
  final body =
      (props['body'] ?? 'Use popovers for contextual helper content.')
          as String;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      shadcn.PrimaryButton(onPressed: () {}, child: Text(trigger)),
      const SizedBox(height: 8),
      shadcn.ModalContainer(
        filled: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    ],
  );
}

Widget _buildPopup(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/popup/preview.dart`: padded rows around
  // a divider). The real `MenuPopup` builds bare (all context reads are
  // null-safe `maybeOf`/sheet checks, same as the menu builder above).
  final item1 = (props['item1'] ?? 'Profile') as String;
  final item2 = (props['item2'] ?? 'Settings') as String;
  final item3 = (props['item3'] ?? 'Sign out') as String;
  return shadcn.MenuPopup(
    children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(item1)),
      Padding(padding: const EdgeInsets.all(8), child: Text(item2)),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(8), child: Text(item3)),
    ],
  );
}

Widget _buildMenubar(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/menubar/preview.dart`: File/Edit menus
  // with submenus). The real `Menubar` builds bare (it provides its own
  // `MenuGroup` scope internally); submenus open in the overlay at runtime,
  // so canvas shows the desktop bar itself.
  final menu1 = (props['menu1'] ?? 'File') as String;
  final menu2 = (props['menu2'] ?? 'Edit') as String;
  return shadcn.Menubar(
    border: true,
    children: [
      shadcn.MenuButton(
        subMenu: const [
          shadcn.MenuButton(child: Text('New')),
          shadcn.MenuButton(child: Text('Open')),
        ],
        child: Text(menu1),
      ),
      shadcn.MenuButton(
        subMenu: const [
          shadcn.MenuButton(child: Text('Cut')),
          shadcn.MenuButton(child: Text('Copy')),
        ],
        child: Text(menu2),
      ),
    ],
  );
}

Widget _buildDropdownMenu(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/dropdown_menu/preview.dart`: account
  // label + action buttons). The real `DropdownMenu` builds bare (it builds
  // its own `MenuGroup` scope; `closeOverlay` only runs in the dismiss
  // callback). Rendered inline — the live `showDropdown` anchor is
  // overlay-only.
  final heading = (props['heading'] ?? 'My Account') as String;
  final item1 = (props['item1'] ?? 'Profile') as String;
  final item2 = (props['item2'] ?? 'Settings') as String;
  return shadcn.DropdownMenu(
    children: [
      shadcn.MenuLabel(child: Text(heading)),
      const shadcn.MenuDivider(),
      shadcn.MenuButton(child: Text(item1)),
      shadcn.MenuButton(child: Text(item2)),
    ],
  );
}

Widget _buildContextMenu(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a trigger hint
  // plus two menu items. The real `ContextMenu` builds bare (gesture
  // detection only); the items live in the right-click overlay, so canvas
  // shows the trigger child — the same honest-static convention as the
  // tooltip catalog builder.
  final hint = (props['hint'] ?? 'Right-click me') as String;
  final item1 = (props['item1'] ?? 'Back') as String;
  final item2 = (props['item2'] ?? 'Reload') as String;
  return shadcn.ContextMenu(
    items: [
      shadcn.MenuButton(child: Text(item1)),
      shadcn.MenuButton(child: Text(item2)),
    ],
    child: shadcn.OutlineButton(onPressed: () {}, child: Text(hint)),
  );
}

Widget _buildHoverCard(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a handle plus
  // a title/body preview. The real `HoverCard` builds bare (overlay only on
  // hover/long-press); the preview content lives in `hoverBuilder`, so canvas
  // shows the handle — the same honest-static convention as the tooltip
  // catalog builder. The card content reuses the card builder's
  // `Card(padding:, child:)` idiom (never shown on canvas, but kept
  // theme-true for export fidelity).
  final handle = (props['handle'] ?? 'Hover card') as String;
  final title = (props['title'] ?? 'Hover title') as String;
  final body = (props['body'] ?? 'Rich preview content.') as String;
  return shadcn.HoverCard(
    hoverBuilder: (context) => SizedBox(
      width: 240,
      child: shadcn.Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      ),
    ),
    child: shadcn.OutlineButton(onPressed: () {}, child: Text(handle)),
  );
}

Widget _buildCommand(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a search hint
  // plus two palette rows. The live `Command` shell cannot render inline: it
  // wraps itself in an `IntrinsicWidth` whose results viewport cannot compute
  // intrinsic dimensions under loose canvas constraints, and its
  // unconditional footer hint row overflows any gallery-fitting fixed width
  // (the kit's own 300px preview overflows the same way). The catalog
  // therefore renders the palette's STATIC query form — a real `TextField`
  // search row plus the real `CommandCategory`/`CommandItem` result parts in
  // the shared `MenuPopup` container (all bare-capable; `CommandItem` owns
  // its focus/hover state internally). Debounced stream search, keyboard
  // navigation, and the footer hints are runtime-only.
  final hint = (props['hint'] ?? 'Search commands...') as String;
  final item1 = (props['item1'] ?? 'Calendar') as String;
  final item2 = (props['item2'] ?? 'Settings') as String;
  return SizedBox(
    width: 300,
    child: shadcn.MenuPopup(
      children: [
        shadcn.TextField(placeholder: Text(hint)),
        shadcn.CommandCategory(
          title: const Text('Suggestions'),
          children: [
            shadcn.CommandItem(title: Text(item1), onTap: () {}),
            shadcn.CommandItem(title: Text(item2), onTap: () {}),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSwiper(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a swipe hint
  // plus the sheet body. The real `Swiper` builds bare (overlay only on
  // swipe); the sheet content lives in `builder`, so canvas shows the trigger
  // child — the same honest-static convention as the tooltip catalog
  // builder. The fixed trigger height keeps the gesture surface visible.
  final hint = (props['hint'] ?? 'Swipe up from the bottom') as String;
  final content = (props['content'] ?? 'Swipe content') as String;
  return shadcn.Swiper(
    handler: shadcn.SwiperHandler.sheet,
    position: shadcn.OverlayPosition.bottom,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(content),
    ),
    child: SizedBox(
      height: 96,
      child: Center(
        child: shadcn.OutlinedContainer(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(hint),
          ),
        ),
      ),
    ),
  );
}

Widget _buildRefreshTrigger(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: three static
  // rows. The real `RefreshTrigger` builds bare around its child; the fixed
  // height mirrors the drawer builder's fixed width (the scrollable needs
  // bounded height, which root canvas columns do not provide). Pull gestures
  // only animate at runtime; canvas shows the wrapped list.
  final item1 = (props['item1'] ?? 'Row 1') as String;
  final item2 = (props['item2'] ?? 'Row 2') as String;
  final item3 = (props['item3'] ?? 'Row 3') as String;
  return shadcn.RefreshTrigger(
    onRefresh: () async {},
    child: SizedBox(
      height: 140,
      child: ListView(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(item1)),
          Padding(padding: const EdgeInsets.all(12), child: Text(item2)),
          Padding(padding: const EdgeInsets.all(12), child: Text(item3)),
        ],
      ),
    ),
  );
}

/// Local selection state for the catalog tab container (builders are
/// stateless). Mirrors the kit's own preview builder: a header row plus the
/// selected-tab label. `TabContainer` + `TabItem` resolve to the tab_container
/// barrel (the `tabs` barrel hides its own same-named types, so the
/// `shadcn.` prefix is unambiguous).
class _TabContainerCell extends StatefulWidget {
  final int initialIndex;
  final List<String> labels;

  const _TabContainerCell({required this.initialIndex, required this.labels});

  @override
  State<_TabContainerCell> createState() => _TabContainerCellState();
}

class _TabContainerCellState extends State<_TabContainerCell> {
  late int _selected = widget.initialIndex.clamp(0, widget.labels.length - 1);

  @override
  Widget build(BuildContext context) {
    return shadcn.TabContainer(
      selected: _selected,
      onSelect: (i) =>
          setState(() => _selected = i.clamp(0, widget.labels.length - 1)),
      builder: (context, children) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
          const SizedBox(height: 8),
          Text('Selected tab: ${_selected + 1}'),
        ],
      ),
      childBuilder: (context, data, child) {
        final selected = data.selected == data.index;
        return GestureDetector(
          onTap: () => data.onSelect?.call(data.index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: child,
            ),
          ),
        );
      },
      children: [
        for (final label in widget.labels) shadcn.TabItem(child: Text(label)),
      ],
    );
  }
}

Widget _buildTabContainer(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: three tab
  // labels plus the selected index (parsed via `num`, see _buildProgress).
  final tab1 = (props['tab1'] ?? 'Overview') as String;
  final tab2 = (props['tab2'] ?? 'Details') as String;
  final tab3 = (props['tab3'] ?? 'Reviews') as String;
  final index = (props['index'] as num?)?.toInt() ?? 0;
  return _TabContainerCell(
    initialIndex: index,
    labels: [tab1, tab2, tab3],
  );
}

/// Local active-tab state for the catalog tab list (builders are stateless).
/// `tabs.TabList` (the tabs barrel's header row) wraps itself in a
/// `TabContainer` internally, so no external scope is needed — mirrors
/// `_TabsCell`, but for the standalone header-row component.
class _TabListCell extends StatefulWidget {
  final int initialIndex;
  final String firstLabel;
  final String secondLabel;

  const _TabListCell({
    required this.initialIndex,
    required this.firstLabel,
    required this.secondLabel,
  });

  @override
  State<_TabListCell> createState() => _TabListCellState();
}

class _TabListCellState extends State<_TabListCell> {
  late int _index = widget.initialIndex.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    return tabs.TabList(
      index: _index,
      onChanged: (i) => setState(() => _index = i.clamp(0, 1)),
      children: [
        tabs.TabItem(child: Text(widget.firstLabel)),
        tabs.TabItem(child: Text(widget.secondLabel)),
      ],
    );
  }
}

Widget _buildTabList(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented, mirroring the
  // tabs kind (two labels + selected index). NOTE: `tabs.TabItem` (not
  // `shadcn.TabItem`) — the header row takes the tabs barrel's own `TabChild`
  // family.
  final index = (props['index'] as num?)?.toInt() ?? 0;
  final first = (props['tab1'] ?? 'Tab 1') as String;
  final second = (props['tab2'] ?? 'Tab 2') as String;
  return _TabListCell(
    initialIndex: index,
    firstLabel: first,
    secondLabel: second,
  );
}

/// Local focus state for the catalog tab pane (builders are stateless).
/// Mirrors the kit's own preview: `TabPaneData` items, an `itemBuilder`
/// returning the tab_container barrel's `TabChildWidget`, and a content card
/// reflecting the focused tab.
class _TabPaneCell extends StatefulWidget {
  final int initialFocused;
  final List<String> labels;

  const _TabPaneCell({required this.initialFocused, required this.labels});

  @override
  State<_TabPaneCell> createState() => _TabPaneCellState();
}

class _TabPaneCellState extends State<_TabPaneCell> {
  late int _focused = widget.initialFocused.clamp(0, widget.labels.length - 1);

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final label in widget.labels) shadcn.TabPaneData(label),
    ];
    final focused = _focused.clamp(0, items.length - 1);
    return shadcn.TabPane<String>(
      items: items,
      focused: focused,
      onFocused: (i) =>
          setState(() => _focused = i.clamp(0, items.length - 1)),
      itemBuilder: (context, item, index) =>
          shadcn.TabChildWidget(indexed: true, child: Text(item.data)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Content: ${items[focused].data}'),
      ),
    );
  }
}

Widget _buildTabPane(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: three tab
  // labels plus the focused index (parsed via `num`, see _buildProgress).
  final tab1 = (props['tab1'] ?? 'Overview') as String;
  final tab2 = (props['tab2'] ?? 'Analytics') as String;
  final tab3 = (props['tab3'] ?? 'Settings') as String;
  final focused = (props['focused'] as num?)?.toInt() ?? 0;
  return _TabPaneCell(
    initialFocused: focused,
    labels: [tab1, tab2, tab3],
  );
}

/// Local controller ownership for the catalog stepper (builders are
/// stateless). Mirrors the kit's own preview: a `StepperController` created
/// in `initState` and disposed with the cell. Vertical direction keeps the
/// three steps narrow-safe on canvas.
class _StepperCell extends StatefulWidget {
  final int initialStep;
  final List<String> steps;
  final List<String> details;

  const _StepperCell({
    required this.initialStep,
    required this.steps,
    required this.details,
  });

  @override
  State<_StepperCell> createState() => _StepperCellState();
}

class _StepperCellState extends State<_StepperCell> {
  late final shadcn.StepperController _controller;

  @override
  void initState() {
    super.initState();
    _controller = shadcn.StepperController(
      currentStep: widget.initialStep.clamp(0, widget.steps.length - 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.Stepper(
      controller: _controller,
      direction: Axis.vertical,
      steps: [
        for (var i = 0; i < widget.steps.length; i++)
          shadcn.Step(
            title: Text(widget.steps[i]),
            // Required: the circle variant force-unwraps the built content
            // (`child!` in `_step_variant_circle.dart`), so a null
            // contentBuilder crashes even for inactive steps.
            contentBuilder: (_) => Text(widget.details[i]),
          ),
      ],
    );
  }
}

Widget _buildStepper(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`navigation/stepper/preview.dart`: three titled
  // steps with bodies): three step titles + bodies plus the active step
  // index. (`Step` is kit-qualified: material's `Step` is also imported
  // here.)
  final step1 = (props['step1'] ?? 'Details') as String;
  final detail1 = (props['detail1'] ?? 'Provide your details.') as String;
  final step2 = (props['step2'] ?? 'Payment') as String;
  final detail2 = (props['detail2'] ?? 'Choose a payment method.') as String;
  final step3 = (props['step3'] ?? 'Confirm') as String;
  final detail3 = (props['detail3'] ?? 'Review and submit.') as String;
  final step = (props['step'] as num?)?.toInt() ?? 0;
  return _StepperCell(
    initialStep: step,
    steps: [step1, step2, step3],
    details: [detail1, detail2, detail3],
  );
}

/// Local value state for the catalog slider (builders are stateless).
/// `Slider` is controlled (`value` + `onChanged`, both required), so the
/// cell owns a double exactly like `_StarRatingCell` owns its rating.
/// (Qualified: material's `Slider` is also imported here.)
class _SliderCell extends StatefulWidget {
  final double initialValue;

  const _SliderCell({required this.initialValue});

  @override
  State<_SliderCell> createState() => _SliderCellState();
}

class _SliderCellState extends State<_SliderCell> {
  late double _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return shadcn.Slider(
      value: _value,
      onChanged: (v) => setState(() => _value = v.clamp(0.0, 1.0)),
    );
  }
}

Widget _buildSlider(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: the static value
  // (parsed via `num`, clamped into the 0..1 domain like the progress
  // catalog builder).
  final value = ((props['value'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0);
  return _SliderCell(initialValue: value);
}

/// Parses a canvas-level hex string (`'#2196F3'`, `'2196F3'`, `'80FFFFFF'`)
/// into a [Color] for the color-kind builders. Malformed input falls back to
/// the invented default blue (the same `0xFF2196F3` the kit's own history
/// preview seeds), so hand-written docs never crash.
Color _parseHexColor(String raw) {
  var hex = raw.trim().replaceAll('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  if (value == null || hex.length != 8) return const Color(0xFF2196F3);
  return Color(value);
}

/// Formats a [Color] as an uppercase `'#RRGGBB'` label for the color-kind
/// swatch rows (mirrors the kit's `colorToHex` without the dependency).
String _toHexLabel(Color color) {
  final rgb = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  return '#$rgb';
}

/// Track P builders (2026-09-05): the hardest kinds — pickers, grids, and
/// form/color shells. Same honesty rules as Track M: no canvas blocks exist
/// in `components.json` for any of these, so defaults are invented and
/// documented per builder; only bool/string/num/enum prop types already
/// established by the seed kinds; theme-token styling only (the swatch
/// colors below are data values, not chrome — a color kind must show a
/// color, and the hex prop drives them).
Widget _buildInputOtp(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: a six-box OTP
  // row like the component's own preview (`form/input_otp/preview.dart`:
  // digit-only character children). The real `InputOTP` builds bare (focus
  // moves on tap at runtime); clipboard/paste handling is runtime-only, so
  // canvas shows the static boxes.
  final length = ((props['length'] as num?)?.toInt() ?? 6).clamp(4, 8);
  return shadcn.InputOTP(
    onChanged: (_) {},
    children: [
      for (var i = 0; i < length; i++)
        shadcn.InputOTPChild.character(allowDigit: true),
    ],
  );
}

Widget _buildCalendar(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: the current
  // month in single-select mode. The real `Calendar` builds bare (view
  // navigation is internal state); value stays null and selection no-ops,
  // so canvas shows the static month grid. The canvas-level `mode` string
  // maps onto `CalendarSelectionMode` (unknown falls back to single, same
  // fallback idiom as the tracker builder).
  final mode = switch (props['mode']) {
    'range' => shadcn.CalendarSelectionMode.range,
    'multi' => shadcn.CalendarSelectionMode.multi,
    'none' => shadcn.CalendarSelectionMode.none,
    _ => shadcn.CalendarSelectionMode.single,
  };
  return shadcn.Calendar(
    view: shadcn.CalendarView.now(),
    selectionMode: mode,
    onChanged: (_) {},
  );
}

Widget _buildDatePicker(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `DatePicker` (an `ObjectFormField` trigger) builds bare; the calendar
  // opens in the overlay at runtime, so canvas shows the trigger with the
  // placeholder — the same honest-static convention as the tooltip catalog
  // builder. The optional `label` renders as a caption above (mirrors the
  // input builder; `DatePicker` takes no label param).
  final placeholder = (props['placeholder'] ?? 'Select date') as String;
  final label = (props['label'] ?? '') as String;
  final field = shadcn.DatePicker(
    value: null,
    onChanged: (_) {},
    placeholder: Text(placeholder),
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

Widget _buildTimePicker(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented, mirroring the
  // date picker builder above (trigger + placeholder statically; the clock
  // opens in the overlay at runtime).
  final placeholder = (props['placeholder'] ?? 'Select time') as String;
  final label = (props['label'] ?? '') as String;
  final field = shadcn.TimePicker(
    value: null,
    onChanged: (_) {},
    placeholder: Text(placeholder),
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

/// Theme-token art for a carousel slide: a tonal container with a centered
/// glyph plus the slide label. Never network/asset images (same rule as the
/// card-image art above).
class _CarouselArt extends StatelessWidget {
  final int index;

  const _CarouselArt({required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.slideshow,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('Slide ${index + 1}'),
          ],
        ),
      ),
    );
  }
}

Widget _buildCarousel(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: three tonal
  // slides. The real `Carousel` builds bare around `itemBuilder`
  // (`autoplaySpeed` stays null, so no timers run on canvas); the fixed
  // height mirrors the scaffold builder's fixed shell (the kit's own preview
  // pins 200px the same way). The dots below mirror the first page
  // statically (`DotIndicator` is its own catalog-ready kind).
  final slides = ((props['slides'] as num?)?.toInt() ?? 3).clamp(1, 5);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 160,
        child: shadcn.Carousel(
          transition: const shadcn.CarouselTransition.sliding(),
          itemCount: slides,
          itemBuilder: (context, index) => _CarouselArt(index: index),
        ),
      ),
      const SizedBox(height: 8),
      shadcn.DotIndicator(index: 0, length: slides),
    ],
  );
}

Widget _buildTree(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`display/tree/preview.dart`: Design{Research,
  // Wireframes} + Launch, both parents expanded). The real `TreeView` builds
  // bare around `TreeItem` nodes; `shrinkWrap: true` keeps the inner
  // `ListView` bounded (root canvas columns are unbounded, so the default
  // false would crash — the fixed-shell precedent in the other direction).
  final node1 = (props['node1'] ?? 'Design') as String;
  final child1 = (props['child1'] ?? 'Research') as String;
  final child2 = (props['child2'] ?? 'Wireframes') as String;
  final node2 = (props['node2'] ?? 'Launch') as String;
  return shadcn.TreeView<String>(
    shrinkWrap: true,
    nodes: [
      shadcn.TreeItem(
        data: node1,
        expanded: true,
        children: [
          shadcn.TreeItem(data: child1),
          shadcn.TreeItem(data: child2),
        ],
      ),
      shadcn.TreeItem(data: node2),
    ],
    builder: (context, item) => Text(item.data),
  );
}

Widget _buildTable(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`layout/table/preview.dart`: Name/Role/Status
  // header plus data rows), trimmed to a header plus two rows. The kit
  // `Table` is imported directly (the barrel hides `Table`/`TableRow` behind
  // material's names — see the `table.` import above) and builds bare;
  // frozen/scroll behavior is runtime-only.
  final header1 = (props['header1'] ?? 'Name') as String;
  final header2 = (props['header2'] ?? 'Role') as String;
  final name1 = (props['name1'] ?? 'Avery') as String;
  final role1 = (props['role1'] ?? 'Designer') as String;
  final name2 = (props['name2'] ?? 'Jordan') as String;
  final role2 = (props['role2'] ?? 'Engineer') as String;
  return table.Table(
    rows: [
      table.TableHeader(
        cells: [
          table.TableCell(child: Text(header1)),
          table.TableCell(child: Text(header2)),
        ],
      ),
      table.TableRow(
        cells: [
          table.TableCell(child: Text(name1)),
          table.TableCell(child: Text(role1)),
        ],
      ),
      table.TableRow(
        cells: [
          table.TableCell(child: Text(name2)),
          table.TableCell(child: Text(role2)),
        ],
      ),
    ],
  );
}

Widget _buildForm(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`form/form/preview.dart`: a `FormTableLayout`
  // row plus a submit button). The real `Form` (qualified: material's `Form`
  // is also imported here) builds bare with an internal controller;
  // validation/submission execute at runtime, so the submit button is a
  // no-op on canvas and the field shows no error state.
  final label = (props['label'] ?? 'Name') as String;
  final placeholder = (props['placeholder'] ?? 'Jane Doe') as String;
  final submitLabel = (props['submitLabel'] ?? 'Submit') as String;
  return shadcn.Form(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        shadcn.FormTableLayout(
          rows: [
            shadcn.FormField<String>(
              key: const shadcn.FormKey<String>(#name),
              label: Text(label),
              child: shadcn.TextField(placeholder: Text(placeholder)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        shadcn.PrimaryButton(
          onPressed: () {},
          child: Text(submitLabel),
        ),
      ],
    ),
  );
}

Widget _buildFormField(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: an empty
  // object field showing its placeholder. The real `ObjectFormField` builds
  // bare (the editor opens in a dialog/popover at runtime); the canvas-level
  // `value` string renders through `builder` when non-empty (same
  // empty-means-null convention as the input builder's label). The static
  // editor content reuses the input builder's `TextField` idiom (never shown
  // on canvas, but kept theme-true for export fidelity — the hover-card
  // precedent).
  final placeholder = (props['placeholder'] ?? 'Select item') as String;
  final value = (props['value'] ?? '') as String;
  return shadcn.ObjectFormField<String>(
    value: value.isEmpty ? null : value,
    onChanged: (_) {},
    placeholder: Text(placeholder),
    builder: (context, selected) => Text(selected),
    editorBuilder: (context, _) => shadcn.TextField(
      placeholder: const Text('Search...'),
    ),
  );
}

Widget _buildFormattedInput(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented from the
  // component's own preview (`form/formatted_input/preview.dart`: an
  // MM/DD/YYYY date mask). The real `FormattedInput` builds bare around its
  // `FormattedValue` segments (static separators + editable parts with
  // placeholders); the optional `label` renders as a caption above (mirrors
  // the input builder; `FormattedInput` takes no label param).
  final label = (props['label'] ?? '') as String;
  final field = shadcn.FormattedInput(
    onChanged: (_) {},
    initialValue: shadcn.FormattedValue([
      shadcn.InputPart.editable(
        length: 2,
        width: 40,
        placeholder: const Text('MM'),
      ).withValue('01'),
      shadcn.InputPart.static('/'),
      shadcn.InputPart.editable(
        length: 2,
        width: 40,
        placeholder: const Text('DD'),
      ).withValue('02'),
      shadcn.InputPart.static('/'),
      shadcn.InputPart.editable(
        length: 4,
        width: 60,
        placeholder: const Text('YYYY'),
      ).withValue('2021'),
    ]),
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

Widget _buildValidated(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`form/validated/preview.dart`: a `TextField`
  // under a required-field validator whose builder shows the error message).
  // The real `Validated` builds bare (it owns its `Form` internally, so no
  // ancestor is needed); the kit validates on attach, so canvas shows that
  // initial error state — subsequent validation executes at runtime only.
  // The validator is catalog-local: the kit's `NotEmptyValidator` reads its
  // message from `ShadcnLocalizations` at attach time (null without
  // delegates — canvas nodes must build bare), so the message rides the
  // canvas-level `errorText` prop instead (same required-field semantics).
  final placeholder = (props['placeholder'] ?? 'Name') as String;
  final errorText = (props['errorText'] ?? 'Required') as String;
  return shadcn.Validated<String>(
    validator: _CanvasRequiredValidator(errorText),
    builder: (context, error, child) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child!,
        const SizedBox(height: 6),
        Text(error is shadcn.InvalidResult ? error.message : errorText),
      ],
    ),
    child: shadcn.TextField(placeholder: Text(placeholder)),
  );
}

Widget _buildColorPicker(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: the kit-history
  // blue (`0xFF2196F3`) with its hex label. The real `ColorPicker` builds
  // bare; the `RecentColorsScope` ancestor documents the storage precondition
  // the history panel needs (same ancestor-proof idiom as the menu builder's
  // `MenuGroupData`). History UI and the eye-dropper stay off
  // (`showHistoryButton`/`initialShowHistory` false, `enableEyeDropper`
  // false) — canvas shows the static sliders plus the hex label, and drags
  // no-op (no `onChanged`).
  final hex = (props['hex'] ?? '#2196F3') as String;
  final color = _parseHexColor(hex);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      shadcn.RecentColorsScope(
        initialRecentColors: [color],
        child: shadcn.ColorPicker(
          value: shadcn.ColorDerivative.fromColor(color),
          showHistoryButton: false,
          initialShowHistory: false,
          enableEyeDropper: false,
        ),
      ),
      const SizedBox(height: 8),
      Text(hex),
    ],
  );
}

Widget _buildColorInput(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented, mirroring the
  // color picker builder (same hex-driven data color). The real `ColorInput`
  // (an `ObjectFormField` trigger showing the swatch plus the kit's hex
  // label) builds bare; the picker opens in the overlay at runtime, so
  // canvas shows the trigger — the same honest-static convention as the
  // tooltip catalog builder. Eye-dropper and history stay off per the color
  // brief; the scope guards the history lookup the change path performs.
  final hex = (props['hex'] ?? '#2196F3') as String;
  final color = _parseHexColor(hex);
  return shadcn.RecentColorsScope(
    initialRecentColors: [color],
    child: shadcn.ColorInput(
      value: shadcn.ColorDerivative.fromColor(color),
      onChanged: (_) {},
      placeholder: Text(hex),
      showLabel: true,
      enableEyeDropper: false,
      showHistory: false,
    ),
  );
}

/// Local color state for the catalog HSL slider (builders are stateless).
/// `HSLColorSlider` is controlled (`color` + `onChanged`), so the cell owns
/// an `HSLColor` exactly like `_StarRatingCell` owns its rating. The swatch
/// row shows the live color plus its hex label (the color brief's static
/// swatch + hex, kept in sync while dragging).
class _HslCell extends StatefulWidget {
  final String mode;

  const _HslCell({required this.mode});

  @override
  State<_HslCell> createState() => _HslCellState();
}

class _HslCellState extends State<_HslCell> {
  late HSLColor _color = HSLColor.fromColor(const Color(0xFF2196F3));

  @override
  Widget build(BuildContext context) {
    final type = switch (widget.mode) {
      'sat' => shadcn.HSLColorSliderType.sat,
      'lum' => shadcn.HSLColorSliderType.lum,
      'alpha' => shadcn.HSLColorSliderType.alpha,
      _ => shadcn.HSLColorSliderType.hue,
    };
    final swatch = _color.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed height: the slider paints into a fill-positioned `Stack`
        // (needs bounded height, which root canvas columns do not provide) —
        // the drawer/scaffold fixed-shell precedent.
        SizedBox(
          height: 32,
          child: shadcn.HSLColorSlider(
            color: _color,
            sliderType: type,
            onChanged: (c) => setState(() => _color = c),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 24, height: 24, color: swatch),
            const SizedBox(width: 8),
            Text(_toHexLabel(swatch)),
          ],
        ),
      ],
    );
  }
}

Widget _buildHsl(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented from the
  // component's own preview (`form/hsl/preview.dart`: a hue slider plus a
  // preview swatch). The canvas-level `mode` string maps onto the kit's
  // `HSLColorSliderType` single-channel members (unknown falls back to hue,
  // same fallback idiom as the tracker builder).
  final mode = (props['mode'] ?? 'hue') as String;
  return _HslCell(mode: mode);
}

/// Local color state for the catalog HSV slider — mirrors [_HslCell] for the
/// kit's `HSVColorSlider` (whose value param is named `value`, not `color`).
class _HsvCell extends StatefulWidget {
  final String mode;

  const _HsvCell({required this.mode});

  @override
  State<_HsvCell> createState() => _HsvCellState();
}

class _HsvCellState extends State<_HsvCell> {
  late HSVColor _color = HSVColor.fromColor(const Color(0xFF2196F3));

  @override
  Widget build(BuildContext context) {
    final type = switch (widget.mode) {
      'sat' => shadcn.HSVColorSliderType.sat,
      'val' => shadcn.HSVColorSliderType.val,
      'alpha' => shadcn.HSVColorSliderType.alpha,
      _ => shadcn.HSVColorSliderType.hue,
    };
    final swatch = _color.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed height: same fill-positioned `Stack` constraint as the HSL
        // slider above — root canvas columns are unbounded.
        SizedBox(
          height: 32,
          child: shadcn.HSVColorSlider(
            value: _color,
            sliderType: type,
            onChanged: (c) => setState(() => _color = c),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 24, height: 24, color: swatch),
            const SizedBox(width: 8),
            Text(_toHexLabel(swatch)),
          ],
        ),
      ],
    );
  }
}

Widget _buildHsv(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented from the
  // component's own preview (`form/hsv/preview.dart`: a hue slider plus a
  // preview swatch), mirroring the HSL builder above.
  final mode = (props['mode'] ?? 'hue') as String;
  return _HsvCell(mode: mode);
}

Widget _buildHistory(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented from the
  // component's own preview (`form/history/preview.dart`: a
  // `RecentColorsScope` seeding two colors around a `ColorHistoryGrid` that
  // reads `ColorHistoryStorage.of`). The grid is all-optional past storage;
  // the canvas-level `columns` prop wires into `crossAxisCount` (parsed via
  // `num`, clamped like the tracker builder's segments).
  final columns = ((props['columns'] as num?)?.toInt() ?? 6).clamp(2, 10);
  return shadcn.RecentColorsScope(
    initialRecentColors: const [Color(0xFF2196F3), Color(0xFF9C27B0)],
    child: Builder(
      builder: (context) => shadcn.ColorHistoryGrid(
        storage: shadcn.ColorHistoryStorage.of(context),
        onColorPicked: (_) {},
        crossAxisCount: columns,
      ),
    ),
  );
}

/// Local controller ownership for the catalog feature carousel (builders are
/// stateless). Mirrors the kit's own preview items, minus autoplay: the
/// controller is created with `autoPlay: false` so no timers run on canvas
/// (the carousel renders its first page statically), and disposed with the
/// cell — the stepper-cell precedent.
class _FeatureCarouselCell extends StatefulWidget {
  final String title1;
  final String description1;
  final String title2;
  final String description2;

  const _FeatureCarouselCell({
    required this.title1,
    required this.description1,
    required this.title2,
    required this.description2,
  });

  @override
  State<_FeatureCarouselCell> createState() => _FeatureCarouselCellState();
}

class _FeatureCarouselCellState extends State<_FeatureCarouselCell> {
  late final shadcn.FeatureCarouselController _controller;

  @override
  void initState() {
    super.initState();
    _controller = shadcn.FeatureCarouselController(
      autoPlay: false,
      showCta: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Item data (icons + accent colors) mirrors the component's own preview
    // (`display/feature_carousel/preview.dart`); the explicit width keeps
    // the 420px theme default narrow-safe on canvas.
    return shadcn.FeatureCardCarousel(
      controller: _controller,
      width: 320,
      items: [
        shadcn.FeatureCarouselItem(
          title: widget.title1,
          description: widget.description1,
          icon: Icons.auto_awesome,
          accentColor: const Color(0xFF7EA3FF),
        ),
        shadcn.FeatureCarouselItem(
          title: widget.title2,
          description: widget.description2,
          icon: Icons.palette,
          accentColor: const Color(0xFF9B87FF),
        ),
      ],
    );
  }
}

Widget _buildFeatureCarousel(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two feature
  // items (title + description each). Despite the "(WIP)" manifest tag, the
  // kit API is usable: `FeatureCardCarousel` self-sizes from its theme
  // (height falls back to `carouselHeight`), so it builds bare with no
  // overlay, network, or asset dependencies.
  final title1 = (props['title1'] ?? 'Palette Selector') as String;
  final description1 =
      (props['description1'] ?? 'Pick a palette to refine results.') as String;
  final title2 = (props['title2'] ?? 'Style Presets') as String;
  final description2 =
      (props['description2'] ?? 'Choose a curated style preset.') as String;
  return _FeatureCarouselCell(
    title1: title1,
    description1: description1,
    title2: title2,
    description2: description2,
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
      // Track M: `initialValue`/`readOnly` promoted from spec-only (Track I)
      // into wired builder props.
      'initialValue': '',
      'disabled': false,
      'obscure': false,
      'readOnly': false,
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
    // Track M: `size` promoted from spec-only (Track I) into a wired prop.
    defaults: const {'initials': 'AB', 'size': 40.0},
    build: _buildAvatar,
  ),
  CatalogEntry(
    kind: 'checkbox',
    label: 'Animated checkbox with tri-state support and controllers.',
    // Track M: `tristate` promoted from spec-only (Track I) into a wired prop.
    defaults: const {'value': false, 'disabled': false, 'tristate': false},
    build: _buildCheckbox,
  ),
  CatalogEntry(
    kind: 'divider',
    label: 'Horizontal and vertical separators with optional label support.',
    // Track M: `thickness` promoted from spec-only (Track I) into a wired
    // prop.
    defaults: const {'label': '', 'thickness': 1.0},
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
    // Track M: `expand` promoted from spec-only (Track I) into a wired prop.
    defaults: const {
      'tab1': 'Tab 1',
      'tab2': 'Tab 2',
      'index': 0,
      'expand': false,
    },
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
    // Track M: `disabled` promoted from spec-only (Track I) into a wired
    // prop.
    defaults: const {
      'placeholder': 'Select an option',
      'option1': 'Option 1',
      'option2': 'Option 2',
      'value': '',
      'disabled': false,
    },
    build: _buildSelect,
  ),
  CatalogEntry(
    kind: 'radio_group',
    label: 'Exclusive selection group with radio items and cards.',
    // Track M: `disabled` promoted from spec-only (Track I) into a wired
    // prop.
    defaults: const {
      'option1': 'Option 1',
      'option2': 'Option 2',
      'value': 'Option 1',
      'disabled': false,
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
    // Track M: `separator` promoted from spec-only (Track I) into a wired
    // prop.
    defaults: const {'home': 'Home', 'current': 'Page', 'separator': 'arrow'},
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
    // Track M: `autoDismiss` promoted from spec-only (Track I) into a wired
    // prop.
    defaults: const {
      'title': 'Saved',
      'message': 'Saved successfully',
      'autoDismiss': false,
    },
    build: _buildToast,
  ),
  CatalogEntry(
    kind: 'drawer',
    label: 'Sliding drawer and sheet overlays with drag support.',
    // Track M: `position` promoted from spec-only (Track I) into a wired
    // prop.
    defaults: const {
      'title': 'Drawer',
      'content': 'Drawer content',
      'position': 'end',
    },
    build: _buildDrawer,
  ),
  // Track J additions (2026-09-05): real builders for the triage kinds
  // (`basic`, `card_image`, `scaffold`) plus the palette-visible batch
  // below. Labels mirror `components.json` descriptions (registry bridge
  // test); defaults are invented and documented per builder above.
  CatalogEntry(
    kind: 'basic',
    label: 'Flexible row layout for leading/title/content/trailing sections.',
    defaults: const {
      'title': 'Title',
      'subtitle': 'Subtitle',
      'content': 'Content',
      'showLeading': true,
      'showTrailing': true,
    },
    build: _buildBasic,
  ),
  CatalogEntry(
    kind: 'card_image',
    label: 'Interactive card that pairs an image with title/subtitle content.',
    defaults: const {'title': 'Card title', 'subtitle': 'Card subtitle'},
    build: _buildCardImage,
  ),
  CatalogEntry(
    kind: 'scaffold',
    label: 'Layout scaffold with headers, footers, and loading indicators.',
    defaults: const {'title': 'My App', 'body': 'Welcome'},
    build: _buildScaffold,
  ),
  CatalogEntry(
    kind: 'collapsible',
    label: 'Independent sections that toggle their own visibility',
    defaults: const {
      'trigger': 'Show more',
      'content': 'Hidden details',
      'expanded': false,
    },
    build: _buildCollapsible,
  ),
  CatalogEntry(
    kind: 'steps',
    label: 'Vertical step list with numbered indicators and connectors.',
    defaults: const {
      'step1': 'Step 1',
      'detail1': 'First step details',
      'step2': 'Step 2',
      'detail2': 'Second step details',
    },
    build: _buildSteps,
  ),
  CatalogEntry(
    kind: 'timeline',
    label: 'Vertical timeline for chronological entries.',
    defaults: const {
      'time1': '9:00 AM',
      'title1': 'Kickoff',
      'detail1': 'Project kickoff meeting',
      'time2': '2:00 PM',
      'title2': 'Review',
      'detail2': 'Design review session',
    },
    build: _buildTimeline,
  ),
  CatalogEntry(
    kind: 'outlined_container',
    label: 'Animated outlined container with theme-aware borders and blur.',
    defaults: const {'label': 'Outlined'},
    build: _buildOutlinedContainer,
  ),
  CatalogEntry(
    kind: 'hidden',
    label: 'Animated visibility helper with axis-aware size control.',
    defaults: const {'label': 'Hidden content', 'hidden': false},
    build: _buildHidden,
  ),
  CatalogEntry(
    kind: 'keyboard_shortcut',
    label: 'Displays keyboard shortcuts as styled keycaps.',
    defaults: const {'keys': 'Ctrl+K'},
    build: _buildKeyboardShortcut,
  ),
  CatalogEntry(
    kind: 'tracker',
    label: 'Horizontal tracker segments with tooltips.',
    defaults: const {'segments': 3, 'level': 'fine'},
    build: _buildTracker,
  ),
  CatalogEntry(
    kind: 'chat',
    label: 'Chat bubbles, groups, and tail helpers for conversational layouts.',
    defaults: const {'message': 'Hello!'},
    build: _buildChat,
  ),
  CatalogEntry(
    kind: 'selectable',
    label: 'Selectable text with themed cursor and selection behavior.',
    defaults: const {'text': 'Select me'},
    build: _buildSelectable,
  ),
  CatalogEntry(
    kind: 'star_rating',
    label: 'Interactive star rating input with theming support.',
    defaults: const {'value': 3.0, 'max': 5.0},
    build: _buildStarRating,
  ),
  CatalogEntry(
    kind: 'clickable',
    label: 'State-aware gesture surface with hover, focus, and press handling.',
    defaults: const {'label': 'Tap me'},
    build: _buildClickable,
  ),
  CatalogEntry(
    kind: 'scrollbar',
    label: 'Themeable scrollbar wrapper built on RawScrollbar.',
    defaults: const {'label': 'Scrollable content'},
    build: _buildScrollbar,
  ),
  CatalogEntry(
    kind: 'pagination',
    label: 'Page navigation controls with skip, previous/next, and ellipsis handling.',
    defaults: const {'page': 1, 'totalPages': 5},
    build: _buildPagination,
  ),
  CatalogEntry(
    kind: 'alert_dialog',
    label: 'Modal alert dialog with customizable header, content, and actions.',
    defaults: const {
      'title': 'Are you sure?',
      'message': 'This action cannot be undone.',
      'showActions': true,
    },
    build: _buildAlertDialog,
  ),
  // Track M additions (2026-09-05): overlay-driven inline forms (menu,
  // popover, popup, menubar, dropdown_menu, context_menu, hover_card,
  // command, swiper, refresh_trigger) plus the tab-controller trio,
  // stepper, and slider. Labels mirror `components.json` descriptions;
  // defaults are invented and documented per builder above. Only
  // bool/string/num prop types already established by the seed kinds.
  CatalogEntry(
    kind: 'menu',
    label: 'Menu primitives, items, and popup container.',
    defaults: const {'heading': 'File', 'item1': 'New', 'item2': 'Open'},
    build: _buildMenu,
  ),
  CatalogEntry(
    kind: 'popover',
    label: 'Anchored overlay surfaces for floating content.',
    defaults: const {
      'trigger': 'Open Popover',
      'title': 'Popover title',
      'body': 'Use popovers for contextual helper content.',
    },
    build: _buildPopover,
  ),
  CatalogEntry(
    kind: 'popup',
    label: 'Styled popup container for menus and dropdowns.',
    defaults: const {
      'item1': 'Profile',
      'item2': 'Settings',
      'item3': 'Sign out',
    },
    build: _buildPopup,
  ),
  CatalogEntry(
    kind: 'menubar',
    label:
        'Horizontal desktop-style menubar with dropdown menus and keyboard navigation.',
    defaults: const {'menu1': 'File', 'menu2': 'Edit'},
    build: _buildMenubar,
  ),
  CatalogEntry(
    kind: 'dropdown_menu',
    label: 'Dropdown menu overlay built on menu primitives.',
    defaults: const {
      'heading': 'My Account',
      'item1': 'Profile',
      'item2': 'Settings',
    },
    build: _buildDropdownMenu,
  ),
  CatalogEntry(
    kind: 'context_menu',
    label: 'Desktop-style context menu overlay for editable text and custom actions.',
    defaults: const {
      'hint': 'Right-click me',
      'item1': 'Back',
      'item2': 'Reload',
    },
    build: _buildContextMenu,
  ),
  CatalogEntry(
    kind: 'hover_card',
    label: 'Hover or long-press triggered popovers for rich previews.',
    defaults: const {
      'handle': 'Hover card',
      'title': 'Hover title',
      'body': 'Rich preview content.',
    },
    build: _buildHoverCard,
  ),
  CatalogEntry(
    kind: 'command',
    label:
        'Command palette with search, keyboard navigation, and customizable result builders.',
    defaults: const {
      'hint': 'Search commands...',
      'item1': 'Calendar',
      'item2': 'Settings',
    },
    build: _buildCommand,
  ),
  CatalogEntry(
    kind: 'swiper',
    label: 'Swipe-triggered overlays for drawers and sheets.',
    defaults: const {
      'hint': 'Swipe up from the bottom',
      'content': 'Swipe content',
    },
    build: _buildSwiper,
  ),
  CatalogEntry(
    kind: 'refresh_trigger',
    label:
        'Pull-to-refresh wrapper with customizable indicator, extents, and completion animations.',
    defaults: const {'item1': 'Row 1', 'item2': 'Row 2', 'item3': 'Row 3'},
    build: _buildRefreshTrigger,
  ),
  CatalogEntry(
    kind: 'tab_container',
    label: 'Coordinated tab state manager with customizable builders.',
    defaults: const {
      'tab1': 'Overview',
      'tab2': 'Details',
      'tab3': 'Reviews',
      'index': 0,
    },
    build: _buildTabContainer,
  ),
  CatalogEntry(
    kind: 'tab_list',
    label: 'Horizontal tab header row with active indicator.',
    defaults: const {'tab1': 'Tab 1', 'tab2': 'Tab 2', 'index': 0},
    build: _buildTabList,
  ),
  CatalogEntry(
    kind: 'tab_pane',
    label: 'Sortable tab strip with integrated content card.',
    defaults: const {
      'tab1': 'Overview',
      'tab2': 'Analytics',
      'tab3': 'Settings',
      'focused': 0,
    },
    build: _buildTabPane,
  ),
  CatalogEntry(
    kind: 'stepper',
    label: 'Multi-step progress with interactive step indicators.',
    defaults: const {
      'step1': 'Details',
      'detail1': 'Provide your details.',
      'step2': 'Payment',
      'detail2': 'Choose a payment method.',
      'step3': 'Confirm',
      'detail3': 'Review and submit.',
      'step': 0,
    },
    build: _buildStepper,
  ),
  CatalogEntry(
    kind: 'slider',
    label:
        'General-purpose single and range slider engine with snapping and pluggable builders.',
    defaults: const {'value': 0.6},
    build: _buildSlider,
  ),
  // Track P additions (2026-09-05): the hardest kinds — pickers (calendar,
  // date/time, carousel, color), grids (tree, table), and form/color shells.
  // Labels mirror `components.json` descriptions; defaults are invented and
  // documented per builder above. Only bool/string/num/enum prop types
  // already established by the seed kinds.
  CatalogEntry(
    kind: 'input_otp',
    label:
        'Fixed-length OTP input field with clipboard integration, paste handling, and focus management.',
    defaults: const {'length': 6},
    build: _buildInputOtp,
  ),
  CatalogEntry(
    kind: 'calendar',
    label:
        'Date picker and calendar widgets for single, range, and multi selection.',
    defaults: const {'mode': 'single'},
    build: _buildCalendar,
  ),
  CatalogEntry(
    kind: 'date_picker',
    label: 'Popover/dialog calendar for single-date and range selection.',
    defaults: const {'placeholder': 'Select date', 'label': ''},
    build: _buildDatePicker,
  ),
  CatalogEntry(
    kind: 'time_picker',
    label: 'Popover/dialog picker for time and duration values.',
    defaults: const {'placeholder': 'Select time', 'label': ''},
    build: _buildTimePicker,
  ),
  CatalogEntry(
    kind: 'carousel',
    label:
        'Interactive carousel with sliding/fading transitions and autoplay controls.',
    defaults: const {'slides': 3},
    build: _buildCarousel,
  ),
  CatalogEntry(
    kind: 'tree',
    label: 'Hierarchical tree view with expandable, selectable nodes.',
    defaults: const {
      'node1': 'Design',
      'child1': 'Research',
      'child2': 'Wireframes',
      'node2': 'Launch',
    },
    build: _buildTree,
  ),
  CatalogEntry(
    kind: 'table',
    label: 'Resizable table layout with headers, footers, and frozen cells.',
    defaults: const {
      'header1': 'Name',
      'header2': 'Role',
      'name1': 'Avery',
      'role1': 'Designer',
      'name2': 'Jordan',
      'role2': 'Engineer',
    },
    build: _buildTable,
  ),
  CatalogEntry(
    kind: 'form',
    label: 'Composable form state, validation, and submit helpers.',
    defaults: const {
      'label': 'Name',
      'placeholder': 'Jane Doe',
      'submitLabel': 'Submit',
    },
    build: _buildForm,
  ),
  CatalogEntry(
    kind: 'form_field',
    label: 'Modal or popover editor field for complex objects.',
    defaults: const {'placeholder': 'Select item', 'value': ''},
    build: _buildFormField,
  ),
  CatalogEntry(
    kind: 'formatted_input',
    label: 'Low-level formatted-field helpers that sync multiple InputPart segments.',
    defaults: const {'label': ''},
    build: _buildFormattedInput,
  ),
  CatalogEntry(
    kind: 'validated',
    label: 'Validation wrapper that exposes form error state.',
    defaults: const {'placeholder': 'Name', 'errorText': 'Required'},
    build: _buildValidated,
  ),
  CatalogEntry(
    kind: 'color_picker',
    label:
        'HSV/HSL/HEX color picker with popovers, eye dropper, and history controls.',
    defaults: const {'hex': '#2196F3'},
    build: _buildColorPicker,
  ),
  CatalogEntry(
    kind: 'color_input',
    label:
        'Popover/dialog color selector that integrates the picker, history, and eye-dropper tools.',
    defaults: const {'hex': '#2196F3'},
    build: _buildColorInput,
  ),
  CatalogEntry(
    kind: 'hsl',
    label:
        'Gradient slider that controls hue, saturation, lightness, or alpha for HSL colors.',
    defaults: const {'mode': 'hue'},
    build: _buildHsl,
  ),
  CatalogEntry(
    kind: 'hsv',
    label:
        'Gradient slider for HSV color component control (hue, saturation, value, alpha).',
    defaults: const {'mode': 'hue'},
    build: _buildHsv,
  ),
  CatalogEntry(
    kind: 'history',
    label: 'Grid + storage helpers that track recently used colors for reuse.',
    defaults: const {'columns': 6},
    build: _buildHistory,
  ),
  CatalogEntry(
    kind: 'feature_carousel',
    label:
        'Animated feature card carousel with autoplay, swipe, and CTA support. (WIP)',
    defaults: const {
      'title1': 'Palette Selector',
      'description1': 'Pick a palette to refine results.',
      'title2': 'Style Presets',
      'description2': 'Choose a curated style preset.',
    },
    build: _buildFeatureCarousel,
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
