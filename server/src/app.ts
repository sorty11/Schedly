import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { logger } from './utils/logger';
import { OutboxWorker } from './worker/outbox.worker';
import { AppConfig } from './config/env.config';
import apiV1Routes from './routes/api.v1.routes';

dotenv.config();
import './config/firebase'; // Ensure firebase is initialized

const app = express();

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

export const worker = new OutboxWorker();

app.get('/', (req, res) => {
  res.json({
    service: "Schedly Notification API",
    version: AppConfig.VERSION,
    status: "running"
  });
});

app.use('/api/v1', apiV1Routes);

// Global Error Handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error(JSON.stringify({
    event: 'unhandled_exception',
    status: 'ERROR',
    error: err.message,
    timestamp: new Date().toISOString()
  }));
  res.status(500).json({ error: 'Internal Server Error' });
});

try {
  console.log("Node:", process.version);
  console.log("firebase-admin:", require("firebase-admin/package.json").version);
  console.log("@google-cloud/firestore:", require("@google-cloud/firestore/package.json").version);
  console.log(require.resolve("@google-cloud/firestore"));
} catch (error: any) {
  console.error("Diagnostic error:");
  console.error(error.stack);
}

worker.start();

app.listen(AppConfig.PORT, () => {
  logger.info(JSON.stringify({
    event: 'server_start',
    status: 'SUCCESS',
    port: AppConfig.PORT,
    timestamp: new Date().toISOString()
  }));
});

export default app;
