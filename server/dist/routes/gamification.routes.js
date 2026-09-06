"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const gamification_service_1 = require("../services/gamification.service");
const logger_1 = require("../utils/logger");
const router = (0, express_1.Router)();
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
    try {
        const result = await gamification_service_1.GamificationService.claimDailyExp(uid);
        logger_1.logger.info(`[GAMIFICATION_API] Daily claim for ${uid}: success=${result.success}, alreadyClaimed=${result.alreadyClaimed}`);
        return res.status(200).json(result);
    }
    catch (error) {
        logger_1.logger.error(`[GAMIFICATION_API_ERROR] Failed daily claim for ${uid}: ${error.message}`);
        return res.status(500).json({ error: 'Internal server error processing daily claim' });
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
    try {
        const result = await gamification_service_1.GamificationService.claimAttendanceExp(uid);
        logger_1.logger.info(`[GAMIFICATION_API] Attendance claim for ${uid}: success=${result.success}, alreadyClaimed=${result.alreadyClaimed}`);
        return res.status(200).json(result);
    }
    catch (error) {
        logger_1.logger.error(`[GAMIFICATION_API_ERROR] Failed attendance claim for ${uid}: ${error.message}`);
        return res.status(500).json({ error: 'Internal server error processing attendance claim' });
    }
});
exports.default = router;
