# 📊 Manage Care: Payment System Audit Report

**Date:** November 30, 2025  
**Project:** Manage Care - Flutter Business Management Application  
**Audit Focus:** Subscription management, payment processing, payment history, reminders, and late payment handling

---

## Executive Summary

The Manage Care app has a **basic payment infrastructure** with subscription tiers (Free, Starter, Professional, Tier3) but lacks:
- ❌ Complete payment history tracking and retrieval
- ❌ Automated payment reminders and notifications
- ❌ Late payment detection and enforcement
- ❌ Payment failure recovery workflows
- ❌ Subscription expiry alerts
- ❌ Pro-feature gating enforcement at runtime
- ❌ Payment method management UI
- ❌ Invoice/receipt tracking

**Risk Level:** 🔴 **HIGH** - Missing critical revenue protection features

---

## 1. Subscription System Audit

### ✅ What Exists

**Subscription Tiers (Core Constants)**
```dart
// lib/core/constants/subscription_tiers.dart
enum SubscriptionTier {
  free,
  starter,
  professional,
  enterprise,
}
```

**Tier Features:**
- **Free:** Basic features, limited users (1), limited products (100), no email receipts
- **Starter:** Monthly billing, 5 users, 1000 products, email receipts, basic reports
- **Professional:** 20 users, unlimited products, advanced features, priority support
- **Enterprise:** Unlimited everything, API access, custom development

**Subscription Storage in BusinessModel:**
```dart
final String subscriptionTier;              // e.g., 'free', 'pro'
final DateTime? subscriptionStartDate;
final DateTime? subscriptionEndDate;
final bool isSubscriptionActive;
```

**Subscription Update Method (BusinessRepositoryImpl):**
```dart
Future<void> updateSubscription({
  required String businessId,
  required String tier,
  required DateTime startDate,
  required DateTime endDate,
  bool isActive = true,
}) async { ... }
```

### ❌ Critical Gaps

#### 1.1 Missing Subscription Expiry Check
**Problem:** No logic to check if subscription has expired  
**Impact:** Businesses with expired subscriptions can still access Pro features  
**Location:** Should be in `BusinessProvider` or `SubscriptionProvider`

**Required Implementation:**
```dart
bool isSubscriptionExpired() {
  if (subscriptionEndDate == null) return false;
  return DateTime.now().isAfter(subscriptionEndDate!);
}

bool isSubscriptionActive() {
  return isSubscriptionActive && !isSubscriptionExpired();
}
```

#### 1.2 No Auto-Renewal Tracking
**Problem:** No field to track auto-renewal status  
**Impact:** Cannot differentiate between manual renewal vs auto-renewal subscriptions  
**Required Field in BusinessModel:**
```dart
final bool autoRenewEnabled;
final DateTime? lastAutoRenewalDate;
final String? autoRenewalFailureReason;
```

#### 1.3 Feature Gating Not Enforced
**Problem:** `canAccessFeature()` in BusinessProvider checks tier but not expiry  
**Current Code:**
```dart
bool canAccessFeature(String featureName) {
  final tier = _currentBusiness!.subscriptionTier;
  // Only checks tier, NOT expiry date
  ...
}
```
**Fixed Version:**
```dart
bool canAccessFeature(String featureName) {
  if (!isSubscriptionValid()) return false; // Add expiry check
  final tier = _currentBusiness!.subscriptionTier;
  ...
}

bool isSubscriptionValid() {
  if (_currentBusiness?.subscriptionEndDate == null) return true;
  return DateTime.now().isBefore(_currentBusiness!.subscriptionEndDate!);
}
```

---

## 2. Payment History Audit

### ✅ What Exists

**Payment Repository (Basic)**
```dart
// lib/data/repositories/payment_repository_impl.dart
class PaymentRepositoryImpl {
  Future<List<dynamic>> getPaymentHistory(
    String businessId, 
    {Map<String, dynamic>? filters}
  ) async { ... }
}
```

**Gym Module Payment Record**
```dart
class PaymentRecord {
  final String id;
  final String memberId;
  final double amount;
  final String currency;
  final String method;  // cash, card, stripe
  final DateTime timestamp;
  final String? note;
  final String? planId;
}
```

**Hotel Payment Status Tracking**
```dart
// lib/providers/hotel_provider.dart
final String paymentStatus; // unpaid, partial, paid
final DateTime? paymentDate;
```

### ❌ Critical Gaps

#### 2.1 No Global Payment History Model
**Problem:** Each industry has different payment tracking (Gym has PaymentRecord, Hotel has paymentStatus)  
**Impact:** No unified payment reporting or dashboard  
**Solution:** Create universal PaymentTransaction model:

```dart
class PaymentTransaction {
  final String id;
  final String businessId;
  final String? orderId;
  final String? invoiceId;
  final double amount;
  final String currency;
  final String status;  // pending, processing, completed, failed, refunded
  final String method;  // cash, card, bank_transfer, mobile_money, stripe
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? failureDate;
  final String? failureReason;
  final String? paymentProcessor;  // stripe, paypal, local_bank
  final String? processorTransactionId;
  final double? fee;
  final String? receiptUrl;
  final String? notes;
  final Map<String, dynamic>? metadata;
  
  // Pro features
  final bool canRetry;
  final int retryCount;
  final DateTime? nextRetryDate;
}
```

#### 2.2 No Payment Failure Tracking
**Problem:** `processPayment()` auto-marks all payments as "completed" regardless of success  
```dart
// Current (BROKEN)
Future<dynamic> processPayment(Map<String, dynamic> paymentData) async {
  try {
    paymentData['status'] = 'completed';  // Always marks as completed!
    final docRef = await _firestore.collection('payments').add(paymentData);
    return {'id': docRef.id, ...paymentData};
  } catch (e) {
    rethrow;  // Doesn't save failed status
  }
}
```

**Fixed Version:**
```dart
Future<Map<String, dynamic>> processPayment(
  Map<String, dynamic> paymentData,
) async {
  try {
    paymentData['status'] = 'processing';
    paymentData['createdAt'] = DateTime.now();
    
    final docRef = await _firestore.collection('payments').add(paymentData);
    final paymentId = docRef.id;
    
    // Attempt actual payment processing
    final success = await _processViaPaymentGateway(paymentData);
    
    if (success) {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': 'completed',
        'completedAt': DateTime.now(),
      });
    } else {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': 'failed',
        'failureDate': DateTime.now(),
        'failureReason': 'Payment gateway declined',
      });
    }
    
    return {'id': paymentId, ...paymentData};
  } catch (e) {
    // Save error for retry
    rethrow;
  }
}
```

#### 2.3 No Payment Analytics
**Problem:** No way to query:
- Total revenue by date/period
- Revenue by payment method
- Successful vs failed payment rates
- Average transaction value

---

## 3. Payment Reminders & Notifications Audit

### ✅ What Exists

**Email Service Methods:**
```dart
// lib/services/email_service.dart
Future<bool> sendSubscriptionPaymentAlert(...) // Payment confirmation
Future<bool> sendPaymentReminder(...) // Upcoming payment reminder
```

**Backend Worker Files:**
```
emailtemplate/payment_reminder_worker.php  // Sends payment reminders
emailtemplate/weekly_report_worker.php     // Weekly reports
```

### ❌ Critical Gaps

#### 3.1 No Scheduled Reminder System
**Problem:** 
- No cron jobs running `payment_reminder_worker.php`
- No logic to detect upcoming subscription renewals
- No notification sent 3/7 days before expiry

**Required Implementation:**
```dart
// Create new service
class PaymentReminderService {
  /// Get subscriptions expiring within N days
  Future<List<SubscriptionAlert>> getUpcomingExpirations(int daysAhead) async {
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    final query = firestore
        .collection('businesses')
        .where('subscriptionEndDate', isLessThanOrEqualTo: cutoff)
        .where('subscriptionEndDate', isGreaterThan: DateTime.now())
        .where('lastReminderSent', isLessThan: DateTime.now().subtract(Duration(days: 7)));
    
    return query.get().then((snap) => 
      snap.docs.map(/* parse */).toList()
    );
  }
  
  /// Send payment reminder notification
  Future<bool> sendPaymentReminder(
    String businessId, 
    DateTime expiryDate,
  ) async {
    // Send email & in-app notification
    // Mark lastReminderSent
  }
  
  /// Trigger payment collection (for auto-renew)
  Future<bool> attemptPaymentCollection(String businessId) async {
    // Call payment processor API
    // Record result
    // Send notification
  }
}
```

#### 3.2 No In-App Notifications
**Problem:** Only email-based reminders exist; no in-app alerts  
**Impact:** User might miss email; no immediate visibility

**Requires:**
```dart
// Use NotificationService to show:
- "Your subscription expires in 7 days"
- "Payment failed - update payment method"
- "Subscription renewed successfully"
```

#### 3.3 No Payment Method Management UI
**Problem:** Users cannot:
- Update/add payment methods
- View saved cards
- Set preferred payment method
- Retry failed payments

**Required Screens:**
```
Settings > Subscription > Payment Methods
  - Add new card
  - List saved cards
  - Delete payment method
  - Mark as primary
  - Test charge ($1 verification)
```

---

## 4. Late Payment & Dunning Management Audit

### ✅ What Exists
- Hotel reservation tracks `paymentStatus` (unpaid, partial, paid)
- Real estate tracks rent payments

### ❌ Critical Gaps

#### 4.1 No Late Payment Detection
**Problem:** No logic to identify overdue subscription payments  
**Impact:** Business doesn't know who owes money

**Required Fields in BusinessModel:**
```dart
final DateTime? lastPaymentDate;
final DateTime? nextPaymentDueDate;
final int daysOverdue;  // Calculated
final bool isPaymentOverdue;  // Calculated
final String paymentStatus; // current, overdue, past_due_30, past_due_60
```

#### 4.2 No Dunning (Collection) Workflow
**Problem:** No systematic approach to recover failed payments

**Required Dunning Sequence:**
```
Day 0: Payment fails → Send alert email
Day 3: Send "Payment Method Update Required" notification
Day 7: Send "Urgent: Subscription at Risk" warning
Day 10: Downgrade to Free tier (optional)
Day 15: Suspend account access
Day 30: Mark for cancellation
```

**Implement:**
```dart
class DunningService {
  /// Check for overdue payments and execute dunning sequence
  Future<void> processDunningCycle() async {
    final overdueBusinesses = await getOverdueBusinesses();
    
    for (final business in overdueBusinesses) {
      final daysOverdue = DateTime.now().difference(
        business.nextPaymentDueDate!
      ).inDays;
      
      if (daysOverdue == 0) {
        await sendPaymentFailedAlert(business);
      } else if (daysOverdue == 3) {
        await sendUpdatePaymentMethodAlert(business);
      } else if (daysOverdue == 7) {
        await sendUrgentWarning(business);
      } else if (daysOverdue == 10) {
        await downgradeToFreeTier(business);
      } else if (daysOverdue == 15) {
        await suspendAccount(business);
      }
    }
  }
}
```

#### 4.3 No Payment Enforcement
**Problem:** Pro features accessible even when subscription expired or payment failed

**Current Flow (BROKEN):**
```
User tries to use "Email Receipt" (Pro feature)
→ Check canAccessFeature('email_receipt')
→ Check only subscriptionTier
→ Returns true even if expired!
```

**Required Flow:**
```
User tries to use "Email Receipt"
→ Check canAccessFeature('email_receipt')
→ Verify subscription active AND not expired AND not overdue
→ If check fails:
   - Show "Upgrade Required" / "Renew Now" dialog
   - Block feature
   - Link to payment page
```

#### 4.4 No Navigation Restrictions
**Problem:** Users with overdue payments can still access dashboard  
**Impact:** Can continue using all features despite non-payment

**Required:**
```dart
// In main app routing/navigation:
if (business.isPaymentOverdue && daysOverdue > 7) {
  // Show payment due screen instead of dashboard
  return PaymentRequiredScreen(business: business);
}
```

---

## 5. Subscription Selection & Onboarding Audit

### ✅ What Exists

**Subscription Selection Screen:**
```dart
// lib/presentation/onboarding/screens/subscription_selection_screen.dart
- Displays 3 tiers: Free, Starter, Professional
- Shows features per tier
- Pricing information
```

### ❌ Gaps

#### 5.1 No Payment During Signup
**Problem:** No payment collection at signup  
**Current:** Users select plan but no charge is made

#### 5.2 No Free Trial Setup
**Problem:** No way to offer 14-day free trial of paid tiers

---

## 6. Business Model Recommendations

### Recommended BusinessModel Changes

```dart
class BusinessModel {
  // ... existing fields ...
  
  // Subscription Management
  final String subscriptionTier;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final bool isSubscriptionActive;
  
  // NEW FIELDS
  final bool autoRenewEnabled;
  final DateTime? lastRenewalDate;
  final String billingCycle; // monthly, annual
  final double subscriptionAmount;
  
  // Payment Tracking
  final DateTime? lastPaymentDate;
  final DateTime? nextPaymentDueDate;
  final String paymentStatus; // current, overdue, suspended, canceled
  final int daysOverdue;
  
  // Dunning/Collection
  final int dunningLevel; // 0=current, 1=reminded, 2=urgent, 3=suspended
  final DateTime? lastReminderSentDate;
  final int failedPaymentCount;
  final DateTime? lastPaymentFailureDate;
  
  // Pro Usage Tracking
  final int emailReceiptsSentThisMonth;
  final int maxEmailReceiptsPerMonth; // Depends on tier
  final int usersCount;
  final double storageUsedGB;
  final DateTime? usageLimitResetDate;
}
```

---

## 7. Action Items (Priority Order)

### 🔴 CRITICAL (Implement First)

1. **Add expiry validation to feature gating**
   - Modify `BusinessProvider.canAccessFeature()` to check expiry
   - File: `lib/providers/business_provider.dart`

2. **Create PaymentTransaction model**
   - Universal payment tracking across all industries
   - File: `lib/data/models/payment_transaction_model.dart`

3. **Implement DunningService**
   - Detect overdue subscriptions
   - Execute dunning sequence
   - File: `lib/services/dunning_service.dart`

4. **Add payment method management UI**
   - Screen to update cards
   - File: `lib/presentation/settings/screens/payment_methods_screen.dart`

5. **Add late payment navigation enforcement**
   - Redirect suspended accounts to payment screen
   - File: `lib/routes/app_router.dart` (modify routing logic)

### 🟠 HIGH (Implement Week 2)

6. Create subscription dashboard
   - Show renewal date, billing history, upcoming charges
   - File: `lib/presentation/settings/screens/subscription_dashboard_screen.dart`

7. Implement payment history viewer
   - List all transactions with status
   - File: `lib/presentation/settings/screens/payment_history_screen.dart`

8. Add scheduled reminders (backend)
   - Update `payment_reminder_worker.php`
   - Create `cron_job_runner.php`

9. Create retry mechanism for failed payments
   - Store failed payment details
   - Retry with new payment method

### 🟡 MEDIUM (Implement Week 3)

10. Add payment analytics/reports
11. Implement free trial system
12. Add Stripe/PayPal integration
13. Create audit logging for all payment changes

---

## 8. Test Scenarios

### Subscription Expiry
- [ ] Business with expired subscription cannot use Pro features
- [ ] User sees "Upgrade Required" dialog
- [ ] Dashboard shows "Subscription Expired" banner

### Late Payment
- [ ] Overdue business tagged at 3, 7, 10, 15 days
- [ ] Payment reminder emails sent at day 3, 7
- [ ] Account suspended at day 15
- [ ] Features disabled immediately upon suspension

### Payment Failure
- [ ] Failed payment recorded with failure reason
- [ ] User notified immediately
- [ ] Retry option presented
- [ ] Payment method update requested

### Feature Access
- [ ] Free tier cannot send email receipts
- [ ] Pro can send, but blocked if expired
- [ ] Shows upgrade link when blocked

---

## 9. Compliance & Security Notes

- ✅ PCI DSS: Never store full card numbers (delegate to Stripe/PayPal)
- ⚠️ GDPR: Add "forget me" clause for payment data after X months
- ⚠️ Tax: Store tax-relevant fields for audit
- ⚠️ Refund Policy: Implement refund deadline (e.g., 30 days)
- ⚠️ Webhooks: Implement Stripe webhook listener for async payment events

---

## 10. Conclusion

**Current State:** Basic subscription tier system with minimal payment enforcement  
**Missing:** 90% of production-ready payment features  
**Timeline:** 2-3 weeks to implement critical items  
**Risk:** Revenue loss, user fraud, account takeover if not addressed

**Next Meeting:** Review this report and prioritize immediate actions.

---

**Generated:** November 30, 2025  
**Reviewer:** Development Team  
**Status:** READY FOR IMPLEMENTATION

