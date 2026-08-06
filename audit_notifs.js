const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

async function checkRuntimeEvidence() {
  try {
    admin.initializeApp({
      projectId: 'schedly-production'
    });

    const db = getFirestore();
    
    // 1. Check outbox processing
    console.log("--- OUTBOX EVIDENCE ---");
    const outboxSnap = await db.collection('notification_outbox')
      .where('processed', '==', true)
      .orderBy('processedAt', 'desc')
      .limit(5)
      .get();
      
    if (outboxSnap.empty) {
      console.log("No processed notifications found in outbox.");
    } else {
      outboxSnap.docs.forEach(doc => {
        const data = doc.data();
        console.log(`[PASS] Doc ${doc.id}: status=${data.status}, type=${data.type}, processedAt=${data.processedAt?.toDate()}`);
      });
    }

    // 2. Check diagnostic logs from SW
    console.log("\n--- SW DIAGNOSTIC LOGS ---");
    const diagSnap = await db.collection('diagnostic_logs')
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();
      
    if (diagSnap.empty) {
      console.log("No diagnostic logs found from SW.");
    } else {
      diagSnap.docs.forEach(doc => {
        const data = doc.data();
        console.log(`[PASS] SW Log: stage=${data.stage}, timestamp=${data.timestamp?.toDate()}`);
      });
    }

    process.exit(0);
  } catch (err) {
    console.error("Error:", err);
    process.exit(1);
  }
}

checkRuntimeEvidence();
