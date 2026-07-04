import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import '../../services/offline_sync_service.dart';

enum QStatus { notVisited, notAnswered, answered, marked, answeredMarked }

class _LocalAnswerState {
  Set<int> selected = {};
  double? numerical;
  QStatus status = QStatus.notVisited;
  int timeSpentSeconds = 0;
}

/// JEE-style CBT interface driven by a real AttemptSession fetched from
/// POST /api/exams/papers/<id>/start/. Saves each answer to the backend
/// (or queues it offline via OfflineSyncService when there's no connection)
/// and finally submits the attempt, returning `true` to the caller.
class CbtExamScreen extends StatefulWidget {
  final AttemptSession session;
  const CbtExamScreen({super.key, required this.session});

  @override
  State<CbtExamScreen> createState() => _CbtExamScreenState();
}

class _CbtExamScreenState extends State<CbtExamScreen> {
  late final Map<int, _LocalAnswerState> answers;
  int current = 0;
  late Timer _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    answers = {for (final q in widget.session.questions) q.id: _LocalAnswerState()};
    answers[widget.session.questions.first.id]!.status = QStatus.notAnswered;

    final elapsed = DateTime.now().difference(widget.session.startedAt);
    _remaining = Duration(minutes: widget.session.durationMinutes) - elapsed;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_remaining.inSeconds <= 0) _submit(auto: true);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Color _statusColor(QStatus s) {
    switch (s) {
      case QStatus.answered: return AppColors.answered;
      case QStatus.marked: return AppColors.markedForReview;
      case QStatus.answeredMarked: return AppColors.answeredAndMarked;
      case QStatus.notAnswered: return AppColors.notAnswered;
      case QStatus.notVisited: return AppColors.notVisited;
    }
  }

  Future<void> _persistAnswer(AttemptQuestion q) async {
    final a = answers[q.id]!;
    final payload = {
      'selected_options': a.selected.toList(),
      'numerical_response': a.numerical,
      'status': a.status.name.toUpperCase(),
      'time_spent_seconds': a.timeSpentSeconds,
    };
    try {
      await ApiClient.dio.patch('/api/exams/attempts/${widget.session.attemptId}/answer/${q.id}/', data: payload);
    } catch (_) {
      // Offline — queue for later sync instead of losing the response.
      await OfflineSyncService.queueAnswer(
        attemptId: widget.session.attemptId,
        questionId: q.id,
        payload: payload,
      );
    }
  }

  void _go(int index) {
    setState(() {
      current = index;
      final q = widget.session.questions[current];
      if (answers[q.id]!.status == QStatus.notVisited) {
        answers[q.id]!.status = QStatus.notAnswered;
      }
    });
  }

  Future<void> _saveAndNext() async {
    final q = widget.session.questions[current];
    final a = answers[q.id]!;
    a.status = a.selected.isNotEmpty || a.numerical != null ? QStatus.answered : QStatus.notAnswered;
    await _persistAnswer(q);
    if (current < widget.session.questions.length - 1) _go(current + 1);
    setState(() {});
  }

  Future<void> _submit({bool auto = false}) async {
    _ticker.cancel();
    try {
      await ApiClient.dio.post('/api/exams/attempts/${widget.session.attemptId}/submit/');
    } catch (_) {
      await OfflineSyncService.queueSubmit(widget.session.attemptId);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.session.questions[current];
    final a = answers[q.id]!;
    final mins = _remaining.inMinutes.clamp(0, 999);
    final secs = _remaining.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JEE Attempt'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${mins}m ${secs.toString().padLeft(2, '0')}s',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.subject, style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Q${current + 1}.', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  _renderBody(q.body),
                  const SizedBox(height: 20),
                  if (q.questionType == 'NUMERICAL')
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Enter numerical answer'),
                      onChanged: (v) => a.numerical = double.tryParse(v),
                    )
                  else
                    ...List.generate(q.options.length, (i) {
                      final isMulti = q.questionType == 'MCQ_MULTIPLE';
                      final selected = a.selected.contains(i);
                      return isMulti
                          ? CheckboxListTile(
                              value: selected,
                              onChanged: (v) => setState(() => v! ? a.selected.add(i) : a.selected.remove(i)),
                              title: Text(q.options[i].text),
                              activeColor: AppColors.purple,
                            )
                          : RadioListTile<int>(
                              value: i,
                              groupValue: a.selected.isEmpty ? null : a.selected.first,
                              onChanged: (v) => setState(() => a.selected = {v!}),
                              title: Text(q.options[i].text),
                              activeColor: AppColors.purple,
                            );
                    }),
                  const Spacer(),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    ElevatedButton(onPressed: _saveAndNext, child: const Text('Save & Next')),
                    OutlinedButton(
                      onPressed: () => setState(() => a.status = QStatus.answeredMarked),
                      child: const Text('Save & Mark for Review'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => a.status = QStatus.marked),
                      child: const Text('Mark for Review'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() { a.selected.clear(); a.numerical = null; }),
                      child: const Text('Clear Response'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: current > 0 ? () => _go(current - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                      TextButton.icon(
                        onPressed: current < widget.session.questions.length - 1 ? () => _go(current + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Question Palette', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(widget.session.questions.length, (i) {
                      final qq = widget.session.questions[i];
                      final st = answers[qq.id]!.status;
                      return GestureDetector(
                        onTap: () => _go(i),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _statusColor(st),
                            borderRadius: BorderRadius.circular(6),
                            border: i == current ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: () => _submit(), child: const Text('Submit Test')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderBody(String body) {
    // Body may mix plain text with $...$ LaTeX segments; render with Math.tex
    // when the whole string looks like LaTeX, else fall back to plain text.
    if (body.contains(r'\') || body.contains('^') || body.contains('_')) {
      try {
        return Math.tex(body.replaceAll('\$', ''), textStyle: const TextStyle(fontSize: 17));
      } catch (_) {}
    }
    return Text(body, style: const TextStyle(fontSize: 15));
  }
}
