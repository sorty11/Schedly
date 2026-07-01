import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../types';

export const validateNotificationPayload = (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
  const { notificationId, type, title, body, division } = req.body;

  if (!notificationId || typeof notificationId !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid notificationId' });
    return;
  }
  if (!type || typeof type !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid type' });
    return;
  }
  if (!title || typeof title !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid title' });
    return;
  }
  if (!body || typeof body !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid body' });
    return;
  }
  if (!division || typeof division !== 'string') {
    res.status(400).json({ error: 'Bad Request: Missing or invalid division' });
    return;
  }

  next();
};
