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
exports.removeFaculty = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const memberships_1 = require("./memberships");
exports.removeFaculty = functions.https.onCall({ secrets: [] }, async (request) => {
    const { auth, data } = request;
    if (!auth)
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    const { targetUid, sectionId, reason } = data;
    if (!targetUid || !sectionId)
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
    // 1. Validate CR owns the section
    const isCR = await (0, memberships_1.verifyCRForSection)(auth.uid, sectionId);
    if (!isCR)
        throw new functions.https.HttpsError('permission-denied', 'Only active CRs can remove faculty from this section.');
    const db = admin.firestore();
    // 2. Validate faculty exists
    const facultyRef = db.collection('faculty_profiles').doc(targetUid);
    const facultyDoc = await facultyRef.get();
    if (!facultyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Faculty profile not found.');
    }
    const facultyData = facultyDoc.data();
    // 3. Validate faculty belongs to the section
    const assignedDivisions = facultyData.assignedDivisions || [];
    if (!assignedDivisions.includes(sectionId)) {
        throw new functions.https.HttpsError('failed-precondition', 'Faculty is not assigned to this section.');
    }
    const subjectsMap = facultyData.subjects || {};
    const subjectIds = subjectsMap[sectionId] || [];
    const batch = db.batch();
    // 4. Update faculty profile
    batch.update(facultyRef, {
        assignedDivisions: admin.firestore.FieldValue.arrayRemove(sectionId),
        [`subjects.${sectionId}`]: admin.firestore.FieldValue.delete(),
    });
    // 5. Cleanup pending faculty requests for this section
    const requestsSnap = await db.collection('sections').doc(sectionId).collection('faculty_requests')
        .where('facultyId', '==', targetUid)
        .where('status', '==', 'pending')
        .get();
    requestsSnap.forEach((doc) => {
        batch.update(doc.ref, {
            status: 'denied',
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
            reason: 'Faculty removed from section'
        });
    });
    // 6. Cleanup reminder subscriptions
    const remindersSnap = await db.collection('faculty_reminders')
        .where('facultyId', '==', targetUid)
        .where('division', '==', sectionId)
        .get();
    remindersSnap.forEach((doc) => {
        batch.delete(doc.ref);
    });
    // 7. Save audit metadata
    const auditRef = db.collection('faculty_audit_logs').doc();
    batch.set(auditRef, {
        action: 'faculty_removed',
        facultyUid: targetUid,
        crUid: auth.uid,
        sectionId,
        subjectIds,
        removedAt: admin.firestore.FieldValue.serverTimestamp(),
        removedBy: auth.uid,
        reason: reason || 'Removed by CR',
    });
    // 8. Notifications
    const timestampStr = Date.now().toString();
    // To removed faculty
    const facultyOutboxRef = db.collection('notification_outbox').doc();
    batch.set(facultyOutboxRef, {
        notificationId: `fac_removed_${timestampStr}`,
        type: 'alert',
        title: 'Faculty Assignment Removed',
        body: `You have been removed from ${sectionId} by the Class Representative.`,
        division: targetUid,
        role: 'faculty',
        priority: 'high',
        deepLink: '/faculty_home',
        processed: false,
        attempts: 0,
        nextRetryAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        uid: auth.uid,
    });
    // To initiating CR
    const crOutboxRef = db.collection('notification_outbox').doc();
    batch.set(crOutboxRef, {
        notificationId: `cr_fac_removed_${timestampStr}`,
        type: 'alert',
        title: 'Faculty Removed',
        body: `You successfully removed ${facultyData.name || 'faculty'} from ${sectionId}.`,
        division: sectionId,
        role: 'student',
        priority: 'normal',
        deepLink: '/cr_panel',
        processed: false,
        attempts: 0,
        nextRetryAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        uid: auth.uid,
    });
    await batch.commit();
    return { success: true, message: 'Faculty removed successfully.' };
});
//# sourceMappingURL=faculty.js.map