import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { logAudit } from './audit';
import { hashPassword } from './utils';
import { MASTER_PASSWORD } from './config';

export const createSection = functions.https.onCall({ secrets: [MASTER_PASSWORD] }, async (request) => {
  const { auth, data } = request;
  if (!auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { masterPassword, sectionId, config, crPassword, srPassword } = data;
  if (!masterPassword || !sectionId || !config || !crPassword || !srPassword) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
  }

  if (masterPassword !== MASTER_PASSWORD.value()) {
    await logAudit({
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

  const hashedCrPassword = await hashPassword(crPassword);
  const hashedSrPassword = await hashPassword(srPassword);

  const batch = db.batch();

  batch.set(sectionRef, {
    ...config,
    crPassword: hashedCrPassword,
    srPassword: hashedSrPassword,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    timetablePublished: false,
  });

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

  await logAudit({
    action: 'CREATE_SECTION',
    targetUser: auth.uid,
    performedBy: auth.uid,
    section: sectionId,
    newRole: 'CR',
    result: 'SUCCESS'
  });

  return { success: true };
});
