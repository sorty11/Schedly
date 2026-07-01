"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleSendNotification = void 0;
const notification_service_1 = require("./notification.service");
const logger_1 = require("../utils/logger");
const handleSendNotification = (req, res) => {
    const payload = req.body;
    // Return 202 Accepted immediately (Fire-and-forget)
    res.status(202).json({ message: 'Notification accepted for delivery' });
    // Process asynchronously
    const uid = req.user?.uid || 'unknown';
    const role = req.userRole || 'unknown';
    logger_1.logger.info('Notification accepted, processing async', { notificationId: payload.notificationId, uid });
    (0, notification_service_1.dispatchNotification)(payload, uid, role)
        .catch(err => {
        logger_1.logger.error('Unhandled error in async notification dispatch', { error: err.message });
    });
};
exports.handleSendNotification = handleSendNotification;
