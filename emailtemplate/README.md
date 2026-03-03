Manage Care Email Templates & Workers
===================================

This folder contains email templates and server-side helpers to send template-based emails using your SMTP settings.

Files added
- `mail.php` - PHPMailer-based send_mail function (supports attachments).
- `email_api.php` - HTTP endpoint for sending template-based emails from the app.
- `template_renderer.php` - small templating engine ({{var}} and {{#list}}...{{/list}}).
- `expiry_worker.php` - CLI worker to send expiry alert emails to business owners.
- `weekly_report_worker.php` - CLI worker to send weekly analytics reports to Pro businesses' admins.
- `manage-care-email (1).html` - HTML file containing the email templates. Each template container uses an id like `welcome-email`, `payment-email`, `analytics-email`, `lowstock-email`, `expiry-email`.

Quickstart
----------

1. Configure environment variables on your server (for cron jobs):

   - `BUSINESS_API_URL` - Base URL of your app API that exposes endpoints for expiring items and weekly reports.
   - `BUSINESS_API_KEY` - API key the app exposes to authenticate worker requests (optional, depends on your app).

2. Test email sending with curl (example):

```bash
curl -X POST 'https://yourdomain.com/emailtemplate/email_api.php' \
  -F 'api_key=8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef' \
  -F 'template=welcome' \
  -F 'recipient=you@example.com' \
  -F 'data={"name":"John","link":"https://app.example.com"}'
```

Upload endpoint examples
------------------------

Single file upload (returns `url` and `urls`):

```bash
curl -X POST 'https://yourdomain.com/emailtemplate/upload.php' \
  -F 'api_key=8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef' \
  -F 'image=@/path/to/receipt.jpg'
```

Multiple files (attachments) upload:

```bash
curl -X POST 'https://yourdomain.com/emailtemplate/upload.php' \
  -F 'api_key=8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef' \
  -F 'attachments[]=@/path/to/file1.jpg' \
  -F 'attachments[]=@/path/to/file2.pdf'
```

Response examples:

Single file:

```json
{ "url": "https://yourdomain.com/uploads/12345_receipt.jpg", "urls": ["..."], "details": [ { "url": "...", "path": "/var/www/html/emailtemplate/uploads/12345_receipt.jpg" } ] }
```

Multiple files:

```json
{ "urls": ["https://.../file1.jpg","https://.../file2.pdf"], "details": [ {...}, {...} ] }
```

3. Cron setup examples

Daily expiry check at 2:00 AM:

```cron
0 2 * * * /usr/bin/php /var/www/html/emailtemplate/expiry_worker.php >> /var/log/email_expiry.log 2>&1
```

Weekly report every Monday at 04:00 AM:

```cron
0 4 * * MON /usr/bin/php /var/www/html/emailtemplate/weekly_report_worker.php >> /var/log/email_weekly.log 2>&1
```

Worker expectations
- `expiry_worker.php` expects either:
  - A JSON file passed as first CLI argument in the format:
    ```json
    [
      {"businessId":"b1","businessName":"My Shop","ownerEmail":"owner@shop.com","items":[{"name":"Milk","expiryDate":"2025-12-01","daysLeft":2}]}
    ]
    ```
  - Or an API endpoint at `${BUSINESS_API_URL}/expiring_items.php` that returns the same JSON.

- `weekly_report_worker.php` expects an endpoint at `${BUSINESS_API_URL}/weekly_reports.php` that returns:
  ```json
  [
    {"businessId":"b1","businessName":"My Shop","subscriptionTier":"professional","admins":["owner@shop.com"],"report":{...}}
  ]
  ```

Security & Recommendations
- Move SMTP credentials in `mail.php` to environment variables instead of hardcoding them. I can update `mail.php` to read credentials from `getenv()`.
- Protect your app endpoints (`expiring_items.php`, `weekly_reports.php`) with an API key or server-to-server authentication.
- The `trigger_daily_send.php` webhook accepts either a header `X-Hook-Token: <token>` (when `DAILY_REPORT_HOOK_TOKEN` is set in the server env) or an `api_key` POST field (form or JSON). For compatibility the legacy API key `8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef` is also accepted by default. Use environment-provided `DAILY_REPORT_API_KEY` for production security.
- Consider logging email send attempts (success/failure) to a file or central log for auditing.

If you want, I can:
- Update `mail.php` to use environment variables for SMTP credentials.
- Implement a small server endpoint in your app to return expiring items and weekly reports in the formats above.
- Add server-side subscription validation for Pro feature gating (recommended).

Additional notes
----------------
- `payment_reminder_worker.php` has been added to send upcoming payment reminders (targets `realestate` businessType by default).
- `manage-care-email (1).html` now includes `order-email` and `payment-reminder-email` templates for order confirmations and payment reminders.

Suggested cron for payment reminders (daily):

```cron
30 3 * * * /usr/bin/php /var/www/html/emailtemplate/payment_reminder_worker.php >> /var/log/email_payments.log 2>&1
```

