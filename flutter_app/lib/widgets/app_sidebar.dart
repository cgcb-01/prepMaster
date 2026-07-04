import 'package:flutter/material.dart';
import '../utils/icon_utils.dart';
import '../theme/app_theme.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  const SidebarItem(this.icon, this.label);
}

// Flat list, one tap = one destination. No nested expand/collapse — that
// was adding UI complexity and an extra tap for zero benefit; PYQ's
// exam/subject/chapter filters now live as dropdowns inside the PYQ screen
// itself instead of as separate sidebar destinations.
const _baseSidebarItems = [
  SidebarItem(LucideIcons.home, 'Home'),
  SidebarItem(LucideIcons.calendarCheck, 'Daily Practice Sheet'),
  SidebarItem(LucideIcons.bookOpenCheck, 'Chapterwise Preparation'),
  SidebarItem(LucideIcons.fileClock, 'Past Year Questions'),
  SidebarItem(LucideIcons.award, 'Premium All India Contest (PAIC)'),
  SidebarItem(LucideIcons.trophy, 'Leaderboard'),
  SidebarItem(LucideIcons.listChecks, 'To-Do'),
  SidebarItem(LucideIcons.library, 'My Library'),
  SidebarItem(LucideIcons.layoutDashboard, 'My Dashboard'),
];

/// Fixed left sidebar. Stateless and cheap to build — all real work
/// (data fetching) lives in the tab bodies, kept alive by AppShell's
/// IndexedStack, not here.
class AppSidebar extends StatelessWidget {
  final String activeLabel;
  final ValueChanged<String> onSelect;
  final bool darkMode;
  final bool showAdmin;
  final ValueChanged<bool> onToggleDark;
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.activeLabel,
    required this.onSelect,
    required this.darkMode,
    required this.onToggleDark,
    required this.onLogout,
    this.showAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = darkMode ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = darkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final items = [..._baseSidebarItems, if (showAdmin) const SidebarItem(LucideIcons.shieldCheck, 'Admin')];

    return Container(
      width: 250,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(colors: [AppColors.purple, AppColors.purpleGlow]),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PrepMaster', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Premium', style: TextStyle(fontSize: 11, color: AppColors.purple)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: items.map((item) => _item(item, secondaryText)).toList(),
            ),
          ),
          Divider(color: borderColor, height: 1),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 18),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 13.5)),
            dense: true,
            onTap: onLogout,
          ),
          SwitchListTile(
            dense: true,
            value: darkMode,
            onChanged: onToggleDark,
            activeColor: AppColors.purple,
            title: const Text('Dark mode', style: TextStyle(fontSize: 13.5)),
            secondary: const Icon(LucideIcons.moon, size: 18),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _item(SidebarItem item, Color secondaryText) {
    final isActive = activeLabel == item.label;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(item.label),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.purple.withOpacity(0.12) : null,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? const Border(left: BorderSide(color: AppColors.purple, width: 2.5)) : null,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 17, color: isActive ? AppColors.purple : secondaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isActive ? AppColors.purple : null,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
