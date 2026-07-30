/**
 * Schedly Production Firestore Backup Utility
 *
 * Requirements:
 * - Connects to REAL production Firestore via backend initialization
 * - Recursively exports all collections and nested subcollections dynamically
 * - Uses Node.js Streams to prevent memory leaks on massive collections
 * - Preserves data types (Timestamp, GeoPoint, Reference, etc)
 * - Supports --dry-run
 */

const fs = require('fs');
const path = require('path');

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
const isDryRun = args.includes('--dry-run');

const timestampStr = new Date().toISOString().replace(/T/, '_').replace(/:/g, '-').split('.')[0];
const backupDir = path.join(__dirname, `../backups/backup_${timestampStr}`);

const state = {
  startTime: Date.now(),
  totalCollections: 0,
  totalDocuments: 0,
  errors: [],
  exportedPaths: new Set()
};

// ============================================================================
// SERIALIZATION
// ============================================================================

function serializeData(data) {
  if (data === null || data === undefined) return data;
  
  if (data instanceof Timestamp) {
    return { __datatype__: 'timestamp', value: { _seconds: data.seconds, _nanoseconds: data.nanoseconds } };
  }
  if (data instanceof GeoPoint) {
    return { __datatype__: 'geopoint', value: { latitude: data.latitude, longitude: data.longitude } };
  }
  if (data && typeof data === 'object' && data.constructor && data.constructor.name === 'DocumentReference') {
    return { __datatype__: 'reference', value: data.path };
  }
  if (data instanceof Buffer || (data && data.constructor && data.constructor.name === 'Buffer')) {
    return { __datatype__: 'bytes', value: data.toString('base64') };
  }
  if (Array.isArray(data)) {
    return data.map(serializeData);
  }
  if (typeof data === 'object') {
    const obj = {};
    for (const key of Object.keys(data)) {
      obj[key] = serializeData(data[key]);
    }
    return obj;
  }
  return data;
}

// ============================================================================
// CORE LOGIC
// ============================================================================

async function ensureDir(dirPath) {
  if (isDryRun) return;
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

async function exportCollection(collectionRef, relativePath) {
  if (state.exportedPaths.has(collectionRef.path)) return;
  state.exportedPaths.add(collectionRef.path);

  console.log(`\nExporting ${collectionRef.path}...`);
  
  const filePath = path.join(backupDir, `${relativePath}.json`);
  let fileStream = null;

  try {
    if (!isDryRun) {
      await ensureDir(path.dirname(filePath));
      fileStream = fs.createWriteStream(filePath, 'utf8');
      fileStream.write('[\n');
    }

    let docCount = 0;
    let isFirst = true;
    const subcollectionsToProcess = new Map();

    // Use .stream() to prevent memory overflow on large collections
    const stream = collectionRef.stream();

    for await (const doc of stream) {
      if (!isDryRun) {
        const serialized = serializeData(doc.data());
        const docObj = { id: doc.id, data: serialized };
        
        if (!isFirst) {
          fileStream.write(',\n');
        }
        fileStream.write('  ' + JSON.stringify(docObj));
        isFirst = false;
      }
      docCount++;

      // Dynamically discover nested subcollections for this document
      const subcollections = await doc.ref.listCollections();
      for (const sub of subcollections) {
        if (!subcollectionsToProcess.has(sub.path)) {
          subcollectionsToProcess.set(sub.path, sub);
        }
      }

      if (docCount % 500 === 0) {
        console.log(`  ...read ${docCount} documents from ${collectionRef.path}`);
      }
    }

    if (!isDryRun) {
      fileStream.write('\n]\n');
      fileStream.end();
    }

    console.log(`✓ ${docCount} documents exported from ${collectionRef.path}.`);
    state.totalCollections++;
    state.totalDocuments += docCount;

    // Process nested subcollections strictly after closing the current stream to preserve memory
    for (const sub of subcollectionsToProcess.values()) {
      await exportCollection(sub, sub.path);
    }

  } catch (error) {
    if (fileStream) fileStream.end();
    if (error.code === 7 || (error.message && error.message.includes('Permission denied'))) {
      console.error(`[ERROR] Permission denied for ${collectionRef.path}. Verify Firebase rules or credentials.`);
    } else {
      console.error(`[ERROR] Failed to export ${collectionRef.path}: ${error.message}`);
    }
    state.errors.push({ path: collectionRef.path, error: error.message });
  }
}

async function main() {
  console.log(`\n=== Schedly Production Backup ===`);
  if (isDryRun) console.log(`[DRY RUN] No files will be written.\n`);

  try {
    // 1. Verify Credentials / Connection
    let rootCollections;
    try {
      rootCollections = await db.listCollections();
    } catch (error) {
      console.error('\n[FATAL] Missing or Invalid Credentials.');
      console.error('The backend initialized successfully, but querying Firestore failed.');
      console.error('Error Details:', error.message);
      console.error('\nRequired Action:');
      console.error('Please ensure that either FIREBASE_SERVICE_ACCOUNT_JSON is set in your .env');
      console.error('OR you have run `gcloud auth application-default login` on this machine.');
      process.exit(1);
    }

    if (!isDryRun) {
      await ensureDir(backupDir);
    }

    // 2. Execute Recursive Backup
    for (const collection of rootCollections) {
      await exportCollection(collection, collection.id);
    }

    // 3. Finalization
    const duration = ((Date.now() - state.startTime) / 1000).toFixed(1);
    
    if (!isDryRun) {
      const metadata = {
        timestamp: new Date().toISOString(),
        totalCollections: state.totalCollections,
        totalDocuments: state.totalDocuments,
        durationSeconds: duration,
        errors: state.errors
      };
      fs.writeFileSync(path.join(backupDir, 'metadata.json'), JSON.stringify(metadata, null, 2));
    }

    console.log(`\n✓ Backup Complete in ${duration}s`);
    console.log(`Total Collections: ${state.totalCollections}`);
    console.log(`Total Documents: ${state.totalDocuments}`);
    
    if (state.errors.length > 0) {
      console.log(`\n[WARNING] Completed with ${state.errors.length} partial failures.`);
      if (!isDryRun) fs.writeFileSync(path.join(backupDir, 'error_report.json'), JSON.stringify(state.errors, null, 2));
    }

    if (!isDryRun) {
      console.log(`\nLocation:\n${backupDir}`);
    }

    process.exit(state.errors.length > 0 ? 1 : 0);

  } catch (globalError) {
    console.error(`\n[FATAL] Unexpected crash: ${globalError.message}`);
    process.exit(1);
  }
}

main();
