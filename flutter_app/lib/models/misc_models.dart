class LeaderboardEntry {
  final int? rank;
  final String user;
  final String school;
  final double score;
  final double accuracy;
  final int timeTakenSeconds;

  LeaderboardEntry({
    this.rank,
    required this.user,
    required this.school,
    required this.score,
    required this.accuracy,
    required this.timeTakenSeconds,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: j['rank'],
        user: j['user'] ?? '',
        school: j['school'] ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        timeTakenSeconds: j['time_taken_seconds'] ?? 0,
      );
}

class TodoItem {
  final int id;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isCompleted,
  });

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        dueDate: DateTime.parse(j['due_date']),
        isCompleted: j['is_completed'] ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String().split('T').first,
      };
}
