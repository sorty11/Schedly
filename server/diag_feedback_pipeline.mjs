import { initializeApp } from "firebase/app";
import { getAuth, signInAnonymously } from "firebase/auth";
import { getFirestore, collection, doc, setDoc, getDoc, serverTimestamp } from "firebase/firestore";

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

async function runDiagnostic() {
    console.log("=== 1. Checking Render Production Health ===");
    const healthRes = await fetch("https://schedly-p61g.onrender.com/api/v1/health");
    console.log("Health Status Code:", healthRes.status);
    const healthJson = await healthRes.json();
    console.log("Health Body:", JSON.stringify(healthJson, null, 2));

    console.log("\n=== 2. Authenticating anonymously for testing ===");
    const userCred = await signInAnonymously(auth);
    const user = userCred.user;
    console.log("Authenticated UID:", user.uid);
    const idToken = await user.getIdToken();
    console.log("ID Token obtained: length", idToken.length);

    console.log("\n=== 3. Writing test feedback document to Firestore ===");
    const reportId = `fb_test_${user.uid}_${Date.now()}`;
    const testData = {
        id: reportId,
        type: 'bug',
        category: 'Diagnostics',
        title: 'Production Pipeline Verification Test',
        description: 'Automated diagnostic probe to verify SMTP/Render feedback pipeline.',
        name: 'Diagnostic Tester',
        email: 'sorty797@gmail.com',
        role: 'Student',
        section: 'SecondYear_CE_C',
        platform: 'TestScript',
        device: 'Node.js Probe',
        appVersion: '1.0.11+11',
        status: 'new',
        emailStatus: 'pending',
        emailAttempts: 0,
        timestamp: serverTimestamp(),
    };

    try {
        await setDoc(doc(db, "feedback", reportId), testData);
        console.log("Firestore Document Created Successfully:", reportId);
    } catch (e) {
        console.error("Firestore write failed:", e.message);
    }

    console.log("\n=== 4. Triggering POST /api/feedback/email on Render Production ===");
    const endpoint = "https://schedly-p61g.onrender.com/api/feedback/email";
    console.log("Calling endpoint:", endpoint);

    try {
        const response = await fetch(endpoint, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${idToken}`,
            },
            body: JSON.stringify({
                type: 'bug_report', // using legacy type key supported by current deployed version
                reportId: reportId,
                data: {
                    ...testData,
                    timestamp: new Date().toISOString(),
                }
            })
        });

        console.log("Render HTTP Status:", response.status, response.statusText);
        const text = await response.text();
        console.log("Render Response Body:", text);

        let parsed;
        try { parsed = JSON.parse(text); } catch (_) {}

    } catch (reqErr) {
        console.error("Request to Render failed:", reqErr.message);
    }

    console.log("\n=== 5. Re-checking Firestore Document State ===");
    try {
        // Read doc if allowed (client rules may forbid read; we will catch)
        const snap = await getDoc(doc(db, "feedback", reportId));
        if (snap.exists()) {
            console.log("Doc state in Firestore:", snap.data());
        }
    } catch (readErr) {
        console.log("Note: Client read rule is false by design (as expected per firestore.rules):", readErr.message);
    }
}

runDiagnostic()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });
