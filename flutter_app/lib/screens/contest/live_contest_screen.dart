import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import '../../models/misc_models.dart';
import '../exam/cbt_exam_screen.dart';
import '../exam/omr_exam_screen.dart';

/// Live PAIC/BAIC screen: shows a countdown before start, an "Enter Exam"
/// button that launches the appropriate CBT/OMR attempt flow, and — once
/// the user has submitted — a live-updating leaderboard streamed over
/// WebSocket from apps.leaderboard.consumers.LeaderboardConsumer.
class LiveContestScreen extends StatefulWidget {
  final ExamPaper paper;
  const LiveContestScreen({super.key, required this.paper});

  @override
  State<LiveContestScreen> createState() => _LiveContestScreenState();
}

class _LiveContestScreenState extends State<LiveContestScreen> {
  WebSocketChannel? _channel;
  List<LeaderboardEntry> _leaderboard = [];
  bool _connected = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _connectLeaderboard();
  }

  void _connectLeaderboard() {
    final wsBase = ApiClient.baseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws/leaderboard/${widget.paper.id}/'));
    _channel!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw);
        final data = (msg['data'] as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
        setState(() {
          _leaderboard = data;
          _connected = true;
        });
      },
      onError: (_) => setState(() => _connected = false),
      onDone: () => setState(() => _connected = false),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _enterExam() async {
    final resp = await ApiClient.dio.post('/api/exams/papers/${widget.paper.id}/start/');
    final session = AttemptSession.fromJson(resp.data);

    final isNeet = widget.paper.examStyle == 'NEET';
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isNeet ? OmrExamScreen(session: session) : CbtExamScreen(session: session),
      ),
    );

    if (result == true) {
      setState(() => _hasSubmitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paper;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(children: [
                Icon(Icons.circle, size: 8, color: _connected ? Colors.greenAccent : Colors.grey),
                const SizedBox(width: 6),
                Text(_connected ? 'Live' : 'Connecting…', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.examStyle} · Class ${p.classLevel} · ${p.durationMinutes} min',
                      style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  if (p.isCurrentlyRunning && !_hasSubmitted)
                    ElevatedButton.icon(
                      onPressed: _enterExam,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Enter Exam'),
                    )
                  else if (_hasSubmitted)
                    const Text('Submitted — waiting for the contest to end for final ranks.',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 24),
                  const Text('Live Leaderboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, i) {
                        final e = _leaderboard[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: (e.rank ?? 99) <= 3 ? AppColors.purple : Colors.grey.shade700,
                            child: Text('${e.rank}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                          title: Text(e.user, style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${e.school} · ${e.accuracy.toStringAsFixed(1)}% acc', style: const TextStyle(fontSize: 10.5)),
                          trailing: Text(e.score.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
