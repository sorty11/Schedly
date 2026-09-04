# Schedly Notification & Feedback Backend

Render-hosted backend for Schedly handling push notifications, faculty reminders, and user feedback dispatch.

## Architecture

### 1. Feedback Submission Pipeline
1. **Client Submission**: Flutter app creates a document under root collection `/feedback/{docId}` with `emailStatus: 'pending'`.
2. **Immediate Dispatch**: Client invokes `POST /api/feedback/email` with Firebase ID token.
3. **Concurrency Lock**: Backend claims the document atomically in a Firestore transaction (`emailStatus: 'processing'`, 2-minute lock TTL) to prevent duplicate emails across concurrent requests.
4. **Nodemailer Delivery**: Backend formats rich HTML and dispatches the email to `sorty797@gmail.com` using IPv4 (`family: 4`, `service: 'gmail'`).
5. **Background Retry Worker**: `OutboxWorker.processPendingFeedbackEmails()` polls every 30s for any `pending` or eligible `failed` documents (exponential backoff up to 5 attempts).

### 2. Required Firestore Composite Indexes
The worker requires the following composite index in `firestore.indexes.json`:
```json
{
  "collectionGroup": "feedback",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "emailStatus", "order": "ASCENDING" },
    { "fieldPath": "nextRetryAt", "order": "ASCENDING" },
    { "fieldPath": "__name__", "order": "ASCENDING" }
  ]
}
```

### 3. Environment Variables (Render Dashboard)
| Variable | Description | Example |
| :--- | :--- | :--- |
| `SMTP_USER` | Sending Gmail address | `sorty797@gmail.com` |
| `SMTP_PASS` | 16-character Google App Password | `abcd efgh ijkl mnop` |
| `SMTP_HOST` | *(Optional)* SMTP host fallback | `smtp.gmail.com` |
| `SMTP_PORT` | *(Optional)* Port (`587` or `465`) | `587` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase service account credentials | `{...}` |

### 4. Health & Verification Endpoints
- `GET /api/v1/health` - Reports uptime, worker status, and `smtpConfigured`.
- `GET /api/feedback/diag` - Authenticated test endpoint that runs SMTP `transporter.verify()`.
- `POST /api/feedback/email` - Dispatches feedback email for a given report ID.
