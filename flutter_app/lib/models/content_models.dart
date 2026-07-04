class SubjectSummary {
  final int id;
  final String name;
  final String exam;
  final int chapterCount;
  final double overallCompletionPercent;

  SubjectSummary({
    required this.id,
    required this.name,
    required this.exam,
    required this.chapterCount,
    required this.overallCompletionPercent,
  });

  factory SubjectSummary.fromJson(Map<String, dynamic> j) => SubjectSummary(
        id: j['id'],
        name: j['name'],
        exam: j['exam'],
        chapterCount: j['chapter_count'] ?? 0,
        overallCompletionPercent: (j['overall_completion_percent'] as num?)?.toDouble() ?? 0,
      );
}

class ChapterSummary {
  final int id;
  final String name;
  final String classLevel;
  final String difficulty;
  final double estimatedHours;
  final int modulesCompleted;
  final int modulesTotal;
  final double completionPercent;

  ChapterSummary({
    required this.id,
    required this.name,
    required this.classLevel,
    required this.difficulty,
    required this.estimatedHours,
    required this.modulesCompleted,
    required this.modulesTotal,
    required this.completionPercent,
  });

  factory ChapterSummary.fromJson(Map<String, dynamic> j) => ChapterSummary(
        id: j['id'],
        name: j['name'],
        classLevel: j['class_level'] ?? '',
        difficulty: j['difficulty'] ?? 'MEDIUM',
        estimatedHours: (j['estimated_hours'] as num?)?.toDouble() ?? 0,
        modulesCompleted: j['modules_completed'] ?? 0,
        modulesTotal: j['modules_total'] ?? 0,
        completionPercent: (j['completion_percent'] as num?)?.toDouble() ?? 0,
      );
}

class ModuleItem {
  final int id;
  final String moduleType; // THEORY, FORMULA, SOLVED, DPP, PYQ, REVISION, TEST, ADVANCED
  final String title;
  final int order;
  final bool isPremium;

  ModuleItem({
    required this.id,
    required this.moduleType,
    required this.title,
    required this.order,
    required this.isPremium,
  });

  factory ModuleItem.fromJson(Map<String, dynamic> j) => ModuleItem(
        id: j['id'],
        moduleType: j['module_type'],
        title: j['title'],
        order: j['order'] ?? 0,
        isPremium: j['is_premium'] ?? false,
      );
}

class ChapterDetail {
  final int id;
  final String name;
  final String classLevel;
  final String difficulty;
  final double estimatedHours;
  final List<ModuleItem> modules;

  ChapterDetail({
    required this.id,
    required this.name,
    required this.classLevel,
    required this.difficulty,
    required this.estimatedHours,
    required this.modules,
  });

  factory ChapterDetail.fromJson(Map<String, dynamic> j) => ChapterDetail(
        id: j['id'],
        name: j['name'],
        classLevel: j['class_level'] ?? '',
        difficulty: j['difficulty'] ?? 'MEDIUM',
        estimatedHours: (j['estimated_hours'] as num?)?.toDouble() ?? 0,
        modules: (j['modules'] as List? ?? []).map((m) => ModuleItem.fromJson(m)).toList(),
      );
}
