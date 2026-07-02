import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { NotificationPayload } from '../types';

function sanitizeTopic(topic: string): string {
  return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}

function getTargetTopic(division: string, batch?: string, role?: string): string {
  if (role && role !== 'student') {
    return `role_${role}_${sanitizeTopic(division)}`;
  }
  if (batch) {
    return `batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}`;
  }
  return `division_${sanitizeTopic(division)}`;
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

  const rawPayload: any = {
    notificationId: payload.notificationId,
    type: payload.type,
    title: payload.title,
    body: payload.body,
    division: payload.division,
    createdAt: payload.createdAt || new Date().toISOString(),
  };
  if (payload.batch) rawPayload.batch = payload.batch;
  if (payload.role) rawPayload.role = payload.role;
  if (payload.lectureId) rawPayload.lectureId = payload.lectureId;
  if (payload.announcementId) rawPayload.announcementId = payload.announcementId;
  if (payload.deepLink) rawPayload.deepLink = payload.deepLink;
  if (payload.room) rawPayload.room = payload.room;
  if (payload.subject) rawPayload.subject = payload.subject;

  const dataPayload: Record<string, string> = {};
  for (const key of Object.keys(rawPayload)) {
    const val = rawPayload[key];
    if (val != null) {
      if (typeof val.toDate === 'function') {
        dataPayload[key] = val.toDate().toISOString();
      } else {
        dataPayload[key] = String(val);
      }
    }
  }

  const message: admin.messaging.Message = {
    topic,
    data: dataPayload,
    android: androidConfig,
    apns: apnsConfig,
    fcmOptions: { analyticsLabel: payload.type },
  };

  await admin.messaging().send(message);
}
