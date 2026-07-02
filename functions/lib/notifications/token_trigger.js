"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onTokenWritten = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const topic_manager_1 = require("./topic_manager");
exports.onTokenWritten = (0, firestore_1.onDocumentWritten)('users/{userId}/fcm_tokens/{tokenId}', async (event) => {
    const tokenId = event.params.tokenId;
    if (!event.data)
        return;
    const beforeData = event.data.before.exists ? event.data.before.data() : null;
    const afterData = event.data.after.exists ? event.data.after.data() : null;
    // Unsubscribe old topic if data changed or document deleted
    if (beforeData && beforeData.platform === 'web') {
        const oldTopic = (0, topic_manager_1.getTargetTopic)(beforeData.division, undefined, beforeData.role);
        const newTopic = afterData ? (0, topic_manager_1.getTargetTopic)(afterData.division, undefined, afterData.role) : null;
        if (oldTopic !== newTopic) {
            logger.info('Unsubscribing web token from old topic', { tokenId, topic: oldTopic });
            try {
                await admin.messaging().unsubscribeFromTopic([tokenId], oldTopic);
            }
            catch (e) {
                logger.error('Failed to unsubscribe', { error: e });
            }
        }
    }
    // Subscribe to new topic if created or updated
    if (afterData && afterData.platform === 'web') {
        const newTopic = (0, topic_manager_1.getTargetTopic)(afterData.division, undefined, afterData.role);
        const oldTopic = beforeData ? (0, topic_manager_1.getTargetTopic)(beforeData.division, undefined, beforeData.role) : null;
        if (oldTopic !== newTopic) {
            logger.info('Subscribing web token to topic', { tokenId, topic: newTopic });
            try {
                await admin.messaging().subscribeToTopic([tokenId], newTopic);
            }
            catch (e) {
                logger.error('Failed to subscribe', { error: e });
            }
        }
    }
});
//# sourceMappingURL=token_trigger.js.map