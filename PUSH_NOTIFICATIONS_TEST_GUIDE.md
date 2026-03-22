# Push Notifications Testing Guide

## Overview
This guide walks through testing the Firebase Cloud Functions for push notifications in the Manage Care app.

## Prerequisites
- ✅ Cloud Functions deployed (onPaymentTransactionCreate and onNotificationCreate)
- ✅ Firestore configured with security rules
- ✅ Firebase Admin SDK credentials set up

## Test Data Creation

### Option 1: Automated Test (Recommended)
Run the automated test script to create all necessary test data:

```bash
# From the root project directory
cd c:\Users\USER\Desktop\mc
node test_notifications.js
```

This script will create:
- Test business
- Test user (business owner)
- Test FCM token
- Test payment transaction (triggers onPaymentTransactionCreate)
- Test notification (triggers onNotificationCreate)

### Option 2: Manual Test in Firebase Console

#### Step 1: Create a Test Business
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **manage-care-1e96b**
3. Go to **Firestore Database**
4. Create a new document in `businesses` collection:
```json
{
  "name": "Test Business",
  "ownerId": "test-owner-123",
  "address": "123 Test St",
  "phone": "+234123456789",
  "email": "test@business.com",
  "createdAt": now
}
```

#### Step 2: Create a Test User (Business Owner)
Create a document in `users` collection with the same `ownerId`:
```json
{
  "fullName": "Test Owner",
  "email": "owner@test.com",
  "businessId": "[businessId from step 1]",
  "pushEnabled": true,
  "createdAt": now
}
```

#### Step 3: Add FCM Token to User
Under `users/[testOwnerId]/fcmTokens`, create a document with the FCM token:
```json
{
  "token": "test-fcm-token-123456",
  "createdAt": now
}
```

#### Step 4: Create Test Payment Transaction
Create a document in `payment_transactions` collection:
```json
{
  "transactionId": "txn-test-123456",
  "businessId": "[businessId from step 1]",
  "amount": 5000,
  "status": "success",
  "method": "card",
  "currency": "NGN",
  "createdAt": now,
  "description": "Test payment"
}
```
**⚠️ This will trigger the `onPaymentTransactionCreate` function**

#### Step 5: Create Test Notification
Create a document in `notifications` collection:
```json
{
  "title": "Test Notification",
  "body": "This is a test notification",
  "targetUsers": ["test-owner-123"],
  "createdAt": now
}
```
**⚠️ This will trigger the `onNotificationCreate` function**

## Verify Function Execution

### Check Cloud Functions Logs

1. Go to **Firebase Console** → **Cloud Functions**
2. Click on **onPaymentTransactionCreate**
3. Go to the **Logs** tab
4. You should see execution logs

Expected logs on success:
```
✓ Function executed successfully
[onPaymentTransactionCreate] Sending push notification for amount: 5000
[onPaymentTransactionCreate] Sent to X tokens
```

Expected logs if FCM fails (OK - test token is not real):
```
Removing invalid token test-fcm-token-123456 Error: InvalidRegistrationToken
```

### Function Execution Details

#### onPaymentTransactionCreate should:
- ✅ Trigger when a document is created in `payment_transactions`
- ✅ Check if payment status is 'success' or 'completed'
- ✅ Find business owner(s)
- ✅ Collect FCM tokens
- ✅ Attempt to send push notification
- ✅ Remove invalid tokens

#### onNotificationCreate should:
- ✅ Trigger when a document is created in `notifications`
- ✅ Get target users from the notification doc
- ✅ Collect FCM tokens for each target user
- ✅ Send push notification to all tokens

## Testing with Real FCM Tokens

To test with real notifications:

1. **Get a real FCM token** from the Flutter app:
   - Open the Manage Care app on a device
   - Go to Settings → Developer Info (or use debugPrint to log tokens)
   - Copy the FCM token

2. **Update the test data** with the real token:
   - Replace `test-fcm-token-123456` with your actual FCM token
   - Ensure the user ID matches a real user in the system

3. **Create test payment or notification** with the real token/user setup

4. **Check device notifications** - you should receive a push notification!

## Troubleshooting

### Issue: "No FCM tokens found"
**Solution:** Ensure the FCM tokens exist in `users/{userId}/fcmTokens` collection

### Issue: "Failed to send notification"
**Solution:** Check if:
- FCM token is valid (real tokens work, test tokens fail)
- User `pushEnabled` is not false
- Business has valid owner IDs

### Issue: "Function not triggered"
**Solution:**
- Check Cloud Functions are deployed: `firebase functions:list`
- Verify Firestore document was created (check Firestore console)
- Allow 5-30 seconds for function to execute

### Issue: "Business not found"
**Solution:**
- Ensure `businessId` in payment_transactions matches an existing business
- Check Firestore has the business document

## Success Indicators

✅ Test successful when you see:
1. Function appears in Cloud Functions list
2. Function logs show execution (no hard errors)
3. If using real tokens: notification appears on device
4. Firestore documents are created correctly

## Next Steps

Once testing is complete:
1. ✅ Clean up test data (optional)
2. ✅ Monitor production payments for real notifications
3. ✅ Set up alerts for function errors in Cloud Monitoring
4. ✅ Configure Firebase Cloud Messaging settings in app
