# Checklist Fix Implementation Plan

## Overview
This document converts the checklist into an actionable implementation plan for the Manage Care app. Use it as a step-by-step guide to fix product, retail, admin, real estate, hospitality, marketer, gas, pharmacy, and subscription issues.

## How to Use This Plan
1. Start with the highest-risk business logic and subscription flows.
2. Fix data correctness, then UI/UX behavior.
3. Validate each change with a focused test case.
4. Mark tasks complete in the order shown.

---

## Priority Implementation Phases
1. Subscription/payment and access control
2. Retail inventory, product units, and expiry handling
3. Admin dashboard and business lifecycle
4. Real estate and hospitality workflow fixes
5. Invoice, bar, marketing, gas, and pharmacy enhancements
6. General UI/UX polish and sync reliability

---

## 1. Subscription & Payment Flow Fixes
### Goals
- Prevent unverified users from accessing the app.
- Ensure subscription alerts and tier enforcement are accurate.
- Fix Flutter payment and subscription status display.

### Tasks
- Audit subscription verification flow during signup.
  - Verify user access only after valid payment confirmation.
  - Reject fake payment image uploads that are not verified.
  - Ensure `Pay with Flutter` flow is wired and testable.
- Implement subscription expiry reminders.
  - Notify users at 30, 15, 7, and 3 days before expiry.
  - Show reminders on sub-admin home and optionally email.
- Enforce tier limits dynamically.
  - Tier 1: max 300 products, 0 branches, 3 workers.
  - Tier 2: max 700 products, 1 branch, 5 workers.
  - Tier 3: max 1000 products, 2 extra branches, 10 workers.
  - Premium: >1000 products, monthly or quarterly payment.
- Fix business registration flow.
  - If a user closes during business selection, allow them to resume.
  - Ensure skip/back buttons work on subscription page.

### Acceptance Criteria
- Users cannot enter the app until payment is verified.
- Reminder notifications appear at configured intervals.
- Tier restrictions block over-limit actions and request upgrades.
- Registration flow recovers gracefully after app backgrounding.

---

## 2. Retail Inventory & Product Management
### Goals
- Correct inventory downloads and product history tracking.
- Track product expiry by batch and procurement date.
- Support wholesale/retail units with correct cart behavior.

### Tasks
- Fix inventory download functionality for web and mobile.
  - Ensure download buttons export current inventory and reports.
- Fix product detail history.
  - Show procurement history and sales history for selected products.
- Implement batch-level expiry tracking.
  - Store expiry date and purchase batch data separately.
  - Allow the owner to allocate how many units expire on each date.
  - Generate expiring-soon notifications correctly.
- Fix low stock threshold selection.
  - Make threshold settings persist and trigger alerts properly.
- Enhance procurement unit selection.
  - Support `pcs`, `packs`, `carton`, `kg`, and more.
  - Store procurement unit alongside quantity and price.
- Add stock-level purchase price and expiry metadata.
  - New stock entries should not overwrite old batch pricing or expiry.
- Reflect procurement changes everywhere.
  - Activity log, product inventory, and procurement history must all update.
- Fix wholesale vs retail product selection.
  - Allow a product to exist in both wholesale and retail forms.
  - Ensure sales use the selected unit type correctly.
  - Prevent wholesale unit from overriding retail mode after cart switch.

### Acceptance Criteria
- Web inventory downloads work reliably.
- Product history displays batch-specific procurement and sales details.
- Expiry notifications consider separate batches.
- Low stock thresholds are selectable and enforced.
- Wholesale/retail selection works in both sale and quick sale flows.

---

## 3. Admin Dashboard & Business Lifecycle
### Goals
- Make admin controls reliable and transparent.
- Fix business status reporting, payment approval, and deactivation behavior.

### Tasks
- Fix admin homepage buttons and status cards.
  - Active users should only show businesses with active subscriptions.
  - Pending should show businesses awaiting payment approval.
- Fix payment approval workflow.
  - Display pending payments correctly.
  - Only approved payments should count toward revenue.
- Add detailed business profile view.
  - Registration date, agent, payment history, product count, branches, workers, contacts.
- Remove duplicate business entries and fix admin list rendering.
- Fix deactivated business access.
  - Owners can log in but cannot act or view data.
  - Show only customer care contact or WhatsApp support info.
- Fix super-admin deletion behavior.
  - Deleted businesses should lose login access or be directed to support.

### Acceptance Criteria
- Admin metrics are correct and actionable.
- Approved payments are the only revenue source.
- Deactivated businesses can access support contact only.
- Deleted businesses cannot use the app.

---

## 4. Bar & Invoice Workflow
### Goals
- Bring bar features up to retail parity and add table/tab order handling.
- Make invoice generation and invoice-to-sale conversion usable.

### Tasks
- Add bar-specific sale and invoice workflow.
  - Allow sale registration to pre-saved customer accounts.
  - Support table-based orders and active tab tracking.
- Allow invoice conversion into a registered sale.
  - Preserve invoice item details and avoid duplicate re-entry.
- Ensure invoices are stored in invoice records.
- Fix invoice/customer selection.
  - Allow selection from existing saved customers.
  - Link invoice customer info to saved customer data.
- Allow preview, print, and send invoice before sale completion.
  - Support workers printing invoices independently of final sale.
- Fix invoice total calculations.
  - Confirm item totals sum correctly on generated invoices.
- Add business logo and contact info to invoice export/share.
  - Use uploaded business profile image as invoice background/logo.
  - Include business location and contact details.

### Acceptance Criteria
- Bar can handle pre-saved customer sales and table orders.
- Invoice-to-sale conversion works without re-entry.
- Invoices are previewable and printable before registering the sale.
- Invoice totals are correct and branding is applied.

---

## 5. Real Estate Module Fixes
### Goals
- Convert real estate inventory into property management.
- Add proper rent payment entry, reminders, and document upload.

### Tasks
- Rename or create a `Properties` module instead of retail inventory.
  - Remove unrelated retail items from the real estate home page.
  - Use a work-focused home page rather than retail dashboard.
- Add property registration fields.
  - Title, description, address, type, price, status, agent, images.
- Improve rent payment entry.
  - Capture payment date/time, due date, payment duration, amount, property link.
  - Record tenant contact email, phone, WhatsApp.
- Add reminders by lease type.
  - Short let: 24-hour reminder before expiry.
  - Rented house: monthly reminder before rent due.
  - Agent reminders for expiring tenancies and client payments.
- Add document upload section for receipts and tenancy agreements.
  - Permit storing receipt images and tenancy documents.

### Acceptance Criteria
- Real estate uses a property-centered workflow.
- Rent payment records capture payment details and tenant contact info.
- Short let and long-term reminders fire appropriately.
- Document upload works for receipts and tenancy agreements.

---

## 6. Hospitality Package & Multi-Service Flow
### Goals
- Support hospitality businesses with multi-service selection.
- Add room, bar, restaurant, and service order handling.

### Tasks
- Add hospitality onboarding options.
  - Allow selection of lodge, restaurant, bar, kitchen, lounge, or combination.
- Support room registration and pricing.
  - Add half-day pricing option and checkout reminders.
- Link room service orders to room bills.
  - Keep services attached to the room until checkout.
- Add table/order assignment for kitchen and bar.
  - Workers can add pending orders by table number.
  - Only inventory-available items may be ordered.
- Allow extra order add-ons and stay extensions.
- Keep table orders active until paid.
- Add a separate `stock` section for restaurant food items.
  - Track food stock separately from general inventory.
- Add leftover/spoilage tracking for restaurant stock.

### Acceptance Criteria
- Hospitality businesses can select and manage the services they offer.
- Room services and orders attach properly to rooms/tables.
- Extra orders and stay extensions can be recorded.
- Restaurant stock and spoilage are tracked distinctly.

---

## 7. Marketing Dashboard & Agent/Marketer Workflow
### Goals
- Make marketer registration, commission tracking, and reporting functional.
- Provide real-time client assignment and leaderboard status.

### Tasks
- Enable admin to create marketer accounts remotely.
- Attach clients to marketers by email referral.
- Allow admin to configure marketer commission % and bonus amounts.
- Show marketer active/inactive client counts.
  - Active: registered and subscribed clients.
  - Inactive: registered but not subscribed.
- Fix marketer leaderboard and client counters.
- Add marketer progress/target tracking.
  - Show commission target, bonus thresholds, and progress to goals.
- Display subscription expiry status for marketer clients.

### Acceptance Criteria
- Marketer dashboard shows accurate metrics and referral attribution.
- Admin can configure commission and bonus values.
- Leaderboard and target progress are functional.
- Expiring client subscriptions are visible to marketers.

---

## 8. Gas Station & Fuel Sales
### Goals
- Separate gas stock from normal inventory.
- Ensure gas pump sales count toward total sales.

### Tasks
- Add a dedicated gas stock area outside standard inventory/procurement.
- Ensure pump sales update the dashboard total sales.
- Keep cylinder and other non-gas items in normal inventory.

### Acceptance Criteria
- Gas inventory is separate and manageable.
- Pump sales reflect correctly in dashboard totals.

---

## 9. Pharmacy & Prescription Handling
### Goals
- Add optional prescription metadata for pharmacy drugs.
- Support prescription creation and printing for customers.

### Tasks
- Add prescription fields to drug inventory registration.
  - Optional age range, drug-specific prescription templates.
- Allow workers to select a prescription during sale.
- Add a direct prescription writer section.
  - Create and print prescriptions separately from sales.
- Ensure worker permissions allow pharmacy prescription access only when authorized.
- Allow real-time owner permission changes for pharmacy workers.

### Acceptance Criteria
- Pharmacy drugs can store age-based prescription rules.
- Workers can write and print prescriptions directly.
- Permissions update in real time.

---

## 10. Cross-Module & UI/UX Polishing
### Goals
- Fix sync lag, account switching, dark mode, and inconsistent page behavior.

### Tasks
- Fix account switching sync lag between owner and worker views.
- Ensure worker accounts cannot log in from owner-only screens.
- Standardize sale feature parity between new sale and quick sale pages.
- Improve dark mode styling across the app.
- Separate branch sales history and reports by store when applicable.
- Fix search edge cases for numeric product names.
- Ensure buttons work on home pages for products, customers, and staff.

### Acceptance Criteria
- Switching accounts updates product state quickly.
- Owner-only and worker-only screens enforce access correctly.
- Sale pages behave consistently.
- Dark mode and search behavior are improved.

---

## Validation Checklist
For every completed fix, validate the following:
- [ ] Business rule correctness matches the checklist item.
- [ ] Related UI flows are functional and intuitive.
- [ ] Data is stored correctly in Firestore or local model state.
- [ ] Notifications and reminders trigger as expected.
- [ ] Edge cases are covered for tier limits, expiry batches, and permission changes.

## Recommended Workflow
1. Create one issue per major section.
2. Implement one section at a time.
3. Review and test with real sample data.
4. Use the checklist above to confirm completion.

---

## Notes
- Real estate changes should prioritize moving the module away from a retail-style dashboard.
- Admin and subscription fixes are high-impact because they affect access control and revenue.
- Marketing and hospitality are complex and should be implemented after core product and admin flows are stable.
- Keep documentation updated as you complete each section.
