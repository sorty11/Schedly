import { Router } from 'express';
import { verifyIdToken } from '../middleware/auth.middleware';
import { gamificationRateLimiter } from '../middleware/rateLimiter.middleware';
import { GamificationService } from '../services/gamification.service';
import { logger } from '../utils/logger';

const router = Router();
router.use(gamificationRateLimiter);

// In-flight claim mutex per UID to reject concurrent bursts before hitting database
const inFlightClaims = new Set<string>();

/**
 * POST /api/gamification/claim-daily
 * Authenticated endpoint to claim daily app-open EXP (+20 XP).
 * Server determines UID, calendar date (Asia/Kolkata), and week bounds.
 */
router.post('/claim-daily', verifyIdToken, async (req: any, res: any) => {
  const uid = req.user?.uid;
  if (!uid) {
    return res.status(401).json({ error: 'Unauthorized: Missing user UID' });
  }

  if (inFlightClaims.has(uid)) {
    logger.warn('[GAMIFICATION_API] Concurrent claim attempt blocked', { uid });
    return res.status(429).json({ error: 'A claim request is already processing. Please wait.' });
  }

  inFlightClaims.add(uid);
  try {
    const result = await GamificationService.claimDailyExp(uid);
    logger.info(`[GAMIFICATION_API] Daily claim for ${uid}: success=${result.success}, alreadyClaimed=${result.alreadyClaimed}`);
    return res.status(200).json(result);
  } catch (error: any) {
    logger.error(`[GAMIFICATION_API_ERROR] Failed daily claim for ${uid}: ${error.message}`);
    return res.status(500).json({ error: 'Internal server error processing daily claim' });
  } finally {
    inFlightClaims.delete(uid);
  }
});

/**
 * POST /api/gamification/claim-attendance
 * Authenticated endpoint to claim attendance view EXP (+10 XP).
 * Server determines UID and ensures single claim per Asia/Kolkata calendar day.
 */
router.post('/claim-attendance', verifyIdToken, async (req: any, res: any) => {
  const uid = req.user?.uid;
  if (!uid) {
    return res.status(401).json({ error: 'Unauthorized: Missing user UID' });
  }

  if (inFlightClaims.has(uid)) {
    logger.warn('[GAMIFICATION_API] Concurrent attendance claim attempt blocked', { uid });
    return res.status(429).json({ error: 'A claim request is already processing. Please wait.' });
  }

  inFlightClaims.add(uid);
  try {
    const result = await GamificationService.claimAttendanceExp(uid);
    logger.info(`[GAMIFICATION_API] Attendance claim for ${uid}: success=${result.success}, alreadyClaimed=${result.alreadyClaimed}`);
    return res.status(200).json(result);
  } catch (error: any) {
    logger.error(`[GAMIFICATION_API_ERROR] Failed attendance claim for ${uid}: ${error.message}`);
    return res.status(500).json({ error: 'Internal server error processing attendance claim' });
  } finally {
    inFlightClaims.delete(uid);
  }
});

export default router;
