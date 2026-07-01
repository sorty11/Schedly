"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkIdempotency = checkIdempotency;
const admin = require("firebase-admin");
async function checkIdempotency(eventId) {
    const db = admin.firestore();
    const ref = db.collection('_event_tracker').doc(eventId);
    try {
        return await db.runTransaction(async (t) => {
            const doc = await t.get(ref);
            if (doc.exists) {
                return false; // Already processed
            }
            t.set(ref, { processedAt: admin.firestore.FieldValue.serverTimestamp() });
            return true;
        });
    }
    catch (e) {
        return false; // Fail safe
    }
}
//# sourceMappingURL=idempotency.js.map