import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/app_sidebar.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dpp_screen.dart';
import 'screens/chapterwise/chapterwise_screen.dart';
import 'screens/pyq/pyq_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/contest/contest_list_screen.dart';
import 'screens/todo/todo_screen.dart';
import 'screens/library/my_library_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

/// The single top-level shell: one Scaffold, one Sidebar, one IndexedStack.
///
/// This replaces the old pattern where every screen built its own
/// Scaffold+AppSidebar and Navigator.pushReplacement rebuilt (and
/// re-fetched) the destination screen from scratch on every tap. Here, all
/// tab bodies are constructed once by IndexedStack and kept alive — tapping
/// a sidebar item is an O(1) index swap, not a rebuild+refetch. This is the
/// direct fix for "switching pages is slow/laggy".
const _tabLabels = [
  'Home',
  'Daily Practice Sheet',
  'Chapterwise Preparation',
  'Past Year Questions',
  'Premium All India Contest (PAIC)',
  'Leaderboard',
  'To-Do',
  'My Library',
  'My Dashboard',
  'Admin',
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;

    // Build once; IndexedStack keeps every tab's state (scroll position,
    // in-flight requests, already-fetched data) alive between switches.
    final tabs = [
      const HomeScreen(),
      const DppScreen(),
      const ChapterwiseScreen(),
      const PyqScreen(),
      const ContestListScreen(),
      const LeaderboardScreen(),
      const TodoScreen(),
      const MyLibraryScreen(),
      const DashboardScreen(),
      if (isAdmin) const AdminDashboardScreen(),
    ];

    final activeLabel = _index < _tabLabels.length ? _tabLabels[_index] : 'Home';

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            activeLabel: activeLabel,
            darkMode: darkMode,
            showAdmin: isAdmin,
            onToggleDark: (v) => ref.read(darkModeProvider.notifier).toggle(v),
            onSelect: (label) {
              final i = _tabLabels.indexOf(label);
              if (i != -1 && i < tabs.length) setState(() => _index = i);
            },
            onLogout: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _index < tabs.length ? _index : 0,
              children: tabs,
            ),
          ),
        ],
      ),
    );
  }
}
