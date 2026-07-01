"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTargetTopic = getTargetTopic;
const utils_1 = require("../utils");
function getTargetTopic(division, batch, role) {
    if (role && role !== 'student') {
        return `${role}_${(0, utils_1.sanitizeTopic)(division)}`;
    }
    if (batch) {
        return `batch_${(0, utils_1.sanitizeTopic)(batch)}_${(0, utils_1.sanitizeTopic)(division)}`;
    }
    return `division_${(0, utils_1.sanitizeTopic)(division)}`;
}
//# sourceMappingURL=topic_manager.js.map