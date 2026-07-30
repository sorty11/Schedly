const fs = require('fs');
const path = require('path');

const rolesPath = path.join(__dirname, 'roles.ts');
let code = fs.readFileSync(rolesPath, 'utf8');

// Insert the helper function right after imports
const importEnd = code.indexOf('\n\n', code.indexOf('FACULTY_MASTER_PASSWORD')) + 2;

const helperCode = `
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
      action: \`ELEVATE_TO_\${roleTarget}_UNLOCK\`,
      targetUser: uid,
      performedBy: uid,
      result: 'SUCCESS',
      failureReason: 'Lockout expired'
    });
  }

  if (txResult.status === 'LOCKED_OUT') {
    await logAudit({
      action: \`ELEVATE_TO_\${roleTarget}\`,
      targetUser: uid,
      performedBy: uid,
      result: 'FAILURE',
      failureReason: 'Account temporarily locked due to too many failed attempts'
    });
    throw new functions.https.HttpsError('resource-exhausted', 'Too many failed attempts. Please try again later.');
  }

  if (txResult.status === 'NEW_LOCKOUT') {
    await logAudit({
      action: \`ELEVATE_TO_\${roleTarget}_LOCKOUT\`,
      targetUser: uid,
      performedBy: uid,
      result: 'FAILURE',
      failureReason: \`Exceeded \${MAX_FAILED_ATTEMPTS} failed attempts\`
    });
    throw new functions.https.HttpsError('resource-exhausted', 'Too many failed attempts. Please try again later.');
  }

  if (txResult.status === 'FAILURE') {
    await logAudit({
      action: \`ELEVATE_TO_\${roleTarget}\`,
      targetUser: uid,
      performedBy: uid,
      result: 'FAILURE',
      failureReason: 'Incorrect password'
    });
    throw new functions.https.HttpsError('permission-denied', 'Incorrect password.');
  }
}
`;

code = code.substring(0, importEnd) + helperCode + code.substring(importEnd);

// Replace verifyCRRole password check
code = code.replace(
  /const isValid = await verifyPassword\(password, storedPassword\);\s*if \(\!isValid\) \{[\s\S]*?throw new functions\.https\.HttpsError\('permission-denied', 'Incorrect password\.'\);\s*\}/g,
  `await checkRateLimitAndVerify(auth.uid, 'CR', async () => await verifyPassword(password, storedPassword));`
);

// Replace verifySRRole password check
code = code.replace(
  /const isValid = await verifyPassword\(password, storedPassword\);\s*if \(\!isValid\) \{[\s\S]*?throw new functions\.https\.HttpsError\('permission-denied', 'Incorrect password\.'\);\s*\}/g,
  `await checkRateLimitAndVerify(auth.uid, 'SR', async () => await verifyPassword(password, storedPassword));`
);

// Replace verifyFacultyRole password check
code = code.replace(
  /if \(masterPassword !== FACULTY_MASTER_PASSWORD\.value\(\)\) \{[\s\S]*?throw new functions\.https\.HttpsError\('permission-denied', 'Incorrect master password\.'\);\s*\}/g,
  `await checkRateLimitAndVerify(auth.uid, 'FACULTY', () => masterPassword === FACULTY_MASTER_PASSWORD.value());`
);

fs.writeFileSync(rolesPath, code);
console.log('Roles modified successfully');
