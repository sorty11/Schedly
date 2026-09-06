import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';

export interface GamificationProfileData {
  uid: string;
  displayName: string;
  photoUrl?: string | null;
  academicYear?: string;
  branch?: string;
  division?: string;
  role?: string;
  exp: number;
  crPoints: number;
  srPoints: number;
  lastDailyClaimDate?: string | null;
  lastAttendanceClaimDate?: string | null;
  updatedAt?: any;
}

export interface WeeklyRecordData {
  weekKey: string;
  userId: string;
  displayName: string;
  photoUrl?: string | null;
  academicContext: string;
  weeklyExp: number;
  updatedAt?: any;
}

export interface ClaimResult {
  success: boolean;
  alreadyClaimed: boolean;
  newTotalExp: number;
  newWeeklyExp: number;
  message: string;
}

export class GamificationService {
  /**
   * Derives current calendar date in 'Asia/Kolkata' timezone (YYYY-MM-DD).
   */
  public static getKolkataDateString(now: Date = new Date()): string {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return formatter.format(now); // Outputs YYYY-MM-DD
  }

  /**
   * Derives standard ISO-8601 week key (YYYY-Www) in Asia/Kolkata timezone.
   * Monday 00:00:00 to Sunday 23:59:59.
   */
  public static getKolkataIsoWeekKey(now: Date = new Date()): string {
    const kolkataStr = now.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' });
    const target = new Date(kolkataStr);
    
    // ISO-8601 week date calculation
    // Day 0 is Sunday, 1 is Monday, ..., 6 is Saturday
    const dayNr = (target.getDay() + 6) % 7; // Monday = 0, Sunday = 6
    target.setDate(target.getDate() - dayNr + 3); // Nearest Thursday
    const firstThursday = target.valueOf();
    target.setMonth(0, 1);
    if (target.getDay() !== 4) {
      target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7));
    }
    const weekNum = 1 + Math.ceil((firstThursday - target.valueOf()) / 604800000);
    const year = new Date(firstThursday).getFullYear();
    return `${year}-W${weekNum.toString().padStart(2, '0')}`;
  }

  /**
   * Derives previous ISO week key (e.g. for weekly Champion calculation).
   */
  public static getPriorKolkataIsoWeekKey(now: Date = new Date()): string {
    const priorDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    return this.getKolkataIsoWeekKey(priorDate);
  }

  /**
   * Extracts academic context string from user document.
   */
  private static extractAcademicContext(userData: admin.firestore.DocumentData | undefined): string {
    if (!userData) return '';
    const parts: string[] = [];
    if (userData.academicYear) parts.push(userData.academicYear);
    if (userData.branch) parts.push(userData.branch);
    if (parts.length === 0 && userData.division) {
      parts.push(String(userData.division).replace(/_/g, ' '));
    }
    return parts.join(' • ');
  }

  /**
   * Claims daily app-open EXP (+20 XP).
   * Strictly limited to once per Asia/Kolkata calendar day.
   */
  public static async claimDailyExp(uid: string): Promise<ClaimResult> {
    const db = admin.firestore();
    const today = this.getKolkataDateString();
    const weekKey = this.getKolkataIsoWeekKey();

    const userDocRef = db.collection('users').doc(uid);
    const gamificationDocRef = db.collection('gamification').doc(uid);
    const weeklyDocRef = db.collection('gamification_weekly').doc(`${weekKey}_${uid}`);

    return db.runTransaction(async (transaction) => {
      const gamSnap = await transaction.get(gamificationDocRef);
      const userSnap = await transaction.get(userDocRef);
      const weeklySnap = await transaction.get(weeklyDocRef);

      const gamData = gamSnap.data() || {};
      const userData = userSnap.data() || {};

      if (gamData.lastDailyClaimDate === today) {
        return {
          success: false,
          alreadyClaimed: true,
          newTotalExp: gamData.exp || 0,
          newWeeklyExp: weeklySnap.exists ? (weeklySnap.data()?.weeklyExp || 0) : 0,
          message: 'Daily EXP already claimed for today',
        };
      }

      const currentTotal = (gamData.exp || 0) + 20;
      const currentWeekly = (weeklySnap.exists ? (weeklySnap.data()?.weeklyExp || 0) : 0) + 20;

      const displayName = userData.name || userData.displayName || 'Student';
      const photoUrl = userData.photoUrl || null;
      const academicContext = this.extractAcademicContext(userData);

      // 1. Update /gamification/{uid}
      transaction.set(gamificationDocRef, {
        uid,
        displayName,
        photoUrl,
        academicYear: userData.academicYear || '',
        branch: userData.branch || '',
        division: userData.division || '',
        role: userData.role || 'Student',
        exp: currentTotal,
        crPoints: gamData.crPoints || 0,
        srPoints: gamData.srPoints || 0,
        lastDailyClaimDate: today,
        lastAttendanceClaimDate: gamData.lastAttendanceClaimDate || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 2. Update /gamification_weekly/{weekKey_uid}
      transaction.set(weeklyDocRef, {
        weekKey,
        userId: uid,
        displayName,
        photoUrl,
        academicContext,
        weeklyExp: currentWeekly,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return {
        success: true,
        alreadyClaimed: false,
        newTotalExp: currentTotal,
        newWeeklyExp: currentWeekly,
        message: 'Successfully claimed +20 Daily EXP',
      };
    });
  }

  /**
   * Claims attendance view EXP (+10 XP).
   * Strictly limited to once per Asia/Kolkata calendar day.
   */
  public static async claimAttendanceExp(uid: string): Promise<ClaimResult> {
    const db = admin.firestore();
    const today = this.getKolkataDateString();
    const weekKey = this.getKolkataIsoWeekKey();

    const userDocRef = db.collection('users').doc(uid);
    const gamificationDocRef = db.collection('gamification').doc(uid);
    const weeklyDocRef = db.collection('gamification_weekly').doc(`${weekKey}_${uid}`);

    return db.runTransaction(async (transaction) => {
      const gamSnap = await transaction.get(gamificationDocRef);
      const userSnap = await transaction.get(userDocRef);
      const weeklySnap = await transaction.get(weeklyDocRef);

      const gamData = gamSnap.data() || {};
      const userData = userSnap.data() || {};

      if (gamData.lastAttendanceClaimDate === today) {
        return {
          success: false,
          alreadyClaimed: true,
          newTotalExp: gamData.exp || 0,
          newWeeklyExp: weeklySnap.exists ? (weeklySnap.data()?.weeklyExp || 0) : 0,
          message: 'Attendance EXP already claimed for today',
        };
      }

      const currentTotal = (gamData.exp || 0) + 10;
      const currentWeekly = (weeklySnap.exists ? (weeklySnap.data()?.weeklyExp || 0) : 0) + 10;

      const displayName = userData.name || userData.displayName || 'Student';
      const photoUrl = userData.photoUrl || null;
      const academicContext = this.extractAcademicContext(userData);

      // 1. Update /gamification/{uid}
      transaction.set(gamificationDocRef, {
        uid,
        displayName,
        photoUrl,
        academicYear: userData.academicYear || '',
        branch: userData.branch || '',
        division: userData.division || '',
        role: userData.role || 'Student',
        exp: currentTotal,
        crPoints: gamData.crPoints || 0,
        srPoints: gamData.srPoints || 0,
        lastDailyClaimDate: gamData.lastDailyClaimDate || null,
        lastAttendanceClaimDate: today,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 2. Update /gamification_weekly/{weekKey_uid}
      transaction.set(weeklyDocRef, {
        weekKey,
        userId: uid,
        displayName,
        photoUrl,
        academicContext,
        weeklyExp: currentWeekly,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return {
        success: true,
        alreadyClaimed: false,
        newTotalExp: currentTotal,
        newWeeklyExp: currentWeekly,
        message: 'Successfully claimed +10 Attendance EXP',
      };
    });
  }

  /**
   * Awards +25 CR/SR activity points strictly from the outbox processing pipeline.
   * Completely idempotent: checks outboxDocId in a dedicated log to prevent duplicate awards.
   */
  public static async awardTimetableContribution(
    db: admin.firestore.Firestore,
    uid: string,
    role: string,
    outboxDocId: string
  ): Promise<boolean> {
    const auditDocRef = db.collection('gamification_activity_logs').doc(outboxDocId);
    const gamificationDocRef = db.collection('gamification').doc(uid);
    const userDocRef = db.collection('users').doc(uid);

    try {
      return await db.runTransaction(async (transaction) => {
        const auditSnap = await transaction.get(auditDocRef);
        if (auditSnap.exists) {
          logger.info(`[GAMIFICATION] Outbox action ${outboxDocId} already rewarded. Skipping.`);
          return false;
        }

        const gamSnap = await transaction.get(gamificationDocRef);
        const userSnap = await transaction.get(userDocRef);
        const gamData = gamSnap.data() || {};
        const userData = userSnap.data() || {};

        const isCR = role.toUpperCase() === 'CR';
        const isSR = role.toUpperCase() === 'SR';
        if (!isCR && !isSR) {
          logger.warn(`[GAMIFICATION] User ${uid} has role ${role}; not eligible for CR/SR points.`);
          return false;
        }

        const newCrPoints = (gamData.crPoints || 0) + (isCR ? 25 : 0);
        const newSrPoints = (gamData.srPoints || 0) + (isSR ? 25 : 0);

        // 1. Write audit log preventing replay
        transaction.set(auditDocRef, {
          outboxDocId,
          uid,
          role,
          pointsAwarded: 25,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 2. Increment user's profile
        transaction.set(gamificationDocRef, {
          uid,
          displayName: userData.name || userData.displayName || 'Student',
          photoUrl: userData.photoUrl || null,
          academicYear: userData.academicYear || '',
          branch: userData.branch || '',
          division: userData.division || '',
          role: userData.role || role,
          exp: gamData.exp || 0,
          crPoints: newCrPoints,
          srPoints: newSrPoints,
          lastDailyClaimDate: gamData.lastDailyClaimDate || null,
          lastAttendanceClaimDate: gamData.lastAttendanceClaimDate || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        logger.info(`[GAMIFICATION] Successfully awarded +25 ${role} points to uid ${uid} for outbox ${outboxDocId}.`);
        return true;
      });
    } catch (e: any) {
      logger.error(`[GAMIFICATION_ERROR] Failed to award timetable contribution: ${e.message}`);
      return false;
    }
  }

  /**
   * Resolves the previous week's highest legitimate weekly XP earner
   * and idempotently stores the winner in /gamification_meta/current_champion.
   */
  public static async resolveWeeklyChampion(db: admin.firestore.Firestore = admin.firestore()): Promise<void> {
    const priorWeekKey = this.getPriorKolkataIsoWeekKey();
    const metaDocRef = db.collection('gamification_meta').doc('current_champion');

    try {
      const metaSnap = await metaDocRef.get();
      if (metaSnap.exists && metaSnap.data()?.weekKey === priorWeekKey) {
        // Already resolved for this week
        return;
      }

      logger.info(`[GAMIFICATION_CHAMPION] Resolving weekly champion for week ${priorWeekKey}...`);

      const topSnap = await db.collection('gamification_weekly')
        .where('weekKey', '==', priorWeekKey)
        .orderBy('weeklyExp', 'desc')
        .limit(1)
        .get();

      if (topSnap.empty) {
        logger.info(`[GAMIFICATION_CHAMPION] No weekly records found for ${priorWeekKey}. Writing null champion.`);
        await metaDocRef.set({
          weekKey: priorWeekKey,
          championUid: null,
          displayName: null,
          photoUrl: null,
          academicContext: null,
          weeklyExp: 0,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const topDoc = topSnap.docs[0].data();
      logger.info(`[GAMIFICATION_CHAMPION] Champion for ${priorWeekKey} is ${topDoc.displayName} (${topDoc.userId}) with ${topDoc.weeklyExp} XP.`);

      await metaDocRef.set({
        weekKey: priorWeekKey,
        championUid: topDoc.userId,
        displayName: topDoc.displayName || 'Champion',
        photoUrl: topDoc.photoUrl || null,
        academicContext: topDoc.academicContext || '',
        weeklyExp: topDoc.weeklyExp || 0,
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e: any) {
      logger.error(`[GAMIFICATION_CHAMPION_ERROR] Failed to resolve weekly champion: ${e.message}`);
    }
  }
}
