# Petroleum Pump Upload Review And Cash Tracking Report

## Objective

Rework petroleum/gas pump uploads so worker submissions no longer deduct fuel stock or register sales immediately. Every online and offline pump upload must first enter a manager review queue. A manager can approve, edit then approve, mark faulty, or decline the upload. Only approved uploads should deduct fuel stock, register fuel sales, and create cash-income records.

The system also needs a petroleum cash section for worker cash breakdowns, approved pump cash income, bank deposits, admin cash submissions, balance cash at hand, history filters, and downloadable records.

## Current Flow

- Pump upload already exists in `lib/presentation/industry_specific/gas/screens/pump_daily_upload_screen.dart`.
- Offline pump upload queue already exists in `lib/presentation/industry_specific/gas/utils/pump_upload_offline_queue.dart`.
- Pump upload history already exists in `lib/presentation/industry_specific/gas/screens/pump_upload_history_screen.dart`.
- Disputed upload review already exists in `lib/presentation/industry_specific/gas/screens/disputed_pump_uploads_screen.dart`.
- Petroleum bank deposit already exists in `lib/presentation/industry_specific/gas/screens/petroleum_bank_deposit_screen.dart`.
- Current pump upload submission calls `RetailProvider.fuelSale()`, so sales registration and stock deduction happen before manager review.

## Required New Flow

1. Worker opens pump upload.
2. Worker enters pump readings, photos, cash/POS amount, and cash denomination breakdown.
3. Worker submits upload.
4. Upload is saved as `pending_review`.
5. No stock deduction happens yet.
6. No sale is registered yet.
7. Manager reviews pending uploads.
8. Manager can edit values before final decision.
9. If approved, the backend creates the fuel sale, deducts stock, records cash income, and marks the upload as `approved`.
10. If declined/faulty, the upload is returned to the worker.
11. Worker sees declined uploads and can reregister, which opens pump upload prefilled with the old values for correction and resubmission.

## Backend Work

### Pump Upload Status

Add or support these statuses on pump upload records:

- `pending_review`
- `approved`
- `declined`
- `faulty`
- `resubmitted`

Each pump upload record should carry:

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

### Pump Upload Submission

`POST /api/pumps/:businessId/uploads` should only save a pump upload record. It must not create a fuel sale or deduct inventory. Offline uploads should sync into the same `pending_review` state.

### Manager Review Endpoints

Required backend endpoints:

- `GET /api/pumps/:businessId/uploads?status=pending_review`
- `GET /api/pumps/:businessId/uploads/counts`
- `PATCH /api/pumps/:businessId/uploads/:uploadId/review`
- `PATCH /api/pumps/:businessId/uploads/:uploadId/decline`
- `PATCH /api/pumps/:businessId/uploads/:uploadId/resubmit`

Approval must run in one database transaction:

1. Lock/read upload.
2. Apply manager edits.
3. Create fuel sale.
4. Create sale item.
5. Deduct fuel inventory.
6. Create petroleum cash income entry.
7. Mark upload approved with sale id.

### Cash Tracking Data

Add petroleum cash tracking records for:

- approved pump upload cash income
- manual worker cash entry
- bank deposit
- admin cash submission

Suggested records:

- `petroleum_cash_entries`
- `petroleum_cash_breakdowns`
- `petroleum_bank_deposits`
- `petroleum_admin_cash_submissions`

Cash report filters:

- type
- worker
- pump
- date range
- bank deposits only
- admin submissions only

Download formats should support CSV first, then PDF later if needed.

## Frontend Work

### Pump Upload Screen

Update `PumpDailyUploadScreen` so submit saves a `pending_review` upload only. Remove immediate `RetailProvider.fuelSale()` from pump upload approval path.

The screen should accept prefilled values for reregistered declined uploads.

### Manager Review Screen

Create a manager screen for:

- pending upload count
- upload list
- pump/operator/product details
- readings and calculated totals
- photos
- cash/POS breakdown
- edit fields
- approve
- mark faulty
- decline

### Worker Declined Upload Screen

Create a worker-facing declined upload page showing:

- declined/faulty uploads
- manager reason/note
- submitted time
- reviewed time
- pump details
- reregister button

Reregister opens pump upload with previous values prefilled.

### Dashboards And Badges

Add badges/counts for:

- pending manager review uploads
- declined worker uploads
- offline uploads waiting to sync

### Petroleum Cash Tracking Screen

Create a report screen under Reports with:

- approved pump cash income
- POS/transfer income
- worker cash denomination breakdown
- bank deposit records
- cash given to admin
- balance cash at hand
- filters
- download/export

### Bank Deposit Screen

Expand bank deposits to include:

- deposited cash entry
- balance cash at hand
- date/time submitted
- history filters
- downloadable records

### Admin Cash Submission

Add screen/records for:

- amount given to admin
- receiver/admin name
- balance before
- balance after
- date/time submitted
- submitted by
- history/download

## Build Order

1. Add markdown report.
2. Locate active custom pump API definitions.
3. Add backend status/count/review/cash support.
4. Rework pump upload submit to pending review.
5. Update offline upload queue to sync pending review only.
6. Add manager review screen.
7. Add worker declined uploads screen and reregister prefill.
8. Add routes and dashboard entries.
9. Add cash tracking report and bank/admin cash extensions.
10. Run static analysis and targeted tests.

