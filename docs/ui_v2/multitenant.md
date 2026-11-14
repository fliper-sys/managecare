# Multi-tenant, multi-business (v2)

One user can own several businesses of different types. Each business has its
own data, plan, accent and UI. v2 treats this as a first-class rule.

## Rules
1. Every business screen is built inside a `TenantScope(tenantId)`. A switch
   changes the id, so cart, filters, search text and dismissed rows of the old
   business are gone. Nothing per-business may live outside the scope.
2. UI is chosen per business, not per user: `resolveProfile(business)` gives
   `v2`, `legacy`, `planExpired` or `unknownType`. A user can have a retail
   business on v2 and a salon on the old screens at the same time.
3. State comes from the existing `BusinessProvider` through one adapter
   (`provider_adapter.dart`). The provider is not changed.

## Session phases (`SessionPhase`)
| Phase | When | Screen |
|---|---|---|
| loadingList | first load, or businesses known but none selected | skeleton |
| noBusinesses | list loaded and empty | empty state, Add a business |
| switching | `isSwitchingBusiness` and a pending id | skeleton with target name and accent |
| ready | selected business exists | gate by profile state |
| error | failed and nothing cached | message, Try again |

Cached data with an error stays `ready`; the switcher shows an offline banner
(`usingCache`).

## Profile states (`ProfileState`)
| State | Rule | Screen |
|---|---|---|
| v2 | migrated profile and flag on | v2 screens |
| legacy | not migrated, or flag off | old screens, unchanged |
| planExpired | plan inactive or past end date (checked first) | recovery screen, keeps accent |
| unknownType | empty business type | pick-a-type screen |

## Switcher
`showBusinessSwitcher` opens the sheet: monogram in the business accent,
name, type label, chips (Current, Plan expired, Set type). Current row is
inert. While a switch runs every other row is dimmed and locked and the target
row shows a spinner. Selecting closes the sheet at once and the shell shows
the switching skeleton.

## Files
`lib/shared_features/session/`: `business_session.dart`, `tenant_scope.dart`,
`business_switcher_sheet.dart`, `session_gate.dart`, `provider_adapter.dart`,
`session.dart`. Tests: `test/ui_v2/session_test.dart`.

## Not done yet
- Wiring `SessionGate` into the router (needs approval to touch `app_router.dart`).
- Expired-plan and unknown-type screens (builders are passed in; stubs only).
- Business-picker at sign-in (`business_selection_screen.dart`) still old.
- Not compiled or run. Run `flutter analyze` and `flutter test test/ui_v2`.
