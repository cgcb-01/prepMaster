class UserProfile {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String schoolName;
  final String state;
  final String country;
  final String rollNo;
  final String studentClass;
  final int rating;
  final String ratingTitle;
  final DateTime registeredAt;
  final DateTime? lastSeenAt;
  final bool isOnline;
  final int friendCount;
  final int currentStreakDays;
  final int maxStreakDays;
  final int maxSubmissionsInADay;

  // Private-only fields (null when viewing someone else's public profile)
  final List<String>? weakSubjects;
  final List<String>? weakChapters;
  final bool? isPremium;
  final bool isStaff;

  UserProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.schoolName,
    required this.state,
    required this.country,
    required this.rollNo,
    required this.studentClass,
    required this.rating,
    required this.ratingTitle,
    required this.registeredAt,
    this.lastSeenAt,
    required this.isOnline,
    required this.friendCount,
    required this.currentStreakDays,
    required this.maxStreakDays,
    required this.maxSubmissionsInADay,
    this.weakSubjects,
    this.weakChapters,
    this.isPremium,
    this.isStaff = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'],
        username: j['username'] ?? '',
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        photoUrl: j['photo'],
        schoolName: j['school_name'] ?? '',
        state: j['state'] ?? '',
        country: j['country'] ?? '',
        rollNo: j['roll_no'] ?? '',
        studentClass: j['student_class'] ?? '',
        rating: j['rating'] ?? 1000,
        ratingTitle: j['rating_title'] ?? 'Newcomer',
        registeredAt: DateTime.tryParse(j['registered_at'] ?? '') ?? DateTime.now(),
        lastSeenAt: j['last_seen_at'] != null ? DateTime.tryParse(j['last_seen_at']) : null,
        isOnline: j['is_online'] ?? false,
        friendCount: j['friend_count'] ?? 0,
        currentStreakDays: j['current_streak_days'] ?? 0,
        maxStreakDays: j['max_streak_days'] ?? 0,
        maxSubmissionsInADay: j['max_submissions_in_a_day'] ?? 0,
        weakSubjects: (j['weak_subjects'] as List?)?.map((e) => e.toString()).toList(),
        weakChapters: (j['weak_chapters'] as List?)?.map((e) => e.toString()).toList(),
        isPremium: j['is_premium'],
        isStaff: j['is_staff'] ?? false,
      );
}