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
exports.dispatchNotification = dispatchNotification;
const admin = __importStar(require("firebase-admin"));
function sanitizeTopic(topic) {
    return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}
function getTargetTopic(division, batch, role) {
    if (role && role !== 'student') {
        return `role_${role}_${sanitizeTopic(division)}`;
    }
    if (batch) {
        return `batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}`;
    }
    return `division_${sanitizeTopic(division)}`;
}
async function dispatchNotification(payload) {
    const topic = getTargetTopic(payload.division, payload.batch, payload.role);
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
    const dataPayload = {
        notificationId: payload.notificationId,
        type: payload.type,
        title: payload.title,
        body: payload.body,
        division: payload.division,
        createdAt: payload.createdAt || new Date().toISOString(),
    };
    if (payload.batch)
        dataPayload.batch = payload.batch;
    if (payload.role)
        dataPayload.role = payload.role;
    if (payload.lectureId)
        dataPayload.lectureId = payload.lectureId;
    if (payload.announcementId)
        dataPayload.announcementId = payload.announcementId;
    if (payload.deepLink)
        dataPayload.deepLink = payload.deepLink;
    if (payload.room)
        dataPayload.room = payload.room;
    if (payload.subject)
        dataPayload.subject = payload.subject;
    const message = {
        topic,
        data: dataPayload,
        android: androidConfig,
        apns: apnsConfig,
        fcmOptions: { analyticsLabel: payload.type },
    };
    await admin.messaging().send(message);
}
