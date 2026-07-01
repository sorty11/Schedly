import { Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { AuthenticatedRequest } from '../types';

export const requireCRorSR = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Unauthorized: Missing or invalid Bearer token');
    res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    return;
  }

  const token = authHeader.split('Bearer ')[1];
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;

    // Fetch user doc to check role
    const userDoc = await admin.firestore().collection('users').doc(decodedToken.uid).get();
    if (!userDoc.exists) {
      logger.warn('Forbidden: User document not found', { uid: decodedToken.uid });
      res.status(403).json({ error: 'Forbidden: User not found' });
      return;
    }

    const userData = userDoc.data();
    const role = userData?.role;

    if (role !== 'CR' && role !== 'SR') {
      logger.warn('Forbidden: Insufficient permissions', { uid: decodedToken.uid, role });
      res.status(403).json({ error: 'Forbidden: Insufficient privileges' });
      return;
    }

    req.userRole = role;
    next();
  } catch (error) {
    logger.error('Token verification failed', { error });
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
    return;
  }
};

export const verifyIdToken = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Unauthorized: Missing or invalid Bearer token');
    res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    return;
  }

  const token = authHeader.split('Bearer ')[1];
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    logger.error('Token verification failed', { error });
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
    return;
  }
};
