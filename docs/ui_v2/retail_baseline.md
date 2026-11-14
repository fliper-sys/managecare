# Retail baseline (phase 1, code-derived)

Counted from `main` at commit e6e6d4b on 14 November 2026. Device timings and tap counts
need a running build and are listed as a checklist at the end.

## Entry points (core/constants/routes.dart, routes/app_router.dart)
| Route | Constant | Screen |
|---|---|---|
| `/retail` | `Routes.retailDashboard` | `retail_dashboard.dart` (1,299 lines) |
| `/retail/pos` | `Routes.retailPos` | `pos_screen.dart` (16 lines, wraps the shared `SalesScreen`) |
| `/retail/receipt` | `Routes.retailReceipt` | `retail_receipt_screen.dart` |
| `/retail/products`, `/add`, `/edit` | `retailProducts`, `retailAddProduct`, `retailEditProduct` | `product_management_screen.dart`, `add_product_screen.dart` (1,138 lines) |
| `/retail/suppliers`, `/add` | `retailSuppliers`, `retailAddSupplier` | supplier screens |
| `/retail/stores`, `/store-reports` | `retailStores`, `retailStoreReports` | `multi_store_screen.dart`, `store_reports_screen.dart` |
| `/retail/promotions`, `/wholesale` | `retailPromotions`, `retailWholesale` | `promotions_screen.dart`, `wholesale_orders_screen.dart` |

## Shared screens the retail flow runs through
| File | Lines | Notes |
|---|---|---|
| `presentation/sales/screens/sales_screen.dart` | 4,132 | Also used by wholesale, gas, workers and the router. 43 provider reads. Has a private `_CheckoutSheet`. |
| `presentation/industry_specific/retail/widgets/checkout_sheet.dart` | 1,303 | A third checkout sheet, public. |
| `presentation/sales/widgets/post_sale_action_sheet.dart` | 2,772 | After-sale actions. |
| `presentation/sales/screens/receipt_screen.dart` | 2,458 | Receipt. |
| `presentation/inventory/screens/inventory_list_screen.dart` | 1,547 | Inventory list. |
| `presentation/dashboard/owner/owner_dashboard_screen.dart` | 4,034 | Chooses the home per business by business-type text. |
| `providers/retail_provider.dart` | 3,301 | Defines `Product`; talks to Supabase, the API client, the local database, sync and notifications. 9 retail files import it. |

## Colour and font use in the retail flow
| File or folder | `Color(0x…)` | `Colors.*` | `GoogleFonts.*` |
|---|---|---|---|
| `industry_specific/retail/` | 7 | 121 | 0 |
| `sales_screen.dart` | 0 | 61 | 0 |
| `post_sale_action_sheet.dart` | 0 | 123 | 0 |
| `receipt_screen.dart` | 1 | 48 | 0 |
| `inventory_list_screen.dart` | 0 | 41 | 0 |
| `owner_dashboard_screen.dart` | 13 | 234 | 0 |

Colour is mostly `Colors.*` (Material shades), not literal hex, and fonts come from the theme here,
so the v2 colour rule is about replacing `Colors.*` with `AppTokens`.

## Services the retail flow calls (do not change; v2 reuses them)
`receipt_manager`, `pdf_invoice_generator`, `email_service`, `business_notification_manager`,
`web_download`, `barcode_service`, `analytics_service`, `notification_and_email_service`,
plus providers `business`, `auth`, `sync`, `reports`, `receipt_settings`, `customer`, `connectivity`, `workers`.

## Existing tests that touch this area
None. The 10 files in `test/` cover administrative, auth, drink, hospitality, local storage,
pharmacy, restaurant and worker permissions. Phase 2 adds `CartController` and checkout tests
before any retail logic is extracted.

## Checklist to capture on a device (fill in before phase 2)
- [ ] Quick sale: taps from home to a recorded cash sale (one item).
- [ ] Quick sale with wholesale pricing switch on.
- [ ] Taps to add a product.
- [ ] Cold start to home on a low-end Android phone and on the Windows POS.
- [ ] Offline sale, then sync: totals match.
- [ ] Print a receipt (ESC/POS and PDF): save both outputs as reference files.
- [ ] Record three test sales with known totals (cash, transfer, POS) to compare old and new.
- [ ] Plan card: tier and days left shown on home, in billing and in the payment screen. Note any mismatch.
