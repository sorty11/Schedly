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

export const sectionCreateRateLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 5, // 5 failed attempts
  skipSuccessfulRequests: true, // Only count failed attempts towards the limit
  message: { error: 'Too many failed creation attempts. Please try again later.' },
  handler: (req, res, next, options) => {
    logger.warn('Section creation rate limit exceeded', { ip: req.ip });
    res.status(options.statusCode).send(options.message);
  }
});
