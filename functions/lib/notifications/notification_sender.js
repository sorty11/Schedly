"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendNotification = sendNotification;
exports.cleanupInvalidTokens = cleanupInvalidTokens;
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const topic_manager_1 = require("./topic_manager");
async function sendNotification(payload, tokens) {
    try {
        const androidConfig = {
            priority: payload.priority,
            ttl: payload.ttlSeconds * 1000,
            collapseKey: payload.collapseKey,
            notification: {
                title: payload.title,
                body: payload.body,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
        };
        const apnsConfig = {
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
        const webpushConfig = {
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
            const message = {
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
                const invalidTokens = [];
                response.responses.forEach((res, idx) => {
                    if (!res.success && res.error) {
                        const errorCode = res.error.code;
                        if (errorCode === 'messaging/invalid-registration-token' ||
                            errorCode === 'messaging/registration-token-not-registered') {
                            invalidTokens.push(tokens[idx]);
                        }
                    }
                });
                if (invalidTokens.length > 0) {
                    await cleanupInvalidTokens(invalidTokens);
                }
            }
        }
        else {
            const topic = (0, topic_manager_1.getTargetTopic)(payload.division, payload.batch, payload.role);
            logger.info('Sending notification to topic', { topic, notificationId: payload.notificationId });
            const message = {
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
    }
    catch (error) {
        logger.error('Delivery failure', { error, payload });
        throw error;
    }
}
async function cleanupInvalidTokens(tokens) {
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
    }
    catch (error) {
        logger.error('Failed to clean up tokens', { error });
    }
}
//# sourceMappingURL=notification_sender.js.map