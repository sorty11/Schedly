const fs = require('fs');
const path = require('path');

function ensureDirSync(dirpath) {
  if (!fs.existsSync(dirpath)) {
    fs.mkdirSync(dirpath, { recursive: true });
  }
}

// 1. Update firebase.json
const firebaseJsonPath = path.join(__dirname, 'firebase.json');
let firebaseJson = {};
if (fs.existsSync(firebaseJsonPath)) {
  firebaseJson = JSON.parse(fs.readFileSync(firebaseJsonPath, 'utf8'));
}
firebaseJson.functions = {
  source: "functions",
  predeploy: [
    "npm --prefix \"%RESOURCE_DIR%\" run build"
  ]
};
fs.writeFileSync(firebaseJsonPath, JSON.stringify(firebaseJson, null, 2));

// 2. Scaffold directories
const functionsDir = path.join(__dirname, 'functions');
ensureDirSync(functionsDir);
ensureDirSync(path.join(functionsDir, 'src', 'notifications'));
ensureDirSync(path.join(functionsDir, 'src', 'utils'));
ensureDirSync(path.join(functionsDir, 'src', 'types'));

// 3. Create package.json
const packageJson = {
  "name": "functions",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "firebase-functions-test": "^3.1.0"
  },
  "private": true
};
fs.writeFileSync(path.join(functionsDir, 'package.json'), JSON.stringify(packageJson, null, 2));

// 4. Create tsconfig.json
const tsconfig = {
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2021"
  },
  "compileOnSave": true,
  "include": [
    "src"
  ]
};
fs.writeFileSync(path.join(functionsDir, 'tsconfig.json'), JSON.stringify(tsconfig, null, 2));

// 5. Create empty ts files
fs.writeFileSync(path.join(functionsDir, 'src', 'index.ts'), `// import * as admin from 'firebase-admin';
// admin.initializeApp();

// Export triggers below once implemented
`);

fs.writeFileSync(path.join(functionsDir, 'src', 'notifications', 'announcement_trigger.ts'), `// Announcement Trigger implementation goes here
`);
fs.writeFileSync(path.join(functionsDir, 'src', 'notifications', 'lecture_trigger.ts'), `// Lecture Trigger implementation goes here
`);
fs.writeFileSync(path.join(functionsDir, 'src', 'notifications', 'notification_sender.ts'), `// FCM payload builder and sender goes here
`);
fs.writeFileSync(path.join(functionsDir, 'src', 'notifications', 'topic_manager.ts'), `// FCM Topic management tools go here
`);
fs.writeFileSync(path.join(functionsDir, 'src', 'utils', 'index.ts'), `// Utility functions go here
`);
fs.writeFileSync(path.join(functionsDir, 'src', 'types', 'index.ts'), `// TypeScript types/interfaces go here
`);

console.log('Scaffolded Cloud Functions');
