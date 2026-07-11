const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, limit, query, orderBy } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: 'AIzaSyCvHene63scD_yzJiR0HHWHBKTad-n-sSI',
  appId: '1:1044389536762:web:8b8c7ec25645328411ba43',
  projectId: 'schedly-production',
  authDomain: 'schedly-production.firebaseapp.com',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

(async () => {
  try {
    const q = query(collection(db, 'notification_outbox'), orderBy('createdAt', 'desc'), limit(10));
    const snapshot = await getDocs(q);
    
    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.role === 'faculty') {
        console.log('--- FOUND FACULTY OUTBOX DOC ---');
        console.log('document id:', doc.id);
        console.log('division:', data.division);
        console.log('role:', data.role);
        console.log('uid:', data.uid);
        console.log('title:', data.title);
        console.log('type:', data.type);
        console.log('processed:', data.processed);
        console.log('--------------------------------');
      }
    });
    process.exit(0);
  } catch (e) {
    console.error('Error:', e);
    process.exit(1);
  }
})();
