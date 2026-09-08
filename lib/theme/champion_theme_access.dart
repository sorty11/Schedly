import 'package:firebase_auth/firebase_auth.dart';

/// Single isolated configuration & access evaluator for the permanent
/// Champion visual theme access allowlist.
///
/// PURELY COSMETIC: Only governs unlocking/selecting the Champion visual theme.
/// Does NOT grant EXP, points, champion title, role, or backend privileges.
class ChampionThemeAccess {
  ChampionThemeAccess._();

  /// Universally unlocked for all users without payment, subscription, or EXP requirements.
  static bool isPermanentlyUnlocked({
    User? user,
    String? explicitUid,
    String? explicitEmail,
  }) =>
      true;

  /// Determines whether the Champion theme is accessible:
  /// Universally available and unlocked for every user.
  static bool hasAccess({
    bool isWeeklyChampion = true,
    User? user,
    String? explicitUid,
    String? explicitEmail,
  }) =>
      true;
}
