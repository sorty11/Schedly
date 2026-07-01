"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sanitizeTopic = sanitizeTopic;
function sanitizeTopic(topic) {
    return topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
}
//# sourceMappingURL=index.js.map