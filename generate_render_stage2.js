const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, 'server', 'src');

const typesCode = `import { Request } from 'express';
import * as admin from 'firebase-admin';

export interface AuthenticatedRequest extends Request {
  user?: admin.auth.DecodedIdToken;
  userRole?: string;
}

export interface NotificationPayload {
  notificationId: string;
  type: string;
  title: string;
  body: string;
  division: string;
  batch?: string;
  role?: string;
  lectureId?: string;
  announcementId?: string;
  room?: string;
  subject?: string;
  createdAt: string;
  deepLink?: string;
  priority?: 'high' | 'normal';
}
`;
fs.writeFileSync(path.join(srcDir, 'types', 'index.ts'), typesCode);

const authMiddlewareCode = `import { Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { AuthenticatedRequest } from '../types';

export const requireCRorSR = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Unauthorized: Missing or invalid Bearer token');
    res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    return;
  }

  const token = authHeader.split('Bearer ')[1];
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;

    // Fetch user doc to check role
    const userDoc = await admin.firestore().collection('users').doc(decodedToken.uid).get();
    if (!userDoc.exists) {
      logger.warn('Forbidden: User document not found', { uid: decodedToken.uid });
      res.status(403).json({ error: 'Forbidden: User not found' });
      return;
    }

    const userData = userDoc.data();
    const role = userData?.role;

    if (role !== 'CR' && role !== 'SR') {
      logger.warn('Forbidden: Insufficient permissions', { uid: decodedToken.uid, role });
      res.status(403).json({ error: 'Forbidden: Insufficient privileges' });
      return;
    }

    req.userRole = role;
    next();
  } catch (error) {
    logger.error('Token verification failed', { error });
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
    return;
  }
};
`;
fs.writeFileSync(path.join(srcDir, 'middleware', 'auth.middleware.ts'), authMiddlewareCode);

const rateLimiterCode = `import rateLimit from 'express-rate-limit';
import { logger } from '../utils/logger';

export const notificationRateLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 10, // Limit each IP to 10 notification requests per minute
  message: { error: 'Too many requests, please try again later.' },
  handler: (req, res, next, options) => {
    logger.warn('Rate limit exceeded', { ip: req.ip });
    res.status(options.statusCode).send(options.message);
  }
});
`;
fs.writeFileSync(path.join(srcDir, 'middleware', 'rateLimiter.middleware.ts'), rateLimiterCode);

const validationMiddlewareCode = `import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../types';

export const validateNotificationPayload = (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
  const { notificationId, type, title, body, division } = req.body;

  if (!notificationId || typeof notificationId !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid notificationId' });
    return;
  }
  if (!type || typeof type !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid type' });
    return;
  }
  if (!title || typeof title !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid title' });
    return;
  }
  if (!body || typeof body !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid body' });
    return;
  }
  if (!division || typeof division !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid division' });
    return;
  }

  next();
};
`;
fs.writeFileSync(path.join(srcDir, 'middleware', 'validation.middleware.ts'), validationMiddlewareCode);

const notificationServiceCode = `import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { NotificationPayload } from '../types';

function sanitizeTopic(topic: string): string {
  return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}

function getTargetTopic(division: string, batch?: string, role?: string): string {
  if (role && role !== 'student') {
    return \`\${role}_\${sanitizeTopic(division)}\`;
  }
  if (batch) {
    return \`batch_\${sanitizeTopic(batch)}_\${sanitizeTopic(division)}\`;
  }
  return \`division_\${sanitizeTopic(division)}\`;
}

async function cleanupInvalidTokens(tokens: string[]): Promise<void> {
  logger.info('Cleanup started', { count: tokens.length });
  const db = admin.firestore();
  
  try {
    const batchDb = db.batch();
    for (const token of tokens) {
      const snap = await db.collectionGroup('fcm_tokens').where('token', '==', token).get();
      snap.forEach(doc => {
        batchDb.delete(doc.ref);
      });
    }
    await batchDb.commit();
    logger.info('Invalid tokens removed', { count: tokens.length });
  } catch (error) {
    logger.error('Failed to clean up tokens', { error: (error as Error).message });
  }
}

export async function dispatchNotification(payload: NotificationPayload, uid: string, role: string, isRetry = false): Promise<void> {
  const startTime = Date.now();
  const topic = getTargetTopic(payload.division, payload.batch, payload.role);
  
  const priority = payload.priority || 'normal';
  const ttlSeconds = priority === 'high' ? 3600 : 86400; // 1 hour high, 24 hours normal

  const androidConfig: admin.messaging.AndroidConfig = {
    priority: priority,
    ttl: ttlSeconds * 1000,
    notification: {
      title: payload.title,
      body: payload.body,
      clickAction: 'FLUTTER_NOTIFICATION_CLICK',
    },
  };

  const apnsConfig: admin.messaging.ApnsConfig = {
    headers: {
      'apns-priority': priority === 'high' ? '10' : '5',
      'apns-expiration': Math.floor(Date.now() / 1000 + ttlSeconds).toString(),
    },
    payload: {
      aps: {
        alert: { title: payload.title, body: payload.body },
        sound: 'default',
      },
    },
  };

  const dataPayload: any = {
    notificationId: payload.notificationId,
    type: payload.type,
    title: payload.title,
    body: payload.body,
    division: payload.division,
    createdAt: payload.createdAt || new Date().toISOString(),
  };
  if (payload.batch) dataPayload.batch = payload.batch;
  if (payload.role) dataPayload.role = payload.role;
  if (payload.lectureId) dataPayload.lectureId = payload.lectureId;
  if (payload.announcementId) dataPayload.announcementId = payload.announcementId;
  if (payload.deepLink) dataPayload.deepLink = payload.deepLink;
  if (payload.room) dataPayload.room = payload.room;
  if (payload.subject) dataPayload.subject = payload.subject;

  const message: admin.messaging.Message = {
    topic,
    data: dataPayload,
    android: androidConfig,
    apns: apnsConfig,
    fcmOptions: { analyticsLabel: payload.type },
  };

  try {
    await admin.messaging().send(message);
    const elapsed = Date.now() - startTime;
    logger.info('Delivery Success', { 
      uid, role, division: payload.division, type: payload.type, target: topic, elapsedMs: elapsed 
    });
  } catch (error) {
    const elapsed = Date.now() - startTime;
    logger.error('Delivery Failure', { 
      uid, role, division: payload.division, type: payload.type, target: topic, elapsedMs: elapsed, error: (error as Error).message 
    });

    if (!isRetry) {
      logger.info('Retrying notification dispatch once', { notificationId: payload.notificationId });
      setTimeout(() => dispatchNotification(payload, uid, role, true), 1000);
    }
  }
}
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'notification.service.ts'), notificationServiceCode);

const notificationControllerCode = `import { Response } from 'express';
import { AuthenticatedRequest, NotificationPayload } from '../types';
import { dispatchNotification } from './notification.service';
import { logger } from '../utils/logger';

export const handleSendNotification = (req: AuthenticatedRequest, res: Response): void => {
  const payload: NotificationPayload = req.body;
  
  // Return 202 Accepted immediately (Fire-and-forget)
  res.status(202).json({ message: 'Notification accepted for delivery' });

  // Process asynchronously
  const uid = req.user?.uid || 'unknown';
  const role = req.userRole || 'unknown';
  
  logger.info('Notification accepted, processing async', { notificationId: payload.notificationId, uid });
  
  dispatchNotification(payload, uid, role)
    .catch(err => {
      logger.error('Unhandled error in async notification dispatch', { error: err.message });
    });
};
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'notification.controller.ts'), notificationControllerCode);

const notificationRoutesCode = `import { Router } from 'express';
import { requireCRorSR } from '../middleware/auth.middleware';
import { validateNotificationPayload } from '../middleware/validation.middleware';
import { notificationRateLimiter } from '../middleware/rateLimiter.middleware';
import { handleSendNotification } from '../notifications/notification.controller';

const router = Router();

router.post(
  '/sendNotification',
  notificationRateLimiter,
  requireCRorSR,
  validateNotificationPayload,
  handleSendNotification
);

export default router;
`;
fs.writeFileSync(path.join(srcDir, 'routes', 'notification.routes.ts'), notificationRoutesCode);

const appTsPatchCode = `import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { logger } from './utils/logger';
import notificationRoutes from './routes/notification.routes';

dotenv.config();
import './config/firebase'; // Ensure firebase is initialized

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Schedly Backend Running' });
});

app.use('/api', notificationRoutes);

// Global Error Handler to prevent stack traces from leaking
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled Exception', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal Server Error' });
});

app.listen(PORT, () => {
  logger.info(\`Server is running on port \${PORT}\`);
});

export default app;
`;
fs.writeFileSync(path.join(srcDir, 'app.ts'), appTsPatchCode);

console.log('Stage 2 files generated in /server.');
