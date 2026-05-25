# Updates Status Report - Completed Items

Date created: 2026-05-25
Source document: [UPDATES_STATUS_REPORT_2026-04-01.md](/c:/Users/USER/Desktop/mc/docs/UPDATES_STATUS_REPORT_2026-04-01.md)

This document lists the updates from the April 1, 2026 status report that can be marked as `Complete`.

Rules used for this document:

- Items under `Done In This Pass` were marked `Complete`.
- Items under `Source-Marked Complete Or Working` were also marked `Complete` based on the source notes already captured in the original report.
- Items under `Needs More Work Or Is Only Partially Done` were not included here.

## Completed Items

### Retail

- `2.` Complete - Subscription days-left issue fixed.
- `3.` Complete - Inventory download/export now works from the main inventory screen.
- `4.` Complete - Product procurement and sales history on product click is working.
- `5.` Complete - Expiry tracking and expiry notification flow is working.
- `6.` Complete - Low-stock threshold selection fixed.
- `7.` Complete - Procurement supports richer unit handling and compatible unit choices.
- `8.` Complete - Procurement batches preserve batch-level quantity, weighted cost, supplier/reference traceability, and optional expiry data.
- `9.` Complete - Procurement changes now reflect in activity log and product history.
- `11.` Complete - Owner home-page `Products`, `Customers`, and `Staff` chips now navigate correctly.
- `12.` Complete - Product search issue marked working.
- `13.` Complete - Retail products support wholesale pricing, sale-unit / inventory-unit differentiation, checkout switching, and manager discount flow.
- `14.` Complete - Invoice flow supports existing customer selection or inline new-customer creation.
- `16.` Complete - Financial reporting now separates gross profit and net profit rules more clearly.
- `17.` Complete - Inventory export supports web downloads from both inventory and inventory report screens.
- `18.` Complete - Admin product change tracking on inventory page marked working.
- `19.` Complete - Worker feature restriction selection fixed.
- `20.` Complete - Owner sign-in rejects worker accounts and routes staff to worker login.
- `21.` Complete - Manual subscription receipt submissions now go through pending approval instead of granting immediate access.
- `22.` Complete - Subscription reminder/status checks resolve against the currently selected business.
- `23.` Complete - Tier-limit enforcement now covers key creation flows such as products, workers, menu/tables, hotel rooms, and bar sessions.
- `24.` Complete - Registration/business-selection lock-up fixed.

### Admin

- `26.` Complete - Admin home-page filtering buttons fixed.
- `27.` Complete - Admin payment approval now writes recognized-revenue audit fields and counts approved revenue correctly.
- `28.` Complete - Admin business detail visibility fixed.
- `29.` Complete - Duplicate business display fixed.
- `30.` Complete - Restricted businesses are rerouted into a dedicated holding/restricted flow with support guidance.
- `31.` Complete - Admin user access now merges `users` and `workers` into one inspectable area.

### Bar

- `33.` Complete - Bar POS supports saved customer/table invoices and tab-style reopen/edit flows.
- `34.` Complete - Bar invoices can be converted directly into completed sales.
- `35.` Complete - Bar invoices are stored persistently in invoice records.

### Real Estate

- `37.` Complete - Properties inventory rename / property management marked working.
- `38.` Complete - Rent/short-let payment details and reminders marked working.
- `39.` Complete - Property document uploads marked working.

### Hospitality / Hotel / Restaurant

- `41.` Complete - Multi-service hospitality support marked working.
- `42.` Complete - Hospitality registration option selection marked working.
- `43.` Complete - Room registration and checkout alerting marked working.
- `44.` Complete - Hotel room-service and billable service requests now flow into folios for final billing.
- `45.` Complete - Hospitality table/order handling is stored to Firestore with stronger caching and persistence support.
- `46.` Complete - Worker order button for available inventory items marked working.
- `47.` Complete - Hotel reservations support extra folio charges and stay extensions.
- `48.` Complete - Open-table restaurant orders stay active until payment and awaiting-payment handling is in place.
- `49.` Complete - Restaurants now have a dedicated stock screen.
- `50.` Complete - Restaurant leftovers and spoilage can be logged against inventory.
- `Hospitality.` Complete - Hotels now have Firestore-backed hall-booking and pool-booking screens.
- `Hospitality.` Complete - Hotel worker-role setup supports richer role presets.
- `Kitchen / Restaurant.` Complete - Restaurant setup exposes direct table registration, add-menu-item flows, preset table sizes, and meal-modifier setup.

### Marketing

- `52.` Complete - Admin can create marketer accounts.
- `53.` Complete - Admin commission allocation / marketer visibility marked working.
- `54.` Complete - Marketer email referral linking marked working.
- `55.` Complete - Marketer analytics split client lists into active, inactive, expiring, rejected, and needs-business buckets.
- `56.` Complete - Monthly marketer ranking board is available for marketers and admins.
- `57.` Complete - Marketer overview/dashboard flows expose loading states and refresh handling for target/progress data.
- `58.` Complete - Marketer and admin views now show subscription-expiry visibility.

### Gas

- `60.` Complete - Pump sales now flow into dashboard totals.
- `61.` Complete - Gas businesses now have a dedicated gas-stock screen.
- `62.` Complete - Non-fuel gas products still use inventory/procurement and are marked working.

### Pharmacy

- `64.` Complete - Prescription flow supports age-aware attachment/reference requirements and printable prescription output.
- `65.` Complete - Pharmacy has a direct prescription-creation and printing screen.
- `66.` Complete - Pharmacy workers land on the pharmacy dashboard with role-gated prescription actions.
- `67.` Complete - Worker auth now reacts faster to live user-document permission updates.

### Apartment

- `Apartment.` Complete - Apartment businesses now have a fuller routed dashboard with apartment, unit, occupancy, and booking metrics.
- `Apartment.` Complete - Apartment booking creation now uses the current-business booking path safely.

### Payment Structure And Subscription

- `69.` Complete - Automatic tier grading during registration marked working.
- `70.` Complete - Tier 1 limit rules are centralized in the subscription service and business checks.
- `71.` Complete - Tier 2 businesses now use the same per-business plan catalog and limit model.
- `72.` Complete - Tier 3 businesses now use the same per-business plan catalog and limit model.
- `73.` Complete - Core subscription flows now use business-specific tier plans instead of the older basic/pro-only owner model.
- `74.` Complete - Premium/unlimited rules and differentiated pricing are defined centrally in the shared subscription catalog.
- `75.` Complete - Hotels, bars, kitchen, and lounge grouped under hospitality marked working.
- `76.` Complete - Hospitality-aware subscription family / tier calculation is wired into onboarding and plan-selection logic.

### Cross-Cutting

- `Cross-cutting.` Complete - Subscription truth now lives on each business document, with synced current-business summary on the user document.
- `Cross-cutting.` Complete - Dark-mode surfaces and contrast were improved across checkout, procurement, analytics, auth card, and marketer registration flows.
- `Cross-cutting.` Complete - Owner dashboard visual shell refreshed with improved navigation, sync feedback, and business-card behavior.
- `Cross-cutting.` Complete - Restaurant pending-checkout, overview, and table-management screens are more responsive on smaller screens.
- `Cross-cutting.` Complete - Retail POS supports multiple open cart sessions.
- `Cross-cutting.` Complete - User profiles now support richer editable details such as job title and address.
- `Cross-cutting.` Complete - Owner-side business deletion updates Firestore and local cached business references more completely.
- `Cross-cutting.` Complete - Active receipt and invoice PDF generation uses refreshed branded layouts for 58mm and 80mm output.
- `Cross-cutting.` Complete - Receipt-share image generation now uses a branded card layout.
- `Cross-cutting.` Complete - Web financial-report PDF export now includes current business branding.
- `Cross-cutting.` Complete - Legacy thermal receipt PDF helper now uses shared currency/font handling.

## Notes

- This document intentionally excludes the items that the source report still describes as partial or still needing more work.
- Some entries above are marked complete because the source report explicitly described them as done, fixed, or working, even where earlier backlog notes had left them pending.
