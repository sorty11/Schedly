"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FACULTY_MASTER_PASSWORD = exports.MASTER_PASSWORD = void 0;
const params_1 = require("firebase-functions/params");
exports.MASTER_PASSWORD = (0, params_1.defineSecret)('MASTER_PASSWORD');
exports.FACULTY_MASTER_PASSWORD = (0, params_1.defineSecret)('FACULTY_MASTER_PASSWORD');
//# sourceMappingURL=config.js.map