# Quick Start Guide - Drinks/Bar Domain

## 🎯 What's New

A complete Drinks/Bar POS system with:
- ✅ Worker onboarding training
- ✅ Clear order flow (Select → Review → Pay)
- ✅ Smart checkout & payments
- ✅ Receipt printing integration
- ✅ Role-based dashboards

---

## 🚀 Getting Started

### For Bar Workers (First Time):

**Step 1: Complete Training**
```
Dashboard → Tap "Worker Training" button
          → Go through 5 training steps
          → Tap "Get Started"
```

**Step 2: Open POS**
```
Dashboard → Tap "Open Bar POS" button
         OR → Tap "Ready to take orders?" card
```

**Step 3: Take an Order**
```
1. Search for drinks or browse menu grid
2. Tap any drink card to add to cart
3. Use +/- buttons to adjust quantity
4. View cart count in top-right corner
```

**Step 4: Review Order**
```
1. Tap "Review Order" button (bottom)
2. See full item breakdown
3. Check quantities and prices
4. Tap "Proceed to Payment"
```

**Step 5: Select Payment**
```
1. Choose payment method:
   - Cash
   - Debit/Credit Card
   - Digital Wallet
2. (Optional) Apply discount in the discount field
3. Review total amount
```

**Step 6: Complete Payment**
```
1. Tap "Complete Payment"
2. Order is saved to system
3. Stock is automatically updated
4. Receipt printing options appear
5. Choose: Print, Share, or Email
```

---

### For Bar Managers/Admins:

**Dashboard View:**
```
Hero Metrics:
├─ Total Sales (₦)
├─ Open Orders (#)
├─ Low Stock Items (#)
└─ Total Drinks (#)

Quick Actions:
├─ POS (Open bar operations)
├─ Inventory (Check stock)
├─ Manage Drinks (CRUD operations)
└─ Orders (View all orders)

Stock Overview:
└─ Real-time inventory list
```

**Manage Workers:**
```
Dashboard → Tap "Manage Workers" (top-right)
         → View all workers
         → Assign roles
         → Track performance
```

---

## 📱 Screen Components

### Bar POS Screen
```
┌─ AppBar: "Bar POS System" + Item Count ─┐
├─ Order Flow Progress (1→2→3)            │
├─ Search Bar                              │
├─ Menu Grid (2 columns)                   │
│  ├─ Drink cards with:                   │
│  │  ├─ Image
│  │  ├─ Name
│  │  ├─ Price
│  │  ├─ Stock status
│  │  └─ +/- buttons
│  └─ Quantity badge on selected items
└─ Bottom Bar: Total + Review Button ──────┘
```

### Order Review View
```
┌─ Order Header #[ID] ────────────────┐
├─ Item Count Chip                    │
├─ Each Item:                         │
│  ├─ Drink Image
│  ├─ Name + Qty × Price
│  ├─ Line Total
│  └─ Quantity controls
├─ Order Summary:                     │
│  ├─ Subtotal
│  ├─ Discount field
│  ├─ Tax (0%)
│  └─ TOTAL (highlighted)
├─ "Proceed to Payment" (Green)       │
└─ "Clear Order" (Red)                │
```

### Checkout Screen
```
┌─ Processing Payment / Full Details ────┐
├─ Order Summary Card                    │
├─ All Items with Images                 │
├─ Discount Section (Optional)           │
├─ Price Breakdown                       │
├─ Payment Method Selection:             │
│  ├─ Cash
│  ├─ Card
│  └─ Digital Wallet
└─ Complete Payment Button               │
```

---

## 💡 Pro Tips

1. **Use Search:**
   - Tap search bar and type drink name
   - Much faster than scrolling menu

2. **Quantity Control:**
   - Single tap: Add 1 bottle
   - Multiple taps: Build quantity quickly
   - Minus button: Reduce quantity

3. **Cart Preview:**
   - Check item count in top-right
   - Tap "Review Order" anytime to see details
   - Allows changes before payment

4. **Discounts:**
   - Apply in checkout screen
   - Real-time total recalculation
   - Auto-caps at subtotal

5. **Receipt Options:**
   - Print: Thermal printer (if connected)
   - Share: Via WhatsApp/social
   - Email: Send digital copy

6. **Stock Monitoring:**
   - Dashboard shows low stock items
   - "Low Stock" badge in inventory
   - Red indicator on out-of-stock drinks

---

## ⚠️ Common Scenarios

### Scenario 1: Customer Changes Order
**Solution:**
1. In Review view, adjust quantities
2. Add/remove items
3. Tap back if you want to add more items
4. Only proceed when order is correct

### Scenario 2: Need to Apply Discount
**Solution:**
1. Get to Checkout screen
2. In "Apply Discount" field, enter amount
3. Total recalculates automatically
4. Confirm before payment

### Scenario 3: Wrong Item Added
**Solution:**
1. In Review view, find the item
2. Tap the minus button to reduce quantity
3. When quantity reaches 0, item is removed
4. OR tap "Clear Order" to start over

### Scenario 4: Stock Run Out During Order
**Solution:**
1. System shows "Out" status on menu
2. Cards for out-of-stock items are disabled
3. Cannot add them to cart
4. Check dashboard for low stock alerts

### Scenario 5: Payment Fails
**Solution:**
1. Error message displayed
2. Order not persisted
3. Can retry or choose different payment method
4. Or cancel and start new order

---

## 🔄 Order States

```
Cart Building
    ↓ (Add items)
Review & Adjust
    ↓ (Verify amounts)
Select Payment
    ↓ (Choose method)
Processing...
    ↓ (Creating order)
Receipt Printing
    ↓ (Print/Share/Email)
✅ COMPLETE
```

---

## 📊 Real-Time Updates

The system automatically:
- ✅ Updates inventory (stock count decreases)
- ✅ Saves order to Firestore
- ✅ Calculates totals
- ✅ Generates receipt data
- ✅ Updates dashboard metrics
- ✅ Caches images for speed

---

## 🎓 Training Path

New workers should:
1. Access **Worker Training** screen
2. Complete all 5 steps:
   - Welcome & orientation
   - POS system features
   - Order flow walkthrough
   - Payment methods
   - Best practices & tips
3. Practice on test orders
4. Complete with supervisor

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| App crashes | Check order has items before checkout |
| Images don't load | Check internet; cached images auto-load |
| Receipt won't print | Check printer connection; try Share instead |
| Cart not updating | Refresh by going back to menu |
| Stock not showing | Ensure inventory is populated in admin |
| Worker can't see POS | Check user role is set to 'worker' |

---

## 📞 Support Flow

1. **Technical Issue?**
   - Check troubleshooting table above
   - Restart app
   - Check internet connection

2. **Training Question?**
   - Tap "Worker Training" again
   - Review the specific step
   - Ask supervisor

3. **System Issue?**
   - Note error message
   - Check timestamp
   - Report to IT with details

---

## ✅ Checklist Before First Order

- [ ] Logged in with correct account
- [ ] Inventory is populated (dashboard shows drinks)
- [ ] Payment methods configured
- [ ] Printer connected (if printing receipts)
- [ ] Internet connection active
- [ ] Completed worker training

**Ready to go! 🎉**

---

## 📈 Performance Tips

1. **App Speed:**
   - Images are cached locally
   - First load may be slower (building cache)
   - Subsequent loads are instant

2. **Accuracy:**
   - Always review order before payment
   - Double-check quantities
   - Verify payment amount

3. **Efficiency:**
   - Search for drinks instead of scrolling
   - Use keyboard shortcuts (if available)
   - Batch similar orders

---

## 🔐 Security Reminders

1. **Never** share your login credentials
2. **Always** log out when leaving terminal
3. **Verify** customer before payment
4. **Confirm** order details before printing
5. **Report** suspicious activity

---

**Version:** 1.0.0  
**Last Updated:** December 5, 2025  
**Status:** ✅ Ready for Production

