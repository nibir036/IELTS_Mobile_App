import 'package:flutter/material.dart';

/// Holds Day / Night mode for the whole app.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.light]);

  bool get isNight => value == ThemeMode.dark;

  void setNight(bool night) => value = night ? ThemeMode.dark : ThemeMode.light;

  void toggle() => setNight(!isNight);
}

/// Makes the [ThemeController] reachable from any widget:
/// `ThemeScope.of(context).toggle()`.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope missing above this widget');
    return scope!.notifier!;
  }
}
