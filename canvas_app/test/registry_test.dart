/// W1 registry tests: full-manifest coverage, section order, the word-start
/// search regression, bridge completeness, and builder smoke tests.
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// All 134 kit component ids, transcribed from
/// `shadcn_flutter_kit/flutter_shadcn_kit/lib/registry/manifests/components.json`
/// (sorted; re-transcribe if the manifest changes).
const _kKitIds = <String>{
  'accordion',
  'alert',
  'alert_dialog',
  'alpha',
  'app',
  'async',
  'autocomplete',
  'avatar',
  'badge',
  'basic',
  'border_loading',
  'breadcrumb',
  'button',
  'calendar',
  'card',
  'card_image',
  'carousel',
  'chat',
  'checkbox',
  'chip',
  'chip_input',
  'circular_progress_indicator',
  'clickable',
  'code_snippet',
  'collapsible',
  'color',
  'color_input',
  'color_picker',
  'command',
  'context_menu',
  'control',
  'date_picker',
  'debug',
  'dialog',
  'divider',
  'dot_indicator',
  'drawer',
  'dropdown_menu',
  'dropzone',
  'empty_state',
  'error_system',
  'eye_dropper',
  'fade_scroll',
  'feature_carousel',
  'file_diff_viewer',
  'file_input',
  'file_picker',
  'filter_bar',
  'flex',
  'focus_outline',
  'form',
  'form_field',
  'formatted_input',
  'formatter',
  'gooey_toast',
  'group',
  'hidden',
  'history',
  'hover',
  'hover_card',
  'hsl',
  'hsv',
  'icon',
  'image',
  'input',
  'input_otp',
  'item_picker',
  'keyboard_shortcut',
  'linear_progress_indicator',
  'locale_utils',
  'markdown',
  'media_query',
  'menu',
  'menubar',
  'multiple_choice',
  'navigation_bar',
  'navigation_menu',
  'number_ticker',
  'object_input',
  'outlined_container',
  'overflow_marquee',
  'overlay',
  'pagination',
  'patch',
  'phone_input',
  'popover',
  'popup',
  'progress',
  'radio_group',
  'refresh_trigger',
  'repeated_animation_builder',
  'resizable',
  'scaffold',
  'scrollable',
  'scrollable_client',
  'scrollbar',
  'scrollview',
  'select',
  'selectable',
  'shadcn_localizations',
  'shadcn_localizations_en',
  'shadcn_localizations_extensions',
  'skeleton',
  'slider',
  'sortable',
  'spinner',
  'stage_container',
  'star_rating',
  'stepper',
  'steps',
  'subfocus',
  'swiper',
  'switch',
  'switcher',
  'tab_container',
  'tab_list',
  'tab_pane',
  'table',
  'tabs',
  'text',
  'text_animate',
  'text_area',
  'text_field',
  'time_picker',
  'timeline',
  'timeline_animation',
  'toast',
  'tooltip',
  'tracker',
  'tree',
  'triple_dots',
  'validated',
  'window',
  'wrapper',
};

/// Expected palette section per kit id (kit category mapping).
const _kExpectedSections = <String, String>{
  'accordion': 'Layout & Structure',
  'alert': 'Layout & Structure',
  'alert_dialog': 'Overlays',
  'alpha': 'Utilities',
  'app': 'Layout & Structure',
  'async': 'Utilities',
  'autocomplete': 'Forms & Inputs',
  'avatar': 'Display',
  'badge': 'Display',
  'basic': 'Layout & Structure',
  'border_loading': 'Display',
  'breadcrumb': 'Navigation',
  'button': 'Controls',
  'calendar': 'Display',
  'card': 'Layout & Structure',
  'card_image': 'Layout & Structure',
  'carousel': 'Display',
  'chat': 'Display',
  'checkbox': 'Forms & Inputs',
  'chip': 'Display',
  'chip_input': 'Forms & Inputs',
  'circular_progress_indicator': 'Display',
  'clickable': 'Controls',
  'code_snippet': 'Display',
  'collapsible': 'Layout & Structure',
  'color': 'Utilities',
  'color_input': 'Forms & Inputs',
  'color_picker': 'Forms & Inputs',
  'command': 'Controls',
  'context_menu': 'Overlays',
  'control': 'Forms & Inputs',
  'date_picker': 'Forms & Inputs',
  'debug': 'Utilities',
  'dialog': 'Overlays',
  'divider': 'Display',
  'dot_indicator': 'Display',
  'drawer': 'Overlays',
  'dropdown_menu': 'Overlays',
  'dropzone': 'Forms & Inputs',
  'empty_state': 'Display',
  'error_system': 'Utilities',
  'eye_dropper': 'Overlays',
  'fade_scroll': 'Layout & Structure',
  'feature_carousel': 'Display',
  'file_diff_viewer': 'Display',
  'file_input': 'Forms & Inputs',
  'file_picker': 'Forms & Inputs',
  'filter_bar': 'Layout & Structure',
  'flex': 'Layout & Structure',
  'focus_outline': 'Utilities',
  'form': 'Forms & Inputs',
  'form_field': 'Forms & Inputs',
  'formatted_input': 'Forms & Inputs',
  'formatter': 'Forms & Inputs',
  'gooey_toast': 'Overlays',
  'group': 'Layout & Structure',
  'hidden': 'Layout & Structure',
  'history': 'Forms & Inputs',
  'hover': 'Controls',
  'hover_card': 'Overlays',
  'hsl': 'Forms & Inputs',
  'hsv': 'Forms & Inputs',
  'icon': 'Display',
  'image': 'Utilities',
  'input': 'Forms & Inputs',
  'input_otp': 'Forms & Inputs',
  'item_picker': 'Forms & Inputs',
  'keyboard_shortcut': 'Display',
  'linear_progress_indicator': 'Display',
  'locale_utils': 'Utilities',
  'markdown': 'Display',
  'media_query': 'Layout & Structure',
  'menu': 'Overlays',
  'menubar': 'Overlays',
  'multiple_choice': 'Forms & Inputs',
  'navigation_bar': 'Navigation',
  'navigation_menu': 'Navigation',
  'number_ticker': 'Display',
  'object_input': 'Forms & Inputs',
  'outlined_container': 'Layout & Structure',
  'overflow_marquee': 'Layout & Structure',
  'overlay': 'Overlays',
  'pagination': 'Navigation',
  'patch': 'Controls',
  'phone_input': 'Forms & Inputs',
  'popover': 'Overlays',
  'popup': 'Overlays',
  'progress': 'Display',
  'radio_group': 'Forms & Inputs',
  'refresh_trigger': 'Overlays',
  'repeated_animation_builder': 'Utilities',
  'resizable': 'Layout & Structure',
  'scaffold': 'Layout & Structure',
  'scrollable': 'Layout & Structure',
  'scrollable_client': 'Layout & Structure',
  'scrollbar': 'Controls',
  'scrollview': 'Controls',
  'select': 'Forms & Inputs',
  'selectable': 'Display',
  'shadcn_localizations': 'Utilities',
  'shadcn_localizations_en': 'Utilities',
  'shadcn_localizations_extensions': 'Utilities',
  'skeleton': 'Display',
  'slider': 'Forms & Inputs',
  'sortable': 'Layout & Structure',
  'spinner': 'Display',
  'stage_container': 'Layout & Structure',
  'star_rating': 'Forms & Inputs',
  'stepper': 'Navigation',
  'steps': 'Layout & Structure',
  'subfocus': 'Navigation',
  'swiper': 'Overlays',
  'switch': 'Forms & Inputs',
  'switcher': 'Navigation',
  'tab_container': 'Navigation',
  'tab_list': 'Navigation',
  'tab_pane': 'Navigation',
  'table': 'Layout & Structure',
  'tabs': 'Navigation',
  'text': 'Display',
  'text_animate': 'Display',
  'text_area': 'Forms & Inputs',
  'text_field': 'Forms & Inputs',
  'time_picker': 'Forms & Inputs',
  'timeline': 'Layout & Structure',
  'timeline_animation': 'Utilities',
  'toast': 'Overlays',
  'tooltip': 'Overlays',
  'tracker': 'Display',
  'tree': 'Display',
  'triple_dots': 'Display',
  'validated': 'Forms & Inputs',
  'window': 'Layout & Structure',
  'wrapper': 'Utilities',
};

void main() {
  group('registry coverage', () {
    test('all 134 kit ids plus the row pseudo-kind, each exactly once', () {
      expect(_kKitIds, hasLength(134));
      final kinds = [for (final entry in kRegistry) entry.kind];
      expect(kinds, hasLength(_kKitIds.length + 1));
      expect(kinds.toSet(), hasLength(kinds.length));
      for (final id in _kKitIds) {
        expect(
          kinds.where((k) => k == id),
          hasLength(1),
          reason: 'missing or duplicated id $id',
        );
      }
      expect(kinds.where((k) => k == 'row'), hasLength(1));
    });

    test('sections are ordered, grouped, and complete', () {
      expect(
        kRegistrySectionOrder,
        orderedEquals([
          'Layout Primitives',
          'Layout & Structure',
          'Display',
          'Forms & Inputs',
          'Controls',
          'Navigation',
          'Overlays',
          'Utilities',
        ]),
      );
      for (final entry in kRegistry) {
        expect(
          kRegistrySectionOrder,
          contains(entry.section),
          reason: '${entry.kind} section',
        );
        expect(entry.label, isNotEmpty, reason: '${entry.kind} label');
      }
      // Sections appear grouped in palette order.
      final seen = <String>[];
      for (final entry in kRegistry) {
        if (seen.isEmpty || seen.last != entry.section) {
          seen.add(entry.section);
        }
      }
      expect(seen, orderedEquals(kRegistrySectionOrder));
      // Every kit id sits in its category section; row starts the palette.
      for (final entry in kRegistry) {
        if (entry.kind == 'row') {
          expect(entry.section, 'Layout Primitives');
        } else {
          expect(
            entry.section,
            _kExpectedSections[entry.kind],
            reason: entry.kind,
          );
        }
      }
      // Per-section counts (manifest: 32/28/25/17/14/11/7 + row).
      final counts = <String, int>{};
      for (final entry in kRegistry) {
        counts[entry.section] = (counts[entry.section] ?? 0) + 1;
      }
      expect(counts, {
        'Layout Primitives': 1,
        'Layout & Structure': 25,
        'Display': 28,
        'Forms & Inputs': 32,
        'Controls': 7,
        'Navigation': 11,
        'Overlays': 17,
        'Utilities': 14,
      });
    });

    test('bridge: every catalog kind is canvas-ready with a matching label',
        () {
      expect(kCatalog, hasLength(19));
      for (final entry in kCatalog) {
        final reg = findRegistryEntry(entry.kind);
        expect(reg, isNotNull, reason: 'no registry entry ${entry.kind}');
        expect(reg!.canvasReady, isTrue, reason: entry.kind);
        // Registry labels mirror the manifest descriptions, same as catalog.
        expect(reg.label, entry.label, reason: entry.kind);
      }
      expect(findRegistryEntry('nope'), isNull);
    });

    test('canvasReady count meets the W1 target', () {
      final ready = [
        for (final entry in kRegistry)
          if (entry.canvasReady) entry.kind,
      ];
      expect(ready.length, greaterThanOrEqualTo(25));
      // Pinned: 19 bridged + 10 hand-verified + the row pseudo-kind.
      expect(ready.length, 30);
    });

    test('hidden utilities stay covered but leave the palette', () {
      expect(
        kHiddenUtilityKinds,
        containsAll([
          'alpha',
          'async',
          'debug',
          'locale_utils',
          'shadcn_localizations',
          'shadcn_localizations_en',
          'shadcn_localizations_extensions',
          'error_system',
          'wrapper',
        ]),
      );
      for (final kind in kHiddenUtilityKinds) {
        final reg = findRegistryEntry(kind);
        expect(reg, isNotNull, reason: kind);
        expect(reg!.section, 'Utilities', reason: kind);
        expect(reg.canvasReady, isFalse, reason: kind);
      }
      var visible = 0;
      for (final section in kRegistrySectionOrder) {
        final entries = registrySectionEntries(section);
        expect(
          entries.where((e) => kHiddenUtilityKinds.contains(e.kind)),
          isEmpty,
          reason: section,
        );
        visible += entries.length;
      }
      expect(visible, kRegistry.length - kHiddenUtilityKinds.length);
    });
  });

  group('search (word-start matcher)', () {
    test("'row' matches Row, never Breadcrumb (regression)", () {
      final row = findRegistryEntry('row')!;
      final crumb = findRegistryEntry('breadcrumb')!;
      expect(registryMatchesQuery(row, 'row'), isTrue);
      // Old substring matching hit Breadcrumb via the 'arrow' in its
      // 'arrow/slash separators' description.
      expect(registryMatchesQuery(crumb, 'row'), isFalse);
      final hits = [
        for (final entry in kRegistry)
          if (registryMatchesQuery(entry, 'row')) entry.kind,
      ];
      expect(hits, contains('row'));
      expect(hits, isNot(contains('breadcrumb')));
    });

    test('matching is case-insensitive, prefix-based, multi-token', () {
      final button = findRegistryEntry('button')!;
      expect(registryMatchesQuery(button, 'BUT'), isTrue);
      expect(registryMatchesQuery(button, 'utton'), isFalse);
      final radio = findRegistryEntry('radio_group')!;
      expect(registryMatchesQuery(radio, 'radio'), isTrue);
      expect(registryMatchesQuery(radio, 'group'), isTrue);
      expect(registryMatchesQuery(radio, 'radio group'), isTrue);
      expect(registryMatchesQuery(radio, 'radio button'), isFalse);
      expect(registryMatchesQuery(button, ''), isTrue);
      expect(registryMatchesQuery(button, '   '), isTrue);
    });
  });

  group('builders', () {
    testWidgets('every canvasReady kind builds without throwing', (
      tester,
    ) async {
      for (final entry in kRegistry) {
        if (!entry.canvasReady) continue;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Builder(builder: entry.build)),
          ),
        );
      }
    });

    testWidgets('placeholder kinds render their label', (tester) async {
      final placeholders = [
        for (final entry in kRegistry)
          if (!entry.canvasReady) entry,
      ];
      expect(placeholders, isNotEmpty);
      for (final entry in placeholders.take(8)) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Builder(builder: entry.build)),
          ),
        );
        expect(find.text(entry.label), findsOneWidget);
        expect(find.text('canvas-ready coming soon'), findsOneWidget);
      }
    });
  });
}
