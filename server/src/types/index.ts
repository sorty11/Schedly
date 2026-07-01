import { Request } from 'express';
import * as admin from 'firebase-admin';

export interface AuthenticatedRequest extends Request {
  user?: admin.auth.DecodedIdToken;
  userRole?: string;
}

export interface NotificationPayload {
  notificationId: string;
  type: string;
  title: string;
  body: string;
  division: string;
  batch?: string;
  role?: string;
  lectureId?: string;
  announcementId?: string;
  room?: string;
  subject?: string;
  createdAt: string;
  deepLink?: string;
  priority?: 'high' | 'normal';
}
