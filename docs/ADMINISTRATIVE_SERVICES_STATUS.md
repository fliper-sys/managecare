# Administrative Services Status

Updated: 2026-10-09

This checklist compares the original Manage Care Administrative Section
requirements with the implementation currently present in this workspace.

Legend: `[x] Done in code` | `[-] Partial` | `[ ] Not built`

## Foundation

| Requirement | Status | Current implementation |
|---|---|---|
| Separate Administrative business type and dashboard route | [x] Done in code | `administrative` business type, `/administrative` route, router registration, and dashboard entry are present. |
| Five subscription tiers and stated limits/prices | [x] Done in code | Tier 1, Tier 2, Tier 3, Premium, and Enterprise plans exist in `SubscriptionService`. |
| Dedicated administrative schema | [x] Done in code | Clients, worker access, folders, documents, tasks, obligations, activity logs, invoices, financial entries, calendar events, document versions, and task comments are defined in migrations 042 and 050 through 054. |
| Administrative API mounted behind authentication | [x] Done in code | `/api/administrative/:businessId/...` is registered in `server.js` behind `authMiddleware`. |

## Dashboard And Navigation

| Requirement | Status | Current implementation |
|---|---|---|
| Home summary for revenue, expenses, clients, and staff | [-] Partial | Dashboard UI exists; client lists and the Finance tab load live data, but the home metric cards still use preview values. |
| Tabs for Clients, Expenses, Revenue, Documents, Staffing, Obligations, and Invoicing | [-] Partial | Mobile navigation and More menu expose Clients, Documents, Staffing, Obligations, Finance, and security. Expenses, Revenue, Invoicing, Calendar, and Activity do not yet have dedicated screens. |
| Notification screen and unread state | [x] Done in code | The shared notification inbox is opened from the administrative bell; unread count is published through `NotificationProvider`. |
| Logout | [x] Done in code | Dashboard logout confirms and calls `AuthProvider.logout()`. |

## Clients And Access

| Requirement | Status | Current implementation |
|---|---|---|
| Client list and search | [-] Partial | Backend supports name/company/location search and pagination. Flutter loads API clients and provides local search; advanced filters are not exposed. |
| Create, edit, archive, and restore clients | [x] Done in code | Managers can create clients, edit name/company/location, archive with confirmation, view archived clients, and restore them. All actions use the administrative API and refresh provider state. |
| Client detail with overview, documents, obligations, tasks, expenses, revenue, and activity tabs | [x] Done in code | Client profiles include Overview, Documents, Obligations, Tasks, Expenses, Revenue, and Activity tabs, each loading the available client-scoped records. |
| Worker assignment and worker-only client visibility | [x] Done in code | Managers can open a staff member from Staffing and grant or revoke each active client's access. The existing API scopes worker client queries to these assignments. |
| Portal credentials/passcodes protected and audited | [-] Partial | Profile UI redacts credentials for non-admin roles. Backend stores credentials as JSON and excludes them for workers, but encryption, passcode validation, reveal/copy auditing, and credential editing are not complete. |

## Documents And Work Review

| Requirement | Status | Current implementation |
|---|---|---|
| Multiple folders per client | [x] Done in code | Managers can create folders and filter the live client document list by folder. |
| Document metadata, list/search/filter, and upload | [x] Done in code | The client document screen loads stored metadata, searches by filename, filters folders, selects local files, uploads through the shared upload API, and creates administrative document records. |
| Controlled document download with audit event | [-] Partial | The client UI requests the access-checked download endpoint and opens the returned storage URL, logging `document_downloaded`. Storage URLs are not yet short-lived signed URLs. |
| Assign document to worker with remark and deadline | [x] Done in code | Managers assign a stored document to a live active worker, select priority and deadline, and add a remark. The API verifies the document, client, worker, and client-access assignment. |
| Worker submission and admin approval/rejection | [-] Partial | UI/provider status lifecycle and task comments are connected. Managers can upload and approve document versions as replacement or history-only versions; worker-submitted replacement-file upload is still incomplete. |

## Obligations, Tasks, And Calendar

| Requirement | Status | Current implementation |
|---|---|---|
| Fixed and trailing obligation recurrence | [x] Done in code | Provider and backend calculate fixed calendar and trailing next due dates. |
| Urgent obligations and completion filters | [x] Done in code | The obligations dashboard has All, 24-hour, 3-day, Urgent, and Completed views, highlights work due within seven days, and orders each view by nearest deadline. |
| Task assignment and status updates | [x] Done in code | Live task creation supports real client/worker IDs, document links, deadlines, priority, remarks, status updates, and an API-backed task-comment view. |
| Calendar of task and obligation deadlines | [x] Done in code | The calendar supports month/day navigation, deadline indicators, a selected-day agenda, and persisted business-wide or client-linked calendar events. Migration 053 adds the event store. |

## Staffing, Finance, And Invoicing

| Requirement | Status | Current implementation |
|---|---|---|
| Staffing workload, assigned clients, and open tasks | [-] Partial | A manager-only staffing API and Flutter staffing workload view show workers, assigned-client counts, and open tasks. Assignment management remains to build. |
| Client-aware expenses and revenue | [x] Done in code | Managers can create, filter by type/client, and edit client-linked or business-wide revenue and expense entries. Invoice payment entries remain protected and are managed from their invoice. |
| Invoices with draft, sent, paid, and void states | [x] Done in code | Invoices support draft, sent, paid, and void states; the detail screen renders line items and totals, generates print/share PDFs, and can deliver the invoice through the configured SMTP server. |

## Audit, Security, Limits, And Testing

| Requirement | Status | Current implementation |
|---|---|---|
| General activity log | [-] Partial | Backend logs client, folder, document, task, obligation, and invoice events and exposes an activity API. The Flutter activity log supports text search and action filters; export remains to build. |
| Business-scoped authorization | [x] Done in code | Membership middleware, administrative business-type checks, active-subscription checks, and manager/worker client/task/obligation checks are implemented. |
| Subscription quota enforcement | [-] Partial | Client and document-storage limits are enforced by administrative API routes. Staff and branch limits still need enforcement at their creation points. |
| Document/credential encryption and version history | [-] Partial | Immutable document-version records are created on upload and can be listed. Credential encryption, passcode verification, and replacement-version uploads are still required. |
| Automated tests | [-] Partial | Provider workflow tests exist. Route integration, authorization, quota, invoice, and document-version tests remain. |

## Next Priority Work

1. Apply migrations 042, 050, 051, 052, 053, and 054, then add route integration tests for authorization, quota, invoice payment transactions, calendar events, document uploads, and version approval.
2. Connect document folders/uploads, live task assignment, and remaining client-detail tabs to the API.
3. Implement file upload/storage, signed downloads, document replacement/new-version behavior, and its review UI.
4. Enforce staff and branch quota limits at their creation points.
5. Implement encrypted credentials, passcode verification, and credential reveal/copy audit events.
