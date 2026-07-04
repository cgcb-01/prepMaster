import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import '../../widgets/async_section.dart';
import '../exam/cbt_exam_screen.dart';
import '../exam/omr_exam_screen.dart';

/// Past Year Questions browser: exam + year filters, backed by
/// /api/exams/papers/?paper_type=PYQ. No sample fallback.
class PyqScreen extends StatefulWidget {
  const PyqScreen({super.key});
  @override
  State<PyqScreen> createState() => _PyqScreenState();
}

class _PyqScreenState extends State<PyqScreen> {
  String? _examFilter;
  String? _yearFilter;
  final _sectionKey = GlobalKey<AsyncSectionState<List<ExamPaper>>>();

  Future<List<ExamPaper>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/exams/papers/', queryParameters: {
      'paper_type': 'PYQ',
      if (_examFilter == 'JEE') 'exam_style': 'JEE_MAIN',
      if (_examFilter == 'NEET') 'exam_style': 'NEET',
    });
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map((j) => ExamPaper.fromJson(j)).toList();
  }

  Future<void> _startAttempt(ExamPaper paper) async {
    if (paper.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium required for this paper.')));
      return;
    }
    final resp = await ApiClient.dio.post('/api/exams/papers/${paper.id}/start/');
    final session = AttemptSession.fromJson(resp.data);
    if (!mounted) return;
    final isNeet = paper.examStyle == 'NEET';
    Navigator.push(context, MaterialPageRoute(builder: (_) => isNeet ? OmrExamScreen(session: session) : CbtExamScreen(session: session)));
  }

  List<String> _years(List<ExamPaper> papers) {
    final s = <String>{};
    for (final p in papers) {
      final m = RegExp(r'20\d{2}').firstMatch(p.title);
      if (m != null) s.add(m.group(0)!);
    }
    return s.toList()..sort((a, b) => b.compareTo(a));
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Past Year Questions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text('Attempt any year — no restriction between JEE and NEET', style: TextStyle(color: secondaryText, fontSize: 12.5)),
              ]),
              DropdownButton<String?>(
                value: _examFilter,
                hint: const Text('All Exams'),
                items: const [DropdownMenuItem(value: null, child: Text('All Exams')), DropdownMenuItem(value: 'JEE', child: Text('JEE')), DropdownMenuItem(value: 'NEET', child: Text('NEET'))],
                onChanged: (v) {
                  setState(() { _examFilter = v; _yearFilter = null; });
                  _sectionKey.currentState?.refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AsyncSection<List<ExamPaper>>(
              key: _sectionKey,
              fetcher: _fetch,
              builder: (context, papers, refresh) {
                final years = _years(papers);
                final filtered = papers.where((p) => _yearFilter == null || p.title.contains(_yearFilter!)).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (years.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButton<String?>(
                          value: _yearFilter,
                          hint: const Text('All Years'),
                          items: [const DropdownMenuItem(value: null, child: Text('All Years')), ...years.map((y) => DropdownMenuItem(value: y, child: Text(y)))],
                          onChanged: (v) => setState(() => _yearFilter = v),
                        ),
                      ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text('No past papers match these filters.', style: TextStyle(color: secondaryText)))
                          : ListView(children: filtered.map((p) => _paperRow(p, borderColor, secondaryText)).toList()),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _paperRow(ExamPaper p, Color borderColor, Color secondaryText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.history_edu, size: 18, color: AppColors.purple)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  if (p.isPremium) ...[const SizedBox(width: 6), const Icon(Icons.workspace_premium, size: 13, color: Colors.amber)],
                ]),
                Text('${p.examStyle.replaceAll('_', ' ')} · ${p.durationMinutes} min · ${p.totalMarks} marks', style: TextStyle(fontSize: 11, color: secondaryText)),
              ],
            ),
          ),
          OutlinedButton(onPressed: () => _startAttempt(p), child: Text(p.isLocked ? 'Premium' : 'Attempt')),
        ],
      ),
    );
  }
}
