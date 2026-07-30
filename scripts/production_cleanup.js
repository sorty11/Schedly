/**
 * Schedly Production Data Cleanup Script
 * 
 * Target: Cleans up only runtime/testing data before college launch.
 * Safety: Will NEVER touch sections, timetables, faculty_profiles, users, attendance, or subjects.
 * 
 * Prerequisites:
 * 1. Ensure you have the Firebase Admin SDK installed: `npm install firebase-admin`
 * 2. Set your Google Application Credentials environment variable:
 *    export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/serviceAccountKey.json"
 * 
 * Usage:
 * Dry Run:  node production_cleanup.js --dry-run
 * Execute:  node production_cleanup.js --confirm
 */

const admin = require('firebase-admin');

// Parse arguments
const args = process.argv.slice(2);
const isConfirm = args.includes('--confirm');
const isDryRun = args.includes('--dry-run');

if (!isConfirm && !isDryRun) {
  console.error('\n[ERROR] Safety Lock Active.');
  console.error('You must explicitly specify either --dry-run (to preview) or --confirm (to execute).');
  console.error('Usage: node production_cleanup.js --dry-run\n');
  process.exit(1);
}

if (isConfirm && isDryRun) {
  console.error('\n[ERROR] Cannot run in both --confirm and --dry-run mode.\n');
  process.exit(1);
}

// Initialize Admin SDK
// This will automatically pick up the GOOGLE_APPLICATION_CREDENTIALS env var
admin.initializeApp();
const db = admin.firestore();

const BATCH_SIZE = 400; // Optimal batch size below Firestore's 500 limit

/**
 * Recursively deletes a batch of documents using batched writes.
 */
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

  // Recurse to handle the next batch. We don't need process.nextTick for typical 
  // sizes since Promises handle micro-task queuing, but keep query limits active.
  return await deleteQueryBatch(query, totalDeletedCount + batchSize);
}

/**
 * Cleans up a root-level collection.
 */
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

/**
 * Cleans up a subcollection nested explicitly under `sections`.
 * This approach guarantees we do not accidentally delete similarly named
 * subcollections under other paths (e.g. users/*/history).
 */
async function cleanupSectionSubcollections(subcollectionName) {
  console.log(`\n--- Target: Subcollections [sections/*/${subcollectionName}] ---`);
  let totalDeleted = 0;
  
  // Using .select() limits the payload strictly to DocumentReferences
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

/**
 * Main execution function
 */
async function main() {
  if (isDryRun) {
    console.log('\n=============================================');
    console.log('       STARTING DRY RUN (NO DELETIONS)       ');
    console.log('=============================================');
  } else {
    console.log('\n=============================================');
    console.log('    STARTING PRODUCTION CLEANUP (CONFIRMED)  ');
    console.log('=============================================');
  }

  let totalGrandDeleted = 0;

  try {
    // 1. Root Collections
    totalGrandDeleted += await cleanupCollection('notification_outbox');
    totalGrandDeleted += await cleanupCollection('faculty_reminders');
    totalGrandDeleted += await cleanupCollection('faculty_audit_logs');
    totalGrandDeleted += await cleanupCollection('conduct_logs');

    // 2. Section Subcollections
    totalGrandDeleted += await cleanupSectionSubcollections('announcements');
    totalGrandDeleted += await cleanupSectionSubcollections('notifications');
    totalGrandDeleted += await cleanupSectionSubcollections('history');

    console.log('\n=============================================');
    if (isDryRun) {
      console.log(`[DRY RUN COMPLETE] Found a total of ${totalGrandDeleted} documents that would be deleted.`);
      console.log('Run with --confirm to execute the deletion permanently.');
    } else {
      console.log(`[CLEANUP COMPLETE] Successfully and permanently deleted ${totalGrandDeleted} documents.`);
      console.log('Production runtime data has been scrubbed.');
    }
    console.log('=============================================\n');

  } catch (error) {
    console.error('\n[FATAL ERROR] An error occurred during the cleanup process:', error);
  }
}

// Run script
main();
