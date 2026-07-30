import * as admin from 'firebase-admin';

export interface AuditLogData {
  action: string;
  targetUser: string;
  performedBy: string;
  section?: string;
  oldRole?: string;
  newRole?: string;
  result: 'SUCCESS' | 'FAILURE';
  failureReason?: string;
}

export async function logAudit(data: AuditLogData) {
  const db = admin.firestore();
  await db.collection('membership_audit_logs').add({
    ...data,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}
