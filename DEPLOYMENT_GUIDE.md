# Firebase Cloud Functions Deployment Guide

## ✅ COMPLETED:
- Service account key: `manage-care-1e96b-firebase-adminsdk-fbsvc-85a00f0674.json` ✅
- Environment variable: `GOOGLE_APPLICATION_CREDENTIALS` ✅
- Gradle build errors fixed ✅

## 🔄 NEXT STEPS:

### 1. Install Node.js (if not working)
Since the winget installation had issues, try one of these:

**Option A: Download from website**
- Go to https://nodejs.org/
- Download and install Node.js 18+ LTS
- Restart PowerShell/terminal

**Option B: Use Chocolatey (if installed)**
```powershell
choco install nodejs
```

**Option C: Manual PATH setup**
Find where Node.js was installed and add to PATH permanently.

### 2. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 3. Login to Firebase
```bash
firebase login
```

### 4. Deploy Functions
```bash
cd functions
firebase deploy --only functions:onPaymentTransactionCreate,onNotificationCreate
```

## 📱 Current Status
- ✅ **Client-side push notifications**: Working
- ✅ **Service account key**: Ready
- ✅ **Environment configured**: Ready
- ⏳ **Cloud Functions**: Need Node.js + Firebase CLI

## 🚀 What You'll Get
Once deployed, you'll have:
- Automatic push notifications for payment transactions
- Admin broadcast notifications
- Server-side reliability for critical business notifications

The client-side notifications already work for sales and logins!</content>
<parameter name="filePath">c:\Users\USER\Desktop\mc\DEPLOYMENT_GUIDE.md