import { Router, Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { feedbackRateLimiter } from '../middleware/rateLimiter.middleware';
import { FeedbackEmailService } from '../services/feedback.service';

const router = Router();

router.post('/email', feedbackRateLimiter, async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    
    // Verify token
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      if (decoded.firebase?.sign_in_provider === 'anonymous') {
        res.status(403).json({ error: 'Forbidden: Anonymous users cannot send feedback emails' });
        return;
      }
    } catch (e) {
      logger.error(`Invalid Firebase token: ${e}`);
      res.status(401).json({ error: 'Unauthorized: Invalid token' });
      return;
    }

    const { type, reportId, data } = req.body;

    if (!reportId || typeof reportId !== 'string' || reportId.length > 128) {
      res.status(400).json({ error: 'Bad Request: Missing or invalid reportId' });
      return;
    }

    // Input sanitization and bounds
    const sanitizedData = { ...(data || {}) };
    if (typeof sanitizedData.title === 'string' && sanitizedData.title.length > 200) {
      sanitizedData.title = sanitizedData.title.substring(0, 200);
    }
    if (typeof sanitizedData.description === 'string' && sanitizedData.description.length > 5000) {
      sanitizedData.description = sanitizedData.description.substring(0, 5000);
    }

    // Dispatch email through FeedbackEmailService (atomic claim prevents duplicate emails)
    const result = await FeedbackEmailService.dispatchFeedbackEmail(reportId, {
      ...sanitizedData,
      type: type || sanitizedData.type || 'other',
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
    const decoded = await admin.auth().verifyIdToken(idToken);
    if (decoded.firebase?.sign_in_provider === 'anonymous') {
      res.status(403).json({ error: 'Forbidden: Anonymous accounts cannot access diagnostics' });
      return;
    }

    const hasResend = Boolean(process.env.RESEND_API_KEY);
    const hasUser = Boolean(process.env.SMTP_USER);
    const hasPass = Boolean(process.env.SMTP_PASS);

    // In production, return minimal non-sensitive configuration status
    if (process.env.NODE_ENV === 'production') {
      res.status(200).json({
        configured: hasResend || (hasUser && hasPass),
        provider: hasResend ? 'resend_https' : (hasUser && hasPass ? 'smtp' : 'none'),
        status: (hasResend || (hasUser && hasPass)) ? 'ready' : 'unconfigured',
      });
      return;
    }

    const host = process.env.SMTP_HOST || 'smtp.gmail.com';
    const port = parseInt(process.env.SMTP_PORT || '587', 10);

    let verifyStatus = 'untested';
    let verifyError: string | null = null;

    if (hasResend) {
      try {
        const testRes = await fetch('https://api.resend.com/api-keys', {
          headers: { 'Authorization': `Bearer ${process.env.RESEND_API_KEY?.trim()}` }
        });
        if (testRes.ok) {
          verifyStatus = 'resend_verified_success';
        } else {
          verifyStatus = 'resend_verify_failed';
          const errData: any = await testRes.json().catch(() => ({}));
          verifyError = errData.message || `Resend HTTP ${testRes.status}`;
        }
      } catch (e: any) {
        verifyStatus = 'resend_verify_failed';
        verifyError = e.message;
      }
    } else if (hasUser && hasPass) {
      try {
        const transporter = FeedbackEmailService.createTransporter();
        if (transporter) {
          await transporter.verify();
          verifyStatus = 'smtp_verified_success';
        }
      } catch (e: any) {
        verifyStatus = 'smtp_verify_failed';
        verifyError = e.message;
      }
    } else {
      verifyStatus = 'missing_credentials';
    }

    res.status(200).json({
      configured: hasResend || (hasUser && hasPass),
      provider: hasResend ? 'resend_https' : 'smtp',
      hasResend,
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
