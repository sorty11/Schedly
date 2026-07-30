"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sanitizeTopic = sanitizeTopic;
exports.getTargetTopic = getTargetTopic;
exports.dispatchNotification = dispatchNotification;
const admin = __importStar(require("firebase-admin"));
const logger_1 = require("../utils/logger");
function sanitizeTopic(topic) {
    return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}
function getTargetTopic(division, batch, role) {
    const normalizedRole = role?.toLowerCase();
    if (normalizedRole === 'faculty') {
        return `faculty_${sanitizeTopic(division)}`;
    }
    if (normalizedRole && normalizedRole !== 'student') {
        return `role_${normalizedRole}_${sanitizeTopic(division)}`;
    }
    if (batch) {
        return `batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}`;
    }
    return `division_${sanitizeTopic(division)}`;
}
async function dispatchNotification(payload) {
    const topic = getTargetTopic(payload.division, payload.batch, payload.role);
    logger_1.logger.info(`[TOPIC] Resolved topic: ${topic} from division=${payload.division}, batch=${payload.batch}, role=${payload.role}`);
    const priority = payload.priority || 'normal';
    const ttlSeconds = priority === 'high' ? 3600 : 86400; // 1 hour high, 24 hours normal
    const androidConfig = {
        priority: priority,
        ttl: ttlSeconds * 1000,
        notification: {
            title: payload.title,
            body: payload.body,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
    };
    const apnsConfig = {
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
    const rawPayload = {
        notificationId: payload.notificationId,
        type: payload.type,
        title: payload.title,
        body: payload.body,
        division: payload.division,
        createdAt: payload.createdAt || new Date().toISOString(),
    };
    if (payload.batch)
        rawPayload.batch = payload.batch;
    if (payload.role)
        rawPayload.role = payload.role;
    if (payload.lectureId)
        rawPayload.lectureId = payload.lectureId;
    if (payload.announcementId)
        rawPayload.announcementId = payload.announcementId;
    if (payload.deepLink)
        rawPayload.deepLink = payload.deepLink;
    if (payload.room)
        rawPayload.room = payload.room;
    if (payload.subject)
        rawPayload.subject = payload.subject;
    const dataPayload = {};
    for (const key of Object.keys(rawPayload)) {
        const val = rawPayload[key];
        if (val != null) {
            if (typeof val.toDate === 'function') {
                dataPayload[key] = val.toDate().toISOString();
            }
            else {
                dataPayload[key] = String(val);
            }
        }
    }
    const link = payload.deepLink || '/';
    const webpushConfig = {
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
    const message = {
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
    logger_1.logger.info(`[FCM] Sending payload to topic ${topic}: ${JSON.stringify(message)}`);
    try {
        const messageId = await admin.messaging().send(message);
    }
    catch (error) {
        logger_1.logger.error(`[FCM_SEND] FAILURE | Topic: ${topic} | Error Code: ${error.code} | Message: ${error.message}`);
        throw error;
    }
}
