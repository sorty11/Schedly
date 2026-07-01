"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateNotificationPayload = void 0;
const validateNotificationPayload = (req, res, next) => {
    const { notificationId, type, title, body, division } = req.body;
    if (!notificationId || typeof notificationId !== 'string') {
        res.status(400).json({ error: 'Bad Request: Missing or invalid notificationId' });
        return;
    }
    if (!type || typeof type !== 'string') {
        res.status(400).json({ error: 'Bad Request: Missing or invalid type' });
        return;
    }
    if (!title || typeof title !== 'string') {
        res.status(400).json({ error: 'Bad Request: Missing or invalid title' });
        return;
    }
    if (!body || typeof body !== 'string') {
        res.status(400).json({ error: 'Bad Request: Missing or invalid body' });
        return;
    }
    if (!division || typeof division !== 'string') {
        res.status(400).json({ error: 'Bad Request: Missing or invalid division' });
        return;
    }
    next();
};
exports.validateNotificationPayload = validateNotificationPayload;
