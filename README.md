# Schedly

Schedly is a college timetable and announcement management application.

## V1.0.1 Architecture
Schedly uses a **Transactional Outbox Pattern** to ensure reliable delivery of Push Notifications.

1. **Flutter App**: Writes data (Timetable/Announcement) AND a `notification_outbox` document in a single atomic `WriteBatch`.
2. **Firestore**: Persists the batch safely.
3. **Render Node.js Backend**: An adaptive polling worker (`OutboxWorker`) monitors the outbox.
4. **FCM Topics**: The backend dispatches the payload to FCM Topics (e.g., `division_A`, `batch_A1_A`, `role_CR_A`) using the Firebase Admin SDK.

*Note: Schedly broadcasts using FCM Topics, completely bypassing individual token tracking for college-wide alerts. Device tokens are only stored for future direct messaging purposes.*

## Security
- Flutter clients cannot trigger notifications directly.
- Firestore Security Rules restrict `notification_outbox` writes to Class Representatives (CR) and Student Representatives (SR).
- The Render backend additionally validates the user's role against the `/users` collection before sending any FCM message.

## Setup
Refer to `DEPLOYMENT.md` for production deployment instructions.
