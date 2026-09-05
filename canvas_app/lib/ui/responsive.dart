/// App-side responsive breakpoint system (v1).
///
/// Material-3 aligned tiers: mobile 0–599, tablet 600–1023, desktop ≥1024.
/// The preview canvas IS the breakpoint: the stage width resolves the tier
/// (see `preview_player.dart`), so resizing the device frame re-tiers live.
///
/// Doc-model status: the per-node fields HAVE landed — `hiddenOn`,
/// `breakpointValues`, and `slots` live on `CanvasNode` in
/// `canvas_core`'s `screen_doc.dart` (pure Dart; this file may import
/// `package:canvas_core/canvas_core.dart`). Use [hiddenOnStringsFromTiers]
/// / [tiersFromHiddenOnStrings] to convert between [Tier] sets and the
/// stored string sets, and [isNodeHiddenOnWidth] to resolve visibility
/// from a layout width.
///
/// What REMAINS (explicit later batch, do NOT implement here):
/// render-time filtering (skip hidden nodes in the preview player),
/// inspector UI (per-tier visibility toggles), and codegen emission
/// (responsive variants in generated code).
///
/// `device_preview` was deliberately NOT added (1.3.1 is what resolves on
/// Flutter 3.44.6; 3.0.0 needs ≥3.47; 2.x has web gesture bugs), so this
/// file plus `device_picker.dart` are our own picker.
library;

import 'package:canvas_core/canvas_core.dart' show kResponsiveTiers;
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
/// the resolver; the stored field itself lives on `CanvasNode.hiddenOn`
/// (string set) in `canvas_core` — convert with [hiddenOnStringsFromTiers]
/// / [tiersFromHiddenOnStrings], or resolve straight from a layout width
/// with [isNodeHiddenOnWidth].
bool isHiddenOnTier(Tier tier, Set<Tier> hiddenOn) => hiddenOn.contains(tier);

/// Converts a [Tier] set to the doc-model string set stored in
/// `CanvasNode.hiddenOn` (e.g. `{Tier.mobile}` → `{'mobile'}`).
Set<String> hiddenOnStringsFromTiers(Set<Tier> tiers) =>
    {for (final tier in tiers) tier.name};

/// Converts a doc-model `hiddenOn` string set back to [Tier]s.
///
/// Unknown names throw [FormatException] (fail fast), mirroring
/// `CanvasNode.fromJson`'s validation against [kResponsiveTiers].
Set<Tier> tiersFromHiddenOnStrings(Set<String> hiddenOn) {
  for (final name in hiddenOn) {
    if (!kResponsiveTiers.contains(name)) {
      throw FormatException('Unknown responsive tier: $name');
    }
  }
  return {for (final name in hiddenOn) Tier.values.byName(name)};
}

/// Resolves whether a node with doc-model `hiddenOn` strings is hidden at
/// layout width [width]: the width maps to a tier via [tierForWidth] and
/// the tier name is looked up in [hiddenOn].
///
/// Unknown strings never match a tier (they are rejected at parse time by
/// `CanvasNode.fromJson`), so they are treated as inert here.
bool isNodeHiddenOnWidth(double width, Set<String> hiddenOn) =>
    hiddenOn.contains(tierForWidth(width).name);

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
