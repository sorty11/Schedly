const fs = require('fs');

const code = `import * as admin from 'firebase-admin';
import { dispatchNotification } from '../notifications/notification.service';
import { logger } from '../utils/logger';

export class OutboxWorker {
  private _isRunning = false;
  private isProcessing = false;
  private timer: NodeJS.Timeout | null = null;
  
  // Adaptive polling intervals
  private readonly ACTIVE_POLL_MS = 5000;
  private readonly IDLE_POLL_MS = 30000;
  private currentPollMs = 30000;

  // Stats
  private stats = {
    pending: 0,
    processedToday: 0,
    failedToday: 0,
    lastReset: new Date().toDateString()
  };

  constructor() {
    this.currentPollMs = this.IDLE_POLL_MS;
  }

  public isRunning() {
    return this._isRunning;
  }

  public getStats() {
    this.checkResetStats();
    return this.stats;
  }

  private checkResetStats() {
    const today = new Date().toDateString();
    if (this.stats.lastReset !== today) {
      this.stats.processedToday = 0;
      this.stats.failedToday = 0;
      this.stats.lastReset = today;
    }
  }

  public start() {
    if (this._isRunning) return;
    this._isRunning = true;
    logger.info('Outbox Worker started');
    
    // Initial run immediately to process everything missed while offline
    this.scheduleNext(0);
  }

  public stop() {
    this._isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    logger.info('Outbox Worker stopped');
  }

  private scheduleNext(delayMs: number) {
    if (!this._isRunning) return;
    this.timer = setTimeout(() => this.processOutbox(), delayMs);
  }

  private async processOutbox() {
    if (this.isProcessing) {
      this.scheduleNext(this.currentPollMs);
      return;
    }

    this.isProcessing = true;
    try {
      this.checkResetStats();
      const db = admin.firestore();
      
      const snapshot = await db.collection('notification_outbox')
        .where('processed', '==', false)
        .where('nextRetryAt', '<=', admin.firestore.FieldValue.serverTimestamp())
        .limit(50)
        .get();

      this.stats.pending = snapshot.size;

      if (snapshot.empty) {
        this.currentPollMs = Math.min(this.currentPollMs * 1.5, this.IDLE_POLL_MS);
      } else {
        this.currentPollMs = this.ACTIVE_POLL_MS;
        logger.info(\`Outbox Worker found \${snapshot.size} pending notifications\`);

        for (const doc of snapshot.docs) {
          await this.processSingleEntry(doc);
        }
      }
      
      // Cleanup job (e.g. 1% chance on each poll)
      if (Math.random() < 0.01) {
        await this.cleanupOldRecords();
      }

    } catch (error) {
      logger.error('Error in outbox worker loop:', error);
    } finally {
      this.isProcessing = false;
      this.scheduleNext(this.currentPollMs);
    }
  }

  private async processSingleEntry(doc: admin.firestore.QueryDocumentSnapshot) {
    const data = doc.data();
    const uid = data.uid;
    const notificationId = data.notificationId || doc.id;
    const division = data.division || 'unknown';
    const type = data.type || 'unknown';
    const db = admin.firestore();
    const attemptNum = (data.attempts || 0) + 1;
    const startTime = Date.now();

    try {
      // 1. Verify Authorization (Defense in depth)
      let authorized = false;
      let role = 'unknown';
      if (uid) {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          role = userDoc.data()?.role || 'unknown';
          if (role === 'CR' || role === 'SR') {
            authorized = true;
          }
        }
      }

      if (!authorized) {
        const elapsed = Date.now() - startTime;
        await doc.ref.update({
          processed: true,
          status: 'DEAD',
          lastError: 'Unauthorized user',
          attempts: attemptNum,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastAttempt: admin.firestore.FieldValue.serverTimestamp()
        });
        this.stats.failedToday++;
        logger.warn('Unauthorized Notification', {
          notificationId, uid, division, role, type, attempt: attemptNum, elapsedMs: elapsed, status: 'DEAD', error: 'Unauthorized user'
        });
        return;
      }

      // 2. Dispatch Notification
      await dispatchNotification(data as any, uid, role);
      
      // 3. Mark Processed (Success)
      const elapsed = Date.now() - startTime;
      await doc.ref.update({
        processed: true,
        status: 'SUCCESS',
        attempts: attemptNum,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAttempt: admin.firestore.FieldValue.serverTimestamp()
      });
      this.stats.processedToday++;
      logger.info('Notification Delivered', {
        notificationId, uid, division, role, type, attempt: attemptNum, elapsedMs: elapsed, status: 'SUCCESS'
      });

    } catch (error: any) {
      const elapsed = Date.now() - startTime;
      const errorMessage = error.message || 'Unknown error';
      
      if (attemptNum >= 5) {
        // Dead Letter Queue
        await doc.ref.update({
          processed: true,
          status: 'DEAD',
          lastError: errorMessage,
          attempts: attemptNum,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastAttempt: admin.firestore.FieldValue.serverTimestamp()
        });
        this.stats.failedToday++;
        logger.error('Notification Dead Lettered', {
          notificationId, uid, division, role: 'unknown', type, attempt: attemptNum, elapsedMs: elapsed, status: 'DEAD', error: errorMessage
        });
      } else {
        // Retry logic
        const backoffSeconds = Math.pow(2, attemptNum);
        const nextRetryAt = admin.firestore.Timestamp.fromMillis(Date.now() + (backoffSeconds * 1000));
        await doc.ref.update({
          status: 'RETRYING',
          lastError: errorMessage,
          attempts: attemptNum,
          nextRetryAt,
          lastAttempt: admin.firestore.FieldValue.serverTimestamp()
        });
        logger.warn('Notification Retry Scheduled', {
          notificationId, uid, division, role: 'unknown', type, attempt: attemptNum, elapsedMs: elapsed, status: 'RETRYING', error: errorMessage
        });
      }
    }
  }

  private async cleanupOldRecords() {
    try {
      const db = admin.firestore();
      const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - (7 * 24 * 60 * 60 * 1000));
      
      const snapshot = await db.collection('notification_outbox')
        .where('processed', '==', true)
        .where('processedAt', '<', sevenDaysAgo)
        .limit(100)
        .get();
        
      if (!snapshot.empty) {
        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        logger.info(\`Cleaned up \${snapshot.size} old outbox records\`);
      }
    } catch (error) {
      logger.error('Error cleaning up old records:', error);
    }
  }
}
`;
fs.writeFileSync('server/src/worker/outbox.worker.ts', code);
console.log('Rewrote outbox.worker.ts');
