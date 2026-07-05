import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/admin_models.dart';

/// Question authoring/editing screen (point #19/#20/#22).
///
/// Every question supports mixed plain text + LaTeX (wrapped in $...$) in
/// the body AND in each option's text, plus an optional image on the body,
/// each option, and the solution — all simultaneously, per spec. Images are
/// uploaded to the backend the moment they're picked; only the resulting
/// permanent storage path is ever saved with the question — never a local
/// device path or a browser blob: URL. Any existing question can be
/// reopened here and edited at any time (point #19): pass an existing
/// `questionId` to load it, or omit it to create a new one.
class QuestionEditorScreen extends StatefulWidget {
  final int? questionId;
  const QuestionEditorScreen({super.key, this.questionId});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _bodyController = TextEditingController();
  final _solutionController = TextEditingController();
  final _numericalController = TextEditingController();
  final _yearController = TextEditingController();
  final _shiftController = TextEditingController();

  AdminQuestion _question = AdminQuestion();
  List<AdminCategory> _categories = [];

  // Real backend-stored paths (sent to the server) and their servable
  // preview URLs, keyed the same way as add_questions_screen.dart:
  // 'body', 'solution', 'opt0'..'optN'.
  final Map<String, String> _uploadedPaths = {};
  final Map<String, String> _uploadedUrls = {};
  final Set<String> _uploadingKeys = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catResp = await ApiClient.dio.get('/api/admin/categories/');
      final catList = (catResp.data is Map ? catResp.data['results'] : catResp.data) as List;
      _categories = catList.map((j) => AdminCategory.fromJson(j)).toList();

      if (widget.questionId != null) {
        final resp = await ApiClient.dio.get('/api/admin/questions/${widget.questionId}/');
        _question = AdminQuestion.fromJson(resp.data);
        _bodyController.text = _question.body;
        _solutionController.text = _question.solutionText;
        _numericalController.text = _question.numericalAnswer?.toString() ?? '';
        _yearController.text = _question.year?.toString() ?? '';
        _shiftController.text = _question.examShift;
        if (_question.imageUrl != null) _uploadedUrls['body'] = _question.imageUrl!;
        if (_question.solutionImageUrl != null) _uploadedUrls['solution'] = _question.solutionImageUrl!;
      }
    } catch (_) {
      // Categories/question failed to load — form still usable once retried.
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(String key, {int? optionIndex}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _uploadingKeys.add(key));
    try {
      final result = await ApiClient.uploadImage(bytes, picked.name);
      setState(() {
        _uploadedPaths[key] = result['path']!;
        _uploadedUrls[key] = result['url']!;
        if (optionIndex != null) _question.options[optionIndex].imageUrl = result['path']!;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      setState(() => _uploadingKeys.remove(key));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _question.body = _bodyController.text;
    _question.solutionText = _solutionController.text;
    _question.numericalAnswer = double.tryParse(_numericalController.text);
    _question.year = int.tryParse(_yearController.text);
    _question.examShift = _shiftController.text;

    try {
      final payload = _question.toJson();
      // Only sent when a NEW image was picked+uploaded this session —
      // omitting the key leaves an existing image untouched on edit.
      if (_uploadedPaths['body'] != null) payload['image_path'] = _uploadedPaths['body'];
      if (_uploadedPaths['solution'] != null) payload['solution_image_path'] = _uploadedPaths['solution'];

      if (widget.questionId != null) {
        await ApiClient.dio.patch('/api/admin/questions/${widget.questionId}/', data: payload);
      } else {
        await ApiClient.dio.post('/api/admin/questions/', data: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  AdminCategory? get _selectedCategory =>
      _categories.where((c) => c.id == _question.categoryId).cast<AdminCategory?>().firstOrNull;

  bool get _isNumerical => _selectedCategory?.questionType == 'NUMERICAL';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.purple)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.questionId != null ? 'Edit Question #${widget.questionId}' : 'New Question'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : ElevatedButton(onPressed: _save, child: const Text('Save')),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: 3, child: _buildForm()),
          const VerticalDivider(width: 1),
          Expanded(flex: 2, child: _buildLivePreview()),
        ],
      ),
    );
  }

  Widget _imageAttachButton(String key, {int? optionIndex, String label = 'Attach image'}) {
    final isUploading = _uploadingKeys.contains(key);
    final url = _uploadedUrls[key];
    return Row(children: [
      OutlinedButton.icon(
        onPressed: isUploading ? null : () => _pickImage(key, optionIndex: optionIndex),
        icon: isUploading
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.image_outlined, size: 16),
        label: Text(label),
      ),
      const SizedBox(width: 10),
      // Rendered from the URL the backend actually returned — never a
      // local file path or blob: URL — so this only shows what's really
      // stored server-side.
      if (url != null) SizedBox(height: 40, child: Image.network(url)),
    ]);
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category (determines marking scheme)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _question.categoryId,
            items: _categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name}  (+${c.marksCorrect}/${c.marksIncorrect})')))
                .toList(),
            onChanged: (v) => setState(() => _question.categoryId = v),
          ),
          const SizedBox(height: 20),

          const Text('Question Body (mix plain text with \$LaTeX\$)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: r'e.g. A particle moves such that $x(t) = 4t^3 - 6t^2$...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _imageAttachButton('body', label: 'Attach image to question'),
          const SizedBox(height: 20),

          if (_isNumerical) ...[
            const Text('Numerical Answer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _numericalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ] else ...[
            const Text('Options (text and/or image, mark correct)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            ...List.generate(_question.options.length, (i) {
              final opt = _question.options[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: opt.isCorrect,
                      activeColor: AppColors.purple,
                      onChanged: (v) => setState(() => opt.isCorrect = v ?? false),
                    ),
                    Text(String.fromCharCode(65 + i), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: opt.text,
                            onChanged: (v) => opt.text = v,
                            decoration: const InputDecoration(hintText: 'Option text (supports \$LaTeX\$)', isDense: true),
                          ),
                          const SizedBox(height: 6),
                          _imageAttachButton('opt$i', optionIndex: i, label: 'Add image'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => setState(() => _question.options.add(AdminQuestionOption())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add option'),
            ),
          ],
          const SizedBox(height: 20),

          const Text('Solution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _solutionController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Worked solution (text + \$LaTeX\$)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          _imageAttachButton('solution', label: 'Attach image to solution'),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: TextField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year (for PYQ)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _shiftController,
                decoration: const InputDecoration(labelText: 'Exam / Shift label', border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Preview', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
            const Divider(color: Colors.black26),
            _renderMixed(_bodyController.text, fontSize: 15),
            if (_uploadedUrls['body'] != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Image.network(_uploadedUrls['body']!, height: 120)),
            const SizedBox(height: 16),
            if (!_isNumerical)
              ..._question.options.asMap().entries.map((e) {
                final i = e.key;
                final o = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('(${String.fromCharCode(65 + i)}) ', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                      Expanded(child: _renderMixed(o.text, fontSize: 13)),
                      if (o.isCorrect) const Icon(Icons.check, color: AppColors.answered, size: 16),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _renderMixed(String text, {required double fontSize}) {
    if (text.trim().isEmpty) return const Text('—', style: TextStyle(color: Colors.black38));
    // Naive split on $...$ segments for the live preview; the backend's
    // apps.pdfgen.latex_render module does the authoritative rendering
    // for actual PDF output.
    final parts = text.split('\$');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.asMap().entries.map((e) {
        final isLatex = e.key.isOdd;
        if (isLatex && e.value.trim().isNotEmpty) {
          try {
            return Math.tex(e.value, textStyle: TextStyle(fontSize: fontSize + 2, color: Colors.black));
          } catch (_) {}
        }
        return Text(e.value, style: TextStyle(fontSize: fontSize, color: Colors.black));
      }).toList(),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
