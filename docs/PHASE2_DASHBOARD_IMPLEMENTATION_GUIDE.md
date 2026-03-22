# 🚀 NEXT PHASE: DASHBOARD IMPLEMENTATION GUIDE
**Status**: Ready to implement  
**Priority**: Critical path  
**Estimated Time**: 2-3 hours for completion

---

## 📋 DASHBOARD WIRING PLAN

### Overview
All business dashboards need to be wired to:
1. Connect to real provider data
2. Display actual metrics (not placeholder values)
3. Navigate to correct screens
4. Show sync status
5. Display notifications

---

## 🎯 OWNER DASHBOARD - STARTING POINT

**File**: `lib/presentation/dashboard/owner/owner_dashboard_screen.dart`

### Current Issues
- Shows placeholder data
- Navigation may not work to all screens
- Real-time metrics not updating
- Business selection needs proper wiring

### Steps to Fix (In Order)

#### Step 1: Connect Business Provider
```dart
// Already done - check currentBusiness is passed correctly
final business = businessProvider.currentBusiness;
```

#### Step 2: Get Industry-Specific Data
```dart
// Route to correct dashboard based on businessType
switch(business.businessType.toLowerCase()) {
  case 'pharmacy':
    return const PharmacyDashboard();
  case 'retail':
    return const RetailDashboard();
  // etc...
}
```

#### Step 3: Display Real Metrics
Need to calculate:
- Today's revenue: Sum of today's sales
- Total customers: Count from customer list
- Active orders: Count pending orders
- Pending payments: Count unpaid invoices

#### Step 4: Navigation Buttons
Verify all onTap handlers route to correct screens:
- Sales → `SalesScreen`
- Inventory → `InventoryListScreen`
- Customers → `CustomerListScreen`
- Reports → `ReportsDashboardScreen`
- Settings → `SettingsScreen`

---

## 🏥 PHARMACY DASHBOARD

**File**: `lib/presentation/industry_specific/pharmacy/screens/pharmacy_dashboard.dart`

### Metrics to Display
1. **Total Prescriptions** - Count all prescriptions
2. **Dispensed Today** - Filter by today and status='dispensed'
3. **Patients** - Count unique patients
4. **Low Stock Drugs** - Filter drugs with stock < 10
5. **Expiring Soon** - Filter drugs expiring < 30 days
6. **Revenue** - Sum of dispensed prescriptions
7. **Controlled Drugs Alert** - Count controlled drugs

### Navigation
- Prescriptions button → `PrescriptionScreen`
- Drugs button → `DrugInventoryScreen`
- Patients button → `PatientRecordsScreen`
- Expiry button → `ExpiryTrackerScreen`

---

## 🛒 RETAIL DASHBOARD

**File**: `lib/presentation/industry_specific/retail/screens/retail_dashboard.dart`

### Metrics to Display
1. **Sales Today** - Sum cartTotal from today
2. **Items Sold** - Sum cartCount from today
3. **Low Stock Items** - Products with stock < 20
4. **Total Inventory Value** - Sum(price * stock)
5. **Active Orders** - Count pending orders
6. **Revenue** - Total sales today

### Navigation
- POS button → `POSScreen`
- Inventory → `ProductCatalogScreen`
- Suppliers → `SupplierManagementScreen`
- Reports → Analytics

---

## 🍽️ RESTAURANT DASHBOARD

**File**: `lib/presentation/industry_specific/restaurant/screens/restaurant_dashboard_screen.dart`

### Metrics to Display
1. **Orders Today** - Count orders created today
2. **Pending Orders** - Count orders with status='pending'
3. **Revenue** - Sum of completed orders
4. **Average Order Value** - Total / Count
5. **Menu Items** - Count available items
6. **Reservations** - Count bookings for today

### Navigation
- Orders → `OrdersScreen`
- Menu → `MenuScreen`
- Reservations → `ReservationsScreen`
- Kitchen → `KitchenScreen`

---

## 🏨 HOTEL DASHBOARD

**File**: `lib/presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart`

### Metrics to Display
1. **Occupied Rooms** - Count rooms with status='occupied'
2. **Available Rooms** - Count rooms with status='available'
3. **Check-ins Today** - Count bookings with today's date
4. **Revenue** - Sum from bookings
5. **Occupancy Rate** - (Occupied / Total) * 100
6. **Average Stay** - Avg(checkout_date - checkin_date)

### Navigation
- Rooms → `RoomListScreen`
- Bookings → `BookingsScreen`
- Check-in → `FrontDeskScreen`
- Services → `ServicesScreen`

---

## 💇 SALON DASHBOARD

**File**: `lib/presentation/industry_specific/salon/screens/salon_dashboard_screen.dart`

### Metrics to Display
1. **Appointments Today** - Count appointments for today
2. **Revenue** - Sum of completed appointments
3. **Available Stylists** - Count stylists available now
4. **Services Offered** - Count available services
5. **Average Service Cost** - Avg(price)
6. **Customer Satisfaction** - Avg rating

### Navigation
- Appointments → `AppointmentsScreen`
- Services → `ServicesCatalogScreen`
- Staff → `StaffManagementScreen`

---

## 🏋️ GYM DASHBOARD

**File**: `lib/presentation/industry_specific/gym/screens/gym_dashboard_screen.dart`

### Metrics to Display
1. **Active Members** - Count members with valid membership
2. **Memberships Expiring** - Count expiring < 7 days
3. **Revenue** - Sum from active memberships
4. **Classes Today** - Count scheduled classes
5. **Attendance Rate** - (Attended / Registered) * 100
6. **New Members** - Count joined this month

### Navigation
- Members → `MembershipsScreen`
- Classes → `ClassScheduleScreen`
- Trainers → `TrainerManagementScreen`

---

## 🚗 AUTO REPAIR DASHBOARD

**File**: `lib/presentation/industry_specific/auto/screens/auto_dashboard_screen.dart`

### Metrics to Display
1. **Active Jobs** - Count jobs with status='active'
2. **Completed This Month** - Count completed jobs
3. **Revenue** - Sum from completed jobs
4. **Parts Inventory** - Count available parts
5. **Low Stock Parts** - Count parts < 5
6. **Average Job Duration** - Avg time to complete

### Navigation
- Jobs → `RepairJobsScreen`
- Parts → `PartsInventoryScreen`
- Bookings → `BookingsScreen`
- Invoices → `InvoicesScreen`

---

## 🌾 AGRICULTURE DASHBOARD

**File**: `lib/presentation/industry_specific/agri/screens/agri_dashboard_screen.dart`

### Metrics to Display
1. **Active Farms** - Count farms
2. **Crops in Progress** - Count crops with status='growing'
3. **Farm Inputs** - Count available inputs
4. **Recent Harvests** - Count harvested this month
5. **Total Acreage** - Sum(farm_size)
6. **Weather Alerts** - Display current weather hints

### Navigation
- Farms → `FarmInventoryScreen`
- Crops → `CropOrdersScreen`
- Inputs → Inventory screen

---

## 🍺 DRINK/BAR DASHBOARD

**File**: `lib/presentation/industry_specific/drink/screens/drink_dashboard_screen.dart`

### Metrics to Display
1. **Bottles in Stock** - Sum of inventory
2. **Low Stock Bottles** - Count < threshold
3. **Revenue** - Sum from sales
4. **Orders Today** - Count orders
5. **Distribution Orders** - Count pending distribution
6. **Brewing Batches** - Count active batches

### Navigation
- Inventory → `InventoryScreen`
- Bottles → `BottleTrackingScreen`
- Logs → `BrewingLogsScreen`
- Distribution → `DistributionOrdersScreen`

---

## 🏠 REAL ESTATE DASHBOARD

**File**: `lib/presentation/industry_specific/realestate/screens/realestate_dashboard_screen.dart`

### Metrics to Display
1. **Total Properties** - Count all properties
2. **Available Properties** - Count with status='available'
3. **Occupied Properties** - Count with tenants
4. **Monthly Rent** - Sum from all leases
5. **Pending Payments** - Count unpaid rent
6. **Total Tenants** - Count active leases

### Navigation
- Properties → `ListingsScreen`
- Tenants → `TenantManagementScreen`
- Leases → `LeaseManagementScreen`
- Payments → `RentCollectionScreen`

---

## 🔄 IMPLEMENTATION SEQUENCE

### Phase 2A: Core Dashboards (1 hour)
1. Owner Dashboard - Route to correct industry dashboard
2. Pharmacy Dashboard - Connect to pharmacy provider
3. Retail Dashboard - Connect to retail provider

### Phase 2B: Additional Dashboards (1 hour)
4. Restaurant Dashboard
5. Hotel Dashboard
6. Salon Dashboard

### Phase 2C: Remaining Dashboards (1 hour)
7. Gym, Auto, Agriculture, Drink, Real Estate

### Phase 2D: Testing (30 min)
- Test all dashboard transitions
- Verify metrics update correctly
- Test notification integration
- Check offline mode

---

## 🔧 COMMON PATTERNS

### Getting Today's Data
```dart
final today = DateTime.now();
final startOfDay = DateTime(today.year, today.month, today.day);
// Filter data where date >= startOfDay
```

### Calculating Metrics
```dart
// Revenue
double revenue = items.fold(0, (sum, item) => sum + item.amount);

// Count
int count = items.length;

// Average
double average = items.isEmpty ? 0 : sum / items.length;

// Percentage
double percentage = (numerator / denominator) * 100;
```

### Connecting Provider
```dart
final myProvider = context.watch<MyProvider>();
// Use myProvider.data, myProvider.isLoading, etc.
```

---

## 📝 CHECKLIST FOR EACH DASHBOARD

Before marking dashboard complete:

- [ ] All metrics calculate correctly
- [ ] Navigation buttons work
- [ ] Shows real data (not placeholder)
- [ ] Updates on provider change
- [ ] Notification badges show if applicable
- [ ] Responsive on different screen sizes
- [ ] Error handling for empty states
- [ ] Sync status visible

---

## 🎯 SUCCESS CRITERIA

Dashboard implementation is complete when:

✅ All 10 industry dashboards implemented
✅ All metrics displaying correctly
✅ All navigation working
✅ Notifications appearing on events
✅ No compilation errors
✅ Offline mode functioning
✅ Data persists correctly
✅ App is fully functional

---

**Next Action**: Start with Owner Dashboard → select industry → show industry dashboard


