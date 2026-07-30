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
exports.verifyFacultyRole = exports.verifySRRole = exports.verifyCRRole = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const audit_1 = require("./audit");
const utils_1 = require("./utils");
const config_1 = require("./config");
exports.verifyCRRole = functions.https.onCall({ secrets: [] }, async (request) => {
    const { auth, data } = request;
    if (!auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const { sectionId, password } = data;
    if (!sectionId || !password) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing sectionId or password.');
    }
    const db = admin.firestore();
    const sectionRef = db.collection('sections').doc(sectionId);
    const sectionDoc = await sectionRef.get();
    if (!sectionDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Section not found.');
    }
    const sectionData = sectionDoc.data();
    const storedPassword = sectionData.crPassword;
    if (!storedPassword) {
        throw new functions.https.HttpsError('failed-precondition', 'Section has no CR password configured.');
    }
    const isValid = await (0, utils_1.verifyPassword)(password, storedPassword);
    if (!isValid) {
        await (0, audit_1.logAudit)({
            action: 'ELEVATE_TO_CR',
            targetUser: auth.uid,
            performedBy: auth.uid,
            section: sectionId,
            result: 'FAILURE',
            failureReason: 'Incorrect password'
        });
        throw new functions.https.HttpsError('permission-denied', 'Incorrect password.');
    }
    // Auto-migrate plaintext password to hash
    if (!storedPassword.startsWith('$2b$') && !storedPassword.startsWith('$2a$')) {
        const hashedPassword = await (0, utils_1.hashPassword)(password);
        await sectionRef.update({ crPassword: hashedPassword });
    }
    const batch = db.batch();
    // Update membership
    const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${auth.uid}`);
    batch.set(membershipRef, {
        userId: auth.uid,
        sectionId: sectionId,
        role: 'CR',
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // Update user role
    const userRef = db.collection('users').doc(auth.uid);
    batch.set(userRef, {
        role: 'CR',
        division: sectionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await (0, audit_1.logAudit)({
        action: 'ELEVATE_TO_CR',
        targetUser: auth.uid,
        performedBy: auth.uid,
        section: sectionId,
        newRole: 'CR',
        result: 'SUCCESS'
    });
    return { success: true };
});
exports.verifySRRole = functions.https.onCall({ secrets: [] }, async (request) => {
    var _a, _b;
    const { auth, data } = request;
    if (!auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const { sectionId, subject, password, userToReplace, identity } = data;
    if (!sectionId || !subject || !password || !identity) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required arguments.');
    }
    const db = admin.firestore();
    const sectionRef = db.collection('sections').doc(sectionId);
    const sectionDoc = await sectionRef.get();
    if (!sectionDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Section not found.');
    }
    const sectionData = sectionDoc.data();
    const storedPassword = sectionData.srPassword;
    if (!storedPassword) {
        throw new functions.https.HttpsError('failed-precondition', 'Section has no SR password configured.');
    }
    const isValid = await (0, utils_1.verifyPassword)(password, storedPassword);
    if (!isValid) {
        await (0, audit_1.logAudit)({
            action: 'ELEVATE_TO_SR',
            targetUser: auth.uid,
            performedBy: auth.uid,
            section: sectionId,
            result: 'FAILURE',
            failureReason: 'Incorrect password'
        });
        throw new functions.https.HttpsError('permission-denied', 'Incorrect password.');
    }
    // Auto-migrate plaintext password to hash
    if (!storedPassword.startsWith('$2b$') && !storedPassword.startsWith('$2a$')) {
        const hashedPassword = await (0, utils_1.hashPassword)(password);
        await sectionRef.update({ srPassword: hashedPassword });
    }
    const assignmentId = subject.toLowerCase().replace(/ /g, '_');
    const assignmentRef = sectionRef.collection('sr_assignments').doc(assignmentId);
    const batch = db.batch();
    // Read current assignment to update srs array safely
    const assignmentDoc = await assignmentRef.get();
    let srs = [];
    if (assignmentDoc.exists && Array.isArray((_a = assignmentDoc.data()) === null || _a === void 0 ? void 0 : _a.srs)) {
        srs = ((_b = assignmentDoc.data()) === null || _b === void 0 ? void 0 : _b.srs) || [];
    }
    if (srs.length >= 2 && !userToReplace) {
        throw new functions.https.HttpsError('failed-precondition', 'Role fully claimed. Please specify a user to replace.');
    }
    if (userToReplace) {
        srs = srs.filter(sr => sr !== userToReplace);
    }
    if (!srs.includes(identity)) {
        srs.push(identity);
    }
    batch.set(assignmentRef, {
        srs,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // Update membership
    const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${auth.uid}`);
    batch.set(membershipRef, {
        userId: auth.uid,
        sectionId: sectionId,
        role: 'SR',
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // Update user role
    const userRef = db.collection('users').doc(auth.uid);
    batch.set(userRef, {
        role: 'SR',
        division: sectionId,
        subject: subject,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await (0, audit_1.logAudit)({
        action: 'ELEVATE_TO_SR',
        targetUser: auth.uid,
        performedBy: auth.uid,
        section: sectionId,
        newRole: 'SR',
        result: 'SUCCESS'
    });
    return { success: true };
});
exports.verifyFacultyRole = functions.https.onCall({ secrets: [config_1.FACULTY_MASTER_PASSWORD] }, async (request) => {
    const { auth, data } = request;
    if (!auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const { name, masterPassword } = data;
    if (!name || !masterPassword) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing name or master password.');
    }
    if (masterPassword !== config_1.FACULTY_MASTER_PASSWORD.value()) {
        await (0, audit_1.logAudit)({
            action: 'ELEVATE_TO_FACULTY',
            targetUser: auth.uid,
            performedBy: auth.uid,
            result: 'FAILURE',
            failureReason: 'Incorrect master password'
        });
        throw new functions.https.HttpsError('permission-denied', 'Incorrect master password.');
    }
    const db = admin.firestore();
    const batch = db.batch();
    const facultyRef = db.collection('faculty_profiles').doc(auth.uid);
    batch.set(facultyRef, {
        facultyId: auth.uid,
        name: name,
        email: auth.token.email || '',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const userRef = db.collection('users').doc(auth.uid);
    batch.set(userRef, {
        role: 'faculty',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await (0, audit_1.logAudit)({
        action: 'ELEVATE_TO_FACULTY',
        targetUser: auth.uid,
        performedBy: auth.uid,
        newRole: 'faculty',
        result: 'SUCCESS'
    });
    return { success: true };
});
//# sourceMappingURL=roles.js.map