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
///
/// STATE BINDINGS (Track R1): a string prop value starting with `=` names an
/// app-state var (`=cartCount`) instead of a literal. [buildCatalogItem]
/// resolves such props through its optional [scope] map (var name → live
/// value) via [resolveBoundProp], per the prop's [PropSpec] type so resolved
/// values keep the builder's expected runtime type (strings stringify,
/// numbers/bools coerce; uncoercible values and unknown vars fall back to
/// the RAW `=name` string, never a crash). Props of schema-less kinds are
/// left raw (no spec → no safe type). Only `scope`-carrying call sites
/// resolve: preview passes its session values (live bindings); the editor
/// canvas (`phone_frame.dart`, frozen this track) passes no scope, so bound
/// props there render the raw `=name` text — the inspector shows the
/// resolved value beside the editor instead (see `inspector_panel.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/canvas/component_registry.dart' as registry;
import 'package:canvas_app/canvas/props_schema.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_core/canvas_core.dart'
    show bindingNameOf, kFlowScreenGap, stringifyStateValue;
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

/// Builds a canvas node widget from stringly-typed props plus already-built
/// child widgets (Track C1 composition — `canvas/COMPOSITION.md` §3).
///
/// Optional positional `children` (default `const []`): the §2 container
/// builders consume it; builders that don't (yet) take children keep their
/// 1-arg shape and ignore the arg — their nodes' children render via the
/// §1 below-fallback, never inside chrome. Component `props` stay
/// stringly-typed; `children` are already-built widgets (builders never
/// look up nodes).
///
/// Dart-variance note: a 1-arg function is NOT a subtype of this 2-optional
/// type, so [CatalogEntry.build] stays 1-arg (all 69 registrations compile
/// untouched — a 2-optional tear-off IS a subtype of the 1-arg type) and
/// [buildCatalogItem] recovers migrated builders with an `is NodeBuilder`
/// check instead.
typedef NodeBuilder = Widget Function(
  Map<String, dynamic> props, [
  List<Widget> children,
]);

/// Container kinds (Track C1 composition — `canvas/COMPOSITION.md` §2).
///
/// A non-row node is a container **iff** its first item's kind is in this
/// set (row pseudo-kind excluded: `isRow` is structural, handled by the
/// renderers). Nodes carry item *lists* while the spec names a singular
/// "kind" — the first item defines the chrome and receives the children;
/// any further items on a container node stack below the chrome (same
/// separator-less rhythm as leaf own-items). Never a name heuristic: kinds
/// promote into this set only per the §2 rule (verified generic child slot).
const Set<String> kContainerKinds = {
  'card',
  'outlined_container',
  'scaffold',
  'dialog',
  'alert_dialog',
  'drawer',
  'form',
  'hidden',
  'clickable',
  'scrollbar',
  // Track D1 promotions (COMPOSITION.md §2 rule: kit-verified generic
  // single-child slot + named slot + 0/1/2-children goldens): `chat`
  // (`ChatBubble.child`), `toast` (`ToastEntry.child`), `validated`
  // (`Validated.child` passthrough), `refresh_trigger`
  // (`RefreshTrigger.child`).
  'chat',
  'toast',
  'validated',
  'refresh_trigger',
};

/// Named builder slots (Track BB): kind → slot names a node may fill with a
/// single built child widget.
///
/// CONTRACT (parallel render agent): renderers build each `node.slotNodes`
/// entry's child node and inject the built widget into a COPY of the node's
/// props under the slot-name key; builders read it back as
/// `props['<slot>'] as Widget?` (null = prop default / empty as today — see
/// [_slotOf]). Slot names never enter `props_schema.dart`: slots are not
/// props (no spec, no inspector field, no binding resolution), so the schema
/// files stay untouched. A third agent builds inspector / layers / codegen on
/// top of this registry.
///
/// KIT-WIDE AUDIT (pinned kit `f4f48d8`; paths are kit-relative under
/// `lib/registry/components/`). Registered only where a GENERIC single-Widget
/// param genuinely exists:
/// - `scaffold` → `appBar`, `body`, `footer`. The kit `Scaffold`
///   (`layout/scaffold/_impl/core/scaffold_2.dart:6`) takes NO `appBar` /
///   `body` / `bottomNav` params — honest mapping onto what it DOES take:
///   `headers` (:8, `List<Widget>`), `child` (:14, required `Widget`), and
///   `footers` (:11, `List<Widget>`). `appBar` fills `headers` (REPLACES the
///   default titled `AppBar` chrome when provided, null = default as today);
///   `body` fills the body region of `child` (SHADOWS the `body` string prop
///   when a Widget is injected, COMPLEMENTS the children splice below it);
///   `footer` fills `footers` (null = `const []`, exactly today's default).
/// - `card_image` → `image`. `CardImage.image`
///   (`layout/card_image/_impl/core/card_image_2.dart:8`, required `Widget`)
///   REPLACES the default tonal art when provided (title/subtitle stay).
///   (`title`/`subtitle`/`leading`/`trailing` (:11–:19, `Widget?`) stay
///   string-driven — no slot; the builder owns that chrome.)
/// - `basic` → `leading`, `trailing`. `Basic.leading`/`trailing`
///   (`layout/basic/_impl/core/basic_2.dart:8`/:20, `Widget?`) REPLACE the
///   default icon chrome when provided (null = the `showLeading` /
///   `showTrailing` bool chrome as today). (`title`/`subtitle`/`content`
///   (:11–:17) stay string-driven — no slot.)
/// - Every other container kind → `content`, COMPLEMENTING (never replacing)
///   the C1 children splice: the slot widget heads the nested list (slot
///   first, then spliced children), so a null slot renders today's tree
///   EXACTLY. Each maps onto the kit's single content param:
///   - `card`: `Card.child` (`layout/card/_impl/core/card_widgets.dart:8`)
///   - `dialog`: `ModalContainer.child`
///     (`overlay/dialog/_impl/core/modal_container.dart:19`)
///   - `alert_dialog`: `AlertDialog.content`
///     (`overlay/alert_dialog/_impl/core/alert_dialog_widget.dart:22`)
///   - `drawer`: `DrawerWrapper.child`
///     (`overlay/drawer/_impl/core/drawer_wrapper.dart:11`)
///   - `form`: `Form.child` (`form/form/form.dart:294`)
///   - `outlined_container`: `OutlinedContainer.child`
///     (`layout/outlined_container/_impl/core/outlined_container_2.dart:27`)
///   - `hidden`: `Hidden.child` (`layout/hidden/hidden.dart:35`)
///   - `clickable`: `Clickable.child`
///     (`control/clickable/_impl/core/clickable_widget.dart:43`)
///   - `scrollbar`: `Scrollbar.child`
///     (`control/scrollbar/_impl/core/scrollbar_widget.dart:25`)
///   - `chat`: `ChatBubble.child`
///     (`display/chat/_impl/core/chat_bubble.dart:20`)
///   - `toast`: `ToastEntry.child`
///     (`overlay/toast/_impl/core/toast_entry.dart:8`)
///   - `validated`: `Validated.child` (`form/validated/validated.dart:55`,
///     optional passthrough)
///   - `refresh_trigger`: `RefreshTrigger.child`
///     (`overlay/refresh_trigger/_impl/core/refresh_trigger_widget.dart:37`)
///
/// REFUSED (structured/typed slots do NOT qualify — a bare `Widget` cannot
/// satisfy these; the builders keep their string-prop + children-splice
/// contract instead):
/// - `tabs`, `tab_list`, `tab_container`: `TabItem … with TabChild`
///   (`navigation/tabs/_impl/core/tab_item.dart:6`); `tab_pane` adds
///   `TabPaneData<T>` (`navigation/tab_pane/_impl/core/tab_pane_data.dart:6`)
///   plus an `itemBuilder` fn.
/// - `table`: `TableRow` / `TableHeader extends TableRow` / `TableCell`
///   (`layout/table/_impl/core/table_row.dart:6`, `table_header.dart:6`,
///   `table_cell.dart:6`).
/// - `steps`: `StepItem` (`layout/steps/_impl/core/step_item.dart:6`);
///   `timeline`: `TimelineData`
///   (`layout/timeline/_impl/core/timeline_data.dart:6`); `tree`:
///   `TreeItem<T>` (`display/tree/_impl/core/tree_item.dart:35`); `stepper`:
///   `Step` (`navigation/stepper/_impl/core/step.dart:6`).
/// - `accordion`: `AccordionItem`
///   (`layout/accordion/_impl/core/accordion_item.dart:6`); `select`:
///   `SelectItemButton<T>`
///   (`form/select/_impl/core/select_item_button.dart:8`); `radio_group`:
///   `RadioItem<T>` (`form/radio_group/_impl/core/radio_item.dart:8`);
///   `input_otp`: `InputOTPChild`
///   (`form/input_otp/_impl/core/input_otp_child.dart:28`).
/// - `menu` / `menubar` / `dropdown_menu` / `context_menu` / `popup`:
///   `MenuButton implements MenuItem` / `MenuLabel implements MenuItem`
///   (`overlay/menu/_impl/core/menu_button.dart:6`, `menu_label.dart:6`);
///   `command`: `CommandCategory` / `CommandItem`
///   (`control/command/_impl/core/command_category.dart:10`,
///   `command_item_widget.dart:8`); `navigation_bar`: `NavigationItem`
///   (`navigation/navigation_bar/_impl/core/navigation_item.dart:6`);
///   `feature_carousel`: `FeatureCarouselItem` (plain data model —
///   `display/feature_carousel/_impl/utils/feature_carousel_models.dart:10`,
///   not a widget at all).
/// - `collapsible`: `children` IS `List<Widget>`
///   (`layout/collapsible/collapsible.dart:29`) but role-ordered (a trigger
///   followed by content widgets, wrapped by the builder in
///   `CollapsibleTrigger` / `CollapsibleContent`) — positional roles, not
///   named single slots.
/// - `tooltip` / `hover_card` / `swiper`: the meaningful content rides a
///   BUILDER FN, not a Widget param (`Tooltip.tooltip` is a `WidgetBuilder`
///   — `overlay/tooltip/_impl/core/tooltip_widget.dart`; same shape for
///   `HoverCard.hoverBuilder` / `Swiper.builder`); slotting only the trigger
///   `child` would misrepresent the component. `form_field` refused on the
///   same grounds (`builder` / `editorBuilder` fns). `carousel` refused likewise
///   (`itemBuilder` fn — `display/carousel/carousel.dart:29`); `popover` has no
///   bare widget at all (only the `showPopover` context API).
/// - Leaf / value kinds with no generic Widget param at all (`button`,
///   `input`, `badge`, `switch`, `avatar`, `checkbox`, `divider`, `progress`,
///   `skeleton`, `breadcrumb`, `toast`'s siblings `calendar`, `date_picker`,
///   `time_picker`, color kinds, `slider`, `star_rating`, `tracker`,
///   `selectable`, `keyboard_shortcut`, `pagination`, `text_area`, …).
/// - Registry-only kinds (`alert`, `chip`, …): no catalog builder exists to
///   read a slot (generated file, off-limits), so they stay out of scope.
const Map<String, List<String>> kNodeSlots = {
  'scaffold': ['appBar', 'body', 'footer'],
  'card': ['content'],
  'dialog': ['content'],
  'alert_dialog': ['content'],
  'drawer': ['content'],
  'form': ['content'],
  'outlined_container': ['content'],
  'hidden': ['content'],
  'clickable': ['content'],
  'scrollbar': ['content'],
  'chat': ['content'],
  'toast': ['content'],
  'validated': ['content'],
  'refresh_trigger': ['content'],
  'card_image': ['image'],
  'basic': ['leading', 'trailing'],
};

/// Reads one Track BB named slot (see [kNodeSlots]): the
/// `props['<slot>'] as Widget?` contract in null-safe form.
///
/// Returns the injected widget, or null when the key is absent, null, or a
/// non-Widget value. The non-Widget tolerance is load-bearing: `scaffold`'s
/// `body` slot shares its key with the canvas-level body STRING prop (a
/// Widget value shadows the string; a String keeps today's text), and stray
/// hand-written values must collapse to the default instead of throwing.
Widget? _slotOf(Map<String, dynamic> props, String slot) {
  final value = props[slot];
  return value is Widget ? value : null;
}

/// Prepends a Track BB `content` slot (see [kNodeSlots]) to a container's
/// children-splice list: slot first, then spliced children (COMPLEMENT, never
/// replace). Returns [children] itself when the slot is null, so the
/// childless tree is byte-identical to today's output.
List<Widget> _withContentSlot(
  Map<String, dynamic> props,
  List<Widget> children,
) {
  final slot = _slotOf(props, 'content');
  return slot == null ? children : <Widget>[slot, ...children];
}

/// Vertical nested-child stack with [kFlowScreenGap] separators
/// (`canvas/COMPOSITION.md` §1: container children stack vertically inside
/// the parent chrome). Callers emit the leading gap before this stack;
/// empty lists never reach here (childless builders return their exact old
/// tree so existing docs render byte-identically).
List<Widget> _nestedStack(List<Widget> children) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) const SizedBox(height: kFlowScreenGap),
    children[i],
  ],
];

/// One draggable component kind.
class CatalogEntry {
  final String kind;
  final String label;
  final Map<String, dynamic> defaults;

  /// The builder. Stays 1-arg so every registration — migrated containers
  /// and untouched leaves alike — compiles as-is (see the [NodeBuilder]
  /// variance note); [buildCatalogItem] recovers the migrated shape.
  final Widget Function(Map<String, dynamic> props) build;

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
  // Track Z2 beauty: 15px semibold label for primary-CTA presence (the
  // 14-16px brief). Color stays inherited so variant/disabled states keep
  // their kit styling — size/weight only, never a hardcoded color.
  final child = Text(
    label,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
  // `enabled: false` renders the disabled state; onPressed stays non-null.
  late final Widget button;
  switch (variant) {
    case 'secondary':
      button = shadcn.SecondaryButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
    case 'outline':
      button = shadcn.OutlineButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
    case 'ghost':
      button = shadcn.GhostButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
    case 'destructive':
      button = shadcn.DestructiveButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
    case 'link':
      button = shadcn.LinkButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
    case 'text':
      // `ButtonVariance.text` / `TextButton` exist in the kit, though the
      // button canvas block's variant enum omits `text` (reported follow-up).
      button = shadcn.TextButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
    case 'primary':
    default:
      button = shadcn.PrimaryButton(
        onPressed: () {},
        enabled: !disabled,
        size: size,
        child: child,
      );
      break;
  }
  // Track Z2 beauty: comfortable 48px CTA touch target. Width is
  // intentionally left unconstrained (minWidth 0, maxWidth pass-through) so
  // the parent stretch owns full-width: this shell only floors the height and
  // never collapses or forces the width (no Center/shrinkwrap).
  // STRETCH INTERPLAY: relies on the parent (phone_frame tight sizing box)
  // for full width; guarantees the 48px height itself.
  // NOTE: top-level shape is now ConstrainedBox-over-variant (childless
  // output change, expected this track) — catalog_test unwraps one level and
  // keeps every variant-wiring assertion intact.
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: button,
  );
}

Widget _buildCard(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // Fallbacks mirror the card canvas block's propsSchema defaults
  // (`components.json`): `Card` takes a bare child, so title/description are
  // canvas-level content props with no constructor counterpart.
  // C1 container slot (COMPOSITION.md §2): inner `Column` after the
  // description, before the footer action.
  final title = (props['title'] ?? 'Title') as String;
  final description = (props['description'] ?? 'Description') as String;
  final showFooter = (props['showFooter'] ?? false) as bool;
  // Track BB slots: `content` (see [kNodeSlots]) complements the C1 splice —
  // [_withContentSlot] heads the nested list, so a null slot keeps the tree.
  final kids = _withContentSlot(props, children);
  // Track Z2 beauty: kit card-preview idiom (`preview.dart`: title
  // `.semiBold()`, description `.muted().small()`, 6px title-desc gap, 20px+
  // before actions). Canvas keeps the 16px padding per the brief; title
  // 17/700 inherits the foreground (kit `Card` merges `cardForeground`), the
  // 14px description binds `mutedForeground` explicitly (same role the
  // `.muted()` modifier resolves — never a hardcoded color).
  return shadcn.Card(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (context) {
            final scheme = shadcn.Theme.of(context).colorScheme;
            return Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: scheme.mutedForeground,
              ),
            );
          },
        ),
        if (kids.isNotEmpty) ...[
          const SizedBox(height: kFlowScreenGap),
          ..._nestedStack(kids),
        ],
        if (showFooter) ...[
          const SizedBox(height: 16),
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
  // Track Z2 beauty: comfortable 48px touch target. The shell floors only
  // the height (minWidth 0, maxWidth pass-through): width stays owned by the
  // parent stretch (phone_frame tight sizing box), and the shell adds no
  // shrink-wrap that could fight it — nor a forced full width that could
  // crash unbounded parents (rows, scrolls).
  // STRETCH INTERPLAY: relies on the parent for full width; guarantees the
  // 48px height itself.
  final field = ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: shadcn.TextField(
      placeholder: Text(placeholder),
      enabled: !disabled,
      obscureText: obscure,
      initialValue: initialValue.isEmpty ? null : initialValue,
      readOnly: readOnly,
    ),
  );
  if (label.isEmpty) return field;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      field,
    ],
  );
}

Widget _buildBadge(Map<String, dynamic> props) {
  final label = (props['label'] ?? 'Badge') as String;
  final variant = (props['variant'] ?? 'primary') as String;
  final child = Text(label);
  // No generic `Badge` class exists — one widget per style.
  late final Widget badge;
  switch (variant) {
    case 'secondary':
      badge = shadcn.SecondaryBadge(child: child);
      break;
    case 'destructive':
      badge = shadcn.DestructiveBadge(child: child);
      break;
    case 'outline':
      badge = shadcn.OutlineBadge(child: child);
      break;
    case 'primary':
    default:
      badge = shadcn.PrimaryBadge(child: child);
      break;
  }
  // Track Z2 beauty: vertical breathing room so badge/stat rows breathe.
  // Vertical-only on purpose: horizontal padding would shrink the badge paint
  // inside fixed-width row cells (the X1 stretch proof pins 92px), while
  // vertical padding keeps that width intact. Row gaps (parent-owned) handle
  // the horizontal rhythm.
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: badge,
  );
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
  // Track T (narrow-width): the kit lays the child label inflexibly between
  // two `Expanded` rule lines, so a long label overflows 320px viewports. A
  // `Flexible` label cannot fix it — the kit wraps `child` in text-modifier
  // ancestors (`WrappedText`, `Padding`), which reject flex parent data. The
  // label is instead capped at 60% of the available width (single-line
  // ellipsis): short labels keep their natural width (rendering unchanged),
  // long ones clamp while the rules keep 40%. `LayoutBuilder` reads the real
  // node width (row slices included); the unbounded fallback is the viewport
  // width, defaulting narrow-safe.
  final label = (props['label'] ?? '') as String;
  final thickness = ((props['thickness'] as num?)?.toDouble() ?? 1.0).clamp(
    1.0,
    8.0,
  );
  return LayoutBuilder(
    builder: (context, constraints) {
      if (label.isEmpty) return shadcn.Divider(thickness: thickness);
      final max = constraints.maxWidth;
      final available = max.isFinite
          ? max
          : (MediaQuery.maybeSizeOf(context)?.width ?? 320.0);
      return shadcn.Divider(
        thickness: thickness,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: available * 0.6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    },
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
    // Track T (narrow-width): `RadioItem` lays `leading` inflexibly in its
    // internal `Row` (radio circle + gaps are fixed), so a long option label
    // overflows 320px viewports. The label rides a loose `Flexible` with
    // single-line ellipsis — short labels keep their natural width
    // (rendering unchanged), long ones clamp instead of overflowing. It is
    // the row's only flex child, so it simply takes the leftover width.
    Widget optionLabel(String option) => Flexible(
      child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
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
            leading: optionLabel(widget.firstOption),
          ),
          const SizedBox(height: 8),
          shadcn.RadioItem<String>(
            value: widget.secondOption,
            leading: optionLabel(widget.secondOption),
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

Widget _buildDialog(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/dialog/preview.dart`), whose
  // `showDialog` builder content is a padded title + body + Close action
  // row. The kit ships no bare `Dialog` widget (`showDialog` needs a
  // `BuildContext` + overlay), so the catalog renders that same content
  // inside the real `ModalContainer` primitive (bare-capable: its only
  // context read is a null-safe `Model.maybeOf`).
  // C1 container slot (COMPOSITION.md §2): `ModalContainer` column after the
  // message, before the action row.
  final title = (props['title'] ?? 'Dialog title') as String;
  final message =
      (props['message'] ?? 'Use dialogs for important confirmations.')
          as String;
  final showActions = (props['showActions'] ?? true) as bool;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
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
        if (kids.isNotEmpty) ...[
          const SizedBox(height: kFlowScreenGap),
          ..._nestedStack(kids),
        ],
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

Widget _buildToast(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented: an icon + title
  // + message notification row (the kit's preview shows a bare `Text` via
  // `ToastController.show`; the entry takes any child). The real
  // `ToastEntry` builds bare. Track M: `autoDismiss` wires into
  // `ToastEntry(autoDismiss:)` — the false default disables the dismiss
  // timer so the canvas node never self-dismisses (the kit ctor defaults to
  // true); the empty default `dismissDirections` disables swipe handling.
  // D1 container slot (COMPOSITION.md §2): `ToastEntry.child` — the kit's
  // single content slot (`toast_entry.dart`: `required this.child`,
  // rendered generically through `FadeTransition` in `_toast_entry_state`).
  // The splice lands in the catalog's message `Column` after the message
  // (card pattern: conditional spread, so the childless tree is identical).
  final title = (props['title'] ?? 'Saved') as String;
  final message = (props['message'] ?? 'Saved successfully') as String;
  final autoDismiss = (props['autoDismiss'] ?? false) as bool;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
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
          children: [
            Text(title),
            Text(message),
            if (kids.isNotEmpty) ...[
              const SizedBox(height: kFlowScreenGap),
              ..._nestedStack(kids),
            ],
          ],
        ),
      ],
    ),
  );
}

Widget _buildDrawer(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented: a title plus
  // body content. The real `DrawerWrapper` builds bare (its overlay-layer
  // lookup is null-safe and it owns its `AnimationController`); with
  // `draggable: false` it renders a plain themed container, so the catalog
  // wraps a fixed-width column as the side-panel mock. `size` is required
  // but only feeds drag math — the visible width comes from the `SizedBox`.
  // Track M: `position` maps the canvas-level edge enum onto `OverlayPosition`
  // (unknown values fall back to `end`, matching the old hardcoded value).
  // Track K2 contrast: the panel content binds `scheme.foreground`
  // explicitly — `DrawerWrapper` paints `scheme.background` with no
  // background override and leaves the foreground to the ambient
  // `DefaultTextStyle`, so the split-theme combo (light components under a
  // dark chrome) measured 1.20:1 here too. `DrawerWrapper` exposes no
  // background param, so only the foreground binds (the on-role for its
  // fixed `background` surface).
  final title = (props['title'] ?? 'Drawer') as String;
  // The `content` key is shared with the canvas-level content string: a
  // Widget value is the BB slot (shadowing the string), anything else keeps
  // today's text (same shared-key idiom as the scaffold `body` slot).
  final content = props['content'] is String
      ? props['content'] as String
      : 'Drawer content';
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  final position = switch (props['position']) {
    'left' => shadcn.OverlayPosition.left,
    'right' => shadcn.OverlayPosition.right,
    'top' => shadcn.OverlayPosition.top,
    'bottom' => shadcn.OverlayPosition.bottom,
    'start' => shadcn.OverlayPosition.start,
    _ => shadcn.OverlayPosition.end,
  };
  return Builder(
    builder: (context) {
      final scheme = shadcn.Theme.of(context).colorScheme;
      return shadcn.DrawerWrapper(
        position: position,
        size: const Size(240, 480),
        stackIndex: 0,
        draggable: false,
        showDragHandle: false,
        child: SizedBox(
          width: 240,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: scheme.foreground),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 16),
                Text(content),
                // C1 container slot (COMPOSITION.md §2): panel column after
                // the content text (BB `content` slot heads it via `kids`).
                if (kids.isNotEmpty) ...[
                  const SizedBox(height: kFlowScreenGap),
                  ..._nestedStack(kids),
                ],
              ],
            ),
          ),
        ),
      );
    },
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
  // Track BB slots: `leading` / `trailing` (see [kNodeSlots]) replace the
  // default icon chrome when provided; null keeps the bool-gated chrome below.
  final leadingSlot = _slotOf(props, 'leading');
  final trailingSlot = _slotOf(props, 'trailing');
  // Track Z2 beauty: the leading rides a 40px box so icon rows line up with
  // avatar rows (avatar default 40); row/column gaps sit in the 8-12px brief
  // band (12 leading/trailing, 10 content). The title-subtitle 2px gap stays
  // kit-owned (hardcoded `baseGap * 0.25` inside `Basic`, no builder param).
  // No outer padding here: `Basic` already owns its (zero-default) padding,
  // so any wrapper would compound into double spacing.
  return shadcn.Basic(
    contentSpacing: 12,
    titleSpacing: 10,
    leading: leadingSlot ??
        (showLeading
            ? const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: Icon(Icons.person, size: 24)),
              )
            : null),
    title: _textOrNull(title),
    subtitle: _textOrNull(subtitle),
    content: _textOrNull(content),
    trailing:
        trailingSlot ?? (showTrailing ? const Icon(Icons.chevron_right) : null),
  );
}

/// Theme-token art for the card-image `image` slot: a tonal container with a
/// centered glyph. The kit's own preview uses `Image.network` (a 404 trap on
/// canvas — the triage screenshot's broken-image box), so the catalog never
/// uses network/asset images here.
/// Text-block budget for the card-image shell below: the `Gap(12)` plus the
/// `Basic` title block plus the kit button's internal padding at default
/// text scales. The shell converts node width into height as
/// `width * 9/16 + budget`; over-estimating is safe (the loose `Flexible`
/// centers the exact-ratio art and long titles shrink it proportionally
/// instead of overflowing), under-estimating would clip. Tuned against the
/// 320px narrow suite (defaults + 60-char stress titles, light + dark).
const double _kCardImageTextBudget = 76;

/// Track BB art cap (user: hero art is a giant empty box — the "stretched"
/// feel): the card-image art height never exceeds this many logical pixels.
/// Below the cap the art keeps its exact 16:9 ratio at full card width (as
/// before); above it the art pins to cap × cap·16/9 and centers instead of
/// stretching wider. The matching max width is `_kCardImageArtMaxHeight * 16
/// / 9` (≈355.6). Token-driven, no network images (see [_CardImageArt]).
const double _kCardImageArtMaxHeight = 200.0;

/// Art height for a node of [width]: 16:9, clamped to [_kCardImageArtMaxHeight].
double _cardImageArtHeight(double width) =>
    (width * 9 / 16).clamp(0.0, _kCardImageArtMaxHeight);

class _CardImageArt extends StatelessWidget {
  const _CardImageArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Track BB art: true 16:9 tonal art, capped (see [_kCardImageArtMaxHeight])
    // and centered — wide phones pin to 200px tall instead of stretching a
    // giant empty box. Tonal diagonal gradient (surfaceContainerHigh →
    // surfaceContainerHighest) plus a bigger 48px centered glyph: designed,
    // token-driven, never network/asset images. The `ConstrainedBox` keeps the
    // exact ratio below the cap (full-bleed, as before) and shrinks the width
    // to ratio-true at the cap; the `Center` keeps capped art centered in the
    // stretched image slot.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _kCardImageArtMaxHeight * 16 / 9,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surfaceContainerHigh,
                  scheme.surfaceContainerHighest,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildCardImage(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: a title plus a
  // subtitle (the required `image` slot is the theme-token art above). The
  // real `CardImage` builds bare; its vertical `Flex` holds a `Flexible`
  // image, which needs bounded height — root canvas columns are unbounded,
  // so the catalog derives the height from the width (16:9 art capped per
  // [_kCardImageArtMaxHeight], plus the text budget below) exactly like the
  // divider builder reads the real node width (row slices included; unbounded
  // fallback is the viewport width, defaulting narrow-safe).
  // STRETCH INTERPLAY: the parent owns the width; this shell converts that
  // width into a proportional (capped) height so the art actually fills
  // narrow phones instead of sitting in a fixed 240px box — and stops growing
  // on wide ones (the BB cap).
  // Track BB slots: `image` (see [kNodeSlots]) REPLACES the default art when
  // provided (title/subtitle stay); null keeps the capped art above.
  final title = (props['title'] ?? 'Card title') as String;
  final subtitle = (props['subtitle'] ?? 'Card subtitle') as String;
  final imageSlot = _slotOf(props, 'image');
  return LayoutBuilder(
    builder: (context, constraints) {
      final max = constraints.maxWidth;
      final width = max.isFinite
          ? max
          : (MediaQuery.maybeSizeOf(context)?.width ?? 320.0);
      return SizedBox(
        // The width owns the card's full-bleed span: the kit wraps the image
        // `Flex` in an `IntrinsicWidth`, so capped art alone would
        // shrink-wrap the whole card to 355px on wide phones. Pinning the
        // shell to the node width keeps the card full-width while the art
        // centers inside it (same `width` the height math already uses).
        width: width,
        height: _cardImageArtHeight(width) + _kCardImageTextBudget,
        child: shadcn.CardImage(
          image: imageSlot ?? const _CardImageArt(),
          title: _textOrNull(title),
          subtitle: _textOrNull(subtitle),
        ),
      );
    },
  );
}

Widget _buildScaffold(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented: an app title
  // plus a body line. Dropping a scaffold yields the default app shell —
  // the real kit `Scaffold` (its `Overlay` + `DrawerOverlay` build bare)
  // with a default `AppBar` titled from props and the body text as the
  // content slot. The fixed height mirrors the drawer builder's fixed width:
  // the kit flex needs bounded height, which root canvas columns do not
  // provide.
  //
  // Track K2 contrast (P11 J2): bar/body colors AND their foregrounds bind
  // explicitly to kit scheme roles (`card`/`cardForeground` for the bar,
  // `background`/`foreground` for the body) instead of leaving nulls. The
  // kit defaults resolve the surfaces from the INNER components scheme but
  // leave the title/body foreground to the ambient `DefaultTextStyle`, which
  // on canvas comes from the OUTER (chrome) material theme — dark chrome
  // under light components (supabase/light under clean-slate/dark) inherited
  // near-white text onto near-white surfaces (measured 1.20:1). The `Builder`
  // reads the nearest `shadcn.Theme` so both bindings follow the components
  // scheme in every chrome/components combination, light and dark.
  final title = (props['title'] ?? 'My App') as String;
  // Track BB slots (see [kNodeSlots]): `appBar` fills `headers` (REPLACES the
  // default titled AppBar when provided — renders above the body either way);
  // `body` fills the body region of `child` (a Widget value SHADOWS the
  // `body` string prop, which keeps today's text when the slot is null — the
  // [_slotOf] tolerance makes the shared key safe); `footer` fills `footers`
  // (the kit `Scaffold` — `layout/scaffold/_impl/core/scaffold_2.dart:6 —
  // takes `headers`/`child`/`footers`, and NO `appBar`/`body`/`bottomNav`
  // params, so these canvas-level names map onto those three regions). The C1
  // children splice complements the body region below the body content; every
  // null slot keeps today's output EXACTLY.
  final appBarSlot = _slotOf(props, 'appBar');
  final bodySlot = _slotOf(props, 'body');
  final footerSlot = _slotOf(props, 'footer');
  final body = props['body'] is String ? props['body'] as String : 'Welcome';
  return SizedBox(
    height: 320,
    child: Builder(
      builder: (context) {
        final scheme = shadcn.Theme.of(context).colorScheme;
        final defaultBar = shadcn.AppBar(
          title: Text(
            title,
            style: TextStyle(color: scheme.cardForeground),
          ),
          backgroundColor: scheme.card,
        );
        final bodyText = Text(body, style: TextStyle(color: scheme.foreground));
        return shadcn.Scaffold(
          backgroundColor: scheme.background,
          headers: [appBarSlot ?? defaultBar],
          footers: footerSlot == null ? const [] : <Widget>[footerSlot],
          child: Padding(
            padding: const EdgeInsets.all(16),
            // C1 container slot (COMPOSITION.md §2): body `Padding` column
            // under the body text (or the body slot shadowing it).
            child: children.isEmpty
                ? (bodySlot ?? bodyText)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bodySlot ?? bodyText,
                      const SizedBox(height: kFlowScreenGap),
                      ..._nestedStack(children),
                    ],
                  ),
          ),
        );
      },
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

Widget _buildOutlinedContainer(
  Map<String, dynamic> props, [
  List<Widget> children = const [],
]) {
  // No canvas block in `components.json` — default invented. The real
  // `OutlinedContainer` requires only `child`; the canvas-level `label` prop
  // renders as that child (same content-prop pattern as the card builder).
  // C1 container slot (COMPOSITION.md §2): `OutlinedContainer.child`
  // (`Column([label, ...children])`).
  final label = (props['label'] ?? 'Outlined') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  if (kids.isEmpty) {
    return shadcn.OutlinedContainer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(label),
      ),
    );
  }
  return shadcn.OutlinedContainer(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: kFlowScreenGap),
          ..._nestedStack(kids),
        ],
      ),
    ),
  );
}

Widget _buildHidden(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented. The real
  // `Hidden` needs `hidden` + `child` (durations/curves all defaulted); the
  // canvas-level `label` prop renders as that child so the visible state is
  // obvious on canvas.
  // C1 container slot (COMPOSITION.md §2): `Hidden.child`
  // (`Column([label, ...children])`).
  final label = (props['label'] ?? 'Hidden content') as String;
  final hidden = (props['hidden'] ?? false) as bool;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  if (kids.isEmpty) return shadcn.Hidden(hidden: hidden, child: Text(label));
  return shadcn.Hidden(
    hidden: hidden,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: kFlowScreenGap),
        ..._nestedStack(kids),
      ],
    ),
  );
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

Widget _buildChat(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — default invented. The real
  // `ChatBubble` requires only `child` (type/color/alignment all fall back
  // to the chat theme); the canvas-level `message` prop renders as that
  // child (same content-prop pattern as the card builder).
  // D1 container slot (COMPOSITION.md §2): `ChatBubble.child` — the kit
  // documents it as "The content of the chat bubble" (`chat_bubble.dart`:
  // `required this.child`, the single content slot — no sibling sub-slots,
  // no item roles). Label-first `Column` only when children exist (the
  // hidden/clickable precedent), so the childless tree is byte-identical.
  final message = (props['message'] ?? 'Hello!') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  if (kids.isEmpty) return shadcn.ChatBubble(child: Text(message));
  return shadcn.ChatBubble(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: kFlowScreenGap),
        ..._nestedStack(kids),
      ],
    ),
  );
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

Widget _buildClickable(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — default invented. The real
  // `Clickable` is a state-aware gesture surface requiring only `child`
  // (all hover/focus/press handling defaults to the theme); the
  // canvas-level `label` prop renders as that child. `onPressed` stays a
  // no-op so the canvas node never navigates.
  // C1 container slot (COMPOSITION.md §2): `Clickable.child`
  // (`Column([label, ...children])`).
  final label = (props['label'] ?? 'Tap me') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  if (kids.isEmpty) {
    return shadcn.Clickable(onPressed: () {}, child: Text(label));
  }
  return shadcn.Clickable(
    onPressed: () {},
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: kFlowScreenGap),
        ..._nestedStack(kids),
      ],
    ),
  );
}

Widget _buildScrollbar(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — default invented. The real kit
  // `Scrollbar` (qualified: material's `Scrollbar` is also imported here)
  // requires only `child`; the canvas-level `label` prop renders inside a
  // fixed-height box so the wrapper has a visible footprint on canvas.
  // C1 container slot (COMPOSITION.md §2): box column under the label. The
  // fixed 64px shell stays for the childless case; with children the column
  // sizes to content (a fixed shell would overflow) behind a 64px floor.
  final label = (props['label'] ?? 'Scrollable content') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  if (kids.isEmpty) {
    return shadcn.Scrollbar(
      child: SizedBox(height: 64, child: Text(label)),
    );
  }
  return shadcn.Scrollbar(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: kFlowScreenGap),
          ..._nestedStack(kids),
        ],
      ),
    ),
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
    // Track T (narrow-width): labeled Previous/Next buttons make even the
    // 5-page default 554px wide, overflowing 320px phones (and 390px ones).
    // Icon-only buttons fit better, and the `scaleDown` shell absorbs the
    // remaining ~47px: page numbers (the canvas-relevant state) render at
    // full size whenever they fit and shrink slightly only when they must.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: shadcn.Pagination(
        page: _page,
        totalPages: widget.totalPages,
        showLabel: false,
        onPageChanged: (p) =>
            setState(() => _page = p.clamp(1, widget.totalPages)),
      ),
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

Widget _buildAlertDialog(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`overlay/alert_dialog/preview.dart`: a title,
  // a message, and a Close action). The real `AlertDialog` (qualified:
  // material's `AlertDialog` is also imported here) is all-optional and
  // builds bare on the same `ModalBackdrop`/`ModalContainer` primitives as
  // the dialog catalog builder.
  // C1 container slot (COMPOSITION.md §2): content area after the message,
  // before the actions.
  final title = (props['title'] ?? 'Are you sure?') as String;
  final message =
      (props['message'] ?? 'This action cannot be undone.') as String;
  final showActions = (props['showActions'] ?? true) as bool;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  return shadcn.AlertDialog(
    title: Text(title),
    content: kids.isEmpty
        ? Text(message)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: kFlowScreenGap),
              ..._nestedStack(kids),
            ],
          ),
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
  // Track T (narrow-width): the kit lays bar items inflexibly in an internal
  // `Row`, so long menu labels overflow 320px viewports. The bar rides a
  // fixed-height horizontal scroll shell — short labels never scroll
  // (rendering unchanged); long ones scroll instead of overflowing. Height
  // 42 is the measured natural bar height (test env); the shell also bounds
  // the height root canvas columns leave unbounded.
  return SizedBox(
    height: 42,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: shadcn.Menubar(
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
      ),
    ),
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
  // navigation, and the footer hints are runtime-only. Track T re-verified at
  // 320px: the live shell still overflows 526px in a bounded 300px shell, so
  // no bounded shell can rescue it — static stays.
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

Widget _buildRefreshTrigger(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented: three static
  // rows. The real `RefreshTrigger` builds bare around its child; the fixed
  // height mirrors the drawer builder's fixed width (the scrollable needs
  // bounded height, which root canvas columns do not provide). Pull gestures
  // only animate at runtime; canvas shows the wrapped list.
  // D1 container slot (COMPOSITION.md §2): `RefreshTrigger.child` — the
  // kit's single content slot (`refresh_trigger_widget.dart`:
  // `required this.child`; the doc example wraps
  // `ListView(children: widgets)`). Canvas children append as further list
  // rows after the prop rows (conditional spread, so the childless tree is
  // identical); the 140px scroll shell keeps every depth bounded.
  final item1 = (props['item1'] ?? 'Row 1') as String;
  final item2 = (props['item2'] ?? 'Row 2') as String;
  final item3 = (props['item3'] ?? 'Row 3') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  return shadcn.RefreshTrigger(
    onRefresh: () async {},
    child: SizedBox(
      height: 140,
      child: ListView(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(item1)),
          Padding(padding: const EdgeInsets.all(12), child: Text(item2)),
          Padding(padding: const EdgeInsets.all(12), child: Text(item3)),
          if (kids.isNotEmpty) ...[
            const SizedBox(height: kFlowScreenGap),
            ..._nestedStack(kids),
          ],
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
    // Track T (narrow-width): the header row below is catalog-owned, so each
    // tab rides a loose `Flexible` with single-line ellipsis labels — short
    // labels keep their natural centered widths (rendering unchanged), long
    // ones share the 320px width instead of overflowing it.
    return shadcn.TabContainer(
      selected: _selected,
      onSelect: (i) =>
          setState(() => _selected = i.clamp(0, widget.labels.length - 1)),
      builder: (context, children) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final child in children) Flexible(child: child)],
          ),
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
        // Track T: single-line ellipsis so long labels clamp inside the
        // header row's `Flexible` cells (short labels render unchanged).
        for (final label in widget.labels)
          shadcn.TabItem(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
    // Track T (narrow-width): `tabs.TabList` lays its buttons inflexibly in
    // an internal `Row`, so long tab labels overflow 320px viewports. The
    // header rides a fixed-height horizontal scroll shell — short labels
    // never scroll (rendering unchanged); long ones scroll instead of
    // overflowing. Height 37 is the measured natural header height (test
    // env); the shell also bounds the height root canvas columns leave
    // unbounded.
    return SizedBox(
      height: 37,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: tabs.TabList(
          index: _index,
          onChanged: (i) => setState(() => _index = i.clamp(0, 1)),
          children: [
            tabs.TabItem(child: Text(widget.firstLabel)),
            tabs.TabItem(child: Text(widget.secondLabel)),
          ],
        ),
      ),
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
    // Track T (narrow-width): the vertical variant lays each title
    // inflexibly in an internal `Row` (indicator + gap + title), so a long
    // step title overflows 320px viewports. Titles ride a loose `Flexible`
    // with single-line ellipsis — short titles keep their natural width
    // (rendering unchanged), long ones clamp instead of overflowing. Each
    // title is its row's only flex child, so it takes the leftover width.
    return shadcn.Stepper(
      controller: _controller,
      direction: Axis.vertical,
      steps: [
        for (var i = 0; i < widget.steps.length; i++)
          shadcn.Step(
            title: Flexible(
              child: Text(
                widget.steps[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

/// Local selection state for the catalog navigation bar (builders are
/// stateless). Mirrors `_TabsCell`: four destination labels plus the selected
/// index. Taps update the local highlight; screen navigation (when the node
/// carries an action) fires at the player level around the whole node — the
/// same single-action-per-node contract as the tabs catalog builder, so each
/// destination is a real tappable widget but all four share the node's one
/// tap action.
class _NavigationBarCell extends StatefulWidget {
  final int initialIndex;
  final List<String> labels;

  const _NavigationBarCell({
    required this.initialIndex,
    required this.labels,
  });

  @override
  State<_NavigationBarCell> createState() => _NavigationBarCellState();
}

class _NavigationBarCellState extends State<_NavigationBarCell> {
  late int _index = widget.initialIndex.clamp(0, widget.labels.length - 1);

  static const _icons = [
    Icons.home,
    Icons.search,
    Icons.bookmark,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    // Track Z2 beauty: the bar spreads four destinations across the full
    // width as equal shares — `expands: true` wraps every child in `Expanded`
    // and `center` adds no inter-item spacers (the spaceBetween/Around/Evenly
    // alignments would). Both match the kit defaults; passing them explicitly
    // pins the spread against theme drift. The bar itself fills the parent
    // width (kit `Container` max-width); the selected highlight and label
    // legibility stay kit-owned. Per-item label overflow stays the kit
    // default (`NavigationOverflow.marquee`), so long labels scroll instead
    // of overflowing 320px viewports (narrow-width track).
    // STRETCH INTERPLAY: relies on the parent for full width (no forced
    // `double.infinity`, which would crash unbounded parents); guarantees
    // the equal-share split itself.
    return shadcn.NavigationBar(
      index: _index,
      // Labels always show: the kit default (`labelType: none`) renders an
      // icon-only strip, but the canvas kind models a labeled bottom tab bar
      // (Home/Search/Saved/You) — documented, like the menubar builder's
      // explicit params.
      labelType: shadcn.NavigationLabelType.all,
      alignment: shadcn.NavigationBarAlignment.center,
      expands: true,
      onSelected: (i) =>
          setState(() => _index = i.clamp(0, widget.labels.length - 1)),
      children: [
        for (var i = 0; i < widget.labels.length; i++)
          shadcn.NavigationItem(
            child: Icon(_icons[i % _icons.length]),
            label: Text(widget.labels[i]),
          ),
      ],
    );
  }
}

Widget _buildNavigationBar(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: four
  // destination labels plus the selected index (parsed via `num`, clamped
  // into range so hand-written docs never crash — see _buildProgress).
  // Discovered per the file-header rule (`grep -rn "^class .* extends
  // .*Widget" navigation/navigation_bar/_impl/`): `NavigationBar`
  // (StatefulWidget, `children: List<NavigationBarItem>`) + `NavigationItem`
  // (`child` required, `label` optional). (Qualified via `shadcn.`: material
  // also declares `NavigationBar`.)
  final labels = [
    (props['tab1'] ?? 'Home') as String,
    (props['tab2'] ?? 'Search') as String,
    (props['tab3'] ?? 'Saved') as String,
    (props['tab4'] ?? 'You') as String,
  ];
  final index = (props['index'] as num?)?.toInt() ?? 0;
  return _NavigationBarCell(initialIndex: index, labels: labels);
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

Widget _buildForm(Map<String, dynamic> props, [List<Widget> children = const []]) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`form/form/preview.dart`: a `FormTableLayout`
  // row plus a submit button). The real `Form` (qualified: material's `Form`
  // is also imported here) builds bare with an internal controller;
  // validation/submission execute at runtime, so the submit button is a
  // no-op on canvas and the field shows no error state.
  // C1 container slot (COMPOSITION.md §2): inner `Column` after the field
  // layout, before the submit button.
  final label = (props['label'] ?? 'Name') as String;
  final placeholder = (props['placeholder'] ?? 'Jane Doe') as String;
  final submitLabel = (props['submitLabel'] ?? 'Submit') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
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
        if (kids.isNotEmpty) ...[
          const SizedBox(height: kFlowScreenGap),
          ..._nestedStack(kids),
        ],
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

Widget _buildValidated(Map<String, dynamic> props, [List<Widget> children = const []]) {
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
  // D1 container slot (COMPOSITION.md §2): `Validated.child` — the kit's
  // optional passthrough field slot (`validated.dart`: "Child widget to
  // wrap", forwarded through `FormEntry` into `builder`; the `builder` param
  // itself is fixed catalog chrome, not a second slot). The splice lands in
  // the catalog builder `Column` after the field, before the error gap
  // (conditional spread, so the childless tree is identical).
  final placeholder = (props['placeholder'] ?? 'Name') as String;
  final errorText = (props['errorText'] ?? 'Required') as String;
  // Track BB slots: `content` complements the splice ([_withContentSlot]).
  final kids = _withContentSlot(props, children);
  return shadcn.Validated<String>(
    validator: _CanvasRequiredValidator(errorText),
    builder: (context, error, child) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child!,
        if (kids.isNotEmpty) ...[
          const SizedBox(height: kFlowScreenGap),
          ..._nestedStack(kids),
        ],
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

/// Track FF2 builders (2026-09-06): placeholder-blitz kinds — the form/input
/// family the user hit (`unknown: phone_input` triage screenshot) first.
/// Same honesty rules as Tracks M/P: no canvas blocks exist in
/// `components.json` for any of these, so defaults are invented and
/// documented per builder; only bool/string/num/enum prop types already
/// established by the seed kinds; theme-token styling only; never a
/// `preview.dart` embed (those render full `Scaffold`s); never
/// network/asset images.
Widget _buildPhoneInput(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `PhoneInput` builds bare with all-optional params (the component's own
  // preview is exactly `PhoneInput(onChanged: (_) {})` in a 320px box): the
  // country selector defaults to United States internally and the number
  // field starts empty. The optional `label` renders as a caption above
  // (mirrors the input builder; `PhoneInput` takes no label param) and
  // `searchHint` drives the country-search placeholder. `Country` /
  // `PhoneNumber` stay kit-internal (unexported value types with no sane
  // string-prop mapping), so canvas shows the empty field — typing,
  // filtering, and country picking are runtime-only.
  // Track Z2 beauty shell: the 48px floor mirrors the input builder (same
  // touch-target brief); width stays parent-owned.
  final label = (props['label'] ?? '') as String;
  final searchHint = (props['searchHint'] ?? 'Search countries...') as String;
  final field = ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: shadcn.PhoneInput(
      onChanged: (_) {},
      searchPlaceholder: Text(searchHint),
    ),
  );
  if (label.isEmpty) return field;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      field,
    ],
  );
}

/// Local controller ownership for the catalog chip input (builders are
/// stateless). The kit factory `ChipEditingController(initialChips:)` writes
/// the chip glyphs into the text but never populates the chip map, so
/// factory-seeded chips render as invisible glyphs (no widget span — kit
/// finding, reported); the public `chips` setter encodes AND maps, so the
/// cell seeds through it exactly like the stepper cell owns its controller.
class _ChipInputCell extends StatefulWidget {
  final String placeholder;
  final List<String> initialChips;

  const _ChipInputCell({
    required this.placeholder,
    required this.initialChips,
  });

  @override
  State<_ChipInputCell> createState() => _ChipInputCellState();
}

class _ChipInputCellState extends State<_ChipInputCell> {
  late final shadcn.ChipEditingController<String> _controller =
      shadcn.ChipEditingController<String>()..chips = widget.initialChips;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.ChipInput<String>(
      controller: _controller,
      chipBuilder: (context, chip) => Text(chip),
      onChipSubmitted: (value) => value.isEmpty ? null : value,
      placeholder: Text(widget.placeholder),
    );
  }
}

Widget _buildChipInput(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`form/chip_input/preview.dart`: an `AutoComplete`
  // wrapping a `ChipInput<String>` whose `chipBuilder` renders `Text(chip)`
  // and whose `onChipSubmitted` prefixes `'@$value'`). The canvas-level
  // `chip1` / `chip2` strings seed the cell controller (empty strings drop
  // out, so a blank second chip renders the empty field exactly like the
  // input builder's empty-label convention). Typing, tokenizing, and
  // suggestion filtering are runtime-only.
  final placeholder = (props['placeholder'] ?? 'Add a tag') as String;
  final chip1 = (props['chip1'] ?? 'Design') as String;
  final chip2 = (props['chip2'] ?? '') as String;
  return _ChipInputCell(
    placeholder: placeholder,
    initialChips: [
      for (final chip in [chip1, chip2])
        if (chip.isNotEmpty) chip,
    ],
  );
}

Widget _buildAutocomplete(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`form/autocomplete/preview.dart`: an
  // `AutoComplete` wrapping a `TextField`, filtering a fruit list on change).
  // The real `AutoComplete` builds bare around `suggestions` + `child`; the
  // suggestion popover opens on focus/typing at runtime, so canvas shows the
  // field — the same honest-static convention as the tooltip catalog builder.
  // The canvas-level `suggestion1` / `suggestion2` strings are the static
  // suggestion list (empty strings drop out, so the popover never shows
  // blanks).
  final placeholder = (props['placeholder'] ?? 'Search...') as String;
  final suggestion1 = (props['suggestion1'] ?? 'Apple') as String;
  final suggestion2 = (props['suggestion2'] ?? 'Apricot') as String;
  return shadcn.AutoComplete(
    suggestions: [
      for (final suggestion in [suggestion1, suggestion2])
        if (suggestion.isNotEmpty) suggestion,
    ],
    child: shadcn.TextField(placeholder: Text(placeholder)),
  );
}

Widget _buildItemPicker(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `ItemPicker<T>` (an `ObjectFormField` trigger like the form-field catalog
  // builder) builds bare around the required `items` delegate + `builder`
  // fn; the grid/list editor opens in a dialog/popover at runtime, so canvas
  // shows the trigger — the same honest-static convention as the form-field
  // catalog builder. The canvas-level `option1` / `option2` strings feed the
  // static `ItemList`; `value` renders through `builder` when non-empty (same
  // empty-means-null convention as the form-field builder).
  final placeholder = (props['placeholder'] ?? 'Select item') as String;
  final option1 = (props['option1'] ?? 'Option 1') as String;
  final option2 = (props['option2'] ?? 'Option 2') as String;
  final value = (props['value'] ?? '') as String;
  return shadcn.ItemPicker<String>(
    items: shadcn.ItemList([option1, option2]),
    builder: (context, item) => Text(item),
    value: value.isEmpty ? null : value,
    onChanged: (_) {},
    placeholder: Text(placeholder),
  );
}

/// Local selection state for the catalog multiple choice (builders are
/// stateless). Mirrors `_RadioGroupCell`: the single-select `MultipleChoice`
/// owns the selected value, the multi-select `MultipleAnswer` owns the
/// selected set — both render the same theme-token choice chips below.
class _MultipleChoiceCell extends StatefulWidget {
  final String mode;
  final List<String> options;
  final String initialSingle;
  final Set<String> initialMulti;

  const _MultipleChoiceCell({
    required this.mode,
    required this.options,
    required this.initialSingle,
    required this.initialMulti,
  });

  @override
  State<_MultipleChoiceCell> createState() => _MultipleChoiceCellState();
}

class _MultipleChoiceCellState extends State<_MultipleChoiceCell> {
  late String? _single = widget.initialSingle.isEmpty
      ? null
      : widget.initialSingle;
  late Set<String> _multi = Set<String>.of(widget.initialMulti);

  /// Theme-token choice chip (never hardcoded colors): the selected chip
  /// inverts to the `foreground`/`background` pair, the unselected chip keeps
  /// the ambient text behind a `mutedForeground` outline — the drawer /
  /// scaffold `Theme.of` precedent, so every chrome/components combination
  /// keeps contrast. Taps toggle through `Choice.choose` (single) or the
  /// local set (multi); `Choice.getValue` is the selection source of truth
  /// for the single variant, exactly like the component's own preview. The
  /// chip owns a `Builder` so the tap context sits BELOW the
  /// `MultipleChoice`/`MultipleAnswer` ancestor (`Choice.choose` looks the
  /// `Data` scope up from the tap context — the cell context above it would
  /// miss).
  Widget _choice(String option, bool selected) {
    return Builder(
      builder: (context) {
        final scheme = shadcn.Theme.of(context).colorScheme;
        return GestureDetector(
          onTap: () {
            if (widget.mode == 'multiple') {
              setState(() {
                if (_multi.contains(option)) {
                  _multi = Set<String>.of(_multi)..remove(option);
                } else {
                  _multi = Set<String>.of(_multi)..add(option);
                }
              });
            } else {
              shadcn.Choice.choose<String>(context, option);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? scheme.foreground : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? scheme.foreground : scheme.mutedForeground,
              ),
            ),
            child: Text(
              option,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? scheme.background : null),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Track T (narrow-width): options ride a `Wrap`, so long labels flow
    // instead of overflowing 320px viewports (each chip ellipsizes past its
    // share, same loose-flex idiom as the radio-group builder).
    if (widget.mode == 'multiple') {
      return shadcn.MultipleAnswer<String>(
        value: _multi,
        onChanged: (v) => setState(() => _multi = Set<String>.of(v ?? const {})),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in widget.options)
              _choice(option, _multi.contains(option)),
          ],
        ),
      );
    }
    return shadcn.MultipleChoice<String>(
      value: _single,
      onChanged: (v) => setState(() => _single = v),
      child: Builder(
        builder: (context) {
          final selected =
              shadcn.Choice.getValue<String>(context)?.toSet() ?? const {};
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in widget.options)
                _choice(option, selected.contains(option)),
            ],
          );
        },
      ),
    );
  }
}

Widget _buildMultipleChoice(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`form/multiple_choice/preview.dart`: a
  // single-select `MultipleChoice` row plus a multi-select `MultipleAnswer`
  // row, both choice-chip `Wrap`s driven by the `Choice.getValue` /
  // `Choice.choose` context API). The canvas-level `mode` string picks the
  // variant (unknown falls back to single, same fallback idiom as the
  // tracker builder); `value` is the single selection, `value` + `value2`
  // seed the multi set (empties and unknowns drop out, never a crash).
  final mode = (props['mode'] ?? 'single') as String;
  final options = [
    (props['option1'] ?? 'Option A') as String,
    (props['option2'] ?? 'Option B') as String,
    (props['option3'] ?? 'Option C') as String,
  ];
  final value = (props['value'] ?? 'Option A') as String;
  final value2 = (props['value2'] ?? 'Option B') as String;
  return _MultipleChoiceCell(
    mode: mode,
    options: options,
    initialSingle: value,
    initialMulti: {
      for (final v in [value, value2])
        if (v.isNotEmpty && options.contains(v)) v,
    },
  );
}

Widget _buildObjectInput(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `DateInput` / `TimeInput` / `DurationInput` (formatted-editor shells
  // around the date/time pickers, all-optional past `onChanged`) build bare;
  // the calendar/clock opens in the overlay at runtime, so canvas shows the
  // inline formatted editor — the same honest-static convention as the
  // date-picker catalog builder. The canvas-level `mode` string picks the
  // editor (unknown falls back to date); the optional `label` renders as a
  // caption above (mirrors the input builder).
  final mode = (props['mode'] ?? 'date') as String;
  final placeholder = (props['placeholder'] ?? 'Select value') as String;
  final label = (props['label'] ?? '') as String;
  final Widget field = switch (mode) {
    'time' => shadcn.TimeInput(
      onChanged: (_) {},
      placeholder: Text(placeholder),
    ),
    'duration' => shadcn.DurationInput(
      onChanged: (_) {},
      placeholder: Text(placeholder),
    ),
    _ => shadcn.DateInput(
      onChanged: (_) {},
      placeholder: Text(placeholder),
    ),
  };
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

/// Track FF2 builders, batch 2 (2026-09-06): display/utility/layout kinds
/// with bare-capable kit widgets. Same honesty rules as batch 1.
Widget _buildTextFieldKind(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented, mirroring the
  // `input` catalog builder (the kit `TextField` IS the widget the input
  // builder renders; this kind exposes its rich core: placeholder, label
  // caption, initial value, and disabled state — popovers, autocomplete, and
  // action features are runtime-only).
  final placeholder = (props['placeholder'] ?? 'Type here') as String;
  final label = (props['label'] ?? '') as String;
  final disabled = (props['disabled'] ?? false) as bool;
  final initialValue = (props['initialValue'] ?? '') as String;
  final field = ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: shadcn.TextField(
      placeholder: Text(placeholder),
      enabled: !disabled,
      initialValue: initialValue.isEmpty ? null : initialValue,
    ),
  );
  if (label.isEmpty) return field;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      field,
    ],
  );
}

Widget _buildMarkdown(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: a short inline
  // document. The real `Markdown` builds bare around the inline `data`
  // string (`shrinkWrap` defaults to true, so unbounded canvas columns are
  // safe); the `asset`/`file` named ctors are deliberately unused (asset and
  // file sources have no canvas counterpart). Links, images, and disclosure
  // interactions are runtime-only.
  final data = (props['data'] ?? '# Title\n\nSome **rich** text.') as String;
  return shadcn.Markdown(data: data);
}

Widget _buildTextAnimate(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: one static
  // sentence. The real `StreamingText` builds bare around `text` and reveals
  // it progressively (typewriter default); canvas shows the settled text
  // after the reveal — stream updates, effects, and cursors are runtime-only.
  final text = (props['text'] ?? 'Watch the words appear.') as String;
  return shadcn.StreamingText(text: text);
}

/// Canvas-level icon names for the icon builder (material glyphs — the same
/// `Icons.*` source every other catalog builder uses for chrome; unknown
/// names fall back to `star` instead of crashing, same fallback idiom as the
/// keyboard-shortcut parser).
IconData _canvasIcon(String? name) {
  return switch (name) {
    'heart' => Icons.favorite,
    'home' => Icons.home,
    'search' => Icons.search,
    'settings' => Icons.settings,
    'check' => Icons.check,
    'info' => Icons.info,
    'image' => Icons.image,
    _ => Icons.star,
  };
}

Widget _buildIcon(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `WrappedIcon` builds bare around the `data` theme-builder fn + `child`;
  // the canvas-level `name` string maps onto a material glyph and `size`
  // wires into the `IconThemeData` the helper exists to resolve (parsed via
  // `num`, clamped like the avatar builder's size). Color stays inherited so
  // the surrounding theme owns it — never a hardcoded color.
  final size = ((props['size'] as num?)?.toDouble() ?? 24.0).clamp(12.0, 64.0);
  return shadcn.WrappedIcon(
    data: (context, theme) => IconThemeData(size: size),
    child: Icon(_canvasIcon(props['name'] as String?)),
  );
}

Widget _buildNavigationMenu(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented from the
  // component's own preview (`navigation/navigation_menu/preview.dart`: a
  // Products/Company bar with content lists). The real `NavigationMenu`
  // builds bare around `NavigationMenuItem`s (dropdowns open in the overlay
  // at runtime, so canvas shows the bar itself — the menubar builder's
  // honest-static precedent). Track T (narrow-width): the bar rides a
  // horizontal scroll shell with NO fixed height — the bar keeps its intrinsic
  // height, so short labels never scroll and long ones scroll instead of
  // overflowing 320px viewports.
  final menu1 = (props['menu1'] ?? 'Products') as String;
  final item1 = (props['item1'] ?? 'Web Apps') as String;
  final detail1 =
      (props['detail1'] ?? 'Landing pages and dashboards.') as String;
  final menu2 = (props['menu2'] ?? 'Company') as String;
  final item2 = (props['item2'] ?? 'About') as String;
  final detail2 = (props['detail2'] ?? 'Team, culture, and careers.') as String;
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: shadcn.NavigationMenu(
      children: [
        shadcn.NavigationMenuItem(
          content: shadcn.NavigationMenuContentList(
            children: [
              shadcn.NavigationMenuContent(
                title: Text(item1),
                content: Text(detail1),
              ),
            ],
          ),
          child: Text(menu1),
        ),
        shadcn.NavigationMenuItem(
          content: shadcn.NavigationMenuContentList(
            children: [
              shadcn.NavigationMenuContent(
                title: Text(item2),
                content: Text(detail2),
              ),
            ],
          ),
          child: Text(menu2),
        ),
      ],
    ),
  );
}

Widget _buildDropzone(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `FileDropzone` is all-optional and builds bare (`showDefaultContent`
  // renders the themed icon + hint + action row); the canvas-level `hint` /
  // `action` strings drive that default content and `onPressed` stays a
  // no-op — the file dialog opens at runtime only.
  final hint = (props['hint'] ?? 'Drag files here') as String;
  final action = (props['action'] ?? 'Browse files') as String;
  return shadcn.FileDropzone(
    hint: Text(hint),
    actionLabel: action,
    onPressed: () {},
  );
}

Widget _buildBorderLoading(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `BorderLoading` builds bare around the required `child` (the sweep
  // gradient + tracer animate on a 1200ms loop at runtime); canvas wraps the
  // canvas-level `label` text in the default padded ring.
  final label = (props['label'] ?? 'Loading') as String;
  return shadcn.BorderLoading(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(label),
    ),
  );
}

Widget _buildOverflowMarquee(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented from the
  // component's own preview (`layout/overflow_marquee/preview.dart`: an
  // `OverflowMarquee` around the "This text scrolls..." caption). The real
  // widget builds bare around the required `child`; the loop only engages
  // past overflow, so short canvas text renders statically and long text
  // scrolls — no fixed shell needed either way.
  final text =
      (props['text'] ?? 'This text scrolls when it overflows its parent.')
          as String;
  return shadcn.OverflowMarquee(child: Text(text));
}

/// Track FF2 builders, batch 3 (2026-09-06): wrappers, viewports, and
/// controllers. Same honesty rules as batch 1.
Widget _buildFocusOutline(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `FocusOutline` builds bare around `child` + `focused`; canvas wraps an
  // outline button (the tooltip builder's trigger precedent) with the ring
  // forced on by default — the ring is the whole point of the kind.
  final label = (props['label'] ?? 'Focus me') as String;
  final focused = (props['focused'] ?? true) as bool;
  return shadcn.FocusOutline(
    focused: focused,
    child: shadcn.OutlineButton(onPressed: () {}, child: Text(label)),
  );
}

Widget _buildSwitcher(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two static
  // pages. The real `Switcher` builds bare around `direction` + `children`
  // (swipe animation at runtime; canvas shows the first page statically).
  // The canvas-level `direction` string maps onto `AxisDirection` (unknown
  // falls back to left); the fixed height mirrors the scaffold builder's
  // fixed shell (the viewport needs bounded height, which root canvas columns
  // do not provide).
  final direction = switch (props['direction']) {
    'right' => AxisDirection.right,
    'up' => AxisDirection.up,
    'down' => AxisDirection.down,
    _ => AxisDirection.left,
  };
  final page1 = (props['page1'] ?? 'Page 1') as String;
  final page2 = (props['page2'] ?? 'Page 2') as String;
  return SizedBox(
    height: 96,
    child: shadcn.Switcher(
      direction: direction,
      children: [
        Center(child: Text(page1)),
        Center(child: Text(page2)),
      ],
    ),
  );
}

Widget _buildScrollable(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: three
  // sentence-long rows. The real `FadedScrollableViewport` builds bare
  // (a `NotificationListener` + `ShaderMask` around any child); canvas pairs
  // it with a `SingleChildScrollView` so the edge fades genuinely engage —
  // the fixed height mirrors the scrollbar builder's fixed shell (the scroll
  // view needs bounded height, which root canvas columns do not provide).
  final text1 =
      (props['text1'] ?? 'First line of scrollable content.') as String;
  final text2 =
      (props['text2'] ?? 'Second line of scrollable content.') as String;
  final text3 = (props['text3'] ?? 'Third line of scrollable content.') as String;
  return SizedBox(
    height: 120,
    child: shadcn.FadedScrollableViewport(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(text1), Text(text2), Text(text3)],
        ),
      ),
    ),
  );
}

Widget _buildStageContainer(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented: one label. The
  // real `StageContainer` builds bare around the required `builder` fn
  // (`(context, padding) => Widget`); canvas renders the label in the
  // breakpoint padding — breakpoint snapping follows the canvas width at
  // runtime.
  final label = (props['label'] ?? 'Stage content') as String;
  return shadcn.StageContainer(
    builder: (context, padding) =>
        Padding(padding: padding, child: Text(label)),
  );
}

Widget _buildMediaQuery(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented. The real
  // `MediaQueryVisibility` builds bare (`MediaQuery.of` always exists on
  // canvas); it shows `child` inside the width range and `alternateChild`
  // outside it. The canvas-level `minWidth` number (default 0, i.e. the child
  // always — null and 0 behave identically since widths are non-negative)
  // previews the breakpoint: raise it past the canvas width to see the
  // alternate content.
  final label = (props['label'] ?? 'Wide content') as String;
  final alternate = (props['alternate'] ?? 'Narrow content') as String;
  final minWidth = ((props['minWidth'] as num?)?.toDouble() ?? 0.0).clamp(
    0.0,
    2000.0,
  );
  return shadcn.MediaQueryVisibility(
    minWidth: minWidth,
    child: Text(label),
    alternateChild: Text(alternate),
  );
}

Widget _buildScrollview(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `ScrollViewInterceptor` builds bare around the required `child`
  // (middle-click drag only engages over a scrollable at runtime); canvas
  // shows the label — the same honest-static wrapper convention as the hover
  // catalog builder below.
  final label = (props['label'] ?? 'Middle-drag to scroll') as String;
  return shadcn.ScrollViewInterceptor(child: Text(label));
}

Widget _buildHover(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `HoverActivity` builds bare around the required `child` (all callbacks
  // optional); canvas shows the label and no-ops hover timings — hover state
  // only exists at runtime.
  final label = (props['label'] ?? 'Hover me') as String;
  return shadcn.HoverActivity(onHover: () {}, child: Text(label));
}

Widget _buildPatch(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `ClickDetector` builds bare around the required `child` (`onClick`
  // optional); canvas shows the label and no-ops tap counting — consecutive
  // taps only exist at runtime.
  final label = (props['label'] ?? 'Tap me') as String;
  return shadcn.ClickDetector(onClick: (_) {}, child: Text(label));
}

Widget _buildText(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `WrappedText` (the foundation of the fluent text-modifier API) builds
  // bare around the required `child`; all style builders stay null, so the
  // canvas-level `text` renders with ambient styling — modifiers compose at
  // runtime.
  final text = (props['text'] ?? 'Styled text') as String;
  return shadcn.WrappedText(child: Text(text));
}

/// Local filter state for the catalog filter bar (builders are stateless).
/// `FilterBar` asserts `controller != null || (state != null &&
/// onChanged != null)`, so the cell owns a `FilterState` exactly like
/// `_StepperCell` owns its controller.
class _FilterBarCell extends StatefulWidget {
  final String searchPlaceholder;

  const _FilterBarCell({required this.searchPlaceholder});

  @override
  State<_FilterBarCell> createState() => _FilterBarCellState();
}

class _FilterBarCellState extends State<_FilterBarCell> {
  shadcn.FilterState _state = const shadcn.FilterState();

  @override
  Widget build(BuildContext context) {
    // `inline` presentation keeps the toolbar on canvas (the default
    // `autoSheet` would move filters behind a sheet trigger at narrow
    // widths); sort options stay empty and the date range stays off, so the
    // node is the search row — chips, sorting, and sheets are runtime-only.
    // Track T (narrow-width): the kit style floors the search field at
    // 220px, which goes non-normalized (hard crash) in row slices and
    // sub-500px viewports — including the standard 390px phone. The style
    // override drops only that floor to 0 (flex sizing still stretches the
    // field at normal widths, so rendering there is unchanged); every other
    // metric stays kit-owned. Residual floor (~131px of fixed search-row
    // chrome): tighter slices show an overflow stripe instead of crashing —
    // a horizontal scroll shell cannot rescue it (the kit's internal flex
    // rows reject unbounded width outright), documented.
    return shadcn.FilterBar(
      state: _state,
      onStateChanged: (next) => setState(() => _state = next),
      presentation: shadcn.FilterBarPresentation.inline,
      searchPlaceholder: widget.searchPlaceholder,
      style: const shadcn.FilterBarStyle(minSearchWidth: 0),
    );
  }
}

Widget _buildFilterBar(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. See
  // [_FilterBarCell] for the state-ownership contract.
  final searchPlaceholder = (props['searchPlaceholder'] ?? 'Search') as String;
  return _FilterBarCell(searchPlaceholder: searchPlaceholder);
}

/// Local scroll-controller ownership for the catalog fade scroll (builders
/// are stateless). Mirrors the component's own preview: a `ScrollController`
/// created with the cell and disposed with it, shared by `FadeScroll` and
/// its `ListView`.
class _FadeScrollCell extends StatefulWidget {
  final List<String> rows;

  const _FadeScrollCell({required this.rows});

  @override
  State<_FadeScrollCell> createState() => _FadeScrollCellState();
}

class _FadeScrollCellState extends State<_FadeScrollCell> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed shell mirrors the preview's 200x260 box (narrowed for canvas —
    // the fades need bounded height, which root canvas columns do not
    // provide).
    return SizedBox(
      height: 160,
      child: shadcn.FadeScroll(
        controller: _controller,
        child: ListView(
          controller: _controller,
          children: [
            for (final row in widget.rows)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(row),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildFadeScroll(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: three rows.
  // See [_FadeScrollCell] for the controller-ownership contract.
  final rows = [
    (props['row1'] ?? 'Row 1') as String,
    (props['row2'] ?? 'Row 2') as String,
    (props['row3'] ?? 'Row 3') as String,
  ];
  return _FadeScrollCell(rows: rows);
}

Widget _buildResizable(Map<String, dynamic> props) {
  // No canvas block in `components.json` — defaults invented: two flex
  // panes. The real `ResizablePanel.horizontal` builds bare around
  // `ResizablePane` children (drag dividers at runtime); the fixed height
  // mirrors the scaffold builder's fixed shell (the custom render layout
  // needs bounded height, which root canvas columns do not provide), while
  // the width stays parent-owned. Long pane labels wrap (default soft-wrap),
  // so 320px viewports hold.
  final pane1 = (props['pane1'] ?? 'Left pane') as String;
  final pane2 = (props['pane2'] ?? 'Right pane') as String;
  return SizedBox(
    height: 120,
    child: shadcn.ResizablePanel.horizontal(
      children: [
        shadcn.ResizablePane.flex(child: Center(child: Text(pane1))),
        shadcn.ResizablePane.flex(child: Center(child: Text(pane2))),
      ],
    ),
  );
}

Widget _buildSubfocus(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `SubFocus` builds bare around the required `builder` fn
  // (`(context, state) => Widget`); canvas renders the label statically —
  // hierarchical keyboard navigation only exists at runtime.
  final label = (props['label'] ?? 'Focused scope') as String;
  return shadcn.SubFocus(builder: (context, state) => Text(label));
}

Widget _buildRepeatedAnimationBuilder(Map<String, dynamic> props) {
  // No canvas block in `components.json` — default invented. The real
  // `PulsingAnimation` (the ready-to-use wrapper the utility component
  // ships) builds bare around the required `child`, looping fade + scale on
  // a 1200ms loop at runtime; canvas wraps the canvas-level `label` text.
  // The raw `RepeatedAnimationBuilder` typedef (a value + builder fn) has no
  // sane string-prop form, so the wrapper is the honest inline form.
  final label = (props['label'] ?? 'Pulsing') as String;
  return shadcn.PulsingAnimation(child: Text(label));
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
  // Track Y1 addition (2026-09-06): real builder for the `navigation_bar`
  // bottom tab bar (kit `NavigationBar` + `NavigationItem`, discovered per
  // the file-header rule). Label mirrors the `components.json` description
  // (registry bridge test); defaults are invented and documented on the
  // builder above. Only bool/string/num prop types already established by
  // the seed kinds.
  CatalogEntry(
    kind: 'navigation_bar',
    label:
        'Themed navigation bar supporting destinations, overflow, and responsive layout.',
    defaults: const {
      'tab1': 'Home',
      'tab2': 'Search',
      'tab3': 'Saved',
      'tab4': 'You',
      'index': 0,
    },
    build: _buildNavigationBar,
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
  // Track FF2 additions (2026-09-06): placeholder-blitz kinds — the
  // form/input family first (phone/input traps from triage), then the
  // bare-capable display/layout/utility batch. Labels mirror
  // `components.json` descriptions (registry bridge test); defaults are
  // invented and documented per builder above. Only bool/string/num/enum
  // prop types already established by the seed kinds.
  CatalogEntry(
    kind: 'phone_input',
    label:
        'International phone number input with country selector and formatting helpers.',
    defaults: const {'label': '', 'searchHint': 'Search countries...'},
    build: _buildPhoneInput,
  ),
  CatalogEntry(
    kind: 'chip_input',
    label:
        'Inline text input that converts typed tokens into chip widgets with removable buttons and autocomplete hooks.',
    defaults: const {
      'placeholder': 'Add a tag',
      'chip1': 'Design',
      'chip2': '',
    },
    build: _buildChipInput,
  ),
  CatalogEntry(
    kind: 'autocomplete',
    label:
        'Autocomplete overlay for text inputs with keyboard navigation and theming.',
    defaults: const {
      'placeholder': 'Search...',
      'suggestion1': 'Apple',
      'suggestion2': 'Apricot',
    },
    build: _buildAutocomplete,
  ),
  CatalogEntry(
    kind: 'item_picker',
    label: 'Grid/list picker with selection chips, search, and in-place actions.',
    defaults: const {
      'placeholder': 'Select item',
      'option1': 'Option 1',
      'option2': 'Option 2',
      'value': '',
    },
    build: _buildItemPicker,
  ),
  CatalogEntry(
    kind: 'multiple_choice',
    label: 'Choice widgets with single or multiple selection and form integration.',
    defaults: const {
      'mode': 'single',
      'option1': 'Option A',
      'option2': 'Option B',
      'option3': 'Option C',
      'value': 'Option A',
      'value2': 'Option B',
    },
    build: _buildMultipleChoice,
  ),
  CatalogEntry(
    kind: 'object_input',
    label: 'Date, time, and duration inputs powered by formatted editors and pickers.',
    defaults: const {
      'mode': 'date',
      'placeholder': 'Select value',
      'label': '',
    },
    build: _buildObjectInput,
  ),
  CatalogEntry(
    kind: 'text_field',
    label: 'Text input with rich features, autocomplete, and actions.',
    defaults: const {
      'placeholder': 'Type here',
      'label': '',
      'disabled': false,
      'initialValue': '',
    },
    build: _buildTextFieldKind,
  ),
  CatalogEntry(
    kind: 'markdown',
    label:
        'Advanced markdown renderer with asset/file sources and optional streaming support.',
    defaults: const {'data': '# Title\n\nSome **rich** text.'},
    build: _buildMarkdown,
  ),
  CatalogEntry(
    kind: 'text_animate',
    label: 'Stream-aware animated text renderer for incremental updates.',
    defaults: const {'text': 'Watch the words appear.'},
    build: _buildTextAnimate,
  ),
  CatalogEntry(
    kind: 'icon',
    label: 'Theme-driven icon size/color helpers and WrappedIcon.',
    defaults: const {'name': 'star', 'size': 24.0},
    build: _buildIcon,
  ),
  CatalogEntry(
    kind: 'navigation_menu',
    label:
        'Dropdown-style navigation menu with popovers, groups, and keyboard navigation.',
    defaults: const {
      'menu1': 'Products',
      'item1': 'Web Apps',
      'detail1': 'Landing pages and dashboards.',
      'menu2': 'Company',
      'item2': 'About',
      'detail2': 'Team, culture, and careers.',
    },
    build: _buildNavigationMenu,
  ),
  CatalogEntry(
    kind: 'dropzone',
    label: 'Dropzone surface for file uploads.',
    defaults: const {'hint': 'Drag files here', 'action': 'Browse files'},
    build: _buildDropzone,
  ),
  CatalogEntry(
    kind: 'border_loading',
    label:
        'Animated border loader wrapper (sweep/linear/radial gradients + tracer mode + circle/custom shapes).',
    defaults: const {'label': 'Loading'},
    build: _buildBorderLoading,
  ),
  CatalogEntry(
    kind: 'overflow_marquee',
    label:
        'Smooth marquee for overflowing content with fade edges and looped timing controls.',
    defaults: const {
      'text': 'This text scrolls when it overflows its parent.',
    },
    build: _buildOverflowMarquee,
  ),
  CatalogEntry(
    kind: 'focus_outline',
    label: 'Keyboard focus visualization outline with theming support.',
    defaults: const {'label': 'Focus me', 'focused': true},
    build: _buildFocusOutline,
  ),
  CatalogEntry(
    kind: 'switcher',
    label: 'Swipeable viewport that animates between children along an axis.',
    defaults: const {
      'direction': 'left',
      'page1': 'Page 1',
      'page2': 'Page 2',
    },
    build: _buildSwitcher,
  ),
  CatalogEntry(
    kind: 'scrollable',
    label: 'Two-dimensional scrollable client and faded viewport utilities.',
    defaults: const {
      'text1': 'First line of scrollable content.',
      'text2': 'Second line of scrollable content.',
      'text3': 'Third line of scrollable content.',
    },
    build: _buildScrollable,
  ),
  CatalogEntry(
    kind: 'stage_container',
    label: 'Responsive container that snaps to breakpoint widths.',
    defaults: const {'label': 'Stage content'},
    build: _buildStageContainer,
  ),
  CatalogEntry(
    kind: 'media_query',
    label:
        'Responsive helper that shows primary or alternate content based on width constraints.',
    defaults: const {
      'label': 'Wide content',
      'alternate': 'Narrow content',
      'minWidth': 0.0,
    },
    build: _buildMediaQuery,
  ),
  CatalogEntry(
    kind: 'scrollview',
    label: 'Middle-click drag scroll interceptor for desktop/web.',
    defaults: const {'label': 'Middle-drag to scroll'},
    build: _buildScrollview,
  ),
  CatalogEntry(
    kind: 'hover',
    label: 'Hover timing helpers plus lightweight state tracking widgets.',
    defaults: const {'label': 'Hover me'},
    build: _buildHover,
  ),
  CatalogEntry(
    kind: 'patch',
    label: 'Tracks consecutive taps and exposes click count details.',
    defaults: const {'label': 'Tap me'},
    build: _buildPatch,
  ),
  CatalogEntry(
    kind: 'text',
    label: 'Typography helpers and fluent text modifiers.',
    defaults: const {'text': 'Styled text'},
    build: _buildText,
  ),
  CatalogEntry(
    kind: 'filter_bar',
    label:
        'Controlled filter toolbar for list/table pages with search, sort, chips, date range, and clear-all.',
    defaults: const {'searchPlaceholder': 'Search'},
    build: _buildFilterBar,
  ),
  CatalogEntry(
    kind: 'fade_scroll',
    label: 'Edge fade overlays for scrollable content.',
    defaults: const {'row1': 'Row 1', 'row2': 'Row 2', 'row3': 'Row 3'},
    build: _buildFadeScroll,
  ),
  CatalogEntry(
    kind: 'resizable',
    label: 'Resizable panels with draggable dividers.',
    defaults: const {'pane1': 'Left pane', 'pane2': 'Right pane'},
    build: _buildResizable,
  ),
  CatalogEntry(
    kind: 'subfocus',
    label: 'Hierarchical focus scope for keyboard navigation.',
    defaults: const {'label': 'Focused scope'},
    build: _buildSubfocus,
  ),
  CatalogEntry(
    kind: 'repeated_animation_builder',
    label: 'Looping animation builder with interpolated values.',
    defaults: const {'label': 'Pulsing'},
    build: _buildRepeatedAnimationBuilder,
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

/// Builds the widget for [kind] with [props] and already-built [children],
/// or registry-fallback / [fallbackBuilder] output for non-catalog kinds.
/// Builders tolerate missing keys (each prop has a fallback), so
/// hand-written docs without full defaults still render. Migrated container
/// builders receive [children] (spliced into their spec slot); every other
/// builder keeps its 1-arg shape and never sees them (their nodes' children
/// render via the renderers' below-fallback, never inside chrome).
///
/// [scope] (Track R1) carries live state values (var name → value); bound
/// props (`=name`) resolve through [resolveBoundProps] before the builder
/// runs. Null (the default) renders bindings raw — see the library docs.
Widget buildCatalogItem(
  String kind,
  Map<String, dynamic> props, [
  List<Widget> children = const [],
  Map<String, dynamic>? scope,
]) {  final entry = findEntry(kind);
  if (entry == null) return _buildRegistryFallback(kind, props, children, scope);
  final effective = scope == null ? props : resolveBoundProps(kind, props, scope);
  if (children.isNotEmpty) {
    final build = entry.build;
    // Recovers the migrated 2-arg shape (see the [NodeBuilder] variance
    // note): true exactly for migrated container builders, so a future
    // 11th migration Just Works and unmigrated builders stay unreachable
    // with children.
    if (build is NodeBuilder) return build(effective, children);
  }
  return entry.build(effective);
}

/// Track U1 render-path unification (2026-09-06): canvas renders through
/// [buildCatalogItem], which used to consult [kCatalog] ONLY — so the ten
/// hand-verified bare registry kinds (`alert`, `chip`,
/// `circular_progress_indicator`, `linear_progress_indicator`,
/// `triple_dots`, `dot_indicator`, `empty_state`, `code_snippet`,
/// `number_ticker`, `text_area`) rendered `unknown: <kind>` + X-box even
/// though the palette lists them and drops accept them.
///
/// Renderability no longer equals catalog membership: on a catalog miss,
/// this fallback consults the generated registry
/// (`registry.findRegistryEntry`). A hit whose entry is NOT a placeholder
/// build renders its real widget; true placeholders and totally-unknown
/// kinds keep [fallbackBuilder] exactly as before.
///
/// `canvasReady` semantics are unchanged: the flags still declare which
/// registry entries own real bare-widget builders (the palette honesty
/// signal), and no flag is touched here — this fallback only READS them.
/// (This note lives in the catalog because `component_registry.dart` is
/// generated and off-limits.)
Widget _buildRegistryFallback(
  String kind,
  Map<String, dynamic> props,
  List<Widget> children,
  Map<String, dynamic>? scope,
) {
  final reg = registry.findRegistryEntry(kind);
  // No registry entry, or a placeholder entry (`canvasReady` is false for
  // placeholders per the registry header — true only where a real
  // bare-widget builder exists): keep the honest unknown + X as before.
  if (reg == null || !reg.canvasReady) return fallbackBuilder(kind);
  // Same props/scope contract as the catalog path: bound props resolve
  // through [scope] first (schema-less registry kinds keep raw values — see
  // [resolveBoundProp] — so this is a no-op for them, never a crash).
  final effective = scope == null ? props : resolveBoundProps(kind, props, scope);
  final propsBuild = _registryPropsBuilderFor(kind);
  if (propsBuild != null) {
    // Mirrors the [NodeBuilder] recovery in [buildCatalogItem]: children
    // splice into chrome only for container kinds with a migrated 2-arg
    // builder. None of the ten registry-only kinds is a container (or
    // 2-arg), so their nodes' children keep rendering via the renderers'
    // below-fallback, as today.
    if (children.isNotEmpty &&
        kContainerKinds.contains(kind) &&
        propsBuild is NodeBuilder) {
      return propsBuild(effective, children);
    }
    return propsBuild(effective);
  }
  // Generic tail: canvasReady registry kinds without a props-aware builder
  // above (today only the `row` pseudo-kind — rows lay out structurally and
  // never arrive here with children). The `Builder` supplies the
  // `BuildContext` the registry `WidgetBuilder` needs; a build that still
  // materializes a [registry.RegistryPlaceholder] (flag drift) keeps the
  // fallback, so placeholder builds can never leak through here.
  final chrome = Builder(
    builder: (context) {
      final built = reg.build(context);
      if (built is registry.RegistryPlaceholder) return fallbackBuilder(kind);
      return built;
    },
  );
  if (children.isEmpty || !kContainerKinds.contains(kind)) return chrome;
  // Unreachable today (every container kind lives in [kCatalog]): mirrors
  // the renderers' §1 below-fallback rhythm so children are never silently
  // dropped if a container kind ever lands here.
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      chrome,
      for (var i = 0; i < children.length; i++) ...[
        const SizedBox(height: kFlowScreenGap),
        children[i],
      ],
    ],
  );
}

/// Props-aware builders for the registry-only canvasReady kinds (the ten
/// hand-verified EASY builders in `component_registry.dart`). A `switch`
/// (not a top-level map) keeps these tear-offs call-time — no initialization
/// coupling with the generated registry this library now imports (the
/// registry imports this catalog back for its bridges; Dart tolerates the
/// cycle because every cross-reference resolves at call time).
///
/// Returns null for every other kind: placeholders never reach here (gated
/// on `canvasReady` above) and remaining canvasReady kinds take the generic
/// `Builder` tail. A future eleventh bare kind renders via that tail until
/// it gains a props-aware case here — never `unknown:` again.
Widget Function(Map<String, dynamic>)? _registryPropsBuilderFor(String kind) {
  switch (kind) {
    case 'alert':
      return registry.buildAlertEntry;
    case 'chip':
      return registry.buildChipEntry;
    case 'circular_progress_indicator':
      return registry.buildCircularProgressEntry;
    case 'code_snippet':
      return registry.buildCodeSnippetEntry;
    case 'dot_indicator':
      return registry.buildDotIndicatorEntry;
    case 'empty_state':
      return registry.buildEmptyStateEntry;
    case 'linear_progress_indicator':
      return registry.buildLinearProgressEntry;
    case 'number_ticker':
      return registry.buildNumberTickerEntry;
    case 'text_area':
      return registry.buildTextAreaEntry;
    case 'triple_dots':
      return registry.buildTripleDotsEntry;
    default:
      return null;
  }
}

/// Resolves one bound prop: a `=var` [raw] value becomes the scope value
/// coerced to the prop's [PropSpec] type (`string`/`enum`/`color`/`slot`
/// stringify, `number`/`bool` coerce-or-raw); anything else (non-bindings,
/// unknown vars, schema-less kinds) returns [raw] untouched — never a throw.
Object? resolveBoundProp(
  String kind,
  String name,
  Object? raw,
  Map<String, dynamic> scope,
) {
  final ref = bindingNameOf(raw);
  if (ref == null || !scope.containsKey(ref)) return raw;
  final value = scope[ref];
  final spec = findSpec(kind, name);
  switch (spec?.type) {
    case 'string':
    case 'enum':
    case 'color':
    case 'slot':
      return stringifyStateValue(value);
    case 'number':
      if (value is num) return value;
      return num.tryParse('$value') ?? raw;
    case 'bool':
      if (value is bool) return value;
      final text = '$value';
      if (text == 'true') return true;
      if (text == 'false') return false;
      return raw;
    default:
      // Schema-less kinds: no safe type, leave the raw binding.
      return raw;
  }
}

/// Resolves every bound prop in [props] for [kind] (see [resolveBoundProp]).
/// Returns [props] itself when nothing is bound (no copy, no rebuild).
Map<String, dynamic> resolveBoundProps(
  String kind,
  Map<String, dynamic> props,
  Map<String, dynamic> scope,
) {
  Map<String, dynamic>? out;
  props.forEach((key, raw) {
    if (!isStateBinding(raw)) return;
    final resolved = resolveBoundProp(kind, key, raw, scope);
    if (identical(resolved, raw)) return;
    out ??= Map<String, dynamic>.of(props);
    out![key] = resolved;
  });
  return out ?? props;
}

/// Whether [raw] is a state binding (`=varName`). Re-exported here so
/// inspector/preview share the catalog's binding vocabulary.
bool isStateBinding(Object? raw) =>
    bindingNameOf(raw) != null;

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
