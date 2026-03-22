# Background Subscription System - Architecture & Flow Diagrams

## 1. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Manage Care App                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              User Interface Layer                         │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Feature Screens │ Dashboard │ Settings │ Upgrade Page   │   │
│  └────────────────┬───────────────────────────────────────┬─┘   │
│                   │                                       │       │
│  ┌────────────────▼──────────────────────────┬────────────▼───┐ │
│  │       Provider Layer (State Management)    │                 │ │
│  ├──────────────────────────────────────────┤                 │ │
│  │                                           │                 │ │
│  │  ┌─────────────────────────────────────┐ │                 │ │
│  │  │ EnhancedSubscriptionProvider ◄───┐  │ │                 │ │
│  │  │ - Manages subscription state      │  │ │                 │ │
│  │  │ - High-level API for UI           │  │ │                 │ │
│  │  │ - Status tracking                 │  │ │                 │ │
│  │  └──────┬──────────────────────────┬─┘ │ │                 │ │
│  │         │                          │   │ │                 │ │
│  │  ┌──────▼────────────┐    ┌───────▼─┐ │ │                 │ │
│  │  │ Background        │    │ Feature │ │ │                 │ │
│  │  │ Subscription      │    │ Guard   │ │ │                 │ │
│  │  │ Checker           │    │ Service │ │ │                 │ │
│  │  │                   │    │         │ │ │                 │ │
│  │  │ • 30min checks    │    │ • Enforce◄┘ │                 │ │
│  │  │ • Expiration det. │    │   access   │                 │ │
│  │  │ • Status changes  │    │ • Log      │                 │ │
│  │  │ • Cache updates   │    │   access   │                 │ │
│  │  └────────┬──────────┘    │ • Upgrade  │                 │ │
│  │           │               │   path     │                 │ │
│  └───────────┼───────────────┼───────────┘ │                 │ │
│              │               │             │                 │ │
│  ┌───────────▼───────────────▼─────────────▼───────────┐    │ │
│  │       Local Storage Layer                           │    │ │
│  ├─────────────────────────────────────────────────────┤    │ │
│  │  • LocalBusinessStorage (Hive/SharedPreferences)    │    │ │
│  │  • Cached business data                             │    │ │
│  │  • Subscription status cache                        │    │ │
│  │  • Current business selection                       │    │ │
│  └─────────────────┬──────────────────────────────────┘    │ │
│                    │                                        │ │
│  ┌─────────────────▼──────────────────────────────────┐    │ │
│  │       Firebase Layer                               │    │ │
│  ├────────────────────────────────────────────────────┤    │ │
│  │  Firestore:                                        │    │ │
│  │  • /businesses/{id}                                │    │ │
│  │    - subscriptionTier                              │    │ │
│  │    - isSubscriptionActive                          │    │ │
│  │    - subscriptionEndDate                           │    │ │
│  │  • /users/{id}                                     │    │ │
│  │    - hasActiveSubscription                         │    │ │
│  └────────────────────────────────────────────────────┘    │ │
│                                                              │ │
└──────────────────────────────────────────────────────────────┘

KEY COMPONENTS:
  → EnhancedSubscriptionProvider: High-level coordinator
  → BackgroundSubscriptionChecker: Monitors subscription status
  → SubscriptionFeatureGuard: Enforces feature access
  → Local Storage: Offline capability & caching
  → Firebase: Single source of truth for subscription data
```

---

## 2. Background Checking Cycle

```
┌─────────────────────────────────────────────────────────────┐
│             Background Subscription Checking                │
└─────────────────────────────────────────────────────────────┘

App Start
    ↓
[Timer] Every 30 minutes
    ↓
Check User Subscriptions
    ├─ Get all cached businesses
    ├─ For each business:
    │   ├─ Query Firestore
    │   ├─ Compare with cache
    │   ├─ Check expiration
    │   └─ Update if changed
    ↓
Decision: Did status change?
    ├─ YES ──┬─→ Update cache
    │        ├─→ Trigger callback
    │        ├─→ Notify listeners
    │        └─→ Log change
    │
    └─ NO ──→ Continue

┌─────────────────────────────────────────────────────────────┐
│               Example Timeline                              │
└─────────────────────────────────────────────────────────────┘

T=0min    : App starts, init called
           ↓ background checking starts

T=30min   : First check
           • Biz A: Valid (expires in 30 days)
           • Biz B: Valid (expires in 5 days)
           ↓ Log: Biz B expiring soon (callback triggered)

T=60min   : Second check
           • Biz A: Valid (no change)
           • Biz B: Valid (expires in 4 days)
           ↓ Log: No changes

T=90min   : Third check
           • Biz A: EXPIRED! (callback triggered)
           • Biz B: Valid
           ↓ Log: Biz A expired! Block features

T=120min  : Fourth check
           • Biz A: RENEWED! (callback triggered)
           • Biz B: Valid
           ↓ Log: Biz A active again! Resume features
```

---

## 3. Feature Access Control Flow

```
User clicks "Send Email Receipt" button
    ↓
Screen calls: subscriptionProvider.canAccessFeature(
  business: currentBusiness,
  feature: 'email_receipts',
  context: 'email_receipt_screen'
)
    ↓
EnhancedSubscriptionProvider
    ↓
BackgroundSubscriptionChecker.validateFeatureAccess()
    ├─ Is subscription active?
    │   ├─ NO  → return (false, "Subscription inactive")
    │   └─ YES ↓
    │
    ├─ Is not expired?
    │   ├─ NO  → return (false, "Subscription expired")
    │   └─ YES ↓
    │
    ├─ Check tier supports feature
    │   ├─ Free tier? ──→ NO EMAIL RECEIPTS
    │   │               return (false, "Feature requires Basic tier+")
    │   │
    │   ├─ Basic tier? ─→ YES, HAS ACCESS
    │   │               return (true, null)
    │   │
    │   ├─ Pro tier? ──→ YES, HAS ACCESS
    │   │               return (true, null)
    │   │
    │   └─ Enterprise? ─→ YES, HAS ACCESS
    │                   return (true, null)
    │
    ↓ SubscriptionFeatureGuard.logAccess()
    
    ↓ Return to screen
    
Screen receives: (true, null)
    ├─ TRUE  → Show email receipt UI
    └─ FALSE → Show upgrade dialog
    
┌─────────────────────────────────────────────────────────────┐
│                    Upgrade Dialog                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ❌ Email Receipts Not Available                           │
│                                                             │
│  This feature is available in Basic tier and above.        │
│  Your subscription: Free                                   │
│  Required: Basic                                           │
│                                                             │
│              [Cancel]  [Upgrade to Basic]                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Subscription Status State Machine

```
                    FREE (Initial State)
                           │
                           │ User upgrades
                           ↓
                    ┌─────────────┐
                    │   BASIC     │ (30 days from now)
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    (5 days)           (7 days)           (Renewal)
        │                  │                  │
        ↓                  ↓                  ↓
    EXPIRING        EXPIRING_SOON         RENEWED
    SOON (3-7d)     (0-3d)               (Reset: +30d)
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                    (Subscription expires)
                           ↓
                    ┌──────────────┐
                    │   EXPIRED    │
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    (Show Alert)    (Block Features)   (Renew)
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                    (User renews)
                           ↓
                    RENEWED → BASIC


States:
  FREE         → All basic features, no premium features
  BASIC        → Email receipts, advanced analytics
  PRO          → Multi-location, API access, payment processing
  TIER3   → Everything + white-label, SSO
  EXPIRED      → No premium features, show renewal prompt
  EXPIRING_SOON → Premium features work, show warning
  EXPIRING     → Premium features work, show urgent warning
```

---

## 5. Data Flow Diagram

```
┌──────────────────────────────────────────────────────────┐
│                   Data Sources                           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Firebase Firestore          Local Storage              │
│  (Single Source of Truth)     (Offline Cache)           │
│                                                          │
│  /businesses/{id}             SharedPreferences         │
│    ├─ subscriptionTier        ├─ cached_businesses     │
│    ├─ isActive                ├─ current_business      │
│    └─ endDate                 └─ last_sync             │
│                                                          │
│  /users/{id}                 Hive (Optional)            │
│    └─ subscription info       ├─ Business data        │
│                               └─ Sync status           │
│                                                          │
└────┬───────────────────────┬──────────────────────────┘
     │                       │
     │ (30 min check)        │ (Immediate access)
     ↓                       ↓
     
  BackgroundSubscriptionChecker.validateFeatureAccess()
     │                       │
     │ (Compare)             │ (Use cache)
     ├─ Remote vs Local      │
     ├─ Check Expiry         │
     └─ Update Cache ────────┼──→ Sync Cache
                             │
                             ↓
                      
  SubscriptionFeatureGuard
     │
     ├─ Check Tier
     ├─ Check Expiry
     ├─ Check Active
     └─ Allow/Deny Access
           │
           ├─ LOG ACCESS
           └─ Return Decision
                │
                ↓
           
  UI Layer
     ├─ Show Feature (if allowed)
     └─ Show Upgrade Dialog (if denied)
```

---

## 6. Offline vs Online Behavior

```
                    OFFLINE MODE
            (No network connection)
                       │
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
    Check Cache   Use Last   Graceful
    Status        Known      Fallback
                  Status
        │              │              │
        ├─ Cache       ├─ Valid?      ├─ No data
        │  Fresh?      │  ├─ YES      │  Show error
        │  ├─ YES      │  │  Allow    │  message
        │  │ Allow     │  │  Access   │
        │  │ Access    │  │           │
        │  │           │  └─ NO       │
        │  └─ NO       │     Block    │
        │    Block     │     Access   │
        │    Access    │              │
        │    (old)     │              │
        │              │              │
        └──────────────┼──────────────┘
                       │
                (Show offline indicator)
                       │
                       ↓
            ONLINE MODE
        (Network connection restored)
                       │
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
    Query        Update       Notify
    Firebase     Cache        UI
        │              │              │
        ├─ Get          ├─ If status  ├─ Refresh
        │  latest       │  changed    │  widgets
        │  status       │  call       │
        │               │  callback   │
        └───────┬───────┴──────┬─────┘
                │              │
                └──────────────┴──→ Resume normal operation
```

---

## 7. Feature Matrix Visualization

```
┌─────────────────────────────────────────────────────────────┐
│           Feature Access By Subscription Tier               │
├─────────────────────────────────────────────────────────────┤

                  FREE    BASIC    PRO    ENTERPRISE
                  ────    ─────    ───    ──────────

Basic Sales        ✓       ✓       ✓         ✓
Product Mgmt       ✓       ✓       ✓         ✓
Reports            ✓       ✓       ✓         ✓
────────────────────────────────────────────────────────

Unlimited Users    ✗       ✓       ✓         ✓
Advanced Analy.    ✗       ✓       ✓         ✓
Email Receipts     ✗       ✓       ✓         ✓
SMS Notifications  ✗       ✓       ✓         ✓
────────────────────────────────────────────────────────

Multi-Location     ✗       ✗       ✓         ✓
API Access         ✗       ✗       ✓         ✓
Payment Process.   ✗       ✗       ✓         ✓
Custom Reports     ✗       ✗       ✓         ✓
Priority Support   ✗       ✗       ✓         ✓
────────────────────────────────────────────────────────

White-Label        ✗       ✗       ✗         ✓
SSO Login          ✗       ✗       ✗         ✓
Dedicated Support  ✗       ✗       ✗         ✓
Custom Dev         ✗       ✗       ✗         ✓

Legend:
  ✓ = Feature available
  ✗ = Feature restricted
```

---

## 8. Integration Points

```
┌─────────────────────────────────────────────────────────────┐
│                   Integration Timeline                      │
├─────────────────────────────────────────────────────────────┘

POINT 1: App Initialization (main.dart)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  MultiProvider(                                            │
│    providers: [                                            │
│      ChangeNotifierProvider(                               │
│        create: (_) => EnhancedSubscriptionProvider()  ← ADD
│      ),                                                    │
│      // ... other providers                               │
│    ],                                                      │
│  )                                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘

POINT 2: Login Success (AuthProvider)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Future<void> _onLoginSuccess(UserModel user) async {    │
│    // ... existing login logic                             │
│                                                             │
│    subscriptionProvider.initializeForUser(user.id);   ← ADD
│  }                                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘

POINT 3: Feature Access (Any Screen)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  @override                                                 │
│  void initState() {                                        │
│    super.initState();                                      │
│    _checkFeatureAccess();  ← Call on init                  │
│  }                                                         │
│                                                             │
│  Future<void> _checkFeatureAccess() async {               │
│    final canAccess = await subscriptionProvider           │
│        .canAccessFeature(                                 │
│      business: currentBusiness,                           │
│      feature: 'email_receipts',                           │
│      context: 'email_screen',                             │
│    );                                                      │
│                                                             │
│    if (!canAccess) {                                       │
│      _showUpgradeDialog();  ← Show if denied              │
│    }                                                       │
│  }                                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘

POINT 4: Status Display (Dashboard)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Consumer<EnhancedSubscriptionProvider>(                   │
│    builder: (context, subscriptionProvider, _) {          │
│      final details = subscriptionProvider              ← Get
│          .getSubscriptionDetails(businessId);          │
│                                                        │
│      if (details?.needsAction ?? false) {              │
│        _showSubscriptionAlert();  ← Show alert         │
│      }                                                 │
│    },                                                  │
│  )                                                     │
│                                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Error Handling Flow

```
Try to Access Feature
    ↓
Call canAccessFeature()
    ↓
DECISION TREE:
    ├─ Subscription Inactive?
    │  ├─ YES → return (false, "Subscription inactive")
    │  └─ NO ↓
    │
    ├─ Subscription Expired?
    │  ├─ YES → return (false, "Subscription expired")
    │  └─ NO ↓
    │
    ├─ Tier has feature?
    │  ├─ NO → return (false, "Upgrade to X tier")
    │  └─ YES ↓
    │
    └─ ALLOW ACCESS → return (true, null)

Screen receives response:
    ├─ (true, null)
    │   ├─ Log: "Access granted"
    │   └─ Show: Feature UI
    │
    └─ (false, reason)
        ├─ Log: "Access denied: {reason}"
        └─ Show: Upgrade Dialog
            ├─ Title: Feature Not Available
            ├─ Reason: {reason}
            └─ CTA: Upgrade Plan


EXCEPTION HANDLING:
    ├─ Assert mode (assertFeatureAccess)
    │   └─ Throws: FeatureAccessDeniedException
    │
    └─ Query mode (canAccessFeature)
        └─ Returns: (false, errorMessage)
```

---

## 10. Cache Synchronization Flow

```
Local Cache                    Firebase
   │                              │
   │  ← 60 minutes old ────────→  │
   │  (needs refresh)             │
   │                              │
   ├─ subscriptionTier: "free"    │
   ├─ isActive: true              │
   └─ endDate: [60 days ago]      │
                                  │
                       (Background Check)
                                  │
                ┌─────────────────┴─────────────────┐
                ↓                                   ↓
            Query Firebase            (Remote data)
                                      │
                                      ├─ tier: "pro"
                                      ├─ active: true
                                      └─ endDate: [30 days]
                │
                │ (Difference detected!)
                ↓
            Update Local Cache
                │
                ├─ subscriptionTier: "pro" (CHANGED)
                ├─ isActive: true
                └─ endDate: [30 days] (CHANGED)
                │
                ├─ Set last_sync_time: NOW
                │
                ├─ Trigger callback:
                │   onSubscriptionStatusChanged(
                │     businessId: "biz-123",
                │     isValid: true
                │   )
                │
                └─ Notify listeners
                    │
                    └─ UI updates
                       ├─ Unlock new features
                       ├─ Show "Upgraded!" alert
                       └─ Refresh dashboard
```

---

## Summary

These diagrams show how the background subscription system:

1. **Continuously monitors** subscription status every 30 minutes
2. **Automatically enforces** feature access restrictions
3. **Seamlessly handles** offline scenarios with local cache
4. **Logs all access** attempts for compliance and debugging
5. **Provides clear** upgrade paths for users
6. **Scales efficiently** with minimal performance impact

The system is designed to be:
- **Transparent** - Works in background without user interaction
- **Reliable** - Handles network failures gracefully
- **Secure** - Enforces access at multiple levels
- **Efficient** - Uses caching to minimize Firebase calls
- **User-friendly** - Shows clear messages when access denied


