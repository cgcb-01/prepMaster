import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../api/api_client.dart';
import '../models/exam_models.dart';
import '../widgets/async_section.dart';
import 'exam/cbt_exam_screen.dart';
import 'exam/omr_exam_screen.dart';

class DppScreen extends StatefulWidget {
  const DppScreen({super.key});
  @override
  State<DppScreen> createState() => _DppScreenState();
}

class _DppScreenState extends State<DppScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _exam = 'NEET';
  final _sectionKey = GlobalKey<AsyncSectionState<ExamPaper?>>();

  Future<ExamPaper?> _fetchTodaysSheet() async {
    final resp = await ApiClient.dio.get('/api/exams/papers/', queryParameters: {
      'paper_type': 'DPP',
      'exam_style': _exam == 'NEET' ? 'NEET' : 'JEE_MAIN',
    });
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.isNotEmpty ? ExamPaper.fromJson(list.first) : null;
  }

  Future<void> _startAttempt(ExamPaper paper) async {
    final resp = await ApiClient.dio.post('/api/exams/papers/${paper.id}/start/');
    final session = AttemptSession.fromJson(resp.data);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _exam == 'NEET' ? OmrExamScreen(session: session) : CbtExamScreen(session: session),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Practice Sheet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              DropdownButton<String>(
                value: _exam,
                items: const [DropdownMenuItem(value: 'NEET', child: Text('NEET')), DropdownMenuItem(value: 'JEE', child: Text('JEE'))],
                onChanged: (v) {
                  setState(() => _exam = v!);
                  _sectionKey.currentState?.refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: _CalendarCard(
                    borderColor: borderColor,
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: (sel, foc) => setState(() { _selectedDay = sel; _focusedDay = foc; }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AsyncSection<ExamPaper?>(
                    key: _sectionKey,
                    fetcher: _fetchTodaysSheet,
                    builder: (context, paper, refresh) => _SheetPreviewCard(borderColor: borderColor, paper: paper, onStart: paper == null ? null : () => _startAttempt(paper)),
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

class _CalendarCard extends StatelessWidget {
  final Color borderColor;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;
  const _CalendarCard({required this.borderColor, required this.focusedDay, required this.selectedDay, required this.onDaySelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2027, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (d) => isSameDay(selectedDay, d),
        onDaySelected: onDaySelected,
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: AppColors.purpleGlow, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      ),
    );
  }
}

class _SheetPreviewCard extends StatelessWidget {
  final Color borderColor;
  final ExamPaper? paper;
  final VoidCallback? onStart;
  const _SheetPreviewCard({required this.borderColor, required this.paper, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(paper?.title ?? 'No DPP available today', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ElevatedButton(onPressed: onStart, child: const Text('Start Attempt')),
            ],
          ),
        ],
      ),
    );
  }
}
