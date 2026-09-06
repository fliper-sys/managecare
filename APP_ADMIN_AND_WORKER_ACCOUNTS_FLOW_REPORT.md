# App Admin And Worker Accounts Flow Report

## Purpose

This document describes the existing ManageCare app-admin, internal worker, business owner, and business worker account flows. It covers creation, login, routing, dashboards, worker screens, permissions, and backend endpoints currently used in the app.

This report documents what exists in the codebase. It does not expose sensitive credentials.

## Account Types

ManageCare currently has four main account categories:

- App admin
- Internal ManageCare worker
- Business owner
- Business worker or staff

Each account type has a different creation path, login path, dashboard, and permission scope.

## App Admin

### Purpose

The app admin account is for platform-level ManageCare administration. It is separate from business owners and business workers.

App admins manage:

- ManageCare dashboard overview
- Businesses
- Users and workers
- Subscription payments
- Restricted businesses
- Company expenses
- Internal ManageCare workers
- Internal work items
- Marketers
- Admin settings

### App Admin Login Screen

Screen:

- `lib/presentation/auth/screens/admin_login_screen.dart`

Route:

- `Routes.adminLogin`
- `/admin_login`

Behavior:

1. Admin enters admin email and password.
2. Screen checks fixed admin credentials.
3. If accepted, it signs in through Supabase to create a real authenticated session.
4. Admin is routed to the app admin dashboard.

Target route:

- `Routes.adminDashboard`
- `/admin/dashboard`

Important note:

- The screen contains a hardcoded credential gate. The actual credential values should not be copied into reports or shared documentation.
- The Supabase sign-in is required because app-admin data calls use `ManagecareApiClient`, which requires a bearer token.

### App Admin Dashboard

Screen:

- `lib/app_admin/app_admin_dashboard_screen.dart`

Main dashboard widget:

- `AdminDashboardApp`
- `DashboardHome`

Tabs/pages:

- Dashboard
- Business
- Payments
- Users
- Restricted
- Expenses
- Workers
- Work
- Marketers
- Settings

Page files:

- `lib/app_admin/pages/all_businesses_page.dart`
- `lib/app_admin/pages/admin_payments_page.dart`
- `lib/app_admin/pages/business_subscription_overview_page.dart`
- `lib/app_admin/pages/admin_restricted_businesses_page.dart`
- `lib/app_admin/pages/admin_expenses_page.dart`
- `lib/app_admin/pages/admin_workers_page.dart`
- `lib/app_admin/pages/admin_work_page.dart`
- `lib/app_admin/pages/marketers_page.dart`
- `lib/app_admin/pages/admin_notifications_page.dart`

### App Admin Backend Routes

Main backend route file:

- `server/managecare-backend/routes/admin.js`

Repository used by Flutter:

- `lib/data/repositories/admin_repository.dart`

Important app-admin endpoints include:

- `GET /api/admin/dashboard`
- `GET /api/admin/settings`
- `PUT /api/admin/settings`
- `PATCH /api/admin/businesses/:businessId`
- `POST /api/admin/businesses/:businessId/grant-subscription`
- `POST /api/admin/businesses/:businessId/decline-subscription`
- `POST /api/admin/businesses/:businessId/restriction`
- `GET /api/admin/payments`
- `GET /api/admin/subscription-requests`
- `POST /api/admin/subscription-requests/:requestId/approve`
- `POST /api/admin/subscription-requests/:requestId/decline`

## Internal ManageCare Workers

### Purpose

Internal ManageCare workers are platform team members, not business staff. They are created and managed by the app admin.

Examples of internal worker roles:

- Customer Support
- Programmer
- Tester
- Operations
- Admin

### Internal Worker Creation Screen

Screen:

- `lib/app_admin/pages/admin_workers_page.dart`

Section name:

- ManageCare Workers

Creation dialog fields:

- Full Name
- Email
- Phone
- Password
- Role
- Active status

Behavior:

1. App admin opens the Workers tab in the app admin dashboard.
2. Admin taps Worker.
3. Admin enters worker details.
4. If creating a worker and password is left blank, the app auto-generates a temporary password.
5. Worker record is saved through `AdminRepository.saveInternalWorker`.
6. If a temporary password is generated, it is shown once for sharing with the worker.

### Internal Worker Backend Routes

Backend file:

- `server/managecare-backend/routes/admin.js`

Endpoints:

- `GET /api/admin/internal-workers`
- `POST /api/admin/internal-workers`
- `PUT /api/admin/internal-workers/:id`
- `GET /api/admin/internal-workers/me`
- `PUT /api/admin/internal-workers/me/password`

Database table:

- `managecare_workers`

Stored fields include:

- name
- email
- phone
- role
- role_key
- is_active
- password_hash
- created_by
- updated_by
- created_at
- updated_at

### Internal Worker Login

Screen:

- `lib/presentation/marketer/marketer_login_screen.dart`

Route:

- `Routes.marketerLogin`
- `/marketer/login`

Behavior:

1. User enters email and password.
2. App first attempts marketer login.
3. If marketer login fails, it tries internal worker login through Supabase.
4. After Supabase sign-in, it fetches the internal worker profile.
5. If a matching internal worker record exists, user is routed to the internal worker dashboard.

Target route:

- `Routes.internalWorkerDashboard`
- `/internal-worker/dashboard`

### Internal Worker Dashboard

Screen:

- `lib/presentation/internal_worker/internal_worker_dashboard_screen.dart`

Features:

- Shows worker profile header.
- Shows assigned work items grouped by status.
- Allows worker to submit assigned pending work for review.
- Allows worker to change password.
- Allows logout.

Work item statuses:

- `pending`
- `review`
- `done`
- `returned`

Worker-facing backend endpoints:

- `GET /api/admin/internal-workers/me`
- `GET /api/admin/work-items/mine`
- `PATCH /api/admin/work-items/:id/worker-status`
- `PUT /api/admin/internal-workers/me/password`

Worker restriction:

- Internal workers can only fetch their own worker profile.
- Internal workers can only fetch work items assigned to their own worker id.
- Internal workers can only submit a pending work item for review.

## Business Owners

### Purpose

Business owners own and manage a business workspace. They create and manage business workers, subscriptions, inventory, sales, industry dashboards, reports, and settings.

### Owner Registration

Screen:

- `lib/presentation/auth/screens/register_screen.dart`

Route:

- `Routes.register`
- `/register`

Provider:

- `lib/providers/auth_provider.dart`
- `lib/providers/auth_provider_supabase.dart`

Service:

- `lib/services/authentication_service.dart`

Behavior:

1. Owner registers with email, password, full name, and phone number.
2. Owner account is created through Supabase auth.
3. Owner profile is created in backend/profile storage.
4. Owner continues into business setup and subscription flow.

### Owner Login

Screen:

- `lib/presentation/auth/screens/login_screen.dart`

Route:

- `Routes.login`
- `/login`

Owner login behavior:

1. User selects Owner sign in.
2. User enters email and password.
3. `AuthProvider.login` calls `AuthenticationService.authenticateUser`.
4. The app rejects non-owner users from owner login.
5. Owner subscription state is checked.
6. Owner is routed based on subscription/business state.

Possible owner destinations:

- `Routes.ownerDashboard`
- `Routes.subscriptionPayment`
- `/subscription-status`
- `Routes.restrictedBusiness`

Important owner rule:

- Worker accounts are rejected from owner login and must use Worker Sign In instead.

## Business Workers

### Purpose

Business workers are staff accounts created under a business. They are scoped to the business and do not have owner-level access.

Examples:

- pump_operator
- sales_rep
- cashier
- manager
- staff
- waiter
- chef
- pharmacist
- receptionist
- mechanic
- baker

Actual available roles depend on the business type.

### Business Worker Creation Screen

Screen:

- `lib/presentation/workers/screens/add_worker_screen.dart`

Route:

- `Routes.workersAdd`
- `/workers/add`

Related screens:

- `lib/presentation/workers/screens/workers_list_screen.dart`
- `lib/presentation/workers/screens/worker_details_screen.dart`
- `lib/presentation/workers/screens/worker_management_screen.dart`
- `lib/presentation/workers/screens/worker_leaderboard_screen.dart`
- `lib/presentation/workers/screens/attendance_screen.dart`
- `lib/presentation/workers/screens/payroll_screen.dart`

Creation fields include:

- Full name
- Email
- Phone
- Password
- Role or roles
- Permissions
- PIN
- Store assignment
- Commission percentage
- Pump assignment for fuel station workers

Fuel station roles:

- pump_operator
- sales_rep
- staff
- cashier
- manager

### Worker Creation Backend Routes

Backend route file:

- `server/managecare-backend/routes/workers.js`

Repository:

- `lib/data/repositories/worker_repository_impl.dart`
- `lib/data/repositories/worker_repository_supabase.dart`

Endpoints:

- `GET /api/workers/:businessId`
- `GET /api/workers/:businessId/:id`
- `POST /api/workers/:businessId`
- `PUT /api/workers/:businessId/:id`
- `DELETE /api/workers/:businessId/:id`

Create route:

- `POST /api/workers/:businessId`

Required:

- `full_name`
- `role`

Optional:

- email
- phone
- store_id
- permissions
- pin
- password

Update route:

- `PUT /api/workers/:businessId/:id`

Updatable:

- email
- full_name
- phone
- role
- store_id
- permissions
- pin
- is_active
- password
- commission_percentage

Important backend behavior:

- Worker routes are business-scoped.
- Listing workers requires business membership.
- Creating/updating/deleting workers requires business owner access.
- Updating worker role, permissions, active status, or store also syncs `business_members`.

### Worker Tables And Membership

Important tables:

- `workers`
- `profiles`
- `business_members`

Worker table stores:

- email
- full_name
- phone
- role
- business_id
- store_id
- permissions
- pin
- password_hash
- is_active
- commission_percentage

Membership table stores:

- user_id
- business_id
- role
- is_owner
- is_active
- permissions
- store_id

Important rule:

- `business_members` is what the app uses to resolve the worker's active business, role, and permissions during login/session composition.

## Business Worker Login

Screen:

- `lib/presentation/auth/screens/login_screen.dart`

Mode:

- Worker Sign In

Inputs:

- Worker ID field
- Password field

Current behavior:

- The Worker ID field is treated as the worker email.
- `AuthProvider.loginAsWorker` calls `AuthenticationService.authenticateWorkerByWorkerId`.
- The authentication service signs in the worker and resolves business membership.
- The app validates the owning business subscription.
- If valid, the worker is routed to the current business industry dashboard.

Important note:

- Code comments state that true short numeric worker IDs are not currently used for sign-in. The current worker login expects the worker email in the Worker ID field.

Possible worker destinations:

- Industry-specific dashboard for the worker's business
- `Routes.workerDashboard` fallback
- `Routes.restrictedBusiness` if business is restricted

## Worker Routing After Login

After a successful worker login:

1. App loads the worker business.
2. App determines industry route from the current business.
3. App routes the worker to that industry dashboard.
4. If no industry route is found, it falls back to `Routes.workerDashboard`.

Main router file:

- `lib/routes/app_router.dart`

Route constants:

- `lib/core/constants/routes.dart`

Main worker route:

- `Routes.workerDashboard`
- `/worker-dashboard`

Industry dashboards include:

- Gas/Petroleum dashboard
- Restaurant dashboard
- Salon dashboard
- Pharmacy dashboard
- Hotel dashboard
- Auto dashboard
- Apartment dashboard
- Retail dashboard
- Wholesale dashboard
- Agri dashboard
- Gym dashboard
- Real estate dashboard

## Worker Permissions

Permission utility:

- `lib/core/utils/worker_permissions.dart`

Role and permission helpers control screen access across the app.

Important helpers include:

- `canAccessReportsForUser`
- `canAccessAdvancedAnalyticsForUser`
- `canAccessProcurementForUser`
- `canAccessFuelStockForUser`
- `canAccessPumpConfigurationForUser`
- `canAccessExpensesForUser`
- `canManagePumpDisputes`
- `canManageStaffForUser`
- `canAttendanceForUser`
- `canAccessAdminScreenForUser`

Business workers may receive role-based permissions and explicit assigned permissions.

Important rule:

- Owners and full-access roles generally get broad access.
- Ordinary workers only get the screens allowed by their role or explicit permissions.

## Petroleum Worker Access Example

For petroleum businesses, the active business dashboard is:

- `lib/presentation/industry_specific/gas/screens/gas_dashboard_screen.dart`

Global petroleum access roles:

- owner
- admin
- sub_admin
- manager
- fuel_manager

Pump operator access:

- Pump sale where allowed
- Pump upload
- Pump upload history
- Pump upload status
- Reregister declined/faulty uploads

Restricted from pump operators:

- Global manager review
- Cash tracking
- Bank deposits
- Global station management unless explicitly granted by permissions

Manager/admin petroleum access:

- Upload review
- Fuel stock
- Pump configuration
- Procurement
- Expenses
- Bank deposits
- Cash tracking
- Reports

## Existing Worker Screens

### Workers List

File:

- `lib/presentation/workers/screens/workers_list_screen.dart`

Features:

- Lists workers for current business.
- Search field.
- Role filter for owners.
- Opens worker details.
- Owners can open worker management.

### Add Worker

File:

- `lib/presentation/workers/screens/add_worker_screen.dart`

Features:

- Creates a business worker.
- Selects role and permissions.
- Generates PIN.
- Supports business-type-specific roles.
- Supports pump assignment for fuel station workers.
- Supports store assignment.
- Supports invitation email behavior.

### Worker Details

File:

- `lib/presentation/workers/screens/worker_details_screen.dart`

Features:

- Loads selected worker profile.
- Shows worker sales metrics.
- Shows bakery assignment/resupply history where applicable.
- Provides worker activity details.

### Attendance

File:

- `lib/presentation/workers/screens/attendance_screen.dart`

Purpose:

- Worker attendance tracking.

### Payroll

File:

- `lib/presentation/workers/screens/payroll_screen.dart`

Purpose:

- Worker payroll tracking.

### Worker Sales

File:

- `lib/presentation/workers/screens/worker_sales_screen.dart`

Purpose:

- Worker sales reporting.

### Worker Inventory

File:

- `lib/presentation/workers/screens/worker_inventory_screen.dart`

Purpose:

- Worker inventory-related view.

## Authentication Services

Main auth provider:

- `lib/providers/auth_provider.dart`
- `lib/providers/auth_provider_supabase.dart`

Main auth service:

- `lib/services/authentication_service.dart`

Key methods:

- `login`
- `loginAsWorker`
- `register`
- `authenticateUser`
- `authenticateWorkerByWorkerId`
- `createWorkerUser`

Backend auth routes:

- `POST /auth/v1/signup`
- `POST /auth/v1/token`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /admin-api/workers`

Important auth behavior:

- Owner login only accepts owner accounts.
- Worker login resolves worker business membership.
- Worker access depends on business subscription status.
- Worker accounts are generally exempt from direct owner subscription payment requirements, but the owning business must be valid.

## Backend Security Model

Backend authorization is handled in Express middleware.

Important middleware files:

- `server/managecare-backend/middleware/auth.js`
- `server/managecare-backend/middleware/validation.js`

Important middleware:

- `authMiddleware`
- `requireBusinessMembership`
- `requireBusinessOwner`
- `requireFields`
- `pagination`
- `asyncHandler`

Important rule:

- The backend does not rely on database row-level security. Business access is enforced in Express middleware.

## Route Summary

### App Admin

- `/admin_login`
- `/admin/dashboard`
- `/admin/businesses`
- `/admin/users-and-workers`
- `/admin/payments`
- `/admin/payments-approval`
- `/admin/installation-requests`
- `/admin/subscriptions`
- `/admin/dunning`

### Internal Worker

- `/marketer/login`
- `/internal-worker/dashboard`

### Business Owner And Worker

- `/login`
- `/register`
- `/owner-dashboard`
- `/worker-dashboard`
- `/workers`
- `/workers/add`
- `/workers/details`
- `/workers/leaderboard`
- `/workers/attendance`
- `/workers/payroll`
- `/worker/sales`
- `/worker/inventory`

## Current Gaps And Notes

- The app-admin login screen currently uses a fixed credential check before Supabase sign-in. This should eventually be replaced with a database-backed admin role check.
- The worker login field is labeled Worker ID, but current authentication treats it as an email.
- Some worker screens still contain legacy Firestore compatibility logic while the backend has moved toward custom Express/Postgres and Supabase-compatible auth.
- Worker membership permissions should be kept synchronized between `workers` and `business_members`.
- Direct-route access should continue to be guarded on sensitive manager/admin screens, not only hidden from dashboard navigation.

## Recommended Future Improvements

1. Replace hardcoded app-admin credential gate with role-based backend authorization.
2. Add a true worker code or worker ID column if the app should support short worker ID login.
3. Continue migrating legacy Firestore worker reads to backend/Postgres endpoints.
4. Add audit history for worker permission changes.
5. Add owner-visible worker invitation status.
6. Add password reset or first-login password change for business workers.
7. Add clearer separation between internal ManageCare workers and business staff in route naming.
