import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/admin_models.dart';

/// Reference-style question authoring flow (matches the admin.js pattern
/// you shared): Step 1 pick a destination paper — with an inline "create
/// missing" quick-form right there instead of navigating away. Step 2 is a
/// persistent question form: subject, type, marks, question (text+image),
/// options (text+image each), correct answer, solution (text+image). On
/// submit it POSTs, attaches the question to the paper, clears the form,
/// and bumps the question number — so adding question 2, 3, 4... never
/// leaves this screen. Existing questions already in the paper are listed
/// below and are editable in place by tapping them.
class AddQuestionsScreen extends StatefulWidget {
  const AddQuestionsScreen({super.key});
  @override
  State<AddQuestionsScreen> createState() => _AddQuestionsScreenState();
}

class _AddQuestionsScreenState extends State<AddQuestionsScreen> {
  // Step 1 state
  List<Map<String, dynamic>> _papers = [];
  int? _paperId;
  String _newPaperType = 'DPP';
  final _newPaperTitle = TextEditingController();
  bool _loadingPapers = true;

  // Step 2 state
  final _bodyCtrl = TextEditingController();
  final _solutionCtrl = TextEditingController();
  final _numericalCtrl = TextEditingController();
  int _qNumber = 1;
  String _subject = 'PHYSICS';
  List<AdminCategory> _categories = [];
  int? _categoryId;
  final _marksCorrectCtrl = TextEditingController(text: '4');
  final _marksIncorrectCtrl = TextEditingController(text: '-1');
  List<AdminQuestionOption> _options = [AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption()];
  final Map<String, File> _pendingImages = {}; // 'body' | 'opt0'..'opt3' | 'solution'
  int? _editingQuestionId; // non-null while editing an existing question
  List<Map<String, dynamic>> _paperQuestions = [];
  bool _submitting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadPapers();
    _loadCategories();
  }

  Future<void> _loadPapers() async {
    setState(() => _loadingPapers = true);
    try {
      final resp = await ApiClient.dio.get('/api/admin/papers/');
      final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
      setState(() => _papers = List<Map<String, dynamic>>.from(list));
    } catch (e) {
      _setStatus('Could not load papers: $e', error: true);
    } finally {
      setState(() => _loadingPapers = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final resp = await ApiClient.dio.get('/api/admin/categories/');
      final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
      setState(() => _categories = list.map((j) => AdminCategory.fromJson(j)).toList());
    } catch (_) {}
  }

  Future<void> _createPaper() async {
    if (_newPaperTitle.text.trim().isEmpty) {
      _setStatus('Enter a title for the new paper.', error: true);
      return;
    }
    try {
      final resp = await ApiClient.dio.post('/api/admin/papers/', data: {
        'title': _newPaperTitle.text.trim(),
        'paper_type': _newPaperType,
        'exam_style': _newPaperType == 'PYQ' ? 'JEE_MAIN' : 'JEE_MAIN',
        'class_level': '12',
        'duration_minutes': 180,
        'total_marks': 300,
        'is_premium': false,
        'is_downloadable': true,
        'is_live_contest': _newPaperType == 'PAIC' || _newPaperType == 'BAIC',
      });
      _newPaperTitle.clear();
      await _loadPapers();
      setState(() => _paperId = resp.data['id']);
      _loadPaperQuestions();
      _setStatus('Paper "${resp.data['title']}" created — now add questions below.');
    } catch (e) {
      _setStatus('Could not create paper: $e', error: true);
    }
  }

  Future<void> _selectPaper(int? id) async {
    setState(() { _paperId = id; _paperQuestions = []; });
    if (id != null) _loadPaperQuestions();
  }

  Future<void> _loadPaperQuestions() async {
    if (_paperId == null) return;
    try {
      final resp = await ApiClient.dio.get('/api/admin/papers/$_paperId/');
      setState(() => _paperQuestions = List<Map<String, dynamic>>.from(resp.data['paper_questions'] ?? []));
    } catch (_) {}
  }

  Future<void> _pickImage(String key) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pendingImages[key] = File(picked.path));
  }

  void _setStatus(String msg, {bool error = false}) {
    setState(() { _statusMessage = msg; _statusIsError = error; });
  }

  bool get _isNumerical => _categories.where((c) => c.id == _categoryId).isEmpty
      ? false
      : _categories.firstWhere((c) => c.id == _categoryId).questionType == 'NUMERICAL';

  Future<void> _loadQuestionForEdit(int questionId) async {
    try {
      final resp = await ApiClient.dio.get('/api/admin/questions/$questionId/');
      final q = AdminQuestion.fromJson(resp.data);
      setState(() {
        _editingQuestionId = questionId;
        _categoryId = q.categoryId;
        _bodyCtrl.text = q.body;
        _solutionCtrl.text = q.solutionText;
        _numericalCtrl.text = q.numericalAnswer?.toString() ?? '';
        _options = q.options.isNotEmpty ? q.options : [AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption()];
        _pendingImages.clear();
      });
      _setStatus('Editing question #$questionId — save to update it in place.');
    } catch (e) {
      _setStatus('Could not load question: $e', error: true);
    }
  }

  void _clearForm({bool bumpNumber = true}) {
    setState(() {
      if (bumpNumber) _qNumber++;
      _editingQuestionId = null;
      _bodyCtrl.clear();
      _solutionCtrl.clear();
      _numericalCtrl.clear();
      _options = [AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption()];
      _pendingImages.clear();
    });
  }

  Future<void> _submitQuestion() async {
    if (_paperId == null) { _setStatus('Pick a destination paper first (Step 1).', error: true); return; }
    if (_categoryId == null) { _setStatus('Pick a category (sets the marking scheme).', error: true); return; }
    if (_bodyCtrl.text.trim().isEmpty) { _setStatus('Question text is required.', error: true); return; }

    setState(() => _submitting = true);
    try {
      final payload = {
        'subject': _subject,
        'category': _categoryId,
        'body': _bodyCtrl.text.trim(),
        'options': _isNumerical ? [] : _options.map((o) => o.toJson()).toList(),
        'numerical_answer': _isNumerical ? double.tryParse(_numericalCtrl.text) : null,
        'solution_text': _solutionCtrl.text.trim(),
      };

      Map<String, dynamic> savedQuestion;
      if (_editingQuestionId != null) {
        final resp = await ApiClient.dio.patch('/api/admin/questions/$_editingQuestionId/', data: payload);
        savedQuestion = resp.data;
        _setStatus('Question #$_editingQuestionId updated.');
      } else {
        final resp = await ApiClient.dio.post('/api/admin/questions/', data: payload);
        savedQuestion = resp.data;
        await ApiClient.dio.post('/api/admin/papers/$_paperId/add_question/', data: {
          'question_id': savedQuestion['id'],
          'order': _paperQuestions.length + 1,
          'marks_correct_override': double.tryParse(_marksCorrectCtrl.text),
          'marks_incorrect_override': double.tryParse(_marksIncorrectCtrl.text),
        });
        _setStatus('Q$_qNumber added (ID: ${savedQuestion['id']}). Ready for Q${_qNumber + 1}.');
      }

      _clearForm(bumpNumber: _editingQuestionId == null);
      _loadPaperQuestions();
    } catch (e) {
      _setStatus('Save failed: $e', error: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Questions')),
      body: _loadingPapers
          ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepCard(
                    step: 1, title: 'Destination',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          value: _paperId,
                          decoration: const InputDecoration(labelText: 'Select existing paper', border: OutlineInputBorder(), isDense: true),
                          items: _papers.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text('${p['title']} (${p['paper_type']})'))).toList(),
                          onChanged: _selectPaper,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CREATE MISSING PAPER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Row(children: [
                                SizedBox(
                                  width: 160,
                                  child: DropdownButtonFormField<String>(
                                    value: _newPaperType,
                                    isDense: true,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                    items: const [
                                      DropdownMenuItem(value: 'DPP', child: Text('DPP')),
                                      DropdownMenuItem(value: 'CHAPTER_TEST', child: Text('Chapter Test')),
                                      DropdownMenuItem(value: 'PYQ', child: Text('PYQ')),
                                      DropdownMenuItem(value: 'PAIC', child: Text('PAIC')),
                                      DropdownMenuItem(value: 'BAIC', child: Text('BAIC')),
                                      DropdownMenuItem(value: 'MOCK_FULL', child: Text('Mock Test')),
                                    ],
                                    onChanged: (v) => setState(() => _newPaperType = v!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: _newPaperTitle, decoration: const InputDecoration(hintText: 'New paper title…', isDense: true, border: OutlineInputBorder()))),
                                const SizedBox(width: 8),
                                ElevatedButton(onPressed: _createPaper, child: const Text('Create')),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_paperId != null) ...[
                    _stepCard(
                      step: 2, title: _editingQuestionId != null ? 'Edit Question #$_editingQuestionId' : 'Add Question — Q$_qNumber',
                      child: _buildQuestionForm(),
                    ),
                    const SizedBox(height: 16),
                    _buildExistingQuestionsList(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stepCard({required int step, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 11, backgroundColor: AppColors.purple, child: Text('$step', style: const TextStyle(fontSize: 11, color: Colors.white))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildQuestionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_statusMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: (_statusIsError ? Colors.red : AppColors.answered).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_statusMessage!, style: TextStyle(fontSize: 12, color: _statusIsError ? Colors.red : AppColors.answered)),
          ),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _subject,
              decoration: const InputDecoration(labelText: 'Subject', isDense: true, border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'PHYSICS', child: Text('Physics')),
                DropdownMenuItem(value: 'CHEMISTRY', child: Text('Chemistry')),
                DropdownMenuItem(value: 'MATHS', child: Text('Maths')),
                DropdownMenuItem(value: 'BIOLOGY', child: Text('Biology')),
              ],
              onChanged: (v) => setState(() => _subject = v!),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Type / Marking', isDense: true, border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (+${c.marksCorrect}/${c.marksIncorrect})', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _richField(label: 'Question', controller: _bodyCtrl, imageKey: 'body', maxLines: 4),
        const SizedBox(height: 12),
        if (_isNumerical)
          TextField(controller: _numericalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Correct numerical value', border: OutlineInputBorder(), isDense: true))
        else ...[
          const Text('Options', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          ...List.generate(_options.length, (i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Checkbox(value: _options[i].isCorrect, activeColor: AppColors.purple, onChanged: (v) => setState(() => _options[i].isCorrect = v ?? false)),
                  Text(String.fromCharCode(65 + i), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: _richField(label: 'Option ${String.fromCharCode(65 + i)}', initialValue: _options[i].text, imageKey: 'opt$i', onChanged: (v) => _options[i].text = v, compact: true)),
                ]),
              )),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _marksCorrectCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '+Marks (override)', isDense: true, border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _marksIncorrectCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '−Marks (override)', isDense: true, border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        _richField(label: 'Solution (optional)', controller: _solutionCtrl, imageKey: 'solution', maxLines: 3),
        const SizedBox(height: 16),
        Row(children: [
          ElevatedButton(
            onPressed: _submitting ? null : _submitQuestion,
            child: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_editingQuestionId != null ? 'Save Changes' : 'Add Question & Continue'),
          ),
          const SizedBox(width: 10),
          if (_editingQuestionId != null)
            OutlinedButton(onPressed: () => _clearForm(bumpNumber: false), child: const Text('Cancel Edit'))
          else
            OutlinedButton(onPressed: () => _clearForm(bumpNumber: false), child: const Text('Clear')),
        ]),
      ],
    );
  }

  Widget _richField({required String label, TextEditingController? controller, String? initialValue, required String imageKey, int maxLines = 2, bool compact = false, ValueChanged<String>? onChanged}) {
    final img = _pendingImages[imageKey];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: controller != null
              ? TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, hintText: r'supports $LaTeX$', border: const OutlineInputBorder(), isDense: true))
              : TextFormField(initialValue: initialValue, maxLines: maxLines, onChanged: onChanged, decoration: InputDecoration(labelText: label, hintText: r'supports $LaTeX$', border: const OutlineInputBorder(), isDense: true)),
        ),
        const SizedBox(width: 6),
        Column(children: [
          IconButton(icon: const Icon(Icons.image_outlined, size: 20), onPressed: () => _pickImage(imageKey), tooltip: 'Attach image'),
          if (img != null) SizedBox(width: 32, height: 24, child: Image.file(img, fit: BoxFit.cover)),
        ]),
      ],
    );
  }

  Widget _buildExistingQuestionsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions already in this paper (${_paperQuestions.length}) — tap to edit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          if (_paperQuestions.isEmpty)
            const Text('None yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ..._paperQuestions.map((pq) => ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 12, backgroundColor: AppColors.purple, child: Text('${pq['order']}', style: const TextStyle(fontSize: 10, color: Colors.white))),
                  title: Text('Question #${pq['question']}', style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () => _loadQuestionForEdit(pq['question']),
                )),
        ],
      ),
    );
  }
}
