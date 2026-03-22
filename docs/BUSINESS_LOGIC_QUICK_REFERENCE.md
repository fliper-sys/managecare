# Business Logic Quick Reference

## 🚀 Quick Start (5 Minutes)

### 1. Initialize in main.dart
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BusinessLogicRegistry().initialize();
  runApp(const MyApp());
}
```

### 2. Use in your provider
```dart
class MyProvider extends ChangeNotifier {
  final createOrderUseCase = CreateOrderUseCase();
  
  Future<void> createOrder() async {
    final order = await createOrderUseCase.call(params);
  }
}
```

### 3. Use in your screen
```dart
Consumer<MyProvider>(
  builder: (context, provider, _) {
    return ElevatedButton(
      onPressed: () => provider.createOrder(),
      child: Text('Create Order'),
    );
  },
);
```

---

## 📋 Use Cases at a Glance

### Inventory
```dart
// Check low stock
await CheckLowStockUseCase().call(businessId);

// Track expiry
await TrackExpiryUseCase().call(businessId);

// Manage stock
await ManageInventoryUseCase().call(ManageInventoryParams(...));

// Get inventory value
await CalculateInventoryValueUseCase().call(businessId);
```

### Sales & Orders
```dart
// Create order
await CreateOrderUseCase().call(CreateOrderParams(...));

// Apply pricing with discounts
await ApplyPricingUseCase().call(ApplyPricingParams(...));

// Manage loyalty program
await ManageLoyaltyProgramUseCase().call(ManageLoyaltyParams(...));

// Update order status
await UpdateOrderStatusUseCase().call(UpdateOrderStatusParams(...));

// Get order history
await GetOrderHistoryUseCase().call(GetOrderHistoryParams(...));

// Calculate fulfillment time
await CalculateFulfillmentTimeUseCase().call(CalculateFulfillmentParams(...));
```

### Staff & Payroll
```dart
// Manage schedule
await ManageStaffScheduleUseCase().call(ManageScheduleParams(...));

// Get availability
await GetStaffAvailabilityUseCase().call(GetAvailabilityParams(...));

// Calculate performance
await CalculatePerformanceUseCase().call(PerformanceParams(...));

// Generate payroll
await ManagePayrollUseCase().call(PayrollParams(...));
```

### Reports & Analytics
```dart
// Generate report
await GenerateReportUseCase().call(GenerateReportParams(...));

// Calculate financial metrics
await CalculateFinancialMetricsUseCase().call(businessId);

// Get KPI dashboard
await GetKPIDashboardUseCase().call(businessId);

// Export data
await ExportDataUseCase().call(ExportDataParams(...));
```

---

## 🏥 Pharmacy

### Check Drug Interactions
```dart
final logic = BusinessLogicRegistry().pharmacyLogic;
final interactions = await logic.checkDrugInteractions(['drug1', 'drug2']);

interactions.forEach((i) {
  print('${i.drug1Id} + ${i.drug2Id}: ${i.severity}');
  print(i.description);
});
```

### Track Expiring Medications
```dart
final expiring = await logic.getExpiringMedications(businessId, 30);

expiring.forEach((med) {
  print('${med.name} expires in ${med.daysUntilExpiry} days');
});
```

### Generate Report
```dart
final report = await logic.generatePrescriptionReport(
  businessId,
  DateTime(2025, 1, 1),
  DateTime(2025, 1, 31),
);

print('Revenue: ${report.totalRevenue}');
print('Prescriptions: ${report.totalPrescriptions}');
```

---

## 🍽️ Restaurant

### Get Queue Status
```dart
final logic = BusinessLogicRegistry().restaurantLogic;
final status = await logic.getCurrentQueueStatus(businessId);

print('Queue: ${status.totalInQueue}');
print('Wait time: ${status.estimatedWaitTimeMinutes} min');
```

### Get Recommendations
```dart
final items = await logic.getMenuRecommendations(businessId);

items.forEach((item) {
  print('${item.name} - Rating: ${item.rating}');
});
```

### Analyze Peak Hours
```dart
final analysis = await logic.analyzePeakHours(
  businessId,
  startDate,
  endDate,
);

print('Peak hours: ${analysis.peakHours.map((h) => h.hour).join(", ")}');
```

### Get Reservations
```dart
final reservations = await logic.getTableReservations(businessId, date);

reservations.forEach((res) {
  print('${res.guestName} - ${res.partySize} people');
});
```

---

## 💇 Salon

### Get Available Slots
```dart
final logic = BusinessLogicRegistry().salonLogic;
final slots = await logic.getAvailableTimeSlots(
  businessId,
  selectedDate,
  serviceId,
);

slots.forEach((slot) {
  print('${slot.time} - Available: ${slot.isAvailable}');
});
```

### Get Available Stylists
```dart
final stylists = await logic.getStylistAvailability(
  businessId,
  serviceId,
  date,
);

stylists.forEach((s) {
  print('${s.stylistName} - Rating: ${s.rating}');
});
```

### Calculate Price
```dart
final pricing = await logic.calculateAppointmentPrice(
  businessId,
  serviceId,
  customerId,
);

print('Base: ${pricing.basePrice}');
print('Discount: ${pricing.discount}');
print('Final: ${pricing.finalPrice}');
```

### Get Customer Profile
```dart
final profile = await logic.getCustomerProfile(businessId, customerId);

print('Visits: ${profile.visitCount}');
print('Total spent: ${profile.totalSpent}');
print('Preferred: ${profile.preferredServices}');
```

---

## 🏠 Real Estate

### Get Lease Status
```dart
final logic = BusinessLogicRegistry().realEstateLogic;
final status = await logic.getLeaseStatus(businessId, propertyId);

print('Status: ${status.status}');
print('Days until expiry: ${status.daysUntilExpiry}');
print('Monthly rent: ${status.monthlyRent}');
```

### Get Maintenance Requests
```dart
final requests = await logic.getMaintenanceRequests(businessId, propertyId);

requests.forEach((req) {
  print('${req.description} - Priority: ${req.priority}');
});
```

### Get Property Analytics
```dart
final analytics = await logic.getPropertyAnalytics(
  businessId,
  startDate,
  endDate,
);

print('Occupancy: ${analytics.occupancyRate}%');
print('Outstanding: ${analytics.outstandingPayments}');
```

### Get Payment History
```dart
final history = await logic.getTenantPaymentHistory(businessId, tenantId);

print('Total paid: ${history.totalPaid}');
print('Overdue: ${history.totalOverdue}');
print('Missed: ${history.missedPayments}');
```

---

## 📊 Common Metrics

### Calculate Revenue
```dart
final summary = BusinessMetricsCalculator.calculateRevenue(
  transactions,
  startDate,
  endDate,
);

print('Total: ${summary.totalRevenue}');
print('Transactions: ${summary.totalTransactions}');
print('Average: ${summary.averageTransactionValue}');
```

### Calculate Growth Rate
```dart
final growth = BusinessMetricsCalculator.calculateGrowthRate(10000, 8000);
print('Growth: ${growth.toStringAsFixed(1)}%');
```

### Get Business Health
```dart
final kpis = BusinessKPIs(...);
print('Health: ${kpis.getHealthStatus()}'); // Excellent, Good, Fair, Needs Attention

kpis.getInsights().forEach((insight) {
  print('• $insight');
});
```

---

## 🎯 Common Patterns

### Error Handling
```dart
try {
  final result = await useCase.call(params);
} catch (e) {
  print('Error: $e');
  // Show error to user
}
```

### Loading State
```dart
bool _isLoading = false;

Future<void> loadData() async {
  _isLoading = true;
  notifyListeners();
  
  try {
    final result = await useCase.call(params);
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

### Caching
```dart
Map<String, dynamic>? _cache;
DateTime? _cacheTime;

Future<dynamic> getCachedData() async {
  if (_cache != null && 
      DateTime.now().difference(_cacheTime!).inMinutes < 5) {
    return _cache;
  }
  
  _cache = await useCase.call(params);
  _cacheTime = DateTime.now();
  return _cache;
}
```

---

## 🔗 Integration Checklist

- [ ] Initialize BusinessLogicRegistry in main()
- [ ] Import use cases in your providers
- [ ] Add use cases to provider classes
- [ ] Call use cases from provider methods
- [ ] Wire up providers in screens
- [ ] Add error handling for all calls
- [ ] Test with real data
- [ ] Add loading indicators
- [ ] Show errors to users
- [ ] Monitor performance

---

## 📚 Learn More

- Full guide: `BUSINESS_LOGIC_GUIDE.md`
- Examples: `lib/providers/business_logic_integration_examples.dart`
- Summary: `BUSINESS_LOGIC_COMPLETE_SUMMARY.md`

---

## ✅ You're Ready!

All business logic is implemented, documented, and ready to use. Start integrating into your screens today!


