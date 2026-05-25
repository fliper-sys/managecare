# Work Done in the Past 2 Months

Review window: 2026-03-25 through 2026-05-25

This document covers general work completed in the repository during the last 2 months, including:

- new features
- screen and UI edits
- backend and payment work
- reports and printing updates
- subscription and access-control changes
- fixes and stability improvements

The summary is based on Git history plus the project update notes in `updates.md`, `newupdates2.md`, `worked_updates_from_newupdates2.md`, and related docs.

## High-level summary

Work in this period focused heavily on:

- subscription and payment flow changes, especially Kora integration
- worker permissions and business access control
- screen redesign and dark-mode polish across many modules
- industry-specific dashboard and workflow expansion
- invoice, receipt, and report generation improvements
- inventory, expiry, low-stock, and customer-history improvements
- admin, marketer, and real-estate workflow expansion

## Features and product work completed

### Subscription, trials, and payments

- Added and refined Kora payment integration for subscription flows.
- Added Kora web checkout support with external browser/tab flow for web users.
- Added safer Kora payment-reference generation and backend normalization.
- Improved backend handling for payment initialization and Kora validation errors.
- Added support for recurring subscription metadata during payment initialization.
- Reworked registration/subscription flow to support a 7-day free trial instead of the earlier broken skip path.
- Added trial start and end tracking on both user and business records.
- Added scheduled trial-expiry reminders.
- Expanded subscription reminder/access logic, including grace-period handling after expiry.
- Updated subscription-related screens:
  - `subscription_payment_screen.dart`
  - `subscription_status_screen.dart`
  - `subscription_screen.dart`
  - `business_details_screen.dart`
  - `kora_checkout_screen.dart`

### Worker accounts, roles, and permissions

- Expanded worker permission handling and worker-management flows.
- Updated owner-side worker creation and worker-detail management screens.
- Added or refined permission selector UI and worker permission utilities.
- Improved worker deletion flow and cleanup of worker data across collections.
- Improved session validation during worker deletion.
- Continued work on real-time worker permission and access structure.
- Related screens and files updated:
  - `add_worker_screen.dart`
  - `worker_details_screen.dart`
  - `worker_management_screen.dart`
  - `permission_selector.dart`
  - `workers_provider.dart`
  - `worker_permissions.dart`

### Sales, receipts, invoices, and printing

- Expanded invoice and receipt generation across app flows.
- Improved printed receipts, reopened receipts, and invoice output to preserve unit and pricing context better.
- Added or improved PDF and thermal printing support.
- Improved receipt upload and receipt asset handling.
- Added customer-linked invoice and receipt behavior in parts of the sales flow.
- Updated post-sale action sheets and shared printing flows.
- Continued work across:
  - `sales_screen.dart`
  - `receipt_screen.dart`
  - `receipt_detail_screen.dart`
  - `post_sale_action_sheet.dart`
  - `printing_action_sheet.dart`
  - `receipt_manager.dart`
  - `thermal_printing_service.dart`
  - `pdf_invoice_generator_io.dart`
  - `pdf_invoice_generator_web.dart`
  - `pdf_receipt_generator_io.dart`
  - `pdf_receipt_generator_web.dart`
  - `esc_pos_receipt_generator.dart`

### Inventory, procurement, stock, and expiry tracking

- Added an inventory expiry tracker screen and supporting expiry service.
- Improved low-stock detection and low-stock screens.
- Expanded procurement, product-history, and inventory-report related work.
- Improved inventory/report export support.
- Continued work on inventory editing, stock visibility, and procurement screens.
- Updated work across:
  - `inventory_expiry_tracker_screen.dart`
  - `low_stock_products_screen.dart`
  - `inventory_list_screen.dart`
  - `inventory_report_screen.dart`
  - `procurement_screen.dart`
  - `procurement_history_screen.dart`
  - `product_procurements_screen.dart`
  - `inventory_export_service.dart`
  - `inventory_expiry_service.dart`
  - `low_stock_detection_service.dart`

### Customer, patient, and treatment workflows

- Improved customer list and customer detail flows, including purchase-history loading.
- Added or refined direct sale from customer profile.
- Expanded pharmacy patient and treatment data models and screens.
- Added or refined patient records, treatment records, and prescription-related screens.
- Related work includes:
  - `customer_list_screen.dart`
  - `customer_details_screen.dart`
  - `patient_records_screen.dart`
  - `patient_records_enhanced.dart`
  - `prescription_screen.dart`
  - `prescription_detail_screen.dart`
  - `add_edit_drug_screen.dart`
  - `pharmacy_provider.dart`

### Reports, analytics, exports, and document generation

- Expanded reporting screens and financial-report generation.
- Added or refined report export support and aggregated reporting pages.
- Added or improved PDF builders for reports and receipts.
- Updated analytics and reporting providers.
- Work included:
  - `financial_report_screen.dart`
  - `reports_dashboard_screen.dart`
  - `export_report_screen.dart`
  - `aggregated_reports_screen.dart`
  - `sales_report_screen.dart`
  - `inventory_report_screen.dart`
  - `financial_report_pdf_service.dart`
  - `enhanced_pdf_builder.dart`

### Admin and marketer workflows

- Expanded admin dashboard, payment pages, businesses page, marketers page, and subscription oversight flows.
- Added or improved marketer registration, marketer dashboards, and marketer data models/providers.
- Added admin/marketer analytics and subscription-related review screens.
- Improved some admin business listing and payment data handling.
- Related files include:
  - `app_admin_dashboard_screen.dart`
  - `admin_payments_page.dart`
  - `all_businesses_page.dart`
  - `marketers_page.dart`
  - `business_subscription_overview_page.dart`
  - `marketer_dashboard_screen.dart`
  - `register_business_screen.dart`
  - `register_user_screen.dart`
  - `marketer_provider.dart`
  - `admin_provider.dart`

### Notifications, support, and communication services

- Added or expanded notification infrastructure.
- Added or refined push-notification and background subscription-check logic.
- Added email and notification/email service work.
- Added web email receipt support and notification logging/settings screens.
- Related work includes:
  - `notification_service.dart`
  - `push_notification_service.dart`
  - `push_service.dart`
  - `background_subscription_checker.dart`
  - `email_service.dart`
  - `email_template_service.dart`
  - `notification_and_email_service.dart`
  - `web_email_receipt_service.dart`

## Screen edits and UI work

### Dark mode and visual polish

- A dedicated `dark mode` commit on 2026-05-22 updated many UI screens across admin, auth, dashboard, hotel, barber, restaurant, gas, wholesale, and retail flows.
- This included screen-level theme polish, card styling, layout cleanup, and consistency work.
- Affected screen groups include:
  - admin payments and businesses pages
  - subscription and auth screens
  - owner business overview and worker management tabs
  - barber shop dashboard, appointments, and services
  - hotel billing, bookings, front desk, guest management, housekeeping, hall bookings, pool bookings, room list, and services
  - pharmacy dashboard
  - restaurant stock and kitchen orders
  - retail checkout/product widgets
  - wholesale inventory, reports, transfers, POS, and purchase orders

### Dashboard and home-screen edits

- Updated owner dashboard, worker dashboard, industry dashboards, and app-admin dashboard multiple times in this period.
- Added or adjusted business overview, dashboard cards, summary tiles, and work-page/home-page flows.
- Refined dashboard behavior for:
  - retail
  - hotel
  - gym
  - pharmacy
  - gas
  - auto
  - salon
  - drink/bar
  - wholesale
  - real estate

### Navigation and routing

- Updated application routing and screen wiring in several releases.
- Continued expansion of route coverage for subscriptions, admin flows, reports, hospitality, and worker flows.
- Updated `app_router.dart`, route constants, app bootstrapping, and provider wiring.

## Industry-specific work completed

### Hotel and hospitality

- Expanded hotel dashboard and operational screens.
- Added or refined:
  - bookings
  - billing
  - check-in/check-out
  - front desk
  - guest management
  - room creation and room list
  - housekeeping
  - pool bookings
  - hall bookings
  - hotel services
- Added hospitality-related service and provider updates.

### Restaurant and kitchen

- Expanded restaurant provider and order workflows.
- Updated:
  - create order
  - pending-order checkout
  - manage menu
  - manage tables
  - manage staff
  - stock screens
  - kitchen orders
- Added work around restaurant cart sheets and owner dashboard flows.

### Pharmacy

- Expanded pharmacy dashboard and POS-related work.
- Added patient, treatment, and prescription models and related repository/provider support.
- Added or refined:
  - add/edit drug
  - add prescription
  - prescription details
  - patient record screens
  - pharmacy cart sheet

### Real estate and apartments

- Expanded real-estate dashboard and lease/rent workflows.
- Added or refined:
  - rent collection
  - lease management
  - tenant management
  - lease form
  - apartment/unit and booking support
- Improved provider wiring for apartment and real-estate business context.

### Drink/bar

- Expanded drink dashboard, POS, tabs, and order screens.
- Added or refined beverage cards, tab cards, and bar-related sales flows.

### Gas

- Expanded gas dashboard, pump, and stock screens.

### Gym

- Expanded gym dashboard and management flows.
- Added or refined:
  - attendance tracking
  - equipment management
  - memberships
  - member details
  - plan management
  - trainer management
  - member progress

### Auto, salon, barber, and wholesale

- Auto:
  - updated auto dashboard and vehicle creation
- Salon:
  - updated dashboard, appointments, services, and staff-management/provider work
- Barber shop:
  - updated dashboard, appointments, and services
- Wholesale:
  - updated warehouse dashboard, inventory, stock transfers, purchase orders, POS, and reports

## Fixes and stability improvements

### Confirmed fixes from commit history

- `2139cc6` - recurrent payment fix
  - fixed recurring-payment metadata handling for Kora initialization

- `bd6529a` and `51a6ac5` - Kora fixes
  - fixed payment-reference handling
  - fixed web checkout flow
  - improved Kora API error handling

- `3110f75` - barber dashboard fix
  - fixed conflicting metric-card border styling

- `0a25aec` - skip/subscription fix
  - fixed broken registration skip path
  - replaced it with a trial-based access flow
  - fixed stuck registration state for some users

- `d0aa6b8` - broad fixes release
  - fixed subscription day calculations and access-window checks
  - fixed low-stock threshold behavior
  - fixed or improved expiry tracking support
  - fixed customer purchase-history access
  - improved receipt/invoice unit and pricing context

- `49829db` - worker fix
  - fixed worker deletion validation and cleanup flow
  - improved error handling around worker deletion/session problems

- `c118446` - provider/admin fix
  - fixed stale provider state after logout/business switching
  - fixed apartment provider reset/business reload behavior
  - fixed an admin payments page data-casting issue

### Fixes confirmed by project notes in this same period

- subscription days-left display was corrected
- low-stock threshold selection was fixed
- product procurement/sales history visibility was restored
- expiry tracking and expiry notifications were worked on and partially confirmed in notes
- worker feature/permission selection was marked as fixed in repo notes
- admin home-page button/filter behavior was marked as fixed in repo notes
- admin business details view was marked as fixed in repo notes
- duplicate business listing issue was marked as fixed in repo notes

## Documentation and planning artifacts added

- `updates.md`
- `newupdates2.md`
- `worked_updates_from_newupdates2.md`
- `git update.md`
- `docs/UPDATES_STATUS_REPORT_2026-04-01.md`
- `docs/CHECKLIST_FIX_IMPLEMENTATION_PLAN.md`
- `docs/subscription new plan.md`
- `checklist.md`

## Notes

- Some commits in this period have generic messages such as `new`, `good`, `version 2`, or `updates1`. For those, this report uses changed files and surrounding project notes to summarize the work.
- This report includes completed work and visible implementation changes, but it does not mark every requested backlog item as fully finished.
- Pending items explicitly described in update notes as `working on it`, `not sure`, or `will be implemented` were not re-labeled here as completed fixes.
