# Manage Care - Complete API Integration & Pricing List

**Last Updated:** January 23, 2026  
**Document Purpose:** Track all external APIs integrated into the Manage Care Flutter application, including pricing, costs, and renewal information.

---

## Table of Contents
1. [Backend Services (Firebase)](#firebase-services)
2. [Payment Processing](#payment-processing)
3. [Communication Services](#communication-services)
4. [Location & Mapping](#location--mapping)
5. [Analytics & Monitoring](#analytics--monitoring)
6. [Storage & CDN](#storage--cdn)
7. [Third-Party Libraries (Free)](#third-party-libraries-free)
8. [Internal Custom APIs](#internal-custom-apis)
9. [Summary of Costs](#summary-of-costs)

---

## Firebase Services
**Provider:** Google Firebase  
**Status:** Primary backend infrastructure  
**Documentation:** https://firebase.google.com/docs

### 1. Firebase Authentication
- **Service:** User authentication and account management
- **Features Used:**
  - Email/password authentication
  - Session management
  - User credential verification
- **Pricing Model:** Free tier + Pay-as-you-go
- **Free Tier Includes:**
  - Unlimited users (no charge per user)
  - 50,000 free authentications/month
- **Pay-as-you-go Rates:**
  - $0.0055 per 100 additional authentications (after free tier)
- **Annual Cost Estimate:** ~$27/year (assuming 2M authentications/month in production)
- **Renewal:** Automatic monthly billing
- **Contract:** No minimum commitment

### 2. Cloud Firestore (Database)
- **Service:** Real-time NoSQL database for business data
- **Features Used:**
  - Business records storage
  - User profiles
  - Transaction history
  - Subscription management
  - Offline persistence
- **Pricing Model:** Pay-as-you-go based on operations
- **Free Tier Includes:**
  - 50,000 read operations/day
  - 20,000 write operations/day
  - 20,000 delete operations/day
  - 1GB storage
- **Pay-as-you-go Rates:**
  - **Reads:** $0.06 per 100,000 reads
  - **Writes:** $0.18 per 100,000 writes
  - **Deletes:** $0.02 per 100,000 deletes
  - **Storage:** $0.18 per GB/month
- **Annual Cost Estimate:** $500-$1,500/year (depending on user volume)
- **Renewal:** Automatic daily/monthly billing
- **Contract:** No minimum commitment

### 3. Firebase Storage
- **Service:** Cloud storage for images, PDFs, and receipts
- **Features Used:**
  - Profile images
  - Business logos
  - Receipt PDFs
  - Report exports
- **Pricing Model:** Pay-as-you-go
- **Free Tier Includes:**
  - 1GB storage
  - 1GB/month download (egress)
- **Pay-as-you-go Rates:**
  - **Storage:** $0.020 per GB/month
  - **Download:** $0.12 per GB (after 1GB free/month)
  - **Upload:** Free
- **Annual Cost Estimate:** $50-$150/year
- **Renewal:** Automatic monthly billing
- **Contract:** No minimum commitment

### 4. Firebase Messaging (Push Notifications)
- **Service:** Server-to-client push notifications
- **Features Used:**
  - Real-time alerts for payments
  - Subscription expiry notifications
  - Order updates
- **Pricing Model:** Free
- **Cost:** $0 (unlimited messages)
- **Renewal:** N/A (Free service)

### 5. Firebase Analytics
- **Service:** User behavior and event tracking
- **Features Used:**
  - Event logging
  - User property tracking
  - Screen view analytics
  - Custom business events
- **Pricing Model:** Free
- **Cost:** $0 (unlimited events)
- **Renewal:** N/A (Free service)

---

## Payment Processing

### 1. Flutterwave Payment Gateway
- **Service:** Payment processing for subscriptions and transactions
- **Website:** https://www.flutterwave.com
- **Features Used:**
  - Credit/Debit card processing
  - USSD payments
  - Bank transfer payments
  - Payment verification
  - Transaction receipts
- **Pricing Model:** Per-transaction commission
- **Transaction Fees:**
  - **Card Payments:** 1.4% + ₦100 (Nigeria)
  - **USSD:** 0.9% + ₦50
  - **Bank Transfer:** 0.5% + ₦100
- **Example Costs:**
  - ₦50,000 subscription → ~₦850 fee (1.7%)
  - ₦100,000 subscription → ~₦1,540 fee (1.54%)
- **Annual Cost Estimate:** $300-$1,000/year (varies with transaction volume)
- **Renewal:** Automatic per transaction
- **Contract:** No long-term contract required
- **Account Setup Cost:** Free
- **Minimum Transaction:** ₦100

---

## Communication Services

### 1. WhatsApp Cloud API (Meta)
- **Service:** Send transactional and notification messages via WhatsApp
- **Website:** https://developers.facebook.com/docs/whatsapp/cloud-api
- **Features Used:**
  - Order notifications
  - Payment confirmations
  - Daily business reports
  - Customer alerts
- **Pricing Model:** Per-message cost
- **Message Rates (Nigeria):**
  - **Utility/Transaction Messages:** ₦4.30 per message
  - **Marketing Messages:** ₦19.50 per message
  - **Authentication Messages:** Free (up to 10,000/month)
- **Estimated Monthly Messages:** 500-1,000
- **Annual Cost Estimate:** $200-$600/year
- **Renewal:** Per-message billing, automatic
- **Contract:** No minimum commitment required
- **Account Requirements:** 
  - WhatsApp Business Account
  - Phone Number ID
  - Access Token

### 2. Custom Email Service
- **Service:** Email delivery for receipts and notifications
- **Infrastructure:** Self-hosted API on globalthrivealliance.com
- **Features Used:**
  - Receipt emails (Pro feature)
  - Payment confirmations
  - Template-based emails
  - File attachments
- **Pricing Model:** Self-hosted (no external cost)
- **Cost:** $0 (included in server hosting)
- **Renewal:** N/A
- **Endpoints:**
  - `https://globalthrivealliance.com/emailtemplate/email_api.php`
  - `https://globalthrivealliance.com/emailtemplate/receipt_email_listener.php`

---

## Location & Mapping

### 1. Google Location Services (Geolocator)
- **Service:** Device location and geocoding
- **Features Used:**
  - Store location capture
  - Address geocoding
  - Location-based business filtering
- **Pricing Model:** Free
- **Cost:** $0 (native device APIs)
- **Renewal:** N/A

### 2. Google Maps (Geocoding)
- **Service:** Address-to-coordinates conversion
- **Features Used:**
  - Address lookup
  - Reverse geocoding
- **Pricing Model:** Pay-as-you-go
- **Rates:**
  - **Geocoding:** $7.00 per 1,000 requests
- **Estimated Annual Cost:** $50-$200/year
- **Renewal:** Monthly billing if implemented
- **Note:** Currently using native geocoding (no API calls if not explicitly integrated)

---

## Analytics & Monitoring

### 1. Firebase Analytics
- **Status:** Already covered in Firebase Services section
- **Cost:** $0 (Free)

### 2. Custom Analytics Logging
- **Service:** In-app analytics and event logging
- **Features Used:**
  - User action tracking
  - Business metrics
  - Feature usage
  - Error tracking
- **Cost:** $0 (Built-in, no external service)

---

## Storage & CDN

### 1. Firebase Storage (Already Listed)
- **Status:** Covered in Firebase Services section
- **Cost:** $50-$150/year

### 2. Custom File Upload Service
- **Service:** File uploads to custom server
- **Infrastructure:** globalthrivealliance.com
- **Features Used:**
  - Image uploads
  - Document storage
- **Cost:** $0 (Self-hosted)

---

## Third-Party Libraries (Free)

The following dependencies are integrated but are completely **FREE**:

| Library | Purpose | Cost |
|---------|---------|------|
| **Flutter SDK** | Core framework | Free |
| **Provider** | State management | Free |
| **Hive** | Local database | Free |
| **Sqflite** | SQLite database | Free |
| **Dio** | HTTP client | Free |
| **Shared Preferences** | Local preferences | Free |
| **Google Fonts** | Typography | Free |
| **Flutter SVG** | Vector graphics | Free |
| **QR Flutter** | QR code generation | Free |
| **Mobile Scanner** | Barcode scanning | Free |
| **PDF Library** | PDF generation | Free |
| **Image Picker** | Image selection | Free |
| **Lottie** | Animations | Free |
| **FL Chart** | Data visualization | Free |
| **Syncfusion Charts** | Advanced charts | Free (Community Edition) |
| **Table Calendar** | Calendar widget | Free |
| **Permission Handler** | Permissions management | Free |
| **Device Info Plus** | Device information | Free |
| **Package Info Plus** | App metadata | Free |
| **URL Launcher** | External link opening | Free |
| **Share Plus** | Native sharing | Free |
| **Timezone** | Timezone handling | Free |
| **Intl** | Internationalization | Free |
| **Barcode Widget** | Barcode rendering | Free |
| **Flutter Animate** | Animations | Free |
| **Connectivity Plus** | Network detection | Free |

**Total Cost for All Libraries:** $0

---

## Internal Custom APIs

### 1. Email Template Service
- **Purpose:** Centralized email template management
- **Endpoints:**
  - `POST /emailtemplate/email_api.php` - Send template emails
  - `POST /emailtemplate/receipt_email_listener.php` - Send receipt emails
- **Authentication:** API Key (`8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef`)
- **Cost:** $0 (Self-hosted)
- **Rate Limits:** None specified

### 2. File Upload Service
- **Purpose:** Handle file uploads to server
- **Endpoint:** `POST /upload.php`
- **Supported:** Images, Documents, PDFs
- **Cost:** $0 (Self-hosted)

### 3. Webhook Services
- **Purpose:** Receive and process webhooks
- **Supported Hooks:**
  - Payment webhooks
  - Daily report webhooks
- **Cost:** $0 (Self-hosted)

---

## Summary of Costs

### Monthly Breakdown (Estimated)

| Service | Monthly Cost | Annual Cost |
|---------|-------------|------------|
| **Firebase Authentication** | $2.25 | $27.00 |
| **Firebase Firestore** | $50-$125 | $600-$1,500 |
| **Firebase Storage** | $5-$15 | $60-$180 |
| **Firebase Messaging** | $0 | $0 |
| **Firebase Analytics** | $0 | $0 |
| **Flutterwave Payments** | Variable* | $300-$1,000 |
| **WhatsApp API** | $20-$50 | $240-$600 |
| **Google Maps (if used)** | $0-$20 | $0-$240 |
| **All Free Libraries** | $0 | $0 |
| **Self-hosted Services** | $0 | $0 |
| **TOTAL (ESTIMATED)** | **$77-$212** | **$1,227-$3,547** |

*Flutterwave: 1.4-1.7% per transaction (no fixed monthly cost)

### Recurring Renewal Schedule

| Service | Renewal Cycle | Renewal Method |
|---------|---------------|-----------------|
| Firebase Services | Monthly | Automatic billing to credit card |
| Flutterwave | Per-transaction | Automatic commission deduction |
| WhatsApp API | Monthly | Automatic to Meta Business account |
| Google Maps API | Monthly | Automatic billing (if enabled) |
| Email Service | N/A | Self-hosted |
| All Free Libraries | N/A | No renewal |

---

## Cost Optimization Recommendations

1. **Firestore Optimization:**
   - Set up indexes for common queries
   - Implement query optimization
   - Consider data archiving for old transactions
   - Could save: $200-400/year

2. **Storage Optimization:**
   - Compress images before upload
   - Delete old/unused files
   - Implement lifecycle policies
   - Could save: $20-50/year

3. **WhatsApp Optimization:**
   - Use utility messages (₦4.30) instead of marketing (₦19.50)
   - Batch notifications where possible
   - Could save: $100-200/year

4. **Flutterwave Optimization:**
   - Encourage USSD payments (0.9% vs 1.4%)
   - No optimization possible here

5. **Consider Alternatives:**
   - Stripe: Similar pricing, possibly better rates
   - AWS instead of Firebase: Complex but potentially cheaper at scale
   - Local email server: Already implemented

---

## Important Notes

✅ **What's Included:**
- All development/testing APIs are included in free tiers
- Production APIs use pay-as-you-go models (no fixed long-term contracts)
- Scalable pricing adjusts with business growth

⚠️ **Important Considerations:**
- All prices are estimates based on assumed usage
- Actual costs depend on user volume and transaction frequency
- Firebase free tier provides substantial cushion for small-to-medium businesses
- Implement proper error handling for payment failures
- Monitor Firebase usage regularly to manage costs

📋 **API Keys & Credentials:**
- Store all API keys securely in Firebase (secure/secure collection)
- Never commit keys to version control
- Rotate keys periodically for security
- Use environment-specific keys (test vs production)

---

## Action Items

- [ ] Set up Firebase billing alerts at $500/month threshold
- [ ] Configure Firebase Firestore indexes for query optimization
- [ ] Monitor WhatsApp API usage and optimize message types
- [ ] Review and compress old files in Firebase Storage quarterly
- [ ] Test payment flows with Flutterwave in production
- [ ] Document API integration changes in this file

---

**Last Reviewed:** January 23, 2026  
**Next Review Date:** April 23, 2026
