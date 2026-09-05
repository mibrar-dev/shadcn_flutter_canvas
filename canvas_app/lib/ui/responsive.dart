/// App-side responsive breakpoint system (v1).
///
/// Material-3 aligned tiers: mobile 0–599, tablet 600–1023, desktop ≥1024.
/// The preview canvas IS the breakpoint: the stage width resolves the tier
/// (see `preview_player.dart`), so resizing the device frame re-tiers live.
///
/// v1 scope: breakpoints + device frames + the adaptive-nav demo template.
/// Per-node responsive visibility (FlutterFlow parity) is DESIGNED here
/// ([isHiddenOnTier] + the `hiddenOn` shape) but NOT wired to the doc model:
/// without `canvas_core` access the per-node field has nowhere to live
/// (node `props` are item-level, so storing it there would be wrong).
/// Promoting `hiddenOn` (plus responsive values/slots) to `canvas_core`'s
/// `screen_doc.dart` is the explicit next batch — see the report.
///
/// `device_preview` was deliberately NOT added (1.3.1 is what resolves on
/// Flutter 3.44.6; 3.0.0 needs ≥3.47; 2.x has web gesture bugs), so this
/// file plus `device_picker.dart` are our own picker.
library;

import 'package:flutter/widgets.dart';

/// Tablet breakpoint: widths ≥ this are at least tablet.
const double kBreakpointTablet = 600.0;

/// Desktop breakpoint: widths ≥ this are desktop.
const double kBreakpointDesktop = 1024.0;

/// Responsive tier resolved from a layout width.
enum Tier {
  /// 0–599.
  mobile,

  /// 600–1023.
  tablet,

  /// ≥1024.
  desktop,
}

/// Resolves [Tier] for a layout width [w].
///
/// Boundaries: 599.9 → mobile, 600 → tablet, 1023.9 → tablet, 1024 → desktop.
Tier tierForWidth(double w) {
  if (w < kBreakpointTablet) return Tier.mobile;
  if (w < kBreakpointDesktop) return Tier.tablet;
  return Tier.desktop;
}

/// v1 app-side visibility shape (FlutterFlow parity design).
///
/// A node's `hiddenOn` set lists the tiers it is hidden on. This helper is
/// the resolver; the doc-model field itself lands with the `canvas_core`
/// promotion next batch, so for now callers pass the set explicitly.
bool isHiddenOnTier(Tier tier, Set<Tier> hiddenOn) => hiddenOn.contains(tier);

/// Builder exposed by [ResponsiveBuilder]: context, resolved tier, width.
typedef ResponsiveBuild =
    Widget Function(BuildContext context, Tier tier, double width);

/// [LayoutBuilder]-based widget exposing `(context, tier, width)`.
///
/// The tier resolves from `constraints.maxWidth` via [tierForWidth], so the
/// subtree re-tiers whenever its parent width crosses 600/1024.
class ResponsiveBuilder extends StatelessWidget {
  /// Builds the responsive subtree.
  final ResponsiveBuild builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return builder(context, tierForWidth(width), width);
      },
    );
  }
}
