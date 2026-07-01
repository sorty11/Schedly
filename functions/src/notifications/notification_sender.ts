import * as admin from 'firebase-admin';
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
