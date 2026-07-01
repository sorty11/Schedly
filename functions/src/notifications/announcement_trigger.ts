import { onDocumentCreated } from 'firebase-functions/v2/firestore';
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
    notificationId: `announcement_${event.params.announcementId}`,
    type: 'announcement',
    title: data.title || 'New Announcement',
    body: data.message || '',
    division: division,
    batch: data.batch,
    role: data.role,
    announcementId: event.params.announcementId,
    createdAt: new Date().toISOString(),
    deepLink: `/announcements/${event.params.announcementId}`,
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
