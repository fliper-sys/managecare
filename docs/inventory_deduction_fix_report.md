# Inventory Deduction Fix Report

## Problem

Some products reduce stock correctly after a sale, while others do not. The behavior is inconsistent because the app has more than one sale path, and not every path resolves inventory in the same way.

## What is happening now

### 1) Some sale items do not carry a usable inventory link

The stock deduction logic depends on a product identifier such as:

- `productId`
- `inventoryProductId`
- `inventoryId`
- `itemId`

If a sale item does not include one of these fields, the app skips the deduction for that line item.

### 2) Quantity is not always normalized the same way

Different screens store quantity in different fields:

- `quantity`
- `qty`
- `quantitySold`
- `soldQty`
- `inventoryQuantity`
- `saleUnitMultiplier`

If a deduction routine reads only one of those fields, the calculation can be wrong or ignored.

### 3) Some flows use different stock fields

Across the app, stock may be written to:

- `quantity`
- `stock`

If the deduction logic updates one field while the UI reads the other, it looks like the stock did not change.

### 4) Some sale flows update stock after the sale, others only save the sale

The retail sale flow updates inventory immediately after checkout.
Other flows may save the sale record first and rely on a later sync, retry, or separate service to deduct inventory.

That means the sale can exist without the stock update if:

- the write fails,
- the item is offline-pending,
- the sync does not complete,
- or the sale is recorded locally only.

### 5) Wholesale and multiplier sales need special handling

Wholesale items often use:

- `pricingMode`
- `saleMode`
- `saleUnit`
- `saleUnitMultiplier`

If the deduction routine uses the display quantity instead of the resolved multiplier, stock will be under-deducted.

## Current deduction path observed

In the retail sale flow, the app creates sale line items with:

- `productId`
- `quantity`
- `unitPrice`
- `pricingMode`
- `saleUnit`
- `saleUnitMultiplier`
- `inventoryQuantity`

Then it reduces inventory with:

`newQuantity = product.stock - (saleUnitMultiplier × quantity)`

That is the correct formula, but it only works when:

- the product exists in memory,
- the product ID matches the inventory document ID,
- the inventory document is writable,
- and the stock field read by the UI is the same field that gets updated.

## Root cause summary

The main causes of the inconsistency are:

1. sale items not always carrying the inventory document ID
2. quantity fields not being normalized consistently
3. stock field mismatch between `stock` and `quantity`
4. sale flows that save records without completing the deduction
5. wholesale sales needing multiplier-aware deduction

## Detailed fix

### A) Standardize sale item payloads

Every sale line item should always include:

- `productId`
- `quantity`
- `unitPrice`
- `pricingMode`
- `saleUnit`
- `saleUnitMultiplier`
- `inventoryQuantity`

For wholesale items, `inventoryQuantity` must always equal:

`quantity × saleUnitMultiplier`

### B) Centralize inventory deduction

Create one shared inventory deduction service that:

- reads the sale item payload,
- resolves the product ID,
- normalizes quantity,
- resolves wholesale multipliers,
- updates the correct stock field,
- and logs any skipped item with a reason.

### C) Use one stock field everywhere

Pick one canonical field for inventory count and use it consistently across:

- inventory screens
- product detail screens
- sale screens
- reporting
- deduction logic

If `quantity` is the canonical field, then all views and updates should use `quantity`.

### D) Add a skip-reason audit log

When deduction is skipped, log the reason:

- missing `productId`
- missing quantity
- zero quantity
- missing inventory document
- permission failure
- offline sync pending

This makes future debugging much easier.

### E) Apply deduction after sale commit and after sync

If offline or async sale saving is supported, inventory should be deducted:

- immediately after the sale is confirmed, and
- again during sync reconciliation if the sale was queued offline

This prevents “sale saved, stock not reduced” inconsistencies.

## Validation test

Use these cases to confirm the fix:

### Test 1: Retail product

- Product stock: `10`
- Quantity sold: `2`
- Expected stock: `8`

### Test 2: Wholesale product

- Product stock: `100`
- Quantity sold: `3`
- `saleUnitMultiplier = 12`
- Expected stock reduction: `36`
- Expected stock: `64`

### Test 3: Item without product link

- Sale item missing `productId`
- Expected result: no deduction
- Expected log entry: `missing productId`

### Test 4: Offline sale

- Save sale while offline
- Sync later
- Expected result: inventory reduced once sync completes

### Test 5: Mixed cart

- one retail item
- one wholesale item
- one service item

Expected:

- stock changes only for inventory-backed products
- service items do not change stock

## Acceptance criteria

The fix is valid when:

- every inventory-backed sale reduces stock exactly once
- wholesale sales reduce stock by the resolved multiplier
- products with missing inventory links are clearly logged
- the same stock number appears on product screens and reports
- offline sales reconcile correctly after sync

## Recommended next step

Implement a single shared deduction helper and call it from every sale completion flow so all business types use the same stock logic.

