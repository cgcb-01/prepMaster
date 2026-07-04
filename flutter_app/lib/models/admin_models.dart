class AdminQuestionOption {
  String text;
  String imageUrl;
  bool isCorrect;
  AdminQuestionOption({this.text = '', this.imageUrl = '', this.isCorrect = false});

  Map<String, dynamic> toJson() => {'text': text, 'image_url': imageUrl, 'is_correct': isCorrect};

  factory AdminQuestionOption.fromJson(Map<String, dynamic> j) => AdminQuestionOption(
        text: j['text'] ?? '',
        imageUrl: j['image_url'] ?? '',
        isCorrect: j['is_correct'] ?? false,
      );
}

class AdminQuestion {
  final int? id;
  int? subjectId;
  int? chapterId;
  int? categoryId;
  String body;
  String? imageUrl;
  List<AdminQuestionOption> options;
  double? numericalAnswer;
  String solutionText;
  String? solutionImageUrl;
  int? year;
  String examShift;

  AdminQuestion({
    this.id,
    this.subjectId,
    this.chapterId,
    this.categoryId,
    this.body = '',
    this.imageUrl,
    List<AdminQuestionOption>? options,
    this.numericalAnswer,
    this.solutionText = '',
    this.solutionImageUrl,
    this.year,
    this.examShift = '',
  }) : options = options ?? [AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption(), AdminQuestionOption()];

  factory AdminQuestion.fromJson(Map<String, dynamic> j) => AdminQuestion(
        id: j['id'],
        subjectId: j['subject'],
        chapterId: j['chapter'],
        categoryId: j['category'],
        body: j['body'] ?? '',
        imageUrl: j['image'],
        options: (j['options'] as List? ?? []).map((o) => AdminQuestionOption.fromJson(o)).toList(),
        numericalAnswer: (j['numerical_answer'] as num?)?.toDouble(),
        solutionText: j['solution_text'] ?? '',
        solutionImageUrl: j['solution_image'],
        year: j['year'],
        examShift: j['exam_shift'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'subject': subjectId,
        'chapter': chapterId,
        'category': categoryId,
        'body': body,
        'options': options.map((o) => o.toJson()).toList(),
        'numerical_answer': numericalAnswer,
        'solution_text': solutionText,
        'year': year,
        'exam_shift': examShift,
      };
}

class AdminCategory {
  final int id;
  final String name;
  final String questionType;
  final double marksCorrect;
  final double marksIncorrect;
  AdminCategory({required this.id, required this.name, required this.questionType, required this.marksCorrect, required this.marksIncorrect});

  factory AdminCategory.fromJson(Map<String, dynamic> j) => AdminCategory(
        id: j['id'], name: j['name'], questionType: j['question_type'],
        marksCorrect: (j['marks_correct'] as num).toDouble(),
        marksIncorrect: (j['marks_incorrect'] as num).toDouble(),
      );
}
