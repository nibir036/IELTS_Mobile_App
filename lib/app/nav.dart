import 'package:flutter/material.dart';

import 'routes.dart';

/// Small navigation helpers so screens stay short.
extension NavX on BuildContext {
  /// Push a named route. [args] is readable in the target with [routeArgs].
  Future<T?> push<T extends Object?>(String route, {Object? args}) =>
      Navigator.of(this).pushNamed<T>(route, arguments: args);

  /// Replace the current screen.
  Future<T?> replace<T extends Object?>(String route, {Object? args}) =>
      Navigator.of(this)
          .pushReplacementNamed<T, Object?>(route, arguments: args);

  /// Clear the stack and go to [route] (e.g. after login → Routes.home).
  Future<T?> resetTo<T extends Object?>(String route, {Object? args}) =>
      Navigator.of(this).pushNamedAndRemoveUntil<T>(
        route,
        (r) => false,
        arguments: args,
      );

  /// Pop if possible, otherwise go home.
  void back() {
    final nav = Navigator.of(this);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed(Routes.home);
    }
  }

  /// Arguments passed with [push], as a map (empty if none).
  Map<String, dynamic> get routeArgs {
    final a = ModalRoute.of(this)?.settings.arguments;
    if (a is Map) return a.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Floating toast in the app style.
  void toast(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
