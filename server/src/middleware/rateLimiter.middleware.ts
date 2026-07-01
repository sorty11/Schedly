import rateLimit from 'express-rate-limit';
import { logger } from '../utils/logger';

export const notificationRateLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 10, // Limit each IP to 10 notification requests per minute
  message: { error: 'Too many requests, please try again later.' },
  handler: (req, res, next, options) => {
    logger.warn('Rate limit exceeded', { ip: req.ip });
    res.status(options.statusCode).send(options.message);
  }
});
