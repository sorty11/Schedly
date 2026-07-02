import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

async function run() {
  const snapshot = await db.collection('notification_outbox')
    .orderBy('createdAt', 'desc')
    .limit(3)
    .get();
  
  console.log("LATEST 3 NOTIFICATIONS:");
  snapshot.forEach(doc => {
    console.log("ID:", doc.id);
    const data = doc.data();
    console.log("  uid:", data.uid);
    console.log("  status:", data.status);
    console.log("  lastError:", data.lastError);
    console.log("  attempts:", data.attempts);
    console.log("  type:", data.type);
    console.log("  title:", data.title);
  });
}

run().catch(console.error);
