import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import '../../services/offline_sync_service.dart';

/// NEET-style OMR interface driven by a real AttemptSession: question
/// paper on the left (two-column, bold, exam-print styling), authentic
/// bubble answer sheet on the right. Bubbles darken solid black on tap,
/// exactly like a real Indian OMR (point #7), and can be changed any time
/// before final submit.
class OmrExamScreen extends StatefulWidget {
  final AttemptSession session;
  const OmrExamScreen({super.key, required this.session});

  @override
  State<OmrExamScreen> createState() => _OmrExamScreenState();
}

class _OmrExamScreenState extends State<OmrExamScreen> {
  final Map<int, int> answers = {}; // questionId -> option index (0=A..3=D)
  late Timer _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    final elapsed = DateTime.now().difference(widget.session.startedAt);
    _remaining = Duration(minutes: widget.session.durationMinutes) - elapsed;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_remaining.inSeconds <= 0) _submit();
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _mark(int questionId, int optionIndex) async {
    setState(() => answers[questionId] = optionIndex);
    final payload = {
      'selected_options': [optionIndex],
      'omr_bubble': String.fromCharCode(65 + optionIndex),
      'status': 'ANSWERED',
    };
    try {
      await ApiClient.dio.patch('/api/exams/attempts/${widget.session.attemptId}/answer/$questionId/', data: payload);
    } catch (_) {
      await OfflineSyncService.queueAnswer(
        attemptId: widget.session.attemptId,
        questionId: questionId,
        payload: payload,
      );
    }
  }

  Future<void> _submit() async {
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
    final mins = _remaining.inMinutes.clamp(0, 999);
    final secs = _remaining.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NEET Attempt — OMR Mode'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${mins}m ${secs.toString().padLeft(2, '0')}s',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ElevatedButton(onPressed: _submit, child: const Text('Submit OMR')),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(child: _QuestionPaperPane(session: widget.session)),
          const VerticalDivider(width: 1),
          Expanded(
            child: _OmrSheetPane(
              session: widget.session,
              answers: answers,
              onMark: _mark,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPaperPane extends StatelessWidget {
  final AttemptSession session;
  const _QuestionPaperPane({required this.session});

  @override
  Widget build(BuildContext context) {
    // Group by subject to mimic the bolded subject-heading, two-column
    // exam-paper style described in point #6.
    final bySubject = <String, List<AttemptQuestion>>{};
    for (final q in session.questions) {
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('NEET\nQUESTION PAPER',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black)),
            ),
            const Divider(color: Colors.black, thickness: 1.4),
            const SizedBox(height: 12),
            for (final subject in bySubject.keys) ...[
              Text(subject.toUpperCase(),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 8),
              // Two-column layout for the question text/options.
              Column(
                children: bySubject[subject]!.map((q) {
                  final idx = session.questions.indexOf(q) + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$idx.  ${q.body}',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        ...q.options.map((o) => Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 3),
                              child: Text('(${o.label}) ${o.text}',
                                  style: const TextStyle(color: Colors.black, fontSize: 12.5)),
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _OmrSheetPane extends StatelessWidget {
  final AttemptSession session;
  final Map<int, int> answers;
  final void Function(int questionId, int optionIndex) onMark;

  const _OmrSheetPane({required this.session, required this.answers, required this.onMark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OMR ANSWER SHEET',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
            const Text('NEET', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 16),
            _rollNoBox(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.4)),
              child: const Text(
                'Instructions:\n• Darken the circle completely.\n• Once marked, tap a new option to change your response.\n• Do not fold or damage the sheet.',
                style: TextStyle(fontSize: 10.5, color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: session.questions.asMap().entries.map((e) {
                final index = e.key + 1;
                final q = e.value;
                return _bubbleRow(index, q.id);
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              width: 220,
              height: 60,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: Colors.black)),
              child: const Text("Candidate's Signature", style: TextStyle(fontSize: 10, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rollNoBox() {
    return Row(
      children: [
        const Text('Roll No.  ', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
        ...List.generate(
          8,
          (i) => Container(
            width: 22,
            height: 26,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _bubbleRow(int displayIndex, int questionId) {
    final selected = answers[questionId];
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$displayIndex', style: const TextStyle(color: Colors.black, fontSize: 11))),
          ...List.generate(4, (i) {
            final label = String.fromCharCode(65 + i);
            final isSelected = selected == i;
            return GestureDetector(
              onTap: () => onMark(questionId, i),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.2),
                  color: isSelected ? Colors.black : Colors.transparent,
                ),
                child: Text(label, style: TextStyle(fontSize: 9, color: isSelected ? Colors.white : Colors.black)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
