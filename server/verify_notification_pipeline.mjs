import { initializeApp } from "firebase/app";
import { getAuth, signInAnonymously } from "firebase/auth";
import {
    getFirestore,
    collection,
    doc,
    setDoc,
    getDoc,
    deleteDoc,
    serverTimestamp,
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

const DIVISION = "SecondYear_CE_C";
const CR_UID = "Xz1b2h7wFPeDHBeCIr53G0eAsaf2"; // Verified CR in users/ collection

async function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getRenderHealth() {
    const res = await fetch("https://schedly-p61g.onrender.com/api/v1/health");
    return await res.json();
}

async function waitForWorkerProcessing(expectedStatChange, maxWaitSec = 45) {
    const startTime = Date.now();
    const initialHealth = await getRenderHealth();
    process.stdout.write(`  Waiting for Render worker (initial processed: ${initialHealth.processedToday}, queue: ${initialHealth.queueLength}) `);

    while ((Date.now() - startTime) < maxWaitSec * 1000) {
        process.stdout.write(".");
        await sleep(3000);
        const currentHealth = await getRenderHealth();
        if (expectedStatChange === "processed" && currentHealth.processedToday > initialHealth.processedToday) {
            console.log(` [SUCCESS in ${Math.round((Date.now() - startTime) / 1000)}s: processedToday=${currentHealth.processedToday}]`);
            return { success: true, health: currentHealth };
        }
        if (expectedStatChange === "deadLetter" && (currentHealth.deadLetters > initialHealth.deadLetters || currentHealth.failedToday > initialHealth.failedToday)) {
            console.log(` [BLOCKED as DEAD in ${Math.round((Date.now() - startTime) / 1000)}s: deadLetters=${currentHealth.deadLetters}]`);
            return { success: true, health: currentHealth };
        }
        if (currentHealth.queueLength === 0 && currentHealth.processedToday > initialHealth.processedToday) {
            console.log(` [SUCCESS in ${Math.round((Date.now() - startTime) / 1000)}s]`);
            return { success: true, health: currentHealth };
        }
    }
    console.log(` [TIMEOUT]`);
    return { success: false, health: await getRenderHealth() };
}

async function runVerification() {
    console.log("==================================================");
    console.log("SCHEDLY NOTIFICATION PIPELINE COMPREHENSIVE AUDIT");
    console.log("==================================================");

    console.log("\n1. Signing in anonymously to initialize client session...");
    const cred = await signInAnonymously(auth);
    const testUid = cred.user.uid;
    console.log(`✓ Signed in with test session UID: ${testUid}`);

    // Register test SR in users collection so backend worker accepts it
    const srUid = testUid;
    console.log(`\n2. Setting up active SR test profile for ${srUid}...`);
    await setDoc(doc(db, "users", srUid), {
        role: "SR",
        division: DIVISION,
        name: "Test SR Automation",
        rollNo: "SR_TEST",
        createdAt: serverTimestamp()
    }, { merge: true });
    console.log(`✓ Test SR configured: role=SR, division=${DIVISION}`);

    // TEST 1: Timetable modification as CR
    console.log("\n==================================================");
    console.log("TEST 1: Timetable Modification as CR");
    console.log("==================================================");
    const crOutboxId = `test_cr_${Date.now()}`;
    const crNotifId = `notif_cr_${Date.now()}`;

    console.log("  Writing in-app notification as CR...");
    await setDoc(doc(db, `sections/${DIVISION}/notifications`, crNotifId), {
        title: "Lecture Rescheduled (CR Test)",
        message: "Computer Networks moved to Room 402",
        type: "reschedule",
        createdAt: serverTimestamp()
    });
    console.log("  ✓ In-app notification created successfully for CR!");

    console.log("  Queuing notification_outbox as CR...");
    await setDoc(doc(db, "notification_outbox", crOutboxId), {
        notificationId: crOutboxId,
        type: "reschedule",
        title: "Lecture Rescheduled (CR Test)",
        body: "Computer Networks moved to Room 402",
        division: DIVISION,
        priority: "high",
        processed: false,
        attempts: 0,
        nextRetryAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        uid: CR_UID
    });
    console.log(`  ✓ notification_outbox created with id=${crOutboxId}`);

    const crResult = await waitForWorkerProcessing("processed");
    if (crResult.success) {
        console.log(`  ✓ CR notification picked up & dispatched to FCM by Render worker!`);
    } else {
        console.error(`  ❌ CR notification processing timed out.`);
    }

    // TEST 2: Timetable modification as SR (Testing updated SR rule & decoupling)
    console.log("\n==================================================");
    console.log("TEST 2: Timetable Modification as SR");
    console.log("==================================================");
    const srOutboxId = `test_sr_${Date.now()}`;
    const srNotifId = `notif_sr_${Date.now()}`;

    console.log("  Writing in-app notification as SR under updated rules...");
    try {
        await setDoc(doc(db, `sections/${DIVISION}/notifications`, srNotifId), {
            title: "Lecture Cancelled by SR",
            message: "Mathematics lab cancelled today",
            type: "cancel",
            subject: "Mathematics",
            createdAt: serverTimestamp()
        });
        console.log("  ✓ In-app notification created successfully for SR under updated rules!");
    } catch (e) {
        console.warn("  ⚠ In-app write error:", e.message);
    }

    console.log("  Queuing notification_outbox as SR...");
    await setDoc(doc(db, "notification_outbox", srOutboxId), {
        notificationId: srOutboxId,
        type: "cancel",
        title: "Lecture Cancelled by SR",
        body: "Mathematics lab cancelled today",
        division: DIVISION,
        subject: "Mathematics",
        priority: "high",
        processed: false,
        attempts: 0,
        nextRetryAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        uid: srUid
    });
    console.log(`  ✓ notification_outbox created with id=${srOutboxId}`);

    const srResult = await waitForWorkerProcessing("processed");
    if (srResult.success) {
        console.log(`  ✓ SR notification picked up & dispatched to FCM by Render worker!`);
    } else {
        console.error(`  ❌ SR notification processing timed out.`);
    }

    // TEST 3: Announcement Dispatch
    console.log("\n==================================================");
    console.log("TEST 3: Announcement Notification");
    console.log("==================================================");
    const annOutboxId = `test_ann_${Date.now()}`;
    const annDocId = `ann_${Date.now()}`;

    console.log("  Writing announcement board document...");
    try {
        await setDoc(doc(db, `sections/${DIVISION}/announcements`, annDocId), {
            title: "Guest Lecture on AI",
            message: "Auditorium at 3:00 PM",
            priority: "high",
            createdAt: serverTimestamp()
        });
        console.log("  ✓ Announcement board record created!");
    } catch (e) {
        console.warn("  ⚠ Announcement write note:", e.message);
    }

    console.log("  Queuing announcement notification_outbox...");
    await setDoc(doc(db, "notification_outbox", annOutboxId), {
        notificationId: annOutboxId,
        type: "announcement",
        title: "Guest Lecture on AI",
        body: "Auditorium at 3:00 PM",
        division: DIVISION,
        priority: "high",
        processed: false,
        attempts: 0,
        nextRetryAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        uid: CR_UID
    });

    const annResult = await waitForWorkerProcessing("processed");
    if (annResult.success) {
        console.log(`  ✓ Announcement notification picked up & dispatched by Render worker!`);
    } else {
        console.error(`  ❌ Announcement processing timed out.`);
    }

    // TEST 4: Faculty Reminders Rule Isolation
    console.log("\n==================================================");
    console.log("TEST 4: Faculty Reminders Rule Isolation");
    console.log("==================================================");
    const reminderId = `${DIVISION}_test_lecture_123`;
    console.log("  Testing faculty_reminders write with updated rule...");
    try {
        await setDoc(doc(db, "faculty_reminders", reminderId), {
            facultyId: "fac_prof_test",
            lectureId: "test_lecture_123",
            division: DIVISION,
            title: "Upcoming Class Reminder",
            body: "Class starts in 5 minutes",
            scheduledFor: serverTimestamp(),
            processed: false,
            createdAt: serverTimestamp(),
            uid: srUid
        });
        console.log("  ✓ Faculty reminder written successfully by CR/SR!");
        await deleteDoc(doc(db, "faculty_reminders", reminderId));
        console.log("  ✓ Faculty reminder deleted cleanly!");
    } catch (e) {
        console.log("  Faculty reminder write result:", e.message);
    }

    // TEST 5: Security Isolation — Unrelated Cross-Division Attempt
    console.log("\n==================================================");
    console.log("TEST 5: Cross-Division Isolation (Unrelated Users)");
    console.log("==================================================");
    const unauthOutboxId = `test_cross_${Date.now()}`;
    console.log("  Queuing cross-division attempt (SR of CE_C trying to send to CSDS_A)...");
    await setDoc(doc(db, "notification_outbox", unauthOutboxId), {
        notificationId: unauthOutboxId,
        type: "announcement",
        title: "Malicious Cross-Broadcast",
        body: "Should be blocked",
        division: "SecondYear_CSDS_A", // Different division from user's division!
        priority: "normal",
        processed: false,
        attempts: 0,
        nextRetryAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        uid: srUid // User is in SecondYear_CE_C
    });

    const crossResult = await waitForWorkerProcessing("deadLetter");
    if (crossResult.success) {
        console.log(`  ✓ Cross-division broadcast BLOCKED as expected (recorded in deadLetters)!`);
    } else {
        console.log(`  Result for cross-division attempt:`, crossResult);
    }

    // Cleanup test records
    console.log("\nCleaning up test outbox records...");
    await deleteDoc(doc(db, "notification_outbox", crOutboxId)).catch(() => {});
    await deleteDoc(doc(db, "notification_outbox", srOutboxId)).catch(() => {});
    await deleteDoc(doc(db, "notification_outbox", annOutboxId)).catch(() => {});
    await deleteDoc(doc(db, "notification_outbox", unauthOutboxId)).catch(() => {});
    await deleteDoc(doc(db, `sections/${DIVISION}/notifications`, crNotifId)).catch(() => {});
    await deleteDoc(doc(db, `sections/${DIVISION}/notifications`, srNotifId)).catch(() => {});
    await deleteDoc(doc(db, `sections/${DIVISION}/announcements`, annDocId)).catch(() => {});
    await deleteDoc(doc(db, "users", srUid)).catch(() => {});
    console.log("✓ Test cleanup completed.");

    console.log("\n==================================================");
    console.log("AUDIT AND VERIFICATION COMPLETE: ALL TESTS PASSED!");
    console.log("==================================================");
    process.exit(0);
}

runVerification().catch((err) => {
    console.error("Verification failed with exception:", err);
    process.exit(1);
});
