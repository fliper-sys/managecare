# Admin Payments Approval & Subscription Management Guide

## Overview

The enhanced Admin Payments Page provides administrators with a comprehensive subscription approval and management system. Admins can now review subscription payment receipts, approve or decline subscriptions, and manage all payment records in one centralized location.

## Features

### 1. **Tabbed Payment Management**
The payments page is organized into three tabs:

#### **Pending Approvals** (Orange Badge)
- Shows all subscription requests awaiting admin approval
- Displays user details, subscription plan, and amount
- Receipt available for review
- Action buttons: **Approve** or **Decline**

#### **Approved Subscriptions** (Green Badge)
- Shows all successfully approved subscriptions
- Users can access their purchased plan features
- Historical reference for audits

#### **Declined Subscriptions** (Red Badge)
- Shows all rejected subscription requests
- Displays decline reason for reference
- Historical record for user follow-up

### 2. **Receipt Management**

#### **Receipt Display**
- Thumbnail preview in payment card
- Full-size preview dialog for detailed viewing
- Supports image formats: JPG, PNG, etc.

#### **Receipt Actions**
- **View Button**: Opens full-size receipt preview dialog
- **Download Button**: Direct download link to receipt image
- Receipts stored at: `https://globalthrivealliance.com/uploads/`

### 3. **Subscription Approval Workflow**

#### **Approval Process**
```
1. Admin navigates to Payments tab
2. Reviews pending subscription in the "Pending" tab
3. Views receipt by clicking "View" button
4. Clicks "Approve" button
5. Confirms action in dialog
6. System updates:
   - User subscription status → 'approved'
   - hasActiveSubscription → true
   - subscriptionApprovedAt → current timestamp
7. Logs approval in subscription_approvals collection
8. User gains immediate access to paid features
```

#### **Decline Process**
```
1. Admin reviews pending subscription
2. Clicks "Decline" button
3. Enters decline reason in dialog
4. Confirms action
5. System updates:
   - User subscription status → 'declined'
   - hasActiveSubscription → false
   - subscriptionDeclinedAt → current timestamp
   - subscriptionDeclineReason → admin's reason
6. Logs decline in subscription_approvals collection
7. User receives notification to retry or contact support
```

### 4. **User Information Display**

Each payment card displays:
- **User Avatar**: Initials on gradient background
- **User Name**: Full name from user profile
- **User Email**: Contact email for follow-up
- **Business Name**: Associated business (if available)
- **Subscription Plan**: Plan name and pricing
  - Basic: ₦10,000/month
  - Pro: ₦20,000/month
  - Tier3: ₦100,000/month
- **Amount**: Total payment amount in Naira
- **Request Date**: When subscription was requested
- **Receipt URL**: Link to uploaded payment proof

### 5. **Audit & Compliance**

#### **Approval Logging**
All approval actions are logged in Firestore:

```dart
// Logged to: subscription_approvals collection
{
  'userId': 'user_id',
  'userName': 'John Doe',
  'userEmail': 'john@example.com',
  'planId': 'pro',
  'amount': 20000.0,
  'receiptUrl': 'https://...',
  'approvedAt': '2025-12-08T...',
  'approvedBy': 'admin',
  'status': 'approved'
}
```

#### **Decline Logging**
```dart
{
  'userId': 'user_id',
  'userName': 'Jane Doe',
  'userEmail': 'jane@example.com',
  'planId': 'pro',
  'amount': 20000.0,
  'receiptUrl': 'https://...',
  'declinedAt': '2025-12-08T...',
  'declinedBy': 'admin',
  'declineReason': 'Receipt unclear - insufficient proof of payment',
  'status': 'declined'
}
```

### 6. **Real-time Data Loading**

The page automatically:
- Fetches all users from Firestore
- Filters by subscription status
- Categorizes into Pending/Approved/Declined
- Loads associated business information
- Sorts by request date (newest first)

## Admin Subscription Approval Tab Layout

```
┌─────────────────────────────────────────┐
│  SUBSCRIPTION APPROVALS                 │
│  Review and approve user payments      │
├─────────────────────────────────────────┤
│  [Pending: 5]  [Approved: 12]  [Declined: 3] │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 👤 John Doe                   │   │
│  │    john@example.com       ⏳Pending │
│  │                                │   │
│  │ Plan: Pro (₦20,000/month)     │   │
│  │ Amount: ₦20,000.00             │   │
│  │ Requested: Dec 8, 2025 7:45 PM │   │
│  │                                │   │
│  │ Receipt:                        │   │
│  │ ┌──────┐  [View] [Download]    │   │
│  │ │ IMG  │                        │   │
│  │ └──────┘                        │   │
│  │                                │   │
│  │  [❌ Decline]    [✓ Approve]   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ... more payment cards ...             │
│                                         │
└─────────────────────────────────────────┘
```

## File Structure

```
lib/
├── app_admin/
│   ├── app_admin_dashboard_screen.dart (Updated)
│   │   ├── Imports AdminPaymentsPage
│   │   └── Uses AdminPaymentsPage in _pages list
│   └── pages/
│       └── admin_payments_page.dart (NEW - 850 lines)
│           ├── SubscriptionPayment model
│           ├── AdminPaymentsPage widget
│           ├── Payment listing logic
│           ├── Approval/decline handlers
│           └── Receipt viewing dialogs
```

## Key Classes

### **SubscriptionPayment Model**
```dart
class SubscriptionPayment {
  final String userId;
  final String userName;
  final String userEmail;
  final String businessId;
  final String businessName;
  final String planId;
  final String planName;
  final double amount;
  final String receiptUrl;
  final DateTime requestDate;
  final String status; // pending, approved, declined
  
  factory SubscriptionPayment.fromFirestore(...) { }
  static String _getPlanName(String planId) { }
}
```

### **AdminPaymentsPage**
```dart
class AdminPaymentsPage extends StatefulWidget {
  // Manages three tabs: Pending, Approved, Declined
  // Loads and filters user subscriptions from Firestore
  // Handles approve/decline actions with confirmation
}
```

## Integration with Existing System

### **User Subscription Flow**
1. User uploads receipt → Subscription Service receives it
2. System sets `subscriptionStatus: 'active'` immediately
3. User sees "Pending Approval" status screen
4. Admin reviews payment in Payments tab
5. Admin approves/declines via dashboard
6. User's Firestore record updates accordingly

### **Feature Access**
```dart
// In FeatureAccessGuard
bool canAccess = user.hasActiveSubscription && 
                 user.subscriptionStatus == 'approved'
```

## Firestore Collections Used

### **users**
Updated fields:
- `subscriptionStatus`: 'pending' → 'approved' or 'declined'
- `subscriptionApprovedAt`: Timestamp of approval
- `subscriptionDeclinedAt`: Timestamp of decline
- `subscriptionDeclineReason`: Admin's reason for decline

### **subscription_approvals** (NEW)
New collection for audit trail:
```dart
{
  'userId': String,
  'userName': String,
  'userEmail': String,
  'planId': String,
  'amount': double,
  'receiptUrl': String,
  'approvedAt' or 'declinedAt': Timestamp,
  'approvedBy' or 'declinedBy': String,
  'declineReason': String (optional),
  'status': 'approved' or 'declined',
}
```

## Best Practices

### **For Admins**
1. ✅ **Review receipts carefully** before approving
2. ✅ **Document decline reasons** for user communication
3. ✅ **Check request timestamp** for overdue payments
4. ✅ **Verify user email** matches intended recipient
5. ✅ **Process pending approvals** regularly to avoid delays

### **For Developers**
1. ✅ Keep receipt URLs accessible and permanent
2. ✅ Log all approval/decline actions in audit trail
3. ✅ Monitor subscription_approvals collection for trends
4. ✅ Update user notifications when status changes
5. ✅ Sync approved subscriptions to business features

## Future Enhancements

- [ ] Bulk approve/decline multiple subscriptions
- [ ] Email notification templates for approvals/declines
- [ ] Subscription renewal reminders (10 days before expiry)
- [ ] Payment failure handling and retry logic
- [ ] Custom invoice generation
- [ ] Payment analytics dashboard
- [ ] Refund/cancellation workflow
- [ ] Subscription tier upgrade tracking
- [ ] Per-user payment history view
- [ ] Late payment dunning sequences

## Troubleshooting

### **Receipt not loading**
- Verify receipt URL is accessible
- Check image format (JPG/PNG supported)
- Ensure globalthrivealliance.com domain is reachable

### **Approval not updating user status**
- Check Firebase permissions for 'users' collection
- Verify user document exists in Firestore
- Check browser console for Firestore errors

### **Receipts not visible in payment cards**
- Confirm receiptUrl is stored in user document
- Check image hosting service availability
- Verify URL format is complete (https://...)

## Admin Dashboard Navigation

From the Admin Dashboard:
1. Click **"Payments"** in bottom navigation bar
2. Select tab: **Pending**, **Approved**, or **Declined**
3. Review subscription request
4. **View** receipt or **Download** for verification
5. Click **Approve** or **Decline** to process
6. Enter decline reason if applicable
7. Confirm action

---

**Created:** December 8, 2025  
**Last Updated:** December 8, 2025  
**Status:** ✅ Complete and Ready for Use

