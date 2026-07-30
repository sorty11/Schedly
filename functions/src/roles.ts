import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { logAudit } from './audit';
import { hashPassword, verifyPassword } from './utils';
import { FACULTY_MASTER_PASSWORD } from './config';


const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_PERIOD_MS = 15 * 60 * 1000;

async function checkRateLimitAndVerify(
  uid: string, 
  roleTarget: string,
  verifyFn: () => Promise<boolean> | boolean
): Promise<void> {
  const db = admin.firestore();
  const limitRef = db.collection('auth_rate_limits').doc(uid);

  const txResult = await db.runTransaction(async (t) => {
    const doc = await t.get(limitRef);
    let attempts = 0;
    let lockoutUntil: number | null = null;
    const now = Date.now();

    if (doc.exists) {
      const data = doc.data()!;
      attempts = data.attempts || 0;
      lockoutUntil = data.lockoutUntil || null;
    }

    if (lockoutUntil && lockoutUntil > now) {
      return { status: 'LOCKED_OUT', lockoutUntil };
    }

    let wasUnlocked = false;
    if (lockoutUntil && lockoutUntil <= now) {
      wasUnlocked = true;
      attempts = 0;
    }

    const isValid = await verifyFn();

    if (isValid) {
      t.set(limitRef, {
        attempts: 0,
        lockoutUntil: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return { status: 'SUCCESS', wasUnlocked };
    } else {
      attempts++;
      let newLockout: number | null = null;
      let status = 'FAILURE';
      
      if (attempts >= MAX_FAILED_ATTEMPTS) {
        newLockout = now + LOCKOUT_PERIOD_MS;
        status = 'NEW_LOCKOUT';
      }

      t.set(limitRef, {
        attempts,
        lockoutUntil: newLockout,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return { status, attempts, wasUnlocked };
    }
  });

  if (txResult.wasUnlocked) {
    await logAudit({
      action: `ELEVATE_TO_${roleTarget}_UNLOCK`,
      targetUser: uid,
      performedBy: uid,
      result: 'SUCCESS',
      failureReason: 'Lockout expired'
    });
  }

  if (txResult.status === 'LOCKED_OUT') {
    await logAudit({
      action: `ELEVATE_TO_${roleTarget}`,
      targetUser: uid,
      performedBy: uid,
      result: 'FAILURE',
      failureReason: 'Account temporarily locked due to too many failed attempts'
    });
    throw new functions.https.HttpsError('resource-exhausted', 'Too many failed attempts. Please try again later.');
  }

  if (txResult.status === 'NEW_LOCKOUT') {
    await logAudit({
      action: `ELEVATE_TO_${roleTarget}_LOCKOUT`,
      targetUser: uid,
      performedBy: uid,
      result: 'FAILURE',
      failureReason: `Exceeded ${MAX_FAILED_ATTEMPTS} failed attempts`
    });
    throw new functions.https.HttpsError('resource-exhausted', 'Too many failed attempts. Please try again later.');
  }

  if (txResult.status === 'FAILURE') {
    await logAudit({
      action: `ELEVATE_TO_${roleTarget}`,
      targetUser: uid,
      performedBy: uid,
      result: 'FAILURE',
      failureReason: 'Incorrect password'
    });
    throw new functions.https.HttpsError('permission-denied', 'Incorrect password.');
  }
}
export const verifyCRRole = functions.https.onCall({ secrets: [] }, async (request) => {
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

  const sectionData = sectionDoc.data()!;
  const storedPassword = sectionData.crPassword;
  
  if (!storedPassword) {
    throw new functions.https.HttpsError('failed-precondition', 'Section has no CR password configured.');
  }

  await checkRateLimitAndVerify(auth.uid, 'CR', async () => await verifyPassword(password, storedPassword));

  // Auto-migrate plaintext password to hash
  if (!storedPassword.startsWith('$2b$') && !storedPassword.startsWith('$2a$')) {
    const hashedPassword = await hashPassword(password);
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

  await logAudit({
    action: 'ELEVATE_TO_CR',
    targetUser: auth.uid,
    performedBy: auth.uid,
    section: sectionId,
    newRole: 'CR',
    result: 'SUCCESS'
  });

  return { success: true };
});

export const verifySRRole = functions.https.onCall({ secrets: [] }, async (request) => {
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

  const sectionData = sectionDoc.data()!;
  const storedPassword = sectionData.srPassword;
  
  if (!storedPassword) {
    throw new functions.https.HttpsError('failed-precondition', 'Section has no SR password configured.');
  }

  await checkRateLimitAndVerify(auth.uid, 'CR', async () => await verifyPassword(password, storedPassword));

  // Auto-migrate plaintext password to hash
  if (!storedPassword.startsWith('$2b$') && !storedPassword.startsWith('$2a$')) {
    const hashedPassword = await hashPassword(password);
    await sectionRef.update({ srPassword: hashedPassword });
  }

  const assignmentId = subject.toLowerCase().replace(/ /g, '_');
  const assignmentRef = sectionRef.collection('sr_assignments').doc(assignmentId);
  
  const batch = db.batch();

  // Read current assignment to update srs array safely
  const assignmentDoc = await assignmentRef.get();
  let srs: string[] = [];
  if (assignmentDoc.exists && Array.isArray(assignmentDoc.data()?.srs)) {
    srs = assignmentDoc.data()?.srs || [];
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

  await logAudit({
    action: 'ELEVATE_TO_SR',
    targetUser: auth.uid,
    performedBy: auth.uid,
    section: sectionId,
    newRole: 'SR',
    result: 'SUCCESS'
  });

  return { success: true };
});

export const verifyFacultyRole = functions.https.onCall({ secrets: [FACULTY_MASTER_PASSWORD] }, async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { name, masterPassword } = data;
  if (!name || !masterPassword) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing name or master password.');
  }

  await checkRateLimitAndVerify(auth.uid, 'FACULTY', () => masterPassword === FACULTY_MASTER_PASSWORD.value());

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

  await logAudit({
    action: 'ELEVATE_TO_FACULTY',
    targetUser: auth.uid,
    performedBy: auth.uid,
    newRole: 'faculty',
    result: 'SUCCESS'
  });

  return { success: true };
});
