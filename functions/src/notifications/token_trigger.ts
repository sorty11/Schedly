import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { getTargetTopic } from './topic_manager';

export const onTokenWritten = onDocumentWritten('users/{userId}/fcm_tokens/{tokenId}', async (event) => {
  const tokenId = event.params.tokenId;
  
  if (!event.data) return;

  const beforeData = event.data.before.exists ? event.data.before.data() : null;
  const afterData = event.data.after.exists ? event.data.after.data() : null;

  // Unsubscribe old topic if data changed or document deleted
  if (beforeData && beforeData.platform === 'web') {
    const oldTopic = getTargetTopic(beforeData.division, undefined, beforeData.role);
    const newTopic = afterData ? getTargetTopic(afterData.division, undefined, afterData.role) : null;
    
    if (oldTopic !== newTopic) {
      logger.info('Unsubscribing web token from old topic', { tokenId, topic: oldTopic });
      try {
        await admin.messaging().unsubscribeFromTopic([tokenId], oldTopic);
      } catch (e) {
        logger.error('Failed to unsubscribe', { error: e });
      }
    }
  }

  // Subscribe to new topic if created or updated
  if (afterData && afterData.platform === 'web') {
    const newTopic = getTargetTopic(afterData.division, undefined, afterData.role);
    const oldTopic = beforeData ? getTargetTopic(beforeData.division, undefined, beforeData.role) : null;

    if (oldTopic !== newTopic) {
      logger.info('Subscribing web token to topic', { tokenId, topic: newTopic });
      try {
        await admin.messaging().subscribeToTopic([tokenId], newTopic);
      } catch (e) {
        logger.error('Failed to subscribe', { error: e });
      }
    }
  }
});
