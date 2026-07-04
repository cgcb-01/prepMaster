import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple Riverpod StateNotifier for dark/light mode, so any screen can
/// read/toggle it without threading darkMode/onToggleDark params through
/// every constructor. main.dart can switch to this instead of local
/// setState once the app grows past a couple of screens.
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(true); // defaults to dark mode

  void toggle(bool isDark) => state = isDark;
}

final darkModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((ref) => ThemeModeNotifier());
