import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../widgets/async_section.dart';

enum AnnouncementType { contestUpcoming, contestDateChange, resultOut, topperList, general }

class Announcement {
  final String title, body;
  final DateTime postedAt;
  final AnnouncementType type;
  Announcement({required this.title, required this.body, required this.postedAt, required this.type});

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        postedAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        type: _typeFrom(j['exam_type']),
      );

  static AnnouncementType _typeFrom(String? category) {
    switch (category) {
      case 'RESULT': return AnnouncementType.resultOut;
      case 'TOPPER': return AnnouncementType.topperList;
      case 'DATE_CHANGE': return AnnouncementType.contestDateChange;
      case 'CONTEST': return AnnouncementType.contestUpcoming;
      default: return AnnouncementType.general;
    }
  }
}

/// Home: real announcements pulled from the backend, Codeforces-blog style
/// (point #3). No sample fallback — a failed fetch shows Retry, not fake posts.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<List<Announcement>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/content/announcements/');
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map((j) => Announcement.fromJson(j)).toList();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Home', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text('Announcements, contest updates & results', style: TextStyle(color: secondaryText, fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(
            child: AsyncSection<List<Announcement>>(
              fetcher: _fetch,
              builder: (context, announcements, refresh) => RefreshIndicator(
                onRefresh: () async => refresh(),
                child: announcements.isEmpty
                    ? Center(child: Text('No announcements yet.', style: TextStyle(color: secondaryText)))
                    : ListView(
                        children: announcements.map((a) => Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
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
                                        Text(_timeAgo(a.postedAt), style: TextStyle(fontSize: 10.5, color: secondaryText)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                      ),
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
