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
exports.TokenWorker = void 0;
const admin = __importStar(require("firebase-admin"));
const logger_1 = require("../utils/logger");
const notification_service_1 = require("../notifications/notification.service");
class TokenWorker {
    unsubscribe = null;
    isInitialScan = true;
    // Keep a local map to track previous topics for "modified" events
    tokenTopicMap = new Map();
    async start() {
        logger_1.logger.info(JSON.stringify({
            event: 'token_worker_started',
            status: 'SUCCESS',
            timestamp: new Date().toISOString()
        }));
        const db = admin.firestore();
        this.unsubscribe = db.collectionGroup('fcm_tokens')
            .where('platform', '==', 'web')
            .onSnapshot(async (snapshot) => {
            if (this.isInitialScan) {
                logger_1.logger.info(`Starting initial reconciliation scan for ${snapshot.size} web tokens`);
                await this.processInitialScan(snapshot);
                this.isInitialScan = false;
            }
            else {
                await this.processIncrementalChanges(snapshot.docChanges());
            }
        }, (error) => {
            logger_1.logger.error(JSON.stringify({
                event: 'token_worker_snapshot_error',
                error: error.message,
                timestamp: new Date().toISOString()
            }));
        });
    }
    stop() {
        if (this.unsubscribe) {
            this.unsubscribe();
            this.unsubscribe = null;
        }
        logger_1.logger.info(JSON.stringify({
            event: 'token_worker_stopped',
            status: 'SUCCESS',
            timestamp: new Date().toISOString()
        }));
    }
    async processInitialScan(snapshot) {
        const topicMap = {};
        snapshot.docs.forEach(doc => {
            const data = doc.data();
            const token = data.token;
            if (!token)
                return;
            const topics = (0, notification_service_1.getAllTargetTopics)(data.division, data.batch, data.role);
            this.tokenTopicMap.set(token, topics);
            for (const topic of topics) {
                if (!topicMap[topic])
                    topicMap[topic] = [];
                topicMap[topic].push(token);
            }
        });
        for (const [topic, tokens] of Object.entries(topicMap)) {
            for (let i = 0; i < tokens.length; i += 1000) {
                const chunk = tokens.slice(i, i + 1000);
                try {
                    await admin.messaging().subscribeToTopic(chunk, topic);
                    logger_1.logger.info(`Reconciliation: Subscribed ${chunk.length} tokens to ${topic}`);
                }
                catch (error) {
                    logger_1.logger.error(`Reconciliation: Failed to subscribe chunk to ${topic}`, { error: error.message });
                }
            }
        }
        logger_1.logger.info('Initial reconciliation scan complete.');
    }
    async processIncrementalChanges(changes) {
        for (const change of changes) {
            const data = change.doc.data();
            const token = data.token;
            if (!token)
                continue;
            const newTopics = (0, notification_service_1.getAllTargetTopics)(data.division, data.batch, data.role);
            if (change.type === 'added') {
                this.tokenTopicMap.set(token, newTopics);
                for (const topic of newTopics) {
                    try {
                        await admin.messaging().subscribeToTopic(token, topic);
                        logger_1.logger.info(JSON.stringify({
                            event: 'token_subscribed',
                            token: token.substring(0, 10) + '...',
                            topic: topic,
                            timestamp: new Date().toISOString()
                        }));
                    }
                    catch (error) {
                        logger_1.logger.error(`Failed to subscribe token to ${topic}: ${error.message}`);
                    }
                }
            }
            else if (change.type === 'modified') {
                const oldTopics = this.tokenTopicMap.get(token) || [];
                // Find topics to unsubscribe from (in old but not in new)
                const topicsToRemove = oldTopics.filter(t => !newTopics.includes(t));
                // Find topics to subscribe to (in new but not in old)
                const topicsToAdd = newTopics.filter(t => !oldTopics.includes(t));
                for (const topic of topicsToRemove) {
                    try {
                        await admin.messaging().unsubscribeFromTopic(token, topic);
                        logger_1.logger.info(JSON.stringify({
                            event: 'token_unsubscribed',
                            token: token.substring(0, 10) + '...',
                            topic: topic,
                            reason: 'topic_changed',
                            timestamp: new Date().toISOString()
                        }));
                    }
                    catch (error) {
                        logger_1.logger.error(`Failed to unsubscribe token from old topic ${topic}: ${error.message}`);
                    }
                }
                for (const topic of topicsToAdd) {
                    try {
                        await admin.messaging().subscribeToTopic(token, topic);
                        logger_1.logger.info(JSON.stringify({
                            event: 'token_subscribed',
                            token: token.substring(0, 10) + '...',
                            topic: topic,
                            reason: 'topic_changed',
                            timestamp: new Date().toISOString()
                        }));
                    }
                    catch (error) {
                        logger_1.logger.error(`Failed to subscribe token to new topic ${topic}: ${error.message}`);
                    }
                }
                this.tokenTopicMap.set(token, newTopics);
            }
            else if (change.type === 'removed') {
                const topics = this.tokenTopicMap.get(token) || newTopics;
                this.tokenTopicMap.delete(token);
                for (const topic of topics) {
                    try {
                        await admin.messaging().unsubscribeFromTopic(token, topic);
                        logger_1.logger.info(JSON.stringify({
                            event: 'token_unsubscribed',
                            token: token.substring(0, 10) + '...',
                            topic: topic,
                            reason: 'document_deleted',
                            timestamp: new Date().toISOString()
                        }));
                    }
                    catch (error) {
                        logger_1.logger.error(`Failed to unsubscribe token from ${topic}: ${error.message}`);
                    }
                }
            }
        }
    }
}
exports.TokenWorker = TokenWorker;
