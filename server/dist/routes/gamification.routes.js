"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const rateLimiter_middleware_1 = require("../middleware/rateLimiter.middleware");
const gamification_service_1 = require("../services/gamification.service");
const logger_1 = require("../utils/logger");
const router = (0, express_1.Router)();
router.use(rateLimiter_middleware_1.gamificationRateLimiter);
// In-flight claim mutex per UID to reject concurrent bursts before hitting database
const inFlightClaims = new Set();
/**
 * POST /api/gamification/claim-daily
 * Authenticated endpoint to claim daily app-open EXP (+20 XP).
 * Server determines UID, calendar date (Asia/Kolkata), and week bounds.
 */
router.post('/claim-daily', auth_middleware_1.verifyIdToken, async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
        return res.status(401).json({ error: 'Unauthorized: Missing user UID' });
    }
    if (inFlightClaims.has(uid)) {
        logger_1.logger.warn('[GAMIFICATION_API] Concurrent claim attempt blocked', { uid });
        return res.status(429).json({ error: 'A claim request is already processing. Please wait.' });
    }
    inFlightClaims.add(uid);
    try {
        const result = await gamification_service_1.GamificationService.claimDailyExp(uid);
        logger_1.logger.info(`[GAMIFICATION_API] Daily claim for ${uid}: success=${result.success}, alreadyClaimed=${result.alreadyClaimed}`);
        return res.status(200).json(result);
    }
    catch (error) {
        logger_1.logger.error(`[GAMIFICATION_API_ERROR] Failed daily claim for ${uid}: ${error.message}`);
        return res.status(500).json({ error: 'Internal server error processing daily claim' });
    }
    finally {
        inFlightClaims.delete(uid);
    }
});
/**
 * POST /api/gamification/claim-attendance
 * Authenticated endpoint to claim attendance view EXP (+10 XP).
 * Server determines UID and ensures single claim per Asia/Kolkata calendar day.
 */
router.post('/claim-attendance', auth_middleware_1.verifyIdToken, async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
        return res.status(401).json({ error: 'Unauthorized: Missing user UID' });
    }
    if (inFlightClaims.has(uid)) {
        logger_1.logger.warn('[GAMIFICATION_API] Concurrent attendance claim attempt blocked', { uid });
        return res.status(429).json({ error: 'A claim request is already processing. Please wait.' });
    }
    inFlightClaims.add(uid);
    try {
        const result = await gamification_service_1.GamificationService.claimAttendanceExp(uid);
        logger_1.logger.info(`[GAMIFICATION_API] Attendance claim for ${uid}: success=${result.success}, alreadyClaimed=${result.alreadyClaimed}`);
        return res.status(200).json(result);
    }
    catch (error) {
        logger_1.logger.error(`[GAMIFICATION_API_ERROR] Failed attendance claim for ${uid}: ${error.message}`);
        return res.status(500).json({ error: 'Internal server error processing attendance claim' });
    }
    finally {
        inFlightClaims.delete(uid);
    }
});
exports.default = router;
