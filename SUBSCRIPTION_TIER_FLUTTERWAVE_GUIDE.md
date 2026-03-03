# Subscription Tier & Flutterwave Integration Guide

## Overview
This document outlines the complete subscription system implementation with tier allocation (Tier 1, 2, 3), Flutterwave payment integration, and admin dashboard functionality.

## Subscription Tiers & Classes

### Tier Classification
The system uses a two-level classification:

#### 1. Business Tier (tier/pro distinction)
- **Basic**: Limited features for small operations  
- **Pro**: Advanced features for larger operations

#### 2. Business Class (Tier1/Tier2/Tier3)
Determined by business size metrics:

```
Tier1:
- Products: < 400
- Staff: < 4  
- Monthly Income: ≤ ₦100,000

Tier2:
- Products: 401-1,000
- Staff: 4-9
- Monthly Income: ₦1,000,000 - ₦2,000,000

Tier3:
- Everything else (highest tier)
```

### Available Plans
Plans are structured by class with different durations:

#### Tier 1 Plans
- `t1_basic_3m` - 3 months - ₦23,750
- `t1_basic_6m` - 6 months - ₦42,250
- `t1_basic_12m` - 12 months - ₦77,850

#### Tier 2 Plans
- `t2_basic_3m` - 3 months - ₦28,980 (Basic features)
- `t2_basic_6m` - 6 months - ₦48,480
- `t2_basic_12m` - 12 months - ₦88,180
- `t2_pro_3m` - 3 months - ₦32,780 (Advanced features)
- `t2_pro_6m` - 6 months - ₦81,880
- `t2_pro_12m` - 12 months - ₦91,900

#### Tier 3 Plans
- `t3_basic_3m` - 3 months - ₦36,580
- `t3_basic_6m` - 6 months - ₦53,980
- `t3_basic_12m` - 12 months - ₦93,780
- `t3_pro_3m` - 3 months - ₦37,900
- `t3_pro_6m` - 6 months - ₦56,100
- `t3_pro_12m` - 12 months - ₦97,780

## Registration & Tier Allocation

### Business Detection on Registration
When a user creates a business, the system automatically:

1. **Detects Business Class** (`detectBusinessClass` method in SubscriptionService)
   - Analyzes product count, staff count, and monthly income
   - Assigns Tier1, Tier2, or Tier3 classification
   - Stores in `business.businessClass` field

2. **Shows Appropriate Plans** in subscription selection
   - Only shows plans matching their business class
   - For example, Tier1 users only see `t1_*` plans

### Subscription Payment Screen
- **Location**: `lib/presentation/auth/screens/subscription_payment_screen.dart`
- **Features**:
  - Plan selection based on business class
  - Multiple payment methods:
    - **Flutterwave**: Direct card/USSD payment
    - **Bank Transfer**: Manual transfer with receipt upload
    - **Camera/Gallery**: Upload proof of payment
    - **Email**: Send receipt to admin

## Payment Methods

### 1. Flutterwave Integration
**Key Features**:
- Real-time payment processing
- Support for cards, USSD, bank transfers
- Automatic transaction tracking
- Receipt generation

**Flow**:
```
1. User selects plan
2. Clicks "Pay with Flutterwave"
3. Flutterwave dialog opens
4. User completes payment
5. Transaction logged with ID format: "flutterwave:TXREF"
6. Subscription activated immediately
7. Transaction recorded in payment_transactions collection
```

**Transaction Logging**:
```dart
// Stored in payment_transactions collection
{
  "transactionId": "FLW1234567890",
  "businessId": "business_id",
  "email": "user@example.com",
  "amount": 23750,
  "currency": "NGN",
  "method": "flutterwave",
  "status": "completed",
  "paymentProcessor": "flutterwave",
  "createdAt": "2026-02-14T10:30:00Z",
  "processorResponse": {...},
  "subscriptionPayment": true,
  "planId": "t1_basic_3m",
  "userId": "user_id"
}
```

### 2. Manual Bank Transfer
**Process**:
```
1. User selects plan
2. System shows bank account details
3. User transfers amount to account
4. User uploads receipt proof (screenshot/photo)
5. Subscription request created as "pending"
6. Admin reviews and approves/declines
7. On approval, subscription activated
```

**Stored in subscription_requests collection**:
```dart
{
  "uploadId": "RCP_userid_timestamp",
  "userId": "user_id",
  "businessId": "business_id",
  "planId": "t1_basic_3m",
  "planName": "Tier 1 — Basic (3 months)",
  "amount": 23750,
  "currency": "NGN",
  "userEmail": "user@example.com",
  "userName": "User Name",
  "receiptUrl": "https://storage.googleapis.com/...",
  "status": "pending|approved|rejected",
  "createdAt": "2026-02-14T10:30:00Z"
}
```

## Admin Dashboard & Payments Management

### Admin Payments Page
**Location**: `lib/app_admin/pages/admin_payments_page.dart`

**Tabs**:
1. **Pending** - Awaiting admin review
2. **Approved** - Activated subscriptions
3. **Declined** - Rejected payments
4. **Transactions** - Flutterwave transactions

### Subscription Payment Card Display
Each subscription payment card shows:

```
┌─────────────────────────────────────┐
│ User Avatar | User Name             │ ⏳ Pending
│             | email@example.com     │
├─────────────────────────────────────┤
│ Subscription Plan: Tier 1 — Basic   │ Amount: ₦23,750
│                                     │
│ Business: My Store    │ [TIER1-TAG]│
│ Requested: 2/14/26    │ 🟢Flutterwave
│
│ Receipt: [View] [Download]
│
│ [Decline] [Approve]
└─────────────────────────────────────┘
```

### Key Information Displayed
- **User**: Name, email
- **Plan**: Detailed plan name (e.g., "Tier 1 — Basic (3 months)")
- **Amount**: Subscription price in ₦
- **Business Class**: Color-coded badge
  - 🔵 Tier1 (Blue)
  - 🟣 Tier2 (Purple)  
  - 🔴 Tier3 (Red)
- **Payment Method**: Shows if Flutterwave or bank transfer
- **Receipt**: Thumbnail, view, and download options

### Admin Actions
#### Approve Subscription
```
1. Admin clicks [Approve]
2. Confirms detail popup
3. Subscription activated for user
4. Entry created in subscription_approvals
5. User record updated:
   - subscriptionStatus: "approved"
   - hasActiveSubscription: true
   - subscriptionStartDate: now
   - subscriptionEndDate: now + duration
```

#### Decline Subscription
```
1. Admin clicks [Decline]
2. Enters decline reason
3. User subscription marked declined
4. Entry logged in subscription_approvals
5. Approval status email sent (optional)
```

#### Upload Missing Receipt
```
1. If receipt missing, admin can upload
2. Click [Upload Receipt]
3. Select from gallery/camera
4. Receipt uploaded and linked
5. Payment card updated
```

## Subscription Databases Structure

### User Document Updates
When subscription activated:
```dart
{
  "userId": "user_id",
  "hasActiveSubscription": true,
  "subscriptionPlan": "t1_basic_3m",
  "subscriptionStatus": "active|approved|pending|declined",
  "subscriptionStartDate": "2026-02-14T...",
  "subscriptionEndDate": "2026-05-14T...",
  "subscriptionAmount": 23750,
  "subscriptionReceiptUrl": "https://...",
  "paymentMethod": "flutterwave|bank_transfer",
  "flutterwaveTransactionId": "FLW1234567890",  // If Flutterwave
  "businessClass": "tier1|tier2|tier3",
  "updatedAt": "2026-02-14T..."
}
```

### Subscription Requests Collection
Manual payment submissions:
```dart
collection('subscription_requests') {
  "uploadId": "RCP_...",
  "userId": "...",
  "businessId": "...",
  "planId": "t1_basic_3m",
  "amount": 23750,
  "receiptUrl": "https://...",
  "status": "pending|approved|rejected",
  "createdAt": Timestamp,
  "approvedAt": Timestamp (if approved)
}
```

### Subscription Approvals Collection
Admin approval records:
```dart
collection('subscription_approvals') {
  "userId": "...",
  "userName": "User Name",
  "userEmail": "user@example.com",
  "planId": "t1_basic_3m",
  "amount": 23750,
  "status": "approved|declined",
  "approvedAt|declinedAt": Timestamp,
  "approvedBy|declinedBy": "admin"
}
```

### Payment Transactions Collection
All payment transactions:
```dart
collection('payment_transactions') {
  "transactionId": "FLW1234567890",
  "businessId": "...",
  "email": "user@example.com",
  "amount": 23750,
  "currency": "NGN",
  "method": "flutterwave|bank_transfer|...",
  "status": "completed|pending|failed",
  "createdAt": Timestamp,
  "processorResponse": {...}
}
```

## Flutterwave Transaction Flow

### Payment Success Path
```
1. User initiates Flutterwave payment
2. Flutterwave dialog displays
3. User completes payment
4. Flutterwave service returns:
   {
     "success": true,
     "transactionId": "FLW1234567890",
     "status": "completed"
   }
5. Receipt uploaded with marker "flutterwave:FLW1234567890"
6. Subscription immediately activated
7. Transaction logged in payment_transactions
8. User record updated with subscription
9. Admin dashboard shows completed transaction
```

### Admin Flutterwave Transaction Management
In **Transactions tab**:
- Lists all Flutterwave transactions
- Shows status (completed, failed, pending)
- Admin can:
  - View transaction details
  - Approve as subscription payment
  - Decline with reason

## Receipt Management

### Receipt Upload Process
1. **Automatic** (Flutterwave): Stored as "flutterwave:TXREF"
2. **Manual** (Bank Transfer): Uploaded image/file
3. **Admin Upload**: Missing receipts filled by admin

### Receipt Actions
- **View**: Pop-up dialog with full-size image
- **Download**: Direct download link
- **Zoom**: Pinch to zoom in pop-up

### Receipt Storage
- Received in Google Cloud Storage
- Permanent URLs generated
- Cache busting: `?t=timestamp` appended

## Validation & Error Handling

### Plan Validation
```dart
// Only show available plans for user's class
if (businessClass == 'tier1') {
  showPlans = SubscriptionService.getPlansForClass('tier1')
  // Result: [t1_basic_3m, t1_basic_6m, t1_basic_12m]
}
```

### Subscription Status Validation
```dart
// Check if subscription is active
bool isActive = SubscriptionService.isSubscriptionActive(user);

// Validates:
// 1. User is owner (non-owners auto-granted)
// 2. hasActiveSubscription == true
// 3. subscriptionEndDate > now
```

### Payment Method Detection
```dart
// Detect payment type from receipt URL
if (receiptUrl.startsWith('flutterwave:')) {
  paymentMethod = "Flutterwave"
  transactionId = receiptUrl.replaceFirst('flutterwave:', '')
}
```

## Testing Checklist

### Complete Subscription Flow
- [ ] Register business (detects tier2)
- [ ] Go to subscription screen
- [ ] Verify only Tier2 plans shown
- [ ] Select plan
- [ ] Complete Flutterwave payment
- [ ] Verify transaction logged
- [ ] Admin sees "Flutterwave" badge
- [ ] Admin approves
- [ ] Subscription activated
- [ ] User can access app

### Admin Dashboard
- [ ] View pending subscriptions
- [ ] View approved subscriptions
- [ ] View Flutterwave transactions
- [ ] Filter by date range
- [ ] Upload missing receipt
- [ ] Approve subscription
- [ ] Decline subscription
- [ ] View transaction details

### Tier Display
- [ ] Tier1 shows blue badge
- [ ] Tier2 shows purple badge
- [ ] Tier3 shows red badge
- [ ] Business class properly detected
- [ ] Only correct plans shown per tier

## API Endpoints & Services

### SubscriptionService Methods
```dart
// Get plans for business class
static List<SubscriptionPlan> getPlansForClass(String? businessClass)

// Detect business class from metrics
static String detectBusinessClass({
  required int products,
  required int staff,
  required double monthlyIncome
})

// Get plan details by ID
static SubscriptionPlan? getPlanById(String planId)

// Validate subscription is active
static bool isSubscriptionActive(UserModel user)

// Activate subscription immediately
Future<bool> activateSubscriptionImmediately({
  required String userId,
  required String planId,
  required String receiptUrl,
  required double amount,
  String? businessId,
})
```

### FlutterwavePaymentService Methods
```dart
// Process payment with Flutterwave
Future<PaymentResult> processPayment({
  required BuildContext context,
  required double amount,
  required String currency,
  required String email,
  required String fullName,
  required String transactionId,
  String? phoneNumber,
})
```

### ReceiptUploadService Methods
```dart
// Upload receipt and create pending request
Future<ReceiptUploadResult> uploadReceipt({
  required String userId,
  required String businessId,
  required String planId,
  required String planName,
  required double amount,
  required String currency,
  required File receiptFile,
  required String userEmail,
  required String userName,
})

// Watch request status
Stream<SubscriptionRequestStatus?> watchRequestStatus(String uploadId)
```

## Common Issues & Solutions

### Issue: Admin doesn't see subscription payment
**Solution**: Check that user record has `subscriptionStatus` field set

### Issue: Flutterwave transaction not appearing in admin dashboard
**Solution**: Verify `payment_transactions` collection has entry with `subscriptionPayment: true`

### Issue: Wrong plans showing in subscription screen
**Solution**: Check business document has `businessClass` field (tier1/tier2/tier3)

### Issue: Receipt preview not loading
**Solution**: Check receipt URL is accessible and not expired

## Future Enhancements

- [ ] Automatic subscription renewal reminders
- [ ] Subscription expiration alerts
- [ ] Bulk payment approval in admin dashboard
- [ ] Payment history export (CSV/PDF)
- [ ] Subscription usage analytics
- [ ] Discounts for annual plans
- [ ] Multiple payment gateway support
- [ ] Subscription downgrade/upgrade
- [ ] Pro-rata refunds
- [ ] Subscription pause functionality
