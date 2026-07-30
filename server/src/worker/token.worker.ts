import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import { getTargetTopic } from '../notifications/notification.service';

export class TokenWorker {
  private unsubscribe: (() => void) | null = null;
  private isInitialScan = true;

  // Keep a local map to track previous topics for "modified" events
  private tokenTopicMap: Map<string, string> = new Map();

  public async start() {
    logger.info(JSON.stringify({
      event: 'token_worker_started',
      status: 'SUCCESS',
      timestamp: new Date().toISOString()
    }));

    const db = admin.firestore();
    
    this.unsubscribe = db.collectionGroup('fcm_tokens')
      .where('platform', '==', 'web')
      .onSnapshot(async (snapshot) => {
        if (this.isInitialScan) {
          logger.info(`Starting initial reconciliation scan for ${snapshot.size} web tokens`);
          await this.processInitialScan(snapshot);
          this.isInitialScan = false;
        } else {
          await this.processIncrementalChanges(snapshot.docChanges());
        }
      }, (error) => {
        logger.error(JSON.stringify({
          event: 'token_worker_snapshot_error',
          error: error.message,
          timestamp: new Date().toISOString()
        }));
      });
  }

  public stop() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
    logger.info(JSON.stringify({
      event: 'token_worker_stopped',
      status: 'SUCCESS',
      timestamp: new Date().toISOString()
    }));
  }

  private async processInitialScan(snapshot: admin.firestore.QuerySnapshot) {
    const topicMap: Record<string, string[]> = {};

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const token = data.token;
      if (!token) return;

      const topic = getTargetTopic(data.division, data.batch, data.role);
      this.tokenTopicMap.set(token, topic);

      if (!topicMap[topic]) topicMap[topic] = [];
      topicMap[topic].push(token);
    });

    for (const [topic, tokens] of Object.entries(topicMap)) {
      for (let i = 0; i < tokens.length; i += 1000) {
        const chunk = tokens.slice(i, i + 1000);
        try {
          await admin.messaging().subscribeToTopic(chunk, topic);
          logger.info(`Reconciliation: Subscribed ${chunk.length} tokens to ${topic}`);
        } catch (error: any) {
          logger.error(`Reconciliation: Failed to subscribe chunk to ${topic}`, { error: error.message });
        }
      }
    }
    logger.info('Initial reconciliation scan complete.');
  }

  private async processIncrementalChanges(changes: admin.firestore.DocumentChange[]) {
    for (const change of changes) {
      const data = change.doc.data();
      const token = data.token;
      if (!token) continue;

      const newTopic = getTargetTopic(data.division, data.batch, data.role);

      if (change.type === 'added') {
        this.tokenTopicMap.set(token, newTopic);
        
        
        try {
          await admin.messaging().subscribeToTopic(token, newTopic);
          logger.info(JSON.stringify({
            event: 'token_subscribed',
            token: token.substring(0, 10) + '...',
            topic: newTopic,
            timestamp: new Date().toISOString()
          }));
        } catch (error: any) {
          logger.error(`Failed to subscribe token to ${newTopic}: ${error.message}`);
        }
      } 
      else if (change.type === 'modified') {
        const oldTopic = this.tokenTopicMap.get(token);
        if (oldTopic && oldTopic !== newTopic) {
          try {
            await admin.messaging().unsubscribeFromTopic(token, oldTopic);
            logger.info(JSON.stringify({
              event: 'token_unsubscribed',
              token: token.substring(0, 10) + '...',
              topic: oldTopic,
              reason: 'topic_changed',
              timestamp: new Date().toISOString()
            }));
          } catch (error: any) {
            logger.error(`Failed to unsubscribe token from old topic ${oldTopic}: ${error.message}`);
          }
          
          try {
            await admin.messaging().subscribeToTopic(token, newTopic);
            this.tokenTopicMap.set(token, newTopic);
            
            
            logger.info(JSON.stringify({
              event: 'token_subscribed',
              token: token.substring(0, 10) + '...',
              topic: newTopic,
              reason: 'topic_changed',
              timestamp: new Date().toISOString()
            }));
          } catch (error: any) {
            logger.error(`Failed to subscribe token to new topic ${newTopic}: ${error.message}`);
          }
        }
      }
      else if (change.type === 'removed') {
        this.tokenTopicMap.delete(token);
        try {
          await admin.messaging().unsubscribeFromTopic(token, newTopic);
          logger.info(JSON.stringify({
            event: 'token_unsubscribed',
            token: token.substring(0, 10) + '...',
            topic: newTopic,
            reason: 'document_deleted',
            timestamp: new Date().toISOString()
          }));
        } catch (error: any) {
          logger.error(`Failed to unsubscribe token from ${newTopic}: ${error.message}`);
        }
      }
    }
  }
}
