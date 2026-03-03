# Procurement Feature — Implementation Notes

This file documents the recent procurement feature implementation and the required Firestore structure and recommended indexes/security rules.

## What was added
- Batch procurement flow in `ProcurementScreen` (select multiple products, set quantity & cost, submit)
- Supplier selection and optional Invoice / Reference in the procurement confirmation dialog
- `ProcurementRepository` (Firestore interaction helpers)
- Master procurement documents under `businesses/{businessId}/procurements/{procurementId}`
  - Fields: `createdAt`, `totalCost`, `totalQuantity`, `itemsCount`, `items` (denormalized array), `supplierId`, `supplierName`, `invoiceRef` (optional)
- Per-product procurement records under `businesses/{businessId}/inventory/{productId}/procurements/{id}`
  - Fields: `procurementId`, `productId`, `quantity`, `cost`, `total`, `createdAt`, `supplierId`, `supplierName`, `invoiceRef`
- `ProcurementHistoryScreen` for searchable, filterable daily grouped lists and CSV export
- `ProductProcurementsScreen` to view procurements for a single product

## Firestore considerations
- The repository uses batched writes and `FieldValue.increment` when updating product quantity.
- Ensure inventory docs exist for the product ids used; otherwise the update will fail. If you may procure products that do not exist in `inventory/`, consider adding logic to `createBatchProcurement` to create inventory docs when missing.

## Indexes
- The current queries use ordered `createdAt` on subcollections and on the `procurements` collection. If you add collectionGroup queries in future, you may need to add composite indexes via `firestore.indexes.json`.

## Security rules
- Procurement creation increases inventory and writes proc records. Ensure only authorized roles (owners/managers) can write to these paths.

## Exports
- CSV export available from `ProcurementHistoryScreen` (copies CSV to clipboard and shows a preview). Consider using `ReportExportService` or platform-specific download for file saving.

## Migration notes
- No destructive changes performed. The new master doc is denormalized for performance when listing histories.

## TODO / Optional improvements
- Add supplier and invoice reference to procurement master doc
- Add PDF export using `ReportExportService`
- Add tests (unit and widget tests) and CI task to run them (unit tests added for `ProcurementRepository` in `test/data/repositories/procurement_repository_test.dart`)
- Add ability to import procurement CSVs

If you'd like, I can continue by adding supplier selection to the procurement flow, PDF export, and UI tests — tell me which you'd like prioritized.