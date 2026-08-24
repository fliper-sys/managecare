# Retail, Hospitality, Petroleum, Bakery, and Pharmacy Fixes Status

Generated: 2026-08-24

This document summarizes the issues that were sent, the current implementation status, and the main files changed.

## Verification Notes

- `node --check server/managecare-backend/routes/sales.js` passed.
- `node --check server/managecare-backend/routes/hotel.js` passed.
- `node --check server/managecare-backend/routes/pumps.js` passed.
- `git diff --check` passed with only existing line-ending and local git config permission warnings.
- `dart format` and targeted `dart analyze` were attempted, but both hung in this environment and were stopped.

## Retail Fixes

| # | Request Sent | Status | Notes / Files |
|---|---|---|---|
| 1 | Financial report breakdown formulas for total sales, gross profit, net profit, operating expenses, and COGS were wrong. | Done | Financial calculations were updated to use final sale revenue, returns, COGS from item cost data, and expenses. Main file: `lib/providers/reports_provider.dart`. |
| 2 | Some inventory products were not showing under procurement, even after recreation. | Done | Procurement product loading now uses the inventory repository path and includes refresh behavior. Main files: `lib/presentation/dashboard/owner/screens/procurement_screen.dart`, `lib/data/repositories/procurement_repository.dart`. |
| 3 | Downloaded procurement records did not show item name, unit type, or dates in product-related rows. | Done | Procurement CSV/PDF exports now include item name, date, quantity, unit, purchase unit, unit cost, and totals. Main files: `lib/data/repositories/procurement_repository.dart`, `lib/services/report_export_service.dart`. |
| 4 | Workers could not choose wholesale or retail per product after carting items; only the whole cart could be converted. | Done | Per-item Retail/Wholesale chips are available in the cart and checkout sheet. Main files: `lib/presentation/sales/screens/sales_screen.dart`, `lib/providers/retail_provider.dart`. |
| 5 | Retail business did not have mixed payment method. | Done | Mixed payment is supported online and offline, including local DB, sync, reports, receipt sheets, and backend endpoints. Main files: `lib/providers/retail_provider.dart`, `lib/data/local/database_helper.dart`, `lib/data/repositories/sales_repository_supabase.dart`, `lib/services/sync_service_supabase.dart`, `server/managecare-backend/routes/sales.js`, `functions/routes/sales.js`, `server/managecare-backend/migration_043.sql`. |
| 6 | Procurement submit flow did not allow users to inspect and edit entries before submitting. | Done | Procurement confirmation now shows current selected entries with edit/remove actions before submit. Main file: `lib/presentation/dashboard/owner/screens/procurement_screen.dart`. |
| 7 | Downloaded sales report showed two lists, with the useful report only after scrolling halfway; first report did not show sold items. | Done | Duplicate sale-level transaction table was removed from the generated PDF, leaving the item-level report with sold items. Main file: `lib/providers/reports_provider.dart`. |
| 8 | Advanced procurement analysis should show most procured item within a time period, quantity procured, and total cost. | Done | Added procurement analysis card in advanced analytics. Main file: `lib/presentation/dashboard/analytics/advanced_analytics_dashboard_screen.dart`. |
| Extra | Add offline display to procurement screen. | Done | Procurement screen includes offline-aware product/entry behavior and refresh support. Main file: `lib/presentation/dashboard/owner/screens/procurement_screen.dart`. |
| Extra | Add product refresh button to procurement screen like sales screen. | Done | AppBar refresh action reloads all products and clears stale product filters. Main file: `lib/presentation/dashboard/owner/screens/procurement_screen.dart`. |
| Extra | Add text printing USB feature to sales history for Windows from print sheet. | Done / Existing Path Confirmed | Sales history opens `PrintingActionSheet`, which shows `Plain Text (USB)` on Windows. Main files: `lib/presentation/sales/screens/sales_history_screen.dart`, `lib/presentation/shared/printing_action_sheet.dart`, `lib/services/windows_raw_print_service.dart`. |

## Hospitality Fixes

| # | Request Sent | Status | Notes / Files |
|---|---|---|---|
| 1 | Edit room details button under room management/settings was not working. | Done | Room edit now opens the room form prefilled and persists through repository update. Main files: `lib/presentation/industry_specific/hotel/screens/room_list_screen.dart`, `lib/presentation/industry_specific/hotel/screens/create_room_screen.dart`, `lib/providers/hotel_provider.dart`, `lib/data/repositories/industry_specific/hotel_repository.dart`, `lib/data/repositories/industry_specific/hotel_repository_impl.dart`. |
| 2 | Checkout history showed unpaid even when payment had been made. | Done | Checkout now uses one paid checkout method that updates reservation/payment status and frees the room together. Main files: `lib/presentation/industry_specific/hotel/screens/check_out_screen.dart`, `lib/providers/hotel_provider.dart`. |
| 3 | Hospitality work page/admin and worker hospitality section went blank from time to time. | Improved / Needs UI verification | Hotel dashboard is now stateful and reloads the provider when business context changes. Main file: `lib/presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart`. |
| 4 | After guest check-in, homepage occupants/revenue/sales were not updated. | Improved / Needs UI verification | Dashboard now binds to business/provider initialization so occupancy and today's sales can refresh from provider state. Main file: `lib/presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart`. |
| 5 | Tabs such as new bookings, front desk, bookings, check-ins should be removed because users can access them from the first check-in guest tab. | Already aligned / Needs UI verification | Current dashboard quick actions are consolidated around Check-In/Guests rather than separate new booking/front desk/check-in tabs. Main file checked: `lib/presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart`. |

## Petroleum Fixes

| # | Request Sent | Status | Notes / Files |
|---|---|---|---|
| 1 | Add cash breakdown on pump upload page for naira denominations and auto-sum into amount received in cash. | Done | Added denomination inputs for 1000, 500, 200, 100, 50, 20, 10, and 5 naira notes; cash total is auto-calculated and stored. Main files: `lib/presentation/industry_specific/gas/screens/pump_daily_upload_screen.dart`, `server/managecare-backend/routes/pumps.js`, `server/managecare-backend/migration_044.sql`, `server/managecare-backend/migration_026.sql`, `lib/presentation/industry_specific/gas/utils/pump_row_mapper.dart`. |
| 2 | WhatsApp messages should carry inventory stock for petroleum products only. | Done | Petroleum WhatsApp stock output now filters to petroleum/fuel products instead of all inventory. Main file: `lib/services/whatsapp_service.dart`. |
| 3 | Workers using web/mobile had no settings access such as dark mode. | Done | Worker dashboard now exposes settings access in quick navigation. Main file: `lib/presentation/dashboard/worker/worker_dashboard_screen.dart`. |
| 4 | Upload history showed under retail sales history; upload history should only show under upload/general history. | Done | Retail sales history now filters fuel/pump-linked upload sales out of normal retail history and totals. Main file: `lib/providers/retail_provider.dart`. |
| 5 | Add bank deposit tab/icon under expenses for managers/higher accounts with depositor, date/time, amount, bank details, receipt upload, and history. | Done | Added petroleum bank deposits screen, route, dashboard entry, backend endpoints, and migration. Main files: `lib/presentation/industry_specific/gas/screens/petroleum_bank_deposit_screen.dart`, `lib/presentation/industry_specific/gas/screens/gas_dashboard_screen.dart`, `lib/core/constants/routes.dart`, `lib/routes/app_router.dart`, `server/managecare-backend/routes/pumps.js`, `server/managecare-backend/migration_045.sql`. |
| 6 | General sales history homepage revenue, volume, and transactions showed zero. | Done | Fuel metrics now combine standalone fuel sales and pump uploads while avoiding double counting linked sales. Main file: `lib/providers/retail_provider.dart`. |

## Bakery Fixes

| # | Request Sent | Status | Notes / Files |
|---|---|---|---|
| 1 | Distributor discount should not be limited to 100 naira; admins/users should set discount at their discretion. | Done | Product form now includes distributor discount percent input without the old fixed 100 naira limitation. Main file: `lib/presentation/industry_specific/retail/screens/add_product_screen.dart`. |
| 2 | Bakery performance report should be taken to the report page. | Already done / Confirmed | Existing routes and report dashboard include Bakery Performance report. Main files checked: `lib/presentation/reports/screens/reports_dashboard_screen.dart`, `lib/core/constants/routes.dart`, `lib/routes/app_router.dart`. |

## Pharmacy Fixes

| # | Request Sent | Status | Notes / Files |
|---|---|---|---|
| 1 | Pharmacy colors should be changed to ManageCare colours. | Done | Pharmacy color constant now uses ManageCare primary, and hard-coded pharmacy green app bars were moved to `AppColors.pharmacy`. Main files: `lib/core/theme/colors.dart`, pharmacy screens under `lib/presentation/industry_specific/pharmacy/screens/`. |
| 2 | Inventory items were not reflecting under new sale page; existing products showed "inventory item not found" when selling or performing actions. | Done | Pharmacy POS checkout now records through the shared REST sales repository instead of old Firestore inventory docs, matching the inventory-backed pharmacy repository. Main files: `lib/presentation/industry_specific/pharmacy/screens/pharmacy_pos_screen.dart`, `lib/data/repositories/industry_specific/pharmacy_repository_impl.dart`. |

## Additional Files Added

- `lib/presentation/industry_specific/gas/screens/petroleum_bank_deposit_screen.dart`
- `server/managecare-backend/migration_043.sql`
- `server/managecare-backend/migration_044.sql`
- `server/managecare-backend/migration_045.sql`

## Items That Still Need Manual App Testing

- Run the Flutter app and verify procurement review/edit before submit on desktop/mobile.
- Verify retail mixed payment sale offline, reconnect, and sync.
- Verify Windows default-printer plain text USB print from sales history on an actual Windows machine with a configured printer.
- Verify hospitality dashboard no longer blanks and updates occupancy/revenue after a check-in and checkout.
- Verify pharmacy sale completes from inventory-backed products and stock reduces once.
- Verify petroleum pump upload cash breakdown total and petroleum bank deposit receipt upload/history.
