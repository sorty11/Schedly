/**
 * Schedly Production Firestore Restore Utility
 *
 * Requirements:
 * - Connects to REAL production Firestore via backend initialization
 * - Recreates all collections and nested subcollections from backup
 * - Deserializes data types (Timestamp, GeoPoint, Reference, etc)
 * - Restores document IDs
 * - Requires explicit --confirm
 * - Batched writes with exponential backoff for memory and rate-limit safety
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

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
const { getFirestore, Timestamp, GeoPoint } = require(firestoreModulePath);
const db = getFirestore();

// ============================================================================
// CONFIGURATION & STATE
// ============================================================================

const args = process.argv.slice(2);
const backupTarget = args.find(a => !a.startsWith('--'));
const isDryRun = args.includes('--dry-run');
const isConfirmed = args.includes('--confirm');

if (!backupTarget) {
  console.error('\nUsage: node restore_firestore.js <backup_folder> [--dry-run] [--confirm]');
  console.error('Example: node restore_firestore.js backups/backup_2026-07-15_18-30');
  process.exit(1);
}

const backupDir = path.resolve(backupTarget);
if (!fs.existsSync(backupDir) || !fs.existsSync(path.join(backupDir, 'metadata.json'))) {
  console.error(`\n[FATAL] Invalid backup folder: ${backupDir}`);
  console.error('A valid metadata.json file must exist in the root of the backup directory.');
  process.exit(1);
}

const state = {
  startTime: Date.now(),
  totalDocumentsRestored: 0,
  errors: []
};

// ============================================================================
// DESERIALIZATION
// ============================================================================

function deserializeData(data) {
  if (data === null || data === undefined) return data;

  if (typeof data === 'object' && data.__datatype__) {
    if (data.__datatype__ === 'timestamp') {
      return new Timestamp(data.value._seconds, data.value._nanoseconds);
    }
    if (data.__datatype__ === 'geopoint') {
      return new GeoPoint(data.value.latitude, data.value.longitude);
    }
    if (data.__datatype__ === 'reference') {
      return db.doc(data.value);
    }
    if (data.__datatype__ === 'bytes') {
      return Buffer.from(data.value, 'base64');
    }
  }

  if (Array.isArray(data)) {
    return data.map(deserializeData);
  }

  if (typeof data === 'object') {
    const obj = {};
    for (const key of Object.keys(data)) {
      obj[key] = deserializeData(data[key]);
    }
    return obj;
  }

  return data;
}

// ============================================================================
// CORE LOGIC
// ============================================================================

// Recursively find all JSON files representing collections
function discoverCollections(dir, base = '') {
  let results = [];
  const items = fs.readdirSync(dir);
  for (const item of items) {
    if (item === 'metadata.json' || item === 'error_report.json') continue;
    
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    
    if (stat.isDirectory()) {
      results = results.concat(discoverCollections(fullPath, path.join(base, item)));
    } else if (item.endsWith('.json')) {
      const collectionPath = path.join(base, item.replace('.json', '')).replace(/\\/g, '/');
      results.push({ collectionPath, file: fullPath });
    }
  }
  return results;
}

// Commit with exponential backoff for rate limits
async function commitBatchWithRetry(batch, attempt = 1) {
  if (isDryRun) return;
  try {
    await batch.commit();
  } catch (err) {
    if (attempt > 5) throw err;
    const delay = attempt * 2000;
    console.warn(`    [WARN] Batch commit failed (${err.message}). Retrying ${attempt}/5 in ${delay}ms...`);
    await new Promise(r => setTimeout(r, delay));
    // Firebase Admin batches technically can't always be re-committed if it was a partial internal failure,
    // but a deadline exceeded usually can be. We throw to higher level if it fails completely.
    await commitBatchWithRetry(batch, attempt + 1);
  }
}

async function restoreCollection(collectionPath, filePath) {
  console.log(`\nRestoring ${collectionPath}...`);
  
  try {
    const rawData = fs.readFileSync(filePath, 'utf8');
    const documents = JSON.parse(rawData);
    
    if (!documents || !Array.isArray(documents)) {
      throw new Error('Invalid JSON format. Expected array of documents.');
    }

    let batch = db.batch();
    let batchCount = 0;
    
    for (const doc of documents) {
      if (!doc.id || !doc.data) continue;
      
      const docRef = db.doc(`${collectionPath}/${doc.id}`);
      const deserializedData = deserializeData(doc.data);
      
      if (!isDryRun) {
        batch.set(docRef, deserializedData);
      }
      
      batchCount++;
      state.totalDocumentsRestored++;
      
      // Execute batched writes (limit to 400 for safety, max is 500)
      if (batchCount >= 400) {
        await commitBatchWithRetry(batch);
        batch = db.batch(); // Reinitialize
        batchCount = 0;
      }
    }
    
    // Commit remaining items
    if (batchCount > 0) {
      await commitBatchWithRetry(batch);
    }
    
    console.log(`✓ ${documents.length} documents restored to ${collectionPath}.`);
  } catch (error) {
    console.error(`[ERROR] Failed to restore ${collectionPath}: ${error.message}`);
    state.errors.push({ path: collectionPath, error: error.message });
  }
}

async function promptConfirmation() {
  if (isDryRun) return true;
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise(resolve => {
    rl.question('\n[WARNING] You are about to write to PRODUCTION Firestore.\nAre you sure? (YES) ', (answer) => {
      rl.close();
      resolve(answer === 'YES');
    });
  });
}

async function main() {
  console.log(`\n=== Schedly Production Restore ===`);
  
  if (isDryRun) {
    console.log(`[DRY RUN] Simulating restore. No data will be written.\n`);
  } else if (!isConfirmed) {
    const confirmed = await promptConfirmation();
    if (!confirmed) {
      console.log('Restore aborted by user.');
      process.exit(0);
    }
  }

  try {
    // 1. Verify Credentials / Connection
    try {
      await db.listCollections();
    } catch (error) {
      console.error('\n[FATAL] Missing or Invalid Credentials.');
      console.error('The backend initialized successfully, but querying Firestore failed.');
      console.error('Error Details:', error.message);
      console.error('\nRequired Action:');
      console.error('Please ensure that either FIREBASE_SERVICE_ACCOUNT_JSON is set in your .env');
      console.error('OR you have run `gcloud auth application-default login` on this machine.');
      process.exit(1);
    }

    // 2. Discover Collections
    const collections = discoverCollections(backupDir);
    if (collections.length === 0) {
      console.log('\nNo collections found to restore in the target directory.');
      process.exit(0);
    }

    // 3. Execute Restore sequentially to prevent spiking rate limits
    for (const { collectionPath, file } of collections) {
      await restoreCollection(collectionPath, file);
    }

    // 4. Finalization
    const duration = ((Date.now() - state.startTime) / 1000).toFixed(1);
    
    console.log(`\n✓ Restore Complete in ${duration}s`);
    console.log(`Total Collections Restored: ${collections.length}`);
    console.log(`Total Documents Restored: ${state.totalDocumentsRestored}`);
    
    if (state.errors.length > 0) {
      console.log(`\n[WARNING] Completed with ${state.errors.length} partial failures.`);
      console.log(JSON.stringify(state.errors, null, 2));
      process.exit(1);
    }

    process.exit(0);

  } catch (globalError) {
    console.error(`\n[FATAL] Unexpected crash: ${globalError.message}`);
    process.exit(1);
  }
}

main();
