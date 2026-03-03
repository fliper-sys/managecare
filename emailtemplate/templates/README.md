# Email Templates

Place PHP template files in this folder. Templates should echo or return the fully rendered HTML when included.

Available templates:

- `daily_transactions.php` — Expects `businessName`, `date`, `transactions` (array of {note,type,amount}).
- `receipt.php` — Expects a `$data` array compatible with `receipt_template.php` helpers (items, subtotal, total, customerName, etc.).

Example curl to send daily transactions via `email_api.php`:

```bash
curl -X POST 'https://yourdomain.com/emailtemplate/email_api.php' \
  -F 'api_key=8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef' \
  -F 'template=daily_transactions' \
  -F 'recipient=lovebari4@icloud.com' \
  -F 'data={"businessName":"My Shop","date":"2025-12-11","transactions":[{"note":"Sale #1","amount":120.50},{"note":"Sale #2","amount":55.00}]}'
```

Make sure the `api_key` is kept secret and set via environment variables in production (consider updating `email_api.php` to read from `getenv()` instead of hardcoding the key).
