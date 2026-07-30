const { initializeApp } = require('firebase/app');
const { getAuth, signInAnonymously } = require('firebase/auth');
const { getFirestore, collection, getDocs } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyCvHene63scD_yzJiR0HHWHBKTad-n-sSI",
  appId: "1:1044389536762:web:8b8c7ec25645328411ba43",
  projectId: "schedly-production",
  authDomain: "schedly-production.firebaseapp.com",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function runAudit() {
  console.log('Starting Client SDK Audit...');
  await signInAnonymously(auth);
  console.log('Signed in anonymously.');

  const usersSnapshot = await getDocs(collection(db, 'users'));
  const facultyProfilesSnapshot = await getDocs(collection(db, 'faculty_profiles'));

  console.log('\n--- USERS ---');
  usersSnapshot.forEach(doc => {
    console.log(`User ID: ${doc.id}, Role: ${doc.data().role}, Division: ${doc.data().division}`);
  });

  console.log('\n--- FACULTY PROFILES ---');
  facultyProfilesSnapshot.forEach(doc => {
    console.log(`Faculty ID: ${doc.id}, Name: ${doc.data().name}, Email: ${doc.data().email}`);
  });

  process.exit(0);
}

runAudit().catch(err => {
  console.error(err);
  process.exit(1);
});
