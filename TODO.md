# TODO - Fix Supabase Realtime unhandled exceptions

## Problem
`RealtimeSubscribeException(status: channelError, details: RealtimeCloseEvent(code: 1006))` and
`JwtSignatureError: Failed to validate JWT signature` unhandled exceptions come from the genuine
Supabase Realtime `.stream()` subscription on the `profiles` table in
`lib/providers/auth_provider_supabase.dart` (`_subscribeToProfile`). The self-hosted backend
(`backend.managecare.info`) does not implement the Supabase Realtime protocol correctly.

## Plan
Replace the realtime profile subscription with a polling Timer (15s), matching the pattern already
used by `ReportsProvider` and `InventoryRepositorySupabase`.

## Steps
- [x] 1. Create TODO.md
- [x] 2. Replace `StreamSubscription? _profileSubscription` field with `Timer? _profilePollTimer` + poll interval constant
- [x] 3. Rewrite `_subscribeToProfile()` to poll `resolveUserAccess()` on a 15s timer (preserving changed-logic, wrapped in try/catch)
- [x] 4. Update cleanup call sites to cancel the timer: `logout()`, `_rejectWorkerFromOwnerLogin()`, `_rejectWorkerDueToBusinessSubscription()`, `_rejectWorkerDueToOwnerRestriction()`, `dispose()`
- [x] 5. Verified: no remaining `_profileSubscription` references (all replaced with `_profilePollTimer`)

