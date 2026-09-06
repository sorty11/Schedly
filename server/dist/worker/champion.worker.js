"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChampionWorker = void 0;
const logger_1 = require("../utils/logger");
const gamification_service_1 = require("../services/gamification.service");
class ChampionWorker {
    timer = null;
    isRunning = false;
    checkIntervalMs = 15 * 60 * 1000; // Check every 15 minutes
    start() {
        if (this.isRunning)
            return;
        this.isRunning = true;
        logger_1.logger.info(JSON.stringify({
            event: 'champion_worker_started',
            status: 'SUCCESS',
            timestamp: new Date().toISOString()
        }));
        // Perform immediate check on startup
        this.runCheck();
    }
    stop() {
        this.isRunning = false;
        if (this.timer) {
            clearTimeout(this.timer);
            this.timer = null;
        }
        logger_1.logger.info(JSON.stringify({
            event: 'champion_worker_stopped',
            status: 'SUCCESS',
            timestamp: new Date().toISOString()
        }));
    }
    async runCheck() {
        if (!this.isRunning)
            return;
        try {
            await gamification_service_1.GamificationService.resolveWeeklyChampion();
        }
        catch (error) {
            logger_1.logger.error(`[CHAMPION_WORKER_ERROR] Error running champion resolution check: ${error.message}`);
        }
        finally {
            if (this.isRunning) {
                this.timer = setTimeout(() => this.runCheck(), this.checkIntervalMs);
            }
        }
    }
}
exports.ChampionWorker = ChampionWorker;
