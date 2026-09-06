/// Track Z2 builder beauty: full-width nodes must look GOOD (the stretch
/// track owns full-width; this track owns comfortable presentation).
///
/// Presentation pins per kind — generous padding/gaps, 48px touch targets,
/// 16:9 card art, equal-share nav — pumped light + dark at phone width with
/// an explicit no-overflow check per pump (`takeException`, the narrow-width
/// idiom). All color assertions resolve through kit scheme roles
/// (`mutedForeground`, `cardForeground`) — never hardcoded hex.
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpBeauty(
  WidgetTester tester,
  Widget widget, {
  required bool dark,
  required String reason,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(body: widget),
    ),
  );
  await tester.pump();
  final Object? error = tester.takeException();
  expect(error, isNull, reason: reason);
}

/// Kit scheme visible from [context]: the role assertions below compare
/// against these, so a palette change updates both sides together.
shadcn.ColorScheme _schemeOf(Element element) =>
    shadcn.Theme.of(element).colorScheme;

void main() {
  group('card family', () {
    testWidgets('card: 16px padding, 17/700 title, 14 muted desc, gaps', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        await _pumpBeauty(
          tester,
          buildCatalogItem('card', {
            'title': 'T',
            'description': 'D',
            'showFooter': true,
          }),
          dark: dark,
          reason: 'card dark=$dark',
        );
        final card = tester.widget<shadcn.Card>(find.byType(shadcn.Card));
        expect(card.padding, const EdgeInsets.all(16));

        final title = tester.widget<Text>(find.text('T'));
        expect(title.style?.fontSize, 17);
        expect(title.style?.fontWeight, FontWeight.w700);

        final descElement = tester.element(find.text('D'));
        final desc = descElement.widget as Text;
        expect(desc.style?.fontSize, 14);
        expect(
          desc.style?.color,
          _schemeOf(descElement).mutedForeground,
          reason: 'description binds the muted role, never a hardcoded color',
        );

        final cardScope = find.byType(shadcn.Card);
        // 6px title-desc gap (kit card-preview idiom).
        expect(
          find.descendant(
            of: cardScope,
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == 6,
            ),
          ),
          findsOneWidget,
        );
        // 16px footer breathing room before the action.
        expect(
          find.descendant(
            of: cardScope,
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == 16,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Action'), findsOneWidget);
      }
    });

    testWidgets('card_image: 16:9 tonal art fills the card width', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        await _pumpBeauty(
          tester,
          buildCatalogItem('card_image', {
            'title': 'Sunset',
            'subtitle': 'Golden hour',
          }),
          dark: dark,
          reason: 'card_image dark=$dark',
        );
        expect(find.byType(shadcn.CardImage), findsOneWidget);
        // Tonal art only: the kit preview's network image never ships here.
        expect(find.byType(Image), findsNothing);

        final art = find.byWidgetPredicate(
          (w) => w is AspectRatio && w.aspectRatio == 16 / 9,
        );
        expect(art, findsOneWidget, reason: 'art keeps the 16:9 ratio');
        // The fixed 240px shell is gone (width-driven shell instead).
        expect(
          find.descendant(
            of: find.byType(shadcn.CardImage),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == 240,
            ),
          ),
          findsNothing,
        );
        // Art fills the card width (cross-axis stretch): the 1px/side
        // delta is the kit button's own border chrome around the image
        // slot, not a builder inset.
        final artWidth = tester.getSize(art).width;
        final cardWidth = tester.getSize(find.byType(shadcn.CardImage)).width;
        expect(cardWidth - artWidth, lessThanOrEqualTo(2.0));
        expect(artWidth, greaterThan(cardWidth * 0.95));
        expect(find.text('Sunset'), findsOneWidget);
        expect(find.text('Golden hour'), findsOneWidget);
      }
    });
  });

  group('input', () {
    testWidgets('input: 48px target, 8px label gap, fills parent width', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        await _pumpBeauty(
          tester,
          buildCatalogItem('input', {
            'placeholder': 'Type here',
            'label': 'Email',
            'disabled': false,
            'obscure': false,
          }),
          dark: dark,
          reason: 'input dark=$dark',
        );
        final field = find.byType(shadcn.TextField);
        expect(field, findsOneWidget);
        // Comfortable touch target (kit default density yields ~30px).
        expect(tester.getSize(field).height, greaterThanOrEqualTo(48));
        // Full-width fill from the bounded parent (no shrink-wrap).
        expect(
          tester.getSize(field).width,
          moreOrLessEquals(390, epsilon: 1.0),
        );
        expect(find.text('Email'), findsOneWidget);
        // Readable label-field gap.
        expect(
          find.byWidgetPredicate((w) => w is SizedBox && w.height == 8),
          findsOneWidget,
        );
      }
    });

    testWidgets('input without label keeps the 48px shell', (tester) async {
      _setPhoneViewport(tester);
      await _pumpBeauty(
        tester,
        buildCatalogItem('input', {'placeholder': 'Type here'}),
        dark: false,
        reason: 'input labelless',
      );
      expect(
        tester.getSize(find.byType(shadcn.TextField)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('button', () {
    testWidgets('button: 48px CTA, 15px label, stretches with parent', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        // Tight sizing box mirrors the parent stretch (phone_frame): the
        // builder must fill it, never collapse inside it.
        await _pumpBeauty(
          tester,
          SizedBox(
            width: 300,
            child: buildCatalogItem('button', {
              'label': 'Go',
              'variant': 'primary',
              'size': 'md',
              'disabled': false,
            }),
          ),
          dark: dark,
          reason: 'button dark=$dark',
        );
        final button = find.byType(shadcn.PrimaryButton);
        expect(button, findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(
          tester.getSize(button).width,
          moreOrLessEquals(300, epsilon: 1.0),
          reason: 'builder does not prevent the parent stretch',
        );
        final label = tester.widget<Text>(find.text('Go'));
        expect(label.style?.fontSize, 15);
        expect(label.style?.fontWeight, FontWeight.w600);
      }
    });
  });

  group('basic / avatar rows', () {
    testWidgets('avatar defaults to the 40px row size', (tester) async {
      _setPhoneViewport(tester);
      await _pumpBeauty(
        tester,
        buildCatalogItem('avatar', {}),
        dark: false,
        reason: 'avatar',
      );
      expect(
        tester.widget<shadcn.Avatar>(find.byType(shadcn.Avatar)).size,
        40.0,
      );
    });

    testWidgets('basic: 40px leading box, 8-12px rhythm, no extra padding', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        await _pumpBeauty(
          tester,
          buildCatalogItem('basic', {
            'title': 'Ada',
            'subtitle': 'Lovelace',
            'content': 'Engine',
            'showLeading': true,
            'showTrailing': true,
          }),
          dark: dark,
          reason: 'basic dark=$dark',
        );
        expect(find.byType(shadcn.Basic), findsOneWidget);
        // Leading lines up with 40px avatar rows.
        expect(
          find.descendant(
            of: find.byType(shadcn.Basic),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 40 && w.height == 40,
            ),
          ),
          findsOneWidget,
        );
        // Row rhythm in the 8-12px band (kit defaults were 16 / 4).
        expect(
          find.descendant(
            of: find.byType(shadcn.Basic),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 12,
            ),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byType(shadcn.Basic),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == 10,
            ),
          ),
          findsOneWidget,
        );
        // No compounding wrapper: the builder adds no Padding around Basic
        // (Basic owns its own zero-default padding).
        expect(
          find.ancestor(
            of: find.byType(shadcn.Basic),
            matching: find.byType(Padding),
          ),
          findsNothing,
        );
      }
    });
  });

  group('navigation_bar', () {
    testWidgets('four destinations share the full width equally', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        await _pumpBeauty(
          tester,
          buildCatalogItem('navigation_bar', {
            'tab1': 'Home',
            'tab2': 'Search',
            'tab3': 'Saved',
            'tab4': 'You',
            'index': 1,
          }),
          dark: dark,
          reason: 'navigation_bar dark=$dark',
        );
        for (final label in ['Home', 'Search', 'Saved', 'You']) {
          expect(find.text(label), findsOneWidget, reason: 'dark=$dark');
        }
        final items = find.byType(shadcn.NavigationItem);
        expect(items, findsNWidgets(4));
        final widths = [
          for (var i = 0; i < 4; i++) tester.getSize(items.at(i)).width,
        ];
        final max = widths.reduce((a, b) => a > b ? a : b);
        final min = widths.reduce((a, b) => a < b ? a : b);
        expect(
          max - min,
          lessThanOrEqualTo(1.0),
          reason: 'equal shares, got $widths',
        );
        // Legible at phone width: each share fits a short label comfortably.
        for (final w in widths) {
          expect(w, greaterThan(70));
        }
        // Taps update the selection without crashing (highlight is
        // kit-owned; this pins the wiring the highlight rides on).
        await tester.tap(find.text('Saved'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('badge', () {
    testWidgets('badge: vertical breathing room, paint intact', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      for (final dark in [false, true]) {
        await _pumpBeauty(
          tester,
          buildCatalogItem('badge', {
            'label': 'New',
            'variant': 'primary',
          }),
          dark: dark,
          reason: 'badge dark=$dark',
        );
        expect(find.byType(shadcn.PrimaryBadge), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(shadcn.PrimaryBadge),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Padding &&
                  w.padding == const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          findsOneWidget,
        );
      }
    });
  });
}
