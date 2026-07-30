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
const app_1 = require("../app");
const env_config_1 = require("../config/env.config");
const admin = __importStar(require("firebase-admin"));
const auth_middleware_1 = require("../middleware/auth.middleware");
const rateLimiter_middleware_1 = require("../middleware/rateLimiter.middleware");
const logger_1 = require("../utils/logger");
const router = (0, express_1.Router)();
router.post('/create-section', rateLimiter_middleware_1.sectionCreateRateLimiter, auth_middleware_1.verifyIdToken, async (req, res) => {
    const { masterPassword, sectionId, sectionData, crPassword, srPassword } = req.body;
    if (masterPassword !== env_config_1.AppConfig.MASTER_SETUP_PASSWORD) {
        logger_1.logger.warn('Failed section creation: Invalid master password', { uid: req.user?.uid, sectionId });
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
            logger_1.logger.warn('Failed section creation: Section already exists', { uid: req.user?.uid, sectionId });
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
        logger_1.logger.info('Section created successfully', { uid: req.user?.uid, sectionId });
        return res.status(201).json({ success: true, message: 'Section created' });
    }
    catch (error) {
        logger_1.logger.error('Error creating section', { error: error.message });
        return res.status(500).json({ error: 'Internal server error' });
    }
});
router.get('/health', async (req, res) => {
    try {
        const stats = app_1.worker.getStats();
        let firebaseStatus = 'connected';
        try {
            await admin.auth().listUsers(1);
        }
        catch (e) {
            firebaseStatus = 'error';
        }
        res.status(200).json({
            status: 'healthy',
            version: env_config_1.AppConfig.VERSION,
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
    }
    catch (e) {
        res.status(500).json({ status: 'error', message: 'Failed to fetch health' });
    }
});
router.get('/stats', (req, res) => {
    res.status(501).json({ error: 'Not Implemented' });
});
router.get('/admin', (req, res) => {
    res.status(501).json({ error: 'Not Implemented' });
});
exports.default = router;
