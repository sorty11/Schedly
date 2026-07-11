import * as admin from 'firebase-admin';

admin.initializeApp({
    projectId: "demo-project"
});

const db = admin.firestore();

async function run() {
  try {
    console.log('--- PROVING FACULTY REMINDER ROLE MISMATCH ---');
    const usersSnap = await db.collection('users').get();
    usersSnap.forEach(doc => {
      const data = doc.data();
      if (data.role && (data.role === 'faculty' || data.role === 'FACULTY')) {
        console.log(`6. Firestore users/{uid}.role for ${doc.id}:`, data.role);
      }
    });

    console.log('\n--- PROVING TIMETABLE ID MISMATCH ---');
    // We want to find the ID stored inside the timetable document
    const ttSnap = await db.collection('timetables').doc('fac_test').collection('Monday').get();
    if (!ttSnap.empty) {
        ttSnap.forEach(doc => {
            const data = doc.data();
            console.log('3. facultyId stored inside the timetable document:', data.facultyId);
        });
    } else {
        console.log('No timetables found in fac_test, checking globally (collectionGroup)...');
        const cgSnap = await db.collectionGroup('Monday').get();
        cgSnap.forEach(doc => {
            const data = doc.data();
            if (data.facultyId) {
                console.log(`3. facultyId stored inside the timetable document (${doc.id}):`, data.facultyId);
            }
        });
    }

    const fpSnap = await db.collection('faculty_profiles').get();
    fpSnap.forEach(doc => {
      console.log('2. faculty_profiles document ID:', doc.id, 'Name:', doc.data().name);
    });

    const outboxSnap = await db.collection('notification_outbox').orderBy('createdAt', 'desc').limit(5).get();
    outboxSnap.forEach(doc => {
        const data = doc.data();
        if (data.role === 'faculty' || data.type === 'faculty_reminder' || data.type === 'lecture_added') {
            console.log('4. division written into notification_outbox:', data.division, 'for type:', data.type);
        }
    });

    // Check fcm_tokens for the subscribed division
    const tokenSnap = await db.collectionGroup('fcm_tokens').get();
    tokenSnap.forEach(doc => {
        const data = doc.data();
        if (data.role === 'faculty') {
            console.log('5. division in fcm_tokens (determines subscribed topic):', data.division);
        }
    });

  } catch(e) {
    console.error(e);
  }
}

run().catch(console.error);
