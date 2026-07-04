import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/content_models.dart';
import '../../widgets/async_section.dart';

/// Chapterwise Preparation (point #11): Stage 1 subject cards -> Stage 2
/// chapter list -> Stage 3 module tiles + Smart Planner. Every stage is
/// backed by a real /api/content/ call via AsyncSection — no fallback
/// sample data, so a broken backend shows Retry instead of fake chapters.
class ChapterwiseScreen extends StatefulWidget {
  const ChapterwiseScreen({super.key});
  @override
  State<ChapterwiseScreen> createState() => _ChapterwiseScreenState();
}

class _ChapterwiseScreenState extends State<ChapterwiseScreen> {
  String _exam = 'JEE';
  SubjectSummary? _selectedSubject;
  ChapterSummary? _selectedChapter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _selectedChapter != null
          ? _ModuleStage(chapterId: _selectedChapter!.id, chapterName: _selectedChapter!.name, onBack: () => setState(() => _selectedChapter = null))
          : _selectedSubject != null
              ? _ChapterListStage(subject: _selectedSubject!, onBack: () => setState(() => _selectedSubject = null), onSelectChapter: (c) => setState(() => _selectedChapter = c))
              : _SubjectStage(exam: _exam, onExamChanged: (v) => setState(() => _exam = v), onSelectSubject: (s) => setState(() => _selectedSubject = s)),
    );
  }
}

class _SubjectStage extends StatelessWidget {
  final String exam;
  final ValueChanged<String> onExamChanged;
  final ValueChanged<SubjectSummary> onSelectSubject;
  const _SubjectStage({required this.exam, required this.onExamChanged, required this.onSelectSubject});

  Future<List<SubjectSummary>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/content/subjects/', queryParameters: {'exam': exam});
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map((j) => SubjectSummary.fromJson(j)).toList();
  }

  IconData _iconFor(String s) => {'Physics': Icons.bolt, 'Chemistry': Icons.science, 'Mathematics': Icons.functions, 'Biology': Icons.biotech}[s] ?? Icons.menu_book;
  Color _colorFor(String s) => {'Physics': AppColors.purple, 'Chemistry': const Color(0xFF10B981), 'Mathematics': const Color(0xFF3B82F6), 'Biology': const Color(0xFFEC4899)}[s] ?? AppColors.purple;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Chapterwise Preparation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text('Master chapters with focused practice and smart planning', style: TextStyle(color: secondaryText, fontSize: 12.5)),
            ]),
            DropdownButton<String>(
              value: exam,
              items: const [DropdownMenuItem(value: 'JEE', child: Text('JEE')), DropdownMenuItem(value: 'NEET', child: Text('NEET'))],
              onChanged: (v) => onExamChanged(v!),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Choose Subject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 14),
        Expanded(
          child: AsyncSection<List<SubjectSummary>>(
            key: ValueKey(exam),
            fetcher: _fetch,
            builder: (context, subjects, refresh) => subjects.isEmpty
                ? Text('No subjects configured for $exam yet.', style: TextStyle(color: secondaryText))
                : Wrap(
                    spacing: 16, runSpacing: 16,
                    children: subjects.map((s) {
                      final color = _colorFor(s.name);
                      return InkWell(
                        onTap: () => onSelectSubject(s),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 190, padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(_iconFor(s.name), color: color, size: 22)),
                              const SizedBox(height: 16),
                              Text(s.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.4)),
                              const SizedBox(height: 4),
                              Text('${s.chapterCount} Chapters', style: TextStyle(fontSize: 11.5, color: secondaryText)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ChapterListStage extends StatefulWidget {
  final SubjectSummary subject;
  final VoidCallback onBack;
  final ValueChanged<ChapterSummary> onSelectChapter;
  const _ChapterListStage({required this.subject, required this.onBack, required this.onSelectChapter});

  @override
  State<_ChapterListStage> createState() => _ChapterListStageState();
}

class _ChapterListStageState extends State<_ChapterListStage> {
  String _search = '';

  Future<List<ChapterSummary>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/content/subjects/${widget.subject.id}/chapters/');
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map((j) => ChapterSummary.fromJson(j)).toList();
  }

  Color _difficultyColor(String d) => d == 'EASY' ? AppColors.answered : d == 'HARD' ? Colors.redAccent : Colors.orange;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
          Text('${widget.subject.name} Chapters', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search Chapter', prefixIcon: Icon(Icons.search, size: 18), isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AsyncSection<List<ChapterSummary>>(
            fetcher: _fetch,
            builder: (context, chapters, refresh) {
              final filtered = chapters.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();
              if (filtered.isEmpty) return Text('No chapters found.', style: TextStyle(color: secondaryText));
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return InkWell(
                    onTap: () => widget.onSelectChapter(c),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.purple))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                Row(children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _difficultyColor(c.difficulty).withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(c.difficulty, style: TextStyle(fontSize: 9.5, color: _difficultyColor(c.difficulty), fontWeight: FontWeight.w700))),
                                  const SizedBox(width: 8),
                                  Text('${c.modulesTotal} Modules', style: TextStyle(fontSize: 11, color: secondaryText)),
                                ]),
                              ],
                            ),
                          ),
                          Text('${c.completionPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModuleStage extends StatelessWidget {
  final int chapterId;
  final String chapterName;
  final VoidCallback onBack;
  const _ModuleStage({required this.chapterId, required this.chapterName, required this.onBack});

  Future<ChapterDetail> _fetch() async {
    final resp = await ApiClient.dio.get('/api/content/chapters/$chapterId/');
    return ChapterDetail.fromJson(resp.data);
  }

  IconData _iconForModule(String type) => {
        'THEORY': Icons.menu_book, 'FORMULA': Icons.functions, 'SOLVED': Icons.check_circle_outline,
        'DPP': Icons.today, 'PYQ': Icons.history_edu, 'REVISION': Icons.timeline,
        'TEST': Icons.assignment_turned_in, 'ADVANCED': Icons.trending_up,
      }[type] ?? Icons.book;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AsyncSection<ChapterDetail>(
      fetcher: _fetch,
      builder: (context, detail, refresh) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
                  Text(detail.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: detail.modules.isEmpty
                      ? const Text('No modules added for this chapter yet.', style: TextStyle(color: Colors.grey))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.4),
                          itemCount: detail.modules.length,
                          itemBuilder: (context, i) {
                            final m = detail.modules[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Icon(_iconForModule(m.moduleType), color: AppColors.purple, size: 20),
                                    if (m.isPremium) const Icon(Icons.workspace_premium, size: 14, color: Colors.amber),
                                  ]),
                                  const Spacer(),
                                  Text('${m.order}. ${m.title}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
