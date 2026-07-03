import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_sidebar.dart';
import '../../navigation.dart';
import '../../api/api_client.dart';
import '../../models/misc_models.dart';

/// Leaderboard: global rankings by rating, filterable by exam/class/state,
/// plus a friends-only toggle (point #16). Live-contest leaderboards are
/// handled separately in contest/live_contest_screen.dart via WebSocket.
class LeaderboardScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  const LeaderboardScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _examFilter = 'JEE';
  bool _friendsOnly = false;
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.dio.get('/api/leaderboard/global/', queryParameters: {
        'target_exam': _examFilter,
        if (_friendsOnly) 'friends_only': 'true',
      });
      setState(() {
        _entries = (resp.data as List)
            .asMap()
            .entries
            .map((e) => LeaderboardEntry.fromJson({
                  ...e.value,
                  'rank': e.key + 1,
                  'user': '${e.value['first_name']} ${e.value['last_name']}'.trim().isEmpty
                      ? e.value['username']
                      : '${e.value['first_name']} ${e.value['last_name']}',
                  'school': e.value['school_name'],
                  'score': e.value['rating'],
                }))
            .toList();
      });
    } catch (_) {
      // Network unavailable — leave prior data or empty state.
    } finally {
      setState(() => _loading = false);
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
            activeLabel: 'Leaderboard',
            onSelect: (label) => navigateToSidebarLabel(context, label, darkMode: widget.darkMode, onToggleDark: widget.onToggleDark),
            darkMode: widget.darkMode,
            onToggleDark: widget.onToggleDark,
            onLogout: () async {
              await ApiClient.logout();
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Leaderboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _examFilter,
                            items: const [
                              DropdownMenuItem(value: 'JEE', child: Text('JEE')),
                              DropdownMenuItem(value: 'NEET', child: Text('NEET')),
                            ],
                            onChanged: (v) {
                              setState(() => _examFilter = v!);
                              _load();
                            },
                          ),
                          const SizedBox(width: 16),
                          FilterChip(
                            label: const Text('Friends only'),
                            selected: _friendsOnly,
                            selectedColor: AppColors.purple.withOpacity(0.2),
                            onSelected: (v) {
                              setState(() => _friendsOnly = v);
                              _load();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.separated(
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                              itemBuilder: (context, i) {
                                final e = _entries[i];
                                final isTop3 = (e.rank ?? 99) <= 3;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isTop3 ? AppColors.purple : Colors.grey.shade700,
                                    child: Text('${e.rank}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                  title: Text(e.user, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  subtitle: Text(e.school, style: TextStyle(fontSize: 11.5, color: secondaryText)),
                                  trailing: Text('${e.score.toInt()}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.purple)),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}