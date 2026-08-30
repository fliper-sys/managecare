# Retail, Hospitality, Petroleum, Bakery, Super Admin Fix Status

Updated: 2026-08-28

This document tracks the request list and marks what has been completed in code.

## Retail

| # | Request | Status | Notes / Files |
|---|---|---|---|
| 1 | Not all products from inventory show under procurement. | Done | Procurement now reloads from the inventory-backed product repository and does not restore a stale category filter that can hide products. Main file: `lib/presentation/dashboard/owner/screens/procurement_screen.dart`. |
| 2 | Exported procurement file is missing item names near the matching rows. | Done | Procurement CSV and PDF exports now include item names in the summary and put item name first in detailed rows. Main files: `lib/data/repositories/procurement_repository.dart`, `lib/services/report_export_service.dart`. |
| 3 | Worker cart only converts all products to wholesale instead of allowing each product to be retail or wholesale. | Done | Worker sales now uses the shared sales screen, giving workers the same per-item Retail/Wholesale controls used by admin/owner sales. Main file: `lib/presentation/workers/screens/worker_sales_screen.dart`. |

## Hospitality

| # | Request | Status | Notes / Files |
|---|---|---|---|
| 1 | Check in guest, front desk, and check-in-guest are the same home feature; leave only check-in-guest. | Done / Confirmed | Hotel home quick actions expose the consolidated `Check-In / Guests` entry only. `Front Desk` is not shown on the hotel dashboard or owner dashboard hotel nav. Main files checked/updated: `lib/presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart`, `lib/presentation/dashboard/owner/owner_dashboard_screen.dart`. |
| 2 | Bookings and new bookings are the same home feature; remove one. | Done / Confirmed | The hotel dashboards do not show separate Bookings/New Booking tiles. New Booking remains only as an action inside the check-in/booking workflow. Main files checked/updated: `lib/presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart`, `lib/presentation/dashboard/owner/owner_dashboard_screen.dart`. |

## Petroleum

| # | Request | Status | Notes / Files |
|---|---|---|---|
| 1 | Cash breakdown does not show under upload history; show it on the right side below sold volume and expected amount. | Done | Upload history now summarizes stored cash breakdown beside each upload under sold volume and expected amount. Main file: `lib/presentation/industry_specific/gas/screens/pump_upload_history_screen.dart`. |
| 2 | Bank deposit feature has not been created. | Done / Existing Implementation Confirmed | Petroleum bank deposits screen, route, and dashboard entry already exist. Main files checked: `lib/presentation/industry_specific/gas/screens/petroleum_bank_deposit_screen.dart`, `lib/presentation/industry_specific/gas/screens/gas_dashboard_screen.dart`, `lib/core/constants/routes.dart`, `lib/routes/app_router.dart`. |
| 3 | Pump upload can create double or triple sales records for the same transaction. | Done | Pump upload sales now use a stable idempotent sale id, and backend checks block recent duplicate pump uploads/sales with matching time, amount, product, and quantity. Main files: `lib/providers/retail_provider.dart`, `lib/presentation/industry_specific/gas/screens/pump_daily_upload_screen.dart`, `server/managecare-backend/routes/pumps.js`, `server/managecare-backend/routes/sales.js`. |

## Bakery

| # | Request | Status | Notes / Files |
|---|---|---|---|
| 1 | Admins/owners cannot set discount more than 100 because the system says discount cannot be more than 100. | Done | Product distributor discount handling now supports a fixed discount price separately from percentage discount, removing the old "more than 100" block for fixed prices. Main file: `lib/presentation/inventory/screens/inventory_list_screen.dart`. |

## Super Admin

| # | Request | Status | Notes / Files |
|---|---|---|---|
| 1 | Businesses under total businesses show twice, especially after new registration. | Done | Super admin business lists are now de-duplicated by business id, or by owner/email, name, and type when id is unavailable. Main file: `lib/providers/admin_provider.dart`. |
| 2 | Active business tab should only show businesses with active subscription. | Done | Active Businesses now filters for active subscription flags or valid subscription end dates. Main file: `lib/app_admin/pages/business_subscription_overview_page.dart`. |
| 3 | There are duplicate revenue tabs and transaction tab; remove duplicates because transactions are visible through revenue. | Done | Removed the duplicate Revenue Report dashboard card and standalone Transactions card/tab. Revenue remains the single entry. Main files: `lib/app_admin/app_admin_dashboard_screen.dart`, `lib/app_admin/pages/admin_payments_page.dart`. |
| 4 | Workers created through super admin do not have anywhere to log in. | Done | The existing internal-worker login path is now visible as the Marketer / Worker Portal, and newly created workers are told to sign in there with their temporary password. Main files: `lib/presentation/marketer/marketer_login_screen.dart`, `lib/presentation/auth/screens/admin_login_screen.dart`, `lib/app_admin/pages/admin_workers_page.dart`. |

## Subscription Tier Follow-Up

| # | Request | Status | Notes / Files |
|---|---|---|---|
| 1 | Enterprise businesses should be able to add unlimited workers for all business types. | Done | Worker limits now return unlimited for enterprise subscriptions across the local and Supabase subscription services, and the business provider honors enterprise tier before older plan ids. Main files: `lib/core/constants/subscription_tiers.dart`, `lib/services/subscription_service.dart`, `lib/services/subscription_service_supabase.dart`, `lib/providers/business_provider.dart`. |

## Verification Notes

- Targeted `dart format` was attempted but hung in this environment and was stopped.
- Targeted `dart analyze` was attempted but also hung and was stopped.
- Manual app testing is still recommended for procurement export layout, worker sales retail/wholesale cart selection, petroleum upload history display, and super admin worker login.
