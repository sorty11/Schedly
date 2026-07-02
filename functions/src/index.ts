import * as admin from 'firebase-admin';

admin.initializeApp();

export { onAnnouncementCreated } from './notifications/announcement_trigger';
export { onNotificationCreated } from './notifications/lecture_trigger';
export { onTokenWritten } from './notifications/token_trigger';
