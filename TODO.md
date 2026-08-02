# Task: Limit Export Sales History retrieval to last 100 sales (per selected date range)

## Context
The Export Sales History screen (Settings) fetches all 2000+ sales (via `ReportsProvider.fetchSalesList` with
`limit: 5000`/`2000`), but the limit is only applied client-side AFTER fetching every page, causing severe lag.
Sales Report and Sales History screens must remain unlimited/paginated as they are.

## Steps
- [x] 1. Understand the delete-sale flow and confirm it works (user confirmed)
- [x] 2. Read all relevant files (sales_repository_supabase, sales_repository_impl, domain/sales_repository,
         reports_provider, export_sales_history_screen, startup_notifications)
- [ ] 3. Add optional `int? limit` to abstract `SalesRepository.fetchSales` (domain)
- [ ] 4. Add `int? limit` param to `SalesRepositorySupabase.fetchSales` and pass into query params (repo)
- [ ] 5. Add `int? limit` param to `SalesRepositoryImpl.fetchSales` (Firebase impl)
- [ ] 6. Pass `limit` through in `ReportsProvider.fetchSalesList` to `_salesRepo.fetchSales`
- [ ] 7. Change all `fetchSalesList` calls in export_sales_history_screen.dart to `limit: 100`
- [ ] 8. Run `flutter analyze` to verify no type errors

