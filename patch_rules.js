const fs = require('fs');
let rules = fs.readFileSync('firestore.rules', 'utf8');

const newRule = `
    // FUNCTION: Check if user is CR or SR
    function isCRorSR() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['CR', 'SR'];
    }

    // OUTBOX FOR RENDER WORKER
    match /notification_outbox/{docId} {
      allow read: if false; // Only backend admin can read
      allow create: if request.auth != null && isCRorSR();
      allow update, delete: if false; // Only backend admin can update/delete
    }
`;

if (!rules.includes('notification_outbox')) {
  rules = rules.replace(
    "    // TIMETABLES",
    newRule + "\n    // TIMETABLES"
  );
  fs.writeFileSync('firestore.rules', rules);
  console.log('Patched firestore.rules');
}
