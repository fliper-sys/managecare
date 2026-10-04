# Administrative Services: Frontend and Backend Specification

## Purpose

Administrative Services is a separate Manage Care business type for firms that
manage client records, regulatory work, documents, recurring obligations,
staff assignments, revenue, expenses, and invoices.

It must use `business_id` as the tenancy boundary. An owner/admin sees every
record for their business. A worker sees only records explicitly assigned to
them, except where a permission grants wider access.

## Current Baseline

The following foundation is already present in the Flutter codebase:

- Business type: `administrative`
- Dashboard route: `/administrative`
- Subscription family: `administrative`
- Plans: Tier 1, Tier 2, Tier 3, Premium, Enterprise
- Initial Postgres migration: `server/managecare-backend/migration_042_administrative.sql`

The dashboard is currently a shell. The following sections define the full
remaining implementation work.

## Subscription Contract

All limits are enforced server-side before a record is created. The client may
show the remaining quota, but it is never the source of truth.

| Tier | Storage | Staff | Clients | Branches | 3 months | 6 months | 12 months |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Tier 1 | 4 GB | 4 | 30 | 0 | NGN 28,510 | NGN 53,087 | NGN 98,310 |
| Tier 2 | 10 GB | 10 | 75 | 2 | NGN 71,275 | NGN 132,713 | NGN 245,776 |
| Tier 3 | 25 GB | 20 | 200 | 5 | NGN 142,559 | NGN 265,438 | NGN 419,552 |
| Premium | 50 GB | 50 | 400 | 10 | NGN 213,825 | NGN 398,157 | NGN 737,328 |
| Enterprise | Unlimited | Unlimited | Unlimited | Unlimited | NGN 285,177 | NGN 530,878 | NGN 983,203 |

Plan identifiers use `administrative_<tier>_<period>`, for example
`administrative_tier2_6m` and `administrative_enterprise_12m`.

## Frontend Work

### Navigation and Access

- Add an Administrative dashboard entry to business selection and switching.
- Use a desktop side navigation and mobile bottom navigation/drawer containing
  Overview, Clients, Expenses, Revenue, Documents, Staffing, Obligations,
  Invoicing, Tasks, Calendar, and Activity.
- Resolve the active business from `BusinessProvider`; every repository call
  receives its `businessId`.
- Apply worker visibility and permissions before rendering sensitive sections.
  Revenue documents and portal credentials require the additional client
  access passcode where configured.

### Overview Dashboard

Display the current business totals for revenue, expenses, clients, and staff.
Also display:

- obligations due within 24 hours, 3 days, and 7 days;
- submitted documents awaiting review;
- assigned tasks due soon or overdue;
- current subscription usage for storage, staff, clients, and branches.

Use a single dashboard endpoint rather than loading each card independently.

### Clients

#### Client list

- Search by client name, company, location, worker, and status.
- Filter by location, assigned worker, date created, and client activity.
- Create, edit, archive, and restore clients.
- Show the assigned worker count, document count, open tasks, and next
  obligation on each row.

#### Client detail

Use tabs for Overview, Documents, Obligations, Tasks, Expenses, Revenue, and
Activity. The Overview tab contains name, company, location, contact address,
assigned workers, and portal credentials.

Portal credentials must never be rendered in plain text by default. Each value
is masked, requires the client passcode where applicable, and emits an audit
event when revealed or copied.

### Documents and Review

- Each client can have multiple named folders, such as VAT.
- Upload metadata includes filename, MIME type, byte size, storage key, folder,
  client, uploader, and version lineage.
- Filter documents by client, folder, name, size, type, upload date, status,
  and assigned worker.
- Assign a document to a worker with a remark and deadline.
- Workers submit a replacement/new version for review. The task state moves to
  `submitted` and appears in the admin review queue.
- An admin approves or rejects the submission. On approval, require one of:
  `replace_original` or `store_as_new_version`.
- Approval stores the final document in the original folder and creates a
  complete audit trail.

### Obligations

An obligation includes client, title, assigned worker, recurrence type,
interval in days, next due date, and active state.

#### Fixed recurrence

For `fixed`, the next due date remains anchored to its scheduled calendar day.
Completing early does not move the next deadline. For a monthly 27th schedule,
the next deadline remains the next 27th.

#### Trailing recurrence

For `trailing`, the next due date equals completion time plus `interval_days`.
Completing two days early starts the new interval on the actual completion day.

The UI must make due-in-7-days obligations visually urgent and provide quick
filters for 24 hours, 3 days, and 7 days.

### Tasks and Calendar

- Present worker-assigned tasks and personal tasks in one queue.
- Support assignee, due date, client, related document, remarks, priority,
  status, and completion notes.
- The calendar supports date-based actions, obligation deadlines, and task
  deadlines. Clicking a day opens the day's tasks and supports creation.
- Admins can review submitted work. Workers can only complete or submit work
  assigned to them unless a permission grants broader access.

### Staffing, Financials, and Invoicing

- Staffing lists workers, assigned clients, open tasks, and workload.
- Expenses and revenue are client-aware and support client filters.
- Invoices can be created for a client, have draft/sent/paid/void states, and
  contribute to revenue only when paid.

### Frontend Components and Data Layer

Create a dedicated feature folder:

```text
lib/presentation/industry_specific/administrative/
  screens/
  widgets/
  models/
  providers/
  services/
```

Use an `AdministrativeRepository` backed by `ManagecareApiClient`. Keep view
state in `AdministrativeProvider`; do not place API calls in widgets. Define
typed models for Client, ClientCredential, DocumentFolder, AdministrativeDocument,
DocumentAssignment, Obligation, AdministrativeTask, Invoice, and ActivityEvent.

## Backend Work

### Database

Apply `migration_042_administrative.sql`, then add the following as needed:

- encrypted credential fields or a dedicated secrets service; never store
  plaintext passwords or passcodes;
- `administrative_invoices` and `administrative_invoice_items`;
- `administrative_expenses` and `administrative_revenue_entries` if the shared
  financial tables cannot safely hold client-level records;
- `administrative_document_versions` for immutable version history;
- `administrative_task_comments` for worker/admin review notes;
- branch records when branch management is enabled.

All mutable tables need `created_at` and `updated_at`. All list queries require
an index beginning with `business_id`.

### API Routes

Add `server/managecare-backend/routes/administrative.js` and mount it at
`/api/administrative` behind `authMiddleware`.

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/:businessId/dashboard` | Dashboard totals, review queue, alerts, usage |
| GET/POST | `/:businessId/clients` | List/create clients with search and filters |
| GET/PATCH/DELETE | `/:businessId/clients/:clientId` | Read/update/archive client |
| PUT/DELETE | `/:businessId/clients/:clientId/workers/:workerId` | Assign/unassign worker |
| GET/POST | `/:businessId/clients/:clientId/folders` | List/create document folders |
| GET/POST | `/:businessId/clients/:clientId/documents` | List/upload document metadata |
| POST | `/:businessId/documents/:documentId/assignments` | Assign document work |
| POST | `/:businessId/tasks/:taskId/submit` | Submit completed document work |
| POST | `/:businessId/tasks/:taskId/review` | Approve/reject submitted work |
| GET/POST | `/:businessId/obligations` | List/create obligations |
| POST | `/:businessId/obligations/:id/complete` | Complete and calculate next due date |
| GET/POST | `/:businessId/tasks` | Task list/create/update |
| GET | `/:businessId/calendar` | Tasks and obligations within a date range |
| GET | `/:businessId/activity` | Auditable client activity with filters |
| GET/POST | `/:businessId/invoices` | List/create invoices |
| POST | `/:businessId/invoices/:id/send` | Mark invoice sent |
| POST | `/:businessId/invoices/:id/payments` | Record payment and revenue |

Use cursor or page/limit pagination for documents, activity, clients, and
tasks. Validate UUIDs, pagination inputs, enum values, uploads, and ownership
on every route.

### Authorization

Every request must verify all of the following before querying data:

1. The authenticated user belongs to `businessId`.
2. The business is an `administrative` business or has this feature enabled.
3. The subscription is active and its relevant limit has not been exceeded.
4. A worker is assigned to the client, related task, or has explicit access.
5. Sensitive credential and revenue actions satisfy the configured passcode
   policy.

Use owner/admin-only authorization for client archival, worker assignment,
credential editing, document review, invoice voiding, and passcode management.

### Audit Logging

Create an activity event for client search/view, credential reveal/copy,
document upload/view/download/assignment/review, task changes, client changes,
obligation changes, invoice actions, and passcode failures.

Each event records business, client where applicable, actor, action, entity,
timestamp, IP/request metadata when available, and non-sensitive context. Do
not log passwords, passcodes, access tokens, or document content.

### Subscription Enforcement

The backend derives the active administrative plan from the business
subscription. Before creating a client, worker, branch, or upload it checks:

- client count against `clients`;
- active staff count against `workers`;
- branch count against `branches`;
- total stored bytes against `storage_gb * 1024^3`.

Enterprise limits are `NULL` and therefore unlimited. Return `409` with a
machine-readable `limit_type`, `limit`, and `current_usage` when a limit is
reached.

## State Rules

### Document assignment

`stored -> assigned -> in_progress -> submitted -> approved`

From `submitted`, an admin may move the work to `approved` or `rejected`.
Rejected work returns to `in_progress` with a review remark. Approved work
requires a storage action: replace the original or create a new version.

### Obligation completion

- `fixed`: calculate the next configured calendar occurrence after the current
  due occurrence. Completion timestamp does not change the anchor.
- `trailing`: `next_due_at = completed_at + interval_days`.
- An obligation is urgent when `next_due_at <= now + 7 days` and incomplete.
- A completed obligation remains in history; it is not overwritten.

## Delivery Sequence

1. Apply the migration; add typed models, repository, provider, authorization
   middleware, dashboard endpoint, and client CRUD.
2. Add client-worker visibility, credentials, audit logging, folders, uploads,
   and document assignment.
3. Add worker submission/admin review, immutable document versions, and
   obligation recurrence processing.
4. Add tasks, calendar, client financial entries, invoicing, and subscription
   usage enforcement.
5. Add notification jobs, full search, export, accessibility checks, and
   end-to-end tests.

## Acceptance Tests

- A Tier 1 business cannot create a 31st client or 5th staff member.
- A worker only sees assigned clients and related documents/tasks.
- A fixed monthly obligation completed early still retains its scheduled next
  calendar date.
- A trailing obligation completed early sets the next date from completion.
- A document cannot become approved without an admin review and storage action.
- Every client/document credential access attempt generates an audit event.
- Unauthorized users cannot enumerate another business's clients, documents,
  tasks, financial records, or activity log.
- Subscription limits are enforced by the API even when the Flutter client is
  modified or bypassed.
