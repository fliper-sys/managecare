# Updates And Fixes Completed

Date: 2026-05-25

This document summarizes the fixes and implementation updates completed from the `fixes_yet_to_be_made.md` backlog.

## Retail, Bar, And Invoice Fixes

- Added subscription access checking before retail invoice generation from the sales screen.
- Improved retail invoice generation so customer details are preserved on saved invoice records.
- Added bar invoice preview/share support from the Tabs & Invoices screen.
- Added bar invoice print support using web PDF printing on web and share-based print handoff on mobile/desktop.
- Added customer ID, email, and phone fields to bar sale maps so receipt/post-sale flows keep customer linkage.
- Hardened bar invoice totals by clamping tax/discount inputs and preventing negative totals.
- Preserved customer details when converting bar invoices into completed sales.
- Added preferred bar table and common-purchase tracking for bar customers.
- Added product activity logging for retail inventory create/update/delete actions.
- Improved procurement stock updates by writing both `quantity` and `stock` so older and newer inventory readers stay aligned.

## Kitchen And Restaurant Fixes

- Added ingredient/supply linkage to restaurant menu items.
- Added portion-based ingredient costing during menu creation/editing.
- Preserved menu item IDs during edits so menu items do not disappear after reload.
- Improved order item parsing so kitchen receipts and reopened orders prefer item names instead of raw item numbers.
- Added menu shortage and supply shortage sections to restaurant stock views.
- Made restaurant shortage visibility permission-aware.
- Added ingredient stock deduction for direct restaurant checkout.
- Added ingredient stock deduction for pending-order checkout.
- Preserved modifier/protein-style price additions in restaurant cart/order totals.

## Hospitality Fixes

- Wired room-charge order creation into restaurant ordering.
- Preserved room-charge context through pending checkout and sales records.
- Added dedicated hospitality billing permission checks.
- Expanded hotel/hospitality worker role presets and aliases.
- Added broader hospitality permissions for guest checkout, room service, billing, bookings, reports, and low-stock visibility.

## Admin And Access-Control Fixes

- Hardened restricted-business detection for deleted, inactive, deactivated, restricted, suspended, and blocked businesses.
- Prevented restricted/deactivated businesses from falling through into subscription or app flows.
- Added clearer restricted-business support fallback messaging.
- Expanded support contact lookup to admin settings and business-level support fields.

## Pharmacy, Gas, Marketing, And Other Completed Work

- Completed pharmacy workflow fixes from the earlier backlog pass.
- Completed gas sales-history receipt view/reprint updates.
- Completed marketer reward/tier enforcement updates.
- Completed retail/gas/marketer backlog cleanup from the previous implementation pass.
- Verified real-estate dashboard quick actions use real-estate workflows instead of retail procurement/inventory actions.

## Verification

- `git diff --check` passed with only existing CRLF line-ending warnings.
- Flutter/Dart validation could not be completed in this shell because `flutter --version` and `dart --version` timed out.

## Remaining Non-Retail Backlog

- Dark mode polish still needs app-wide visual QA.
- Multi-store reporting still needs separate per-store report views across sales, daily sales, inventory reports, and procurement history.
- Installation icon cleanup/removal still needs a dedicated asset pass.
- Inventory assignment between stores still needs owner-side per-item/per-quantity transfer tooling.
- Subscription/pricing rollout work remains for reminder timing, legacy terminology, unlimited-plan UI/reporting coverage, hospitality-aware enforcement, and hard-stop coverage.
- Legacy receipt/invoice/document helpers still need consolidation into the newer branded document system.
