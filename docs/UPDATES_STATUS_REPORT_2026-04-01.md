# Updates Status Report

Date: 2026-04-01
Source: [updates.md](/c:/Users/USER/Desktop/mc/updates.md)

This report combines:
- the status notes already written in `updates.md`
- the code changes completed in this session

Items listed as "source-marked complete" were taken from `updates.md` and were not exhaustively re-verified end-to-end in this session.

## Done In This Pass

- `3.` Inventory download/export now works from the main inventory screen, not only the inventory report screen.
- `7.` Procurement now supports a richer unit flow by letting products carry explicit inventory units and by offering compatible unit choices during procurement edits.
- `10.` Auto-rotate is now enabled again across app and web startup configuration.
- `14.` Retail checkout/invoice flow can now select an existing customer or create a brand-new customer inline before generating the invoice or recording the sale.
- `11.` The owner home-page `Products`, `Customers`, and `Staff` chips now navigate to their actual screens.
- `20.` Owner sign-in now rejects worker accounts directly and routes staff back to the worker-login path.
- `17.` Inventory export now supports web download flows from both the inventory screen and the inventory report screen.
- `21.` Manual subscription receipt submissions now go through a pending-approval gate instead of activating access immediately.
- `23.` Product and worker creation now surface tier-limit prompts using normalized business-class / plan-level rules.
- `27.` Admin payment approval now writes recognized-revenue audit fields, and admin revenue totals now count approved/recognized payment records instead of estimated subscription tiers.
- `31.` Admin user access now merges the `users` and `workers` tables so the Users & Workers area can inspect both sources from one place.
- `34.` Bar invoices can now be converted directly into completed sales from the new Tabs & Invoices flow, so staff do not need to re-enter the order after payment.
- `35.` Bar invoices are now stored persistently in invoice records under the business, with open, converted, and cancelled states visible from the new Tabs & Invoices screen.

## Source-Marked Complete Or Working

### Retail

- `2.` Subscription days-left issue marked fixed.
- `4.` Product procurement and sales history on product click marked working.
- `5.` Expiry tracking / expiry notification flow marked working.
- `6.` Low-stock threshold selection marked fixed.
- `9.` Procurement changes reflecting in activity log and product history marked working.
- `12.` Product search issue marked working.
- `18.` Admin product change tracking on inventory page marked working.
- `19.` Worker feature restriction selection marked fixed.
- `24.` Registration/business-selection lock-up marked fixed.

### Admin

- `26.` Admin home-page filtering buttons marked fixed.
- `28.` Business detail visibility for admin marked fixed.
- `29.` Duplicate business display marked fixed.

### Real Estate

- `37.` Properties inventory rename / property management marked working.
- `38.` Rent/short-let payment details and reminders marked working.
- `39.` Property document uploads marked working.

### Hospitality

- `41.` Multi-service hospitality support marked working.
- `42.` Hospitality registration option selection marked working.
- `43.` Room registration and checkout alerting marked working.
- `46.` Worker order button for available inventory items marked working.

### Marketing

- `52.` Admin can create marketer accounts marked working.
- `53.` Admin commission allocation / marketer visibility marked working.
- `54.` Marketer email referral linking marked working.

### Gas / Pharmacy / Subscription

- `62.` Non-fuel gas products still using inventory/procurement marked working.
- `69.` Automatic tier grading during registration marked working.
- `75.` Hotels, bars, kitchen, and lounge grouped under hospitality marked working.

## Needs More Work Or Is Only Partially Done

### Retail

- `8.` Procurement batches still need stronger handling for new-stock vs old-stock costing/expiry separation.
- `10.` Menu-button behavior still needs work after the auto-rotate fix.
- `13.` Wholesale vs retail variants and sale-unit differentiation are still pending.
- `15.` Same-device account switching and owner/worker sync lag still need work.
- `16.` Gross-profit vs net-profit rules still need metric clarification.
- `21.` Manual receipt approval is safer now, but processor-side verification and broader payment-approval flow still need work.
- `22.` Expired-owner gating is tighter now, but reminder timing and explicit post-expiry grace-period rules still need work.
- `23.` Product/worker limit prompts now exist, but wider upgrade enforcement across the app still needs more detail and implementation.

### Admin

- `30.` Restricted businesses now get a dedicated login holding screen, support-contact prompt, and user notifications, but real-time kick-out for already-open sessions still needs stronger enforcement.

### Bar / Invoice

- `33.` Bar POS now supports saved customer/table invoices and tab-style conversion to sales, but fuller retail parity still needs more work around deeper table service, editing/reopening open tabs, and broader bar workflow polish.

### Hospitality

- `44.` Room-service orders rolling into final room bills still need work.
- `45.` Kitchen/bar assignment to table numbers still needs work.
- `47.` Extra orders and stay-extension flow still need work.
- `48.` Open-table order lifecycle until payment still needs work.
- `49.` Separate restaurant stock screen still needs work.
- `50.` Leftover/spoilage recording still needs work.

### Marketing

- `55.` Active vs inactive marketer client tracking still needs work.
- `56.` Monthly marketer ranking board still needs work.
- `57.` Target/progress loading indicator still needs work.
- `58.` Client subscription-expiry visibility for marketers still needs work.

### Gas

- `60.` Pump sales reflecting under dashboard total sales still needs work.
- `61.` Separate gas-stock input area still needs work.

### Pharmacy / Permissions

- `64.` Age-based prescription attachment and receipt printing still need work.
- `65.` Direct prescription writing/printing screen still needs work.
- `66.` Worker-dashboard prescription visibility with permissions still needs work.
- `67.` Real-time worker-permission changes still need work.

### Subscription / Pricing Structure

- `70.` Tier 1 hard-limit enforcement still needs confirmation / implementation.
- `71.` Tier 2 hard-limit enforcement still needs confirmation / implementation.
- `72.` Tier 3 hard-limit enforcement still needs confirmation / implementation.
- `73.` Removing basic/pro-only restructuring still needs work.
- `74.` Premium tier rules and pricing still need work.
- `76.` Hospitality-specific tier calculation still needs work.
- `77.` Hospitality multi-service rule is noted, but still needs full enforcement review.

## Verification Notes

- Targeted tests were added for inventory unit normalization and inventory CSV export generation.
- Automated `flutter test` execution could not be completed in this session because `flutter`/`dart` are not available on this machine's PATH.
