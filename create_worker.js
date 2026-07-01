const fs = require('fs');

// 1. Rewrite notification.routes.ts
const routesCode = `import { Router } from 'express';
import { verifyIdToken } from '../middleware/auth.middleware';

const router = Router();

// Endpoint solely to wake up the worker
// We protect it with verifyIdToken so random internet scans don't keep it awake unnecessarily
// But we don't enforce CR/SR here since the outbox worker does the actual authorization
router.get('/wake', verifyIdToken, (req, res) => {
  res.status(200).json({ message: 'Worker is awake' });
});

export default router;
`;
fs.writeFileSync('server/src/routes/notification.routes.ts', routesCode);
console.log('Rewrote notification.routes.ts');

// 2. Create outbox.worker.ts
const workerCode = `import * as admin from 'firebase-admin';
import { NotificationService } from '../notifications/notification.service';
import { logger } from '../utils/logger';

export class OutboxWorker {
  private isRunning = false;
  private isProcessing = false;
  private timer: NodeJS.Timeout | null = null;
  
  // Adaptive polling intervals
  private readonly ACTIVE_POLL_MS = 5000;  // 5 seconds when busy
  private readonly IDLE_POLL_MS = 30000;   // 30 seconds when idle
  private currentPollMs = 30000;

  constructor() {
    this.currentPollMs = this.IDLE_POLL_MS;
  }

  public start() {
    if (this.isRunning) return;
    this.isRunning = true;
    logger.info('Outbox Worker started');
    
    // Initial run immediately
    this.scheduleNext(0);
  }

  public stop() {
    this.isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    logger.info('Outbox Worker stopped');
  }

  private scheduleNext(delayMs: number) {
    if (!this.isRunning) return;
    this.timer = setTimeout(() => this.processOutbox(), delayMs);
  }

  private async processOutbox() {
    if (this.isProcessing) {
      this.scheduleNext(this.currentPollMs);
      return;
    }

    this.isProcessing = true;
    try {
      const db = admin.firestore();
      
      // Fetch unprocessed entries that are due for processing/retry
      const snapshot = await db.collection('notification_outbox')
        .where('processed', '==', false)
        .where('nextRetryAt', '<=', admin.firestore.FieldValue.serverTimestamp())
        .limit(50)
        .get();

      if (snapshot.empty) {
        // Idle
        this.currentPollMs = Math.min(this.currentPollMs * 1.5, this.IDLE_POLL_MS);
      } else {
        // Active
        this.currentPollMs = this.ACTIVE_POLL_MS;
        logger.info(\`Outbox Worker found \${snapshot.size} pending notifications\`);

        for (const doc of snapshot.docs) {
          await this.processSingleEntry(doc);
        }
      }
      
      // Also occasionally run cleanup (e.g. 1% chance on each poll)
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
    const db = admin.firestore();

    try {
      // 1. Verify Authorization (CR/SR only)
      let authorized = false;
      if (uid) {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          const role = userDoc.data()?.role;
          if (role === 'CR' || role === 'SR') {
            authorized = true;
          }
        }
      }

      if (!authorized) {
        // Not authorized. Mark failed permanently.
        await doc.ref.update({
          processed: true,
          status: 'failed',
          lastError: 'Unauthorized user',
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        logger.warn(\`Unauthorized outbox entry \${doc.id} from uid \${uid}\`);
        return;
      }

      // 2. Dispatch Notification
      await NotificationService.sendNotification(data as any);
      
      // 3. Mark Processed (Success)
      await doc.ref.update({
        processed: true,
        status: 'success',
        attempts: (data.attempts || 0) + 1,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      logger.info(\`Successfully processed outbox entry \${doc.id}\`);

    } catch (error: any) {
      // 4. Handle Failure & Retries
      const attempts = (data.attempts || 0) + 1;
      if (attempts >= 4) { // Max 4 attempts total
        await doc.ref.update({
          processed: true,
          status: 'failed_permanent',
          lastError: error.message || 'Unknown error',
          attempts,
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        logger.error(\`Permanently failed outbox entry \${doc.id} after \${attempts} attempts\`);
      } else {
        // Exponential backoff: 2^attempts seconds = 2s, 4s, 8s
        const backoffSeconds = Math.pow(2, attempts);
        const nextRetryAt = admin.firestore.Timestamp.fromMillis(Date.now() + (backoffSeconds * 1000));
        await doc.ref.update({
          status: 'retrying',
          lastError: error.message || 'Unknown error',
          attempts,
          nextRetryAt
        });
        logger.warn(\`Retrying outbox entry \${doc.id}, attempt \${attempts}\`);
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
fs.mkdirSync('server/src/worker', { recursive: true });
fs.writeFileSync('server/src/worker/outbox.worker.ts', workerCode);
console.log('Created outbox.worker.ts');
