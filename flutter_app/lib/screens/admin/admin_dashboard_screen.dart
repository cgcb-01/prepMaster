import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../widgets/async_section.dart';
import 'add_questions_screen.dart';
import 'paper_builder_screen.dart';

/// Admin landing: quick counts + entry into the reference-style
/// "Add Questions" flow and the paper builder.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<Map<String, int>> _fetchCounts() async {
    final q = await ApiClient.dio.get('/api/admin/questions/');
    final p = await ApiClient.dio.get('/api/admin/papers/');
    return {
      'questions': (q.data is Map ? q.data['count'] : (q.data as List).length) ?? 0,
      'papers': (p.data is Map ? p.data['count'] : (p.data as List).length) ?? 0,
    };
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
          const Text('Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text('Question bank & paper authoring', style: TextStyle(color: secondaryText, fontSize: 13)),
          const SizedBox(height: 20),
          AsyncSection<Map<String, int>>(
            fetcher: _fetchCounts,
            builder: (context, counts, refresh) => Row(children: [
              _statCard('Questions', '${counts['questions']}', borderColor),
              const SizedBox(width: 16),
              _statCard('Papers', '${counts['papers']}', borderColor),
            ]),
          ),
          const SizedBox(height: 24),
          Wrap(spacing: 16, runSpacing: 16, children: [
            _actionCard(context, icon: Icons.quiz_outlined, title: 'Add Questions', subtitle: 'Pick a destination paper, then add questions one after another — text, LaTeX, images, options.', borderColor: borderColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQuestionsScreen()))),
            _actionCard(context, icon: Icons.dynamic_feed, title: 'Paper Builder', subtitle: 'Create/edit DPP, Chapter Test, PYQ, PAIC, BAIC papers and their settings.', borderColor: borderColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaperBuilderScreen()))),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color borderColor) => Container(
        width: 160, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.purple)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );

  Widget _actionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color borderColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 320, padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.purple, size: 26),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }
}
