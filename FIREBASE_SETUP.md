# Firebase Service Account Setup for Push Notifications

## Required Files for Firebase Storage/Functions

### 1. Service Account Key (for Cloud Functions)
**File:** `serviceAccountKey.json`
**Location:** `functions/` directory
**Purpose:** Authenticates Firebase Cloud Functions with Firebase Admin SDK

### How to Create:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (manage-care-1e96b)
3. Go to Project Settings → Service Accounts
4. Click "Generate new private key"
5. Download the JSON file and rename it to `serviceAccountKey.json`
6. Place it in the `functions/` directory

### Environment Setup:
```bash
# Set environment variable (Windows)
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\your\project\functions\serviceAccountKey.json

# Or for PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your\project\functions\serviceAccountKey.json"
```

### 2. Deploy Cloud Functions
After setting up the service account key:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy functions
cd functions
firebase deploy --only functions:onPaymentTransactionCreate,onNotificationCreate
```

## Current Status
- ✅ Client-side push notifications implemented
- ❌ Server-side Cloud Functions not deployed
- ❌ Service account key not configured

## What Works Now
- Local notifications on device
- Client-side FCM token management
- Push notification triggers in POS screens

## What Needs Server-Side
- Automated notifications for payment transactions
- Admin broadcast notifications
- Server-side reliability for critical notifications</content>
<parameter name="filePath">c:\Users\USER\Desktop\mc\FIREBASE_SETUP.md