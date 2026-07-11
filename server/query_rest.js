const fetch = require('node-fetch');

(async () => {
  try {
    console.log('--- PROVING FACULTY REMINDER ROLE MISMATCH ---');
    const p = 'schedly-production';
    const baseUrl = `https://firestore.googleapis.com/v1/projects/${p}/databases/(default)/documents`;
    
    // 6. Firestore users/{uid}.role
    const uRes = await fetch(baseUrl + '/users');
    const uData = await uRes.json();
    uData.documents.forEach(doc => {
      const role = doc.fields.role?.stringValue;
      if (role === 'faculty' || role === 'FACULTY') {
        console.log(`6. users (${doc.name.split('/').pop()}) -> role: ${role}`);
      }
    });
    
    // 2. faculty_profiles
    const fpRes = await fetch(baseUrl + '/faculty_profiles');
    const fpData = await fpRes.json();
    fpData.documents.forEach(doc => {
      console.log(`2. faculty_profiles ID: ${doc.name.split('/').pop()} (Name: ${doc.fields.name?.stringValue})`);
    });

    // 4. outbox
    const oRes = await fetch(baseUrl + '/notification_outbox');
    const oData = await oRes.json();
    if (oData.documents) {
        oData.documents.forEach(doc => {
          const type = doc.fields.type?.stringValue;
          const role = doc.fields.role?.stringValue;
          if (role === 'faculty' || type === 'faculty_reminder' || type === 'lecture_added') {
            console.log(`4. Outbox (${doc.name.split('/').pop()}) -> division: ${doc.fields.division?.stringValue}, type: ${type}`);
          }
        });
    }

  } catch(e) { console.error(e.message); }
})();
