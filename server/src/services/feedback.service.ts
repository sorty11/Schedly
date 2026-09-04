import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import { logger } from '../utils/logger';

export class FeedbackEmailService {
  public static isSmtpConfigured(): boolean {
    return Boolean(process.env.SMTP_USER && process.env.SMTP_PASS);
  }

  public static createTransporter(): nodemailer.Transporter | null {
    const user = process.env.SMTP_USER ? process.env.SMTP_USER.trim() : '';
    const pass = process.env.SMTP_PASS ? process.env.SMTP_PASS.replace(/\s+/g, '') : '';

    if (!user || !pass) {
      return null;
    }

    const host = process.env.SMTP_HOST || 'smtp.gmail.com';
    const port = parseInt(process.env.SMTP_PORT || '587', 10);
    const isGmail = !process.env.SMTP_HOST || process.env.SMTP_HOST === 'smtp.gmail.com';

    // If using Gmail on standard ports, service: 'gmail' with family: 4
    // completely avoids ENETUNREACH IPv6 routing errors on cloud environments (like Render).
    if (isGmail && (!process.env.SMTP_PORT || process.env.SMTP_PORT === '465' || process.env.SMTP_PORT === '587')) {
      return nodemailer.createTransport({
        service: 'gmail',
        auth: { user, pass },
        family: 4,
      } as any);
    }

    return nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      family: 4,
    } as any);
  }

  public static formatSubject(type: string, title: string): string {
    const cleanTitle = (title || 'No Title').trim();
    const lower = (type || '').toLowerCase();
    if (lower.includes('bug')) {
      return `[Schedly Bug] ${cleanTitle}`;
    } else if (lower.includes('feature')) {
      return `[Schedly Feature] ${cleanTitle}`;
    } else {
      return `[Schedly Feedback] ${cleanTitle}`;
    }
  }

  public static formatHtmlBody(data: any): string {
    const typeLabel = data.type === 'bug' || data.type === 'bug_report'
      ? 'Bug Report 🐞'
      : data.type === 'feature' || data.type === 'feature_request'
      ? 'Feature Suggestion 💡'
      : 'General Feedback 💬';

    const safeDescription = (data.description || 'No description provided')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br/>');

    return `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1e293b;">
        <div style="background: linear-gradient(135deg, #4f46e5, #6366f1); padding: 24px; border-radius: 12px 12px 0 0; color: #ffffff;">
          <h1 style="margin: 0; font-size: 20px; font-weight: 700;">${typeLabel}</h1>
          <p style="margin: 6px 0 0 0; font-size: 16px; opacity: 0.95;">${data.title || 'Untitled'}</p>
        </div>

        <div style="padding: 24px; background: #ffffff; border: 1px solid #e2e8f0; border-top: none; border-radius: 0 0 12px 12px;">
          <h2 style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; color: #64748b; margin-top: 0;">Description</h2>
          <div style="background: #f8fafc; border-left: 4px solid #4f46e5; padding: 14px 16px; border-radius: 4px; font-size: 14px; line-height: 1.6; margin-bottom: 24px; white-space: pre-wrap;">
            ${safeDescription}
          </div>

          <h2 style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; color: #64748b; margin-top: 0;">Reporter Details</h2>
          <table style="width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 20px;">
            <tr>
              <td style="padding: 6px 0; color: #64748b; width: 120px;"><strong>Name:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.name || 'Anonymous'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>Email:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;"><strong>${data.email || 'No email provided'}</strong></td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>Role:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.role || 'Student'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>Section:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.section || data.division || 'N/A'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>Category:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.category || 'General'}</td>
            </tr>
          </table>

          <h2 style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; color: #64748b; margin-top: 0;">Environment & Device</h2>
          <table style="width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 20px;">
            <tr>
              <td style="padding: 6px 0; color: #64748b; width: 120px;"><strong>Platform:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.platform || 'Unknown'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>Device:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.device || 'Unknown'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>App Version:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.appVersion || 'Unknown'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>UID:</strong></td>
              <td style="padding: 6px 0; color: #64748b; font-family: monospace;">${data.uid || 'N/A'}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #64748b;"><strong>Timestamp:</strong></td>
              <td style="padding: 6px 0; color: #0f172a;">${data.timestamp || new Date().toISOString()}</td>
            </tr>
          </table>

          <div style="font-size: 11px; color: #94a3b8; border-top: 1px solid #f1f5f9; padding-top: 12px;">
            Sent automatically by Schedly Backend Service • Report ID: <code>${data.id || 'N/A'}</code>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Dispatches the feedback email with atomic concurrency lock to prevent duplicate emails.
   */
  public static async dispatchFeedbackEmail(
    reportId: string,
    providedData?: any
  ): Promise<{ success: boolean; skipped?: boolean; error?: string }> {
    const db = admin.firestore();
    const docRef = db.collection('feedback').doc(reportId);

    // 1. Concurrency Lock / Claim via Transaction
    let docData: any = providedData;
    let claimed = false;

    try {
      claimed = await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(docRef);
        if (!snap.exists) {
          if (!providedData) return false;
          // Document might not have synced yet, create or set it
          transaction.set(docRef, {
            ...providedData,
            emailStatus: 'processing',
            emailProcessingAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          return true;
        }

        const current = snap.data() || {};
        docData = { ...current, ...(providedData || {}) };

        // Duplicate guard: already sent
        if (current.emailStatus === 'sent') {
          return false;
        }

        // Concurrency guard: currently being processed by worker/route (lock TTL: 2 mins)
        if (current.emailStatus === 'processing') {
          const procTime = current.emailProcessingAt?.toMillis?.() || 0;
          if (Date.now() - procTime < 120000) {
            return false;
          }
        }

        transaction.update(docRef, {
          emailStatus: 'processing',
          emailProcessingAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (lockErr: any) {
      logger.error('Error claiming feedback document for email dispatch', { reportId, error: lockErr.message });
      return { success: false, error: lockErr.message };
    }

    if (!claimed) {
      logger.info('Skipping feedback email dispatch: already sent or currently being processed', { reportId });
      return { success: true, skipped: true };
    }

    // 2. Check SMTP Transporter
    const transporter = FeedbackEmailService.createTransporter();
    if (!transporter) {
      const errorMsg = 'SMTP credentials not configured on server (SMTP_USER or SMTP_PASS missing)';
      logger.warn(errorMsg, { reportId });
      await docRef.update({
        emailStatus: 'pending',
        lastEmailError: errorMsg,
      });
      return { success: false, error: errorMsg };
    }

    // 3. Send Email
    try {
      const subject = FeedbackEmailService.formatSubject(docData.type, docData.title);
      const html = FeedbackEmailService.formatHtmlBody({ ...docData, id: reportId });

      const sendResult = await transporter.sendMail({
        from: `"Schedly App" <${process.env.SMTP_USER}>`,
        to: 'sorty797@gmail.com',
        subject,
        html,
      });

      logger.info('Feedback email delivered successfully', {
        reportId,
        subject,
        messageId: sendResult.messageId,
        accepted: sendResult.accepted,
        rejected: sendResult.rejected,
        response: sendResult.response,
      });

      // 4. Mark Sent
      await docRef.update({
        emailStatus: 'sent',
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: sendResult.messageId || null,
        smtpResponse: sendResult.response || null,
        lastEmailError: admin.firestore.FieldValue.delete(),
      });

      return { success: true };
    } catch (sendErr: any) {
      logger.error('Failed to send feedback email via SMTP', { reportId, error: sendErr.message });

      await docRef.update({
        emailStatus: 'failed',
        lastEmailError: sendErr.message,
        emailAttempts: admin.firestore.FieldValue.increment(1),
        nextRetryAt: admin.firestore.Timestamp.fromMillis(Date.now() + 60000), // retry after 1 min
      });

      return { success: false, error: sendErr.message };
    }
  }
}
