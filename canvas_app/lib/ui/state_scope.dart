/// Session state scope for binding resolution (Track R1).
///
/// [StateScope] is an [InheritedWidget] carrying live state values (var name
/// → value) for the subtree below it:
///
/// * preview ([preview_player.dart]) provides its session map — bindings
///   resolve live and tap flows write through `setState`;
/// * the editor provides [defaultsFor] values (see `inspector_panel.dart`,
///   which wraps its own subtree — the editor shell in `main.dart` is owned
///   by another track, so full-canvas editor scope is future wiring; the
///   editor canvas meanwhile renders bindings raw — documented in
///   `component_catalog.dart`).
///
/// Session values are NEVER persisted: the doc (and its autosave) carries
/// only var *declarations* ([AppStateVar]); overrides live in the store's
/// session map or the preview's local copy and reset with the session.
library;

import 'package:flutter/widgets.dart';

import 'package:canvas_core/canvas_core.dart';

/// Live state values for the subtree below.
class StateScope extends InheritedWidget {
  /// Var name → live value (missing names resolve to the raw `=name`
  /// string at every consumer — never a crash).
  final Map<String, dynamic> values;

  const StateScope({super.key, required this.values, required super.child});

  /// Live values from the nearest scope, or null when no scope is above.
  static Map<String, dynamic>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StateScope>()?.values;

  /// Live values, defaulting to empty when no scope is above.
  static Map<String, dynamic> of(BuildContext context) =>
      maybeOf(context) ?? const {};

  /// Editor defaults for [vars] (name → default): what the editor provides
  /// where no session override exists.
  static Map<String, dynamic> defaultsFor(List<AppStateVar> vars) =>
      {for (final v in vars) v.name: v.defaultValue};

  @override
  bool updateShouldNotify(StateScope oldWidget) =>
      !_shallowEquals(oldWidget.values, values);

  /// Shallow map equality (values compare with `==`; enough for
  /// string/num/bool session state — no deep snapshot needed).
  static bool _shallowEquals(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}
