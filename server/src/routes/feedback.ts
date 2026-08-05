import { Router, Request, Response } from 'express';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import { logger } from '../utils/logger';

const router = Router();

// Create reusable transporter object using the default SMTP transport
const createTransporter = () => {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_PORT === '465', // true for 465, false for other ports
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
};

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

    if (!type || !reportId || !data) {
      res.status(400).json({ error: 'Bad Request: Missing required fields' });
      return;
    }

    const transporter = createTransporter();
    
    let subject = '';
    let htmlContent = '';

    if (type === 'bug_report') {
      subject = `🐞 New Schedly Bug Report: ${data.title}`;
      htmlContent = `
        <h2>New Bug Report</h2>
        <p><strong>Title:</strong> ${data.title}</p>
        <p><strong>Category:</strong> ${data.category}</p>
        <p><strong>Description:</strong><br/>${data.description.replace(/\\n/g, '<br/>')}</p>
        <hr/>
        <h3>User Metadata</h3>
        <ul>
          <li><strong>Name:</strong> ${data.name}</li>
          <li><strong>Role:</strong> ${data.role}</li>
          <li><strong>Section:</strong> ${data.section}</li>
          <li><strong>UID:</strong> ${data.uid}</li>
        </ul>
        <h3>Device Info</h3>
        <ul>
          <li><strong>Platform:</strong> ${data.platform}</li>
          <li><strong>Device:</strong> ${data.device}</li>
          <li><strong>App Version:</strong> ${data.appVersion}</li>
        </ul>
        <p><small>Timestamp: ${data.timestamp}</small></p>
      `;
    } else if (type === 'feature_request') {
      subject = `💡 New Feature Suggestion: ${data.title}`;
      htmlContent = `
        <h2>New Feature Suggestion</h2>
        <p><strong>Title:</strong> ${data.title}</p>
        <p><strong>Category:</strong> ${data.category}</p>
        <p><strong>Description:</strong><br/>${data.description.replace(/\\n/g, '<br/>')}</p>
        <hr/>
        <h3>User Metadata</h3>
        <ul>
          <li><strong>Name:</strong> ${data.name}</li>
          <li><strong>Role:</strong> ${data.role}</li>
          <li><strong>Section:</strong> ${data.section}</li>
          <li><strong>UID:</strong> ${data.uid}</li>
        </ul>
        <p><small>Timestamp: ${data.timestamp}</small></p>
      `;
    } else {
      res.status(400).json({ error: 'Bad Request: Invalid type' });
      return;
    }

    const mailOptions = {
      from: `"Schedly App" <${process.env.SMTP_USER}>`,
      to: 'sorty797@gmail.com',
      subject: subject,
      html: htmlContent,
    };

    await transporter.sendMail(mailOptions);
    logger.info(`Feedback email sent successfully for report: ${reportId}`);
    
    res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (error) {
    logger.error(`Error sending feedback email: ${error}`);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

export default router;
