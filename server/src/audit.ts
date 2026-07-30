import * as admin from 'firebase-admin';
import './config/firebase';

async function audit() {
  console.log('--- FIRESTORE AUDIT ---');
  const db = admin.firestore();
  const collections = await db.listCollections();
  
  for (const collection of collections) {
    const countSnapshot = await collection.count().get();
    const count = countSnapshot.data().count;
    console.log(`\nCollection: ${collection.id} (Count: ${count})`);
    
    if (count > 0) {
      const sample = await collection.limit(5).get();
      if (!sample.empty) {
        console.log(`  Sample Document IDs: ${sample.docs.map(d => d.id).join(', ')}`);
        
        // Check subcollections for the first document
        const subCollections = await sample.docs[0].ref.listCollections();
        if (subCollections.length > 0) {
          for (const sub of subCollections) {
            const subCountSnapshot = await sub.count().get();
            console.log(`    Subcollection: ${sub.id} (Count: ${subCountSnapshot.data().count} in ${sample.docs[0].id})`);
          }
        }
      }
    }
  }
  
  console.log('\n--- AUTH AUDIT ---');
  let authCount = 0;
  let pageToken;
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    authCount += result.users.length;
    pageToken = result.pageToken;
  } while (pageToken);
  console.log(`  Total Users: ${authCount}`);
  
  console.log('\nDone.');
  process.exit(0);
}

audit().catch(console.error);
