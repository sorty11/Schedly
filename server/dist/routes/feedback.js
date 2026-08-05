"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const admin = __importStar(require("firebase-admin"));
const nodemailer = __importStar(require("nodemailer"));
const logger_1 = require("../utils/logger");
const router = (0, express_1.Router)();
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
router.post('/email', async (req, res) => {
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
        }
        catch (e) {
            logger_1.logger.error(`Invalid Firebase token: ${e}`);
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
        }
        else if (type === 'feature_request') {
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
        }
        else {
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
        logger_1.logger.info(`Feedback email sent successfully for report: ${reportId}`);
        res.status(200).json({ success: true, message: 'Email sent successfully' });
    }
    catch (error) {
        logger_1.logger.error(`Error sending feedback email: ${error}`);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
exports.default = router;
