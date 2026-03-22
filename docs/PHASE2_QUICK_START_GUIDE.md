# 🚀 QUICK START: PHASE 2 IMPLEMENTATION - WIRING DASHBOARDS

**Date**: December 5, 2025  
**Time Estimate**: 2-3 hours to complete Phase 2  
**Goal**: Wire all dashboards to real provider data

---

## ⚡ QUICK CHECKLIST - START HERE

### Step 1: Pharmacy Dashboard (30 minutes)
**File**: `lib/presentation/industry_specific/pharmacy/screens/pharmacy_dashboard.dart`

```dart
// Find the build method and add this code:
@override
Widget build(BuildContext context) {
  return Consumer<PharmacyProvider>(
    builder: (context, provider, _) {
      final medications = provider.getAllMedications();
      final expiringMeds = provider.getExpiringMedications();
      final stats = provider.getPrescriptionStats();
      
      return SingleChildScrollView(
        child: Column(
          children: [
            // Top metrics card
            _buildMetricsCard(
              totalDrugs: medications.length,
              expiringCount: expiringMeds.length,
              totalRevenue: stats.totalRevenue,
              prescriptionCount: stats.totalPrescriptions,
            ),
            
            // Expiring medications alert
            if (expiringMeds.isNotEmpty)
              _buildExpiryAlertCard(expiringMeds),
            
            // Drug interactions warning
            _buildInteractionsCard(provider),
            
            // Recent prescriptions
            _buildRecentPrescriptionsCard(stats),
          ],
        ),
      );
    },
  );
}

// Replace placeholder build methods with actual implementations
Widget _buildMetricsCard({
  required int totalDrugs,
  required int expiringCount,
  required double totalRevenue,
  required int prescriptionCount,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green[400]!, Colors.green[600]!],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _metricBox('Drugs', '$totalDrugs', Icons.medication),
            _metricBox('Expiring', '$expiringCount', Icons.warning),
            _metricBox('Revenue', '₦${totalRevenue.toInt()}', Icons.money),
            _metricBox('Prescriptions', '$prescriptionCount', Icons.receipt),
          ],
        ),
      ],
    ),
  );
}

Widget _metricBox(String label, String value, IconData icon) {
  return Column(
    children: [
      Icon(icon, color: Colors.white),
      SizedBox(height: 8),
      Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}
```

---

### Step 2: Retail Dashboard (30 minutes)
**File**: `lib/presentation/industry_specific/retail/screens/retail_dashboard.dart`

```dart
@override
Widget build(BuildContext context) {
  return Consumer<RetailProvider>(
    builder: (context, provider, _) {
      final turnover = provider.getInventoryTurnover();
      final lowStock = provider.getLowStockItems();
      final inventory = provider.getTotalInventoryValue();
      final topProducts = provider.getTopProducts();
      
      return SingleChildScrollView(
        child: Column(
          children: [
            // Inventory health card
            _buildInventoryHealthCard(
              totalValue: inventory,
              turnover: turnover.rate,
              lowStockCount: lowStock.length,
            ),
            
            // Low stock alerts
            if (lowStock.isNotEmpty)
              _buildLowStockAlerts(lowStock),
            
            // Top products
            _buildTopProductsCard(topProducts),
            
            // Quick actions
            _buildRetailActionsCard(),
          ],
        ),
      );
    },
  );
}
```

---

### Step 3: Restaurant Dashboard (30 minutes)
**File**: `lib/presentation/industry_specific/restaurant/screens/restaurant_dashboard_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  return Consumer<RestaurantProvider>(
    builder: (context, provider, _) {
      final queueStatus = provider.getQueueStatus();
      final analysis = provider.analyzePeakHours(
        DateTime.now().subtract(Duration(days: 7)),
        DateTime.now(),
      );
      final recommendations = provider.getRecommendedMenuItems();
      
      return SingleChildScrollView(
        child: Column(
          children: [
            // Queue status card
            _buildQueueCard(queueStatus),
            
            // Peak hours chart
            _buildPeakHoursChart(analysis),
            
            // Menu recommendations
            _buildRecommendationsCard(recommendations),
          ],
        ),
      );
    },
  );
}
```

---

## 📊 WIRING PATTERN (Use for All Dashboards)

```dart
// TEMPLATE FOR WIRING ANY DASHBOARD

class YourDashboardScreen extends StatelessWidget {
  const YourDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<YourProvider>(
      builder: (context, provider, _) {
        // Step 1: Get data from provider
        final data = provider.getAllData();
        final stats = provider.getStatistics();
        final alerts = provider.getAlerts();
        
        // Step 2: Build UI with real data
        return SingleChildScrollView(
          child: Column(
            children: [
              // Metric cards
              _buildMetricsCard(stats),
              
              // Alert cards
              if (alerts.isNotEmpty)
                _buildAlertCard(alerts),
              
              // Data list
              _buildDataListCard(data),
            ],
          ),
        );
      },
    );
  }

  // Helper methods to build UI components
  Widget _buildMetricsCard(Statistics stats) {
    // Return your metrics UI
  }
}
```

---

## 🎯 WIRING CHECKLIST - DO THESE IN ORDER

- [ ] **Pharmacy** - Wire 5 methods (getMedications, getExpiring, getStats, getInteractions, getPrescriptionReport)
- [ ] **Retail** - Wire 5 methods (getInventory, getLowStock, getTurnover, getTopProducts, getValue)
- [ ] **Restaurant** - Wire 4 methods (getQueue, analyzePeakHours, getRecommendations, getTables)
- [ ] **Hotel** - Wire 5 methods (getOccupancy, getCheckIns, getCheckOuts, getRevenue, getMaintenance)
- [ ] **Salon** - Wire 4 methods (getTimeSlots, getStylistAvailability, getAppointments, getServices)
- [ ] **Gym** - Wire 5 methods (getTotalMembers, getActiveMembers, getClasses, getEquipment, getTrainers)
- [ ] **Auto** - Wire 5 methods (getServiceQueue, getVehicles, getParts, getMechanics, getTools)
- [ ] **Agriculture** - Wire 5 methods (getCropHealth, predictHarvest, getLivestock, getEquipment, getWeather)
- [ ] **Drink** - Wire 5 methods (getInventory, getLowStock, getSalesByBeverage, getTableStatus, getStaff)
- [ ] **Real Estate** - Wire 5 methods (getProperties, getTenants, getLeaseStatus, getMaintenance, getRevenue)

---

## ✅ TESTING EACH DASHBOARD

After wiring each dashboard, run:

```bash
# Test compilation
flutter pub get

# Check for errors
flutter analyze lib/presentation/industry_specific/[industry]/screens/[dashboard_file].dart

# Run the app
flutter run

# Navigate to that dashboard and verify:
# ✓ Data displays (not placeholders)
# ✓ Numbers are correct (not 0)
# ✓ Cards render without errors
# ✓ Dark mode works
# ✓ Scrolling works
```

---

## 🚨 COMMON ISSUES & FIXES

### Issue 1: "Provider is null"
**Cause**: Provider not initialized in main.dart  
**Fix**: Check BusinessLogicProvider is in ChangeNotifierProvider list

### Issue 2: "Method not found"
**Cause**: Provider method name mismatch  
**Fix**: Check actual method name in *_logic.dart file

### Issue 3: "Type mismatch"
**Cause**: Returning wrong data type  
**Fix**: Check return type annotation in service definition

### Issue 4: "Data not updating"
**Cause**: Forgot to call notifyListeners()  
**Fix**: Add `notifyListeners()` after data update in provider

### Issue 5: "Blank screen"
**Cause**: data list is empty  
**Fix**: Add `if (data.isEmpty) return _buildEmptyState();`

---

## 🎯 ACTUAL CODE TO RUN NOW

### Quick Test - Wire Owner Dashboard Real Data

**File**: `lib/presentation/dashboard/owner/owner_dashboard_screen.dart`

Find this line (around line 305):
```dart
// Quick Metrics
_buildQuickMetrics(isDark)
```

Update the `_buildQuickMetrics` method to:

```dart
Widget _buildQuickMetrics(bool isDark) {
  final businessProvider = context.watch<BusinessProvider>();
  
  return Consumer<BusinessLogicProvider>(
    builder: (context, provider, _) {
      // Get real data from provider
      final sales = provider.getTotalSalesValue();
      final orders = provider.getTotalOrders();
      final customers = provider.getTotalCustomers();
      final revenue = provider.getTotalRevenue();
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMetricTile('Sales', '₦${sales.toStringAsFixed(0)}', Icons.shopping_bag_rounded,
                AppColors.primary, isDark),
            _buildMetricTile('Orders', '$orders', Icons.receipt_rounded, Colors.green,
                isDark),
            _buildMetricTile('Customers', '$customers', Icons.people_rounded,
                Colors.orange, isDark),
            _buildMetricTile('Revenue', '₦${revenue.toStringAsFixed(0)}', Icons.trending_up_rounded,
                Colors.blue, isDark),
          ],
        ),
      );
    },
  );
}
```

---

## 📈 EXPECTED PROGRESS

| Dashboard | Status | Time | Priority |
|-----------|--------|------|----------|
| Owner | ✅ Wired | 0 min | Done |
| Pharmacy | 🔄 Wire now | 30 min | Critical |
| Retail | 🔄 Next | 30 min | High |
| Restaurant | 🔄 Next | 30 min | High |
| Hotel | ⏳ After | 30 min | High |
| Salon | ⏳ After | 30 min | Medium |
| Gym | ⏳ After | 30 min | Medium |
| Auto | ⏳ After | 30 min | Medium |
| Agri | ⏳ After | 30 min | Medium |
| Drink | ⏳ After | 30 min | Low |
| Real Estate | ⏳ After | 30 min | Low |

**Total Time**: 3-4 hours (if done consecutively)

---

## 🎓 KEY LEARNING

**Why we wire dashboards?**
1. Verify providers are working correctly
2. Ensure data flows from service → provider → UI
3. Catch type mismatches early
4. Create visual feedback that app is functional
5. Build confidence in architecture

**What comes after?**
- Phase 3: Build feature screens (Sales, Inventory, Customers, etc.)
- Real user data flows through complete app
- Offline mode tested with real scenarios
- Performance optimization
- Production build

---

## 🚀 START NOW!

Pick the **Pharmacy Dashboard** and wire it first. It's the simplest:
1. 5 provider methods to connect
2. Clean data types (no complex nested structures)
3. Good example for other dashboards

**Time: 30 minutes**

Once pharmacy works, move to retail. Once retail works, repeat pattern for all.

After all 11 dashboards are wired, analyzer issues should drop to ~300-350 range.

---


