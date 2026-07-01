"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const router = (0, express_1.Router)();
// Endpoint solely to wake up the worker
// We protect it with verifyIdToken so random internet scans don't keep it awake unnecessarily
// But we don't enforce CR/SR here since the outbox worker does the actual authorization
router.get('/wake', auth_middleware_1.verifyIdToken, (req, res) => {
    res.status(200).json({ message: 'Worker is awake' });
});
exports.default = router;
