# Post-Sale Action Sheet & Printer UI - Visual Guide

## 1. Post-Sale Action Sheet (Bottom Sheet Modal)

### Appearance After Sale

```
┌─────────────────────────────────────┐
│ Receipt Actions               [×]   │  ← Header with close button
├─────────────────────────────────────┤
│                                     │
│  ✓ Receipt shared!                 │  ← Status message (green)
│  Shared successfully to apps        │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  [↗ Share]  [✉ Email]              │  ← Action buttons (row 1)
│                                     │
│  [🖨 Print (Bluetooth)]             │  ← Action button (full width)
│                                     │
│  [Done]                            │  ← Close button
│                                     │
└─────────────────────────────────────┘
```

### Action Button States

**Idle State** (tappable):
```
[↗ Share]  [✉ Email]
[🖨 Print (Bluetooth)]
```

**Loading State** (disabled, dimmed):
```
[↗ Share]  [✉ Email]    ← disabled (gray)
[🖨 Print (Bluetooth)]   ← disabled (gray)
```

### Status Messages

**Success** (Green):
```
✓ Receipt shared!
✓ Receipt emailed!
✓ Receipt printed!
```

**Error** (Red):
```
✗ Share failed
✗ Email send failed
✗ Print failed
✗ No printer configured
```

**Warning** (Orange):
```
⚠ Email receipts are a Pro feature
⚠ No recipient email available
```

---

## 2. Printer Connection Screen

### Main Screen Layout

```
┌──────────────────────────────────────┐
│ ← Connect Thermal Printer      [Settings icon] │
├──────────────────────────────────────┤
│                                      │
│ Setup Guide                  [Toggle ON]  │
│                                      │
├──────────────────────────────────────┤
│                                      │
│ 📘 How to Connect Your...            │
│                                      │
│ 1️⃣ Enable Bluetooth                  │
│    "Ensure Bluetooth is enabled..."  │
│                                      │
│ 2️⃣ Pair Printer                      │
│    "Go to device Bluetooth settings.." │
│                                      │
│ 3️⃣ Scan Here                         │
│    "Return to this app and tap..."   │
│                                      │
│ 4️⃣ Select & Connect                  │
│    "Select your printer..."          │
│                                      │
├──────────────────────────────────────┤
│ [🔍 Scan for Printers]               │
│                                      │
├──────────────────────────────────────┤
│ Available Printers                   │
│                                      │
│ ◯ Thermal Printer 1                  │
│   MAC: 00:1A:7D:DA:71:13             │
│                                      │
│ ◯ Thermal Printer 2                  │
│   MAC: 00:1A:7D:DA:71:14             │
│                                      │
│ ◯ Receipt Printer                    │
│   MAC: 00:1A:7D:DA:71:15             │
│                                      │
├──────────────────────────────────────┤
│ [🖨 Connect & Test]                  │
│                                      │
└──────────────────────────────────────┘
```

### Tutorial Section (Expanded)

```
┌──────────────────────────────────────┐
│ 📘 How to Connect Your Thermal       │
│    Printer                           │
│                                      │
│ 1️⃣ Enable Bluetooth                  │
│    Ensure Bluetooth is enabled on    │
│    your device and the printer is    │
│    powered on.                       │
│                                      │
│ 2️⃣ Pair Printer                      │
│    Go to your device's Bluetooth     │
│    settings and pair with your       │
│    thermal printer. (Device will     │
│    appear as "Thermal Printer"...)   │
│                                      │
│ 3️⃣ Scan Here                         │
│    Return to this app and tap        │
│    "Scan for Printers" to discover   │
│    paired devices.                   │
│                                      │
│ 4️⃣ Select & Connect                  │
│    Select your printer from the      │
│    list and tap "Connect & Test".    │
│    The printer will print a test     │
│    receipt.                          │
│                                      │
└──────────────────────────────────────┘
```

### Scanning State

```
┌──────────────────────────────────────┐
│ ← Connect Thermal Printer            │
├──────────────────────────────────────┤
│                                      │
│ 🔄 Scanning for Bluetooth printers...│
│                                      │
│              [loading spinner]       │
│                                      │
│ Please wait...                       │
│                                      │
└──────────────────────────────────────┘
```

### After Scan - Printer Selection

```
┌──────────────────────────────────────┐
│                                      │
│ ✓ Found 3 printers                  │
│                                      │
├──────────────────────────────────────┤
│                                      │
│ Available Printers                   │
│                                      │
│ ◉ Thermal Printer 1  ← Selected      │
│   MAC: 00:1A:7D:DA:71:13             │
│                                      │
│ ◯ Thermal Printer 2                  │
│   MAC: 00:1A:7D:DA:71:14             │
│                                      │
│ ◯ Receipt Printer                    │
│   MAC: 00:1A:7D:DA:71:15             │
│                                      │
├──────────────────────────────────────┤
│ [🖨 Connect & Test]                  │
│                                      │
└──────────────────────────────────────┘
```

### Connection Test - Success

```
┌──────────────────────────────────────┐
│                                      │
│ ✓ Printer connected and saved!       │ ← Green status
│   Configuration saved to your        │
│   business profile.                  │
│                                      │
├──────────────────────────────────────┤
│                                      │
│ Available Printers                   │
│                                      │
│ ◉ Thermal Printer 1                  │
│   MAC: 00:1A:7D:DA:71:13             │
│   (Currently Connected)              │
│                                      │
│ ◯ Thermal Printer 2                  │
│   MAC: 00:1A:7D:DA:71:14             │
│                                      │
├──────────────────────────────────────┤
│ [🖨 Connect & Test]                  │
│                                      │
└──────────────────────────────────────┘
```

### Connection Test - Failure

```
┌──────────────────────────────────────┐
│                                      │
│ ✗ Connection test failed             │ ← Red status
│   Ensure printer is on and in        │
│   pairing mode.                      │
│                                      │
├──────────────────────────────────────┤
│                                      │
│ Available Printers                   │
│                                      │
│ ◯ Thermal Printer 1                  │
│   MAC: 00:1A:7D:DA:71:13             │
│                                      │
│ ◯ Thermal Printer 2                  │
│   MAC: 00:1A:7D:DA:71:14             │
│                                      │
├──────────────────────────────────────┤
│ [🖨 Connect & Test]                  │
│                                      │
└──────────────────────────────────────┘
```

---

## 3. Business Settings Screen - Printer Setup

### Settings Screen with Printer Section

```
┌──────────────────────────────────────┐
│ ← Business Settings          [menu]  │
├──────────────────────────────────────┤
│                                      │
│ [Business Photo Upload UI]           │
│                                      │
│ Business Information                 │
│ [Business Name field]                │
│ [Address field]                      │
│ [Phone field]                        │
│                                      │
│ Tax & Registration                   │
│ [Registration field]                 │
│ [Tax ID field]                       │
│                                      │
│ Preferences                          │
│ [Notifications toggle]               │
│ [Offline Mode toggle]                │
│ [Auto Backup toggle]                 │
│                                      │
│ Business Details                     │
│ Business Type: Retail                │
│ Subscription: PROFESSIONAL           │
│ Registered: 15/11/2024               │
│                                      │
│ Printer Setup                        │
│ [🖨 Configure Thermal Printer] ← NEW │
│                                      │
│ [Save Settings]                      │
│                                      │
│ ─────────────────────────────────    │
│ Danger Zone                          │
│ [Delete Business]                    │
│                                      │
└──────────────────────────────────────┘
```

---

## 4. Receipt Flow Sequence

### Complete Sale → Action Sheet → User Choice

**Step 1: Checkout Completed**
```
User taps "Confirm Sale" in POS/Restaurant/etc.
        ↓
ReceiptManager.handlePostSale() is called
        ↓
Receipt text is generated with all details
```

**Step 2: Action Sheet Appears**
```
┌─────────────────────────────────────┐
│ Receipt Actions               [×]   │
├─────────────────────────────────────┤
│                                     │
│  [↗ Share]  [✉ Email]              │
│                                     │
│  [🖨 Print (Bluetooth)]             │
│                                     │
│  [Done]                            │
│                                     │
└─────────────────────────────────────┘
```

**Step 3: User Selects Action**

- **Share**: Opens native share dialog
  ```
  More ⋯
  - Copy to clipboard
  - Messages
  - Email
  - WhatsApp
  - Etc.
  ```

- **Email** (Pro only): Sends to customer
  ```
  ✓ Receipt emailed to customer@example.com
  ```

- **Print**: Connects to printer
  ```
  Connecting to thermal printer...
  ✓ Receipt printed!
  ```

**Step 4: User Closes Sheet**
```
Taps [Done] or back arrow
        ↓
Action sheet closes
        ↓
Returns to main POS screen
```

---

## 5. Color Scheme

### Button Colors

| Element | Color | Hex |
|---------|-------|-----|
| Primary Button (Share) | Blue | #007AFF |
| Secondary Button (Email) | Purple | #AF52DE |
| Success Button (Print) | Green | #34C759 |
| Disabled State | Gray | #D1D1D6 |

### Status Message Colors

| Status | Color | Icon |
|--------|-------|------|
| Success | Green | ✓ |
| Error | Red | ✗ |
| Warning | Orange | ⚠ |
| Info | Blue | ℹ |

### Status Message Backgrounds

| State | Background | Border |
|-------|-----------|--------|
| Success | Green 10% | Green |
| Error | Red 10% | Red |
| Warning | Orange 10% | Orange |
| Info | Blue 10% | Blue |

---

## 6. Animations & Transitions

### Sheet Entry
- Slides up from bottom (300ms ease-out)
- Status message fades in
- Buttons are immediately interactive

### Button Press
- Ripple effect on tap
- Button becomes disabled (grayed out)
- Spinning loader appears

### Status Update
- Previous message fades out (200ms)
- New message fades in (200ms)
- Color changes instantly
- Icon updates

### Sheet Exit
- User taps [Done] or X
- Sheet slides down (200ms ease-in)
- Returns to POS screen

---

## 7. Receipt Template Example

```
ACME RETAIL STORE
123 Main Street
Tel: (555) 123-4567
────────────────────────────
Order ID: ORD-20241130-12345
Date: 30/11/2024
Time: 14:35:22
Cashier: John Smith
────────────────────────────

Product A x2            $20.00
Product B x1            $15.50
Product C x3            $45.00

────────────────────────────
TOTAL               $80.50
Payment: Card
────────────────────────────

Thank you for your purchase!

Bank: First National Bank
A/C: 1234567890

ACME RETAIL STORE

```

---

## 8. Error States & Messages

### No Printer Configured
```
Status: ⚠ Orange
Message: "No printer configured"
Action: Tap "Configure Thermal Printer" in Settings
```

### No Customer Email (for Email action)
```
Status: ⚠ Orange
Message: "No recipient email available"
Action: Manually select from contacts or save customer email
```

### Pro Feature Locked
```
Status: ⚠ Orange
Message: "Email receipts are a Pro feature"
Action: Show upgrade button to Pro plan
```

### Printer Connection Failed
```
Status: ✗ Red
Message: "Connection test failed"
Action: Check printer is on/in pairing mode, retry
```

### Bluetooth Permission Denied
```
Status: ✗ Red
Message: "Bluetooth permission denied"
Action: Go to Settings > Permissions > Grant Bluetooth
```

---

## 9. Accessibility Features

### Screen Reader Support
- Action buttons labeled: "Share receipt via messaging", "Email receipt to customer", "Print receipt on thermal printer"
- Status messages announced
- Color not sole indicator (icons used)

### Touch Targets
- Minimum 44x44 pt for all buttons
- Adequate spacing between interactive elements
- Large radio buttons for printer selection

### High Contrast
- Text meets WCAG AA standards
- Color palette supports colorblind users
- Icons paired with text labels

---

## 10. Responsive Design

### Phone (narrow) - Default
```
Full width buttons stacked
Share and Email side-by-side in grid
Print full width below
```

### Tablet (wide) - Optional future enhancement
```
Could expand buttons horizontally
Share | Email | Print in single row
Printer list in 2-column grid
```

