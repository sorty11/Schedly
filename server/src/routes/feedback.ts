import { Router, Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { FeedbackEmailService } from '../services/feedback.service';

const router = Router();

router.post('/email', async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    
    // Verify token
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      logger.error(`Invalid Firebase token: ${e}`);
      res.status(401).json({ error: 'Unauthorized: Invalid token' });
      return;
    }

    const { type, reportId, data } = req.body;

    if (!reportId) {
      res.status(400).json({ error: 'Bad Request: Missing reportId' });
      return;
    }

    // Dispatch email through FeedbackEmailService (atomic claim prevents duplicate emails)
    const result = await FeedbackEmailService.dispatchFeedbackEmail(reportId, {
      ...(data || {}),
      type: type || data?.type || 'other',
    });

    if (result.skipped) {
      res.status(200).json({ success: true, message: 'Email already sent or currently processing' });
      return;
    }

    if (!result.success) {
      res.status(202).json({
        success: false,
        message: 'Feedback saved in Firestore; email delivery queued for retry',
        error: result.error,
      });
      return;
    }

    res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (error: any) {
    logger.error('Error handling feedback email request', { error: error.message });
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.get('/diag', async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    await admin.auth().verifyIdToken(idToken);

    const hasUser = Boolean(process.env.SMTP_USER);
    const hasPass = Boolean(process.env.SMTP_PASS);
    const host = process.env.SMTP_HOST || 'smtp.gmail.com';
    const port = parseInt(process.env.SMTP_PORT || '587', 10);

    let verifyStatus = 'untested';
    let verifyError: string | null = null;

    if (hasUser && hasPass) {
      try {
        const transporter = FeedbackEmailService.createTransporter();
        if (transporter) {
          await transporter.verify();
          verifyStatus = 'verified_success';
        }
      } catch (e: any) {
        verifyStatus = 'verify_failed';
        verifyError = e.message;
      }
    } else {
      verifyStatus = 'missing_credentials';
    }

    res.status(200).json({
      smtpConfigured: hasUser && hasPass,
      hasUser,
      hasPass,
      host,
      port,
      userDomain: process.env.SMTP_USER ? process.env.SMTP_USER.split('@')[1] : null,
      verifyStatus,
      verifyError,
    });
  } catch (error: any) {
    logger.error('Error handling feedback diag request', { error: error.message });
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

export default router;
