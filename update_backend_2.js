const fs = require('fs');
const path = require('path');

// 1. Rewrite outbox.worker.ts with config, logging, and stats
const workerCode = `import * as admin from 'firebase-admin';
import { dispatchNotification } from '../notifications/notification.service';
import { logger } from '../utils/logger';
import { WorkerConfig } from '../config/env.config';

export class OutboxWorker {
  private _isRunning = false;
  private isProcessing = false;
  private timer: NodeJS.Timeout | null = null;
  
  private currentPollMs = WorkerConfig.IDLE_INTERVAL_MS;

  // Stats
  private stats = {
    pending: 0,
    processedToday: 0,
    failedToday: 0,
    deadLetters: 0,
    lastReset: new Date().toDateString(),
    totalProcessingTime: 0,
  };

  constructor() {
    this.currentPollMs = WorkerConfig.IDLE_INTERVAL_MS;
  }

  public isRunning() {
    return this._isRunning;
  }

  public getStats() {
    this.checkResetStats();
    const avg = this.stats.processedToday > 0 ? (this.stats.totalProcessingTime / this.stats.processedToday).toFixed(2) : 0;
    return {
      workerState: this._isRunning ? (this.isProcessing ? 'processing' : 'idle') : 'stopped',
      queueLength: this.stats.pending,
      processedToday: this.stats.processedToday,
      failedToday: this.stats.failedToday,
      deadLetters: this.stats.deadLetters,
      pollingInterval: \`\${this.currentPollMs}ms\`,
      averageProcessingTime: \`\${avg}ms\`
    };
  }

  private checkResetStats() {
    const today = new Date().toDateString();
    if (this.stats.lastReset !== today) {
      this.stats.processedToday = 0;
      this.stats.failedToday = 0;
      this.stats.deadLetters = 0;
      this.stats.totalProcessingTime = 0;
      this.stats.lastReset = today;
    }
  }

  public start() {
    if (this._isRunning) return;
    this._isRunning = true;
    
    logger.info(JSON.stringify({
      event: 'worker_started',
      status: 'SUCCESS',
      timestamp: new Date().toISOString()
    }));
    
    this.scheduleNext(0);
  }

  public stop() {
    this._isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    
    logger.info(JSON.stringify({
      event: 'worker_stopped',
      status: 'SUCCESS',
      timestamp: new Date().toISOString()
    }));
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
    const loopStartTime = Date.now();
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
        this.currentPollMs = Math.min(this.currentPollMs * 1.5, WorkerConfig.IDLE_INTERVAL_MS);
      } else {
        this.currentPollMs = WorkerConfig.FAST_INTERVAL_MS;
        
        const workerLatency = Date.now() - loopStartTime;
        logger.info(JSON.stringify({
           event: 'queue_found',
           queueLength: snapshot.size,
           workerLatency,
           status: 'SUCCESS',
           timestamp: new Date().toISOString()
        }));

        for (const doc of snapshot.docs) {
          await this.processSingleEntry(doc, workerLatency);
        }
      }
      
      if (Math.random() < 0.01) {
        await this.cleanupOldRecords();
      }

    } catch (error) {
      logger.error(JSON.stringify({
        event: 'worker_error',
        status: 'ERROR',
        error: (error as Error).message,
        timestamp: new Date().toISOString()
      }));
    } finally {
      this.isProcessing = false;
      this.scheduleNext(this.currentPollMs);
    }
  }

  private async processSingleEntry(doc: admin.firestore.QueryDocumentSnapshot, workerLatency: number) {
    const data = doc.data();
    const uid = data.uid;
    const notificationId = data.notificationId || doc.id;
    const division = data.division || 'unknown';
    const type = data.type || 'unknown';
    const db = admin.firestore();
    const attemptNum = (data.attempts || 0) + 1;
    const startTime = Date.now();

    try {
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
        const processingTime = Date.now() - startTime;
        await doc.ref.update({
          processed: true,
          status: 'DEAD',
          lastError: 'Unauthorized user',
          attempts: attemptNum,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastAttempt: admin.firestore.FieldValue.serverTimestamp()
        });
        this.stats.failedToday++;
        this.stats.deadLetters++;
        
        logger.warn(JSON.stringify({
           event: 'notification_processed',
           notificationType: type,
           division,
           workerLatency,
           attempt: attemptNum,
           status: 'DEAD',
           processingTime,
           error: 'Unauthorized user',
           timestamp: new Date().toISOString()
        }));
        return;
      }

      await dispatchNotification(data as any);
      
      const processingTime = Date.now() - startTime;
      await doc.ref.update({
        processed: true,
        status: 'SUCCESS',
        attempts: attemptNum,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAttempt: admin.firestore.FieldValue.serverTimestamp()
      });
      this.stats.processedToday++;
      this.stats.totalProcessingTime += processingTime;
      
      logger.info(JSON.stringify({
         event: 'notification_processed',
         notificationType: type,
         division,
         workerLatency,
         attempt: attemptNum,
         status: 'SUCCESS',
         processingTime,
         timestamp: new Date().toISOString()
      }));

    } catch (error: any) {
      const processingTime = Date.now() - startTime;
      const errorMessage = error.message || 'Unknown error';
      
      if (attemptNum >= WorkerConfig.MAX_RETRY_COUNT) {
        await doc.ref.update({
          processed: true,
          status: 'DEAD',
          lastError: errorMessage,
          attempts: attemptNum,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastAttempt: admin.firestore.FieldValue.serverTimestamp()
        });
        this.stats.failedToday++;
        this.stats.deadLetters++;
        
        logger.error(JSON.stringify({
           event: 'notification_processed',
           notificationType: type,
           division,
           workerLatency,
           attempt: attemptNum,
           status: 'DEAD',
           processingTime,
           error: errorMessage,
           timestamp: new Date().toISOString()
        }));
      } else {
        const backoffSeconds = Math.min(Math.pow(2, attemptNum), WorkerConfig.MAX_BACKOFF_SECONDS);
        const nextRetryAt = admin.firestore.Timestamp.fromMillis(Date.now() + (backoffSeconds * 1000));
        await doc.ref.update({
          status: 'RETRYING',
          lastError: errorMessage,
          attempts: attemptNum,
          nextRetryAt,
          lastAttempt: admin.firestore.FieldValue.serverTimestamp()
        });
        this.stats.failedToday++;
        
        logger.warn(JSON.stringify({
           event: 'notification_retry',
           notificationType: type,
           division,
           workerLatency,
           attempt: attemptNum,
           status: 'RETRYING',
           processingTime,
           error: errorMessage,
           timestamp: new Date().toISOString()
        }));
      }
    }
  }

  private async cleanupOldRecords() {
    try {
      const db = admin.firestore();
      const retentionMs = WorkerConfig.OUTBOX_RETENTION_DAYS * 24 * 60 * 60 * 1000;
      const retentionLimit = admin.firestore.Timestamp.fromMillis(Date.now() - retentionMs);
      
      const snapshot = await db.collection('notification_outbox')
        .where('processed', '==', true)
        .where('processedAt', '<', retentionLimit)
        .limit(100)
        .get();
        
      if (!snapshot.empty) {
        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        
        logger.info(JSON.stringify({
          event: 'cleanup_run',
          status: 'SUCCESS',
          recordsCleaned: snapshot.size,
          timestamp: new Date().toISOString()
        }));
      }
    } catch (error) {
      logger.error(JSON.stringify({
          event: 'cleanup_run',
          status: 'ERROR',
          error: (error as Error).message,
          timestamp: new Date().toISOString()
      }));
    }
  }
}
`;
fs.writeFileSync(path.join(__dirname, 'server/src/worker/outbox.worker.ts'), workerCode);

// 2. Rewrite app.ts to use versioned routes
const appCode = `import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { logger } from './utils/logger';
import { OutboxWorker } from './worker/outbox.worker';
import { AppConfig } from './config/env.config';
import apiV1Routes from './routes/api.v1.routes';

dotenv.config();
import './config/firebase'; // Ensure firebase is initialized

const app = express();

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

export const worker = new OutboxWorker();

app.get('/', (req, res) => {
  res.json({
    service: "Schedly Notification API",
    version: AppConfig.VERSION,
    status: "running"
  });
});

app.use('/api/v1', apiV1Routes);

// Global Error Handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error(JSON.stringify({
    event: 'unhandled_exception',
    status: 'ERROR',
    error: err.message,
    timestamp: new Date().toISOString()
  }));
  res.status(500).json({ error: 'Internal Server Error' });
});

worker.start();

app.listen(AppConfig.PORT, () => {
  logger.info(JSON.stringify({
    event: 'server_start',
    status: 'SUCCESS',
    port: AppConfig.PORT,
    timestamp: new Date().toISOString()
  }));
});

export default app;
`;
fs.writeFileSync(path.join(__dirname, 'server/src/app.ts'), appCode);

// 3. Create api.v1.routes.ts
const apiV1Code = `import { Router } from 'express';
import { worker } from '../app';
import { AppConfig } from '../config/env.config';
import * as admin from 'firebase-admin';

const router = Router();

router.get('/health', async (req, res) => {
  try {
    const stats = worker.getStats();
    let firebaseStatus = 'connected';
    try {
      await admin.auth().listUsers(1);
    } catch(e) {
      firebaseStatus = 'error';
    }
    
    res.status(200).json({
      status: 'healthy',
      version: AppConfig.VERSION,
      worker: stats.workerState,
      firebase: firebaseStatus,
      uptime: \`\${process.uptime()}s\`,
      queueLength: stats.queueLength,
      processedToday: stats.processedToday,
      failedToday: stats.failedToday,
      deadLetters: stats.deadLetters,
      pollingInterval: stats.pollingInterval,
      averageProcessingTime: stats.averageProcessingTime
    });
  } catch(e) {
    res.status(500).json({ status: 'error', message: 'Failed to fetch health' });
  }
});

router.get('/stats', (req, res) => {
  res.status(501).json({ error: 'Not Implemented' });
});

router.get('/admin', (req, res) => {
  res.status(501).json({ error: 'Not Implemented' });
});

export default router;
`;
fs.writeFileSync(path.join(__dirname, 'server/src/routes/api.v1.routes.ts'), apiV1Code);

console.log('Done backend stage 5, 6, 7.');
