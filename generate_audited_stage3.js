const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, 'functions', 'src');

const typesCode = `export interface NotificationPayload {
  notificationId: string;
  type: string;
  title: string;
  body: string;
  division: string;
  batch?: string;
  role?: string;
  lectureId?: string;
  announcementId?: string;
  createdAt: string;
  deepLink: string;
  priority: 'high' | 'normal';
  collapseKey?: string;
  ttlSeconds: number;
}
`;
fs.writeFileSync(path.join(srcDir, 'types', 'index.ts'), typesCode);

const notificationSenderCode = `import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { NotificationPayload } from '../types';
import { getTargetTopic } from './topic_manager';

export async function sendNotification(payload: NotificationPayload, tokens?: string[]): Promise<void> {
  try {
    const androidConfig: admin.messaging.AndroidConfig = {
      priority: payload.priority,
      ttl: payload.ttlSeconds * 1000,
      collapseKey: payload.collapseKey,
      notification: {
        title: payload.title,
        body: payload.body,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    const apnsConfig: admin.messaging.ApnsConfig = {
      headers: {
        'apns-priority': payload.priority === 'high' ? '10' : '5',
        'apns-expiration': Math.floor(Date.now() / 1000 + payload.ttlSeconds).toString(),
        ...(payload.collapseKey && { 'apns-collapse-id': payload.collapseKey }),
      },
      payload: {
        aps: {
          alert: {
            title: payload.title,
            body: payload.body,
          },
          sound: 'default',
        },
      },
    };

    const webpushConfig: admin.messaging.WebpushConfig = {
      headers: {
        TTL: payload.ttlSeconds.toString(),
        ...(payload.collapseKey && { Topic: payload.collapseKey }),
      },
      notification: {
        title: payload.title,
        body: payload.body,
      },
    };

    const dataPayload = {
      notificationId: payload.notificationId,
      type: payload.type,
      title: payload.title,
      body: payload.body,
      division: payload.division,
      batch: payload.batch || '',
      role: payload.role || '',
      lectureId: payload.lectureId || '',
      announcementId: payload.announcementId || '',
      createdAt: payload.createdAt,
      deepLink: payload.deepLink,
    };

    if (tokens && tokens.length > 0) {
      logger.info('Sending multicast notification', { count: tokens.length, notificationId: payload.notificationId });
      const message: admin.messaging.MulticastMessage = {
        tokens,
        data: dataPayload,
        android: androidConfig,
        apns: apnsConfig,
        webpush: webpushConfig,
        fcmOptions: { analyticsLabel: payload.type },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      logger.info('Delivery success (multicast)', { successCount: response.successCount, failureCount: response.failureCount });

      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((res, idx) => {
          if (!res.success && res.error) {
            const errorCode = res.error.code;
            if (
              errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered'
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });
        if (invalidTokens.length > 0) {
          await cleanupInvalidTokens(invalidTokens);
        }
      }
    } else {
      const topic = getTargetTopic(payload.division, payload.batch, payload.role);
      logger.info('Sending notification to topic', { topic, notificationId: payload.notificationId });

      const message: admin.messaging.Message = {
        topic,
        data: dataPayload,
        android: androidConfig,
        apns: apnsConfig,
        webpush: webpushConfig,
        fcmOptions: { analyticsLabel: payload.type },
      };

      const messageId = await admin.messaging().send(message);
      logger.info('Delivery success (topic)', { messageId, topic });
    }
  } catch (error) {
    logger.error('Delivery failure', { error, payload });
    throw error;
  }
}

export async function cleanupInvalidTokens(tokens: string[]): Promise<void> {
  logger.info('Cleanup started', { count: tokens.length });
  const db = admin.firestore();
  
  // To safely delete tokens, we would query the subcollection group or known paths.
  // Assuming a subcollection group query since token is the doc ID.
  try {
    const batch = db.batch();
    for (const token of tokens) {
      const snap = await db.collectionGroup('fcm_tokens').where('token', '==', token).get();
      snap.forEach(doc => {
        batch.delete(doc.ref);
      });
    }
    await batch.commit();
    logger.info('Invalid tokens removed', { count: tokens.length });
  } catch (error) {
    logger.error('Failed to clean up tokens', { error });
  }
}
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'notification_sender.ts'), notificationSenderCode);

const idempotencyCode = `import * as admin from 'firebase-admin';

export async function checkIdempotency(eventId: string): Promise<boolean> {
  const db = admin.firestore();
  const ref = db.collection('_event_tracker').doc(eventId);
  
  try {
    return await db.runTransaction(async (t) => {
      const doc = await t.get(ref);
      if (doc.exists) {
        return false; // Already processed
      }
      t.set(ref, { processedAt: admin.firestore.FieldValue.serverTimestamp() });
      return true;
    });
  } catch (e) {
    return false; // Fail safe
  }
}
`;
fs.writeFileSync(path.join(srcDir, 'utils', 'idempotency.ts'), idempotencyCode);

const announcementTriggerCode = `import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { sendNotification } from './notification_sender';
import { NotificationPayload } from '../types';
import { checkIdempotency } from '../utils/idempotency';

export const onAnnouncementCreated = onDocumentCreated('announcements/{announcementId}', async (event) => {
  logger.info('Trigger started: onAnnouncementCreated', { eventId: event.id, announcementId: event.params.announcementId });

  const isNewEvent = await checkIdempotency(event.id);
  if (!isNewEvent) {
    logger.info('Duplicate event ignored', { eventId: event.id });
    return;
  }

  const snapshot = event.data;
  if (!snapshot) {
    logger.error('No data associated with the announcement event');
    return;
  }

  const data = snapshot.data();
  const division = data.division;
  
  if (!division) {
    logger.error('Announcement missing division', { announcementId: event.params.announcementId });
    return;
  }

  // Emergency announcements have high priority, normal otherwise
  const isEmergency = data.isEmergency === true;

  const payload: NotificationPayload = {
    notificationId: \`announcement_\${event.params.announcementId}\`,
    type: 'announcement',
    title: data.title || 'New Announcement',
    body: data.message || '',
    division: division,
    batch: data.batch,
    role: data.role,
    announcementId: event.params.announcementId,
    createdAt: new Date().toISOString(),
    deepLink: \`/announcements/\${event.params.announcementId}\`,
    priority: isEmergency ? 'high' : 'normal',
    collapseKey: 'announcement_update',
    ttlSeconds: 24 * 60 * 60, // 24 hours
  };

  logger.info('Payload generated', { payload });

  try {
    await sendNotification(payload);
  } catch (error) {
    logger.error('Trigger retry requested', { error });
    throw error; // Cloud Functions will retry if configured
  }
});
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'announcement_trigger.ts'), announcementTriggerCode);

const lectureTriggerCode = `import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { sendNotification } from './notification_sender';
import { NotificationPayload } from '../types';
import { checkIdempotency } from '../utils/idempotency';

export const onNotificationCreated = onDocumentCreated('sections/{divisionId}/notifications/{notificationId}', async (event) => {
  logger.info('Trigger started: onNotificationCreated', { eventId: event.id, notificationId: event.params.notificationId });

  const isNewEvent = await checkIdempotency(event.id);
  if (!isNewEvent) {
    logger.info('Duplicate event ignored', { eventId: event.id });
    return;
  }

  const snapshot = event.data;
  if (!snapshot) {
    logger.error('No data associated with the notification event');
    return;
  }

  const data = snapshot.data();
  const division = event.params.divisionId;

  const type = data.type || 'timetable_updated';
  let priority: 'high' | 'normal' = 'normal';
  let ttlSeconds = 7 * 24 * 60 * 60; // 7 days by default

  if (type === 'lecture_cancelled' || type === 'lecture_replaced') {
    priority = 'high';
    ttlSeconds = 60 * 60; // 1 hour for urgent lecture changes
  }

  const payload: NotificationPayload = {
    notificationId: \`timetable_\${event.params.notificationId}\`,
    type: type,
    title: data.title || 'Timetable Update',
    body: data.message || '',
    division: division,
    lectureId: data.lectureId,
    createdAt: new Date().toISOString(),
    deepLink: \`/timetable/\${data.lectureId || ''}\`,
    priority: priority,
    collapseKey: 'timetable_update',
    ttlSeconds: ttlSeconds,
  };

  logger.info('Payload generated', { payload });

  try {
    await sendNotification(payload);
  } catch (error) {
    logger.error('Trigger retry requested', { error });
    throw error; 
  }
});
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'lecture_trigger.ts'), lectureTriggerCode);

console.log('Audited Stage 3 files generated.');
