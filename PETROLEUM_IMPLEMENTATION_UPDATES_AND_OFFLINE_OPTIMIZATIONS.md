# Petroleum Pump Upload Review, Cash Tracking, And Offline Optimization Updates

## Deployment Status

The backend migration and updated pump routes have been copied to the VPS and deployed.

- Backend path: `/opt/managecare-backend`
- PM2 process: `managecare-backend`
- Health check: `https://backend.managecare.info/api/health`
- Confirmed health response:
  - `status: ok`
  - `database: connected`
  - `minio: configured`

Migration applied:

- `server/managecare-backend/migration_046.sql`

Backend route updated:

- `server/managecare-backend/routes/pumps.js`

## Main Business Flow Update

Pump uploads no longer register a sale or deduct stock immediately when a pump operator submits readings.

New flow:

1. Pump operator submits pump upload.
2. Upload is saved as `pending_review`.
3. Fuel stock is not deducted yet.
4. Fuel sale is not registered yet.
5. Manager or admin reviews the upload.
6. Manager/admin can approve, edit then approve, decline, or mark faulty.
7. Only approval creates the fuel sale, deducts inventory, and records petroleum cash income.
8. Declined or faulty uploads remain visible to the pump operator.
9. Pump operator can reregister a declined/faulty upload, which reopens the pump upload screen with previous values prefilled.

## Backend Updates

### Pump Upload Status Support

Pump upload records now support the following review statuses:

- `pending_review`
- `approved`
- `declined`
- `faulty`
- `resubmitted`

New pump upload fields added:

- `status`
- `submitted_at`
- `submitted_by`
- `submitted_by_name`
- `reviewed_at`
- `reviewed_by`
- `reviewed_by_name`
- `review_note`
- `decline_reason`
- `approved_sale_id`
- `approved_stock_deduction_applied`
- `resubmitted_from_upload_id`

Existing pump uploads with linked sales were backfilled as `approved`.

### Pump Upload Submission Endpoint

Updated endpoint:

- `POST /api/pumps/:businessId/uploads`

New behavior:

- Saves pump upload as `pending_review`.
- Preserves submitted time from the app.
- Supports offline synced uploads.
- Supports `resubmitted_from_upload_id`.
- Does not create a sale immediately.
- Does not deduct stock immediately.

### Manager Review Endpoints

Added or updated endpoints:

- `GET /api/pumps/:businessId/uploads?status=pending_review`
- `GET /api/pumps/:businessId/uploads/counts`
- `PATCH /api/pumps/:businessId/uploads/:id/review`
- `PATCH /api/pumps/:businessId/uploads/:id/decline`

Manager approval now runs inside a database transaction:

1. Locks the pump upload record.
2. Applies manager edit values.
3. Validates product, sold volume, and paid amount.
4. Creates the fuel sale.
5. Creates the sale item.
6. Deducts fuel inventory.
7. Creates petroleum cash income entry.
8. Marks upload as `approved`.
9. Stores approved sale reference.

### Review Access Control

Review and approval endpoints are protected.

Allowed roles:

- owner
- admin
- sub_admin
- manager
- fuel_manager

Pump operators and other workers cannot approve, decline, or globally review pump uploads.

## Cash Tracking Backend Updates

### Petroleum Cash Entries

New table:

- `petroleum_cash_entries`

Used for:

- Approved pump upload cash income
- POS/transfer income connected to approved fuel sales
- Worker/pump/product cash reporting

### Bank Deposit Updates

Bank deposits now support:

- deposited cash entry
- balance cash at hand
- submitted date
- submitted time
- history records

Updated backend support:

- `GET /api/pumps/:businessId/bank-deposits`
- `POST /api/pumps/:businessId/bank-deposits`

### Admin Cash Submission Updates

New backend support:

- `GET /api/pumps/:businessId/admin-cash-submissions`
- `POST /api/pumps/:businessId/admin-cash-submissions`

Records include:

- receiver/admin name
- submitted amount
- balance cash at hand
- submitted date
- submitted time
- note

### Cash Summary

New endpoint:

- `GET /api/pumps/:businessId/cash-summary`

Summary tracks:

- approved pump cash income
- POS/transfer income
- bank deposits
- admin cash submissions
- current balance cash at hand

## Frontend Updates

### Pump Upload Screen

Updated file:

- `lib/presentation/industry_specific/gas/screens/pump_daily_upload_screen.dart`

Changes:

- Removed immediate fuel sale creation from pump upload submit.
- Removed immediate stock deduction from pump upload submit.
- Submits upload as `pending_review`.
- Sends `submitted_at` so pending uploads keep the correct worker submission time.
- Supports `prefillUpload` for reregistering declined/faulty uploads.
- Preserves uploaded photos and reading values when reregistering.
- Offline submissions now enter manager review after sync.

### Manager Pump Upload Review Screen

Screen:

- `lib/presentation/industry_specific/gas/screens/manager_pump_upload_review_screen.dart`

Purpose:

- Available to managers/admins/owners/fuel managers.
- Shows pending uploads.
- Shows pending upload count through dashboard badge.
- Allows manager to inspect readings, worker, pump, product, cash, and POS values.
- Allows edit before approval.
- Allows approve, decline, or mark faulty.

### Pump Operator Upload Status Screen

Screen:

- `lib/presentation/industry_specific/gas/screens/worker_declined_pump_uploads_screen.dart`

Purpose:

- Available to pump operators.
- Shows upload statuses for the logged-in pump operator.
- Includes pending, approved, declined, and faulty uploads.
- Shows submitted time and reviewed time.
- Shows manager note or decline reason.
- Provides reregister button for declined/faulty uploads.
- Reregister opens pump upload screen with the old upload values prefilled.

### Gas/Petroleum Dashboard Updates

Updated file:

- `lib/presentation/industry_specific/gas/screens/gas_dashboard_screen.dart`

Changes:

- This is the active industry-specific business dashboard.
- Manager/admin/owner/fuel manager receive global petroleum access.
- Pump operators do not receive global access.
- Pump operators see upload/status-related actions.
- Manager/admin users see upload review.
- Pending review count is shown as a badge.
- Declined/faulty upload count is shown for pump operators.
- Bank deposit and cash tracking actions are available for petroleum managers/admins.
- Existing permission helpers remain important and are still used:
  - `WorkerPermissions.canAccessPumpConfigurationForUser`
  - `WorkerPermissions.canAccessProcurementForUser`
  - `WorkerPermissions.canAccessExpensesForUser`

### Reports Section Navigation

Updated file:

- `lib/presentation/reports/screens/reports_dashboard_screen.dart`

Petroleum report entries added:

- Petroleum Cash Tracking
- Petroleum Bank Deposits

These entries appear for petroleum businesses where the user has manager/admin/global report access.

### Bank Deposit Screen

Updated file:

- `lib/presentation/industry_specific/gas/screens/petroleum_bank_deposit_screen.dart`

Changes:

- Added deposited cash entry field.
- Added balance cash at hand field.
- Saves deposited cash entry and balance cash at hand to backend.
- Shows balance in deposit history.
- Direct screen access is limited to managers/admins/owners/fuel managers.

### Petroleum Cash Tracking Screen

Updated file:

- `lib/presentation/industry_specific/gas/screens/petroleum_cash_tracking_screen.dart`

Features:

- Approved pump cash income section.
- Bank deposits section.
- Cash given to admin section.
- Cash summary cards.
- Admin cash submission dialog.
- CSV download/export support.
- Direct screen access is limited to managers/admins/owners/fuel managers.

## Offline Optimization Updates

Updated file:

- `lib/presentation/industry_specific/gas/utils/pump_upload_offline_queue.dart`

Offline improvements:

- Offline pump uploads are queued when the device has no connection.
- Queued uploads keep their original `submitted_at` time.
- Queue entries store `queuedAt`.
- Upload body is normalized before saving offline.
- Duplicate queued uploads are reduced using `upload_fingerprint`.
- Offline uploads sync to the same backend endpoint as online uploads.
- Synced offline uploads become `pending_review`, matching online behavior.
- Photos are resolved before sync so incomplete uploads stay queued until ready.
- Queue processing remains oldest-first by preserving queue order.
- Failed sync attempts remain in the queue for retry.

Result:

- Online and offline pump uploads now follow the same review workflow.
- Offline uploads no longer deduct stock or register sales before manager approval.
- Worker submission time remains traceable after sync.

## Route Updates

Updated files:

- `lib/core/constants/routes.dart`
- `lib/routes/app_router.dart`

Routes added:

- `Routes.petroleumPumpUploadReview`
- `Routes.petroleumDeclinedPumpUploads`
- `Routes.petroleumCashTracking`

Pump upload route now accepts optional prefill data for reregistering declined/faulty uploads.

## Data And Report Mapping Updates

Updated file:

- `lib/presentation/industry_specific/gas/utils/pump_row_mapper.dart`

Mapped new fields:

- status
- submitted/review timestamps
- reviewer details
- review notes
- decline reason
- approved sale id
- stock deduction status
- resubmitted source upload id

Updated file:

- `lib/presentation/industry_specific/gas/screens/pump_upload_history_screen.dart`

Changes:

- Displays upload status.
- Displays decline reason when present.
- Displays manager review note when present.

## Verification Completed

Backend syntax check passed:

```powershell
node --check server\managecare-backend\routes\pumps.js
```

VPS migration applied successfully:

```bash
sudo -u postgres psql -d managecare -f migration_046.sql
```

Backend restarted successfully:

```bash
pm2 delete managecare-backend
pm2 start server.js --name managecare-backend
pm2 save
```

Health check confirmed:

```bash
curl https://backend.managecare.info/api/health
```

Response confirmed:

```json
{
  "status": "ok",
  "database": "connected",
  "minio": "configured"
}
```

## Notes

- The old PM2 log errors about `SALE-...` invalid UUID came from older sale route requests, not from the new migration.
- Flutter formatting/analyzer commands were attempted but stalled in the local environment, so the backend was verified directly and deployed first.
- The backend is live and ready for the updated Flutter app workflow.
