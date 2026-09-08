import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/gamification_profile.dart';
import 'package:schedly/services/gamification_service.dart';

import 'package:schedly/theme/champion_theme_access.dart';

void main() {
  group('Gamification System Tests', () {
    test('GamificationProfile defaults and academicContext', () {
      const profile = GamificationProfile(
        uid: 'user123',
        displayName: 'Ayaan',
        photoUrl: 'https://example.com/avatar.jpg',
        academicYear: '3rd Year',
        branch: 'CSE',
        division: '3rdYear_CSE_B',
        exp: 1840,
        crPoints: 50,
      );

      expect(profile.uid, 'user123');
      expect(profile.displayName, 'Ayaan');
      expect(profile.photoUrl, 'https://example.com/avatar.jpg');
      expect(profile.exp, 1840);
      expect(profile.crPoints, 50);
      expect(profile.srPoints, 0);
      expect(profile.academicContext, '3rd Year • CSE');
    });

    test('GamificationProfile fallback academicContext from division', () {
      const profile = GamificationProfile(
        uid: 'user456',
        displayName: 'Rahul',
        division: '2ndYear_IT_A',
        exp: 1200,
      );

      expect(profile.academicContext, '2ndYear IT A');
    });

    test('Reward constants verification', () {
      expect(GamificationService.dailyExpReward, 20);
      expect(GamificationService.attendanceExpReward, 10);
      expect(GamificationService.timetableActionReward, 25);
    });

    test('toFirestore serialization contains valid keys including photoUrl', () {
      const profile = GamificationProfile(
        uid: 'test_uid',
        displayName: 'Sara',
        photoUrl: 'https://example.com/sara.png',
        exp: 500,
        lastDailyExpClaimDate: '2026-09-06',
      );

      final map = profile.toFirestore();
      expect(map['uid'], 'test_uid');
      expect(map['displayName'], 'Sara');
      expect(map['photoUrl'], 'https://example.com/sara.png');
      expect(map['exp'], 500);
      expect(map['lastDailyExpClaimDate'], '2026-09-06');
      expect(map.containsKey('updatedAt'), isTrue);
    });

    test('LeaderboardPopupData model encapsulates rankings correctly', () {
      const p1 = GamificationProfile(uid: '1', displayName: 'User 1', exp: 100);
      const p2 = GamificationProfile(uid: '2', displayName: 'User 2', exp: 80);
      const p3 = GamificationProfile(uid: '3', displayName: 'User 3', exp: 60);
      const cr = GamificationProfile(uid: 'cr1', displayName: 'CR 1', crPoints: 50);

      const popupData = LeaderboardPopupData(
        top3: [p1, p2, p3],
        bestCR: cr,
      );

      expect(popupData.top3.length, 3);
      expect(popupData.top3.first.displayName, 'User 1');
      expect(popupData.bestCR?.displayName, 'CR 1');
      expect(popupData.bestSR, isNull);
    });

    test('ChampionThemeAccess is universally unlocked for every user', () {
      // Champion theme is universally available without subscription, payment, or EXP
      expect(
        ChampionThemeAccess.isPermanentlyUnlocked(explicitEmail: 'student@example.com'),
        isTrue,
      );
      expect(
        ChampionThemeAccess.isPermanentlyUnlocked(explicitEmail: 'sorty797@gmail.com'),
        isTrue,
      );
      expect(
        ChampionThemeAccess.hasAccess(
          isWeeklyChampion: false,
          explicitEmail: 'student@example.com',
        ),
        isTrue,
      );
      expect(
        ChampionThemeAccess.hasAccess(
          isWeeklyChampion: false,
        ),
        isTrue,
      );
    });
  });
}
