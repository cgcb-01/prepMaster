import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import '../../widgets/async_section.dart';
import 'live_contest_screen.dart';

class ContestListScreen extends StatefulWidget {
  const ContestListScreen({super.key});
  @override
  State<ContestListScreen> createState() => _ContestListScreenState();
}

class _ContestListScreenState extends State<ContestListScreen> {
  String _tab = 'PAIC';
  final _sectionKey = GlobalKey<AsyncSectionState<List<ExamPaper>>>();

  Future<List<ExamPaper>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/exams/papers/', queryParameters: {'paper_type': _tab});
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map((j) => ExamPaper.fromJson(j)).toList();
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
          Row(children: [
            ChoiceChip(label: const Text('Premium (PAIC)', style: TextStyle(fontSize: 12)), selected: _tab == 'PAIC', selectedColor: AppColors.purple.withOpacity(0.2), onSelected: (_) { setState(() => _tab = 'PAIC'); _sectionKey.currentState?.refresh(); }),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Biweekly (BAIC)', style: TextStyle(fontSize: 12)), selected: _tab == 'BAIC', selectedColor: AppColors.purple.withOpacity(0.2), onSelected: (_) { setState(() => _tab = 'BAIC'); _sectionKey.currentState?.refresh(); }),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: AsyncSection<List<ExamPaper>>(
              key: _sectionKey,
              fetcher: _fetch,
              builder: (context, papers, refresh) => papers.isEmpty
                  ? Center(child: Text('No contests scheduled right now.', style: TextStyle(color: secondaryText)))
                  : ListView.builder(
                      itemCount: papers.length,
                      itemBuilder: (context, i) {
                        final p = papers[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border.all(color: p.isCurrentlyRunning ? AppColors.purple : borderColor, width: p.isCurrentlyRunning ? 1.6 : 1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      if (p.isPremium) ...[const SizedBox(width: 6), const Icon(Icons.workspace_premium, size: 14, color: Colors.amber)],
                                      if (p.isCurrentlyRunning) ...[
                                        const SizedBox(width: 8),
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                                      ],
                                    ]),
                                    Text('${p.examStyle} · Class ${p.classLevel} · ${p.durationMinutes} min · ${p.totalMarks} marks', style: TextStyle(fontSize: 11.5, color: secondaryText)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: p.isLocked ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveContestScreen(paper: p))),
                                child: Text(p.isLocked ? 'Premium' : (p.isCurrentlyRunning ? 'Enter' : 'View')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
