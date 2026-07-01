"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.worker = void 0;
const express_1 = __importDefault(require("express"));
const helmet_1 = __importDefault(require("helmet"));
const cors_1 = __importDefault(require("cors"));
const compression_1 = __importDefault(require("compression"));
const morgan_1 = __importDefault(require("morgan"));
const dotenv_1 = __importDefault(require("dotenv"));
const logger_1 = require("./utils/logger");
const outbox_worker_1 = require("./worker/outbox.worker");
const env_config_1 = require("./config/env.config");
const api_v1_routes_1 = __importDefault(require("./routes/api.v1.routes"));
dotenv_1.default.config();
require("./config/firebase"); // Ensure firebase is initialized
const app = (0, express_1.default)();
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)());
app.use((0, compression_1.default)());
app.use(express_1.default.json());
app.use((0, morgan_1.default)('combined', { stream: { write: message => logger_1.logger.info(message.trim()) } }));
exports.worker = new outbox_worker_1.OutboxWorker();
app.get('/', (req, res) => {
    res.json({
        service: "Schedly Notification API",
        version: env_config_1.AppConfig.VERSION,
        status: "running"
    });
});
app.use('/api/v1', api_v1_routes_1.default);
// Global Error Handler
app.use((err, req, res, next) => {
    logger_1.logger.error(JSON.stringify({
        event: 'unhandled_exception',
        status: 'ERROR',
        error: err.message,
        timestamp: new Date().toISOString()
    }));
    res.status(500).json({ error: 'Internal Server Error' });
});
exports.worker.start();
app.listen(env_config_1.AppConfig.PORT, () => {
    logger_1.logger.info(JSON.stringify({
        event: 'server_start',
        status: 'SUCCESS',
        port: env_config_1.AppConfig.PORT,
        timestamp: new Date().toISOString()
    }));
});
exports.default = app;
