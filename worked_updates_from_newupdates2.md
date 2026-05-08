Worked updates moved out of `newupdates2.md`

Updated: 2026-05-08

This file tracks backlog items that have already been worked on so `newupdates2.md` can stay focused on the remaining issues.

Completed or addressed items

GENERAL
- WhatsApp message now differentiates between goods sold as retail or wholesale.

RETAIL
- Cart price state now stays aligned better when switching items between retail and wholesale in checkout/cart flow.
- Printed invoice now uses the selected sale pricing and unit context instead of mixing retail and wholesale values.
- Printed receipt and reopened receipt history now preserve the sold unit better, including retail vs wholesale labels.
- WhatsApp/share receipt text now differentiates between pcs/packs and retail/wholesale.
- Customer name added to a sale now prints on the completed receipt.
- Clicking a saved customer now shows purchase history.
- Expiry tracking now has a dedicated dashboard-accessible screen for expiring products and procurement batches.
- Startup expiry notifications now summarize expired, due-today, and due-soon stock into the in-app notification feed.

CUSTOMERS / BAR SHARED CUSTOMER FLOW
- Customer list now has search.
- Opening a customer can load purchase history instead of failing.
- A new sale can now be started directly from the customer profile.

INVOICE / CUSTOMER LINK
- Sales invoice generation now uses customer details from the active sale and stores a draft invoice record.
- Invoice PDF line items now include unit and pricing mode context.
- Invoice PDFs now use the business profile image/logo more visibly, including a soft branded watermark/background treatment.
- Quick Sale now has a direct invoice action in the top app bar in addition to the cart-area invoice button.

Notes
- Some broader bar-specific invoice requests in `newupdates2.md` are still pending.

SUBSCRIPTION
- Subscription renewal reminders now fire at 30 days, 15 days, 1 week, and 3 days before expiry.
- Owners now keep access during a 7-day renewal grace period after subscription end date.
- After the grace period ends, the app revalidates access and routes owners back to the subscription payment flow.
