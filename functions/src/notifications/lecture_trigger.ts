import { onDocumentCreated } from 'firebase-functions/v2/firestore';
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
    await sendNotification(payload);
  } catch (error) {
    logger.error('Trigger retry requested', { error });
    throw error; 
  }
});
