import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import dns from 'dns';
import { logger } from './utils/logger';
import { OutboxWorker } from './worker/outbox.worker';
import { TokenWorker } from './worker/token.worker';
import { AppConfig } from './config/env.config';
import apiV1Routes from './routes/api.v1.routes';
import feedbackRoutes from './routes/feedback';
import gamificationRoutes from './routes/gamification.routes';
import { ChampionWorker } from './worker/champion.worker';

if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first');
}

dotenv.config();
import './config/firebase'; // Ensure firebase is initialized

const app = express();

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

export const worker = new OutboxWorker();
export const tokenWorker = new TokenWorker();
export const championWorker = new ChampionWorker();

app.get('/', (req, res) => {
  res.json({
    service: "Schedly Notification API",
    version: AppConfig.VERSION,
    status: "running"
  });
});

app.use('/api/v1', apiV1Routes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api/gamification', gamificationRoutes);

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

worker.start();
tokenWorker.start();
championWorker.start();

app.listen(AppConfig.PORT, () => {
  logger.info(JSON.stringify({
    event: 'server_start',
    status: 'SUCCESS',
    port: AppConfig.PORT,
    timestamp: new Date().toISOString()
  }));
});

export default app;
