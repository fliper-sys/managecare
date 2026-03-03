# Drinks & Bar UI/UX - Visual Screen Guide

## Screen 1: Worker Onboarding (5 Pages)

```
┌─────────────────────────────┐
│  Worker Onboarding      [X] │
│                             │
│ ███░░░░░░░░░░░░░░░░░░░  20% │
│                             │
│         👋                  │
│   Welcome to the Bar!       │
│                             │
│ "Your role as a bartender   │
│  is crucial to our          │
│  operation."                │
│                             │
│ • Handle customer orders    │
│ • Process payments          │
│ • Manage inventory          │
│                             │
│    [Back]  [Next →]         │
└─────────────────────────────┘
```

**Page 1 (Welcome)** → **Page 2 (POS)** → **Page 3 (Flow)** → **Page 4 (Payment)** → **Page 5 (Tips)** → "Get Started"

---

## Screen 2: Bar POS - Menu View

```
┌────────────────────────────────┐
│ Bar POS System         Items: 3│
│                                │
│ [🔍 Search drinks by name... ✕]│
│                                │
│ ┌── Order Flow Progress ───┐   │
│ │ ①Select [●→→●→→○] ③Pay   │   │
│ └────────────────────────┘   │
│                                │
│ ┌──────────────┬──────────────┐│
│ │ 🍺 Guinness  │ 🍷 Red Wine  ││
│ │ ₦500         │ ₦450         ││
│ │ Available [2] │ Out [0]      ││
│ │ [-] [+]      │ [-] [+]      ││
│ └──────────────┴──────────────┘│
│ ┌──────────────┬──────────────┐│
│ │ 🍻 Beer      │ 🥃 Cocktail  ││
│ │ ₦350         │ ₦600         ││
│ │ Available [1] │ Available [3]││
│ │ [-] [+]      │ [-] [+]      ││
│ └──────────────┴──────────────┘│
│                                │
│ ┌────────────────────────────┐ │
│ │ Total: ₦2,450 [Review →] │ │
│ └────────────────────────────┘ │
└────────────────────────────────┘
```

---

## Screen 3: Cart Review View

```
┌────────────────────────────────┐
│ Cart Review           Items: 3 │
│                                │
│ Order #1701859200    [3 items] │
│                                │
│ ┌────────────────────────────┐ │
│ │🍺 Guinness Stout          │ │
│ │ x2 @ ₦500 = ₦1,000        │ │
│ │ [-]  2  [+]               │ │
│ └────────────────────────────┘ │
│ ┌────────────────────────────┐ │
│ │🍷 Red Wine Premium         │ │
│ │ x1 @ ₦450 = ₦450          │ │
│ │ [-]  1  [+]               │ │
│ └────────────────────────────┘ │
│ ┌────────────────────────────┐ │
│ │🥃 Margarita Cocktail       │ │
│ │ x3 @ ₦600 = ₦1,800        │ │
│ │ [-]  3  [+]               │ │
│ └────────────────────────────┘ │
│                                │
│ ╔════════════════════════════╗ │
│ ║ Subtotal: ₦3,250          ║ │
│ ║ Tax (0%): ₦0              ║ │
│ ║ Discount: ₦0              ║ │
│ ║────────────────────────────║ │
│ ║ TOTAL: ₦3,250             ║ │
│ ╚════════════════════════════╝ │
│                                │
│ [Proceed to Payment] [Clear]   │
└────────────────────────────────┘
```

---

## Screen 4: Checkout & Payment

```
┌────────────────────────────────┐
│ Checkout & Payment             │
│                                │
│ Order #1701859200              │
│ Dec 5, 2024 2:30 PM  [3 items] │
│                                │
│ ITEMS:                         │
│ 🍺 Guinness (x2) - ₦1,000     │
│ 🍷 Red Wine (x1) - ₦450       │
│ 🥃 Margarita (x3) - ₦1,800    │
│                                │
│ ┌──────────────────────────┐   │
│ │ Apply Discount           │   │
│ │ [₦____] -₦[0.00]        │   │
│ └──────────────────────────┘   │
│                                │
│ ┌──────────────────────────┐   │
│ │ Subtotal: ₦3,250         │   │
│ │ Tax (0%): ₦0             │   │
│ │ Discount: -₦0            │   │
│ │─────────────────────     │   │
│ │ TOTAL: ₦3,250           │   │
│ └──────────────────────────┘   │
│                                │
│ PAYMENT METHOD:                │
│ ◉ Cash                         │
│ ○ Debit/Credit Card           │
│ ○ Digital Wallet              │
│                                │
│ [Complete Payment - ₦3,250]    │
│ [Cancel]                       │
└────────────────────────────────┘
```

---

## Screen 5: Receipt Action Sheet

```
┌────────────────────────────────┐
│                                │
│ ✓ Payment Successful!          │
│                                │
│ Receipt Options:               │
│                                │
│ [🖨️  Print Receipt]            │
│ Send to thermal printer        │
│                                │
│ [📤 Share Receipt]             │
│ Share via WhatsApp/Social      │
│                                │
│ [📧 Email Receipt]             │
│ Send to customer email         │
│                                │
│ [Close]                        │
│                                │
└────────────────────────────────┘
```

---

## Screen 6: Drink Dashboard - Worker View

```
┌────────────────────────────────┐
│ Bar Management    [🎓] [👥]   │
│                                │
│ ┌──────────────────────────┐   │
│ │ 🍷 Ready to take orders? │   │
│ │   [Open Bar POS →]       │   │
│ └──────────────────────────┘   │
│                                │
│ ┌───────┬───────┬───────┬───┐ │
│ │💰 Sales│📝 Orders│⚠️ Low │🍸 │
│ │₦12.5K │   5   │  2   │ 15 │
│ │       │       │      │    │
│ └───────┴───────┴───────┴───┘ │
│                                │
│ Stock Overview:                │
│ 🍺 Guinness      12 bottles OK │
│ 🍷 Red Wine       6 bottles OK │
│ 🍻 Beer          3 bottles ⚠️ │
│ 🥃 Cocktail      8 bottles OK │
│                                │
└────────────────────────────────┘
```

---

## Screen 7: Drink Dashboard - Admin View

```
┌────────────────────────────────┐
│ Bar Management    [🎓] [👥]   │
│                                │
│ ┌───────┬───────┬───────┬───┐ │
│ │💰 Sales│📝 Orders│⚠️ Low │🍸 │
│ │₦12.5K │   5   │  2   │ 15 │
│ └───────┴───────┴───────┴───┘ │
│                                │
│ Quick Actions:                 │
│ ┌─────────┬─────────┐          │
│ │ 🔵 POS  │ 🟢 Inv  │          │
│ │ Open POS│Inventory│          │
│ ├─────────┼─────────┤          │
│ │ 🟠Drinks│ 🟣 Orders         │
│ │ Manage  │ View    │          │
│ └─────────┴─────────┘          │
│                                │
│ Stock Overview:                │
│ 🍺 Guinness    12 bottles OK   │
│ 🍷 Red Wine     6 bottles OK   │
│ 🍻 Beer        3 bottles ⚠️    │
│ 🥃 Cocktail    8 bottles OK    │
│                                │
└────────────────────────────────┘
```

---

## Order Flow - Complete Visual

```
START
  ↓
┌─────────────────────────────────┐
│ 1️⃣  MENU SELECTION (POS Screen) │
│                                 │
│ Search: [____Search drinks____] │
│                                 │
│ [Drink 1] [Drink 2]            │
│ [Drink 3] [Drink 4]            │
│                                 │
│ Progress: ①Select→→②Review→→③Pay │
│ Cart: 3 items │ Total: ₦3,250 │
│        [Review →]               │
└─────────────────────────────────┘
  ↓ User taps "Review Order"
┌─────────────────────────────────┐
│ 2️⃣  ORDER REVIEW (Cart View)    │
│                                 │
│ Order #1701859200   [3 items]   │
│                                 │
│ [Item 1] Qty: [-]2[+] ₦1,000   │
│ [Item 2] Qty: [-]1[+] ₦450     │
│ [Item 3] Qty: [-]3[+] ₦1,800   │
│                                 │
│ Summary: Subtotal ₦3,250        │
│          TOTAL: ₦3,250          │
│                                 │
│ Progress: ①Select→→②Review→→③Pay │
│ [Proceed to Payment] [Clear]    │
└─────────────────────────────────┘
  ↓ User taps "Proceed to Payment"
┌─────────────────────────────────┐
│ 3️⃣  CHECKOUT (Payment Screen)   │
│                                 │
│ Items Review:                   │
│ • Guinness (x2) - ₦1,000       │
│ • Red Wine (x1) - ₦450         │
│ • Margarita (x3) - ₦1,800      │
│                                 │
│ Discount: [₦____] Applied: ₦0  │
│                                 │
│ TOTAL: ₦3,250                   │
│                                 │
│ Payment:                        │
│ ◉ Cash  ○ Card  ○ Wallet       │
│                                 │
│ [Complete Payment - ₦3,250]     │
└─────────────────────────────────┘
  ↓ User taps "Complete Payment"
┌─────────────────────────────────┐
│ 4️⃣  RECEIPT & ACTIONS           │
│                                 │
│ ✅ Payment Successful!          │
│                                 │
│ Order #1701859200               │
│ Items: 3                        │
│ Amount: ₦3,250                  │
│ Method: Cash                    │
│                                 │
│ [🖨️  Print] [📤 Share] [📧 Email]│
│                                 │
│ ORDER SAVED ✓                   │
│ INVENTORY UPDATED ✓             │
│ RECEIPT PRINTED ✓               │
└─────────────────────────────────┘
  ↓ Success message shown
COMPLETE - Ready for next order ✅
```

---

## Color & Design System

### Colors:
- **Brown (#8D6E63)** - Primary action, headers
- **Green (#4CAF50)** - Success, payment, "Go" actions
- **Red (#F44336)** - Cancel, clear, warning
- **Orange (#FF9800)** - Low stock, warning
- **Blue (#2196F3)** - Info, secondary actions
- **White** - Background, cards
- **Grey (#757575)** - Secondary text

### Typography:
- **Heading 4/5** - Screen titles, section headers
- **Body 1/2** - Regular text, item names
- **Caption** - Small text, status labels

### Spacing:
- **16px** - Padding/margins
- **12px** - Inner card spacing
- **8px** - Between elements

---

## Responsive Design

```
PHONE (360px)        TABLET (600px)
┌──────────────┐    ┌─────────────────┐
│ Single Column│    │ Multi-column    │
│ Grid 1-col   │    │ Grid 2-col      │
│ Vertical     │    │ Can be wider    │
│ Stack        │    │                 │
└──────────────┘    └─────────────────┘
```

---

## Interactive Elements

### Buttons:
```
Default:                Active:
┌──────────────┐       ┌──────────────┐
│ [Button]     │       │ [Button]     │  ← Darker shade
└──────────────┘       └──────────────┘

Disabled:              Focus:
┌──────────────┐       ┌──────────────┐
│ [Button]     │       │ [Button]     │  ← Border highlight
└──────────────┘       └──────────────┘  (lighter shade)
```

### Cards:
```
Default:               Selected:
┌────────────────┐    ┌════════════════╗
│ Card Content   │    ║ Card Content   ║  ← Thick border
└────────────────┘    ╚════════════════╝  (highlight color)
```

---

## Accessibility Features

✓ Large touch targets (48px minimum)
✓ Clear color contrast (WCAG AAA)
✓ Clear labels on all buttons
✓ Icon + text combinations
✓ Readable font sizes (14px minimum)
✓ Logical tab order
✓ Error message clarity

---

This visual guide shows the complete Drinks/Bar UI/UX implementation
with clear screen layouts, order flow progression, and design system.
All screens are labeled, intuitive, and production-ready! 🎉

