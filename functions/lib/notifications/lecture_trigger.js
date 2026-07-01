"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNotificationCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const notification_sender_1 = require("./notification_sender");
const idempotency_1 = require("../utils/idempotency");
exports.onNotificationCreated = (0, firestore_1.onDocumentCreated)('sections/{divisionId}/notifications/{notificationId}', async (event) => {
    logger.info('Trigger started: onNotificationCreated', { eventId: event.id, notificationId: event.params.notificationId });
    const isNewEvent = await (0, idempotency_1.checkIdempotency)(event.id);
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
    let priority = 'normal';
    let ttlSeconds = 7 * 24 * 60 * 60; // 7 days by default
    if (type === 'lecture_cancelled' || type === 'lecture_replaced') {
        priority = 'high';
        ttlSeconds = 60 * 60; // 1 hour for urgent lecture changes
    }
    const payload = {
        notificationId: `timetable_${event.params.notificationId}`,
        type: type,
        title: data.title || 'Timetable Update',
        body: data.message || '',
        division: division,
        lectureId: data.lectureId,
        createdAt: new Date().toISOString(),
        deepLink: `/timetable/${data.lectureId || ''}`,
        priority: priority,
        collapseKey: 'timetable_update',
        ttlSeconds: ttlSeconds,
    };
    logger.info('Payload generated', { payload });
    try {
        await (0, notification_sender_1.sendNotification)(payload);
    }
    catch (error) {
        logger.error('Trigger retry requested', { error });
        throw error;
    }
});
//# sourceMappingURL=lecture_trigger.js.map