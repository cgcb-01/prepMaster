import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_sidebar.dart';
import '../../navigation.dart';
import '../../api/api_client.dart';

enum AnnouncementType { contestUpcoming, contestDateChange, resultOut, topperList, general }

class Announcement {
  final String title;
  final String body;
  final DateTime postedAt;
  final AnnouncementType type;
  Announcement({required this.title, required this.body, required this.postedAt, required this.type});
}

/// Home: All announcements of AICs and results, Codeforces-blog style
/// (point #3): upcoming contests / date changes, then post-exam result +
/// solution release + topper names.
class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  const HomeScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Announcement> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // In production: GET /api/content/announcements/
    // Sample data shown here so the screen renders meaningfully out of the box.
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _announcements = [
        Announcement(
          title: 'PAIC #14 scheduled for 6 July, 09:00 AM',
          body: 'Physics, Chemistry, Mathematics/Biology — 3 hours, syllabus: Mechanics + Organic I.',
          postedAt: DateTime.now().subtract(const Duration(hours: 2)),
          type: AnnouncementType.contestUpcoming,
        ),
        Announcement(
          title: 'BAIC #27 results & solutions released',
          body: 'Solutions are live in My Library. Leaderboard finalized.',
          postedAt: DateTime.now().subtract(const Duration(hours: 20)),
          type: AnnouncementType.resultOut,
        ),
        Announcement(
          title: 'Top rankers — BAIC #27',
          body: '1. Arjun Sharma  2. Priya Nair  3. Rohan Verma',
          postedAt: DateTime.now().subtract(const Duration(hours: 19)),
          type: AnnouncementType.topperList,
        ),
        Announcement(
          title: 'PAIC #13 date changed',
          body: 'Moved from 30 June to 2 July due to scheduling conflict.',
          postedAt: DateTime.now().subtract(const Duration(days: 3)),
          type: AnnouncementType.contestDateChange,
        ),
      ];
      _loading = false;
    });
  }

  IconData _iconFor(AnnouncementType t) {
    switch (t) {
      case AnnouncementType.contestUpcoming: return Icons.event_available;
      case AnnouncementType.contestDateChange: return Icons.edit_calendar;
      case AnnouncementType.resultOut: return Icons.fact_check;
      case AnnouncementType.topperList: return Icons.emoji_events;
      case AnnouncementType.general: return Icons.campaign;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.darkMode ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = widget.darkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            activeLabel: 'Home',
            onSelect: (label) => navigateToSidebarLabel(context, label, darkMode: widget.darkMode, onToggleDark: widget.onToggleDark),
            darkMode: widget.darkMode,
            onToggleDark: widget.onToggleDark,
            onLogout: () async {
              await ApiClient.logout();
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Home', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        Text('Announcements, contest updates & results',
                            style: TextStyle(color: secondaryText, fontSize: 13)),
                        const SizedBox(height: 20),
                        ..._announcements.map((a) => Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.purple.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_iconFor(a.type), size: 18, color: AppColors.purple),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(a.body, style: TextStyle(fontSize: 12.5, color: secondaryText)),
                                        const SizedBox(height: 6),
                                        Text(_timeAgo(a.postedAt),
                                            style: TextStyle(fontSize: 10.5, color: secondaryText)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}