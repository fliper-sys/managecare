# Business Selection & Current Business

This document explains how Manage Care manages multiple businesses per user, how the current/preferred business is persisted, and best-practices for UI switcher integration.

- **User fields**
  - `businessId` (String): For workers, this is the single business they belong to. AuthProvider ensures this is set for workers on login.
  - `preferredBusinessId` (String, optional): Owner's preferred/current business. Used to restore work context across devices.

- **Local cache**
  - `LocalBusinessStorage` caches `currentBusinessId` and business details for fast startup and offline use.
  - `BusinessProvider` will attempt to restore cache if Firebase fails.

- **Bootstrapping behavior**
  - On owner login: `OwnerDashboard` reads `authProvider.currentUser?.preferredBusinessId` and calls `BusinessProvider.loadUserBusinesses(userId, preferredBusinessId: preferredBusinessId)`.
  - On worker login: `AuthProvider` ensures `businessId` exists on the user document and caches the business for quick startup.

- **Switching behavior**
  - Owner: use `BusinessProvider.setCurrentBusinessAndSave(userId, business)` to set current and persist `preferredBusinessId` to the user doc and local cache.
  - Worker: use `BusinessProvider.setCurrentBusiness(business)` to set current business locally (worker `businessId` should already be set on their user doc).

- **UI integration**
  - Use `BusinessSwitcher` (lib/widgets/business_switcher.dart) in headers or AppBar actions. It lists user businesses and calls the appropriate provider methods when switching.
  - Owner flows typically save preference on switch so next login resumes the same business.

- **Recommendations**
  - Call `setCurrentBusinessAndSave` after creating a new business so the owner immediately operates in the new business (BusinessDetailsScreen now does this).
  - Add `BusinessSwitcher` to prominent app headers for quick switching.
  - Add tests that assert owner bootstrapping restores preferred business and worker login sets business from worker doc.

- **Troubleshooting**
  - If users see "No business selected", check console logs for `[BusinessProvider]` and `[OwnerDashboard]` messages indicating cached vs loaded state.
  - Ensure `LocalBusinessStorage` was initialized (AuthProvider and BusinessProvider both attempt init).

This document should be referenced when changing business-selection flows or adding a global header switcher.

