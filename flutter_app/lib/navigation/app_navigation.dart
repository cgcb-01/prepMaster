import 'package:flutter/material.dart';

/// Lets any screen's AppSidebar reach back up to the top-level nav state
/// without passing callbacks down through every constructor.
class AppNavigation extends InheritedWidget {
  final String active;
  final ValueChanged<String> onSelect;

  const AppNavigation({
    super.key,
    required this.active,
    required this.onSelect,
    required super.child,
  });

  static AppNavigation of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppNavigation>();
    assert(result != null, 'No AppNavigation found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppNavigation oldWidget) => oldWidget.active != active;
}
