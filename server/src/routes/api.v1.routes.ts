import { Router } from 'express';
import { worker } from '../app';
import { AppConfig } from '../config/env.config';
import * as admin from 'firebase-admin';
import { verifyIdToken } from '../middleware/auth.middleware';
import { sectionCreateRateLimiter } from '../middleware/rateLimiter.middleware';
import { logger } from '../utils/logger';

const router = Router();

router.post('/create-section', sectionCreateRateLimiter, verifyIdToken, async (req: any, res: any) => {
  const { masterPassword, sectionId, sectionData, crPassword, srPassword } = req.body;

  if (masterPassword !== AppConfig.MASTER_SETUP_PASSWORD) {
    logger.warn('Failed section creation: Invalid master password', { uid: req.user?.uid, sectionId });
    return res.status(403).json({ error: 'Incorrect Master Password' });
  }

  if (!sectionId || !sectionData || !crPassword || !srPassword) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const db = admin.firestore();
    const sectionRef = db.collection('sections').doc(sectionId);
    
    // Check if it already exists
    const doc = await sectionRef.get();
    if (doc.exists) {
      logger.warn('Failed section creation: Section already exists', { uid: req.user?.uid, sectionId });
      return res.status(409).json({ error: 'Section already exists' });
    }

    // Create the section securely
    await sectionRef.set({
      ...sectionData,
      crPassword,
      srPassword,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timetablePublished: false,
    });
    
    logger.info('Section created successfully', { uid: req.user?.uid, sectionId });
    return res.status(201).json({ success: true, message: 'Section created' });
  } catch (error: any) {
    logger.error('Error creating section', { error: error.message });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/delete-account', verifyIdToken, async (req: any, res: any) => {
  const uid = req.user?.uid;
  if (!uid) {
    logger.warn('Delete account rejected: Missing UID in token');
    return res.status(401).json({ success: false, error: 'Unauthorized: Missing user UID' });
  }

  logger.info('Starting account deletion workflow', { uid });
  const db = admin.firestore();
  const stepLog: string[] = [];

  try {
    // 1. Fetch user metadata (if user document exists)
    stepLog.push('fetch_metadata');
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    const userData = userSnap.data() || {};
    const division = userData.division as string | undefined;
    const rollNo = userData.rollNo as string | undefined;
    const role = userData.role as string | undefined;
    const facultyProfileId = userData.facultyProfileId as string | undefined;
    const studentName = userData.name as string | undefined;

    // 2. Detach section memberships strictly owned by this UID
    stepLog.push('detach_memberships');
    const membershipsSnap = await db.collection('section_memberships')
      .where('userId', '==', uid)
      .get();
    
    if (!membershipsSnap.empty) {
      const batch = db.batch();
      for (const doc of membershipsSnap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    // If division is known, also check canonical key ${division}_${uid}
    if (division) {
      const canonicalRef = db.collection('section_memberships').doc(`${division}_${uid}`);
      const canSnap = await canonicalRef.get();
      if (canSnap.exists && canSnap.data()?.userId === uid) {
        await canonicalRef.delete();
      }
    }

    // 3. Detach student entry from section if applicable
    stepLog.push('detach_student_entry');
    if (division && rollNo) {
      const studentDocRef = db.collection('sections').doc(division).collection('students').doc(rollNo);
      const studentSnap = await studentDocRef.get();
      if (studentSnap.exists) {
        const sData = studentSnap.data();
        if (!sData?.rollNo || sData.rollNo === rollNo) {
          await studentDocRef.delete();
        }
      }
    }

    // 4. Detach SR assignment if applicable (smallest possible shared-document update)
    stepLog.push('detach_sr_assignment');
    if (division && (role === 'SR' || userData.srSubject)) {
      const srAssignmentsSnap = await db.collection('sections').doc(division).collection('sr_assignments').get();
      for (const doc of srAssignmentsSnap.docs) {
        const data = doc.data();
        if (Array.isArray(data.srs)) {
          const initialLen = data.srs.length;
          const filtered = data.srs.filter((s: any) => {
            if (typeof s !== 'string') return true;
            if (rollNo && s.includes(rollNo)) return false;
            if (studentName && s.includes(studentName)) return false;
            if (s.includes(uid)) return false;
            return true;
          });
          if (filtered.length !== initialLen) {
            await doc.ref.update({
              srs: filtered,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        }
      }
    }

    // 5. Detach faculty profile if applicable (smallest possible shared-document update)
    stepLog.push('detach_faculty');
    if (role === 'Faculty' || facultyProfileId) {
      const facQuery = await db.collection('faculty_profiles').where('uid', '==', uid).get();
      for (const doc of facQuery.docs) {
        await doc.ref.update({
          uid: admin.firestore.FieldValue.delete(),
          unlinkedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      if (facultyProfileId) {
        const facDocRef = db.collection('faculty_profiles').doc(facultyProfileId);
        const facSnap = await facDocRef.get();
        if (facSnap.exists && facSnap.data()?.uid === uid) {
          await facDocRef.update({
            uid: admin.firestore.FieldValue.delete(),
            unlinkedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
    }

    // 6. Cleanup user-owned Storage files if any exist
    stepLog.push('cleanup_storage');
    try {
      const bucket = admin.storage().bucket();
      await bucket.deleteFiles({
        prefix: `attendance-uploads/${uid}/`
      });
    } catch (storageErr: any) {
      logger.info('Storage cleanup skipped or completed with non-fatal message', {
        uid,
        message: storageErr.message
      });
    }

    // 7. Recursive deletion of all private user data (root doc + all subcollections)
    stepLog.push('delete_private_firestore');
    if (userSnap.exists) {
      await db.recursiveDelete(userRef);
    } else {
      const fcmTokensSnap = await userRef.collection('fcm_tokens').get();
      const attendanceSnap = await userRef.collection('attendance').get();
      const logsSnap = await userRef.collection('attendance_logs').get();
      const summarySnap = await userRef.collection('attendance_summary').get();
      
      const b = db.batch();
      fcmTokensSnap.docs.forEach(d => b.delete(d.ref));
      attendanceSnap.docs.forEach(d => b.delete(d.ref));
      logsSnap.docs.forEach(d => b.delete(d.ref));
      summarySnap.docs.forEach(d => b.delete(d.ref));
      await b.commit();
    }

    // 8. Delete Firebase Auth user
    stepLog.push('delete_auth_user');
    try {
      await admin.auth().deleteUser(uid);
    } catch (authErr: any) {
      if (authErr.code === 'auth/user-not-found') {
        logger.info('Auth user was already deleted', { uid });
      } else {
        throw authErr;
      }
    }

    logger.info('Account deletion completed successfully', { uid, stepsCompleted: stepLog });
    return res.status(200).json({
      success: true,
      message: 'Account and associated data deleted successfully',
      stepsCompleted: stepLog
    });
  } catch (error: any) {
    const failedStep = stepLog[stepLog.length - 1] || 'unknown';
    logger.error('Account deletion failed', { uid, failedStep, error: error.message });
    return res.status(500).json({
      success: false,
      error: `Deletion failed during step '${failedStep}': ${error.message}`,
      failedStep
    });
  }
});

router.get('/health', async (req, res) => {
  try {
    const stats = worker.getStats();
    let firebaseStatus = 'connected';
    try {
      await admin.auth().listUsers(1);
    } catch(e) {
      firebaseStatus = 'error';
    }
    
    res.status(200).json({
      status: 'healthy',
      version: AppConfig.VERSION,
      worker: stats.workerState,
      firebase: firebaseStatus,
      uptime: `${process.uptime()}s`,
      queueLength: stats.queueLength,
      processedToday: stats.processedToday,
      failedToday: stats.failedToday,
      deadLetters: stats.deadLetters,
      pollingInterval: stats.pollingInterval,
      averageProcessingTime: stats.averageProcessingTime
    });
  } catch(e) {
    res.status(500).json({ status: 'error', message: 'Failed to fetch health' });
  }
});

router.get('/stats', (req, res) => {
  res.status(501).json({ error: 'Not Implemented' });
});

router.get('/admin', (req, res) => {
  res.status(501).json({ error: 'Not Implemented' });
});

export default router;
