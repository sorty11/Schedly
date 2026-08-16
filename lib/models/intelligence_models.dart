import 'package:flutter/material.dart';

enum RecommendationLevel {
  mustAttend,
  stronglyRecommended,
  recommended,
  lowRisk,
  comfortableMargin,
}

enum IntelligenceGrade {
  excellent, // 95%+
  safe, // 85-94%
  monitor, // 80-84%
  attention, // 75-79%
  critical, // 70-74%
  emergency, // <70%
}

enum AttendanceTrend { improving, stable, declining }

class SubjectIntelligence {
  final String subjectCode;
  final String component;
  final IntelligenceGrade grade;
  final double currentPercentage;
  final int safeMargin;
  final int classesUntilCritical;
  final int recoveryClassesNeeded;
  final String? insight;

  SubjectIntelligence({
    required this.subjectCode,
    required this.component,
    required this.grade,
    required this.currentPercentage,
    required this.safeMargin,
    required this.classesUntilCritical,
    required this.recoveryClassesNeeded,
    this.insight,
  });
}

class OverallHealth {
  final int score; // 0-100
  final String grade; // A, B, C, D, F
  final AttendanceTrend trend;
  final int
  safeClassesRemaining; // Global safe margin until next subject drops below threshold

  OverallHealth({
    required this.score,
    required this.grade,
    required this.trend,
    required this.safeClassesRemaining,
  });
}

class TodayRecommendation {
  final String subjectCode;
  final String component;
  final RecommendationLevel level;
  final String reason;
  final int priority; // Lower number = higher priority to attend

  TodayRecommendation({
    required this.subjectCode,
    required this.component,
    required this.level,
    required this.reason,
    required this.priority,
  });
}

class RecoveryPlan {
  final String subjectCode;
  final String component;
  final double currentPercentage;
  final double targetPercentage;
  final int classesToAttend;
  final int estimatedDays;

  RecoveryPlan({
    required this.subjectCode,
    required this.component,
    required this.currentPercentage,
    required this.targetPercentage,
    required this.classesToAttend,
    required this.estimatedDays,
  });
}

class GamificationStats {
  final int currentStreak;
  final int bestStreak;
  final List<String> unlockedBadges;
  final int perfectWeeks;

  GamificationStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.unlockedBadges,
    required this.perfectWeeks,
  });
}
