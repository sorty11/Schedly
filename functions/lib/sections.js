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
exports.createSection = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const audit_1 = require("./audit");
const utils_1 = require("./utils");
const config_1 = require("./config");
exports.createSection = functions.https.onCall({ secrets: [config_1.MASTER_PASSWORD] }, async (request) => {
    const { auth, data } = request;
    if (!auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const { masterPassword, sectionId, config, crPassword, srPassword } = data;
    if (!masterPassword || !sectionId || !config || !crPassword || !srPassword) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
    }
    if (masterPassword !== config_1.MASTER_PASSWORD.value()) {
        await (0, audit_1.logAudit)({
            action: 'CREATE_SECTION',
            targetUser: auth.uid,
            performedBy: auth.uid,
            section: sectionId,
            result: 'FAILURE',
            failureReason: 'Incorrect master password'
        });
        throw new functions.https.HttpsError('permission-denied', 'Incorrect master password.');
    }
    const db = admin.firestore();
    const sectionRef = db.collection('sections').doc(sectionId);
    const doc = await sectionRef.get();
    if (doc.exists) {
        throw new functions.https.HttpsError('already-exists', 'Section already exists.');
    }
    const hashedCrPassword = await (0, utils_1.hashPassword)(crPassword);
    const hashedSrPassword = await (0, utils_1.hashPassword)(srPassword);
    const batch = db.batch();
    batch.set(sectionRef, Object.assign(Object.assign({}, config), { crPassword: hashedCrPassword, srPassword: hashedSrPassword, createdAt: admin.firestore.FieldValue.serverTimestamp(), timetablePublished: false }));
    const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${auth.uid}`);
    batch.set(membershipRef, {
        userId: auth.uid,
        sectionId: sectionId,
        role: 'CR',
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const userRef = db.collection('users').doc(auth.uid);
    batch.set(userRef, {
        role: 'CR',
        division: sectionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await (0, audit_1.logAudit)({
        action: 'CREATE_SECTION',
        targetUser: auth.uid,
        performedBy: auth.uid,
        section: sectionId,
        newRole: 'CR',
        result: 'SUCCESS'
    });
    return { success: true };
});
//# sourceMappingURL=sections.js.map