# Subscription Payment Data Storage - Quick Reference

## Where Subscription Payments Are Stored

### 1. User Submits Receipt Payment
- **Service**: `ReceiptUploadService.uploadReceipt()`
- **Collection**: `subscription_requests`
- **Document Fields**:
  ```
  uploadId: "RCP_${userId}_${timestamp}"
  userId: string
  businessId: string
  planId: string (basic, pro, tier3)
  planName: string
  amount: number
  currency: string (NGN)
  userEmail: string
  userName: string
  receiptUrl: string (Firebase Storage URL)
  status: "pending"
  createdAt: timestamp
  updatedAt: timestamp
  ```

### 2. Admin Views Pending Payments
- **Screen**: `AdminPaymentsPage`
- **Query Source**: `subscription_requests` collection
- **Filter**: `where('status', isEqualTo: 'pending')`
- **Display**: All payment details including receipt thumbnail and download

### 3. Admin Approves Payment
- **Method**: `_approveSubscription(payment)`
- **Updates Made**:

#### User Document (users/{userId})
```
subscriptionStatus: "approved"
hasActiveSubscription: true
subscriptionApprovedAt: timestamp
subscriptionPlan: planId
subscriptionStartDate: timestamp
subscriptionEndDate: timestamp
```

#### Subscription Requests Document (subscription_requests/{uploadId})
```
status: "approved"
approvedAt: timestamp
approvedBy: "admin"
```

#### Business Document (businesses/{businessId})
```
subscriptionPlan: planId
subscriptionStartDate: timestamp
subscriptionEndDate: timestamp
```

#### Audit Log (subscription_approvals collection)
```
userId: string
userName: string
userEmail: string
planId: string
amount: number
receiptUrl: string
approvedAt: timestamp
approvedBy: "admin"
status: "approved"
```

### 4. Admin Declines Payment
- **Method**: `_declineSubscription(payment, reason)`
- **Updates Made**:

#### User Document
```
subscriptionStatus: "declined"
hasActiveSubscription: false
subscriptionDeclinedAt: timestamp
subscriptionDeclineReason: reason
```

#### Subscription Requests Document
```
status: "rejected"
rejectedAt: timestamp
rejectedBy: "admin"
rejectedReason: reason
```

#### Audit Log
```
userId: string
userName: string
userEmail: string
planId: string
amount: number
receiptUrl: string
declinedAt: timestamp
declinedBy: "admin"
declineReason: reason
status: "declined"
```

---

## Data Flow Visualization

```
┌────────────────────────────────────────┐
│ SubscriptionPaymentScreen              │
│ User uploads receipt + payment proof   │
└──────────────┬─────────────────────────┘
               │
               ▼
┌────────────────────────────────────────┐
│ ReceiptUploadService                   │
│ • Uploads file to Firebase Storage     │
│ • Creates subscription_requests doc    │
└──────────────┬─────────────────────────┘
               │
               ▼
        ✅ STORED IN:
   subscription_requests/{uploadId}
   Status: pending
               │
               ▼
┌────────────────────────────────────────┐
│ AdminPaymentsPage                      │
│ Loads and displays pending payments    │
│ Query: subscription_requests (pending) │
└──────────────┬─────────────────────────┘
               │
      ┌────────┴────────┐
      ▼                 ▼
  APPROVE          DECLINE
    │                 │
    ▼                 ▼
Updates:          Updates:
• users/{id}      • users/{id}
• subscription_  • subscription_
  requests/{id}     requests/{id}
• businesses/{id} • subscription_
• subscription_     approvals
  approvals       
```

---

## Admin Payment Screen Data Sources

**Primary Query**: `subscription_requests` collection
- Retrieves all pending, approved, and declined payments
- Includes receipt URLs for preview/download
- Shows transaction dates and amounts

**Secondary Source**: User documents
- Provides user name and email for display
- Shows subscription plan and status

**Audit Trail**: `subscription_approvals` collection
- Complete record of all approve/decline actions
- Tracks who made the decision and when
- Includes decline reasons for declined payments

---

## Field Verification Checklist

✅ All required fields are stored in the correct locations
✅ Admin payments screen retrieves data from the right collections
✅ Approval process updates all necessary documents
✅ Audit trail captures all actions
✅ Business subscription synced on approval
✅ Status fields properly updated on approve/decline

**Status**: Production Ready ✅


