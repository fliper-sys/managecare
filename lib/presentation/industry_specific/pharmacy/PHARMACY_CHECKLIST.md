Pharmacy Feature Checklist

Goal: Provide a production-ready Pharmacy vertical with POS, prescriptions, inventory management, expiry tracking, patient records, and controlled substance handling.

Core Modules (MVP):
- [x] Dashboard (overview stats, quick actions)
- [x] Drug Inventory (list, add, edit, stock adjustments)
- [x] Prescriptions (create, list, dispense, mark status)
- [x] Expiry Tracker (show drugs expiring soon)
- [x] Patient Records (CRUD basic patient data)
- [ ] POS for Pharmacy (sales flow, receipts, integration with payments)
- [ ] Controlled Substances module (compliance + audit logs)
- [ ] Reporting (sales, expiry, inventory valuation)

Technical tasks:
- [x] Add `PharmacyProvider` with models and API stubs
- [x] Wire `pharmacyDashboard` route in app router
- [x] Add localization hooks for UI strings
- [ ] Add widget/unit tests for UI screens (POS, inventory, prescriptions)
- [ ] Integrate backend API / Firestore for persistence
- [ ] Add access controls and user roles (pharmacist vs clerk)

Next immediate steps:
1. Implement Pharmacy POS screen and wire to `PharmacyProvider` (stock adjustments on sale).
2. Add widget tests for prescription flows and expiry tracker.
3. Integrate a basic audit log for controlled substances (if required by local regulation).
4. Add CI test jobs to ensure regressions are caught.

Notes:
- Use existing `AppTextStyles` and `AppColors.pharmacy` for consistent theme.
- Replace the simple `AppLocalizations` hook with `intl`/ARB for real translations when ready.

