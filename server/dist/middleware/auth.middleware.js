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
exports.verifyIdToken = exports.requireCRorSR = void 0;
const admin = __importStar(require("firebase-admin"));
const logger_1 = require("../utils/logger");
const requireCRorSR = async (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        logger_1.logger.warn('Unauthorized: Missing or invalid Bearer token');
        res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
        return;
    }
    const token = authHeader.split('Bearer ')[1];
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.user = decodedToken;
        // Fetch user doc to check role
        const userDoc = await admin.firestore().collection('users').doc(decodedToken.uid).get();
        if (!userDoc.exists) {
            logger_1.logger.warn('Forbidden: User document not found', { uid: decodedToken.uid });
            res.status(403).json({ error: 'Forbidden: User not found' });
            return;
        }
        const userData = userDoc.data();
        const role = userData?.role;
        if (role !== 'CR' && role !== 'SR') {
            logger_1.logger.warn('Forbidden: Insufficient permissions', { uid: decodedToken.uid, role });
            res.status(403).json({ error: 'Forbidden: Insufficient privileges' });
            return;
        }
        req.userRole = role;
        next();
    }
    catch (error) {
        logger_1.logger.error('Token verification failed', { error });
        res.status(401).json({ error: 'Unauthorized: Invalid token' });
        return;
    }
};
exports.requireCRorSR = requireCRorSR;
const verifyIdToken = async (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        logger_1.logger.warn('Unauthorized: Missing or invalid Bearer token');
        res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
        return;
    }
    const token = authHeader.split('Bearer ')[1];
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.user = decodedToken;
        next();
    }
    catch (error) {
        logger_1.logger.error('Token verification failed', { error });
        res.status(401).json({ error: 'Unauthorized: Invalid token' });
        return;
    }
};
exports.verifyIdToken = verifyIdToken;
