"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificationRateLimiter = void 0;
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const logger_1 = require("../utils/logger");
exports.notificationRateLimiter = (0, express_rate_limit_1.default)({
    windowMs: 1 * 60 * 1000, // 1 minute
    max: 10, // Limit each IP to 10 notification requests per minute
    message: { error: 'Too many requests, please try again later.' },
    handler: (req, res, next, options) => {
        logger_1.logger.warn('Rate limit exceeded', { ip: req.ip });
        res.status(options.statusCode).send(options.message);
    }
});
