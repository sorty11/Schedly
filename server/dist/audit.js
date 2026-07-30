"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const admin = __importStar(require("firebase-admin"));
require("./config/firebase");
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
