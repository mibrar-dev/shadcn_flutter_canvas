/// Clean-folders bundle exporter (P2c): screens + shadcn bodies + manifest + zip.
///
/// Pure Dart (CLI-reusable): builds the installable `screen add` bundle from
/// a [ScreenDoc]. Kind metadata snapshots `components.json` for the 29
/// canvas-ready kinds; bodies arrive via [sourcesByDestination]. Unknown kinds warn.
///
/// Track F3 (bundle bodies): emitted screens inline real per-item widget
/// expressions for every catalog kind (mirroring the canvas app's
/// `component_catalog.dart` builders prop-for-prop with the same defaults
/// and edge handling, static-snapshotted: stateful cells render their
/// initial value with no-op callbacks, exactly like `codegen_single.dart`).
/// Non-catalog kinds (unknown ids, or known kinds with no catalog builder:
/// `chip`, `alert`, `circular_progress_indicator`,
/// `linear_progress_indicator`, `triple_dots`, `dot_indicator`,
/// `empty_state`, `code_snippet`, `number_ticker`, `text_area`) keep the
/// explicit doc comment plus a `Text` placeholder and never crash.
///
/// Barrel paths resolve against the real kit entry files (verified once
/// against the pinned kit checkout's `components.json` `files[].destination`
/// entries — see [_barrelFile]; re-verify against a newer kit on upgrade).
///
/// Track G2 (bundle tree closure): kind-prefix bodies alone do not compile —
/// they reference shared files (`../../../shared/…`) and sibling parts via
/// relative URIs. [buildCleanBundle] therefore emits the relative-reference
/// fixpoint: every relative `import`/`export`/`part`/`part of` URI in an
/// emitted body resolves to another emitted file (shared files land under
/// their `{sharedPath}/` destinations — the `{installPath}/shared/…`/
/// `{sharedPath}/…` rewrite in [_resolveBundleUri] mirrors the emitted
/// `lib/ui/shadcn/shared/` layout, so relative depth is preserved exactly).
/// Part edges are derived by parsing (the same part→library data the embed
/// tool ships as `kEmbeddedParts` for inliners, which this Flutter-free
/// package cannot import): a library's `part` directives pull its parts, and
/// a part's `part of` pulls its library, so no part ever compiles orphaned.
/// `package:`/`dart:` URIs are not files — third-party ones ride the
/// per-kind pubspec table (see [_kinds]).
///
/// Emitted screens are vanilla `StatefulWidget`s with no store dependency
/// (flutter + kit only): adopt any state management by lifting the `build`
/// body into your own widget. Per-node responsive uses the same
/// tier-conditional idiom as `codegen_single.dart`; tap actions navigate
/// with `Navigator.pushNamed` to the target screen's route (unknown `to`
/// ids emit a comment and no navigation, never a crash).
///
/// Track H2 (screen wiring): each screen file imports the barrel of every
/// catalog kind it renders (plus the cross-kind extras in
/// [_screenExtraKinds] and the non-kind files in [_screenExtraTemplates]),
/// resolved via [_barrelFile]. Import clashes disambiguate without private
/// prefixes: Flutter-SDK names hide on the Flutter import, the `menu`
/// barrel hides its shadowed names (mirroring the kit's own global barrel),
/// and the `tabs` barrel imports `as tabs` with qualified call sites.
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import 'screen_doc.dart';

/// Result of [buildCleanBundle].
class BundleManifest {
  final String manifestJson; // JSON descriptor (`manifest.json` content).
  final Map<String, String> files; // Writable code files: destPath->content.
  final String pubspecPatch; // YAML merge of used components' pubspec deps.
  final List<int> zipBytes; // Zip of [files] + manifest.json + patch yaml.

  const BundleManifest({
    required this.manifestJson,
    required this.files,
    required this.pubspecPatch,
    required this.zipBytes,
  });
}

/// Per-kind install metadata snapshotted from `components.json`.
/// Positional: (destination-template prefix, shared ids, pubspec deps,
/// component dependsOn). The barrel is derived: `<prefix><kind>.dart`.
class _KindSpec {
  final String prefix;
  final List<String> shared;
  final Map<String, String> pubspecDeps;
  final List<String> dependsOn;

  const _KindSpec(this.prefix, this.shared, this.pubspecDeps, this.dependsOn);
}

// Exact metadata for the 78 canvas-ready kinds (19 seed + 10 W1: chip, alert,
// circular_progress_indicator, linear_progress_indicator, triple_dots,
// dot_indicator, empty_state, code_snippet, number_ticker, text_area + 17
// Track J: basic, card_image, scaffold, collapsible, steps, timeline,
// outlined_container, hidden, keyboard_shortcut, tracker, chat, selectable,
// star_rating, clickable, scrollbar, pagination, alert_dialog + 15 Track M:
// menu, popover, popup, menubar, dropdown_menu, context_menu, hover_card,
// command, swiper, refresh_trigger, tab_container, tab_list, tab_pane,
// stepper, slider + 17 Track P: input_otp, calendar, date_picker,
// time_picker, carousel, tree, table, form, form_field, formatted_input,
// validated, color_picker, color_input, hsl, hsv, history, feature_carousel
// — snapshotted from the pinned kit's `components.json`:
// destination prefix from `files[].destination`
// (`{installPath}/components/<category>/<id>/`), alphabetized `shared`,
// `pubspec.dependencies`, `dependsOn` verbatim — unknown dep ids warn at
// export time, same as the seed kinds' `text_field`).
// NOTE: `select`'s `dependsOn` (`async`, `command`, `hover`,
// `menu`, `text_field`) — `command`/`menu` now resolve (this batch),
// `async`/`hover`/`text_field` still warn (transitively pulled bodies are out
// of scope; the ids are kept verbatim, never invented). Its `chip` and
// `dialog` deps resolve.
// NOTE: `tooltip`'s `dependsOn` (`popover`) now resolves (this batch adds
// `popover`).
// NOTE: `text_area`'s `dependsOn` (`text_field`) warns the same way `input`'s
// does (verbatim policy).
// NOTE (Track J): `scaffold`'s `dependsOn` (`drawer`, `linear_progress_indicator`,
// `text`) partially warns — `drawer`/`linear_progress_indicator` resolve, `text`
// has no `_KindSpec` (verbatim policy). `steps`/`timeline` also name `text`.
// `card_image`'s (`basic`, `button`, `outlined_container`), `chat`'s (same
// three), `collapsible`'s (`button`), `keyboard_shortcut`'s (`card`),
// `tracker`'s (`tooltip`), `pagination`'s (`button`, `triple_dots`), and
// `alert_dialog`'s (`dialog`) deps all resolve.
// NOTE (Track M): `menubar`'s (`menu`), `dropdown_menu`'s (`menu`, `drawer`),
// `context_menu`'s (`menu`), `hover_card`'s (`tooltip`), `popup`'s
// (`dialog`), `swiper`'s (`drawer`), `refresh_trigger`'s (`card`,
// `checkbox`), and `tab_list`'s (`button`, `tab_container`) deps all resolve.
// `command`'s (`button`, `dialog`, `divider`, `text_field`), `stepper`'s
// (`icon`, `text`), and `tab_pane`'s (`outlined_container`, `sortable`,
// `tab_container`) partially warn — `text`/`text_field`/`icon`/`sortable`
// have no `_KindSpec` (verbatim policy).
// NOTE (Track P): `calendar`'s (`button`), `carousel`'s (`dot_indicator`),
// `date_picker`'s (`calendar`, `form_field`), `validated`'s (`form`),
// `form_field`'s (`alert_dialog`, `button`, `card`, `dialog`),
// `color_input`'s (`button`, `color_picker`, `form_field`, `history`),
// `history`'s (`button`, part of [`alpha`, `button`]), and
// `feature_carousel`'s/`table`'s (no deps) all resolve.
// `input_otp`'s (`text_field`), `hsl`'s/`hsv`'s (`alpha`),
// `tree`'s (`icon`), `form`'s (`text_field`, part of
// [`button`, `text_field`, `checkbox`]), `formatted_input`'s (`text_field`,
// part of [`button`, `form`, `outlined_container`, `text_field`]),
// `time_picker`'s (`text`/`text_field`, part of
// [`button`, `form_field`, `text`, `text_field`]), and `color_picker`'s
// (`alpha`/`color`/`eye_dropper`/`formatter`/`text_field`, part of
// [`alpha`, `button`, `color`, `eye_dropper`, `formatter`, `history`,
// `select`, `text_field`]) partially warn (verbatim policy).
// NOTE (Track G2): several `pubspecDeps` below carry MORE than the kit's
// per-component metadata declares (verified kind-by-kind against the pinned
// kit's `components.json`, which matches this table exactly). The extras are
// closure-implied: the bundle tree now ships the shared/component files the
// emitted bodies relatively reference, and those files import packages the
// owning component never declared — shared `clickable`/`overlay`/
// `form_value_supplier`/`sheet_overlay`/`subfocus`/`text`/`util` barrels
// import `data_widget` (so 11 gap-only kinds gain it), `checkbox` bodies
// import `animation_kit` (so `form`/`formatted_input`/`refresh_trigger`/
// `validated` gain it), `form` bodies import `email_validator` (so
// `formatted_input`/`validated` gain it), and `formatter` bodies import
// `expressions: ^0.2.5+2` (the kit `formatter` component's own constraint,
// gained by `color_picker`/`color_input` whose barrels relatively reference
// `formatter.dart`). `number_ticker`'s `intl` stays: declared by the kit but
// imported by no shipped body (harmless, verbatim policy).
const _kinds = <String, _KindSpec>{
  'button': _KindSpec('{installPath}/components/control/button/',
      ['clickable', 'color_extensions', 'component_schema', 'focus_outline', 'form_control', 'form_value_supplier', 'generated_colors', 'geometry_extensions', 'menu_group', 'platform_utils', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'card': _KindSpec('{installPath}/components/layout/card/',
      ['border_utils', 'color_extensions', 'component_schema', 'outlined_container', 'sheet_overlay', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'input': _KindSpec('{installPath}/components/form/input/',
      ['constants', 'form_value_supplier', 'lucide_icons', 'overlay', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button', 'text_field']),
  'badge': _KindSpec('{installPath}/components/display/badge/',
      ['component_schema', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button']),
  'switch': _KindSpec('{installPath}/components/form/switch/',
      ['border_utils', 'component_schema', 'focus_outline', 'form_control', 'form_value_supplier', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'avatar': _KindSpec('{installPath}/components/display/avatar/',
      ['component_schema', 'geometry_extensions', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'checkbox': _KindSpec('{installPath}/components/form/checkbox/',
      ['animated_value_builder', 'border_utils', 'clickable', 'color_extensions', 'component_schema', 'constants', 'form_control', 'form_value_supplier', 'style_value', 'text_modifiers', 'theme'],
      {'animation_kit': '^0.0.2', 'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'divider': _KindSpec('{installPath}/components/display/divider/',
      ['animated_value_builder', 'axis', 'axis_insets', 'axis_insets_directional', 'axis_insets_geometry', 'component_schema', 'constants', 'style_value', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'progress': _KindSpec('{installPath}/components/display/progress/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'tabs': _KindSpec('{installPath}/components/navigation/tabs/',
      ['border_utils', 'component_schema', 'constants', 'fade_scroll', 'geometry_extensions', 'outlined_container', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['sortable', 'text', 'button']),
  'accordion': _KindSpec('{installPath}/components/layout/accordion/',
      ['component_schema', 'constants', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'select': _KindSpec('{installPath}/components/form/select/',
      ['clickable', 'component_schema', 'focus_outline', 'form_control', 'form_value_supplier', 'icon_extensions', 'lucide_icons', 'overlay', 'radix_icons', 'style_value', 'subfocus', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['async', 'button', 'chip', 'command', 'dialog', 'hover', 'menu', 'text_field']),
  'radio_group': _KindSpec('{installPath}/components/form/radio_group/',
      ['color_extensions', 'component_schema', 'constants', 'focus_outline', 'form_control', 'form_value_supplier', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card']),
  'skeleton': _KindSpec('{installPath}/components/display/skeleton/',
      ['color_extensions', 'component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1', 'skeletonizer': '^2.1.0+1'}, ['avatar']),
  'breadcrumb': _KindSpec('{installPath}/components/navigation/breadcrumb/',
      ['basic_layout', 'radix_icons', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'dialog': _KindSpec('{installPath}/components/overlay/dialog/',
      ['color_extensions', 'component_schema', 'constants', 'geometry_extensions', 'overlay', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card']),
  'tooltip': _KindSpec('{installPath}/components/overlay/tooltip/',
      ['animated_value_builder', 'color_extensions', 'component_schema', 'constants', 'hover', 'outlined_container', 'overlay', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['popover']),
  'toast': _KindSpec('{installPath}/components/overlay/toast/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'drawer': _KindSpec('{installPath}/components/overlay/drawer/',
      ['color_extensions', 'component_schema', 'constants', 'controlled_animation', 'geometry_extensions', 'outlined_container', 'overlay', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dialog']),
  'chip': _KindSpec('{installPath}/components/display/chip/',
      ['component_schema', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button']),
  'alert': _KindSpec('{installPath}/components/layout/alert/',
      ['basic_layout', 'component_schema', 'outlined_container', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'circular_progress_indicator': _KindSpec('{installPath}/components/display/circular_progress_indicator/',
      ['animated_value_builder', 'color_extensions', 'component_schema', 'constants', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'linear_progress_indicator': _KindSpec('{installPath}/components/display/linear_progress_indicator/',
      ['animated_value_builder', 'color_extensions', 'component_schema', 'constants', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'triple_dots': _KindSpec('{installPath}/components/display/triple_dots/',
      [],
      {}, []),
  'dot_indicator': _KindSpec('{installPath}/components/display/dot_indicator/',
      ['clickable', 'component_schema', 'constants', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'empty_state': _KindSpec('{installPath}/components/display/empty_state/',
      ['component_schema', 'radix_icons', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card', 'button']),
  'code_snippet': _KindSpec('{installPath}/components/display/code_snippet/',
      ['component_schema', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'number_ticker': _KindSpec('{installPath}/components/display/number_ticker/',
      ['animated_value_builder', 'component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1', 'intl': '^0.20.2'}, []),
  'text_area': _KindSpec('{installPath}/components/form/text_area/',
      ['theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['text_field']),
  'basic': _KindSpec('{installPath}/components/layout/basic/',
      ['style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'card_image': _KindSpec('{installPath}/components/layout/card_image/',
      ['constants', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['basic', 'button', 'outlined_container']),
  'scaffold': _KindSpec('{installPath}/components/layout/scaffold/',
      ['color_extensions', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['drawer', 'linear_progress_indicator', 'text']),
  'collapsible': _KindSpec('{installPath}/components/layout/collapsible/',
      ['component_schema', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button']),
  'steps': _KindSpec('{installPath}/components/layout/steps/',
      ['theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['text']),
  'timeline': _KindSpec('{installPath}/components/layout/timeline/',
      ['theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['text']),
  'outlined_container': _KindSpec('{installPath}/components/layout/outlined_container/',
      ['animated_value_builder', 'border_utils', 'component_schema', 'constants', 'geometry_extensions', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'hidden': _KindSpec('{installPath}/components/layout/hidden/',
      ['animated_value_builder', 'component_schema', 'constants', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'keyboard_shortcut': _KindSpec('{installPath}/components/display/keyboard_shortcut/',
      ['color_extensions', 'component_schema', 'keyboard_shortcut_utils', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card']),
  'tracker': _KindSpec('{installPath}/components/display/tracker/',
      ['component_schema', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['tooltip']),
  'chat': _KindSpec('{installPath}/components/display/chat/',
      ['axis', 'clickable', 'constants', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['basic', 'button', 'outlined_container']),
  'selectable': _KindSpec('{installPath}/components/display/selectable/',
      ['theme'],
      {'gap': '^3.0.1'}, []),
  'star_rating': _KindSpec('{installPath}/components/form/star_rating/',
      ['animated_value_builder', 'component_schema', 'constants', 'form_control', 'form_value_supplier', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'clickable': _KindSpec('{installPath}/components/control/clickable/',
      ['animated_value_builder', 'clickable', 'constants', 'focus_outline', 'platform_utils', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'scrollbar': _KindSpec('{installPath}/components/control/scrollbar/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'pagination': _KindSpec('{installPath}/components/navigation/pagination/',
      ['icon_extensions', 'localizations', 'radix_icons', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button', 'triple_dots']),
  'alert_dialog': _KindSpec('{installPath}/components/overlay/alert_dialog/',
      ['overlay', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dialog']),
  'menu': _KindSpec('{installPath}/components/overlay/menu/',
      ['basic_layout', 'color_extensions', 'component_schema', 'constants', 'geometry_extensions', 'keyboard_shortcut_utils', 'outlined_container', 'overlay', 'radix_icons', 'style_value', 'subfocus', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dialog', 'drawer', 'button']),
  'popover': _KindSpec('{installPath}/components/overlay/popover/',
      ['color_extensions', 'constants', 'geometry_extensions', 'overlay', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'popup': _KindSpec('{installPath}/components/overlay/popup/',
      ['component_schema', 'menu_group', 'overlay', 'sheet_overlay', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dialog']),
  'menubar': _KindSpec('{installPath}/components/overlay/menubar/',
      ['component_schema', 'constants', 'outlined_container', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['menu']),
  'dropdown_menu': _KindSpec('{installPath}/components/overlay/dropdown_menu/',
      ['component_schema', 'overlay', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['menu', 'drawer']),
  'context_menu': _KindSpec('{installPath}/components/overlay/context_menu/',
      ['animated_value_builder', 'component_schema', 'constants', 'localizations', 'overlay', 'sheet_overlay', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['menu']),
  'hover_card': _KindSpec('{installPath}/components/overlay/hover_card/',
      ['component_schema', 'overlay', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['tooltip']),
  'command': _KindSpec('{installPath}/components/control/command/',
      ['border_utils', 'clickable', 'color_extensions', 'constants', 'focus_outline', 'icon_extensions', 'localizations', 'lucide_icons', 'outlined_container', 'overlay', 'subfocus', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button', 'dialog', 'divider', 'text_field']),
  'swiper': _KindSpec('{installPath}/components/overlay/swiper/',
      ['component_schema', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['drawer']),
  'refresh_trigger': _KindSpec('{installPath}/components/overlay/refresh_trigger/',
      ['animated_value_builder', 'component_schema', 'constants', 'localizations', 'style_value', 'theme', 'util'],
      {'animation_kit': '^0.0.2', 'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card', 'checkbox']),
  'tab_container': _KindSpec('{installPath}/components/navigation/tab_container/',
      ['theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'tab_list': _KindSpec('{installPath}/components/navigation/tab_list/',
      ['style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button', 'tab_container']),
  'tab_pane': _KindSpec('{installPath}/components/navigation/tab_pane/',
      ['fade_scroll', 'geometry_extensions', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['outlined_container', 'sortable', 'tab_container']),
  'stepper': _KindSpec('{installPath}/components/navigation/stepper/',
      ['clickable', 'component_schema', 'constants', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['icon', 'text']),
  'slider': _KindSpec('{installPath}/components/form/slider/',
      ['color_extensions', 'component_schema', 'form_control', 'form_value_supplier', 'slider_value', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'input_otp': _KindSpec('{installPath}/components/form/input_otp/',
      ['color_extensions', 'component_schema', 'focus_outline', 'form_value_supplier', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['text_field']),
  'calendar': _KindSpec('{installPath}/components/display/calendar/',
      ['component_schema', 'icon_extensions', 'localizations', 'lucide_icons', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button']),
  'date_picker': _KindSpec('{installPath}/components/form/date_picker/',
      ['component_schema', 'form_control', 'localizations', 'localizations_extensions', 'lucide_icons', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['calendar', 'form_field']),
  'time_picker': _KindSpec('{installPath}/components/form/time_picker/',
      ['component_schema', 'form_control', 'localizations', 'localizations_extensions', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button', 'form_field', 'text', 'text_field']),
  'carousel': _KindSpec('{installPath}/components/display/carousel/',
      ['animation_queue', 'component_schema', 'style_value', 'theme', 'wrap_utils'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dot_indicator']),
  'tree': _KindSpec('{installPath}/components/display/tree/',
      ['clickable', 'color_extensions', 'constants', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['icon']),
  'table': _KindSpec('{installPath}/components/layout/table/',
      ['clickable', 'component_schema', 'resizer', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'form': _KindSpec('{installPath}/components/form/form/',
      ['color_extensions', 'focus_outline', 'localizations', 'phone_number', 'slider_value', 'text_modifiers', 'theme', 'util'],
      {'animation_kit': '^0.0.2', 'data_widget': '^0.0.2', 'email_validator': '^3.0.0', 'gap': '^3.0.1'}, ['button', 'text_field', 'checkbox']),
  'form_field': _KindSpec('{installPath}/components/form/form_field/',
      ['form_value_supplier', 'localizations', 'overlay', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['alert_dialog', 'button', 'card', 'dialog']),
  'formatted_input': _KindSpec('{installPath}/components/form/formatted_input/',
      ['clickable', 'color_extensions', 'component_schema', 'focus_outline', 'form_control', 'overlay', 'text_input_utils', 'text_modifiers', 'theme', 'util'],
      {'animation_kit': '^0.0.2', 'data_widget': '^0.0.2', 'email_validator': '^3.0.0', 'gap': '^3.0.1'}, ['button', 'form', 'outlined_container', 'text_field']),
  'validated': _KindSpec('{installPath}/components/form/validated/',
      [],
      {'animation_kit': '^0.0.2', 'data_widget': '^0.0.2', 'email_validator': '^3.0.0', 'gap': '^3.0.1'}, ['form']),
  'color_picker': _KindSpec('{installPath}/components/form/color_picker/',
      ['component_schema', 'localizations', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'expressions': '^0.2.5+2', 'gap': '^3.0.1'}, ['alpha', 'button', 'color', 'eye_dropper', 'formatter', 'history', 'select', 'text_field']),
  'color_input': _KindSpec('{installPath}/components/form/color_input/',
      ['component_schema', 'constants', 'form_control', 'form_value_supplier', 'localizations', 'lucide_icons', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'expressions': '^0.2.5+2', 'gap': '^3.0.1'}, ['button', 'color', 'color_picker', 'eye_dropper', 'form_field', 'history']),
  'hsl': _KindSpec('{installPath}/components/form/hsl/',
      ['theme'],
      {'gap': '^3.0.1'}, ['alpha']),
  'hsv': _KindSpec('{installPath}/components/form/hsv/',
      ['theme'],
      {'gap': '^3.0.1'}, ['alpha']),
  'history': _KindSpec('{installPath}/components/form/history/',
      ['theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['alpha', 'button']),
  'feature_carousel': _KindSpec('{installPath}/components/display/feature_carousel/',
      ['component_schema', 'theme'],
      {'gap': '^3.0.1'}, []),
};

const _installPath = '{installPath}/';
const _sharedPath = '{sharedPath}/';
const _installRoot = 'lib/ui/shadcn';
const _sharedRoot = 'lib/ui/shadcn/shared';
const _flutterWidgets = 'package:' 'flutter/widgets.dart'; // split: generated output imports widgets, this file does not.
const _flutterMaterial = 'package:' 'flutter/material.dart'; // split: same trick for the material import.
const _flutterServices = 'package:' 'flutter/services.dart'; // split: same trick for keyboard-shortcut keys.
const _dartAsync = 'dart:' 'async'; // split: same trick for the validator helper.

/// Kinds whose emitted bodies need material-only APIs (`Icons`, `Curves`,
/// `Theme`): those screens import `package:flutter/material.dart` (which
/// re-exports widgets) instead of widgets directly. Kind-based, not
/// prop-based, so a `basic` with both icons hidden still imports material —
/// harmless (every name material provides is used) and deterministic.
/// `card_image`/`carousel` art is static (const color + text label, no
/// `Theme`/`Icons`) precisely to stay widgets-only; see their builders.
/// `popup` needs material for the catalog-mirroring `const Divider(height: 1)`
/// in its body (Flutter's `Divider` lives in material, not widgets).
const _bundleNeedsMaterial = {'basic', 'toast', 'feature_carousel', 'popup'};

/// Real kit entry file per kind, relative to the kind's install prefix.
///
/// Default (absent here): `<kind>.dart` — the export barrel most components
/// ship (e.g. `components/control/button/button.dart`). Exceptions below were
/// resolved by reading the pinned kit checkout (oracle: `components.json`
/// `files[].destination`, cross-checked with `ls` + the kit's own
/// `flutter_shadcn_kit.dart` barrel, which exports `hsl/hsl_color_slider.dart`
/// and `hsv/hsv_color_slider.dart` but nothing for `tab_list`):
/// * `hsl` ships `hsl_color_slider.dart` (no `hsl.dart`).
/// * `hsv` ships `hsv_color_slider.dart` (no `hsv.dart`).
/// * `tab_list` ships NO top-level barrel — its only importable library root
///   is `_impl/core/tab_list.dart` (kept wired via the header comment for
///   hand use; emitted tab-list bodies render the `tabs` barrel's `TabList`
///   family instead, mirroring the canvas catalog — see [_bundleTabList]).
/// Re-verify this map against a newer kit on upgrade (the bundle test pins
/// every emitted barrel path against the checked-in list derived here).
const _barrelFile = <String, String>{
  'hsl': 'hsl_color_slider.dart',
  'hsv': 'hsv_color_slider.dart',
  'tab_list': '_impl/core/tab_list.dart',
};

/// Track H2 (screen wiring): kinds whose screen bodies are `Text`
/// placeholders (no catalog builder in [_bundleBody]) need no barrel import —
/// the screen references no kit names for them. Every other known kind has a
/// real body and gets a barrel import in screens that use it.
const _bundlePlaceholderKinds = {
  'chip',
  'alert',
  'circular_progress_indicator',
  'linear_progress_indicator',
  'triple_dots',
  'dot_indicator',
  'empty_state',
  'code_snippet',
  'number_ticker',
  'text_area',
};

/// Track H2: extra kind barrels a screen body references beyond its own
/// kind's barrel (verified per builder against the pinned kit checkout —
/// kit barrels import but never re-export each other, so e.g. a `card`
/// footer renders `PrimaryButton` which only the `button` barrel provides).
/// Screens import these alongside the used kinds'; [buildCleanBundle] also
/// `requireKind`s them so the barrels ship (never a dangling import).
/// `menu` bodies render the *popup* barrel's `MenuPopup` (mirroring the
/// canvas catalog, which reads it off the kit's global barrel where the
/// menu barrel's own `MenuPopup` is hidden); `tab_list` renders the
/// tab-container barrel's `TabChild` (its own barrel only declares
/// `TabList`); `command` renders the popup barrel's `MenuPopup` the same way.
const _screenExtraKinds = <String, List<String>>{
  'card': ['button'],
  'dialog': ['button'],
  'tooltip': ['button'],
  'alert_dialog': ['button'],
  'popover': ['button', 'dialog'],
  'menu': ['popup'],
  'menubar': ['menu'],
  'dropdown_menu': ['menu'],
  'context_menu': ['button', 'menu'],
  'hover_card': ['button', 'card'],
  'command': ['popup'],
  'swiper': ['drawer', 'outlined_container'],
  'carousel': ['dot_indicator'],
  'tab_pane': ['tab_container'],
  'form': ['button'],
  'validated': ['form'],
  'color_picker': ['history'],
  'color_input': ['history'],
};

/// Track H2: non-kind library files a screen body references. `TextField`
/// lives in the `text_field` component library (no canvas kind, hence no
/// `_KindSpec` — the `input` kind barrel imports it but never re-exports
/// it); `ColorDerivative` lives in the `utility/color` library (imported the
/// same way by the color barrels). Screens import these files directly;
/// [buildCleanBundle] seeds them for emission (with manifest entries) when
/// the source map carries them, so the imports never dangle.
const _screenExtraTemplates = <String, String>{
  'input': '{installPath}/components/form/text_field/text_field.dart',
  'command': '{installPath}/components/form/text_field/text_field.dart',
  'form': '{installPath}/components/form/text_field/text_field.dart',
  'form_field': '{installPath}/components/form/text_field/text_field.dart',
  'validated': '{installPath}/components/form/text_field/text_field.dart',
  'color_picker': '{installPath}/components/utility/color/color.dart',
  'color_input': '{installPath}/components/utility/color/color.dart',
};

/// Destination paths for [_screenExtraTemplates] values (via
/// [_resolveDestination]), kept here so screens and the emission seed share
/// one literal per file.
String _screenExtraDest(String template) => _resolveDestination(template);

/// Track H2: Flutter-SDK names to `hide` on the screen's Flutter import, per
/// imported kind barrel. The kit reuses several Flutter names for its own
/// widgets (`Table`, `Form`, `Tooltip`, …); Dart reports the use as
/// ambiguous unless the Flutter one is hidden, and hiding keeps every
/// kit call site bare and readable (mirroring how the kit's own
/// `validated.dart` does `import 'package:flutter/widgets.dart' hide Form`).
/// Only names the screen's own barrels provide are hidden — e.g. `Divider`
/// is hidden only when the kit `divider` barrel is imported, because popup
/// bodies intentionally render Flutter's `Divider`. The tables split by
/// which Flutter library exports the hidden names: hiding a name the
/// imported library never exported warns (`undefined_hidden_name`), so
/// material-only names hide only on material imports. `TextField`
/// (material) hides whenever the supplemental text-field file is imported
/// on a material screen; `RadioGroup` hides always — Flutter 3.47 ships its
/// own widgets-level `RadioGroup`.
const _screenFlutterHideWidgets = <String, List<String>>{
  'table': ['Table', 'TableCell', 'TableRow'],
  'form': ['Form', 'FormField'],
  'radio_group': ['RadioGroup'],
};

/// Material-only half of the Track H2 hide table (see
/// [_screenFlutterHideWidgets]): applied only when the screen imports
/// `package:flutter/material.dart`.
const _screenFlutterHideMaterial = <String, List<String>>{
  'selectable': ['SelectableText'],
  'scrollbar': ['Scrollbar'],
  'tooltip': ['Tooltip'],
  'alert_dialog': ['AlertDialog'],
  'stepper': ['Step', 'Stepper'],
  'scaffold': ['AppBar', 'Scaffold'],
  'switch': ['Switch'],
  'slider': ['Slider'],
  'checkbox': ['Checkbox'],
  'divider': ['Divider'],
  'badge': ['Badge'],
  'card': ['Card'],
  'dropdown_menu': ['DropdownMenu'],
};

/// Track H2 clash convention (documented once, applied per screen):
/// * Kit-vs-Flutter clashes (`Tooltip`, `AlertDialog`, `Table`/`TableRow`/
///   `TableCell`, `Form`/`FormField`, `SelectableText`, `Scrollbar`, `Step`/
///   `Stepper`, `Scaffold`/`AppBar`, `Switch`, `Slider`, `Checkbox`,
///   `Divider`, `Badge`, `Card`, `DropdownMenu`, `TextField`): `hide` the
///   Flutter names on the screen's single Flutter import (see
///   [_screenFlutterHide]) — call sites stay bare (`Tooltip(`, `Table(`).
/// * Kit-vs-kit `MenuPopup`/`Menubar` (the `menu` barrel declares its own
///   alongside the `popup`/`menubar` barrels'): `hide` them on the `menu`
///   import — exactly the kit global barrel's own hide list — and import
///   the `popup` barrel for the catalog-mirroring `MenuPopup`.
/// * Kit-vs-kit tab family (the `tabs` barrel re-declares `TabItem`,
///   `TabList`, `TabPane`, … alongside their home barrels): import the
///   `tabs` barrel prefixed `as tabs` and qualify its two body names
///   (`tabs.Tabs(`, `tabs.TabItem(`) — the canvas catalog's own convention
///   (`component_catalog.dart` imports the same barrel `as tabs`).
/// Private-prefix imports (`as _tooltip`) are deliberately NOT used: a
/// leading-underscore prefix marks the import private to nowhere and reads
/// worse than either combinator above.
const _screenMenuHide = [
  'Menubar',
  'MenubarState',
  'MenubarTheme',
  'MenuPopup',
  'MenuPopupTheme',
];

/// Builds the clean-folders bundle for [doc].
BundleManifest buildCleanBundle(
  ScreenDoc doc,
  Map<String, String> sourcesByDestination,
) {
  final warnings = <String>[];
  final kinds = <String>[];
  void requireKind(String kind, String requiredBy) {
    if (kinds.contains(kind)) return;
    final spec = _kinds[kind];
    if (spec == null) {
      warnings.add("unknown component '$kind' required by $requiredBy: skipped");
      return;
    }
    kinds.add(kind);
    for (final dep in spec.dependsOn) {
      requireKind(dep, "'$kind'");
    }
  }

  for (final node in doc.nodes) {
    for (final item in node.items) {
      if (_kinds[item.kind] == null) {
        warnings.add("unknown kind '${item.kind}' (item ${item.id}): skipped");
      } else {
        requireKind(item.kind, 'canvas item ${item.id}');
      }
    }
  }
  // Track H2 screen-wiring closure: screens import the barrels in
  // [_screenExtraKinds] beyond the item kinds, so those barrels must ship
  // (requireKind pulls their dependsOn transitively, same policy as items).
  final screenExtraKinds = <String>{};
  for (final node in doc.nodes) {
    for (final item in node.items) {
      if (_kinds[item.kind] == null ||
          _bundlePlaceholderKinds.contains(item.kind)) {
        continue;
      }
      for (final extra in _screenExtraKinds[item.kind] ?? const <String>[]) {
        if (screenExtraKinds.add(extra)) {
          requireKind(extra, "screen wiring for '${item.kind}'");
        }
      }
    }
  }
  // Component bodies + manifest files[] (registry source -> resolved dest).
  final bodies = <String, String>{};
  final manifestFiles = <Map<String, String>>[];
  // Templates already emitted (seed for the closure fixpoint below).
  final emittedTemplates = <String>{};
  for (final kind in kinds) {
    final templates = sourcesByDestination.keys
        .where((k) => k.startsWith(_kinds[kind]!.prefix))
        .toList()
      ..sort();
    for (final template in templates) {
      final dest = _resolveDestination(template);
      if (bodies.containsKey(dest)) continue;
      bodies[dest] = sourcesByDestination[template]!;
      emittedTemplates.add(template);
      manifestFiles.add(
        {'source': _registrySource(template), 'destination': dest},
      );
    }
  }
  // Track H2 supplemental seed: the non-kind library files screens import
  // ([_screenExtraTemplates]) are not under any kind prefix, so the loop
  // above never emits them — seed them here (with manifest entries) when a
  // used catalog kind needs them. Missing templates (minimal test stubs)
  // are skipped silently; the relative-URI fixpoint below then pulls
  // whatever THEY relatively reference, exactly like kind bodies.
  final supplemental = <String>{};
  for (final node in doc.nodes) {
    for (final item in node.items) {
      final template = _screenExtraTemplates[item.kind];
      if (template != null &&
          kinds.contains(item.kind) &&
          supplemental.add(template)) {
        if (emittedTemplates.contains(template)) continue;
        final content = sourcesByDestination[template];
        if (content == null) continue;
        final dest = _resolveDestination(template);
        if (bodies.containsKey(dest)) continue;
        bodies[dest] = content;
        emittedTemplates.add(template);
        manifestFiles.add(
          {'source': _registrySource(template), 'destination': dest},
        );
      }
    }
  }
  // Track G2 closure fixpoint: every relative `import`/`export`/`part`/
  // `part of` URI in an emitted body resolves to another emitted file.
  // Rounds stay sorted so output is deterministic regardless of map order.
  var frontier = emittedTemplates.toList()..sort();
  while (frontier.isNotEmpty) {
    final discovered = <String>{};
    for (final template in frontier) {
      final content = sourcesByDestination[template]!;
      for (final match in _bundleDirectiveUri.allMatches(content)) {
        final target = _resolveBundleUri(template, match.group(1)!);
        if (target == null || emittedTemplates.contains(target)) continue;
        final targetContent = sourcesByDestination[target];
        if (targetContent == null) continue; // foreign/missing: never crash.
        discovered.add(target);
      }
    }
    frontier = discovered.toList()..sort();
    for (final template in frontier) {
      final dest = _resolveDestination(template);
      if (bodies.containsKey(dest)) continue;
      bodies[dest] = sourcesByDestination[template]!;
      emittedTemplates.add(template);
      manifestFiles.add(
        {'source': _registrySource(template), 'destination': dest},
      );
    }
  }
  manifestFiles.sort((a, b) => a['destination']!.compareTo(b['destination']!));
  // One minimal scaffold per screen (deduped snake names).
  final screenNames = <String>[];
  final usedPaths = <String>{};
  final screenFiles = <String, String>{};
  for (final screen in doc.screens) {
    var slug = _snakeName(screen.name);
    var path = _screenPath(slug);
    if (usedPaths.contains(path)) {
      var i = 2;
      while (usedPaths.contains(_screenPath('${slug}_$i'))) {
        i++;
      }
      slug = '${slug}_$i';
      path = _screenPath(slug);
    }
    usedPaths.add(path);
    screenNames.add(slug);
    screenFiles[path] = _screenFile(doc, screen, kinds);
  }
  final shared = <String>{
    for (final kind in kinds) ..._kinds[kind]!.shared,
  }.toList()
    ..sort();
  final deps = <String, String>{};
  for (final kind in kinds) {
    deps.addAll(_kinds[kind]!.pubspecDeps);
  }
  final depKeys = deps.keys.toList()..sort();
  final manifest = <String, dynamic>{
    'screens': screenNames,
    'namespace': 'shadcn',
    'root': _installRoot,
    'files': manifestFiles,
    'shared': shared,
    'pubspec': {'dependencies': {for (final k in depKeys) k: deps[k]}},
    'entry': doc.screens.isEmpty ? '' : screenFiles.keys.first,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
  final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest) + '\n';
  final patch = StringBuffer('# GENERATED by canvas bundle exporter — merge into pubspec.yaml.\ndependencies:\n');
  if (depKeys.isEmpty) {
    patch.write('  {}\n');
  } else {
    for (final k in depKeys) {
      patch.write('  $k: ${deps[k]}\n');
    }
  }

  final files = <String, String>{...screenFiles, ...bodies};
  return BundleManifest(
    manifestJson: manifestJson,
    files: files,
    pubspecPatch: patch.toString(),
    zipBytes: _zipBundle(files, manifestJson, patch.toString()),
  );
}

String _resolveDestination(String t) {
  if (t.startsWith(_installPath)) return '$_installRoot/${t.substring(_installPath.length)}';
  if (t.startsWith(_sharedPath)) return '$_sharedRoot/${t.substring(_sharedPath.length)}';
  return t;
}

/// Relative file directives inside an emitted body: `import`, `export`,
/// `part`, and URI-form `part of` (the kit uses no named `part of`), in
/// either quote style. Line-anchored so `//` comments never match; the
/// shipped corpus has no conditional, deferred, or multi-line directives.
final _bundleDirectiveUri = RegExp(
  r'''^\s*(?:import|export|part\s+of|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Resolves a relative directive [uri] found in [baseTemplate] to the
/// referenced source-map key, or `null` when it names no shipped file
/// (`dart:`/`package:` imports, absolute paths, `..` escapes above the
/// template root).
///
/// Both template roots are honored: segments resolve against a virtual root
/// where `{sharedPath}/…` sits at `{installPath}/shared/…` (exactly the
/// emitted `lib/ui/shadcn/shared/` layout), so component↔shared references
/// in either direction — and arbitrarily deep `_impl` nesting — land on the
/// same key no matter which side the reference starts from.
String? _resolveBundleUri(String baseTemplate, String uri) {
  if (uri.startsWith('dart:') ||
      uri.startsWith('package:') ||
      uri.startsWith('/')) {
    return null;
  }
  final prefixed = baseTemplate.startsWith(_installPath) ||
      baseTemplate.startsWith(_sharedPath);
  final List<String> segs = baseTemplate.startsWith(_installPath)
      ? baseTemplate.substring(_installPath.length).split('/')
      : baseTemplate.startsWith(_sharedPath)
          ? ['shared', ...baseTemplate.substring(_sharedPath.length).split('/')]
          : baseTemplate.split('/');
  var cur = segs.sublist(0, segs.length - 1);
  for (final part in uri.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (cur.isEmpty) return null;
      cur = cur.sublist(0, cur.length - 1);
    } else {
      cur = [...cur, part];
    }
  }
  if (!prefixed) return cur.join('/');
  if (cur.isNotEmpty && cur.first == 'shared') {
    return '$_sharedPath${cur.sublist(1).join('/')}';
  }
  return '$_installPath${cur.join('/')}';
}

String _registrySource(String t) {
  if (t.startsWith(_installPath)) return 'registry/${t.substring(_installPath.length)}';
  if (t.startsWith(_sharedPath)) return 'registry/shared/${t.substring(_sharedPath.length)}';
  return t;
}

List<int> _zipBundle(Map<String, String> files, String manifestJson, String pubspecPatch) {
  final archive = Archive();
  final names = [...files.keys, 'manifest.json', 'pubspec_patch.yaml']..sort();
  for (final name in names) {
    final content = name == 'manifest.json' ? manifestJson : name == 'pubspec_patch.yaml' ? pubspecPatch : files[name]!;
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

String _screenPath(String slug) => slug.endsWith('_screen')
    ? 'lib/ui/screens/$slug.dart'
    : 'lib/ui/screens/${slug}_screen.dart';

String _barrel(String kind) =>
    '$_installRoot/${_kinds[kind]!.prefix.substring(_installPath.length)}${_barrelFile[kind] ?? '$kind.dart'}';

/// Minimal screen scaffold: package imports plus real per-item bodies.
///
/// Known catalog kinds inline the widget expression mirroring the canvas
/// app's `component_catalog.dart` builder for that kind (same props, same
/// defaults, same edge handling — statically snapshotted, see the library
/// docs); non-catalog kinds keep the doc comment plus a `Text` placeholder.
/// Component bodies ALSO ship under `lib/ui/shadcn/` (barrel paths listed in
/// the header for wiring).
///
/// Vanilla `StatefulWidget` with no store dependency (see the library docs):
/// per-node responsive rides the `codegen_single.dart` tier-conditional
/// idiom, and items with tap actions navigate with `Navigator.pushNamed`.
String _screenFile(ScreenDoc doc, CanvasScreen screen, List<String> kinds) {
  final routes = {for (final s in doc.screens) s.id: _routeOf(s.name)};
  final ids = {for (final s in doc.screens) s.id};
  final nodes = [
    for (final n in doc.nodes)
      if (n.screenId == screen.id) n,
  ]..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });
  final usedKinds = {
    for (final n in nodes)
      for (final i in n.items)
        if (kinds.contains(i.kind)) i.kind,
  }.toList()
    ..sort();
  final rows = <String>[];
  for (final node in nodes) {
    _writeBundleNode(rows, node, routes, ids, '      ');
  }
  if (rows.isEmpty) rows.add('      // (empty screen).');
  final barrels = usedKinds.isEmpty ? '// (no known components on this screen).' : [for (final k in usedKinds) '// - $k -> ${_barrel(k)}'].join('\n');
  final cls = _pascalName(screen.name);
  // Flutter import surface for this screen (kind-based, deterministic):
  // material (a widgets superset) when any item needs material-only APIs,
  // plus services for keyboard-shortcut keys. Docs without new bodies keep
  // the exact old header (widgets only, no extras) byte-identical.
  final screenKinds = {
    for (final n in nodes)
      for (final i in n.items) i.kind,
  };
  final needsMaterial =
      screenKinds.any(_bundleNeedsMaterial.contains);
  final needsServices = screenKinds.contains('keyboard_shortcut');
  final needsValidator = screenKinds.contains('validated');
  final flutterImport = needsMaterial ? _flutterMaterial : _flutterWidgets;
  // Track H2 barrel imports: one relative import per used catalog kind
  // (plus [_screenExtraKinds] extras and [_screenExtraTemplates] files),
  // resolved via [_barrelFile] — the same entry files the header comments
  // list. Clash disambiguation follows the convention documented above
  // [_screenMenuHide]: Flutter names hide on the Flutter import, `menu`
  // hides its shadowed names, `tabs` imports prefixed. Placeholder kinds
  // reference no kit names, so they contribute no imports (their header
  // comment still documents the shipped barrel for hand wiring).
  final catalogUsed = {
    for (final k in usedKinds)
      if (!_bundlePlaceholderKinds.contains(k)) k,
  };
  final importKinds = {
    ...catalogUsed,
    for (final k in catalogUsed) ...(_screenExtraKinds[k] ?? const <String>[]),
  }.toList()
    ..sort();
  final importFiles = {
    for (final k in catalogUsed)
      if (_screenExtraTemplates[k] != null)
        _screenExtraDest(_screenExtraTemplates[k]!),
  }.toList()
    ..sort();
  final hideNames = {
    for (final k in importKinds)
      ...(_screenFlutterHideWidgets[k] ?? const <String>[]),
    if (needsMaterial)
      for (final k in importKinds)
        ...(_screenFlutterHideMaterial[k] ?? const <String>[]),
    // The supplemental text-field file declares material's `TextField`
    // (hidden only on material screens — widgets exports no such name and
    // hiding it there would warn).
    if (needsMaterial &&
        importFiles.any((f) => f.endsWith('/text_field/text_field.dart')))
      'TextField',
  }.toList()
    ..sort();
  final flutterLine = hideNames.isEmpty
      ? "import '$flutterImport';"
      : "import '$flutterImport' hide ${hideNames.join(', ')};";
  final kitImports = StringBuffer();
  for (final k in importKinds) {
    final uri = '../${_barrel(k).substring('lib/ui/'.length)}';
    if (k == 'tabs') {
      kitImports.writeln("import '$uri' as tabs;");
    } else if (k == 'menu') {
      kitImports.writeln("import '$uri' hide ${_screenMenuHide.join(', ')};");
    } else {
      kitImports.writeln("import '$uri';");
    }
  }
  for (final f in importFiles) {
    kitImports.writeln("import '../${f.substring('lib/ui/'.length)}';");
  }
  final extraImports = StringBuffer();
  if (needsServices) extraImports.writeln("import '$_flutterServices';");
  if (needsValidator) extraImports.writeln("import '$_dartAsync';");
  final extraNote = [
    if (needsServices) '`package:flutter/services.dart` for keyboard shortcuts',
    if (needsValidator) '`dart:async` for form validators',
  ].join(' and ');
  // Extra barrel imports are kind-based, not prop-based (a `card` screen
  // imports the button barrel even with the footer off): hand-edits that
  // flip such props never need new imports. The provably-unused remainder
  // is an info-level lint, silenced file-wide like the kit's own barrels.
  final ignoreLine =
      kitImports.isEmpty ? '' : '// ignore_for_file: unused_import\n';
  return '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
$ignoreLine// Screen: ${screen.name} (id: ${screen.id}). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
$barrels
$flutterLine
${extraImports}${kitImports}
/// ${screen.name} screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `$flutterImport`
/// plus the shipped kit bodies.${extraNote.isEmpty ? '' : '\n/// (plus $extraNote — Flutter SDK libraries, no extra packages).'}
class ${cls}Screen extends StatefulWidget {
  const ${cls}Screen({super.key});

  @override
  State<${cls}Screen> createState() => _${cls}ScreenState();
}

class _${cls}ScreenState extends State<${cls}Screen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
${rows.join('\n')}
      ],
    );
  }
}
${needsValidator ? '\n$_bundleValidatorHelper' : ''}''';
}

/// Per-file required-field validator emitted when a screen uses `validated`.
///
/// Mirrors the canvas catalog's `_CanvasRequiredValidator`: the kit's
/// `NotEmptyValidator` reads its message from `ShadcnLocalizations` at
/// attach time (null without delegates), so exported screens carry this tiny
/// localization-free validator instead (same required-field semantics, the
/// message rides the canvas-level `errorText` prop).
const String _bundleValidatorHelper = '''
/// Localization-free required-field validator for [Validated] fields.
class _CanvasRequiredValidator extends Validator<String> {
  final String message;

  const _CanvasRequiredValidator([this.message = 'Required']);

  @override
  FutureOr<ValidationResult?> validate(
    BuildContext context,
    String? value,
    FormValidationMode lifecycle,
  ) {
    if (value == null || value.isEmpty) {
      return InvalidResult(message, state: lifecycle);
    }
    return null;
  }
}
''';

/// Whether [node] needs a responsive wrapper: the same rule as
/// `codegen_single.dart` — a known `hiddenOn` tier or a known-tier
/// `breakpointValues` entry. Unknown tiers are inert, so docs without
/// responsive fields keep byte-identical output.
bool _isBundleResponsive(CanvasNode node) =>
    _bundleHiddenTiers(node).isNotEmpty || _bundleOverrideTiers(node).isNotEmpty;

/// Known `hiddenOn` tiers, sorted (deterministic conditions/comments).
List<String> _bundleHiddenTiers(CanvasNode node) =>
    (node.hiddenOn.where(kResponsiveTiers.contains).toList()..sort());

/// Known `breakpointValues` tiers, sorted (deterministic branch order).
List<String> _bundleOverrideTiers(CanvasNode node) =>
    (node.breakpointValues.keys.where(kResponsiveTiers.contains).toList()
      ..sort());

/// One-line `// kind 'label' (...)` doc comment for [item], naming the tap
/// target route (or the unknown-target fallback) when it has an action.
String _bundleItemComment(
  CanvasItem item,
  Map<String, String> routes,
  Set<String> ids,
) {
  final detail = _detailOf(item);
  final head =
      "// ${item.kind} '${_labelOf(item)}'${detail.isEmpty ? '' : ' ($detail)'}";
  final action = item.action;
  if (action == null) return '$head.';
  final route = ids.contains(action.to) ? routes[action.to] : null;
  if (route == null) return "$head — unknown target '${action.to}': no navigation.";
  return '$head — pushes $route (transition: ${action.transition}).';
}

/// Widget expression lines for [item] (unindented, trailing comma on the
/// last line): the real catalog-mirroring body from [_bundleBody], wrapped
/// in a `GestureDetector` pushing the route by name when the item's action
/// targets a known screen (the transition rides along as a comment —
/// `pushNamed` carries no transition); unknown `to` ids and action-less
/// items render the bare body, never a crash.
List<String> _bundleItemExpr(
  CanvasItem item,
  Map<String, String> routes,
  Set<String> ids,
) {
  final body = _bundleBody(item);
  final action = item.action;
  if (action == null) return body;
  final route = ids.contains(action.to) ? routes[action.to] : null;
  if (route == null) return body;
  return [
    'GestureDetector(',
    "  onTap: () => Navigator.of(context).pushNamed('$route'), // transition: ${action.transition}",
    '  child: ${body.first}',
    for (final line in body.skip(1)) '  $line',
    '),',
  ];
}

/// Real per-item body (unindented lines, trailing comma on the last line).
///
/// One case per catalog kind, mirroring the canvas app's
/// `component_catalog.dart` builder for that kind prop-for-prop with the
/// same defaults and edge handling — statically snapshotted for export:
/// stateful cells (switch, checkbox, tabs, select, radio, slider, star
/// rating, pagination, tab controllers, pickers, sliders) render their
/// initial value with a no-op callback (the `codegen_single.dart` honesty
/// rule); overlay-driven kinds render their inline static form exactly like
/// the catalog does. Props read leniently (missing/wrong-typed values fall
/// back to the catalog default) so hand-written docs never crash the
/// exporter. Non-catalog kinds keep the old `Text` placeholder byte-identical.
List<String> _bundleBody(CanvasItem item) {
  switch (item.kind) {
    case 'button':
      return _bundleButton(item.props);
    case 'card':
      return _bundleCard(item.props);
    case 'input':
      return _bundleInput(item.props);
    case 'badge':
      return _bundleBadge(item.props);
    case 'switch':
      return _bundleSwitch(item.props);
    case 'avatar':
      return _bundleAvatar(item.props);
    case 'checkbox':
      return _bundleCheckbox(item.props);
    case 'divider':
      return _bundleDivider(item.props);
    case 'progress':
      return _bundleProgress(item.props);
    case 'tabs':
      return _bundleTabs(item.props);
    case 'accordion':
      return _bundleAccordion(item.props);
    case 'select':
      return _bundleSelect(item.props);
    case 'radio_group':
      return _bundleRadioGroup(item.props);
    case 'skeleton':
      return _bundleSkeleton(item.props);
    case 'breadcrumb':
      return _bundleBreadcrumb(item.props);
    case 'dialog':
      return _bundleDialog(item.props);
    case 'tooltip':
      return _bundleTooltip(item.props);
    case 'toast':
      return _bundleToast(item.props);
    case 'drawer':
      return _bundleDrawer(item.props);
    case 'basic':
      return _bundleBasic(item.props);
    case 'card_image':
      return _bundleCardImage(item.props);
    case 'scaffold':
      return _bundleScaffold(item.props);
    case 'collapsible':
      return _bundleCollapsible(item.props);
    case 'steps':
      return _bundleSteps(item.props);
    case 'timeline':
      return _bundleTimeline(item.props);
    case 'outlined_container':
      return _bundleOutlinedContainer(item.props);
    case 'hidden':
      return _bundleHidden(item.props);
    case 'keyboard_shortcut':
      return _bundleKeyboardShortcut(item.props);
    case 'tracker':
      return _bundleTracker(item.props);
    case 'chat':
      return _bundleChat(item.props);
    case 'selectable':
      return _bundleSelectable(item.props);
    case 'star_rating':
      return _bundleStarRating(item.props);
    case 'clickable':
      return _bundleClickable(item.props);
    case 'scrollbar':
      return _bundleScrollbar(item.props);
    case 'pagination':
      return _bundlePagination(item.props);
    case 'alert_dialog':
      return _bundleAlertDialog(item.props);
    case 'menu':
      return _bundleMenu(item.props);
    case 'popover':
      return _bundlePopover(item.props);
    case 'popup':
      return _bundlePopup(item.props);
    case 'menubar':
      return _bundleMenubar(item.props);
    case 'dropdown_menu':
      return _bundleDropdownMenu(item.props);
    case 'context_menu':
      return _bundleContextMenu(item.props);
    case 'hover_card':
      return _bundleHoverCard(item.props);
    case 'command':
      return _bundleCommand(item.props);
    case 'swiper':
      return _bundleSwiper(item.props);
    case 'refresh_trigger':
      return _bundleRefreshTrigger(item.props);
    case 'tab_container':
      return _bundleTabContainer(item.props);
    case 'tab_list':
      return _bundleTabList(item.props);
    case 'tab_pane':
      return _bundleTabPane(item.props);
    case 'stepper':
      return _bundleStepper(item.props);
    case 'slider':
      return _bundleSlider(item.props);
    case 'input_otp':
      return _bundleInputOtp(item.props);
    case 'calendar':
      return _bundleCalendar(item.props);
    case 'date_picker':
      return _bundleDatePicker(item.props);
    case 'time_picker':
      return _bundleTimePicker(item.props);
    case 'carousel':
      return _bundleCarousel(item.props);
    case 'tree':
      return _bundleTree(item.props);
    case 'table':
      return _bundleTable(item.props);
    case 'form':
      return _bundleForm(item.props);
    case 'form_field':
      return _bundleFormField(item.props);
    case 'formatted_input':
      return _bundleFormattedInput(item.props);
    case 'validated':
      return _bundleValidated(item.props);
    case 'color_picker':
      return _bundleColorPicker(item.props);
    case 'color_input':
      return _bundleColorInput(item.props);
    case 'hsl':
      return _bundleHsl(item.props);
    case 'hsv':
      return _bundleHsv(item.props);
    case 'history':
      return _bundleHistory(item.props);
    case 'feature_carousel':
      return _bundleFeatureCarousel(item.props);
    default:
      return ["Text(${_bundleStr(_labelOf(item))}),"];
  }
}

/// Lenient string prop: missing/non-string values fall back (never crash).
String _bStr(Map<String, dynamic> props, String key, String fallback) {
  final value = props[key];
  return value is String ? value : fallback;
}

/// Lenient bool prop: missing/non-bool values fall back (never crash).
bool _bBool(Map<String, dynamic> props, String key, bool fallback) {
  final value = props[key];
  return value is bool ? value : fallback;
}

/// Lenient clamped double prop (parsed via `num`: `jsonDecode` yields `int`
/// for whole numbers). Mirrors the catalog's clamp-into-domain edge handling.
double _bDouble(
  Map<String, dynamic> props,
  String key,
  double fallback,
  double min,
  double max,
) {
  final value = props[key];
  final parsed = value is num ? value.toDouble() : fallback;
  return parsed.clamp(min, max).toDouble();
}

/// Lenient clamped int prop (parsed via `num`, same `jsonDecode` trap).
int _bInt(
  Map<String, dynamic> props,
  String key,
  int fallback,
  int min,
  int max,
) {
  final value = props[key];
  final parsed = value is num ? value.toInt() : fallback;
  return parsed.clamp(min, max);
}

/// Empty canvas-level strings map to a null literal so optional slots
/// collapse instead of rendering empty gaps (mirrors the catalog's
/// `_textOrNull` convention).
String _bTextOrNull(String value) =>
    value.isEmpty ? 'null' : 'Text(${_bundleStr(value)})';

List<String> _bundleButton(Map<String, dynamic> props) {
  final constructor = switch (props['variant']) {
    'secondary' => 'SecondaryButton',
    'outline' => 'OutlineButton',
    'ghost' => 'GhostButton',
    'destructive' => 'DestructiveButton',
    'link' => 'LinkButton',
    // The button canvas block's variant enum omits `text`, but the kit's
    // `TextButton` exists and the catalog supports it — mirrored here.
    'text' => 'TextButton',
    _ => 'PrimaryButton',
  };
  final size = switch (props['size']) {
    'sm' => 'ButtonSize.small',
    'lg' => 'ButtonSize.large',
    // 'md' (default) and anything unknown (incl. the block's `icon`, which
    // has no `ButtonSize` member) fall back to normal.
    _ => 'ButtonSize.normal',
  };
  return [
    '$constructor(',
    '  onPressed: () {},',
    '  enabled: ${!_bBool(props, 'disabled', false)},',
    '  size: $size,',
    "  child: Text(${_bundleStr(_bStr(props, 'label', 'Button'))}),",
    '),',
  ];
}

List<String> _bundleCard(Map<String, dynamic> props) {
  final footer = _bBool(props, 'showFooter', false)
      ? [
          '      const SizedBox(height: 12),',
          '      PrimaryButton(',
          '        size: ButtonSize.small,',
          '        onPressed: () {},',
          "        child: Text('Action'),",
          '      ),',
        ]
      : <String>[];
  return [
    'Card(',
    '  padding: const EdgeInsets.all(16),',
    '  child: Column(',
    '    mainAxisSize: MainAxisSize.min,',
    '    crossAxisAlignment: CrossAxisAlignment.start,',
    '    children: [',
    "      Text(${_bundleStr(_bStr(props, 'title', 'Title'))}),",
    '      const SizedBox(height: 4),',
    "      Text(${_bundleStr(_bStr(props, 'description', 'Description'))}),",
    ...footer,
    '    ],',
    '  ),',
    '),',
  ];
}

List<String> _bundleInput(Map<String, dynamic> props) {
  final initialValue = _bStr(props, 'initialValue', '');
  final field = [
    'TextField(',
    "  placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Type here'))}),",
    '  enabled: ${!_bBool(props, 'disabled', false)},',
    '  obscureText: ${_bBool(props, 'obscure', false)},',
    '  initialValue: ${initialValue.isEmpty ? 'null' : _bundleStr(initialValue)},',
    '  readOnly: ${_bBool(props, 'readOnly', false)},',
    '),',
  ];
  final label = _bStr(props, 'label', '');
  if (label.isEmpty) return field;
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    Text(${_bundleStr(label)}),',
    '    const SizedBox(height: 6),',
    '    ${field.first}',
    ...field.skip(1).map((line) => '    $line'),
    '  ],',
    '),',
  ];
}

List<String> _bundleBadge(Map<String, dynamic> props) {
  final constructor = switch (props['variant']) {
    'secondary' => 'SecondaryBadge',
    'destructive' => 'DestructiveBadge',
    'outline' => 'OutlineBadge',
    _ => 'PrimaryBadge',
  };
  return [
    "$constructor(child: Text(${_bundleStr(_bStr(props, 'label', 'Badge'))})),",
  ];
}

List<String> _bundleSwitch(Map<String, dynamic> props) {
  // Static snapshot of the catalog's toggle cell: fixed value, no-op
  // callback (null renders the disabled state, same as the cell).
  final onChanged = _bBool(props, 'disabled', false) ? 'null' : '(v) {}';
  return [
    "Switch(value: ${_bBool(props, 'value', false)}, onChanged: $onChanged),",
  ];
}

List<String> _bundleAvatar(Map<String, dynamic> props) {
  final size = _bDouble(props, 'size', 40.0, 16.0, 96.0);
  return [
    "Avatar(initials: ${_bundleStr(_bStr(props, 'initials', 'AB'))}, size: $size),",
  ];
}

List<String> _bundleCheckbox(Map<String, dynamic> props) {
  final state = _bBool(props, 'value', false)
      ? 'CheckboxState.checked'
      : 'CheckboxState.unchecked';
  final onChanged = _bBool(props, 'disabled', false) ? 'null' : '(s) {}';
  return [
    'Checkbox(',
    '  state: $state,',
    '  tristate: ${_bBool(props, 'tristate', false)},',
    '  onChanged: $onChanged,',
    '),',
  ];
}

List<String> _bundleDivider(Map<String, dynamic> props) {
  final thickness = _bDouble(props, 'thickness', 1.0, 1.0, 8.0);
  final label = _bStr(props, 'label', '');
  // Static snapshot of the catalog's narrow-safe label shell: the empty
  // branch is chosen at export time (the runtime `if` condition is statically
  // known), so bare and labeled dividers emit their exact catalog form.
  if (label.isEmpty) return ['Divider(thickness: $thickness),'];
  return [
    'LayoutBuilder(',
    '  builder: (context, constraints) {',
    '    final max = constraints.maxWidth;',
    '    final available = max.isFinite ? max : (MediaQuery.maybeSizeOf(context)?.width ?? 320.0);',
    '    return Divider(',
    '      thickness: $thickness,',
    '      child: ConstrainedBox(',
    '        constraints: BoxConstraints(maxWidth: available * 0.6),',
    '        child: Text(',
    '          ${_bundleStr(label)},',
    '          maxLines: 1,',
    '          overflow: TextOverflow.ellipsis,',
    '        ),',
    '      ),',
    '    );',
    '  },',
    '),',
  ];
}

List<String> _bundleProgress(Map<String, dynamic> props) {
  final value = _bDouble(props, 'progress', 0.5, 0.0, 1.0);
  return ['Progress(progress: $value),'];
}

List<String> _bundleTabs(Map<String, dynamic> props) {
  final index = _bInt(props, 'index', 0, 0, 1);
  // Track H2: the `tabs` barrel imports prefixed (`as tabs` — it re-declares
  // the tab-family names alongside their home barrels), so its names qualify.
  return [
    'tabs.Tabs(',
    '  index: $index,',
    '  expand: ${_bBool(props, 'expand', false)},',
    '  onChanged: (_) {},',
    '  children: [',
    "    tabs.TabItem(child: Text(${_bundleStr(_bStr(props, 'tab1', 'Tab 1'))})),",
    "    tabs.TabItem(child: Text(${_bundleStr(_bStr(props, 'tab2', 'Tab 2'))})),",
    '  ],',
    '),',
  ];
}

List<String> _bundleAccordion(Map<String, dynamic> props) {
  return [
    'Accordion(',
    '  items: [',
    '    AccordionItem(',
    "      trigger: AccordionTrigger(child: Text(${_bundleStr(_bStr(props, 'title', 'Section 1'))})),",
    "      content: Text(${_bundleStr(_bStr(props, 'content', 'Content 1'))}),",
    '      expanded: ${_bBool(props, 'expanded', false)},',
    '    ),',
    '  ],',
    '),',
  ];
}

List<String> _bundleSelect(Map<String, dynamic> props) {
  final first = _bStr(props, 'option1', 'Option 1');
  final second = _bStr(props, 'option2', 'Option 2');
  // Mirrors the catalog cell: empty/absent-from-options renders unselected
  // (placeholder) instead of crashing.
  final raw = _bStr(props, 'value', '');
  final value =
      raw.isEmpty || (raw != first && raw != second) ? 'null' : _bundleStr(raw);
  final disabled = _bBool(props, 'disabled', false);
  return [
    'Select<String>(',
    '  value: $value,',
    "  placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Select an option'))}),",
    '  itemBuilder: (context, item) => Text(item),',
    '  enabled: ${!disabled},',
    '  onChanged: ${disabled ? 'null' : '(_) {}'},',
    '  popup: SelectPopup(',
    '    items: SelectItemList(',
    '      children: [',
    '        SelectItemButton(value: ${_bundleStr(first)}, child: Text(${_bundleStr(first)})),',
    '        SelectItemButton(value: ${_bundleStr(second)}, child: Text(${_bundleStr(second)})),',
    '      ],',
    '    ),',
    '  ).call,',
    '),',
  ];
}

List<String> _bundleRadioGroup(Map<String, dynamic> props) {
  final first = _bStr(props, 'option1', 'Option 1');
  final second = _bStr(props, 'option2', 'Option 2');
  // Mirrors the catalog cell: empty renders unselected (no
  // options-membership check, exactly like the catalog).
  final raw = _bStr(props, 'value', 'Option 1');
  final value = raw.isEmpty ? 'null' : _bundleStr(raw);
  final disabled = _bBool(props, 'disabled', false);
  List<String> option(String option) => [
        '      RadioItem<String>(',
        '        value: ${_bundleStr(option)},',
        '        leading: Flexible(',
        '          child: Text(',
        '            ${_bundleStr(option)},',
        '            maxLines: 1,',
        '            overflow: TextOverflow.ellipsis,',
        '          ),',
        '        ),',
        '      ),',
      ];
  return [
    'RadioGroup<String>(',
    '  value: $value,',
    '  enabled: ${!disabled},',
    '  onChanged: ${disabled ? 'null' : '(_) {}'},',
    '  child: Column(',
    '    mainAxisSize: MainAxisSize.min,',
    '    children: [',
    ...option(first),
    '      const SizedBox(height: 8),',
    ...option(second),
    '    ],',
    '  ),',
    '),',
  ];
}

List<String> _bundleSkeleton(Map<String, dynamic> props) {
  return [
    "Text(${_bundleStr(_bStr(props, 'label', 'Loading'))}).asSkeleton(enabled: ${_bBool(props, 'enabled', true)}),",
  ];
}

List<String> _bundleBreadcrumb(Map<String, dynamic> props) {
  final separator = props['separator'] == 'slash'
      ? 'Breadcrumb.slashSeparator'
      : 'Breadcrumb.arrowSeparator';
  return [
    'Breadcrumb(',
    '  separator: $separator,',
    '  children: [',
    "    Text(${_bundleStr(_bStr(props, 'home', 'Home'))}),",
    "    Text(${_bundleStr(_bStr(props, 'current', 'Page'))}),",
    '  ],',
    '),',
  ];
}

List<String> _bundleDialog(Map<String, dynamic> props) {
  final actions = _bBool(props, 'showActions', true)
      ? [
          '      const SizedBox(height: 20),',
          '      Row(',
          '        children: [',
          '          const Spacer(),',
          '          OutlineButton(',
          '            onPressed: () {},',
          "            child: const Text('Close'),",
          '          ),',
          '        ],',
          '      ),',
        ]
      : <String>[];
  return [
    'ModalContainer(',
    '  filled: true,',
    '  padding: const EdgeInsets.all(24),',
    '  child: Column(',
    '    mainAxisSize: MainAxisSize.min,',
    '    crossAxisAlignment: CrossAxisAlignment.start,',
    '    children: [',
    "      Text(${_bundleStr(_bStr(props, 'title', 'Dialog title'))}),",
    '      const SizedBox(height: 12),',
    "      Text(${_bundleStr(_bStr(props, 'message', 'Use dialogs for important confirmations.'))}),",
    ...actions,
    '    ],',
    '  ),',
    '),',
  ];
}

List<String> _bundleTooltip(Map<String, dynamic> props) {
  // NOTE: `Tooltip` also exists in `package:flutter/widgets.dart` — when
  // wiring the shipped tooltip barrel alongside it, disambiguate (prefix or
  // hide), the same trap documented in `component_catalog.dart`.
  return [
    'Tooltip(',
    "  tooltip: (context) => TooltipContainer(child: Text(${_bundleStr(_bStr(props, 'tip', 'Helpful context'))})),",
    "  child: OutlineButton(onPressed: () {}, child: Text(${_bundleStr(_bStr(props, 'label', 'Hover me'))})),",
    '),',
  ];
}

List<String> _bundleToast(Map<String, dynamic> props) {
  return [
    'ToastEntry(',
    '  duration: const Duration(seconds: 3),',
    '  animationDuration: const Duration(milliseconds: 200),',
    '  animationCurve: Curves.easeOut,',
    '  onDismissed: () {},',
    '  autoDismiss: ${_bBool(props, 'autoDismiss', false)},',
    '  child: Row(',
    '    mainAxisSize: MainAxisSize.min,',
    '    children: [',
    '      const Icon(Icons.check_circle, size: 20),',
    '      const SizedBox(width: 8),',
    '      Column(',
    '        mainAxisSize: MainAxisSize.min,',
    '        crossAxisAlignment: CrossAxisAlignment.start,',
    '        children: [',
    "          Text(${_bundleStr(_bStr(props, 'title', 'Saved'))}),",
    "          Text(${_bundleStr(_bStr(props, 'message', 'Saved successfully'))}),",
    '        ],',
    '      ),',
    '    ],',
    '  ),',
    '),',
  ];
}

List<String> _bundleDrawer(Map<String, dynamic> props) {
  final position = switch (props['position']) {
    'left' => 'OverlayPosition.left',
    'right' => 'OverlayPosition.right',
    'top' => 'OverlayPosition.top',
    'bottom' => 'OverlayPosition.bottom',
    'start' => 'OverlayPosition.start',
    _ => 'OverlayPosition.end',
  };
  return [
    'DrawerWrapper(',
    '  position: $position,',
    '  size: const Size(240, 480),',
    '  stackIndex: 0,',
    '  draggable: false,',
    '  showDragHandle: false,',
    '  child: SizedBox(',
    '    width: 240,',
    '    child: Column(',
    '      mainAxisSize: MainAxisSize.min,',
    '      crossAxisAlignment: CrossAxisAlignment.start,',
    '      children: [',
    "        Text(${_bundleStr(_bStr(props, 'title', 'Drawer'))}),",
    '        const SizedBox(height: 16),',
    "        Text(${_bundleStr(_bStr(props, 'content', 'Drawer content'))}),",
    '      ],',
    '    ),',
    '  ),',
    '),',
  ];
}

/// Parses a canvas-level shortcut string (`'Ctrl+K'`, `'Shift+Alt+S'`) into
/// emitted [LogicalKeyboardKey] constant names. Mirrors the catalog's
/// `_parseShortcutKeys`/`_shortcutToken`: unknown tokens are skipped, and a
/// fully-unknown string falls back to `keyK` instead of crashing.
List<String> _bundleShortcutKeys(String raw) {
  final keys = <String>[];
  for (final token in raw.split(RegExp(r'[+\s]+'))) {
    final key = _bundleShortcutToken(token);
    if (key != null) keys.add(key);
  }
  return keys.isEmpty ? ['LogicalKeyboardKey.keyK'] : keys;
}

String? _bundleShortcutToken(String token) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return null;
  switch (t) {
    case 'ctrl':
    case 'control':
      return 'LogicalKeyboardKey.controlLeft';
    case 'shift':
      return 'LogicalKeyboardKey.shiftLeft';
    case 'alt':
    case 'option':
      return 'LogicalKeyboardKey.altLeft';
    case 'meta':
    case 'cmd':
    case 'command':
    case 'win':
      return 'LogicalKeyboardKey.metaLeft';
    case 'enter':
    case 'return':
      return 'LogicalKeyboardKey.enter';
    case 'space':
      return 'LogicalKeyboardKey.space';
    case 'tab':
      return 'LogicalKeyboardKey.tab';
    case 'esc':
    case 'escape':
      return 'LogicalKeyboardKey.escape';
    case 'backspace':
      return 'LogicalKeyboardKey.backspace';
    case 'delete':
    case 'del':
      return 'LogicalKeyboardKey.delete';
  }
  if (t.length == 1) {
    final c = t.codeUnitAt(0);
    if (c >= 97 && c <= 122) {
      return 'LogicalKeyboardKey.key${t.toUpperCase()}';
    }
    if (c >= 48 && c <= 57) return 'LogicalKeyboardKey.digit$t';
  }
  return null;
}

List<String> _bundleBasic(Map<String, dynamic> props) {
  final leading = _bBool(props, 'showLeading', true)
      ? 'const Icon(Icons.person)'
      : 'null';
  final trailing = _bBool(props, 'showTrailing', true)
      ? 'const Icon(Icons.chevron_right)'
      : 'null';
  return [
    'Basic(',
    '  leading: $leading,',
    "  title: ${_bTextOrNull(_bStr(props, 'title', 'Title'))},",
    "  subtitle: ${_bTextOrNull(_bStr(props, 'subtitle', 'Subtitle'))},",
    "  content: ${_bTextOrNull(_bStr(props, 'content', 'Content'))},",
    '  trailing: $trailing,',
    '),',
  ];
}

List<String> _bundleCardImage(Map<String, dynamic> props) {
  // Deviation (documented): the catalog's `image` slot is theme-token art
  // (`Theme` + `Icons`) via a helper widget class. Emitted screens stay
  // widgets+kit only with no helper classes, so the art is a static tonal
  // box with a text label — same fixed-height shell, same title/subtitle
  // props.
  return [
    'SizedBox(',
    '  height: 240,',
    '  child: CardImage(',
    '    image: Container(',
    '      height: 120,',
    '      color: const Color(0xFFE8EAED),',
    "      child: Center(child: Text('Image')),",
    '    ),',
    "    title: ${_bTextOrNull(_bStr(props, 'title', 'Card title'))},",
    "    subtitle: ${_bTextOrNull(_bStr(props, 'subtitle', 'Card subtitle'))},",
    '  ),',
    '),',
  ];
}

List<String> _bundleScaffold(Map<String, dynamic> props) {
  return [
    'SizedBox(',
    '  height: 320,',
    '  child: Scaffold(',
    "    headers: [AppBar(title: Text(${_bundleStr(_bStr(props, 'title', 'My App'))}))],",
    '    child: Padding(',
    '      padding: const EdgeInsets.all(16),',
    "      child: Text(${_bundleStr(_bStr(props, 'body', 'Welcome'))}),",
    '    ),',
    '  ),',
    '),',
  ];
}

List<String> _bundleCollapsible(Map<String, dynamic> props) {
  return [
    'Collapsible(',
    '  isExpanded: ${_bBool(props, 'expanded', false)},',
    '  children: [',
    "    CollapsibleTrigger(child: Text(${_bundleStr(_bStr(props, 'trigger', 'Show more'))})),",
    "    CollapsibleContent(child: Text(${_bundleStr(_bStr(props, 'content', 'Hidden details'))})),",
    '  ],',
    '),',
  ];
}

List<String> _bundleSteps(Map<String, dynamic> props) {
  List<String> step(String title, String detail) => [
        '    StepItem(',
        '      title: Text(${_bundleStr(title)}),',
        '      content: [Text(${_bundleStr(detail)})],',
        '    ),',
      ];
  return [
    'Steps(',
    '  children: [',
    ...step(
      _bStr(props, 'step1', 'Step 1'),
      _bStr(props, 'detail1', 'First step details'),
    ),
    ...step(
      _bStr(props, 'step2', 'Step 2'),
      _bStr(props, 'detail2', 'Second step details'),
    ),
    '  ],',
    '),',
  ];
}

List<String> _bundleTimeline(Map<String, dynamic> props) {
  List<String> entry(String time, String title, String detail) => [
        '    TimelineData(',
        '      time: Text(${_bundleStr(time)}),',
        '      title: Text(${_bundleStr(title)}),',
        '      content: ${_bTextOrNull(detail)},',
        '    ),',
      ];
  return [
    'Timeline(',
    '  data: [',
    ...entry(
      _bStr(props, 'time1', '9:00 AM'),
      _bStr(props, 'title1', 'Kickoff'),
      _bStr(props, 'detail1', 'Project kickoff meeting'),
    ),
    ...entry(
      _bStr(props, 'time2', '2:00 PM'),
      _bStr(props, 'title2', 'Review'),
      _bStr(props, 'detail2', 'Design review session'),
    ),
    '  ],',
    '),',
  ];
}

List<String> _bundleOutlinedContainer(Map<String, dynamic> props) {
  return [
    'OutlinedContainer(',
    '  child: Padding(',
    '    padding: const EdgeInsets.all(12),',
    "    child: Text(${_bundleStr(_bStr(props, 'label', 'Outlined'))}),",
    '  ),',
    '),',
  ];
}

List<String> _bundleHidden(Map<String, dynamic> props) {
  return [
    "Hidden(hidden: ${_bBool(props, 'hidden', false)}, child: Text(${_bundleStr(_bStr(props, 'label', 'Hidden content'))})),",
  ];
}

List<String> _bundleKeyboardShortcut(Map<String, dynamic> props) {
  // The keys string parses at export time into `LogicalKeyboardKey`
  // constants (mirroring the catalog parser); the screen gains a
  // `package:flutter/services.dart` import for them.
  final keys =
      _bundleShortcutKeys(_bStr(props, 'keys', 'Ctrl+K')).join(', ');
  return [
    'KeyboardShortcutDisplayMapper(',
    '  child: KeyboardDisplay(keys: [$keys]),',
    '),',
  ];
}

List<String> _bundleTracker(Map<String, dynamic> props) {
  final segments = _bInt(props, 'segments', 3, 1, 5);
  final level = switch (props['level']) {
    'warning' => 'TrackerLevel.warning',
    'critical' => 'TrackerLevel.critical',
    'unknown' => 'TrackerLevel.unknown',
    _ => 'TrackerLevel.fine',
  };
  return [
    'Tracker(',
    '  data: [',
    for (var i = 0; i < segments; i++)
      "    TrackerData(tooltip: Text('Segment ${i + 1}'), level: $level),",
    '  ],',
    '),',
  ];
}

List<String> _bundleChat(Map<String, dynamic> props) {
  return [
    "ChatBubble(child: Text(${_bundleStr(_bStr(props, 'message', 'Hello!'))})),",
  ];
}

List<String> _bundleSelectable(Map<String, dynamic> props) {
  return ["SelectableText(${_bundleStr(_bStr(props, 'text', 'Select me'))}),"];
}

List<String> _bundleStarRating(Map<String, dynamic> props) {
  final max = _bDouble(props, 'max', 5.0, 1.0, 10.0);
  final value = _bDouble(props, 'value', 3.0, 0.0, max);
  return ['StarRating(value: $value, max: $max, onChanged: (v) {}),'];
}

List<String> _bundleClickable(Map<String, dynamic> props) {
  return [
    "Clickable(onPressed: () {}, child: Text(${_bundleStr(_bStr(props, 'label', 'Tap me'))})),",
  ];
}

List<String> _bundleScrollbar(Map<String, dynamic> props) {
  return [
    'Scrollbar(',
    "  child: SizedBox(height: 64, child: Text(${_bundleStr(_bStr(props, 'label', 'Scrollable content'))})),",
    '),',
  ];
}

List<String> _bundlePagination(Map<String, dynamic> props) {
  final total = _bInt(props, 'totalPages', 5, 1, 20);
  final page = _bInt(props, 'page', 1, 1, total);
  return [
    'Pagination(page: $page, totalPages: $total, showLabel: false, onPageChanged: (p) {}),',
  ];
}

List<String> _bundleAlertDialog(Map<String, dynamic> props) {
  // NOTE: `AlertDialog` also exists in material — when wiring the shipped
  // alert-dialog barrel alongside it, disambiguate (same trap as `Tooltip`).
  final actions = _bBool(props, 'showActions', true)
      ? [
          '  actions: [',
          "    OutlineButton(onPressed: () {}, child: const Text('Close')),",
          '  ],',
        ]
      : ['  actions: [],'];
  return [
    'AlertDialog(',
    "  title: Text(${_bundleStr(_bStr(props, 'title', 'Are you sure?'))}),",
    "  content: Text(${_bundleStr(_bStr(props, 'message', 'This action cannot be undone.'))}),",
    ...actions,
    '),',
  ];
}

List<String> _bundleMenu(Map<String, dynamic> props) {
  return [
    'MenuGroup(',
    '  direction: Axis.vertical,',
    '  autofocus: false,',
    '  builder: (context, children) => MenuPopup(children: children),',
    '  children: [',
    "    MenuLabel(child: Text(${_bundleStr(_bStr(props, 'heading', 'File'))})),",
    "    MenuButton(child: Text(${_bundleStr(_bStr(props, 'item1', 'New'))})),",
    "    MenuButton(child: Text(${_bundleStr(_bStr(props, 'item2', 'Open'))})),",
    '  ],',
    '),',
  ];
}

List<String> _bundlePopover(Map<String, dynamic> props) {
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    "    PrimaryButton(onPressed: () {}, child: Text(${_bundleStr(_bStr(props, 'trigger', 'Open Popover'))})),",
    '    const SizedBox(height: 8),',
    '    ModalContainer(',
    '      filled: true,',
    '      padding: const EdgeInsets.all(16),',
    '      child: Column(',
    '        mainAxisSize: MainAxisSize.min,',
    '        crossAxisAlignment: CrossAxisAlignment.start,',
    '        children: [',
    "          Text(${_bundleStr(_bStr(props, 'title', 'Popover title'))}),",
    '          const SizedBox(height: 8),',
    "          Text(${_bundleStr(_bStr(props, 'body', 'Use popovers for contextual helper content.'))}),",
    '        ],',
    '      ),',
    '    ),',
    '  ],',
    '),',
  ];
}

List<String> _bundlePopup(Map<String, dynamic> props) {
  return [
    'MenuPopup(',
    '  children: [',
    "    Padding(padding: const EdgeInsets.all(8), child: Text(${_bundleStr(_bStr(props, 'item1', 'Profile'))})),",
    "    Padding(padding: const EdgeInsets.all(8), child: Text(${_bundleStr(_bStr(props, 'item2', 'Settings'))})),",
    '    const Divider(height: 1),',
    "    Padding(padding: const EdgeInsets.all(8), child: Text(${_bundleStr(_bStr(props, 'item3', 'Sign out'))})),",
    '  ],',
    '),',
  ];
}

List<String> _bundleMenubar(Map<String, dynamic> props) {
  List<String> menu(String label, String sub1, String sub2) => [
        '      MenuButton(',
        '        subMenu: const [',
        "          MenuButton(child: Text('$sub1')),",
        "          MenuButton(child: Text('$sub2')),",
        '        ],',
        '        child: Text(${_bundleStr(label)}),',
        '      ),',
      ];
  // Submenu labels are fixed chrome (the kit preview's own rows), so they
  // emit raw — only the bar labels ride props, exactly like the catalog.
  return [
    'SizedBox(',
    '  height: 42,',
    '  child: SingleChildScrollView(',
    '    scrollDirection: Axis.horizontal,',
    '    child: Menubar(',
    '      border: true,',
    '      children: [',
    ...menu(_bStr(props, 'menu1', 'File'), 'New', 'Open'),
    ...menu(_bStr(props, 'menu2', 'Edit'), 'Cut', 'Copy'),
    '      ],',
    '    ),',
    '  ),',
    '),',
  ];
}

List<String> _bundleDropdownMenu(Map<String, dynamic> props) {
  return [
    'DropdownMenu(',
    '  children: [',
    "    MenuLabel(child: Text(${_bundleStr(_bStr(props, 'heading', 'My Account'))})),",
    '    const MenuDivider(),',
    "    MenuButton(child: Text(${_bundleStr(_bStr(props, 'item1', 'Profile'))})),",
    "    MenuButton(child: Text(${_bundleStr(_bStr(props, 'item2', 'Settings'))})),",
    '  ],',
    '),',
  ];
}

List<String> _bundleContextMenu(Map<String, dynamic> props) {
  return [
    'ContextMenu(',
    '  items: [',
    "    MenuButton(child: Text(${_bundleStr(_bStr(props, 'item1', 'Back'))})),",
    "    MenuButton(child: Text(${_bundleStr(_bStr(props, 'item2', 'Reload'))})),",
    '  ],',
    "  child: OutlineButton(onPressed: () {}, child: Text(${_bundleStr(_bStr(props, 'hint', 'Right-click me'))})),",
    '),',
  ];
}

List<String> _bundleHoverCard(Map<String, dynamic> props) {
  return [
    'HoverCard(',
    '  hoverBuilder: (context) => SizedBox(',
    '    width: 240,',
    '    child: Card(',
    '      padding: const EdgeInsets.all(16),',
    '      child: Column(',
    '        mainAxisSize: MainAxisSize.min,',
    '        crossAxisAlignment: CrossAxisAlignment.start,',
    '        children: [',
    "          Text(${_bundleStr(_bStr(props, 'title', 'Hover title'))}),",
    '          const SizedBox(height: 4),',
    "          Text(${_bundleStr(_bStr(props, 'body', 'Rich preview content.'))}),",
    '        ],',
    '      ),',
    '    ),',
    '  ),',
    "  child: OutlineButton(onPressed: () {}, child: Text(${_bundleStr(_bStr(props, 'handle', 'Hover card'))})),",
    '),',
  ];
}

List<String> _bundleCommand(Map<String, dynamic> props) {
  // Static query form, mirroring the catalog: the live `Command` shell
  // cannot render under loose constraints, so the palette's search row plus
  // real `CommandCategory`/`CommandItem` result parts ship instead.
  return [
    'SizedBox(',
    '  width: 300,',
    '  child: MenuPopup(',
    '    children: [',
    "      TextField(placeholder: Text(${_bundleStr(_bStr(props, 'hint', 'Search commands...'))})),",
    '      CommandCategory(',
    "        title: const Text('Suggestions'),",
    '        children: [',
    "          CommandItem(title: Text(${_bundleStr(_bStr(props, 'item1', 'Calendar'))}), onTap: () {}),",
    "          CommandItem(title: Text(${_bundleStr(_bStr(props, 'item2', 'Settings'))}), onTap: () {}),",
    '        ],',
    '      ),',
    '    ],',
    '  ),',
    '),',
  ];
}

List<String> _bundleSwiper(Map<String, dynamic> props) {
  return [
    'Swiper(',
    '  handler: SwiperHandler.sheet,',
    '  position: OverlayPosition.bottom,',
    "  builder: (context) => Padding(padding: const EdgeInsets.all(24), child: Text(${_bundleStr(_bStr(props, 'content', 'Swipe content'))})),",
    '  child: SizedBox(',
    '    height: 96,',
    '    child: Center(',
    '      child: OutlinedContainer(',
    '        child: Padding(',
    '          padding: const EdgeInsets.all(12),',
    "          child: Text(${_bundleStr(_bStr(props, 'hint', 'Swipe up from the bottom'))}),",
    '        ),',
    '      ),',
    '    ),',
    '  ),',
    '),',
  ];
}

List<String> _bundleRefreshTrigger(Map<String, dynamic> props) {
  return [
    'RefreshTrigger(',
    '  onRefresh: () async {},',
    '  child: SizedBox(',
    '    height: 140,',
    '    child: ListView(',
    '      children: [',
    "        Padding(padding: const EdgeInsets.all(12), child: Text(${_bundleStr(_bStr(props, 'item1', 'Row 1'))})),",
    "        Padding(padding: const EdgeInsets.all(12), child: Text(${_bundleStr(_bStr(props, 'item2', 'Row 2'))})),",
    "        Padding(padding: const EdgeInsets.all(12), child: Text(${_bundleStr(_bStr(props, 'item3', 'Row 3'))})),",
    '      ],',
    '    ),',
    '  ),',
    '),',
  ];
}

List<String> _bundleTabContainer(Map<String, dynamic> props) {
  // Static snapshot of the catalog's tab-container cell: the selected index
  // is clamped like the cell clamps it, and the `Selected tab` label renders
  // that index statically; taps no-op.
  final labels = [
    _bStr(props, 'tab1', 'Overview'),
    _bStr(props, 'tab2', 'Details'),
    _bStr(props, 'tab3', 'Reviews'),
  ];
  final selected = _bInt(props, 'index', 0, 0, labels.length - 1);
  return [
    'TabContainer(',
    '  selected: $selected,',
    '  onSelect: (i) {},',
    '  builder: (context, children) => Column(',
    '    mainAxisSize: MainAxisSize.min,',
    '    children: [',
    '      Row(',
    '        mainAxisAlignment: MainAxisAlignment.center,',
    '        children: [for (final child in children) Flexible(child: child)],',
    '      ),',
    '      const SizedBox(height: 8),',
    "      Text('Selected tab: ${selected + 1}'),",
    '    ],',
    '  ),',
    '  childBuilder: (context, data, child) {',
    '    final selected = data.selected == data.index;',
    '    return GestureDetector(',
    '      onTap: () => data.onSelect?.call(data.index),',
    '      child: Padding(',
    '        padding: const EdgeInsets.symmetric(horizontal: 12),',
    '        child: DefaultTextStyle.merge(',
    '          style: TextStyle(',
    '            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,',
    '          ),',
    '          child: child,',
    '        ),',
    '      ),',
    '    );',
    '  },',
    '  children: [',
    for (final label in labels)
      "    TabItem(child: Text(${_bundleStr(label)}, maxLines: 1, overflow: TextOverflow.ellipsis)),",
    '  ],',
    '),',
  ];
}

List<String> _bundleTabList(Map<String, dynamic> props) {
  // The catalog's tab-list cell renders the TABS barrel's `TabList` with the
  // tabs barrel's `TabItem` children (qualified `tabs.` there) — mirrored
  // here with the screen-level `as tabs` prefix. (The standalone tab_list
  // barrel declares its own `TabList`, but its `TabChild` is the
  // tab-container barrel's mixin, which cannot be instantiated — so the
  // catalog family is the only compilable static form.)
  final index = _bInt(props, 'index', 0, 0, 1);
  return [
    'SizedBox(',
    '  height: 37,',
    '  child: SingleChildScrollView(',
    '    scrollDirection: Axis.horizontal,',
    '    child: tabs.TabList(',
    '      index: $index,',
    '      onChanged: (i) {},',
    '      children: [',
    "        tabs.TabItem(child: Text(${_bundleStr(_bStr(props, 'tab1', 'Tab 1'))})),",
    "        tabs.TabItem(child: Text(${_bundleStr(_bStr(props, 'tab2', 'Tab 2'))})),",
    '      ],',
    '    ),',
    '  ),',
    '),',
  ];
}

List<String> _bundleTabPane(Map<String, dynamic> props) {
  final labels = [
    _bStr(props, 'tab1', 'Overview'),
    _bStr(props, 'tab2', 'Analytics'),
    _bStr(props, 'tab3', 'Settings'),
  ];
  final focused = _bInt(props, 'focused', 0, 0, labels.length - 1);
  final contentLabel = _bundleStr('Content: ${labels[focused]}');
  return [
    'TabPane<String>(',
    '  items: [',
    for (final label in labels) '    TabPaneData(${_bundleStr(label)}),',
    '  ],',
    '  focused: $focused,',
    '  onFocused: (i) {},',
    '  itemBuilder: (context, item, index) => TabChildWidget(indexed: true, child: Text(item.data)),',
    '  child: Padding(',
    '    padding: const EdgeInsets.all(16),',
    '    child: Text($contentLabel),',
    '  ),',
    '),',
  ];
}

List<String> _bundleStepper(Map<String, dynamic> props) {
  // Static snapshot of the catalog's stepper cell: the controller builds
  // inline with the clamped step (the catalog owns+disposes it; exported
  // screens carry it inline — lift into state when adopting).
  // NOTE: `Step` also exists in material — disambiguate when wiring
  // (same trap as `Tooltip`).
  List<String> step(String title, String detail) => [
        '    Step(',
        '      title: Flexible(',
        '        child: Text(',
        '          ${_bundleStr(title)},',
        '          maxLines: 1,',
        '          overflow: TextOverflow.ellipsis,',
        '        ),',
        '      ),',
        '      contentBuilder: (_) => Text(${_bundleStr(detail)}),',
        '    ),',
      ];
  return [
    'Stepper(',
    '  controller: StepperController(currentStep: ${_bInt(props, 'step', 0, 0, 2)}),',
    '  direction: Axis.vertical,',
    '  steps: [',
    ...step(
      _bStr(props, 'step1', 'Details'),
      _bStr(props, 'detail1', 'Provide your details.'),
    ),
    ...step(
      _bStr(props, 'step2', 'Payment'),
      _bStr(props, 'detail2', 'Choose a payment method.'),
    ),
    ...step(
      _bStr(props, 'step3', 'Confirm'),
      _bStr(props, 'detail3', 'Review and submit.'),
    ),
    '  ],',
    '),',
  ];
}

List<String> _bundleSlider(Map<String, dynamic> props) {
  final value = _bDouble(props, 'value', 0.6, 0.0, 1.0);
  return ['Slider(value: $value, onChanged: (v) {}),'];
}

/// Parses a canvas-level hex string (`'#2196F3'`, `'2196F3'`, `'80FFFFFF'`)
/// into an ARGB int for the color-kind builders. Mirrors the catalog's
/// `_parseHexColor`: malformed input falls back to the kit-history blue
/// (`0xFF2196F3`), so hand-written docs never crash.
int _bundleColorValue(String raw) {
  var hex = raw.trim().replaceAll('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  if (value == null || hex.length != 8) return 0xFF2196F3;
  return value;
}

/// `Color(0xFF2196F3)` literal for a canvas-level hex string.
String _bundleColorLit(String raw) =>
    "Color(0x${_bundleColorValue(raw).toRadixString(16).padLeft(8, '0').toUpperCase()})";

/// Uppercase `'#RRGGBB'` label for a canvas-level hex string (mirrors the
/// catalog's `_toHexLabel`, which formats the parsed swatch color).
String _bundleHexLabel(String raw) {
  final rgb = _bundleColorValue(raw)
      .toRadixString(16)
      .padLeft(8, '0')
      .substring(2)
      .toUpperCase();
  return '#$rgb';
}

List<String> _bundleInputOtp(Map<String, dynamic> props) {
  final length = _bInt(props, 'length', 6, 4, 8);
  return [
    'InputOTP(',
    '  onChanged: (_) {},',
    '  children: [',
    for (var i = 0; i < length; i++)
      '    InputOTPChild.character(allowDigit: true),',
    '  ],',
    '),',
  ];
}

List<String> _bundleCalendar(Map<String, dynamic> props) {
  final mode = switch (props['mode']) {
    'range' => 'CalendarSelectionMode.range',
    'multi' => 'CalendarSelectionMode.multi',
    'none' => 'CalendarSelectionMode.none',
    _ => 'CalendarSelectionMode.single',
  };
  return [
    'Calendar(',
    '  view: CalendarView.now(),',
    '  selectionMode: $mode,',
    '  onChanged: (_) {},',
    '),',
  ];
}

List<String> _bundleDatePicker(Map<String, dynamic> props) {
  final field = [
    'DatePicker(',
    '  value: null,',
    '  onChanged: (_) {},',
    "  placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Select date'))}),",
    '),',
  ];
  final label = _bStr(props, 'label', '');
  if (label.isEmpty) return field;
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    Text(${_bundleStr(label)}),',
    '    const SizedBox(height: 6),',
    '    ${field.first}',
    ...field.skip(1).map((line) => '    $line'),
    '  ],',
    '),',
  ];
}

List<String> _bundleTimePicker(Map<String, dynamic> props) {
  final field = [
    'TimePicker(',
    '  value: null,',
    '  onChanged: (_) {},',
    "  placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Select time'))}),",
    '),',
  ];
  final label = _bStr(props, 'label', '');
  if (label.isEmpty) return field;
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    Text(${_bundleStr(label)}),',
    '    const SizedBox(height: 6),',
    '    ${field.first}',
    ...field.skip(1).map((line) => '    $line'),
    '  ],',
    '),',
  ];
}

List<String> _bundleCarousel(Map<String, dynamic> props) {
  // Deviation (documented, same reason as card_image): the catalog slide art
  // is theme-token (`Theme` + `Icons`) — the static snapshot uses a tonal
  // box with a runtime slide label instead, so the screen stays
  // widgets+kit only.
  final slides = _bInt(props, 'slides', 3, 1, 5);
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  children: [',
    '    SizedBox(',
    '      height: 160,',
    '      child: Carousel(',
    '        transition: const CarouselTransition.sliding(),',
    '        itemCount: $slides,',
    "        itemBuilder: (context, index) => Container(",
    '          color: const Color(0xFFE8EAED),',
    "          child: Center(child: Text('Slide \${index + 1}')),",
    '        ),',
    '      ),',
    '    ),',
    '    const SizedBox(height: 8),',
    '    DotIndicator(index: 0, length: $slides),',
    '  ],',
    '),',
  ];
}

List<String> _bundleTree(Map<String, dynamic> props) {
  final node1 = _bStr(props, 'node1', 'Design');
  final child1 = _bStr(props, 'child1', 'Research');
  final child2 = _bStr(props, 'child2', 'Wireframes');
  final node2 = _bStr(props, 'node2', 'Launch');
  return [
    'TreeView<String>(',
    '  shrinkWrap: true,',
    '  nodes: [',
    '    TreeItem(',
    '      data: ${_bundleStr(node1)},',
    '      expanded: true,',
    '      children: [',
    '        TreeItem(data: ${_bundleStr(child1)}),',
    '        TreeItem(data: ${_bundleStr(child2)}),',
    '      ],',
    '    ),',
    '    TreeItem(data: ${_bundleStr(node2)}),',
    '  ],',
    '  builder: (context, item) => Text(item.data),',
    '),',
  ];
}

List<String> _bundleTable(Map<String, dynamic> props) {
  // NOTE: `Table`/`TableHeader`/`TableRow`/`TableCell` also exist in
  // material — the catalog aliases the kit's (`table.` prefix); when wiring
  // the shipped table barrel, disambiguate the same way.
  List<String> row(String cell1, String cell2, String ctor) => [
        '    $ctor(',
        '      cells: [',
        '        TableCell(child: Text(${_bundleStr(cell1)})),',
        '        TableCell(child: Text(${_bundleStr(cell2)})),',
        '      ],',
        '    ),',
      ];
  return [
    'Table(',
    '  rows: [',
    ...row(
      _bStr(props, 'header1', 'Name'),
      _bStr(props, 'header2', 'Role'),
      'TableHeader',
    ),
    ...row(
      _bStr(props, 'name1', 'Avery'),
      _bStr(props, 'role1', 'Designer'),
      'TableRow',
    ),
    ...row(
      _bStr(props, 'name2', 'Jordan'),
      _bStr(props, 'role2', 'Engineer'),
      'TableRow',
    ),
    '  ],',
    '),',
  ];
}

List<String> _bundleForm(Map<String, dynamic> props) {
  // NOTE: `Form`/`FormField` also exist in material — disambiguate when
  // wiring (same trap as `Table`).
  return [
    'Form(',
    '  child: Column(',
    '    mainAxisSize: MainAxisSize.min,',
    '    children: [',
    '      FormTableLayout(',
    '        rows: [',
    '          FormField<String>(',
    '            key: const FormKey<String>(#name),',
    "            label: Text(${_bundleStr(_bStr(props, 'label', 'Name'))}),",
    "            child: TextField(placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Jane Doe'))})),",
    '          ),',
    '        ],',
    '      ),',
    '      const SizedBox(height: 16),',
    '      PrimaryButton(',
    '        onPressed: () {},',
    "        child: Text(${_bundleStr(_bStr(props, 'submitLabel', 'Submit'))}),",
    '      ),',
    '    ],',
    '  ),',
    '),',
  ];
}

List<String> _bundleFormField(Map<String, dynamic> props) {
  final value = _bStr(props, 'value', '');
  return [
    'ObjectFormField<String>(',
    '  value: ${value.isEmpty ? 'null' : _bundleStr(value)},',
    '  onChanged: (_) {},',
    "  placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Select item'))}),",
    '  builder: (context, selected) => Text(selected),',
    "  editorBuilder: (context, _) => TextField(placeholder: const Text('Search...')),",
    '),',
  ];
}

List<String> _bundleFormattedInput(Map<String, dynamic> props) {
  final field = [
    'FormattedInput(',
    '  onChanged: (_) {},',
    '  initialValue: FormattedValue([',
    '    InputPart.editable(',
    '      length: 2,',
    '      width: 40,',
    "      placeholder: const Text('MM'),",
    "    ).withValue('01'),",
    "    InputPart.static('/'),",
    '    InputPart.editable(',
    '      length: 2,',
    '      width: 40,',
    "      placeholder: const Text('DD'),",
    "    ).withValue('02'),",
    "    InputPart.static('/'),",
    '    InputPart.editable(',
    '      length: 4,',
    '      width: 60,',
    "      placeholder: const Text('YYYY'),",
    "    ).withValue('2021'),",
    '  ]),',
    '),',
  ];
  final label = _bStr(props, 'label', '');
  if (label.isEmpty) return field;
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    Text(${_bundleStr(label)}),',
    '    const SizedBox(height: 6),',
    '    ${field.first}',
    ...field.skip(1).map((line) => '    $line'),
    '  ],',
    '),',
  ];
}

List<String> _bundleValidated(Map<String, dynamic> props) {
  // The validator rides the per-file `_CanvasRequiredValidator` helper
  // (emitted once when any screen item uses this kind); the builder closure
  // mirrors the catalog verbatim.
  final errorText = _bStr(props, 'errorText', 'Required');
  return [
    'Validated<String>(',
    '  validator: _CanvasRequiredValidator(${_bundleStr(errorText)}),',
    '  builder: (context, error, child) => Column(',
    '    mainAxisSize: MainAxisSize.min,',
    '    crossAxisAlignment: CrossAxisAlignment.start,',
    '    children: [',
    '      child!,',
    '      const SizedBox(height: 6),',
    '      Text(error is InvalidResult ? error.message : ${_bundleStr(errorText)}),',
    '    ],',
    '  ),',
    "  child: TextField(placeholder: Text(${_bundleStr(_bStr(props, 'placeholder', 'Name'))})),",
    '),',
  ];
}

List<String> _bundleColorPicker(Map<String, dynamic> props) {
  // The hex prop parses at export time (malformed falls back to the
  // kit-history blue, mirroring the catalog); the label echoes the raw prop.
  final hex = _bStr(props, 'hex', '#2196F3');
  final color = _bundleColorLit(hex);
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    RecentColorsScope(',
    '      initialRecentColors: [$color],',
    '      child: ColorPicker(',
    '        value: ColorDerivative.fromColor($color),',
    '        showHistoryButton: false,',
    '        initialShowHistory: false,',
    '        enableEyeDropper: false,',
    '      ),',
    '    ),',
    '    const SizedBox(height: 8),',
    '    Text(${_bundleStr(hex)}),',
    '  ],',
    '),',
  ];
}

List<String> _bundleColorInput(Map<String, dynamic> props) {
  final hex = _bStr(props, 'hex', '#2196F3');
  final color = _bundleColorLit(hex);
  return [
    'RecentColorsScope(',
    '  initialRecentColors: [$color],',
    '  child: ColorInput(',
    '    value: ColorDerivative.fromColor($color),',
    '    onChanged: (_) {},',
    '    placeholder: Text(${_bundleStr(hex)}),',
    '    showLabel: true,',
    '    enableEyeDropper: false,',
    '    showHistory: false,',
    '  ),',
    '),',
  ];
}

List<String> _bundleHsl(Map<String, dynamic> props) {
  // Static snapshot of the catalog's HSL cell: the slider starts at the
  // kit-history blue with the selected channel; drags no-op.
  final type = switch (props['mode']) {
    'sat' => 'HSLColorSliderType.sat',
    'lum' => 'HSLColorSliderType.lum',
    'alpha' => 'HSLColorSliderType.alpha',
    _ => 'HSLColorSliderType.hue',
  };
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    SizedBox(',
    '      height: 32,',
    '      child: HSLColorSlider(',
    '        color: HSLColor.fromColor(Color(0xFF2196F3)),',
    '        sliderType: $type,',
    '        onChanged: (_) {},',
    '      ),',
    '    ),',
    '    const SizedBox(height: 8),',
    '    Row(',
    '      mainAxisSize: MainAxisSize.min,',
    '      children: [',
    '        Container(width: 24, height: 24, color: Color(0xFF2196F3)),',
    '        const SizedBox(width: 8),',
    // Swatch label derives from the same initial blue (mirrors the
    // catalog's `_toHexLabel`, which formats the live swatch color).
    "        Text('${_bundleHexLabel('#2196F3')}'),",
    '      ],',
    '    ),',
    '  ],',
    '),',
  ];
}

List<String> _bundleHsv(Map<String, dynamic> props) {
  // Static snapshot of the catalog's HSV cell, mirroring [_bundleHsl] for
  // the kit's `HSVColorSlider` (whose value param is named `value`).
  final type = switch (props['mode']) {
    'sat' => 'HSVColorSliderType.sat',
    'val' => 'HSVColorSliderType.val',
    'alpha' => 'HSVColorSliderType.alpha',
    _ => 'HSVColorSliderType.hue',
  };
  return [
    'Column(',
    '  mainAxisSize: MainAxisSize.min,',
    '  crossAxisAlignment: CrossAxisAlignment.start,',
    '  children: [',
    '    SizedBox(',
    '      height: 32,',
    '      child: HSVColorSlider(',
    '        value: HSVColor.fromColor(Color(0xFF2196F3)),',
    '        sliderType: $type,',
    '        onChanged: (_) {},',
    '      ),',
    '    ),',
    '    const SizedBox(height: 8),',
    '    Row(',
    '      mainAxisSize: MainAxisSize.min,',
    '      children: [',
    '        Container(width: 24, height: 24, color: Color(0xFF2196F3)),',
    '        const SizedBox(width: 8),',
    // Swatch label derives from the same initial blue (mirrors the
    // catalog's `_toHexLabel`, which formats the live swatch color).
    "        Text('${_bundleHexLabel('#2196F3')}'),",
    '      ],',
    '    ),',
    '  ],',
    '),',
  ];
}

List<String> _bundleHistory(Map<String, dynamic> props) {
  final columns = _bInt(props, 'columns', 6, 2, 10);
  return [
    'RecentColorsScope(',
    '  initialRecentColors: const [Color(0xFF2196F3), Color(0xFF9C27B0)],',
    '  child: Builder(',
    '    builder: (context) => ColorHistoryGrid(',
    '      storage: ColorHistoryStorage.of(context),',
    '      onColorPicked: (_) {},',
    '      crossAxisCount: $columns,',
    '    ),',
    '  ),',
    '),',
  ];
}

List<String> _bundleFeatureCarousel(Map<String, dynamic> props) {
  // Static snapshot of the catalog's feature-carousel cell: the controller
  // builds inline with autoplay off (no timers in exported screens).
  return [
    'FeatureCardCarousel(',
    '  controller: FeatureCarouselController(autoPlay: false, showCta: false),',
    '  width: 320,',
    '  items: [',
    "    FeatureCarouselItem(title: ${_bundleStr(_bStr(props, 'title1', 'Palette Selector'))}, description: ${_bundleStr(_bStr(props, 'description1', 'Pick a palette to refine results.'))}, icon: Icons.auto_awesome, accentColor: const Color(0xFF7EA3FF)),",
    "    FeatureCarouselItem(title: ${_bundleStr(_bStr(props, 'title2', 'Style Presets'))}, description: ${_bundleStr(_bStr(props, 'description2', 'Choose a curated style preset.'))}, icon: Icons.palette, accentColor: const Color(0xFF9B87FF)),",
    '  ],',
    '),',
  ];
}

/// Writes [node]'s item rows at [indent]: real bodies for catalog kinds
/// (plain items), or — for responsive nodes — a `LayoutBuilder` tier conditional in the
/// `codegen_single.dart` idiom (tier resolution line, hidden-tier early
/// return, one `if (tier == …)` branch per override tier with statically
/// merged props, then the default branch). A node hidden on every tier
/// emits a bare `SizedBox.shrink()`.
void _writeBundleNode(
  List<String> rows,
  CanvasNode node,
  Map<String, String> routes,
  Set<String> ids,
  String indent,
) {
  final hidden = _bundleHiddenTiers(node);
  final tiers = _bundleOverrideTiers(node);
  if (hidden.length == kResponsiveTiers.length) {
    rows
      ..add('$indent// hidden on: ${hidden.join(', ')} (all tiers)')
      ..add('${indent}const SizedBox.shrink(),');
    return;
  }
  if (!_isBundleResponsive(node)) {
    for (final item in node.items) {
      rows.add('$indent${_bundleItemComment(item, routes, ids)}');
      for (final line in _bundleItemExpr(item, routes, ids)) {
        rows.add('$indent$line');
      }
    }
    return;
  }
  final summary = [
    if (hidden.isNotEmpty) 'hidden on ${hidden.join(', ')}',
    if (tiers.isNotEmpty) 'overrides on ${tiers.join(', ')}',
  ].join('; ');
  rows
    ..add('$indent// responsive ($summary)')
    ..add('${indent}LayoutBuilder(')
    ..add('$indent  builder: (context, constraints) {')
    ..add(
      "$indent    final tier = constraints.maxWidth >= 1024 "
      "? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';",
    );
  if (hidden.isNotEmpty) {
    final cond = hidden.map((t) => "tier == '$t'").join(' || ');
    rows.add('$indent    if ($cond) return const SizedBox.shrink();');
  }
  for (final tier in tiers) {
    _writeBundleBranch(
      rows,
      node,
      node.breakpointValues[tier]!,
      routes,
      ids,
      '$indent    ',
      "tier == '$tier'",
    );
  }
  _writeBundleBranch(rows, node, const {}, routes, ids, '$indent    ', null);
  rows
    ..add('$indent  },')
    ..add('$indent),');
}

/// Writes one tier branch (or the default branch when [guard] is null):
/// the item doc comments above a `return <expr>;` for the node's
/// placeholder content with [overrides] statically merged over item props.
void _writeBundleBranch(
  List<String> rows,
  CanvasNode node,
  Map<String, dynamic> overrides,
  Map<String, String> routes,
  Set<String> ids,
  String indent,
  String? guard,
) {
  final items = [
    for (final item in node.items)
      overrides.isEmpty
          ? item
          : item.copyWith(props: {...item.props, ...overrides}),
  ];
  for (final item in items) {
    rows.add('$indent${_bundleItemComment(item, routes, ids)}');
  }
  final expr = _bundleNodeExpr(items, routes, ids);
  final prefix = guard == null ? 'return ' : 'if ($guard) return ';
  final lines = [
    for (final line in expr.split('\n')) if (line.isNotEmpty) line,
  ];
  for (var i = 0; i < lines.length; i++) {
    final tail = i == lines.length - 1 ? ';' : '';
    if (i == 0) {
      rows.add('$indent$prefix${lines[i]}$tail');
    } else {
      rows.add('$indent${lines[i]}$tail');
    }
  }
}

/// Placeholder content expression for [items] (unindented, no trailing
/// comma): one item renders its widget, empty renders
/// `SizedBox.shrink()`, many render a `Column` of widgets.
String _bundleNodeExpr(
  List<CanvasItem> items,
  Map<String, String> routes,
  Set<String> ids,
) {
  if (items.length == 1) {
    var out = _bundleItemExpr(items.single, routes, ids).join('\n').trimRight();
    if (out.endsWith(',')) out = out.substring(0, out.length - 1);
    return out;
  }
  if (items.isEmpty) return 'SizedBox.shrink()';
  final buf = StringBuffer()
    ..writeln('Column(')
    ..writeln('mainAxisSize: MainAxisSize.min,')
    ..writeln('children: [');
  for (final item in items) {
    for (final line in _bundleItemExpr(item, routes, ids)) {
      buf.writeln('  $line');
    }
  }
  buf.write(')');
  return buf.toString();
}

String _labelOf(CanvasItem item) {
  for (final key in ['label', 'title', 'placeholder']) {
    final value = item.props[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return item.kind;
}

String _detailOf(CanvasItem item) {
  final keys = item.props.keys
      .where((k) => k != 'label' && k != 'title' && k != 'placeholder')
      .toList()
    ..sort();
  return keys.map((k) => '$k ${item.props[k]}').join(', ');
}

/// Dart single-quoted string literal for [value]; mirrors `_str` in
/// `codegen_single.dart`. Labels interpolate into `Text(…)` widget
/// expressions (not comments), so a quote/`$`/newline in a label must not
/// break compilation of the emitted screen.
String _bundleStr(Object? value) {
  final escaped = '$value'
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
  return "'$escaped'";
}

String _routeOf(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-\$'), '');
  return '/${slug.isEmpty ? 'screen' : slug}';
}

String _snakeName(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp('^_+|_+\$'), '');
  return slug.isEmpty ? 'screen' : slug;
}

String _pascalName(String name) {
  final parts = name
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'Screen';
  final joined = parts.map((p) => p[0].toUpperCase() + p.substring(1)).join();
  return RegExp('^[0-9]').hasMatch(joined) ? '_$joined' : joined;
}
