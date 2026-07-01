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
  createdAt: string;
  deepLink: string;
  priority: 'high' | 'normal';
  collapseKey?: string;
  ttlSeconds: number;
}
