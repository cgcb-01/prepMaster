import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import '../../services/offline_sync_service.dart';

/// NEET-style OMR interface driven by a real AttemptSession: authentic
/// question paper on the left, bubble answer sheet on the right — matching
/// the reference screenshot exactly (black bold bubbles, roll no boxes,
/// booklet code, signature box).
class OmrExamScreen extends StatefulWidget {
  final AttemptSession session;
  const OmrExamScreen({super.key, required this.session});

  @override
  State<OmrExamScreen> createState() => _OmrExamScreenState();
}

class _OmrExamScreenState extends State<OmrExamScreen> {
  final Map<int, int> answers = {}; // questionId -> option index (0=A..3=D)
  final Map<int, double> numericalAnswers = {};
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
      await ApiClient.dio.patch(
        '/api/exams/attempts/${widget.session.attemptId}/answer/$questionId/',
        data: payload,
      );
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
        title: const Text('NEET Attempt — Booklet Code A'),
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
              child: ElevatedButton(onPressed: _submit, child: const Text('Submit')),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(child: _QuestionPaper(questions: widget.session.questions)),
          const VerticalDivider(width: 1),
          Expanded(
            child: _OmrSheet(
              questions: widget.session.questions,
              answers: answers,
              onMark: _mark,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPaper extends StatelessWidget {
  final List<AttemptQuestion> questions;
  const _QuestionPaper({required this.questions});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'NEET\nQUESTION PAPER',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            ...questions.asMap().entries.map((e) => _questionBlock(e.key + 1, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _questionBlock(int n, AttemptQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n.  ${q.body}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          if (q.imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Image.network(q.imageUrl!, height: 90, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ...q.options.map((opt) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text('(${opt.label}) ${opt.text}',
                    style: const TextStyle(color: Colors.black, fontSize: 12.5)),
              )),
        ],
      ),
    );
  }
}

class _OmrSheet extends StatelessWidget {
  final List<AttemptQuestion> questions;
  final Map<int, int> answers;
  final void Function(int questionId, int option) onMark;
  const _OmrSheet({required this.questions, required this.answers, required this.onMark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OMR ANSWER SHEET',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
            const SizedBox(height: 4),
            const Text('NEET', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 16),
            _rollNoBox(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.4)),
              child: const Text(
                'Instructions:\n• Use Blue/Black Ball Point Pen only.\n• Darken the circle completely.\n• Do not fold or damage the sheet.\n• Once marked, response can be changed by darkening a new option.',
                style: TextStyle(fontSize: 10.5, color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: questions.asMap().entries.map((e) => _bubbleRow(e.key + 1, e.value)).toList(),
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

  Widget _bubbleRow(int displayNumber, AttemptQuestion q) {
    final selected = answers[q.id];
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$displayNumber', style: const TextStyle(color: Colors.black, fontSize: 11))),
          ...List.generate(q.options.length.clamp(0, 4), (i) {
            final label = String.fromCharCode(65 + i);
            final isSelected = selected == i;
            return GestureDetector(
              onTap: () => onMark(q.id, i),
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
