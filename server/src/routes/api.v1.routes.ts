import { Router } from 'express';
import { worker } from '../app';
import { AppConfig } from '../config/env.config';
import * as admin from 'firebase-admin';

const router = Router();

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
