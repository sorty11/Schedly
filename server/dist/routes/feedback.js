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
const feedback_service_1 = require("../services/feedback.service");
const router = (0, express_1.Router)();
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
        if (!reportId) {
            res.status(400).json({ error: 'Bad Request: Missing reportId' });
            return;
        }
        // Dispatch email through FeedbackEmailService (atomic claim prevents duplicate emails)
        const result = await feedback_service_1.FeedbackEmailService.dispatchFeedbackEmail(reportId, {
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
        await admin.auth().verifyIdToken(idToken);
        const hasUser = Boolean(process.env.SMTP_USER);
        const hasPass = Boolean(process.env.SMTP_PASS);
        const host = process.env.SMTP_HOST || 'smtp.gmail.com';
        const port = parseInt(process.env.SMTP_PORT || '587', 10);
        let verifyStatus = 'untested';
        let verifyError = null;
        if (hasUser && hasPass) {
            try {
                const transporter = feedback_service_1.FeedbackEmailService.createTransporter();
                if (transporter) {
                    await transporter.verify();
                    verifyStatus = 'verified_success';
                }
            }
            catch (e) {
                verifyStatus = 'verify_failed';
                verifyError = e.message;
            }
        }
        else {
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
    }
    catch (error) {
        logger_1.logger.error('Error handling feedback diag request', { error: error.message });
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
exports.default = router;
