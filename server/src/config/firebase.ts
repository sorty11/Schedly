import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import dotenv from 'dotenv';

dotenv.config();

export function initFirebase() {
  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      logger.info('Firebase Admin initialized with provided service account.');
    } else {
      // Fallback for local development or default credentials
      admin.initializeApp();
      logger.info('Firebase Admin initialized with default credentials.');
    }
  } catch (error) {
    logger.error('Failed to initialize Firebase Admin', { error });
  }
}

// Call it to initialize when this file is imported
initFirebase();
