import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { NotificationPayload } from '../types';

export function sanitizeTopic(topic: string): string {
  return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}

export function getTargetTopic(division: string, batch?: string, role?: string, subject?: string): string {
  const normalizedRole = role?.toLowerCase();
  if (normalizedRole === 'faculty') {
    return `faculty_${sanitizeTopic(division)}`;
  }
  if (normalizedRole === 'sr' && subject) {
    return `role_sr_${sanitizeTopic(division)}_${sanitizeTopic(subject)}`;
  }
  if (normalizedRole && normalizedRole !== 'student') {
    return `role_${normalizedRole}_${sanitizeTopic(division)}`;
  }
  if (batch) {
    return `batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}`;
  }
  return `division_${sanitizeTopic(division)}`;
}

export function getAllTargetTopics(division: string, batch?: string, role?: string, subject?: string): string[] {
  const topics: string[] = [];
  const normalizedRole = role?.toLowerCase();
  
  if (normalizedRole === 'faculty') {
    topics.push(`faculty_${sanitizeTopic(division)}`);
  } else {
    topics.push(`division_${sanitizeTopic(division)}`);
    if (normalizedRole === 'sr' && subject) {
      topics.push(`role_sr_${sanitizeTopic(division)}_${sanitizeTopic(subject)}`);
    } else if (normalizedRole && normalizedRole !== 'student') {
      topics.push(`role_${normalizedRole}_${sanitizeTopic(division)}`);
    }
    if (batch) {
      topics.push(`batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}`);
    }
  }
  return topics;
}

export async function dispatchNotification(payload: NotificationPayload): Promise<void> {
  const topic = getTargetTopic(payload.division, payload.batch, payload.role, payload.subject);
  logger.info(`[TOPIC] Resolved topic: ${topic} from division=${payload.division}, batch=${payload.batch}, role=${payload.role}, subject=${payload.subject}`);
  
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

  const link = payload.deepLink || '/';
  const webpushConfig: admin.messaging.WebpushConfig = {
    notification: {
      title: payload.title,
      body: payload.body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: payload.notificationId || 'schedly-notification',
      renotify: true,
      vibrate: [200, 100, 200],
    },
    fcmOptions: {
      link,
    },
    data: dataPayload,
  };

  const message: admin.messaging.Message = {
    topic,
    data: dataPayload,
    android: androidConfig,
    apns: apnsConfig,
    webpush: webpushConfig,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    fcmOptions: { analyticsLabel: payload.type },
  };

  logger.info(`[FCM] Sending payload to topic ${topic}: ${JSON.stringify(message)}`);

  try {
    const messageId = await admin.messaging().send(message);
  } catch (error: any) {
    logger.error(`[FCM_SEND] FAILURE | Topic: ${topic} | Error Code: ${error.code} | Message: ${error.message}`);
    throw error;
  }
}
