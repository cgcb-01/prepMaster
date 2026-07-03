import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dpp_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/contest/contest_list_screen.dart';
import 'screens/todo/todo_screen.dart';
import 'screens/library/my_library_screen.dart';

/// Maps a sidebar label to its screen and performs the navigation.
/// Every top-level screen (Home, Dashboard, DPP, Leaderboard, Contests,
/// To-Do, Library) constructs its own AppSidebar and wires `onSelect` to
/// this function, so tapping any sidebar item works consistently from
/// anywhere in the app without a global route table / named routes.
void navigateToSidebarLabel(
  BuildContext context,
  String label, {
  required bool darkMode,
  required ValueChanged<bool> onToggleDark,
}) {
  Widget? screen;

  switch (label) {
    case 'Home':
      screen = HomeScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    case 'My Dashboard':
      screen = DashboardScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    case 'Daily Practice Sheet':
      screen = DppScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    case 'Leaderboard':
      screen = LeaderboardScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    case 'Premium All India Contest (PAIC)':
    case 'Biweekly All India Contest (BAIC)':
      screen = ContestListScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    case 'To-Do':
      screen = TodoScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    case 'My Library':
      screen = MyLibraryScreen(darkMode: darkMode, onToggleDark: onToggleDark);
      break;
    default:
      // Chapterwise Preparation, Announcement, Syllabus, PYQ sub-items etc.
      // are additive screens not yet wired here — no-op rather than crash.
      screen = null;
  }

  if (screen != null) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen!));
  }
}
