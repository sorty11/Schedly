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
}
`;
fs.writeFileSync(path.join(srcDir, 'types', 'index.ts'), typesCode);

const utilsCode = `export function sanitizeTopic(topic: string): string {
  return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}
`;
fs.writeFileSync(path.join(srcDir, 'utils', 'index.ts'), utilsCode);

const topicManagerCode = `import { sanitizeTopic } from '../utils';

export function getTargetTopic(division: string, batch?: string, role?: string): string {
  if (role && role !== 'student') {
    return \`\${role}_\${sanitizeTopic(division)}\`;
  }
  
  if (batch) {
    return \`batch_\${sanitizeTopic(batch)}_\${sanitizeTopic(division)}\`;
  }
  
  return \`division_\${sanitizeTopic(division)}\`;
}
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'topic_manager.ts'), topicManagerCode);

const notificationSenderCode = `import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { NotificationPayload } from '../types';
import { getTargetTopic } from './topic_manager';

export async function sendNotification(payload: NotificationPayload): Promise<void> {
  try {
    const topic = getTargetTopic(payload.division, payload.batch, payload.role);
    logger.info('Sending notification to topic', { topic, notificationId: payload.notificationId });

    const message: admin.messaging.Message = {
      topic: topic,
      data: {
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
      },
      android: {
        priority: payload.priority,
        notification: {
          title: payload.title,
          body: payload.body,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: payload.title,
              body: payload.body,
            },
            sound: 'default',
          },
        },
      },
    };

    const messageId = await admin.messaging().send(message);
    logger.info('Successfully sent message to topic', { messageId, topic });
  } catch (error) {
    logger.error('Failed to send notification via topic', { error, payload });
    // Fallback to token multicast if necessary could be implemented here
  }
}

export async function cleanupInvalidTokens(tokens: string[]): Promise<void> {
  // If we ever use sendEachForMulticast, we call this function for failures
  // For topics, FCM handles dead tokens internally on their end, but we can clean our DB if we want.
  // Topic-based sending does not return invalid tokens directly.
  logger.info('Clean up invalid tokens called', { count: tokens.length });
}
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'notification_sender.ts'), notificationSenderCode);

const announcementTriggerCode = `import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { sendNotification } from './notification_sender';
import { NotificationPayload } from '../types';

export const onAnnouncementCreated = onDocumentCreated('announcements/{announcementId}', async (event) => {
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

  logger.info('Announcement trigger received', { announcementId: event.params.announcementId });

  const payload: NotificationPayload = {
    notificationId: \`announcement_\${event.params.announcementId}\`,
    type: 'announcement',
    title: data.title || 'New Announcement',
    body: data.message || '',
    division: division,
    batch: data.batch, // optional
    role: data.role,   // optional
    announcementId: event.params.announcementId,
    createdAt: new Date().toISOString(),
    deepLink: \`/announcements/\${event.params.announcementId}\`,
    priority: 'high',
  };

  logger.info('Announcement payload created', { payload });

  try {
    await sendNotification(payload);
  } catch (error) {
    logger.error('Failed to process announcement notification', { error });
  }
});
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'announcement_trigger.ts'), announcementTriggerCode);

const lectureTriggerCode = `import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { sendNotification } from './notification_sender';
import { NotificationPayload } from '../types';

export const onNotificationCreated = onDocumentCreated('sections/{divisionId}/notifications/{notificationId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.error('No data associated with the notification event');
    return;
  }

  const data = snapshot.data();
  const division = event.params.divisionId;

  logger.info('Lecture/Timetable trigger received', { notificationId: event.params.notificationId });

  const payload: NotificationPayload = {
    notificationId: \`timetable_\${event.params.notificationId}\`,
    type: data.type || 'timetable_updated',
    title: data.title || 'Timetable Update',
    body: data.message || '',
    division: division,
    lectureId: data.lectureId,
    createdAt: new Date().toISOString(),
    deepLink: \`/timetable/\${data.lectureId || ''}\`,
    priority: 'high',
  };

  logger.info('Lecture payload created', { payload });

  try {
    await sendNotification(payload);
  } catch (error) {
    logger.error('Failed to process lecture notification', { error });
  }
});
`;
fs.writeFileSync(path.join(srcDir, 'notifications', 'lecture_trigger.ts'), lectureTriggerCode);

const indexCode = `import * as admin from 'firebase-admin';

admin.initializeApp();

export { onAnnouncementCreated } from './notifications/announcement_trigger';
export { onNotificationCreated } from './notifications/lecture_trigger';
`;
fs.writeFileSync(path.join(srcDir, 'index.ts'), indexCode);

console.log('Stage 3 files generated.');
