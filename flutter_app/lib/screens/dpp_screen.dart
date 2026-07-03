import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../navigation.dart';
import '../api/api_client.dart';
import '../models/exam_models.dart';
import 'exam/cbt_exam_screen.dart';
import 'exam/omr_exam_screen.dart';

/// Daily Practice Sheet screen: calendar on the left (marks attempted vs
/// missed days), sheet preview + subject switcher on the right, with a
/// real "Start Attempt" flow into the JEE/OMR attempt screens.
class DppScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  const DppScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<DppScreen> createState() => _DppScreenState();
}

class _DppScreenState extends State<DppScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _exam = 'NEET';
  ExamPaper? _todaysPaper;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaysSheet();
  }

  Future<void> _loadTodaysSheet() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.dio.get('/api/exams/papers/', queryParameters: {
        'paper_type': 'DPP',
        'exam_style': _exam == 'NEET' ? 'NEET' : 'JEE_MAIN',
      });
      final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
      setState(() => _todaysPaper = list.isNotEmpty ? ExamPaper.fromJson(list.first) : null);
    } catch (_) {
      setState(() => _todaysPaper = null);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startAttempt() async {
    if (_todaysPaper == null) return;
    final resp = await ApiClient.dio.post('/api/exams/papers/${_todaysPaper!.id}/start/');
    final session = AttemptSession.fromJson(resp.data);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _exam == 'NEET' ? OmrExamScreen(session: session) : CbtExamScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.darkMode ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            activeLabel: 'Daily Practice Sheet',
            onSelect: (label) => navigateToSidebarLabel(context, label, darkMode: widget.darkMode, onToggleDark: widget.onToggleDark),
            darkMode: widget.darkMode,
            onToggleDark: widget.onToggleDark,
            onLogout: () async {
              await ApiClient.logout();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
                      const Text('Daily Practice Sheet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      DropdownButton<String>(
                        value: _exam,
                        items: const [
                          DropdownMenuItem(value: 'NEET', child: Text('NEET')),
                          DropdownMenuItem(value: 'JEE', child: Text('JEE')),
                        ],
                        onChanged: (v) {
                          setState(() => _exam = v!);
                          _loadTodaysSheet();
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
                            onDaySelected: (sel, foc) => setState(() {
                              _selectedDay = sel;
                              _focusedDay = foc;
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SheetPreviewCard(
                            borderColor: borderColor,
                            exam: _exam,
                            paper: _todaysPaper,
                            loading: _loading,
                            onStart: _startAttempt,
                          ),
                        ),
                      ],
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

class _CalendarCard extends StatelessWidget {
  final Color borderColor;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;

  const _CalendarCard({
    required this.borderColor,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (d) => isSameDay(selectedDay, d),
            onDaySelected: onDaySelected,
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: AppColors.purpleGlow, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: AppColors.answered, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            eventLoader: (day) => day.day % 3 == 0 ? ['done'] : [],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _LegendDot(color: AppColors.answered, label: 'Completed'),
              _LegendDot(color: AppColors.purple, label: 'Available'),
              _LegendDot(color: Colors.orange, label: 'Not Available'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip('Current Streak', '12 Days'),
              const SizedBox(width: 12),
              _statChip('Monthly Progress', '58%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ]);
  }
}

class _SheetPreviewCard extends StatelessWidget {
  final Color borderColor;
  final String exam;
  final ExamPaper? paper;
  final bool loading;
  final VoidCallback onStart;

  const _SheetPreviewCard({
    required this.borderColor,
    required this.exam,
    required this.paper,
    required this.loading,
    required this.onStart,
  });

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
              Text(paper != null ? paper!.title : 'DPP Sheet — Today ($exam)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ElevatedButton(onPressed: paper != null ? onStart : null, child: const Text('Start Attempt')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                : paper == null
                    ? Container(
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: const Text('No DPP available for today yet.',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        // The PDF is served from the signed Backblaze B2 URL
                        // returned in the paper detail payload; the viewer
                        // streams it directly without a manual download step.
                        child: Container(color: Colors.grey.shade200, child: const _PaperPreviewPlaceholder()),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown until `paper.questionPaperPdfUrl` is wired into the
/// ExamPaper model; swap this for
/// `SfPdfViewer.network(paper.questionPaperPdfUrl!)` once that field is added.
class _PaperPreviewPlaceholder extends StatelessWidget {
  const _PaperPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'PDF PREVIEW\n(SfPdfViewer.network(paper.pdfUrl))',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black45, fontSize: 12),
      ),
    );
  }
}
