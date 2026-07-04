import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/misc_models.dart';
import '../../widgets/async_section.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _examFilter = 'JEE';
  bool _friendsOnly = false;
  final _sectionKey = GlobalKey<AsyncSectionState<List<LeaderboardEntry>>>();

  Future<List<LeaderboardEntry>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/leaderboard/global/', queryParameters: {
      'target_exam': _examFilter,
      if (_friendsOnly) 'friends_only': 'true',
    });
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.asMap().entries.map((e) => LeaderboardEntry.fromJson({
          ...e.value,
          'rank': e.key + 1,
          'user': ('${e.value['first_name']} ${e.value['last_name']}').trim().isEmpty ? e.value['username'] : '${e.value['first_name']} ${e.value['last_name']}',
          'school': e.value['school_name'],
          'score': e.value['rating'],
        })).toList();
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Leaderboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Row(children: [
                DropdownButton<String>(
                  value: _examFilter,
                  items: const [DropdownMenuItem(value: 'JEE', child: Text('JEE')), DropdownMenuItem(value: 'NEET', child: Text('NEET'))],
                  onChanged: (v) { setState(() => _examFilter = v!); _sectionKey.currentState?.refresh(); },
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('Friends only'),
                  selected: _friendsOnly,
                  selectedColor: AppColors.purple.withOpacity(0.2),
                  onSelected: (v) { setState(() => _friendsOnly = v); _sectionKey.currentState?.refresh(); },
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AsyncSection<List<LeaderboardEntry>>(
              key: _sectionKey,
              fetcher: _fetch,
              builder: (context, entries, refresh) => entries.isEmpty
                  ? Center(child: Text('No ranked users yet.', style: TextStyle(color: secondaryText)))
                  : Container(
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          final isTop3 = (e.rank ?? 99) <= 3;
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: isTop3 ? AppColors.purple : Colors.grey.shade700, child: Text('${e.rank}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                            title: Text(e.user, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: Text(e.school, style: TextStyle(fontSize: 11.5, color: secondaryText)),
                            trailing: Text('${e.score.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.purple)),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
