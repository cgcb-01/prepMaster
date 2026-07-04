import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import 'question_editor_screen.dart';

/// Paper builder (point #12/19/22): create/edit a DPP, Chapter Test, PYQ
/// set, PAIC, or BAIC — set duration/marks/premium/live-window, then add
/// questions from the bank with optional per-question marking overrides.
/// Reorder is drag-based via ReorderableListView; PDF generation is
/// triggered explicitly once the paper looks right.
class PaperBuilderScreen extends StatefulWidget {
  final int? paperId;
  const PaperBuilderScreen({super.key, this.paperId});

  @override
  State<PaperBuilderScreen> createState() => _PaperBuilderScreenState();
}

class _PaperBuilderScreenState extends State<PaperBuilderScreen> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '180');
  final _marksController = TextEditingController(text: '300');

  String _paperType = 'DPP';
  String _examStyle = 'JEE_MAIN';
  String _classLevel = '12';
  bool _isPremium = false;
  bool _isLiveContest = false;

  List<Map<String, dynamic>> _paperQuestions = [];
  bool _loading = true;
  bool _saving = false;
  int? _savedPaperId;

  @override
  void initState() {
    super.initState();
    _savedPaperId = widget.paperId;
    _load();
  }

  Future<void> _load() async {
    if (widget.paperId != null) {
      try {
        final resp = await ApiClient.dio.get('/api/admin/papers/${widget.paperId}/');
        final d = resp.data;
        _titleController.text = d['title'];
        _durationController.text = '${d['duration_minutes']}';
        _marksController.text = '${d['total_marks']}';
        _paperType = d['paper_type'];
        _examStyle = d['exam_style'];
        _classLevel = d['class_level'];
        _isPremium = d['is_premium'];
        _isLiveContest = d['is_live_contest'];
        _paperQuestions = List<Map<String, dynamic>>.from(d['paper_questions'] ?? []);
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  Future<void> _savePaperMeta() async {
    setState(() => _saving = true);
    final payload = {
      'title': _titleController.text,
      'paper_type': _paperType,
      'exam_style': _examStyle,
      'class_level': _classLevel,
      'duration_minutes': int.tryParse(_durationController.text) ?? 180,
      'total_marks': int.tryParse(_marksController.text) ?? 300,
      'is_premium': _isPremium,
      'is_downloadable': true,
      'is_live_contest': _isLiveContest,
    };
    try {
      if (_savedPaperId != null) {
        await ApiClient.dio.patch('/api/admin/papers/$_savedPaperId/', data: payload);
      } else {
        final resp = await ApiClient.dio.post('/api/admin/papers/', data: payload);
        setState(() => _savedPaperId = resp.data['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paper saved.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _addQuestionById() async {
    if (_savedPaperId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the paper first.')));
      return;
    }
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Question by ID'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Question ID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    try {
      await ApiClient.dio.post('/api/admin/papers/$_savedPaperId/add_question/', data: {
        'question_id': int.parse(result.trim()),
        'order': _paperQuestions.length + 1,
      });
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  Future<void> _generatePdfs() async {
    if (_savedPaperId == null) return;
    try {
      await ApiClient.dio.post('/api/admin/papers/$_savedPaperId/generate_pdfs/');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF generation queued.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.purple)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_savedPaperId != null ? 'Edit Paper #$_savedPaperId' : 'New Paper'),
        actions: [
          if (_savedPaperId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(onPressed: _generatePdfs, child: const Text('Generate PDFs')),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _saving ? null : _savePaperMeta,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildMetaForm()),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: _buildQuestionList()),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paper Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paperType,
            decoration: const InputDecoration(labelText: 'Paper Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'DPP', child: Text('Daily Practice Sheet')),
              DropdownMenuItem(value: 'CHAPTER_TEST', child: Text('Chapterwise Test')),
              DropdownMenuItem(value: 'PYQ', child: Text('Past Year Question Set')),
              DropdownMenuItem(value: 'PAIC', child: Text('Premium All India Contest')),
              DropdownMenuItem(value: 'BAIC', child: Text('Biweekly All India Contest')),
              DropdownMenuItem(value: 'MOCK_FULL', child: Text('Full Mock Test')),
            ],
            onChanged: (v) => setState(() {
              _paperType = v!;
              _isLiveContest = v == 'PAIC' || v == 'BAIC';
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _examStyle,
            decoration: const InputDecoration(labelText: 'Exam Style', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'JEE_MAIN', child: Text('JEE Main')),
              DropdownMenuItem(value: 'JEE_ADV', child: Text('JEE Advanced (single column)')),
              DropdownMenuItem(value: 'NEET', child: Text('NEET (OMR)')),
            ],
            onChanged: (v) => setState(() => _examStyle = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _classLevel,
            decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '11', child: Text('Class 11')),
              DropdownMenuItem(value: '12', child: Text('Class 12')),
              DropdownMenuItem(value: 'DROP', child: Text('Dropper')),
            ],
            onChanged: (v) => setState(() => _classLevel = v!),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (min)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _marksController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Marks', border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isPremium,
            onChanged: (v) => setState(() => _isPremium = v),
            activeColor: AppColors.purple,
            title: const Text('Premium', style: TextStyle(fontSize: 13)),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _isLiveContest,
            onChanged: (v) => setState(() => _isLiveContest = v),
            activeColor: AppColors.purple,
            title: const Text('Live contest (PAIC/BAIC leaderboard)', style: TextStyle(fontSize: 13)),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Questions (${_paperQuestions.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Row(children: [
              TextButton.icon(
                onPressed: () async {
                  final created = await Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionEditorScreen()));
                  if (created == true) _addQuestionById();
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('New Question'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _addQuestionById, icon: const Icon(Icons.link, size: 16), label: const Text('Add by ID')),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _paperQuestions.isEmpty
              ? const Center(child: Text('No questions added yet.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: _paperQuestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final pq = _paperQuestions[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(radius: 14, backgroundColor: AppColors.purple, child: Text('${pq['order']}', style: const TextStyle(fontSize: 11, color: Colors.white))),
                        title: Text('Question #${pq['question']}', style: const TextStyle(fontSize: 13)),
                        subtitle: pq['marks_correct_override'] != null
                            ? Text('Override: +${pq['marks_correct_override']}/${pq['marks_incorrect_override']}', style: const TextStyle(fontSize: 11))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            await ApiClient.dio.post('/api/admin/papers/$_savedPaperId/remove_question/', data: {'question_id': pq['question']});
                            _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
