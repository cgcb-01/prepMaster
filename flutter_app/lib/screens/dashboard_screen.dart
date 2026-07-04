import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../api/api_client.dart';
import '../models/user_profile.dart';
import '../widgets/async_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<UserProfile> _fetch() async {
    final resp = await ApiClient.dio.get('/api/users/me/');
    return UserProfile.fromJson(resp.data);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text('Your public profile and performance overview', style: TextStyle(color: secondaryText, fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(
            child: AsyncSection<UserProfile>(
              fetcher: _fetch,
              builder: (context, profile, refresh) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 280, child: _ProfileCard(borderColor: borderColor, profile: profile, onClassChanged: refresh)),
                          const SizedBox(width: 16),
                          Expanded(child: _RatingGraphCard(borderColor: borderColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StatsRow(borderColor: borderColor, profile: profile),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _InfoPanel(title: 'Public', borderColor: borderColor, rows: const {})),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InfoPanel(
                            title: 'Private (Only You)',
                            borderColor: borderColor,
                            rows: {
                              'Weak Subjects': (profile.weakSubjects ?? []).isEmpty ? 'None yet' : profile.weakSubjects!.join(', '),
                              'Weak Chapters': (profile.weakChapters ?? []).isEmpty ? 'None yet' : profile.weakChapters!.join(', '),
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
  final UserProfile profile;
  final VoidCallback onClassChanged;
  const _ProfileCard({required this.borderColor, required this.profile, required this.onClassChanged});

  @override
  Widget build(BuildContext context) {
    final name = '${profile.firstName} ${profile.lastName}'.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: AppColors.purple, backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? profile.username : name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                  Text('Rating ${profile.rating} · ${profile.ratingTitle}', style: const TextStyle(fontSize: 12, color: AppColors.purple)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(profile.schoolName.isEmpty ? 'No school set' : profile.schoolName, style: const TextStyle(fontSize: 12)),
          Text('${profile.state}, ${profile.country}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text('Roll No. ${profile.rollNo}', style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: profile.studentClass.isNotEmpty ? profile.studentClass : '12',
            isDense: true,
            items: const [
              DropdownMenuItem(value: '11', child: Text('Class 11')),
              DropdownMenuItem(value: '12', child: Text('Class 12')),
              DropdownMenuItem(value: 'DROP', child: Text('Dropper')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              await ApiClient.dio.post('/api/users/me/class/', data: {'student_class': v});
              onClassChanged();
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Friends (${profile.friendCount})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Registered ${profile.registeredAt.toString().split(' ').first}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _RatingGraphCard extends StatefulWidget {
  final Color borderColor;
  const _RatingGraphCard({required this.borderColor});
  @override
  State<_RatingGraphCard> createState() => _RatingGraphCardState();
}

class _RatingGraphCardState extends State<_RatingGraphCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<List<double>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/rating/history/');
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map<double>((j) => (j['rating_after'] as num).toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: widget.borderColor), borderRadius: BorderRadius.circular(12)),
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rating Graph', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<double>>(
              future: _fetch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.purple));
                final points = snapshot.data!;
                if (points.isEmpty) return const Center(child: Text('No rated events yet.', style: TextStyle(color: Colors.grey, fontSize: 12)));
                final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
                return LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: AppColors.purple, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.purple.withOpacity(0.12)))],
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Color borderColor;
  final UserProfile profile;
  const _StatsRow({required this.borderColor, required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ['Current Streak', '${profile.currentStreakDays} Days'],
      ['Max Streak', '${profile.maxStreakDays} Days'],
      ['Max Submissions/Day', '${profile.maxSubmissionsInADay}'],
    ];
    return Row(
      children: stats.map((s) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s[0], style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(s[1], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),
      )).toList(),
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
                child: RichText(text: TextSpan(style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12.5), children: [
                  TextSpan(text: '${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: e.value),
                ])),
              )),
        ],
      ),
    );
  }
}
