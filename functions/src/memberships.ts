import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { logAudit } from './audit';

export async function verifyCRForSection(uid: string, sectionId: string): Promise<boolean> {
  const db = admin.firestore();
  const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${uid}`);
  const doc = await membershipRef.get();
  return doc.exists && doc.data()?.role === 'CR' && doc.data()?.status === 'active';
}

export const removeStudent = functions.https.onCall({ secrets: [] }, async (request) => {
  const { auth, data } = request;
  if (!auth) throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');

  const { targetUserId, sectionId } = data;
  if (!targetUserId || !sectionId) throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');

  const isCR = await verifyCRForSection(auth.uid, sectionId);
  if (!isCR) throw new functions.https.HttpsError('permission-denied', 'Only active CRs can remove students.');

  const db = admin.firestore();
  const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${targetUserId}`);
  
  await membershipRef.update({
    status: 'removed',
    removedAt: admin.firestore.FieldValue.serverTimestamp(),
    removedBy: auth.uid,
  });

  await logAudit({
    action: 'REMOVE_STUDENT',
    targetUser: targetUserId,
    performedBy: auth.uid,
    section: sectionId,
    newRole: 'removed',
    result: 'SUCCESS'
  });

  return { success: true };
});

export const restoreStudent = functions.https.onCall({ secrets: [] }, async (request) => {
  const { auth, data } = request;
  if (!auth) throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');

  const { targetUserId, sectionId } = data;
  if (!targetUserId || !sectionId) throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');

  const isCR = await verifyCRForSection(auth.uid, sectionId);
  if (!isCR) throw new functions.https.HttpsError('permission-denied', 'Only active CRs can restore students.');

  const db = admin.firestore();
  const membershipRef = db.collection('section_memberships').doc(`${sectionId}_${targetUserId}`);
  
  await membershipRef.update({
    status: 'active',
    restoredAt: admin.firestore.FieldValue.serverTimestamp(),
    restoredBy: auth.uid,
  });

  await logAudit({
    action: 'RESTORE_STUDENT',
    targetUser: targetUserId,
    performedBy: auth.uid,
    section: sectionId,
    newRole: 'active',
    result: 'SUCCESS'
  });

  return { success: true };
});
