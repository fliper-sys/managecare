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
- `8.` Procurement batches now preserve batch-level quantity, weighted cost, supplier/reference traceability, and optional expiry data so new stock no longer just overwrites old-stock costing/expiry context.
- `10.` Auto-rotate is now enabled again across app and web startup configuration.
- `13.` Retail products now support distinct wholesale pricing plus sale-unit / inventory-unit differentiation, and checkout can switch qualifying items between retail and wholesale pricing while keeping stock deduction aligned to the configured sale-unit multiplier.
- `14.` Retail checkout/invoice flow can now select an existing customer or create a brand-new customer inline before generating the invoice or recording the sale.
- `11.` The owner home-page `Products`, `Customers`, and `Staff` chips now navigate to their actual screens.
- `16.` Financial reporting now uses explicit gross-profit vs net-profit rules with stronger COGS fallback from inventory/procurement cost data when sale items do not carry direct cost values.
- `20.` Owner sign-in now rejects worker accounts directly and routes staff back to the worker-login path.
- `17.` Inventory export now supports web download flows from both the inventory screen and the inventory report screen.
- `21.` Manual subscription receipt submissions now go through a pending-approval gate instead of activating access immediately.
- `23.` Product, worker, restaurant-menu, restaurant-table, hotel-room, and bar table-session creation flows now surface or hard-stop on per-business plan limits using normalized business-class / plan-level rules.
- `27.` Admin payment approval now writes recognized-revenue audit fields, and admin revenue totals now count approved/recognized payment records instead of estimated subscription tiers.
- `30.` Restricted-business checks now reroute affected users from login/splash into a dedicated holding screen with the saved admin reason and support-contact guidance, and already-open sessions are now kicked into that holding flow when the business becomes restricted live.
- `31.` Admin user access now merges the `users` and `workers` tables so the Users & Workers area can inspect both sources from one place.
- `33.` Bar POS now lets staff save customer/table invoices from checkout, edit/reopen saved tabs from Tabs & Invoices, and convert them into completed sales without re-entering the order.
- `34.` Bar invoices can now be converted directly into completed sales from the new Tabs & Invoices flow, so staff do not need to re-enter the order after payment.
- `35.` Bar invoices are now stored persistently in invoice records under the business, with open, converted, and cancelled states visible from the new Tabs & Invoices screen.
- `44.` Hotel room-service and other billable service requests now flow into reservation folios so room charges can roll into the final room bill at checkout.
- `45.` Hospitality table/order handling is now stored to Firestore with restaurant-side local cache warmup for tables, orders, reservations, staff, and waste logs, while existing bar tabs/invoices continue to carry customer and table labels.
- `Hospitality.` Hotels now have dedicated Firestore-backed hall-booking and pool-booking screens, including hall time/capacity/decoration/features capture and pool booking by persons and hours.
- `Hospitality.` Hotel worker-role setup now supports receptionist, front desk, waiter, housekeeper, HR, and manager role presets with expanded role-permission mapping.
- `47.` Hotel reservations now support extra folio charges and stay-extension updates from the booking details flow.
- `48.` Restaurant open-table orders now stay active until payment, checkout groups served/completed-but-unpaid tables under an awaiting-payment flow, and the updated hospitality POS/billing surfaces now use NGN display formatting.
- `49.` Restaurants now have a dedicated stock screen for hospitality inventory review and actioning stock-loss records separately from the general dashboard.
- `50.` Restaurant leftovers and spoilage can now be logged against inventory, with Firestore history plus cached visibility in the new restaurant stock flow.
- `Kitchen / Restaurant.` Restaurant setup now exposes direct register-table and add-menu-item entry points, preset table sizes for 2/3/4/6/8/10 seats, and kitchen meal modifier setup for soup/stew, protein quantity, and dine-in vs take-away options.
- `55.` Marketer analytics now split client lists into active, inactive, expiring, rejected, and needs-business buckets so marketers and admins can track live versus non-live client states directly.
- `56.` Marketers and admins now have a monthly ranking board fed from marketer performance snapshots, including rank, wins, active clients, and projected bonuses.
- `57.` Marketer overview and dashboard flows now expose proper loading states and refresh handling while target/progress performance data is fetched.
- `58.` Marketer client cards and admin marketer views now show subscription-expiry visibility, including expiring-soon and expired states.
- `60.` Gas dashboard totals now read fuel sales metrics from recorded sales history so pump sales are reflected inside dashboard revenue, transaction, and volume summaries.
- `61.` Gas businesses now have a dedicated gas-stock screen for adding fuel products and updating fuel inventory separately from the generic procurement screen.
- `64.` Pharmacy prescription flow now supports age-aware attachment/reference requirements for minors and printable prescription output alongside the existing receipt-actions flow.
- `65.` Pharmacy now has a direct prescription-creation and printing screen where staff can create/select patients, capture notes/attachments, and save prescriptions without going through the sales checkout first.
- `66.` Pharmacy workers now land on the pharmacy dashboard with prescription stats, recent-prescription visibility, and role-gated prescription actions tied to worker permissions.
- `67.` Worker auth now listens to a broader set of live user-document updates so role, store, business, activation, and other permission-related changes reach active sessions faster.
- `22.` Subscription reminder/status checks now resolve against the currently selected business, and switching businesses now refreshes the owner's synced subscription summary for that business instead of relying only on a shared owner-level subscription snapshot.
- `70.` Tier 1 limit rules are now centralized in the new subscription service and business-provider checks, so current-business plan enforcement can read normalized per-business limits and feature access rules.
- `71.` Tier 2 businesses now use the same per-business plan catalog / limit model instead of the old owner-level basic/pro mapping when subscription checks and plan selection screens resolve access.
- `72.` Tier 3 businesses now use the same per-business plan catalog / limit model, including normalized feature access checks for higher-tier subscription capabilities.
- `73.` Core subscription flows no longer depend on the older basic/pro-only owner model; login, splash, payment, status, settings, marketer registration, and business-switch flows now use business-specific tier plans.
- `74.` Premium / unlimited rules and differentiated pricing are now defined centrally in the shared subscription catalog, including separate standard, kitchen, lounge, and hospitality business families, and `drink` businesses now resolve against the lounge plan family for pricing/limits.
- `76.` Hospitality-aware subscription-family / tier calculation is now wired into onboarding and plan-selection logic so business type drives the applicable subscription structure more accurately.
- `Cross-cutting.` Subscription truth is now stored on each business document, while the user document keeps a synced summary of the currently selected business so multi-business owners are checked against the active business plan.
- `Cross-cutting.` Sales checkout, procurement management, advanced analytics, the login auth card, and the marketer business-registration flow now follow dark-mode surfaces and contrast more reliably instead of forcing light cards/sections.
- `15.` Current-business switching now follows a coordinated auth-plus-business-provider handoff with explicit syncing state, stale metric hiding, and restaurant data reinitialization so owners see less old-business bleed-through while changing businesses.
- `Cross-cutting.` The owner dashboard now has a refreshed visual shell with a more polished bottom navigation bar, stronger business-card feedback, and visible sync status while business context changes are in flight.
- `Cross-cutting.` Restaurant pending-checkout, overview, and table-management screens now adapt more cleanly to smaller screens with stacked checkout layout, responsive cards, and mobile-friendlier management dialogs.
- `Cross-cutting.` Retail POS now supports multiple open cart sessions with create, switch, rename, and close actions so workers can hold more than one active customer cart at the same time.
- `Cross-cutting.` User profiles now support richer editable details including job title and address, and those fields persist to both the user profile and business-scoped settings documents.
- `Cross-cutting.` Owner-side business deletion now updates Firestore and local cached business references more completely, including fallback current-business selection and removal of deleted business IDs from cached owner context.
- `13.` Retail checkout now supports a manager-only discount control in the retail checkout sheet, and approved discounts flow through sale totals, receipts, and invoice generation.
- `Cross-cutting.` Active receipt and invoice PDF generation now uses refreshed branded layouts built for 58mm and 80mm output, with smaller Manage Care footer branding, stronger Naira/NGN font fallback handling, and tier-3 business-logo support on generated documents.
- `Cross-cutting.` Receipt-share image generation now uses a designed branded card instead of a plain screenshot-style export, keeps the Manage Care logo small in the footer, and shows the business logo in the header for qualifying tier-3 businesses.
- `Cross-cutting.` Web financial-report PDF export now passes the current business branding details into the shared generator so exported documents stay aligned with the active business context.
- `Cross-cutting.` The legacy thermal receipt PDF helper now uses the shared currency/font handling so fallback document output no longer emits non-Naira placeholders.
- `Apartment.` Apartment businesses now have a fuller routed dashboard with live apartment, unit, occupancy, and booking metrics, plus apartment add/edit/delete flow, better unit-management controls, and more usable booking management screens.
- `Apartment.` Apartment booking creation now writes through the real current-business booking path instead of guessing the business from apartment IDs, which makes apartment reservations safer and more consistent.

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

- `10.` Menu-button behavior still needs work after the auto-rotate fix.
- `15.` Business switching is smoother now for owner current-business changes, but same-device owner/worker account switching and broader sync lag still need more work.
- `21.` Manual receipt approval is safer now, but processor-side verification and broader payment-approval flow still need work.
- `22.` Expired-owner gating and current-business reminder checks are tighter now, but reminder timing and explicit post-expiry grace-period rules still need work.
- `23.` Hard-stop upgrade enforcement now reaches product, worker, restaurant-menu, restaurant-table, hotel-room, and bar table-session creation flows, but broader rollout across the rest of the app still needs more detail and implementation.

### Bar / Invoice

- `33.` Bar POS now supports saved customer/table invoices, tab-style conversion to sales, edit/reopen flows, and active-subscription / open-table-session gating, but fuller retail parity still needs more work around deeper table service and broader bar workflow polish.

### Hospitality

- `45.` Restaurant table lifecycle, caching, Firestore persistence, and current-business table-limit enforcement are now stronger, but deeper end-to-end kitchen/bar table-service parity may still need more polish.
- `Hospitality worker access.` Hotel staffing now supports richer role presets, but fully custom per-worker permission matrices beyond role presets still need more work.

### Subscription / Pricing Structure

- `70.` Tier 1 limits now exist in the shared subscription layer, and hard-stop enforcement now covers products, workers, restaurant tables/menu, hotel rooms, and bar table sessions, but wider rollout across the app still needs more work.
- `71.` Tier 2 limits now exist in the shared subscription layer, and hard-stop enforcement now covers products, workers, restaurant tables/menu, hotel rooms, and bar table sessions, but wider rollout across the app still needs more work.
- `72.` Tier 3 limits now exist in the shared subscription layer, and hard-stop enforcement now covers products, workers, restaurant tables/menu, hotel rooms, and bar table sessions, but wider rollout across the app still needs more work.
- `73.` Core subscription restructuring is now in place, but remaining cleanup of old admin/reporting terminology and legacy plan assumptions still needs work.
- `74.` Premium / unlimited rules and pricing now exist in the subscription catalog, but broader UI/admin/reporting support still needs more work.
- `76.` Hospitality-aware tier calculation is now wired into the subscription system, and hotel-room / restaurant-table / bar-table workflow enforcement is stronger, but deeper enforcement across all hospitality workflows still needs work.
- `77.` Hospitality multi-service rule is noted, but still needs full enforcement review.

### Cross-cutting

- `Cross-cutting.` Active receipt, invoice, and receipt-image flows now use the newer branded document system, but some older low-usage legacy document helpers still need consolidation onto the same design/runtime path.

## Verification Notes

- Targeted tests were added for inventory unit normalization and inventory CSV export generation.
- Automated `flutter test` execution could not be completed in this session because `flutter`/`dart` are not available on this machine's PATH.
