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
const logger_1 = require("../utils/logger");
const rateLimiter_middleware_1 = require("../middleware/rateLimiter.middleware");
const feedback_service_1 = require("../services/feedback.service");
const router = (0, express_1.Router)();
router.post('/email', rateLimiter_middleware_1.feedbackRateLimiter, async (req, res) => {
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
        }
        catch (e) {
            logger_1.logger.error(`Invalid Firebase token: ${e}`);
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
        const result = await feedback_service_1.FeedbackEmailService.dispatchFeedbackEmail(reportId, {
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
    }
    catch (error) {
        logger_1.logger.error('Error handling feedback email request', { error: error.message });
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
router.get('/diag', async (req, res) => {
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
        let verifyError = null;
        if (hasResend) {
            try {
                const testRes = await fetch('https://api.resend.com/api-keys', {
                    headers: { 'Authorization': `Bearer ${process.env.RESEND_API_KEY?.trim()}` }
                });
                if (testRes.ok) {
                    verifyStatus = 'resend_verified_success';
                }
                else {
                    verifyStatus = 'resend_verify_failed';
                    const errData = await testRes.json().catch(() => ({}));
                    verifyError = errData.message || `Resend HTTP ${testRes.status}`;
                }
            }
            catch (e) {
                verifyStatus = 'resend_verify_failed';
                verifyError = e.message;
            }
        }
        else if (hasUser && hasPass) {
            try {
                const transporter = feedback_service_1.FeedbackEmailService.createTransporter();
                if (transporter) {
                    await transporter.verify();
                    verifyStatus = 'smtp_verified_success';
                }
            }
            catch (e) {
                verifyStatus = 'smtp_verify_failed';
                verifyError = e.message;
            }
        }
        else {
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
    }
    catch (error) {
        logger_1.logger.error('Error handling feedback diag request', { error: error.message });
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
exports.default = router;
