# Update Summary: Past Two Weeks (2026-06-10 to 2026-06-21)

Date: 2026-06-22

This document summarizes all major new features, fixes, and updates implemented in the Manage Care project during the past two weeks.

## Scope

Coverage includes:
- new feature work
- bug fixes and stability updates
- UI/dashboard redesigns
- industry-specific module improvements
- report, invoice, receipt, and printing fixes
- worker permission and access control updates
- subscription / financial flow corrections

## High-level summary

Work in this period focused on delivering stronger business workflows and fixing persistent edge cases in the core app.
- Pharmacy: cleaned up patient dashboard duplication, stabilized patient selection, and linked prescription records directly to POS sales.
- Reports: fixed multiple broken report screens and corrected the underlying repository math so totals now match expected customer, expense, and inventory figures.
- Invoice/receipt: improved print and share flows, especially for web and mobile, so invoices preserve customer details and invoice actions remain available after sale.
- Worker permissions: tightened restaurant and hospitality authorization checks so workers no longer inherit unauthorized access by default.
- Dashboard redesigns: updated owner, real-estate, gas, and gym dashboards with clearer metrics and improved navigation.
- Auto module: fixed auto-specific role assignment and enabled explicit customer-vehicle linkage in service order workflows.
- Cleanup and stability: removed dead code, fixed offline sales sync issues, and improved overall state consistency between screens.

## Major module updates

### Pharmacy

- Fixed dashboard duplicate entries that were appearing when the pharmacy dashboard list refreshed; the patient list now filters correctly and avoids repeated rows.
- Fixed patient picker behavior so the correct patient is selected when a pharmacy worker chooses a patient during sale or prescription creation.
- Improved prescription flow by linking saved prescriptions to sales and enabling prescriptions to appear in patient treatment history.
- Added treatment dose logging for pharmacy patients, including dose frequency and duration fields that now persist correctly in patient records.
- Stabilized pharmacy POS and patient records screens, reducing crashes and inconsistent state when switching between patients, prescriptions, and sales.
- Updated `lib/providers/pharmacy_provider.dart`, `pharmacy_pos_screen.dart`, `patient_records_screen.dart`, and pharmacy dashboard screens.

### Reports and financials

- Fixed multiple report generation bugs in customer reports, expense reports, sales reports, inventory reports, financial breakdown, and financial report screens.
- Corrected filtering and date-range logic so each report loads the expected dataset when the user selects a period, business, or branch.
- Updated `lib/providers/reports_provider.dart` to handle both report refresh and export states reliably, preventing stale totals after screen navigation.
- Fixed mismatched financial report totals by ensuring revenue, cost, gross profit, and net profit calculations use the same sales and inventory reconciliation logic.
- Updated `sales_repository_impl.dart` to align report payloads with actual sales records and to avoid double-counting in summary reports.
- Added small UX fixes that improve the export/report screen behavior, such as preserving selected filters after refresh.

### Sales, invoices, receipts, and printing

- Improved invoice print/share behavior across retail, bar, and restaurant flows so customer contact details and business branding now persist into printed and shared documents.
- Fixed invoice totals by clamping discount/tax values and ensuring the PDF generator uses the correct sale currency, unit, and customer pricing context.
- Improved print dialog flows on web and mobile, reducing cases where printing would fail or stay stuck in a loading state.
- Updated the post-sale action sheet so invoice and receipt actions are preserved after a sale completes, allowing users to still print, share, or save documents.
- Fixed offline sales sync issues where receipts failed to generate after retrying a network sync.
- Corrected PDF and receipt generator service behavior for both IO and web contexts; receipts now include accurate item names and do not lose line-item pricing.
- Files touched include:
  - `sales_screen.dart`
  - `post_sale_action_sheet.dart`
  - `checkout_sheet.dart`
  - `pdf_invoice_generator_io.dart`
  - `pdf_invoice_generator_web.dart`
  - `pdf_receipt_generator_io.dart`
  - `pdf_receipt_generator_web.dart`
  - `offline_sales_service.dart`
  - `sync_service.dart`
  - `receipt_manager.dart`

### Worker permissions and authorization

- Enhanced worker permission checks in the restaurant dashboard so unauthorized workers no longer see or access restricted sections such as procurement, inventory adjustment, and billing access.
- Added and refined permission handling across hotel, restaurant, retail, and worker-management screens, improving the enforcement of role-based restrictions.
- Fixed worker creation and update flows so selected permissions are now respected immediately instead of defaulting to broader access.
- Updated core permission utilities in `lib/core/utils/worker_permissions.dart` to support restaurant-specific and hospitality-specific permission rules.
- Updated screens that were affected by these fixes:
  - `worker_management_screen.dart`
  - `worker_details_screen.dart`
  - `add_worker_screen.dart`
  - `worker_inventory_screen.dart`

### Dashboard redesign and UI updates

- Redesigned the owner dashboard layout to make business summary cards clearer and reduce clutter in the top-level business overview.
- Updated the real-estate dashboard to better surface quick actions for property management, rent collection, and tenant reminders.
- Refined the gas stock screen with improved section grouping and clearer stock status indicators for fuel and gas inventory.
- Updated the gym dashboard with a cleaner report layout and clearer KPI presentation.
- Applied broader dashboard polish across owner, hotel, real estate, and other industry dashboards to improve navigation and reduce layout inconsistencies.
- Affected files include `owner_dashboard_screen.dart`, `gas_stock_screen.dart`, `gym_dashboard_screen.dart`, and `realestate_dashboard_screen.dart`.

### Auto module and customer linkage

- Fixed auto module role assignment so mechanics and service staff no longer receive incorrect access privileges or module roles.
- Added explicit customer-vehicle linkage in the auto service order flow so each service request now ties directly to both the customer and the selected vehicle.
- Improved auto service and repair order screens to show job status consistently and preserve customer/vehicle relationships across order edits.
- Updated providers and route handling in the auto module so service orders are loaded with the correct customer and business context.

### Retail and general sales flow fixes

- Removed the obsolete Product Catalog feature from the retail flow, simplifying the sales UI and preventing duplicate catalog access points.
- Fixed cost summary bugs on report screens and corrected inventory export interactions so exported data now matches the in-app report values.
- Improved checkout and cart behavior across retail and restaurant modules, including better handling of product quantity, unit conversion, and sale price context.
- Corrected gross/net profit calculations in mixed retail/wholesale inventory flows by fixing the underlying pricing context and preventing wholesale units from overriding retail unit totals.
- These fixes reduce discrepancies in sales totals and make report output reliable across business types.

## Additional work and cleanup

- Performed dead code cleanup in key backend repository classes, including `pharmacy_repository.dart`, `offline_sync_repository_impl.dart`, and `sales_repository_impl.dart`.
- Updated owner dashboard logic and auth provider behavior to reduce stale state issues when switching between businesses and worker accounts.
- Fixed sync and offline state stability in sales and inventory modules so cached sales now resume correctly after reconnecting.
- Corrected errors that caused failed refreshes in the sales screen and improved fallback handling for offline invoice generation.
- Updated `lastupdates.md` and project notes to reflect completed work and to keep the implementation backlog aligned with the actual fixes.

## Notable files changed

- `lib/providers/reports_provider.dart`
- `lib/providers/auth_provider.dart`
- `lib/providers/pharmacy_provider.dart`
- `lib/core/utils/worker_permissions.dart`
- `lib/data/repositories/sales_repository_impl.dart`
- `lib/presentation/sales/screens/sales_screen.dart`
- `lib/presentation/hotel/screens/guest_management_screen.dart`
- `lib/presentation/retail/screens/retail_dashboard.dart`
- `lib/presentation/auto/screens/create_service_order_screen.dart`
- `lib/presentation/auto/screens/repair_jobs_screen.dart`
- `lib/presentation/pharmacy/screens/pharmacy_pos_screen.dart`
- `lib/presentation/reports/screens/export_report_screen.dart`
- `lib/presentation/reports/screens/expense_report_screen.dart`
- `lib/presentation/workers/screens/worker_management_screen.dart`
- `lib/services/pdf_invoice_generator_web.dart`

## Summary of dates and commit window

This summary covers commits made between June 10, 2026 and June 21, 2026, including:
- `8250b8a` through `faa28a8`
- key commit topics: pharmacy fixes, reports fixes, permission fixes, dashboard redesign, auto module improvements, invoice printing updates, and cleanup work.

## Result

The last two weeks of work delivered improved stability and workflow support across the core retail/bar/restaurant application, strengthened industry-specific modules (pharmacy, auto, gas, hotel, real estate), and corrected major report, invoice, and permissions issues.
