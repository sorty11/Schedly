import 'package:firebase_auth/firebase_auth.dart';

/// Single isolated configuration & access evaluator for the permanent
/// Champion visual theme access allowlist.
///
/// PURELY COSMETIC: Only governs unlocking/selecting the Champion visual theme.
/// Does NOT grant EXP, points, champion title, role, or backend privileges.
class ChampionThemeAccess {
  ChampionThemeAccess._();

  /// Allowlisted Firebase User UIDs that have permanent access to the Champion theme.
  /// Configure permanent account UIDs here.
  static const Set<String> _allowlistedUids = {
    // Add your Firebase UID here if desired, e.g. 'YOUR_FIREBASE_UID',
  };

  /// Allowlisted emails that have permanent access to the Champion theme.
  /// Automatically matches authenticated user's email case-insensitively.
  static const Set<String> _allowlistedEmails = {
    'sorty797@gmail.com',
    'ayaan9421375797@gmail.com',
    'maulapatel369@gmail.com',
  };

  static String? _getCurrentUserUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String? _getCurrentUserEmail() {
    try {
      return FirebaseAuth.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Evaluates whether the given user (or current Firebase user) is allowlisted
  /// for permanent theme access.
  static bool isPermanentlyUnlocked({
    User? user,
    String? explicitUid,
    String? explicitEmail,
  }) {
    final uid = explicitUid ?? user?.uid ?? _getCurrentUserUid();
    if (uid != null && _allowlistedUids.contains(uid)) {
      return true;
    }

    final email = (explicitEmail ?? user?.email ?? _getCurrentUserEmail())
        ?.toLowerCase()
        .trim();
    if (email != null && _allowlistedEmails.contains(email)) {
      return true;
    }

    return false;
  }

  /// Determines whether the Champion theme is accessible:
  /// either permanently allowlisted or currently the active weekly Champion.
  static bool hasAccess({
    required bool isWeeklyChampion,
    User? user,
    String? explicitUid,
    String? explicitEmail,
  }) {
    if (isPermanentlyUnlocked(
      user: user,
      explicitUid: explicitUid,
      explicitEmail: explicitEmail,
    )) {
      return true;
    }
    return isWeeklyChampion;
  }
}
