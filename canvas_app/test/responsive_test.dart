import 'package:canvas_app/ui/responsive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tierForWidth boundaries', () {
    test('below 600 is mobile', () {
      expect(tierForWidth(0), Tier.mobile);
      expect(tierForWidth(390), Tier.mobile);
      expect(tierForWidth(599.9), Tier.mobile);
    });

    test('600 up to below 1024 is tablet', () {
      expect(tierForWidth(600), Tier.tablet);
      expect(tierForWidth(768), Tier.tablet);
      expect(tierForWidth(1023.9), Tier.tablet);
    });

    test('1024 and above is desktop', () {
      expect(tierForWidth(1024), Tier.desktop);
      expect(tierForWidth(1100), Tier.desktop);
      expect(tierForWidth(1440), Tier.desktop);
    });

    test('breakpoint consts are Material-3 aligned', () {
      expect(kBreakpointTablet, 600.0);
      expect(kBreakpointDesktop, 1024.0);
    });
  });

  group('isHiddenOnTier', () {
    test('hidden only on the listed tiers', () {
      const hiddenOn = {Tier.mobile};
      expect(isHiddenOnTier(Tier.mobile, hiddenOn), isTrue);
      expect(isHiddenOnTier(Tier.tablet, hiddenOn), isFalse);
      expect(isHiddenOnTier(Tier.desktop, hiddenOn), isFalse);
      expect(isHiddenOnTier(Tier.desktop, <Tier>{}), isFalse);
    });
  });

  group('ResponsiveBuilder', () {
    Future<Tier> pumpWidth(WidgetTester tester, double width) async {
      var seen = Tier.desktop;
      var seenWidth = 0.0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          // Center loosens the tight root constraints so the SizedBox can
          // impose the exact pump width on the ResponsiveBuilder.
          child: Center(
            child: SizedBox(
              width: width,
              height: 200,
              child: ResponsiveBuilder(
                builder: (context, tier, w) {
                  seen = tier;
                  seenWidth = w;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(seenWidth, width);
      return seen;
    }

    testWidgets('exposes tier and width per breakpoint', (tester) async {
      // Wide viewport so pump widths up to 1440 are not clamped.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      expect(await pumpWidth(tester, 390), Tier.mobile);
      expect(await pumpWidth(tester, 600), Tier.tablet);
      expect(await pumpWidth(tester, 1024), Tier.desktop);
    });
  });
}
