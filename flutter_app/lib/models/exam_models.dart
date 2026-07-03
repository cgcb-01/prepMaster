class ExamPaper {
  final int id;
  final String title;
  final String paperType; // DPP, CHAPTER_TEST, PYQ, PAIC, BAIC, WEEKLY_PERSONAL, MOCK_FULL
  final String examStyle; // JEE_MAIN, JEE_ADV, NEET
  final String classLevel;
  final int durationMinutes;
  final int totalMarks;
  final bool isPremium;
  final bool isDownloadable;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final bool isLiveContest;
  final bool isLocked;

  ExamPaper({
    required this.id,
    required this.title,
    required this.paperType,
    required this.examStyle,
    required this.classLevel,
    required this.durationMinutes,
    required this.totalMarks,
    required this.isPremium,
    required this.isDownloadable,
    this.scheduledStart,
    this.scheduledEnd,
    required this.isLiveContest,
    required this.isLocked,
  });

  factory ExamPaper.fromJson(Map<String, dynamic> j) => ExamPaper(
        id: j['id'],
        title: j['title'],
        paperType: j['paper_type'],
        examStyle: j['exam_style'],
        classLevel: j['class_level'],
        durationMinutes: j['duration_minutes'] ?? 180,
        totalMarks: j['total_marks'] ?? 300,
        isPremium: j['is_premium'] ?? false,
        isDownloadable: j['is_downloadable'] ?? true,
        scheduledStart: j['scheduled_start'] != null ? DateTime.tryParse(j['scheduled_start']) : null,
        scheduledEnd: j['scheduled_end'] != null ? DateTime.tryParse(j['scheduled_end']) : null,
        isLiveContest: j['is_live_contest'] ?? false,
        isLocked: j['is_locked'] ?? false,
      );

  bool get isCurrentlyRunning {
    if (scheduledStart == null || scheduledEnd == null) return false;
    final now = DateTime.now();
    return now.isAfter(scheduledStart!) && now.isBefore(scheduledEnd!);
  }
}

class AttemptQuestion {
  final int id;
  final int order;
  final String subject;
  final String categoryName;
  final String questionType; // MCQ_SINGLE, MCQ_MULTIPLE, NUMERICAL, MATCH_COLUMN, ASSERTION_REASON
  final String body;
  final String? imageUrl;
  final List<QuestionOption> options;

  AttemptQuestion({
    required this.id,
    required this.order,
    required this.subject,
    required this.categoryName,
    required this.questionType,
    required this.body,
    this.imageUrl,
    required this.options,
  });

  factory AttemptQuestion.fromJson(Map<String, dynamic> j) => AttemptQuestion(
        id: j['id'],
        order: j['order'],
        subject: j['subject'],
        categoryName: j['category_name'],
        questionType: j['question_type'],
        body: j['body'],
        imageUrl: j['image'],
        options: (j['options'] as List? ?? [])
            .map((o) => QuestionOption(label: o['label'], text: o['text'], imageUrl: o['image']))
            .toList(),
      );
}

class QuestionOption {
  final String label;
  final String text;
  final String? imageUrl;
  QuestionOption({required this.label, required this.text, this.imageUrl});
}

class AttemptSession {
  final int attemptId;
  final int durationMinutes;
  final DateTime startedAt;
  final List<AttemptQuestion> questions;

  AttemptSession({
    required this.attemptId,
    required this.durationMinutes,
    required this.startedAt,
    required this.questions,
  });

  factory AttemptSession.fromJson(Map<String, dynamic> j) => AttemptSession(
        attemptId: j['attempt_id'],
        durationMinutes: j['duration_minutes'],
        startedAt: DateTime.parse(j['started_at']),
        questions: (j['questions'] as List).map((q) => AttemptQuestion.fromJson(q)).toList(),
      );
}