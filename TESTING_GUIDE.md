# Complete Features Testing Guide

## Quick Test Checklist

### 1. Export Sales History Feature ✓

**Screen:** Settings → Export Sales History

**Test Steps:**
1. Open the Export Sales History screen
2. Select date range (e.g., last 30 days)
3. Choose export format:
   - [ ] CSV format
   - [ ] JSON format
   - [ ] TSV format
4. Enable "Include Images" option
5. Enable "Auto Backup" toggle
6. Click "Export Now" button
7. Verify success message appears
8. Check file was created in app documents
9. Test "Export & Share" to share file
10. Test "Generate Report" for statistics

**Expected Results:**
- File created in temp directory
- Success SnackBar displayed
- File size shows in UI
- Record count displays correctly

---

### 2. Printer Configuration Feature ✓

**Screen:** Settings → Printer Settings

**Test Steps:**
1. Select printer model (Thermal/Inkjet/Network)
2. Choose connection type (Bluetooth/USB/WiFi/LAN)
3. Set paper width (80mm default)
4. Add header text: "My Business Name"
5. Add footer text: "Thank you for your business!"
6. Click "Test Connection" button
7. Verify connection status
8. Click "Save Settings" button
9. Verify success message

**Expected Results:**
- Printer settings saved to Firestore
- Connection test shows status
- Settings persist after reload
- Receipt format includes custom header/footer

---

### 3. Profile Image Upload Feature ✓

**Screen:** Settings → My Profile

**Test Steps:**
1. Click on profile photo circle
2. Select "Upload Photo"
3. Choose image from gallery or camera
4. Image should upload to:
   - [ ] Firebase Storage
   - [ ] PHP endpoint
5. Progress indicator shows upload status
6. Success message appears
7. Profile photo updates in UI
8. Refresh app to verify persistence

**Expected Results:**
- Image stored in Firebase Storage
- Image backed up on PHP server
- Firestore updated with URLs
- Photo displays in profile section
- Photo persists across app sessions

---

### 4. Email & Receipt Notifications ✓

**Screen:** Receipt generated after sale

**Test Steps:**
1. Create a new sale/order
2. Complete payment
3. Generate receipt
4. System should send:
   - [ ] Email receipt to customer
   - [ ] Push notification
5. Check customer email inbox
6. Verify receipt content:
   - Business name
   - Receipt number
   - Items listing
   - Total amount
   - Payment method

**Expected Results:**
- Receipt email arrives within 2 minutes
- Push notification appears on device
- Email contains all order details
- Links/formatting work correctly
- No spam folder routing

---

### 5. Notification Preferences ✓

**Screen:** Settings → Notification Settings

**Test Steps:**
1. Enable/Disable notification channels:
   - [ ] Email notifications
   - [ ] SMS notifications
   - [ ] Push notifications
2. Set frequency:
   - [ ] Immediate
   - [ ] Hourly
   - [ ] Daily
3. Select notification types:
   - [ ] Sales notifications
   - [ ] Inventory alerts
   - [ ] Payment reminders
   - [ ] Orders
   - [ ] System alerts
4. Click "Save Preferences"
5. Verify preferences save to Firestore

**Expected Results:**
- Preferences persist after reload
- Notifications respect frequency setting
- Only enabled channels send alerts
- Notification types filter correctly

---

### 6. Data Synchronization ✓

**Test Steps:**
1. Make changes to:
   - [ ] Profile information
   - [ ] Business settings
   - [ ] Printer configuration
2. System should auto-sync to:
   - [ ] Firestore (real-time)
   - [ ] PHP endpoint (delayed/batch)
3. Check Firestore Console
4. Verify sync timestamps
5. Check PHP endpoint logs

**Expected Results:**
- Changes appear in Firestore within 1 second
- PHP endpoint receives data within 5 minutes
- Sync timestamps updated
- No data loss or duplication
- Offline changes sync when online

---

### 7. Low Stock & Expiry Alerts ✓

**Test Steps:**
1. Set inventory item to low quantity (< 10)
2. System should send:
   - [ ] Email alert to owner
   - [ ] Push notification
   - [ ] In-app notification
3. Set inventory item expiry date to tomorrow
4. System should send:
   - [ ] Expiry email alert
   - [ ] Push notification
5. Verify alert content:
   - Item name
   - Current quantity/expiry date
   - Action recommendations

**Expected Results:**
- Alerts sent to configured channels
- Multiple reminders for items near expiry
- Owner receives emails within 2 minutes
- Push notifications appear immediately
- Alerts don't repeat excessively

---

### 8. Payment Reminder Notifications ✓

**Test Steps:**
1. Create payment with due date
2. Set due date to tomorrow
3. System should automatically:
   - [ ] Send reminder email
   - [ ] Send push notification
   - [ ] Log reminder event
4. Check notification preferences
5. Verify reminder follows user preferences

**Expected Results:**
- Reminders sent 1 day before due date
- Email contains payment details
- Dashboard highlights due payments
- Multiple notifications for overdue items
- Logging tracks all reminders

---

### 9. Business Information Sync ✓

**Screen:** Settings → Business Information

**Test Steps:**
1. Update business details:
   - [ ] Business name
   - [ ] Phone number
   - [ ] Email address
   - [ ] Address
   - [ ] Tax ID
2. Click "Save"
3. Verify data syncs to:
   - [ ] Firestore
   - [ ] PHP endpoint
4. Check update timestamps
5. Test on different device/session

**Expected Results:**
- Updates appear immediately in app
- Firestore reflects changes
- PHP endpoint receives updates
- Timestamps update correctly
- Changes visible across devices

---

### 10. File Export with Server Upload ✓

**Test Steps:**
1. Export sales data in CSV format
2. Enable "Upload to Server"
3. Provide export date range
4. Click "Export Now"
5. Verify:
   - [ ] File created locally
   - [ ] File uploaded to server
   - [ ] Server URL returned
   - [ ] Export metadata saved

**Expected Results:**
- Local file created successfully
- Server upload completes
- Download URL available
- Export metadata in Firestore
- Can re-access exported file from server

---

## Integration Tests

### Test 1: Complete Order Flow

**Steps:**
1. Create new sale
2. Add items
3. Apply discount
4. Process payment
5. Generate receipt
6. System should:
   - Save sale to Firestore
   - Send receipt email
   - Send push notification
   - Update inventory
   - Log transaction
   - Track metrics

**Verification:**
- [ ] Sale appears in sales history
- [ ] Receipt email arrives
- [ ] Notification displayed
- [ ] Inventory decrements
- [ ] Revenue reflected in dashboard

### Test 2: Daily Sync Cycle

**Steps:**
1. Make multiple changes throughout day
2. End of day: system auto-syncs
3. Check:
   - Firestore updates
   - PHP endpoint receives data
   - All changes captured
   - No data conflicts

**Verification:**
- [ ] All changes synced
- [ ] Timestamps accurate
- [ ] No duplicate data
- [ ] Sync logs recorded

### Test 3: Offline Mode

**Steps:**
1. Enable offline mode
2. Make sales
3. Upload photos
4. Edit settings
5. Go online
6. Sync all changes

**Verification:**
- [ ] Changes queue locally
- [ ] No errors when offline
- [ ] Auto-sync when online
- [ ] All data preserved

---

## Performance Benchmarks

Expected performance metrics:

| Feature | Target | Test Result |
|---------|--------|-------------|
| Export CSV (1000 records) | < 5s | _____ |
| Email send | < 2s | _____ |
| Push notification | < 1s | _____ |
| Profile image upload | < 3s | _____ |
| Data sync to Firestore | < 1s | _____ |
| Data sync to PHP | < 5s | _____ |
| Printer connection | < 2s | _____ |
| Print receipt | < 10s | _____ |

---

## Error Scenarios

### Test 1: Network Failure

**Scenario:** Network disconnects during sync

**Expected Behavior:**
- [ ] Operation queued for retry
- [ ] Error message shown
- [ ] App continues functioning
- [ ] Auto-retry when online

### Test 2: Invalid Data

**Scenario:** Invalid email address in profile

**Expected Behavior:**
- [ ] Validation error shown
- [ ] Helpful message displayed
- [ ] Correction form provided
- [ ] Save blocked until valid

### Test 3: Server Error

**Scenario:** PHP endpoint returns 500 error

**Expected Behavior:**
- [ ] Error caught gracefully
- [ ] User notified
- [ ] Fallback to local storage
- [ ] Retry option provided

### Test 4: Storage Full

**Scenario:** Device storage is full

**Expected Behavior:**
- [ ] Appropriate error message
- [ ] Suggestion to clean up
- [ ] Graceful failure (no crash)
- [ ] Clear action to resolve

---

## Security Tests

- [ ] API key not exposed in logs
- [ ] Sensitive data encrypted
- [ ] Passwords not stored locally
- [ ] Firebase rules enforced
- [ ] PHP endpoint validates permissions
- [ ] Rate limiting prevents abuse
- [ ] XSS/SQL injection protection
- [ ] CORS headers configured

---

## Compatibility Tests

**Android:**
- [ ] Android 11+
- [ ] Different screen sizes
- [ ] Different printers

**iOS:**
- [ ] iOS 14+
- [ ] Different screen sizes
- [ ] iCloud sync

**Browsers (Web):**
- [ ] Chrome
- [ ] Safari
- [ ] Firefox

---

## Bug Report Template

Found an issue? Use this template:

```
**Title:** [Brief description]

**Steps to Reproduce:**
1. First step
2. Second step
3. Third step

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Device/OS:**
[Platform and version]

**Logs:**
[Error message or stack trace]

**Screenshot:**
[If applicable]
```

---

## Sign-Off

| Item | Tester | Date | Status |
|------|--------|------|--------|
| Export Feature | _____ | _____ | ✓/✗ |
| Printer Config | _____ | _____ | ✓/✗ |
| Image Upload | _____ | _____ | ✓/✗ |
| Email Notifications | _____ | _____ | ✓/✗ |
| Data Sync | _____ | _____ | ✓/✗ |
| All Integration Tests | _____ | _____ | ✓/✗ |

**Overall Status:** _____ (PASSED / NEEDS FIXES)

**Date Completed:** _____

**Tested By:** _____

