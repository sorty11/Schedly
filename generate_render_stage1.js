const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const serverDir = path.join(__dirname, 'server');
if (!fs.existsSync(serverDir)) {
  fs.mkdirSync(serverDir);
}

const packageJson = {
  "name": "schedly-backend",
  "version": "1.0.0",
  "description": "Render-hosted backend for Schedly notifications",
  "main": "dist/app.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/app.js",
    "dev": "ts-node-dev --respawn --transpile-only src/app.ts"
  },
  "engines": {
    "node": ">=20.0.0"
  },
  "dependencies": {
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "firebase-admin": "^12.1.0",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "winston": "^3.13.0"
  },
  "devDependencies": {
    "@types/compression": "^1.7.5",
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/morgan": "^1.9.9",
    "@types/node": "^20.12.11",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.4.5"
  }
};
fs.writeFileSync(path.join(serverDir, 'package.json'), JSON.stringify(packageJson, null, 2));

const tsconfig = {
  "compilerOptions": {
    "target": "es2022",
    "module": "commonjs",
    "rootDir": "./src",
    "outDir": "./dist",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"]
};
fs.writeFileSync(path.join(serverDir, 'tsconfig.json'), JSON.stringify(tsconfig, null, 2));

const srcDir = path.join(serverDir, 'src');
if (!fs.existsSync(srcDir)) fs.mkdirSync(srcDir);

const dirs = ['routes', 'services', 'notifications', 'middleware', 'types', 'utils', 'config'];
dirs.forEach(d => {
  const p = path.join(srcDir, d);
  if (!fs.existsSync(p)) fs.mkdirSync(p);
});

const appTsCode = `import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { logger } from './utils/logger';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Schedly Backend Running' });
});

app.listen(PORT, () => {
  logger.info(\`Server is running on port \${PORT}\`);
});

export default app;
`;
fs.writeFileSync(path.join(srcDir, 'app.ts'), appTsCode);

const loggerTsCode = `import winston from 'winston';

export const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});
`;
fs.writeFileSync(path.join(srcDir, 'utils', 'logger.ts'), loggerTsCode);

const firebaseConfigCode = `import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';
import dotenv from 'dotenv';

dotenv.config();

export function initFirebase() {
  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      logger.info('Firebase Admin initialized with provided service account.');
    } else {
      // Fallback for local development or default credentials
      admin.initializeApp();
      logger.info('Firebase Admin initialized with default credentials.');
    }
  } catch (error) {
    logger.error('Failed to initialize Firebase Admin', { error });
  }
}

// Call it to initialize when this file is imported
initFirebase();
`;
fs.writeFileSync(path.join(srcDir, 'config', 'firebase.ts'), firebaseConfigCode);

console.log('Stage 1 files generated in /server.');
