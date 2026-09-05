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
import 'package:flutter/services.dart';

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

/// Empty canvas-level strings map to null so optional slots collapse instead
/// of rendering empty gaps (mirrors the input builder's empty-label
/// convention).
Widget? _textOrNull(String value) => value.isEmpty ? null : Text(value);

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
