import { Router } from 'express';
import { worker } from '../app';
import { AppConfig } from '../config/env.config';
import * as admin from 'firebase-admin';
import { verifyIdToken } from '../middleware/auth.middleware';
import { sectionCreateRateLimiter } from '../middleware/rateLimiter.middleware';
import { logger } from '../utils/logger';

const router = Router();

router.post('/create-section', sectionCreateRateLimiter, verifyIdToken, async (req: any, res: any) => {
  const { masterPassword, sectionId, sectionData, crPassword, srPassword } = req.body;

  if (masterPassword !== AppConfig.MASTER_SETUP_PASSWORD) {
    logger.warn('Failed section creation: Invalid master password', { uid: req.user?.uid, sectionId });
    return res.status(403).json({ error: 'Incorrect Master Password' });
  }

  if (!sectionId || !sectionData || !crPassword || !srPassword) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const db = admin.firestore();
    const sectionRef = db.collection('sections').doc(sectionId);
    
    // Check if it already exists
    const doc = await sectionRef.get();
    if (doc.exists) {
      logger.warn('Failed section creation: Section already exists', { uid: req.user?.uid, sectionId });
      return res.status(409).json({ error: 'Section already exists' });
    }

    // Create the section securely
    await sectionRef.set({
      ...sectionData,
      crPassword,
      srPassword,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timetablePublished: false,
    });
    
    logger.info('Section created successfully', { uid: req.user?.uid, sectionId });
    return res.status(201).json({ success: true, message: 'Section created' });
  } catch (error: any) {
    logger.error('Error creating section', { error: error.message });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/health', async (req, res) => {
  try {
    const stats = worker.getStats();
    let firebaseStatus = 'connected';
    try {
      await admin.auth().listUsers(1);
    } catch(e) {
      firebaseStatus = 'error';
    }
    
    res.status(200).json({
      status: 'healthy',
      version: AppConfig.VERSION,
      worker: stats.workerState,
      firebase: firebaseStatus,
      uptime: `${process.uptime()}s`,
      queueLength: stats.queueLength,
      processedToday: stats.processedToday,
      failedToday: stats.failedToday,
      deadLetters: stats.deadLetters,
      pollingInterval: stats.pollingInterval,
      averageProcessingTime: stats.averageProcessingTime
    });
  } catch(e) {
    res.status(500).json({ status: 'error', message: 'Failed to fetch health' });
  }
});

router.get('/stats', (req, res) => {
  res.status(501).json({ error: 'Not Implemented' });
});

router.get('/admin', (req, res) => {
  res.status(501).json({ error: 'Not Implemented' });
});

export default router;
