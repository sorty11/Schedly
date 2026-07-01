"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WorkerConfig = exports.AppConfig = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
exports.AppConfig = {
    VERSION: process.env.APP_VERSION || '1.0.1',
    PORT: process.env.PORT || 3000,
};
exports.WorkerConfig = {
    FAST_INTERVAL_MS: parseInt(process.env.WORKER_FAST_INTERVAL_MS || '5000', 10),
    IDLE_INTERVAL_MS: parseInt(process.env.WORKER_IDLE_INTERVAL_MS || '30000', 10),
    MAX_RETRY_COUNT: parseInt(process.env.MAX_RETRY_COUNT || '5', 10),
    MAX_BACKOFF_SECONDS: parseInt(process.env.MAX_BACKOFF_SECONDS || '64', 10),
    OUTBOX_RETENTION_DAYS: parseInt(process.env.OUTBOX_RETENTION_DAYS || '7', 10),
};
