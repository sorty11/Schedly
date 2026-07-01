const fs = require('fs');
const path = require('path');

// 1. Create env.config.ts
const envConfigCode = `import dotenv from 'dotenv';
dotenv.config();

export const AppConfig = {
  VERSION: process.env.APP_VERSION || '1.0.1',
  PORT: process.env.PORT || 3000,
};

export const WorkerConfig = {
  FAST_INTERVAL_MS: parseInt(process.env.WORKER_FAST_INTERVAL_MS || '5000', 10),
  IDLE_INTERVAL_MS: parseInt(process.env.WORKER_IDLE_INTERVAL_MS || '30000', 10),
  MAX_RETRY_COUNT: parseInt(process.env.MAX_RETRY_COUNT || '5', 10),
  MAX_BACKOFF_SECONDS: parseInt(process.env.MAX_BACKOFF_SECONDS || '64', 10),
  OUTBOX_RETENTION_DAYS: parseInt(process.env.OUTBOX_RETENTION_DAYS || '7', 10),
};
`;

fs.writeFileSync(path.join(__dirname, 'server/src/config/env.config.ts'), envConfigCode);

// 2. Rewrite notification.service.ts
const notifServiceCode = `import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { NotificationPayload } from '../types';

function sanitizeTopic(topic: string): string {
  return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}

function getTargetTopic(division: string, batch?: string, role?: string): string {
  if (role && role !== 'student') {
    return \`role_\${role}_\${sanitizeTopic(division)}\`;
  }
  if (batch) {
    return \`batch_\${sanitizeTopic(batch)}_\${sanitizeTopic(division)}\`;
  }
  return \`division_\${sanitizeTopic(division)}\`;
}

export async function dispatchNotification(payload: NotificationPayload): Promise<void> {
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

  await admin.messaging().send(message);
}
`;

fs.writeFileSync(path.join(__dirname, 'server/src/notifications/notification.service.ts'), notifServiceCode);

console.log('Done backend stage 3 and 4.');
