# Phase 3 Visual Implementation Guide

## 🎬 User Navigation Flow

```
Settings Screen
│
├─→ Currency Management
│   ├─ Currencies Tab
│   │  ├─ List Currencies
│   │  ├─ Add Currency (FAB)
│   │  └─ Set as Default
│   └─ Exchange Rates Tab
│      ├─ List Rates
│      ├─ Add Rate
│      └─ Update Expired Rates
│
├─→ Notification Preferences
│   ├─ Notification Channels
│   │  ├─ Push Toggle
│   │  ├─ Email Toggle
│   │  ├─ SMS Toggle
│   │  └─ In-App Toggle
│   ├─ Notification Types
│   │  ├─ Sales Alerts
│   │  ├─ Inventory Alerts
│   │  ├─ Payment Alerts
│   │  ├─ Customer Alerts
│   │  └─ System Alerts
│   ├─ Quiet Hours
│   │  ├─ Enable/Disable
│   │  ├─ Start Time Picker
│   │  └─ End Time Picker
│   └─ Notification Frequency
│      ├─ Real-time
│      ├─ Hourly Digest
│      └─ Daily Digest
│
├─→ Backup & Restore
│   ├─ Create Backup Tab
│   │  ├─ Select Backup Items
│   │  │  ├─ Business Data
│   │  │  ├─ Sales Records
│   │  │  ├─ Inventory
│   │  │  ├─ Customers
│   │  │  ├─ Reports
│   │  │  └─ Settings
│   │  ├─ Choose Destination
│   │  │  ├─ Local Storage
│   │  │  ├─ Cloud (Firebase)
│   │  │  └─ Both
│   │  └─ Create Backup Button
│   └─ Backups List Tab
│      ├─ List All Backups
│      ├─ View Backup Details
│      ├─ Restore Backup
│      └─ Delete Backup
│
└─ Other existing Settings...
```

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                   │
├─────────────────────────────────────────────────────────┤
│  Currency        Notification        Backup             │
│  Management  +   Preferences    +    & Restore     +    │
│  Screen          Screen             Screen        Settings│
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  STATE MANAGEMENT LAYER                 │
├─────────────────────────────────────────────────────────┤
│  CurrencyProvider + NotificationProvider +              │
│  BackupProvider + SettingsProvider                      │
│  (Using Provider package - ChangeNotifier)              │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   SERVICES LAYER                        │
├─────────────────────────────────────────────────────────┤
│  Backup Service + Cloud Storage Service +               │
│  Currency Service + Notification Service                │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   DATA LAYER                            │
├─────────────────────────────────────────────────────────┤
│  Firestore     +  Firebase       +  SharedPreferences   │
│  Collections     Cloud Storage       (Local Storage)    │
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────┐   │
│  │Currencies│   │Backups   │   │Notification      │   │
│  │Exchange  │   │Backup    │   │Settings          │   │
│  │Rates     │   │Data      │   │App Preferences   │   │
│  └──────────┘   └──────────┘   └──────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 📊 Data Flow Diagrams

### Currency Management Flow
```
User Action
    │
    ├─ Add Currency
    │   │
    │   └─→ Dialog Form ──→ Validation ──→ CurrencyProvider
    │                                            │
    │                                            ├─→ Save to Firestore
    │                                            │
    │                                            └─→ Update UI
    │
    ├─ Set as Default
    │   │
    │   └─→ CurrencyProvider.setDefaultCurrency()
    │                    │
    │                    ├─→ Update Local List
    │                    ├─→ Save to Firestore
    │                    └─→ Refresh UI
    │
    └─ View Exchange Rates
        │
        └─→ Display Rates ──→ Check Expiration ──→ Show Status
```

### Notification Settings Flow
```
User Changes Setting
    │
    └─→ Provider Setter Called (e.g., setSalesAlerts(bool))
            │
            ├─→ Update internal state
            ├─→ Save to SharedPreferences
            ├─→ Call notifyListeners()
            │
            └─→ UI Updates via Consumer Widget
```

### Backup Flow
```
Create Backup
    │
    ├─→ Select Backup Items
    ├─→ Choose Destination
    ├─→ Tap "Create Backup"
    │   │
    │   └─→ Confirmation Dialog
    │       │
    │       └─→ User Confirms
    │           │
    │           └─→ BackupProvider.createBackup()
    │               │
    │               ├─→ Show Loading Indicator
    │               ├─→ Gather Data from Firestore
    │               ├─→ Compress Data
    │               ├─→ Save Locally (if selected)
    │               ├─→ Upload to Cloud (if selected)
    │               ├─→ Create Backup Record
    │               ├─→ Hide Loading Indicator
    │               │
    │               └─→ Show Success Snackbar
    │
    └─→ Backup appears in Backups List
```

## 📱 Screen Component Structure

### Currency Management Screen
```
CurrencyManagementScreen
├─ AppBar
├─ TabBar
│  ├─ "Currencies" Tab
│  └─ "Exchange Rates" Tab
│
├─ TabBarView
│  ├─ Currencies Tab Content
│  │  ├─ FloatingActionButton (Add)
│  │  └─ ListView
│  │     └─ CurrencyCard (multiple)
│  │        ├─ Code & Name
│  │        ├─ Symbol
│  │        ├─ Decimal Places
│  │        ├─ Default Badge
│  │        └─ Make Default Button
│  │
│  └─ Exchange Rates Tab Content
│     ├─ ListView
│     │  └─ RateCard (multiple)
│     │     ├─ Currency Pair
│     │     ├─ Rate Value
│     │     ├─ Expiry Date
│     │     ├─ Expired Badge
│     │     └─ Update Button
│     │
│     └─ Empty State (if no rates)
│
└─ Dialogs
   ├─ Add Currency Dialog
   │  ├─ Code TextField
   │  ├─ Name TextField
   │  ├─ Symbol TextField
   │  ├─ Decimal Places TextField
   │  └─ Buttons (Cancel, Add)
   │
   └─ Add Rate Dialog
      ├─ Base Currency Dropdown
      ├─ Target Currency Dropdown
      ├─ Rate TextField
      ├─ Validity Days TextField
      └─ Buttons (Cancel, Add)
```

### Notification Preferences Screen
```
NotificationPreferencesScreen
├─ AppBar
├─ SingleChildScrollView
│
├─ Notification Channels Section
│  ├─ Push Notifications Switch
│  ├─ Email Notifications Switch
│  ├─ SMS Notifications Switch
│  └─ In-App Notifications Switch
│
├─ Notification Types Section
│  ├─ Sales Alerts Toggle + Description
│  ├─ Inventory Alerts Toggle + Description
│  ├─ Payment Alerts Toggle + Description
│  ├─ Customer Alerts Toggle + Description
│  └─ System Alerts Toggle + Description
│
├─ Quiet Hours Section
│  ├─ Enable Quiet Hours Switch
│  ├─ (If Enabled)
│  │  ├─ Start Time Picker
│  │  └─ End Time Picker
│  │
│  └─ (Visual: Time Range Display)
│
└─ Notification Frequency Section
   ├─ Real-time Option (Radio)
   ├─ Hourly Digest Option (Radio)
   └─ Daily Digest Option (Radio)
```

### Backup & Restore Screen
```
BackupAndRestoreScreen
├─ AppBar
├─ TabBar
│  ├─ "Create Backup" Tab
│  └─ "Backups" Tab
│
├─ TabBarView
│  ├─ Create Backup Tab
│  │  ├─ "What to backup" Section
│  │  │  ├─ Business Data Checkbox
│  │  │  ├─ Sales Records Checkbox
│  │  │  ├─ Inventory Checkbox
│  │  │  ├─ Customers Checkbox
│  │  │  ├─ Reports Checkbox
│  │  │  └─ Settings Checkbox
│  │  │
│  │  ├─ "Backup Destination" Section
│  │  │  ├─ Local Storage Radio
│  │  │  ├─ Cloud (Firebase) Radio
│  │  │  └─ Both Radio
│  │  │
│  │  └─ (If Backing Up)
│  │     ├─ Loading Indicator
│  │     └─ "Creating backup..." Text
│  │
│  │  (Or)
│  │  └─ Create Backup Button
│  │
│  └─ Backups List Tab
│     ├─ ListView
│     │  └─ BackupCard (multiple)
│     │     ├─ Backup Name
│     │     ├─ Created Date/Time
│     │     ├─ Size
│     │     ├─ Destination Badge
│     │     ├─ Restore Button
│     │     └─ Delete Button
│     │
│     └─ Empty State (if no backups)
│
└─ Dialogs
   ├─ Backup Confirmation Dialog
   ├─ Restore Confirmation Dialog
   └─ Delete Confirmation Dialog
```

## 🔄 State Management Flow

### Using Provider Pattern
```
UI Component
    │
    ├─ Read: context.read<ProviderName>()
    │         └─ Access data once
    │
    ├─ Watch: context.watch<ProviderName>()
    │         └─ Rebuild when data changes
    │
    └─ Consumer<ProviderName>(
        builder: (context, provider, child) {
            // Rebuilt whenever provider updates
        }
    )
```

### Provider State Update Cycle
```
User Interaction
    │
    ├─→ Provider Method Called
    │   (e.g., addCurrency())
    │
    ├─→ State Updated
    │   _currencies.add(newCurrency)
    │
    ├─→ notifyListeners() Called
    │   provider.notifyListeners()
    │
    ├─→ Consumer Widgets Rebuild
    │   build() called with new state
    │
    └─→ UI Updated on Screen
```

## 📦 Import Structure

```
Presentation Layer
├─ import 'package:provider/provider.dart'
├─ import 'package:flutter/material.dart'
├─ import '../../../providers/currency_provider.dart'
├─ import '../../../providers/notification_provider.dart'
├─ import '../../../providers/backup_provider.dart'
├─ import '../../../core/theme/colors.dart'
├─ import '../../../core/theme/text_styles.dart'
└─ import '../../../widgets/custom_app_bar.dart'

Provider Layer
├─ import 'package:flutter/material.dart'
├─ import 'package:cloud_firestore/cloud_firestore.dart'
├─ import 'package:shared_preferences/shared_preferences.dart'
└─ models for Currency, CurrencyRate, Backup, etc.

Service Layer
├─ import 'package:firebase_storage/firebase_storage.dart'
├─ import 'package:cloud_firestore/cloud_firestore.dart'
├─ import 'package:path_provider/path_provider.dart'
└─ other dependencies
```

## 🎨 Design Tokens

### Color Usage
```
Primary Color (Blue)
├─ Buttons
├─ Icons
└─ Highlights

Success Color (Green)
├─ Default badges
├─ Success messages
└─ Active toggles

Error Color (Red)
├─ Expired status
├─ Delete buttons
└─ Error messages

Surface Color
├─ Cards
├─ Dialogs
└─ Backgrounds

Text Colors
├─ Primary: Main text
├─ Secondary: Subtitles
└─ Tertiary: Hints
```

### Spacing Scale
```
xs: 4px
sm: 8px
md: 12px
lg: 16px
xl: 24px
2xl: 32px
```

### Typography
```
Display: Headlines
Headline: Large titles
Title: Section headers
Body: Main content
Label: Small text
Caption: Smallest text
```

## 🧪 Testing Pyramid

```
         ┌─────────────────┐
         │  E2E Tests      │  (5%)
         │  Full workflows │
         └─────────────────┘
                ▲
        ┌───────────────────┐
        │ Integration Tests │  (20%)
        │ Provider + Screens│
        └───────────────────┘
             ▲
    ┌────────────────────────┐
    │  Widget Tests          │  (25%)
    │  Screen rendering      │
    └────────────────────────┘
       ▲
    ┌──────────────────┐
    │  Unit Tests      │  (50%)
    │  Providers       │
    │  Services        │
    │  Models          │
    └──────────────────┘
```

## 🔗 Component Dependencies

```
CurrencyManagementScreen
├─ CurrencyProvider
├─ Currency Model
├─ CurrencyRate Model
└─ Custom AppBar

NotificationPreferencesScreen
├─ NotificationProvider
└─ Custom AppBar

BackupAndRestoreScreen
├─ BackupProvider
├─ Backup Model
└─ Custom AppBar

SettingsScreen (Updated)
├─ All three new screens (navigation)
├─ AuthProvider
├─ BusinessProvider
├─ ThemeProvider
└─ Settings helpers
```

## 📈 Implementation Dependency Order

```
Phase 1: Models
├─ Currency
├─ CurrencyRate
├─ Backup
└─ Backup selections

Phase 2: Providers
├─ CurrencyProvider (uses models)
├─ NotificationProvider
├─ BackupProvider (uses models)
└─ SettingsProvider

Phase 3: Services
├─ BackupService (uses BackupProvider)
├─ CloudStorageService (uses FirebaseStorage)
├─ CurrencyService (uses CurrencyProvider)
└─ NotificationService

Phase 4: Integration
├─ Wire providers to screens
├─ Test all workflows
├─ Optimize performance
└─ Document usage
```

## ✨ Performance Optimization Points

```
UI Rendering
├─ Use Consumer sparingly
├─ Separate read and watch
└─ Use const constructors

Data Loading
├─ Lazy load backups list
├─ Cache exchange rates
└─ Paginate long lists

Storage Operations
├─ Batch Firestore operations
├─ Compress backup data
└─ Implement cleanup for old backups
```

---

This visual guide helps understand the complete architecture and data flow of Phase 3 implementation.

