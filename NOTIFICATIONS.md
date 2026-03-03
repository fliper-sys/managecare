# Push Notifications (FCM) — Overview and Setup

This project now supports push notifications for sales/payment confirmations.

## Client-side (Flutter)
1. Ensure `firebase_messaging` is added (it's already in `pubspec.yaml`).
2. Initialization:
   - `PushService.initialize()` is called on app startup for authenticated users.
   - `PushService` requests permissions, registers `onMessage`, `onMessageOpenedApp`, and background handler.
3. Token management:
   - Device FCM tokens are saved under `users/{uid}/fcmTokens/{token}` with metadata.
   - On logout, the token will be removed.
4. Foreground notifications:
   - `PushService` forwards foreground messages to `NotificationService` which shows local notifications.
5. User opt-in:
   - `NotificationPreferencesScreen` includes `Push Notifications` toggle which writes `pushEnabled` to user's Firestore doc.
6. Manage devices:
   - `ManageDevicesScreen` lets owners view and revoke registered devices.

## Server-side (Cloud Functions)
Two Cloud Functions are included under `functions/`:

- `onPaymentTransactionCreate`: triggers when a `payment_transactions` document is created. If the transaction status is `success` or `completed` this function fetches the business owners' `fcmTokens` and sends an FCM notification. It respects `users/{uid}.pushEnabled`.

- `onNotificationCreate`: triggers when an admin creates a `notifications/{id}` doc and dispatches it to listed `targetUsers`.

Deployment:
1. Install Functions SDK: `cd functions && npm install`.
2. Deploy: `firebase deploy --only functions:onPaymentTransactionCreate,onNotificationCreate`.

## Notes & Best Practices
- Always include the `notification` object for visible notifications so the OS displays it even when the app is terminated.
- Keep FCM service account / environment secure. Cloud Functions use server-side privileges and should not be called directly from untrusted clients.
- Consider adding throttling/rate-limiting if many transactions happen often.

## Testing
- Use Firebase Console to send test messages to specific tokens.
- Create a `payment_transactions` document (status `success`) in Firestore to trigger the function.

---
If you'd like, I can:
- Add a small test that simulates a payment doc creation and verifies tokens were notified (requires emulator or integration tests),
- Replace the hex-management/opt-in behavior with a server-side config per business.
