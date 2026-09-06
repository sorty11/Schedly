import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { GamificationService } from '../services/gamification.service';

export class ChampionWorker {
  private timer: NodeJS.Timeout | null = null;
  private isRunning = false;
  private readonly checkIntervalMs = 15 * 60 * 1000; // Check every 15 minutes

  public start() {
    if (this.isRunning) return;
    this.isRunning = true;

    logger.info(JSON.stringify({
      event: 'champion_worker_started',
      status: 'SUCCESS',
      timestamp: new Date().toISOString()
    }));

    // Perform immediate check on startup
    this.runCheck();
  }

  public stop() {
    this.isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    logger.info(JSON.stringify({
      event: 'champion_worker_stopped',
      status: 'SUCCESS',
      timestamp: new Date().toISOString()
    }));
  }

  private async runCheck() {
    if (!this.isRunning) return;

    try {
      await GamificationService.resolveWeeklyChampion();
    } catch (error: any) {
      logger.error(`[CHAMPION_WORKER_ERROR] Error running champion resolution check: ${error.message}`);
    } finally {
      if (this.isRunning) {
        this.timer = setTimeout(() => this.runCheck(), this.checkIntervalMs);
      }
    }
  }
}
