# Web Email Integration - Visual Flow Diagrams

## Complete Receipt Checkout Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CUSTOMER AT CHECKOUT                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ↓
                    ┌───────────────────────────────┐
                    │  User completes payment       │
                    │  (Cash/Card/Mobile Money)     │
                    └───────────────────────────────┘
                                    │
                                    ↓
            ┌───────────────────────────────────────────────┐
            │    CheckoutReceiptHandler.handleCheckoutReceipt()    │
            └───────────────────────────────────────────────┘
                                    │
                ┌───────────────────┼───────────────────┐
                ↓                   ↓                   ↓
        ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
        │ Generate    │    │ Show Loading │    │ Get Receipt │
        │ Receipt #   │    │ Dialog       │    │ Settings    │
        │ RCP-XXXXX   │    └──────────────┘    └─────────────┘
        └─────────────┘
                │
                ↓
        ┌──────────────────────────────────┐
        │ PdfReceiptGenerator.generate()   │
        │ (Local - 2-3 seconds)            │
        │ Returns: File(receipt.pdf)       │
        └──────────────────────────────────┘
                │
                ↓
        ┌────────────────────────────────────┐
        │ Show Receipt Confirmation Dialog    │
        │ - Send via Email button            │
        │ - Receipt Saved button             │
        └────────────────────────────────────┘
                │
        ┌───────┴──────────┐
        │                  │
        ↓                  ↓
   ┌──────────────┐  ┌──────────────┐
   │ Send Email   │  │ Continue     │
   │ (web server) │  │ Checkout     │
   └──────────────┘  └──────────────┘
        │
        │ *** WEB INTEGRATION BEGINS ***
        │
    ┌───┴────────────────────────────────────────────────────┐
    │                                                         │
    ↓                                                         ↓
┌──────────────────────────┐                    ┌──────────────────────────┐
│ 1. Upload PDF to Server  │                    │ 2. Generate HTML Email   │
├──────────────────────────┤                    ├──────────────────────────┤
│ WebEmailReceiptService   │                    │ EmailTemplateService     │
│.uploadFileToWebServer()  │                    │.generateReceiptEmailHtml│
│                          │                    │                          │
│ POST to upload.php       │                    │ Creates beautiful CSS    │
│ Returns: Public URL      │                    │ formatted HTML with:     │
│ https://...uploads/...   │                    │ - Business logo          │
│                          │                    │ - Receipt details        │
│ Time: 3-5 seconds        │                    │ - Item breakdown         │
└──────────────────────────┘                    │ - Professional styling   │
    │                                           │ - Responsive design      │
    │                                           │ - Mobile compatible      │
    │                                           │ Time: <1 second (local)  │
    │                                           └──────────────────────────┘
    │                                                   │
    └───────────────────┬─────────────────────────────┘
                        │
                        ↓
        ┌──────────────────────────────────┐
        │ 3. Send Receipt Email (Customer) │
        ├──────────────────────────────────┤
        │ WebEmailReceiptService           │
        │.sendReceiptEmail()               │
        │                                  │
        │ POST to email_api.php            │
        │ Includes:                        │
        │ - CSS HTML email                 │
        │ - Receipt data (JSON)            │
        │ - Business branding info         │
        │                                  │
        │ Time: 2-3 seconds                │
        └──────────────────────────────────┘
                        │
                        ↓
                ┌───────────────┐
                │ Email arrives │
                │ at customer   │
                │ beautifully   │
                │ formatted     │
                └───────────────┘
                        │
                        ↓
        ┌──────────────────────────────────────┐
        │ 4. Send Sales Notification (Owner)   │
        ├──────────────────────────────────────┤
        │ WebEmailReceiptService               │
        │.sendSalesNotification()              │
        │                                      │
        │ POST to email_api.php                │
        │ Includes:                            │
        │ - Alert HTML (green, eye-catching)  │
        │ - Sale amount (large)                │
        │ - Customer details                   │
        │ - Items list                         │
        │ - Receipt number                     │
        │                                      │
        │ Time: 2-3 seconds                    │
        └──────────────────────────────────────┘
                        │
                        ↓
                ┌───────────────┐
                │ Email arrives │
                │ at owner      │
                │ with alert    │
                └───────────────┘
                        │
                        ↓
        ┌──────────────────────────────────┐
        │ 5. Create Admin Notification     │
        ├──────────────────────────────────┤
        │ AdminNotificationService         │
        │.createPaymentNotification()      │
        │                                  │
        │ Save to Firestore:               │
        │ - Payment amount                 │
        │ - Customer name                  │
        │ - Business name                  │
        │ - Receipt number                 │
        │                                  │
        │ Time: <1 second (Firestore)      │
        └──────────────────────────────────┘
                        │
                        ↓
            ┌─────────────────────────┐
            │ All operations complete │
            │ (Total: 5-8 seconds)    │
            │                         │
            │ - Customer has receipt  │
            │ - Owner notified        │
            │ - Admin sees payment    │
            │ - PDF on web server     │
            │ - All beautifully       │
            │   formatted emails sent │
            └─────────────────────────┘
                        │
                        ↓
        ┌──────────────────────────────┐
        │ Dialog closes                │
        │ Receipt saved button updates │
        │ Success message shown        │
        └──────────────────────────────┘
                        │
                        ↓
            ┌──────────────────────┐
            │ Checkout complete    │
            │ Cart cleared         │
            │ User returns to POS  │
            └──────────────────────┘
```

## Email Service Architecture

```
┌──────────────────────────────────────────────────────┐
│         Checkout Receipt Handler (Orchestrator)      │
│ - Manages receipt generation workflow               │
│ - Shows user dialogs                                │
│ - Handles completion callbacks                      │
└──────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ↓               ↓               ↓
    ┌─────────┐  ┌────────────┐  ┌──────────────┐
    │ PDF     │  │ Web Email  │  │ Email        │
    │ Receipt │  │ Receipt    │  │ Template     │
    │ Gen.    │  │ Service    │  │ Service      │
    │         │  │            │  │              │
    │ Local   │  │ HTTP       │  │ HTML Gen.    │
    │ PDF     │  │ Client     │  │ CSS Styling  │
    │ File    │  │ to PHP     │  │ Formatting   │
    │ (2-3s)  │  │ (2-3s)     │  │ (<1s)        │
    └─────────┘  └────────────┘  └──────────────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
                ┌────────┴────────┐
                ↓                 ↓
        ┌──────────────┐  ┌──────────────┐
        │ File Upload  │  │ Email Send   │
        │ to Server    │  │ via Server   │
        │              │  │              │
        │ upload.php   │  │ email_api.php│
        │              │  │              │
        │ Returns URL  │  │ Template     │
        │              │  │ rendering    │
        └──────────────┘  └──────────────┘
             │                    │
             ↓                    ↓
        ┌──────────────┐  ┌──────────────┐
        │ Web Server   │  │ PHPMailer    │
        │ Storage      │  │ SMTP         │
        │              │  │              │
        │ /uploads/    │  │ Hostinger    │
        │              │  │ (smtp:587)   │
        │ Public URL   │  │              │
        │ for download │  │ Sends emails │
        └──────────────┘  └──────────────┘
```

## Database Integration

```
┌──────────────────────────────────────────────────────┐
│             Firestore Database                       │
├──────────────────────────────────────────────────────┤
│                                                      │
│  collections/                                       │
│  ├─ businesses/{businessId}                         │
│  │  ├─ name, email, logo, phone                     │
│  │  ├─ subscriptions/ (user's subscription tier)    │
│  │  ├─ sales/ (payment records)                     │
│  │  │  └─ {saleId}: amount, customer, items        │
│  │  └─ products/ (inventory)                        │
│  │                                                  │
│  ├─ users/{userId}                                  │
│  │  ├─ email, name, phone                           │
│  │  ├─ subscription {tier, features}                │
│  │  └─ preferences {receiptSettings}                │
│  │                                                  │
│  └─ admin_notifications/ (payments, etc)            │
│     └─ {notificationId}: amount, customer, date     │
│                                                      │
└──────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
   [Web Email]     [Receipt           [Admin
    Service]       Settings]          Notif.
                                      Service]
```

## Concurrent Operations

```
Timeline of Checkout Flow:
═══════════════════════════════════════════════════════

T=0s  │ User clicks "Send via Email"
      │
T=0s  │ ├─ Generate PDF (local)
      │ │
T=2s  │ └─ PDF ready (receipt.pdf)
      │
T=2s  │ ├─ Upload PDF to server
      │ │ ├─ POST to upload.php
      │ │ │
T=5s  │ │ └─ URL returned
      │ │
T=2s  │ ├─ Generate HTML email (parallel)
      │ │ └─ CSS templates rendered
      │ │
T=2s  │ ├─ Send receipt email (parallel)
      │ │ └─ POST to email_api.php
      │ │
T=4s  │ ├─ Send owner notification (parallel)
      │ │ └─ POST to email_api.php
      │ │
T=4s  │ ├─ Save admin notification (parallel)
      │ │ └─ Firestore write
      │ │
T=5s  │ └─ All done! Show success message
      │
═══════════════════════════════════════════════════════
Time:  0 ────── 2 ────── 4 ────── 6 ────── 8 seconds
```

## Email Template Examples

### Receipt Email Structure
```
┌─────────────────────────────────────────┐
│  BUSINESS LOGO  BUSINESS NAME           │ ← Header
│  Business Contact Info                  │
│  RECEIPT #RCP-001234                    │
│  Date & Time                            │
├─────────────────────────────────────────┤
│  Welcome Message (Custom Header)        │
├─────────────────────────────────────────┤
│  Customer Name: John Doe                │ ← Customer Info
├─────────────────────────────────────────┤
│  Item           Qty   Unit Price  Total │ ← Items Table
│  Widget         2     ₦5,000      ₦10,000
│  Service        1     ₦500        ₦500
│                                  ─────
│  Subtotal                        ₦10,500
│  Tax (5%)                        ₦525
│  ════════════════════════════════════════ ← Total
│  TOTAL                          ₦11,025
├─────────────────────────────────────────┤
│  Payment: CASH                          │ ← Payment Info
├─────────────────────────────────────────┤
│  Thank you message (Custom Footer)      │
├─────────────────────────────────────────┤
│  Thank you for your purchase!           │ ← Footer
│  This is an automated receipt.          │
└─────────────────────────────────────────┘
```

### Sales Notification Structure
```
┌─────────────────────────────────────────┐
│         ✅ NEW SALE RECORDED             │ ← Alert
│                                         │
│            ₦11,025                      │
├─────────────────────────────────────────┤
│  Receipt: #RCP-001234                   │ ← Sale Details
│  Customer: John Doe                     │
│  Email: john@example.com                │
├─────────────────────────────────────────┤
│  Items Sold                             │
│  • Widget (x2)                          │ ← Quick Scan
│  • Service (x1)                         │   Format
├─────────────────────────────────────────┤
│  Payment: CASH                          │
│  Time: 2:30 PM Today                    │
├─────────────────────────────────────────┤
│  From your POS system                   │
└─────────────────────────────────────────┘
```

## File Upload Flow

```
Local Device              Network            Web Server
═════════════════════════════════════════════════════════════

[PDF File]
    │
    ├─ generateReceipt()
    │  └─ receipt.pdf (2MB)
    │
    ├─ sendEmail()
    │  └─ Prepare multipart form
    │
    └─ uploadFileToWebServer()
        │
        │ HTTP POST (multipart)
        │ {"api_key": "xxx", "pdf": [FILE]}
        ├─────────────────────────────────→ POST /upload.php
                                             │
                                             ├─ Validate API key
                                             │
                                             ├─ Store in /uploads/
                                             │  RCP-001234.pdf
                                             │
                                             ├─ Generate public URL
                                             │  https://...uploads/RCP-001234.pdf
                                             │
        ←───────────────────────────────────┤
        {"success": true,                   │
         "url": "https://..."}              │
        │
        ├─ Store URL in email data
        │
        └─ Send email with CSS + URL link
```

## Performance Timeline

```
Operation                  Duration    Status
════════════════════════════════════════════════════════════

Generate Receipt PDF       2-3 sec     ⏳ Sequential
                           ├─────┤
                           ↓
Upload to Web Server       3-5 sec     ⏳ Sequential
                                ├────┤
                                ↓
Generate HTML Email        <1 sec      ⚡ Local (parallel)
Send Receipt Email         2-3 sec     📧 Network (parallel)
Send Owner Notification    2-3 sec     📧 Network (parallel)
Save Admin Notification    <1 sec      💾 Firestore (parallel)

════════════════════════════════════════════════════════════
Total Time:                5-8 sec     ✅ Most operations parallel
```

---

**Notes:**
- All times are approximate and depend on network conditions
- PDF generation is local (fast)
- Email sending is network-dependent
- Upload speed depends on file size
- Most operations run in parallel after upload completes

