import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../navigation.dart';
import '../api/api_client.dart';
import '../models/user_profile.dart';

/// My Dashboard screen — public profile, rating graph, activity heatmap,
/// stats cards, and public/private info panels. Mirrors the reference UI.
class DashboardScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;

  const DashboardScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.dio.get('/api/users/me/');
      setState(() => _profile = UserProfile.fromJson(resp.data));
    } catch (_) {
      // No connection / not logged in yet — screen still renders with
      // sample fallback data below so the UI is always demonstrable.
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
            activeLabel: 'My Dashboard',
            onSelect: (label) => navigateToSidebarLabel(context, label, darkMode: widget.darkMode, onToggleDark: widget.onToggleDark),
            darkMode: widget.darkMode,
            onToggleDark: widget.onToggleDark,
            onLogout: () async {
              await ApiClient.logout();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        Text('Your public profile and performance overview',
                            style: TextStyle(color: secondaryText, fontSize: 13)),
                        const SizedBox(height: 20),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 280, child: _ProfileCard(borderColor: borderColor, profile: _profile)),
                              const SizedBox(width: 16),
                              Expanded(child: _RatingGraphCard(borderColor: borderColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _HeatmapCard(borderColor: borderColor),
                        const SizedBox(height: 16),
                        _StatsRow(borderColor: borderColor, profile: _profile),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _InfoPanel(
                                title: 'Public (Visible to all users)',
                                borderColor: borderColor,
                                rows: const {'Strong Subjects': 'Physics, Chemistry'},
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _InfoPanel(
                                title: 'Private (Only You)',
                                borderColor: borderColor,
                                rows: {
                                  'Weak Subjects': (_profile?.weakSubjects ?? ['Organic Chemistry', 'Mechanics']).join(', '),
                                  'Weak Chapters': (_profile?.weakChapters ?? ['Rotational Motion', 'Hydrocarbons']).join(', '),
                                },
                              ),
                            ),
                          ],
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

class _ProfileCard extends StatelessWidget {
  final Color borderColor;
  final UserProfile? profile;
  const _ProfileCard({required this.borderColor, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile != null ? '${profile!.firstName} ${profile!.lastName}'.trim() : 'Arjun Sharma';
    final title = profile?.ratingTitle ?? 'Diamond Warrior';
    final rating = profile?.rating ?? 1987;
    final school = profile?.schoolName.isNotEmpty == true ? profile!.schoolName : 'Delhi Public School, R.K. Puram';
    final state = profile?.state.isNotEmpty == true ? profile!.state : 'Delhi';
    final country = profile?.country ?? 'India';
    final rollNo = profile?.rollNo ?? 'PM2405017';
    final friendCount = profile?.friendCount ?? 128;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.purple,
                backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: Text(name.isEmpty ? 'Student' : name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(title, style: const TextStyle(fontSize: 9, color: AppColors.purple)),
                      ),
                    ]),
                    Text('Rating $rating', style: const TextStyle(fontSize: 12, color: AppColors.purple)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(school, style: const TextStyle(fontSize: 12)),
          Text('$state, $country', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text('Roll No. $rollNo', style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: profile?.studentClass.isNotEmpty == true ? profile!.studentClass : '12',
            isDense: true,
            items: const [
              DropdownMenuItem(value: '11', child: Text('Class 11')),
              DropdownMenuItem(value: '12', child: Text('Class 12 (Year 2024-25)')),
              DropdownMenuItem(value: 'DROP', child: Text('Dropper')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              try {
                await ApiClient.dio.post('/api/users/me/class/', data: {'student_class': v});
              } catch (_) {}
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Friends ($friendCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Registered on ${profile?.registeredAt.toString().split(' ').first ?? '15 Feb 2024'}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RatingGraphCard extends StatelessWidget {
  final Color borderColor;
  const _RatingGraphCard({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      const FlSpot(0, 900), const FlSpot(1, 1300), const FlSpot(2, 1200),
      const FlSpot(3, 1550), const FlSpot(4, 1450), const FlSpot(5, 1700),
      const FlSpot(6, 1650), const FlSpot(7, 1987),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rating Graph', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => AppColors.purple),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.purple,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.purple.withOpacity(0.12)),
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

class _HeatmapCard extends StatelessWidget {
  final Color borderColor;
  const _HeatmapCard({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity Heatmap', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: List.generate(140, (i) {
              final intensity = (i * 37) % 5;
              final opacity = [0.08, 0.25, 0.45, 0.7, 1.0][intensity];
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: AppColors.purple.withOpacity(opacity), borderRadius: BorderRadius.circular(2)),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Color borderColor;
  final UserProfile? profile;
  const _StatsRow({required this.borderColor, required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ['Current Streak', '${profile?.currentStreakDays ?? 23} Days'],
      ['Max Streak', '${profile?.maxStreakDays ?? 47} Days'],
      ['Max Submissions/Day', '${profile?.maxSubmissionsInADay ?? 18}'],
      ['Accuracy', '82.6%'],
      ['Tests Given', '42'],
    ];
    return Row(
      children: stats
          .map((s) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s[0], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(s[1], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final Map<String, String> rows;
  final Color borderColor;
  const _InfoPanel({required this.title, required this.rows, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.purple)),
          const SizedBox(height: 10),
          ...rows.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12.5),
                    children: [
                      TextSpan(text: '${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: e.value),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
