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
exports.restoreStudent = exports.removeStudent = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const audit_1 = require("./audit");
async function verifyCRForSection(uid, sectionId) {
    var _a, _b;
    const db = admin.firestore();
    const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${uid}`);
    const doc = await membershipRef.get();
    return doc.exists && ((_a = doc.data()) === null || _a === void 0 ? void 0 : _a.role) === 'CR' && ((_b = doc.data()) === null || _b === void 0 ? void 0 : _b.status) === 'active';
}
exports.removeStudent = functions.https.onCall({ secrets: [] }, async (request) => {
    const { auth, data } = request;
    if (!auth)
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    const { targetUserId, sectionId } = data;
    if (!targetUserId || !sectionId)
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
    const isCR = await verifyCRForSection(auth.uid, sectionId);
    if (!isCR)
        throw new functions.https.HttpsError('permission-denied', 'Only active CRs can remove students.');
    const db = admin.firestore();
    const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${targetUserId}`);
    await membershipRef.update({
        status: 'removed',
        removedAt: admin.firestore.FieldValue.serverTimestamp(),
        removedBy: auth.uid,
    });
    await (0, audit_1.logAudit)({
        action: 'REMOVE_STUDENT',
        targetUser: targetUserId,
        performedBy: auth.uid,
        section: sectionId,
        newRole: 'removed',
        result: 'SUCCESS'
    });
    return { success: true };
});
exports.restoreStudent = functions.https.onCall({ secrets: [] }, async (request) => {
    const { auth, data } = request;
    if (!auth)
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    const { targetUserId, sectionId } = data;
    if (!targetUserId || !sectionId)
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
    const isCR = await verifyCRForSection(auth.uid, sectionId);
    if (!isCR)
        throw new functions.https.HttpsError('permission-denied', 'Only active CRs can restore students.');
    const db = admin.firestore();
    const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${targetUserId}`);
    await membershipRef.update({
        status: 'active',
        restoredAt: admin.firestore.FieldValue.serverTimestamp(),
        restoredBy: auth.uid,
    });
    await (0, audit_1.logAudit)({
        action: 'RESTORE_STUDENT',
        targetUser: targetUserId,
        performedBy: auth.uid,
        section: sectionId,
        newRole: 'active',
        result: 'SUCCESS'
    });
    return { success: true };
});
//# sourceMappingURL=memberships.js.map