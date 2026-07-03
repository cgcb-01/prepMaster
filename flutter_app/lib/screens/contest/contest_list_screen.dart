import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_sidebar.dart';
import '../../navigation.dart';
import '../../api/api_client.dart';
import '../../models/exam_models.dart';
import 'live_contest_screen.dart';

/// Lists PAIC (Premium All India Contest) and BAIC (Biweekly All India
/// Contest) papers with countdowns and entry into the live attempt / live
/// leaderboard flow (point #12/16).
class ContestListScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  const ContestListScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<ContestListScreen> createState() => _ContestListScreenState();
}

class _ContestListScreenState extends State<ContestListScreen> {
  String _tab = 'PAIC';
  List<ExamPaper> _papers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.dio.get('/api/exams/papers/', queryParameters: {'paper_type': _tab});
      final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
      setState(() => _papers = list.map<ExamPaper>((j) => ExamPaper.fromJson(j)).toList());
    } catch (_) {
      setState(() => _papers = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.darkMode ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = widget.darkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            activeLabel: 'Premium All India Contest (PAIC)',
            onSelect: (label) => navigateToSidebarLabel(context, label, darkMode: widget.darkMode, onToggleDark: widget.onToggleDark),
            darkMode: widget.darkMode,
            onToggleDark: widget.onToggleDark,
            onLogout: () async {
              await ApiClient.logout();
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _tabButton('PAIC', 'Premium All India Contest'),
                      const SizedBox(width: 8),
                      _tabButton('BAIC', 'Biweekly All India Contest'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                        : _papers.isEmpty
                            ? Center(child: Text('No contests scheduled right now.', style: TextStyle(color: secondaryText)))
                            : ListView.builder(
                                itemCount: _papers.length,
                                itemBuilder: (context, i) {
                                  final p = _papers[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: p.isCurrentlyRunning ? AppColors.purple : borderColor,
                                          width: p.isCurrentlyRunning ? 1.6 : 1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                if (p.isPremium) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.workspace_premium, size: 14, color: Colors.amber),
                                                ],
                                                if (p.isCurrentlyRunning) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('LIVE',
                                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                                                  ),
                                                ],
                                              ]),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${p.examStyle} · Class ${p.classLevel} · ${p.durationMinutes} min · ${p.totalMarks} marks',
                                                style: TextStyle(fontSize: 11.5, color: secondaryText),
                                              ),
                                              if (p.scheduledStart != null)
                                                Text('Starts: ${p.scheduledStart}', style: TextStyle(fontSize: 11, color: secondaryText)),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: p.isLocked
                                              ? null
                                              : () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (_) => LiveContestScreen(paper: p)),
                                                  ),
                                          child: Text(p.isLocked ? 'Premium' : (p.isCurrentlyRunning ? 'Enter' : 'View')),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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

  Widget _tabButton(String value, String label) {
    final active = _tab == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: active,
      selectedColor: AppColors.purple.withOpacity(0.2),
      onSelected: (_) {
        setState(() => _tab = value);
        _load();
      },
    );
  }
}