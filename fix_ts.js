const fs = require('fs');

// 1. Fix auth.middleware.ts
let authCode = fs.readFileSync('server/src/middleware/auth.middleware.ts', 'utf8');

const verifyTokenFn = `
export const verifyIdToken = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Unauthorized: Missing or invalid Bearer token');
    res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    return;
  }

  const token = authHeader.split('Bearer ')[1];
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    logger.error('Token verification failed', { error });
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
    return;
  }
};
`;

if (!authCode.includes('export const verifyIdToken')) {
  authCode += '\\n' + verifyTokenFn;
  fs.writeFileSync('server/src/middleware/auth.middleware.ts', authCode);
}

// 2. Fix outbox.worker.ts
let workerCode = fs.readFileSync('server/src/worker/outbox.worker.ts', 'utf8');
workerCode = workerCode.replace(
  "import { NotificationService } from '../notifications/notification.service';",
  "import { dispatchNotification } from '../notifications/notification.service';"
);
workerCode = workerCode.replace(
  "await NotificationService.sendNotification(data as any);",
  "await dispatchNotification(data as any, uid, 'SYSTEM');"
);
fs.writeFileSync('server/src/worker/outbox.worker.ts', workerCode);

console.log('Fixed typescript errors');
