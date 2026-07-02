"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onTokenWritten = exports.onNotificationCreated = exports.onAnnouncementCreated = void 0;
const admin = require("firebase-admin");
admin.initializeApp();
var announcement_trigger_1 = require("./notifications/announcement_trigger");
Object.defineProperty(exports, "onAnnouncementCreated", { enumerable: true, get: function () { return announcement_trigger_1.onAnnouncementCreated; } });
var lecture_trigger_1 = require("./notifications/lecture_trigger");
Object.defineProperty(exports, "onNotificationCreated", { enumerable: true, get: function () { return lecture_trigger_1.onNotificationCreated; } });
var token_trigger_1 = require("./notifications/token_trigger");
Object.defineProperty(exports, "onTokenWritten", { enumerable: true, get: function () { return token_trigger_1.onTokenWritten; } });
//# sourceMappingURL=index.js.map