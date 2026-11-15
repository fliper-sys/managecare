# ManageCare UI v2 (branch: `redesign-v2`)

**Design target: the Flagship Tactile-Luxury demo, exactly the same design feel and more. See `design_target.md`. It overrides anything else.**

Long-lived branch for the restructuring in the ManageCare Restructuring Blueprint
(14 November 2026). The current app on `main` keeps shipping and being fixed
while this is built.

## Rules
1. **Nothing merges into `main` until the pilot and the final sign-off pass.** No pull request to `main`, no release builds from this branch.
2. **Bug fixes for the live app happen on `main`.** Do not fix old screens here.
3. **Keep this branch current:** `git checkout redesign-v2 && git merge main` at least weekly, so main's fixes are not lost. Merge, do not rebase, once the branch is shared.
4. **Additive first.** New code goes in the folders below. Old files are edited only to route through the `UiV2` flag, and old screens are deleted only at sign-off.
5. **No `pubspec.yaml` version bump** on this branch.

## Layout (all new, beside the existing folders)
```
lib/design/                design tokens, theme, type, motion, icons, lottie registry
lib/design/components/     shared components
lib/business_profiles/     BusinessProfile + one file per business type
lib/shared_features/       checkout, receipt, plan_journey, inventory, work_feed
lib/templates/             catalogue_cart, booking_schedule, rooms_tables
lib/features/retail/       pilot: retail-only screens and state
```

## Switching v2 on (planned)
`UiV2.enabledFor(businessType)` is checked where the router builds the home and sales screens.
Start as a build setting: `flutter run --dart-define=UI_V2=retail`.
Turning it off returns that business to the old screens.

## Order of work
Wave 1 Retail (pilot) -> gate -> Wave 2 catalogue and cart -> Wave 3 booking and schedule
-> Wave 4 rooms and tables -> Wave 5 Administrative Services and Real Estate.

## Status
- Phase 1 (foundation): `lib/design` tokens, motion and five components; `lib/business_profiles` contract and Retail profile; `lib/shared_features/ui_v2.dart` flag; `tool/check_ui_v2_colors.sh`; tests in `test/ui_v2/`; `docs/ui_v2/retail_baseline.md`.
- Not yet verified by `flutter analyze` or `flutter test`: run both before building on this.
- Phase 2 (demo-parity primitives): `AmbientBackground`, `GlassSurface`, `StaggerIn`, `StatusIsland`, `PillTabBar`, bundled fonts (pubspec.yaml `fonts:`), tests in `test/ui_v2/phase2_test.dart`.
- Phase 3 (Retail home view): `HeroKpiCard`, `HoloTilt`, `OdometerText`, `SparklineDraw`, `SwipeRow`, `QuickActionsGrid`, `PlanSummaryCard`, `lib/features/retail/home/` (view and data, no provider access), `test/ui_v2/phase3_test.dart`.
- Phase 3c (multi-business): session phases, per-business profile states, `TenantScope`, v2 switcher sheet, `SessionGate` with skeletons, provider adapter, `test/ui_v2/session_test.dart`. See `multitenant.md`.
- Phase 3b (retail wiring): `lib/features/retail/home/retail_home_screen.dart` connector (providers read here only); `routes/app_router.dart` retail case switches on `UiV2.enabledFor('retail')` (one edit; default build unchanged). Delta, count and 7-day trend come from `retail_sales_summary.dart` (one `fetchSales` call, tested in `sales_window_test.dart`). Next: plan journey, catalogue-cart template.
- Phase 4a (plan journey): `lib/shared_features/plans/` tier cards, billing-length chips, confirm sheet, `planChoicesFor(businessType)` reading the existing catalogue; payment stays with the caller. Tests `plan_journey_test.dart`. Not yet routed.
- Phase 4c (Retail POS): `lib/features/retail/pos/retail_pos_screen.dart` on the template; `Routes.retailPos` flagged like the home. The v2 cart is copied into the provider cart at checkout and `RetailProvider.checkout` runs unchanged (stock check, offline queue, upload). Now covered: wholesale/retail mode, **editable price per line (catalogue row and checkout line, shared `showPriceEditor`)**, tax from the business rate, discount, split payments (must add up), store picker, several open carts, offline-queued notice on the receipt. **Currency:** `formatNairaPrecise` (kobo only when present) for every unit price, line and total; `NairaInputFormatter` groups thousands while typing in all money fields; `parseNaira` reads them back. Also done: saved-customer picker (search by name or phone; id and email sent; customer totals updated after an uploaded sale, as the old POS does), per-line retail/wholesale chips, and open carts saved per business under their own key (`ui_v2_pos_carts_<businessId>`; restored against today's prices and stock, with a notice when lines are dropped or reduced). Still missing: **credit sales**, which need a backend decision (there is no debt or balance field on sales or customers today). **Parity audit against `sales_screen.dart` (done):** fixed tax (now typed at checkout, default 0, like the old POS, not read from the business); fixed stock caps for wholesale sale units (a carton uses 12 base units); fixed `fullName` for the worker name; hid fuel and gas products like the old POS; added the post-sale steps (customer receipt email, owner alert and log, order-success email on `email_receipts` plans, pending-sync badge, offline in-memory stock) in `retail_post_sale.dart`; added a Print or share receipt button that opens the existing `ReceiptManager`. **Then added:** worker permissions for price edit and discount (same `WorkerPermissions` rules, enforced inside `CartState` and on restore, not only hidden in the UI); camera and handheld barcode scanning with the old matching rules and analytics event; store filter that reloads products and sets the checkout store; refresh, Sales history (reuses the existing screen, which holds sale details and returns/refunds) and Customer tracking buttons. **Sales history (v2):** `lib/features/retail/history/` redone on the same data calls as the old screen (paged history, device-only offline sales merged on All/Completed, today/7-day/month totals or a custom range, delete with stock restore, refund, print, sync button). New: working search over reference, customer and product, a skeleton while loading, retry on failure, an action sheet per sale. Sale detail and the refund form are still the old screens. Logic is in pure files (`sale_summary.dart`, `sales_pager.dart`) with tests in `history_test.dart`. **Router safety:** the three flagged routes now go through `UiV2Switch`, which checks the current business's type as well as the flag, so shared routes like Sales history never show retail screens to other business types. **Observation, not changed:** the old history lets any role delete a sale (stock is restored); there is no permission check. **Not yet in v2 POS:** invoice generation (Quick Sale only), in-screen sale details and refunds (reached through the old history screen), pharmacy product merge. The old procurement button was already moved to Inventory, so it is not a POS feature. Payment strings follow the old screen (Cash/Transfer/Card, Mixed + lower-case breakdown); Credit is hidden until confirmed.
- Phase 4b (catalogue-cart): `lib/templates/catalogue_cart/` `CartState` (per business, stock-capped), `CatalogueCartView` (search, categories, loading/empty states, cart bar), one `CheckoutSheet` (review, processing with no double submit, failure with retry, receipt), `ReceiptCard` (perforated) and `DrawnTick`. Tests `catalogue_cart_test.dart`. 

## Checks
```
./tool/check_ui_v2_colors.sh
flutter analyze lib/design lib/business_profiles lib/shared_features test/ui_v2
flutter test test/ui_v2
```
