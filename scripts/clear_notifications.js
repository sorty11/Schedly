/**
 * Schedly Temporary Notifications Cleanup Script
 * 
 * Target: Cleans up only the temporary notifications stored in the notification tab
 * - notification_outbox
 * - sections/[section_id]/notifications
 */

const path = require('path');
const fs = require('fs');

// 1. Parse Backend TypeScript Configuration
const tsNodePath = path.join(__dirname, '../server/node_modules/ts-node');
if (!fs.existsSync(tsNodePath)) {
  console.error('\n[FATAL] ts-node not found. Run npm install in server/.');
  process.exit(1);
}
require(tsNodePath).register({
  transpileOnly: true,
  project: path.join(__dirname, '../server/tsconfig.json'),
  compilerOptions: { module: 'commonjs' }
});

// 2. Load Environment (Simulating backend startup)
require(path.join(__dirname, '../server/node_modules/dotenv')).config({
  path: path.join(__dirname, '../server/.env')
});

// Fallback: If no project ID is provided in the environment, pull it from .firebaserc
if (!process.env.GCLOUD_PROJECT && !process.env.FIREBASE_PROJECT_ID) {
  try {
    const rcPath = path.join(__dirname, '../.firebaserc');
    if (fs.existsSync(rcPath)) {
      const rc = JSON.parse(fs.readFileSync(rcPath, 'utf8'));
      if (rc.projects && rc.projects.default) {
        process.env.GCLOUD_PROJECT = rc.projects.default;
      }
    }
  } catch(e) {}
}

// 3. Intercept and Reuse Backend Initialization EXACTLY
const adminPath = require.resolve('firebase-admin', { paths: [path.join(__dirname, '../server')] });
const admin = require(adminPath);

let capturedInitError = null;
const originalInit = admin.initializeApp;
admin.initializeApp = function(...args) {
  try {
    return originalInit.apply(admin, args);
  } catch (e) {
    capturedInitError = e;
    throw e;
  }
};

require('../server/src/config/firebase');

if (admin.apps.length === 0) {
  console.error('\n[FATAL] Firebase initialization failed inside server/src/config/firebase.ts.');
  if (capturedInitError) {
    console.error('\nExact Initialization Error:');
    console.error(capturedInitError.stack || capturedInitError.message);
  } else {
    console.error('\nNo app was initialized and no explicit error was thrown.');
  }
  process.exit(1);
}

// Restore original just to be clean
admin.initializeApp = originalInit;

// 4. Import exact Firebase SDK
const firestoreModulePath = require.resolve('firebase-admin/firestore', { paths: [path.join(__dirname, '../server')] });
const { getFirestore } = require(firestoreModulePath);
const db = getFirestore();

// Parse arguments
const args = process.argv.slice(2);
const isConfirm = args.includes('--confirm');
const isDryRun = args.includes('--dry-run');

if (!isConfirm && !isDryRun) {
  console.error('\n[ERROR] Safety Lock Active.');
  console.error('You must explicitly specify either --dry-run (to preview) or --confirm (to execute).');
  console.error('Usage: node scripts/clear_notifications.js --dry-run\n');
  process.exit(1);
}

if (isConfirm && isDryRun) {
  console.error('\n[ERROR] Cannot run in both --confirm and --dry-run mode.\n');
  process.exit(1);
}

const BATCH_SIZE = 400; // Optimal batch size below Firestore's 500 limit

async function deleteQueryBatch(query, totalDeletedCount = 0) {
  const snapshot = await query.get();
  const batchSize = snapshot.size;
  
  if (batchSize === 0) {
    return totalDeletedCount;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log(`  ✓ Deleted batch of ${batchSize} documents...`);

  return await deleteQueryBatch(query, totalDeletedCount + batchSize);
}

async function cleanupCollection(collectionName) {
  console.log(`\n--- Target: Collection [${collectionName}] ---`);
  
  if (isDryRun) {
    const snap = await db.collection(collectionName).count().get();
    const count = snap.data().count;
    console.log(`[DRY RUN] Would delete ${count} documents from /${collectionName}.`);
    return count;
  } else {
    const query = db.collection(collectionName).orderBy('__name__').limit(BATCH_SIZE);
    const deleted = await deleteQueryBatch(query);
    console.log(`[SUCCESS] Deleted ${deleted} total documents from /${collectionName}.`);
    return deleted;
  }
}

async function cleanupSectionSubcollections(subcollectionName) {
  console.log(`\n--- Target: Subcollections [sections/*/${subcollectionName}] ---`);
  let totalDeleted = 0;
  
  const sectionsSnap = await db.collection('sections').select().get();
  
  for (const sectionDoc of sectionsSnap.docs) {
    const subRef = sectionDoc.ref.collection(subcollectionName);
    
    if (isDryRun) {
      const snap = await subRef.count().get();
      const count = snap.data().count;
      if (count > 0) {
        console.log(`  [DRY RUN] Would delete ${count} docs from sections/${sectionDoc.id}/${subcollectionName}`);
      }
      totalDeleted += count;
    } else {
      const query = subRef.orderBy('__name__').limit(BATCH_SIZE);
      const deleted = await deleteQueryBatch(query);
      if (deleted > 0) {
        console.log(`  [SUCCESS] Deleted ${deleted} docs from sections/${sectionDoc.id}/${subcollectionName}`);
      }
      totalDeleted += deleted;
    }
  }

  console.log(`\n[COMPLETE] Total ${totalDeleted} documents processed for sections/*/${subcollectionName}.`);
  return totalDeleted;
}

async function main() {
  if (isDryRun) {
    console.log('\n=============================================');
    console.log('       STARTING DRY RUN (NO DELETIONS)       ');
    console.log('=============================================');
  } else {
    console.log('\n=============================================');
    console.log('    STARTING NOTIFICATION CLEANUP (CONFIRMED)  ');
    console.log('=============================================');
  }

  let totalGrandDeleted = 0;

  try {
    // ONLY Notification related collections
    totalGrandDeleted += await cleanupCollection('notification_outbox');
    totalGrandDeleted += await cleanupSectionSubcollections('notifications');

    console.log('\n=============================================');
    if (isDryRun) {
      console.log(`[DRY RUN COMPLETE] Found a total of ${totalGrandDeleted} notification documents that would be deleted.`);
      console.log('Run with --confirm to execute the deletion permanently.');
    } else {
      console.log(`[CLEANUP COMPLETE] Successfully and permanently deleted ${totalGrandDeleted} notification documents.`);
    }
    console.log('=============================================\n');

  } catch (error) {
    if (error.message && error.message.includes('Could not load the default credentials')) {
      console.error('\n[FATAL] Missing Google Cloud Credentials.');
      console.error('Your local environment is not authenticated to access the production Firestore.');
      console.error('\nRequired Action (choose one):');
      console.error('1. Set FIREBASE_SERVICE_ACCOUNT_JSON in your server/.env file.');
      console.error('2. Or, run the following command in your terminal to authenticate globally:');
      console.error('   gcloud auth application-default login\n');
    } else {
      console.error('\n[FATAL ERROR] An error occurred during the cleanup process:', error);
    }
  }
}

main();
