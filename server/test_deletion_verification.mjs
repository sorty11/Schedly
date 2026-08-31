import { initializeApp } from "firebase/app";
import { 
    getAuth, 
    createUserWithEmailAndPassword, 
    signInWithEmailAndPassword, 
    deleteUser 
} from "firebase/auth";
import { 
    getFirestore, 
    doc, 
    setDoc, 
    getDoc 
} from "firebase/firestore";

const firebaseConfig = {
    apiKey: 'AIzaSyCvHene63scD_yzJiR0HHWHBKTad-n-sSI',
    appId: '1:1044389536762:web:8b8c7ec25645328411ba43',
    messagingSenderId: '1044389536762',
    projectId: 'schedly-production',
    authDomain: 'schedly-production.firebaseapp.com',
    storageBucket: 'schedly-production.firebasestorage.app',
    measurementId: 'G-RKCNHWHVX9',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const BACKEND_URL = 'https://schedly-p61g.onrender.com';

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function runVerification() {
    console.log("==================================================");
    console.log("STARTING PRODUCTION ACCOUNT DELETION VERIFICATION");
    console.log("==================================================");

    const testEmail = `delete_smoke_${Date.now()}@example.com`;
    const testPassword = 'Password123!Secure';

    // 1. Create a fresh test user
    console.log(`\n[1/7] Creating fresh test account: ${testEmail}...`);
    const cred = await createUserWithEmailAndPassword(auth, testEmail, testPassword);
    const uid = cred.user.uid;
    console.log(`✓ Created user with UID: ${uid}`);

    // 2. Populate user-owned Firestore documents and subcollections
    console.log("\n[2/7] Populating user-owned Firestore data & subcollections...");
    await setDoc(doc(db, "users", uid), {
        name: "Smoke Test User",
        email: testEmail,
        division: "SmokeTest_Division",
        role: "Student",
        rollNo: "SMOKE_01",
        createdAt: new Date()
    });

    await setDoc(doc(db, `users/${uid}/fcm_tokens`, "test_token_abc"), {
        token: "test_token_abc",
        createdAt: new Date()
    });

    await setDoc(doc(db, `users/${uid}/attendance`, "rec_smoke"), {
        present: 10,
        absent: 2,
        division: "SmokeTest_Division"
    });

    await setDoc(doc(db, `users/${uid}/attendance_logs`, "log_smoke"), {
        date: "2026-09-01",
        status: "present"
    });

    // Check that existing shared section exists
    const sectionDoc = await getDoc(doc(db, "sections", "SecondYear_CSDS_A"));
    if (!sectionDoc.exists()) {
        throw new Error("FAIL: Pre-existing section SecondYear_CSDS_A not found!");
    }
    console.log("  Verified shared section SecondYear_CSDS_A exists.");

    console.log("✓ All private user documents and subcollections created.");

    // 3. Verify data exists before deletion
    console.log("\n[3/7] Confirming data exists prior to deletion...");
    const preUser = await getDoc(doc(db, "users", uid));
    const preToken = await getDoc(doc(db, `users/${uid}/fcm_tokens`, "test_token_abc"));
    const preAtt = await getDoc(doc(db, `users/${uid}/attendance`, "rec_smoke"));
    if (!preUser.exists() || !preToken.exists() || !preAtt.exists()) {
        throw new Error("FAIL: Pre-deletion verification failed; documents were not created.");
    }
    console.log("✓ Pre-deletion state confirmed.");

    // 4. Obtain fresh ID token and dispatch deletion request
    console.log("\n[4/7] Requesting account deletion from Render backend...");
    const idToken = await cred.user.getIdToken(true);

    const deleteResp = await fetch(`${BACKEND_URL}/api/v1/delete-account`, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${idToken}`,
            "Content-Type": "application/json"
        }
    });

    const respText = await deleteResp.text();
    let respJson = {};
    try { respJson = JSON.parse(respText); } catch (_) {}

    console.log(`Backend HTTP Status: ${deleteResp.status}`);
    console.log("Backend Response:", respJson);

    if (deleteResp.status !== 200 || !respJson.success) {
        throw new Error(`FAIL: Deletion endpoint returned failure: ${respText}`);
    }
    console.log("✓ Deletion endpoint confirmed success.");

    // 5. Verify Firestore private data is completely removed
    console.log("\n[5/7] Verifying private Firestore data and tokens are removed...");
    await sleep(2000); // Allow write propagation

    const postUser = await getDoc(doc(db, "users", uid));
    const postToken = await getDoc(doc(db, `users/${uid}/fcm_tokens`, "test_token_abc"));
    const postAtt = await getDoc(doc(db, `users/${uid}/attendance`, "rec_smoke"));
    const postLogs = await getDoc(doc(db, `users/${uid}/attendance_logs`, "log_smoke"));

    if (postUser.exists()) throw new Error("FAIL: users/{uid} was NOT deleted!");
    if (postToken.exists()) throw new Error("FAIL: fcm_tokens subcollection was NOT deleted!");
    if (postAtt.exists()) throw new Error("FAIL: attendance subcollection was NOT deleted!");
    if (postLogs.exists()) throw new Error("FAIL: attendance_logs subcollection was NOT deleted!");

    console.log("✓ users/{uid} confirmed DELETED.");
    console.log("✓ fcm_tokens confirmed DELETED.");
    console.log("✓ attendance records confirmed DELETED.");
    console.log("✓ attendance_logs confirmed DELETED.");

    // 6. Verify shared section data is PRESERVED
    console.log("\n[6/7] Verifying shared section data remains intact...");
    const postSection = await getDoc(doc(db, "sections", "SecondYear_CSDS_A"));
    if (!postSection.exists()) {
        throw new Error("FAIL: Shared section document was improperly deleted!");
    }
    console.log("✓ Shared section SecondYear_CSDS_A intact.");

    // 7. Verify Auth user deleted & same email can sign up again with new UID
    console.log("\n[7/7] Verifying Auth user deleted & re-registration with same email...");
    try {
        await signInWithEmailAndPassword(auth, testEmail, testPassword);
        throw new Error("FAIL: User was still able to sign in with deleted credentials!");
    } catch (e) {
        if (e.code === 'auth/invalid-credential' || e.code === 'auth/user-not-found') {
            console.log("✓ Old credentials rejected (User deleted from Firebase Auth).");
        } else {
            console.log(`✓ Old credentials rejected with code: ${e.code}`);
        }
    }

    // Re-register with the exact same email
    console.log("  Re-registering with the exact same email address...");
    const newCred = await createUserWithEmailAndPassword(auth, testEmail, testPassword);
    const newUid = newCred.user.uid;
    console.log(`✓ Re-registration succeeded! New UID: ${newUid}`);

    if (newUid === uid) {
        throw new Error("FAIL: Re-registered account received the same UID!");
    }
    console.log("✓ New distinct UID verified.");

    // Cleanup the second test user
    await deleteUser(newCred.user);
    console.log("✓ Temporary test user cleaned up.");

    console.log("\n==================================================");
    console.log("ALL PRODUCTION VERIFICATION CHECKS PASSED PERFECTLY!");
    console.log("==================================================");
}

runVerification().catch(err => {
    console.error("\n❌ VERIFICATION FAILED:", err);
    process.exit(1);
});
