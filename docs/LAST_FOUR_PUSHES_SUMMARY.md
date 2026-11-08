# Work Summary: Last Four Pushes

This document summarizes the four latest commits on `origin/main` as of
2026-10-31. It is based on the pushed commit history, not on uncommitted local
changes.

## 1. Inventory schema and distributor pricing

**Commit:** `9cc1e80b`  
**Date:** 2026-10-30  
**Subject:** `feat: update database schema and enhance inventory handling with distributor discount`

- Improved distributor discount and pricing behavior in the inventory list.
- Preserved distributor pricing data through inventory repository updates and
  local cache storage.
- Updated the local inventory database schema/version to retain the discount
  field.
- Updated bakery resupply row mapping and workflow screen behavior.

## 2. Live logs, offline authentication, and application updates

**Commit:** `eee99cc6`  
**Date:** 2026-10-30  
**Subject:** `feat: add live logs screen and logging service enhancements`

- Added an owner-only live logs screen and enhanced device log capture,
  retention, and recovery notices.
- Added local authentication cache and local user reload/persistence support,
  with tests for user storage and auto-login behavior.
- Updated sign-in and startup flows, owner/admin dashboards, business/profile
  editing, and local/offline data handling.
- Added bakery resupply approval/history and spoilage workflows in the client
  and backend, with migration 077.
- Added or updated backend migrations for owner membership RLS, administrative
  finance payment methods, and business tax IDs (migrations 073–076).
- Updated administrative task handling, backend routes, Android installer
  configuration, and app version to `2.0.111`.

## 3. Legacy authentication and account recovery

**Commit:** `a4108960`  
**Date:** 2026-10-20  
**Subject:** `feat: Implement legacy authentication migration and related functionalities`

- Added backend and database support for linking verified legacy identities to
  current accounts and business memberships.
- Added profile lookup/contact fields, current-business selection, password
  reset tokens, and legacy authentication compatibility endpoints.
- Updated Flutter authentication, profile, business, and subscription flows to
  use the newer Supabase-backed behavior.
- Added migration, reconciliation, and worker-profile rebuild scripts, plus
  authentication migration tests.
- Updated deployment configuration for the backend and web hosting.

## 4. Administrative dashboard appearance settings

**Commit:** `d368c2ab`  
**Date:** `2026-10-16`  
**Subject:** `feat: add theme toggle functionality to administrative dashboard and owner dashboard`

- Added light/dark theme controls to the administrative dashboard and owner
  dashboard.
- Integrated the shared theme provider and updated dashboard screens to reflect
  the selected appearance consistently.

## Production deployment follow-up

After these commits, production was checked and updated on 2026-10-31:

- Applied migrations 076 and 077 transactionally after taking a database
  backup.
- Deployed the updated inventory and administrative routes and synchronized
  the Prisma schema.
- Confirmed `admin.js` and `server.js` already matched the pushed versions.
- The backend service remained active; the health endpoint reported the
  database connected, and recent service error logs were empty at verification.
- The broad `schema.sql` bootstrap file was not replayed against production.

The deployment checks confirmed service startup, health, and route protection;
they did not exercise authenticated end-to-end business workflows.
