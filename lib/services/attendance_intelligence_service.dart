import '../models/attendance_record.dart';
import '../models/attendance_log.dart';
import '../models/timetable_entry.dart';
import '../models/intelligence_models.dart';
import 'attendance/academic_grouping_policy.dart';
import 'progress_calculator_service.dart';
import 'subject_identity_service.dart';
import 'dart:math';

class AttendanceIntelligenceService {
  static const double thresholdSafe = 0.85;
  static const double thresholdWarning = 0.80;
  static const double thresholdCritical = 0.75;
  static const double thresholdEmergency = 0.70;

  /// Evaluate a single subject's intelligence metrics
  static SubjectIntelligence evaluateSubject(AttendanceRecord record) {
    final pct = record.percentage;
    final total = record.total;

    IntelligenceGrade grade;
    if (total == 0) {
      grade = IntelligenceGrade.safe;
    } else if (pct >= 0.95) {
      grade = IntelligenceGrade.excellent;
    } else if (pct >= thresholdSafe) {
      grade = IntelligenceGrade.safe;
    } else if (pct >= thresholdWarning) {
      grade = IntelligenceGrade.monitor;
    } else if (pct >= thresholdCritical) {
      grade = IntelligenceGrade.attention;
    } else if (pct >= thresholdEmergency) {
      grade = IntelligenceGrade.critical;
    } else {
      grade = IntelligenceGrade.emergency;
    }

    final safeMargin = _calculateClassesUntil(
      record.present,
      total,
      thresholdWarning,
      false,
    );
    final classesUntilCritical = _calculateClassesUntil(
      record.present,
      total,
      thresholdCritical,
      false,
    );
    final recoveryClassesNeeded = _calculateClassesUntil(
      record.present,
      total,
      thresholdCritical,
      true,
    );

    String? insight;
    if (total > 0) {
      if (pct >= 0.95)
        insight = 'You can comfortably miss several classes.';
      else if (pct >= 0.85)
        insight = 'No immediate action required.';
      else if (pct >= 0.80)
        insight = 'Keep attending regularly.';
      else if (pct >= 0.75)
        insight = 'Avoid unnecessary absences.';
      else if (pct >= 0.70)
        insight = 'Attend all upcoming lectures.';
      else
        insight = 'High risk. Prioritize every class.';
    } else {
      insight = 'No attendance recorded yet.';
    }

    return SubjectIntelligence(
      subjectCode: record.subjectCode,
      component: record.component,
      grade: grade,
      currentPercentage: pct,
      safeMargin: safeMargin,
      classesUntilCritical: classesUntilCritical,
      recoveryClassesNeeded: recoveryClassesNeeded,
      insight: insight,
    );
  }

  /// Calculates how many classes to miss (or attend) until hitting a target percentage
  static int _calculateClassesUntil(
    int present,
    int total,
    double targetPct,
    bool attending,
  ) {
    if (total == 0) return 0;
    final currentPct = present / total;

    if (attending) {
      if (currentPct >= targetPct) return 0;
      // (present + x) / (total + x) >= targetPct
      // x >= (targetPct * total - present) / (1 - targetPct)
      final need = ((targetPct * total - present) / (1 - targetPct)).ceil();
      return max(0, need);
    } else {
      if (currentPct <= targetPct) return 0;
      // present / (total + x) >= targetPct
      // x <= (present / targetPct) - total
      final canMiss = (present / targetPct).floor() - total;
      return max(0, canMiss);
    }
  }

  /// Calculates overall health score
  static OverallHealth calculateOverallHealth(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return OverallHealth(
        score: 100,
        grade: 'A',
        trend: AttendanceTrend.stable,
        safeClassesRemaining: 0,
      );
    }

    int totalPresent = 0;
    int totalTotal = 0;
    int totalSafeMargin = 9999;

    for (final r in records) {
      totalPresent += r.present;
      totalTotal += r.total;

      if (r.total > 0) {
        final safeForSubject = _calculateClassesUntil(
          r.present,
          r.total,
          thresholdWarning,
          false,
        );
        if (safeForSubject < totalSafeMargin) {
          totalSafeMargin = safeForSubject;
        }
      }
    }

    if (totalTotal == 0) {
      return OverallHealth(
        score: 100,
        grade: 'A',
        trend: AttendanceTrend.stable,
        safeClassesRemaining: 0,
      );
    }

    final overallPct = totalPresent / totalTotal;

    // Score out of 100
    int score = (overallPct * 100).round();

    // Penalize score if any subject is highly critical
    final criticalSubjects = records
        .where((r) => r.total > 0 && r.percentage < thresholdCritical)
        .length;
    score -=
        (criticalSubjects * 5); // Subtract 5 points for every critical subject
    score = score.clamp(0, 100);

    String grade;
    if (score >= 90)
      grade = 'A';
    else if (score >= 80)
      grade = 'B';
    else if (score >= 70)
      grade = 'C';
    else if (score >= 60)
      grade = 'D';
    else
      grade = 'F';

    return OverallHealth(
      score: score,
      grade: grade,
      trend: AttendanceTrend.stable, // Can be improved by analyzing history
      safeClassesRemaining: totalSafeMargin == 9999 ? 0 : totalSafeMargin,
    );
  }

  /// Generates recommendations for today's lectures
  static List<TodayRecommendation> generateTodayRecommendations(
    List<TimetableEntry> entries,
    List<AttendanceRecord> records, {
    ProgressCalculatorService? calculator,
  }) {
    final List<TodayRecommendation> recommendations = [];

    // Deduplicate entries by subject+component
    final uniqueEntries = <String, TimetableEntry>{};
    for (var e in entries) {
      if (e.isActive) {
        uniqueEntries['${e.subject}_${e.component}'] = e;
      }
    }

    for (final entry in uniqueEntries.values) {
      final rawSubj = entry.subject.trim();
      final rawComp = entry.component.trim();
      final entryNormComp = AcademicGroupingPolicy.normalizeComponent(rawComp);

      // 1. Dedicated STME DSA handling: DSA Theory != DSA Lab
      final bool isEntryDsa = rawSubj.toUpperCase() == 'DSA' ||
          rawSubj.toUpperCase().contains('DATA STRUCTURE') ||
          AttendanceLog.isDsa(rawSubj);

      final AttendanceRecord? record;
      if (isEntryDsa) {
        final bool isLab = entryNormComp == 'Lab' ||
            rawSubj.toUpperCase().contains('LAB') ||
            rawComp.toUpperCase().contains('LAB') ||
            rawComp.toUpperCase().contains('PRACTICAL') ||
            rawComp.toUpperCase() == 'P4';

        record = records.where((r) {
          final rSubjUpper = r.subjectCode.trim().toUpperCase();
          final isRDsa = rSubjUpper == 'DSA' ||
              rSubjUpper.contains('DATA STRUCTURE') ||
              AttendanceLog.isDsa(r.subjectCode);
          if (!isRDsa) return false;

          final rComp = AcademicGroupingPolicy.normalizeComponent(r.component);
          if (isLab) {
            return rComp == 'Lab' || rSubjUpper.contains('LAB');
          } else {
            return rComp == 'Theory' && !rSubjUpper.contains('LAB');
          }
        }).firstOrNull;
      } else {
        // 2. General matching (handles SOL Company Law 2 <-> II, Sakshya, etc.)
        record = records.where((r) {
          final isSubjMatch = SubjectIdentityService.isMatch(entry.subject, r.subjectCode);
          if (!isSubjMatch) return false;
          final rNormComp = AcademicGroupingPolicy.normalizeComponent(r.component);
          if (rNormComp != 'Merged' && entryNormComp != 'Merged' && rawComp.isNotEmpty) {
            return rNormComp == entryNormComp;
          }
          return true;
        }).firstOrNull;
      }

      if (record == null || record.total == 0) {
        recommendations.add(
          TodayRecommendation(
            subjectCode: entry.subject,
            component: entry.component,
            level: RecommendationLevel.recommended,
            reason: 'No attendance data yet. Build a strong foundation.',
            priority: 3,
          ),
        );
        continue;
      }

      final pct = record.percentage;
      final safeMargin80 = _calculateClassesUntil(
        record.present,
        record.total,
        thresholdWarning,
        false,
      );
      final safeMargin75 = _calculateClassesUntil(
        record.present,
        record.total,
        thresholdCritical,
        false,
      );

      RecommendationLevel level;
      String reason;
      int priority;

      if (pct < thresholdCritical) {
        level = RecommendationLevel.mustAttend;
        reason = 'Attendance is critically low. Every class is essential.';
        priority = 1;
      } else if (pct < thresholdWarning) {
        level = RecommendationLevel.stronglyRecommended;
        if (safeMargin80 <= 1) {
          reason = 'One absence will reduce attendance below the 80% requirement.';
        } else {
          reason =
              'Attendance is below the 80% goal. Missing classes increases risk rapidly.';
        }
        priority = 2;
      } else if (pct < thresholdSafe) {
        level = RecommendationLevel.recommended;
        reason =
            'Attendance is decent but should be maintained to avoid entering the warning zone.';
        priority = 3;
      } else if (pct >= 0.95) {
        level = RecommendationLevel.comfortableMargin;
        reason =
            'You have excellent attendance and can safely miss if necessary.';
        priority = 5;
      } else {
        level = RecommendationLevel.lowRisk;
        reason = 'You have a healthy safe margin of $safeMargin80 classes.';
        priority = 4;
      }

      // Calculate course hours & skip budget if calculator is available
      int? assignedHours;
      int? remainingLectures;
      int? skipsLeft;

      if (calculator != null) {
        assignedHours = calculator.getConfiguredCourseHours(record.subjectCode, record.component);
        if (assignedHours != null && assignedHours > 0) {
          remainingLectures = calculator.getRemainingLectures(record.subjectCode, record.component, record.total);
          final isSol = record.division.toUpperCase().startsWith('SOL_');
          final targetPct = isSol ? 0.70 : 0.80;
          skipsLeft = calculator.getRemainingSkips(
            record.subjectCode,
            record.component,
            record.absent,
            requiredAttendance: targetPct,
          );
        }
      }

      String enrichedReason = reason;
      if (assignedHours != null && assignedHours > 0) {
        if (skipsLeft != null && skipsLeft > 0) {
          enrichedReason += ' You can safely miss $skipsLeft lecture(s) ($remainingLectures remaining in semester).';
        } else if (skipsLeft != null && skipsLeft == 0) {
          enrichedReason += ' 0 skips remaining ($remainingLectures remaining in semester).';
        }
      }

      recommendations.add(
        TodayRecommendation(
          subjectCode: entry.subject,
          component: entry.component,
          level: level,
          reason: enrichedReason,
          priority: priority,
          remainingSkips: skipsLeft,
          remainingLectures: remainingLectures,
          assignedHours: assignedHours,
        ),
      );
    }

    recommendations.sort((a, b) => a.priority.compareTo(b.priority));
    return recommendations;
  }

  /// Generates a recovery plan for subjects below 75%
  static List<RecoveryPlan> generateRecoveryPlans(
    List<AttendanceRecord> records,
  ) {
    final plans = <RecoveryPlan>[];
    for (final r in records) {
      if (r.total > 0 && r.percentage < thresholdCritical) {
        final needed = _calculateClassesUntil(
          r.present,
          r.total,
          thresholdCritical,
          true,
        );
        plans.add(
          RecoveryPlan(
            subjectCode: r.subjectCode,
            component: r.component,
            currentPercentage: r.percentage,
            targetPercentage: thresholdCritical,
            classesToAttend: needed,
            estimatedDays:
                needed * 3, // rough estimate, assuming 2-3 classes per week
          ),
        );
      }
    }
    return plans;
  }

  /// Scenario simulator for 'What If' projections
  static double simulateScenario(
    AttendanceRecord record, {
    required int attendNext,
    required int missNext,
  }) {
    if (record.total == 0) {
      if (attendNext + missNext == 0) return 0.0;
      return attendNext / (attendNext + missNext);
    }
    final newPresent = record.present + attendNext;
    final newTotal = record.total + attendNext + missNext;
    return newPresent / newTotal;
  }
}
