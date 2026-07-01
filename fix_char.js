const fs = require('fs');

let authCode = fs.readFileSync('server/src/middleware/auth.middleware.ts', 'utf8');
authCode = authCode.replace(/\\\\n/g, '\\n');
fs.writeFileSync('server/src/middleware/auth.middleware.ts', authCode);

console.log('Fixed auth.middleware.ts invalid char');
