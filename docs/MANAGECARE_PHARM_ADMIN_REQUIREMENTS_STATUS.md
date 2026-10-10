# ManageCare Pharmacy and Administrative Requirements Status

**Status date:** October 9, 2026  
**Scope:** Pharmacy requirements and Administrative Section / Subscription Structure supplied in the ManageCare Pharm Update.

## Status Legend

- `[x]` Implemented in the current codebase.
- `[-]` Partly implemented, or implementation exists but full end-to-end behavior is not verified.
- `[ ]` Not found as implemented in the reviewed code.

These marks describe code and test evidence, not a production acceptance sign-off. Detailed administrative notes are also maintained in [ADMINISTRATIVE_SERVICES_STATUS.md](ADMINISTRATIVE_SERVICES_STATUS.md).

## Pharmacy Requirements

### 1. Drug Inventory

| Requirement | Status | Evidence / notes |
|---|:---:|---|
| 1.1 Editing an existing drug updates that record instead of creating a duplicate | [x] | Edit flow supplies the existing drug ID; repository sync uses create-or-update behavior. |
| 1.2 Remove duplicate Adjust Stock action when it opens the same edit flow | [x] | Drug detail actions retain Edit without the duplicate Adjust Stock action. |
| 1.3 Search by drug name or manufacturer | [x] | Provider search covers both fields; regression test added. |
| 1.4 Show expiry countdown in inventory and exact expiry date in details | [x] | Inventory list displays days remaining; detail view retains the exact date. |
| 1.5 Keep added/edited inventory after logout and subsequent login | [-] | Inventory uses the business-scoped backend repository and local cache. Remote persistence is implemented, but a complete logout/login acceptance test is not recorded here. |

### 2. Sales and Cart

| Requirement | Status | Evidence / notes |
|---|:---:|---|
| 2.1 Use Add Items → View Cart → Complete Sale; cart is the final review step | [x] | Active `PharmacyPosScreen` exposes View Cart; Complete Sale is inside the cart. |
| Remove a separate top-right Cart action and replace Confirm Sale with View Cart | [x] | Active POS screen uses a View Cart action; sale completion is in the cart review. |
| 2.2 Select/create patient, use saved prescription/dosage, and keep optional details optional | [x] | Cart supports patient selection or walk-in, saved drug prescriptions, and an optional dosage note. |

### 3-5. Printing, Entry Points, and Patient Category

| Requirement | Status | Evidence / notes |
|---|:---:|---|
| 3. Print prescription details for the patient | [x] | Prescription create/detail screens call `PrescriptionPrintService`; physical printer execution was not part of the focused tests. |
| 4.1 Consolidate POS/New Sale into one pharmacy sales entry point | [x] | The pharmacy dashboard presents New Sale and routes it to the pharmacy POS. |
| 4.2 Consolidate Add Drug/Inventory entry points | [x] | Pharmacy dashboard has one Inventory entry point; adding drugs is handled from inventory. |
| 5. Use Patients as the pharmacy people category instead of a separate Customers category | [-] | Patient Records is the pharmacy record area and the cart selects patients, but walk-in and legacy UI labels still use “Customer” wording. |

### 6-7. Patient Records and History

| Requirement | Status | Evidence / notes |
|---|:---:|---|
| 6.1 Persist newly created patients after navigation and logout/login | [-] | Patient creation writes through the pharmacy repository and retains local-only patients during empty remote refreshes. Full logout/login persistence still needs acceptance testing. |
| 6.2 Make new patients immediately selectable for sales and treatments | [x] | Patient creation updates provider state; POS and patient treatment flows read that provider list/context. |
| 7. Use a patient profile as the central record for demographics and history | [-] | Profile displays contact/demographic data, prescriptions, treatments, administration log, treatment history, and linked sales. Complete linkage of every requested historical drug/transaction record has not been verified. |

### 8-10. Treatments, Inventory, and Persistence

| Requirement | Status | Evidence / notes |
|---|:---:|---|
| 8.1 Present Treatment as the treatment workflow entry point | [x] | Treatment route and dashboard entry are wired. Prescription records/screens remain available for prescription-specific workflows. |
| 8.2 Create a treatment for a patient with drug/dosage, frequency, duration, inventory, consultation fee, and checkout | [-] | Patient-linked treatment creation, inventory selection, fee calculation, sale creation, and treatment save are implemented. A complete free-form clinical-notes workflow is not confirmed. |
| 8.3 Generate sessions from duration × frequency and track Pending/Completed/Missed | [x] | Treatment model generates the schedule and provider accepts the three statuses; session completion drives treatment lifecycle. |
| 9. Link selected inventory to treatment, deduct stock, include consultation fee, and checkout | [x] | Treatment checkout creates sale line items for inventory and consultation fee; sale API handles stock deduction and treatment is saved. |
| 10. Persist drugs, patients, treatments, prescriptions, sales, and related history across sessions | [-] | Remote repository operations and local caching exist, including the patient refresh regression fix. Complete cross-record logout/login validation is still outstanding. |

### 11-13. UI Cleanup and Pharmacy Subscription

| Requirement | Status | Evidence / notes |
|---|:---:|---|
| 11. Remove duplicate inventory and sale actions; require cart review; remove duplicate drug action | [x] | Active pharmacy dashboard/POS flow has one inventory entry, one New Sale entry, one View Cart review, and the duplicate stock action was removed. See partial patient/customer label cleanup above. |
| 12. Configure Tier 1-3 subscription prices for 3, 6, and 12 months | [x] | `SubscriptionService` contains the supplied pharmacy prices. |

| Pharmacy tier | 3 months | 6 months | 12 months |
|---|---:|---:|---:|
| Tier 1 | NGN 30,885 | NGN 55,832 | NGN 99,978 |
| Tier 2 | NGN 41,665 | NGN 69,914 | NGN 113,685 |
| Tier 3 | NGN 49,279 | NGN 84,045 | NGN 127,270 |

### 13. Summary Requirements Checklist

| # | Required change | Status |
|---:|---|:---:|
| 1 | Edit existing drugs without creating duplicates | [x] |
| 2 | Remove duplicate Adjust Stock action | [x] |
| 3 | Search by drug name and manufacturer | [x] |
| 4 | Expiry countdown in list and exact date in details | [x] |
| 5 | Preserve inventory after logout/login | [-] |
| 6 | Require cart review before completing a sale | [x] |
| 7 | Use View Cart as the review action | [x] |
| 8 | Allow patient and saved prescription/dosage selection in cart | [x] |
| 9 | Print prescription information | [x] |
| 10 | Consolidate POS and New Sale | [x] |
| 11 | Remove duplicate inventory entry points | [x] |
| 12 | Use Patients instead of a separate Customers category | [-] |
| 13 | Persist patients and make them selectable | [-] |
| 14 | Provide patient demographics and linked history | [-] |
| 15 | Present the treatment workflow as Treatment | [x] |
| 16 | Create treatments and track attendance | [x] |
| 17 | Generate sessions from duration and frequency | [x] |
| 18 | Include inventory and consultation fees in treatment | [x] |
| 19 | Send treatment charges through checkout | [x] |
| 20 | Preserve complete patient treatment/transaction history | [-] |
| 21 | Apply the supplied pharmacy subscription prices | [x] |

## Administrative Section

| Requirement area | Status | Current implementation / remaining work |
|---|:---:|---|
| Administrative business type, dashboard route, authenticated API, and dedicated schema | [x] | Business type/router, authenticated `/api/administrative` routes, and administrative migrations are present. |
| Subscription tiers, price configuration, and listed plan limits | [x] | Tier 1, Tier 2, Tier 3, Premium, and Enterprise durations/prices/limits are configured. Actual server quota enforcement is tracked separately below. |
| Home tabs for Clients, Expenses, Revenue, Documents, Staffing, Obligations, and Invoicing | [-] | Clients, Documents, Staffing, Obligations, Finance, and security surfaces exist; not every requested section has a dedicated screen/tab. |
| Overview totals for revenue, expenses, clients, and staff | [-] | Dashboard exists, but some home metrics remain preview values rather than live totals. |
| Client details: company/location/contact, assigned workers, expenses, revenue, tasks, obligations, documents, and activity | [x] | Client profile tabs and client-scoped data are implemented. |
| Worker client assignments and worker visibility | [x] | Managers assign/revoke client access; backend restricts worker queries to assigned clients. |
| Client/document search and requested advanced filters | [-] | Basic client/document search, pagination, and folder filters exist; full location/worker/date/size/type/status filter set is not exposed. |
| Client folders and document upload/metadata | [x] | Multiple client folders, upload metadata, search, and folder filtering are present. |
| Assign documents to workers with remarks/deadlines | [x] | Assignment UI/API supports worker, remarks, priority, and deadline with access checks. |
| Worker submission, admin review, approval, and replace/new-version choice | [-] | Review/status workflows and version records exist; worker-submitted replacement upload and full version handoff remain incomplete. |
| Fixed and trailing obligations, countdowns, urgent coloring, and due filters | [x] | Both recurrence calculations and due-soon filters/urgent states are implemented. |
| Portal credentials and revenue passcodes with masked display and access audit | [-] | Some role redaction and backend exclusion exist; encryption, passcode verification, reveal/copy auditing, and credential editing need completion. |
| General activity/audit history for client and document actions | [-] | Backend records many business events and UI supports search/action filters; coverage/export and some sensitive-access events remain incomplete. |
| Task management and calendar for assigned work/deadlines | [x] | Task assignment/status and date-based calendar with task/obligation deadlines are present. |
| Expenses, revenue, and invoicing | [x] | Client-aware financial entries and invoice lifecycle/print/share/payment flows are present. |
| Business-scoped authorization and active-subscription checks | [x] | Membership, business type, subscription, and role checks are implemented on administrative routes. |
| Enforce storage, client, staff, and branch quotas server-side | [-] | Client and storage quotas are enforced; staff and branch limits still need enforcement at their creation points. |
| Automated tests for administrative API authorization, quotas, documents, invoices, and calendar | [-] | Provider tests exist; route integration and several workflow acceptance tests remain. |

## Administrative Subscription Structure

Configured tier limits and prices match the supplied specification. Amounts are NGN per billing term.

| Tier | Storage | Staff | Clients | Branches | 3 months | 6 months | 12 months |
|---|---:|---:|---:|---:|---:|---:|---:|
| Tier 1 | 4 GB | 4 | 30 | 0 | 28,510 | 53,087 | 98,310 |
| Tier 2 | 10 GB | 10 | 75 | 2 | 71,275 | 132,713 | 245,776 |
| Tier 3 | 25 GB | 20 | 200 | 5 | 142,559 | 265,438 | 419,552 |
| Premium | 50 GB | 50 | 400 | 10 | 213,825 | 398,157 | 737,328 |
| Enterprise | Unlimited | Unlimited | Unlimited | Unlimited | 285,177 | 530,878 | 983,203 |

## Verification Evidence

- Pharmacy provider and subscription regression tests passed: `flutter test test/pharmacy_provider_search_test.dart test/pharmacy_subscription_plans_test.dart` (`+5` tests).
- Prescription print calls are wired from prescription create/detail screens to `PrescriptionPrintService`; physical printer behavior was not specifically tested in this pass.
- Administrative route syntax check passed with `node --check server/managecare-backend/routes/administrative.js`.
- Administrative provider/UI tests exist, but a complete backend route integration and authorization test suite is still needed.
- For detailed admin evidence, see [ADMINISTRATIVE_SERVICES_STATUS.md](ADMINISTRATIVE_SERVICES_STATUS.md). For recent dated work, see [ADMIN_PHARMACY_WEEKLY_WORK_LOG_2026-10-03_to_2026-10-09.md](ADMIN_PHARMACY_WEEKLY_WORK_LOG_2026-10-03_to_2026-10-09.md).

## Highest-Priority Remaining Work

1. Verify pharmacy drugs, patients, prescriptions, treatments, and sales through real logout/login and remote refresh scenarios.
2. Complete and test end-to-end patient history/transaction linkage and finish legacy Customers wording cleanup.
3. Complete administrative credential encryption/passcode auditing, document worker replacement uploads/version review, and the remaining advanced filters.
4. Enforce administrative staff and branch quotas at record-creation endpoints and add focused route integration tests.
5. Validate all checkout and printing flows on target devices/printers.