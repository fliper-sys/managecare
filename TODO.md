# Private Database Migration Bug Fixes - TODO

## Priority 1: Worker & Permission Issues
- [x] 1. Fix worker role always "staff" (auth_provider_supabase.dart)
- [x] 2. Fix workers shown off duty / permission filtering (workers.js + worker_permissions)
- [x] 3. Fix edit permission & role switching not working (worker_details_screen.dart + workers_provider.dart)

## Priority 2: Pharmacy & Procurement Issues
- [x] 4. Fix products registered as "pharmacy" in procurement edit (procurement_screen.dart)
- [x] 5. Fix sale error due to pharmacy category (sales_screen.dart)

## Priority 3: Wholesale Pricing
- [x] 6. Fix wholesale pricing missing from product data (inventory_repository_supabase.dart + inventory.js)

## Priority 4: Offline & Subscription
- [x] 7. Fix logout to subscription page on offline (auth_provider_supabase.dart + enhanced_subscription_provider.dart)

## Priority 5: WhatsApp & Email
- [x] 8. Fix WhatsApp message to include sold items (whatsapp_service.dart)
- [x] 9. Add petroleum remaining stock to WhatsApp (whatsapp_service.dart)
- [x] 10. Wire up daily email transactions from all businesses page (owner_dashboard_screen.dart)
