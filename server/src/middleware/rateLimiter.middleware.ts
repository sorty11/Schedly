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

export const gamificationRateLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 15, // Max 15 gamification requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many gamification requests. Please try again later.' },
  handler: (req, res, next, options) => {
    logger.warn('Gamification rate limit exceeded', { ip: req.ip, path: req.path });
    res.status(options.statusCode).json(options.message);
  }
});

export const feedbackRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Max 10 feedback submissions per 15 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many feedback submissions. Please wait before submitting again.' },
  handler: (req, res, next, options) => {
    logger.warn('Feedback submission rate limit exceeded', { ip: req.ip });
    res.status(options.statusCode).json(options.message);
  }
});

