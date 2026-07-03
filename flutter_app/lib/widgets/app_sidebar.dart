import 'package:flutter/material.dart';
import 'package:prepmaster/utils/icon_utils.dart';
import '../theme/app_theme.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final List<SidebarItem>? children;
  const SidebarItem(this.icon, this.label, {this.children});
}

const sidebarItems = [
  SidebarItem(LucideIcons.home, 'Home'),
  SidebarItem(LucideIcons.megaphone, 'Announcement'),
  SidebarItem(LucideIcons.fileClock, 'Past Year Questions', children: [
    SidebarItem(LucideIcons.circle, 'JEE'),
    SidebarItem(LucideIcons.circle, 'NEET'),
    SidebarItem(LucideIcons.circle, 'Subject Wise'),
    SidebarItem(LucideIcons.circle, 'Chapter Wise'),
  ]),
  SidebarItem(LucideIcons.calendarCheck, 'Daily Practice Sheet'),
  SidebarItem(LucideIcons.bookOpenCheck, 'Chapterwise Preparation'),
  SidebarItem(
  LucideIcons.trophy2,
  'Premium All India Contest (PAIC)'
  ),
  SidebarItem(LucideIcons.award, 'Biweekly All India Contest (BAIC)'),
  SidebarItem(LucideIcons.calendarDays, 'Syllabus Timeline for Mock test'),
  SidebarItem(LucideIcons.listChecks, 'To-Do'),
  SidebarItem(LucideIcons.trophy, 'Leaderboard'),
  SidebarItem(LucideIcons.library, 'My Library'),
  SidebarItem(LucideIcons.layoutDashboard, 'My Dashboard'),
];

/// Desktop/tablet fixed sidebar. On mobile, wrap this in a Drawer instead.
class AppSidebar extends StatefulWidget {
  final String activeLabel;
  final ValueChanged<String> onSelect;
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.activeLabel,
    required this.onSelect,
    required this.darkMode,
    required this.onToggleDark,
    required this.onLogout,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final isDark = widget.darkMode;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      width: 260,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
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
              children: sidebarItems.map((item) => _buildItem(item, secondaryText)).toList(),
            ),
          ),
          Divider(color: borderColor, height: 1),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 18),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 13.5)),
            dense: true,
            onTap: widget.onLogout,
          ),
          SwitchListTile(
            dense: true,
            value: widget.darkMode,
            onChanged: widget.onToggleDark,
            activeColor: AppColors.purple,
            title: const Text('Dark mode', style: TextStyle(fontSize: 13.5)),
            secondary: const Icon(LucideIcons.moon, size: 18),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildItem(SidebarItem item, Color secondaryText) {
    final isActive = widget.activeLabel == item.label;
    final hasChildren = item.children != null;
    final isExpanded = _expanded.contains(item.label);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (hasChildren) {
                setState(() => isExpanded ? _expanded.remove(item.label) : _expanded.add(item.label));
              } else {
                widget.onSelect(item.label);
              }
            },
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
                  if (hasChildren) Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 14),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: item.children!.map((c) => _buildItem(SidebarItem(c.icon, c.label), secondaryText)).toList(),
            ),
          ),
      ],
    );
  }
}
