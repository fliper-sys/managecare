# Financial Calculation Guide

This document explains how the app generates financial totals, how the numbers are derived from source records, and how to validate that the results are correct.

## 1) Data sources

The app builds financial reports from Firestore data and related business records:

- `businesses/{businessId}/sales`
- `sales` mirror collection when available
- `businesses/{businessId}/expenses`
- `businesses/{businessId}/inventory`
- customer and receipt records used for display, not for core profit math

The financial report screen, the detailed breakdown screen, and WhatsApp summaries should all reference the same underlying sales and expense records.

## 2) How sales revenue is generated

Revenue is taken from the sale record itself, using the most complete amount available:

1. `finalAmount`
2. `totalAmount`
3. `total`
4. fallback to line-item math only when needed

This prevents revenue from drifting when discounts, taxes, or service charges are already reflected in the stored sale total.

### Revenue rule

`total sales revenue = sum of sale total fields for the selected date range`

## 3) How Cost of Goods Sold (COGS) is generated

COGS is calculated per sold item:

`item COGS = item quantity × item unit cost`

The item unit cost is resolved in this order:

1. direct sale item cost fields such as `costPrice`, `cost`, `unitCost`, `purchasePrice`, or `inventoryCost`
2. linked inventory product cost from `businesses/{businessId}/inventory/{productId}`
3. nested product cost fields when the item stores an embedded product map

If the item is sold in wholesale/bulk form, the sale quantity or multiplier is used so the cost reflects the real amount moved from stock.

### COGS rule

`total COGS = sum of all sold line-item costs`

## 4) Gross profit

Gross profit shows profit before operating expenses.

`gross profit = total sales revenue - total COGS`

Gross margin:

`gross margin % = (gross profit ÷ total sales revenue) × 100`

## 5) Operating expenses

Operating expenses are loaded from the business expense records inside the selected date range.

Examples:

- rent
- salaries
- utilities
- admin costs
- other recurring expenses

### Expense rule

`operating expenses = sum of all expense records in the selected date range`

## 6) Net profit

Net profit is the final profit after operating expenses are removed.

`net profit = gross profit - operating expenses`

Net margin:

`net margin % = (net profit ÷ total sales revenue) × 100`

## 7) How the detailed screen is built

The detailed financial breakdown screen reads the same report provider data and shows:

- selected date range
- total sales revenue
- total COGS
- gross profit
- operating expenses
- net profit
- gross margin
- net margin
- sale-by-sale breakdown
- item-by-item cost breakdown
- wholesale flags where applicable
- expense-by-expense breakdown

This makes the report easier to audit and helps spot any mismatch between a sale receipt and the summary totals.

## 8) How WhatsApp summaries are generated

WhatsApp summaries should use the same source logic as the report page:

- transaction totals from payment transaction records
- gross profit from sale revenue minus COGS
- wholesale line count from sold items marked wholesale/bulk or sold with a multiplier greater than 1

The message should clearly label:

- total sampled revenue
- gross profit
- gross margin
- wholesale items included in the summary

## 9) Why inventory may not always decrement

If inventory reduction is inconsistent, it usually means one of these is missing on the sold item:

- `productId` or another inventory link
- a numeric quantity
- a recognized wholesale multiplier
- a sale completion step that actually writes the stock update

When any of those fields are missing or the item is not linked to inventory, the stock update cannot be resolved reliably.

## 10) Validation test

Use this scenario to confirm the calculations are valid:

### Test setup

Create:

- 1 product in inventory with `costPrice = 2,000`
- 1 sale of 3 units of that product at `unitPrice = 3,500`
- 1 operating expense of `1,000`

### Expected result

- Revenue: `3 × 3,500 = 10,500`
- COGS: `3 × 2,000 = 6,000`
- Gross profit: `10,500 - 6,000 = 4,500`
- Net profit: `4,500 - 1,000 = 3,500`
- Gross margin: `42.86%`
- Net margin: `33.33%`

### Inventory check

After sale completion, inventory should reduce by exactly `3` units.

For a wholesale sale with a multiplier, verify that the inventory deduction uses the actual sold quantity or the resolved multiplier, not only the displayed unit label.

### Acceptance criteria

- The financial report shows the same revenue, COGS, gross profit, and net profit as the manual calculation
- The detailed breakdown screen shows the same numbers with line-by-line explanation
- The WhatsApp summary matches the report totals
- Inventory stock changes by the expected quantity after the sale is completed

## 11) Suggested regression test

Repeat the same test after each release with:

- one retail sale
- one wholesale sale
- one service-only sale
- one sale with discount or extra charge
- one sale with multiple items and mixed costs

If any one of those cases disagrees with the manual calculation, the sale record fields or cost lookup logic should be checked first.

