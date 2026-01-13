class UserStats {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final int points;
  final int streakCount;
  final int longestStreak;
  final int totalLessonsCompleted;
  final int totalExercisesCompleted;
  final String? level;
  final LearningStats? learningStats;

  UserStats({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    required this.points,
    required this.streakCount,
    required this.longestStreak,
    required this.totalLessonsCompleted,
    required this.totalExercisesCompleted,
    this.level,
    this.learningStats,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    String _asString(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      return v.toString();
    }

    return UserStats(
      id: _asInt(json['id']),
      username: _asString(json['username'], fallback: 'user'),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      points: _asInt(json['points'], fallback: 0),
      streakCount: _asInt(json['streak_count'], fallback: 0),
      longestStreak: _asInt(json['longest_streak'], fallback: 0),
      totalLessonsCompleted: _asInt(
        json['total_lessons_completed'],
        fallback: 0,
      ),
      totalExercisesCompleted: _asInt(
        json['total_exercises_completed'],
        fallback: 0,
      ),
      level: json['level']?.toString(),
      learningStats:
          (json['learning_stats'] is Map)
              ? LearningStats.fromJson(
                Map<String, dynamic>.from(json['learning_stats'] as Map),
              )
              : null,
    );
  }
}

class LearningStats {
  final int id;
  final int vocabularyLearned;
  final int grammarTopicsCompleted;
  final int listeningTime;
  final int speakingPractice;
  final double accuracyRate;
  final DateTime updatedAt;

  LearningStats({
    required this.id,
    required this.vocabularyLearned,
    required this.grammarTopicsCompleted,
    required this.listeningTime,
    required this.speakingPractice,
    required this.accuracyRate,
    required this.updatedAt,
  });

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    double _asDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    DateTime _asDate(dynamic v) {
      try {
        if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
        if (v is String && v.isNotEmpty) return DateTime.parse(v);
      } catch (_) {}
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return LearningStats(
      id: _asInt(json['id']),
      vocabularyLearned: _asInt(json['vocabulary_learned']),
      grammarTopicsCompleted: _asInt(json['grammar_topics_completed']),
      listeningTime: _asInt(json['listening_time']),
      speakingPractice: _asInt(json['speaking_practice']),
      accuracyRate: _asDouble(json['accuracy_rate']),
      updatedAt: _asDate(json['updated_at']),
    );
  }
}

class UserProgressRecord {
  final int id;
  final int userId;
  final String date;
  final int lessonsCompleted;
  final int exercisesCompleted;
  final int pointsEarned;
  final int timeSpent;

  UserProgressRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.lessonsCompleted,
    required this.exercisesCompleted,
    required this.pointsEarned,
    required this.timeSpent,
  });

  factory UserProgressRecord.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    String _asString(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      return v.toString();
    }

    return UserProgressRecord(
      id: _asInt(json['id']),
      userId: _asInt(json['user']),
      date: _asString(json['date']),
      lessonsCompleted: _asInt(json['lessons_completed']),
      exercisesCompleted: _asInt(json['exercises_completed']),
      pointsEarned: _asInt(json['points_earned']),
      timeSpent: _asInt(json['time_spent']),
    );
  }
}
