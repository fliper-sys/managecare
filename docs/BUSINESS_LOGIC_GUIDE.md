# Manage Care - Business Logic Implementation Guide

## Overview

The Manage Care application now includes comprehensive business logic tailored to each industry type. This document outlines all implemented business logic and how to use it in your application.

## 📋 Table of Contents

1. [Use Cases (Domain Layer)](#use-cases-domain-layer)
2. [Industry-Specific Business Logic](#industry-specific-business-logic)
3. [Common Business Metrics](#common-business-metrics)
4. [Integration Guide](#integration-guide)
5. [Examples](#examples)

---

## Use Cases (Domain Layer)

All use cases are located in `lib/domain/usecases/` and follow clean architecture principles.

### Inventory Management

**File**: `lib/domain/usecases/inventory/manage_inventory.dart`

#### ManageInventoryUseCase
Manages stock level changes with reasons tracking.

```dart
// Parameters
ManageInventoryParams(
  businessId: 'business_123',
  itemId: 'item_456',
  quantityChange: 10, // positive for add, negative for remove
  reason: 'purchase', // purchase, sale, adjustment, damage, expiry
  notes: 'Initial stock',
)
```

#### CheckLowStockUseCase
Triggers alerts when inventory falls below reorder points.

```dart
// Returns low stock items for immediate reordering
List<LowStockAlert> alerts = await checkLowStockUseCase.call(businessId);
```

#### TrackExpiryUseCase
Monitors product expiry dates (critical for pharmacy, food, etc.)

```dart
// Returns items organized by severity
List<ExpiryAlert> expiryItems = await trackExpiryUseCase.call(businessId);
```

#### CalculateInventoryValueUseCase
Calculates total inventory asset value and category breakdowns.

```dart
InventoryValuation valuation = await calculateInventoryValueUseCase.call(businessId);
// Access: valuation.totalValue, valuation.categoryValues
```

---

### Pricing & Discounts

**File**: `lib/domain/usecases/sales/apply_pricing.dart`

#### ApplyPricingUseCase
Dynamically calculates prices with discounts, tax, and loyalty points.

```dart
// Parameters
ApplyPricingParams(
  businessId: 'business_123',
  customerId: 'customer_456',
  items: [
    CartItem(itemId: 'item1', quantity: 2, basePrice: 100),
    CartItem(itemId: 'item2', quantity: 1, basePrice: 50),
  ],
  couponCode: 'SAVE20',
  loyaltyTier: 'gold',
)

// Result includes: subtotal, discounts, taxes, total, loyalty points earned
```

**Discount Types Supported**:
- Percentage-based discounts
- Fixed amount discounts
- Tiered bulk discounts
- Loyalty program discounts
- Seasonal/promotional discounts

---

### Customer Loyalty Program

**File**: `lib/domain/usecases/sales/manage_loyalty.dart`

#### ManageLoyaltyProgramUseCase
Enrolls customers and manages loyalty points.

```dart
// Operations: enroll, addPoints, redeemPoints, upgrade
ManageLoyaltyParams(
  businessId: 'business_123',
  customerId: 'customer_456',
  operation: 'addPoints',
  amount: 100,
)
```

#### GetAvailableRewardsUseCase
Shows rewards customer can redeem with current points.

```dart
List<AvailableReward> rewards = await getRewardsUseCase.call(
  GetRewardsParams(
    businessId: 'business_123',
    currentPoints: 500,
  ),
);
```

#### GetCustomerProfileUseCase
Retrieves complete customer engagement history.

```dart
CustomerProfile profile = await getCustomerProfileUseCase.call(customerId);
// Includes: visit count, total spent, favorite categories, loyalty status
```

---

### Financial Reporting

**File**: `lib/domain/usecases/subscription/generate_reports.dart`

#### GenerateReportUseCase
Creates comprehensive business reports with analytics.

```dart
// Report types: sales, inventory, financial, customer, performance
GenerateReportParams(
  businessId: 'business_123',
  reportType: 'sales',
  startDate: DateTime(2025, 1, 1),
  endDate: DateTime(2025, 1, 31),
  groupBy: 'daily', // daily, weekly, monthly, category
)
```

#### CalculateFinancialMetricsUseCase
Computes key financial indicators.

```dart
FinancialMetrics metrics = await calculateFinancialMetricsUseCase.call(businessId);
// Includes: ROI, profit margin, average order value, etc.
```

#### GetKPIDashboardUseCase
Provides real-time KPI dashboard data.

```dart
KPIDashboard kpi = await getKPIDashboardUseCase.call(businessId);
// Includes: revenue, transaction count, conversion rate, growth percentage
```

#### ExportDataUseCase
Exports data for external analysis.

```dart
// Formats: csv, excel, json, pdf
String filePath = await exportDataUseCase.call(
  ExportDataParams(
    businessId: 'business_123',
    format: 'csv',
    dataType: 'sales',
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 31),
  ),
);
```

---

### Staff Management

**File**: `lib/domain/usecases/subscription/manage_staff.dart`

#### ManageStaffScheduleUseCase
Creates and manages employee shift schedules.

```dart
ManageScheduleParams(
  businessId: 'business_123',
  workerId: 'worker_456',
  operation: 'create',
  shiftData: ShiftData(
    startTime: DateTime(2025, 1, 15, 9, 0),
    endTime: DateTime(2025, 1, 15, 17, 0),
    position: 'cashier',
    isRecurring: true,
    recurringDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
  ),
)
```

#### GetStaffAvailabilityUseCase
Shows available staff for a specific date/position.

```dart
List<StaffMember> available = await getStaffAvailabilityUseCase.call(
  GetAvailabilityParams(
    businessId: 'business_123',
    date: DateTime.now(),
    position: 'cashier',
  ),
);
```

#### CalculatePerformanceUseCase
Rates employee performance with metrics.

```dart
PerformanceMetrics performance = await calculatePerformanceUseCase.call(
  PerformanceParams(
    businessId: 'business_123',
    workerId: 'worker_456',
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 31),
  ),
);
// Includes: productivity score, completed tasks, missed shifts, strengths
```

#### ManagePayrollUseCase
Generates payroll reports and employee paychecks.

```dart
PayrollReport payroll = await managePayrollUseCase.call(
  PayrollParams(
    businessId: 'business_123',
    payPeriodStart: DateTime(2025, 1, 1),
    payPeriodEnd: DateTime(2025, 1, 31),
    workerId: 'worker_456', // optional, null for all
  ),
);
```

---

### Order Management

**File**: `lib/domain/usecases/sales/manage_orders.dart`

#### CreateOrderUseCase
Creates new customer orders.

```dart
CreateOrderParams(
  businessId: 'business_123',
  customerId: 'customer_456',
  items: [OrderItem(...)],
  orderType: 'delivery', // delivery, pickup, dine-in
  deliveryAddress: '123 Main St',
  specialInstructions: 'No onions',
)
```

#### UpdateOrderStatusUseCase
Tracks order progress through fulfillment pipeline.

```dart
// Status progression: pending → confirmed → preparing → ready → completed
UpdateOrderStatusParams(
  businessId: 'business_123',
  orderId: 'order_789',
  newStatus: 'preparing',
  notes: 'Started cooking',
)
```

#### GetOrderHistoryUseCase
Retrieves order history with filtering.

```dart
List<OrderSummary> history = await getOrderHistoryUseCase.call(
  GetOrderHistoryParams(
    businessId: 'business_123',
    customerId: 'customer_456',
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 31),
    status: 'completed',
    limit: 50,
  ),
);
```

#### CalculateFulfillmentTimeUseCase
Estimates order completion time.

```dart
FulfillmentEstimate estimate = await calculateFulfillmentTimeUseCase.call(
  CalculateFulfillmentParams(
    businessId: 'business_123',
    orderType: 'delivery',
    itemCount: 5,
  ),
);
// Returns: estimated time, priority level, feasibility
```

#### OptimizeDeliveryRouteUseCase
Optimizes delivery routes for multiple orders.

```dart
DeliveryRoute route = await optimizeDeliveryRouteUseCase.call(
  OptimizeRouteParams(
    businessId: 'business_123',
    orderIds: ['order1', 'order2', 'order3'],
    currentLocation: 'restaurant',
  ),
);
// Returns: stops, total distance, estimated time, estimated cost
```

---

## Industry-Specific Business Logic

Located in `lib/services/business_logic/`

### Pharmacy Logic

**File**: `pharmacy_logic.dart`

#### Check Drug Interactions
```dart
final logic = PharmacyBusinessLogic();
List<DrugInteraction> interactions = await logic.checkDrugInteractions(
  ['drug_id_1', 'drug_id_2'],
);
// Returns: severity (mild, moderate, severe), description
```

#### Track Expiring Medications
```dart
List<ExpiringMedication> expiring = await logic.getExpiringMedications(
  businessId,
  daysThreshold: 30,
);
// Alerts for medications expiring within 30 days
```

#### Generate Prescription Report
```dart
PrescriptionReport report = await logic.generatePrescriptionReport(
  businessId,
  DateTime(2025, 1, 1),
  DateTime(2025, 1, 31),
);
// Revenue, frequency analysis, most prescribed drugs
```

---

### Restaurant & Bar Logic

**File**: `restaurant_logic.dart`

#### Queue Management
```dart
final logic = RestaurantBusinessLogic();
QueueStatus status = await logic.getCurrentQueueStatus(businessId);
// Total in queue, estimated wait time, detailed queue entries
```

#### Menu Recommendations
```dart
List<MenuRecommendation> recommendations = 
  await logic.getMenuRecommendations(businessId);
// Popular items, ratings, order frequency
```

#### Peak Hours Analysis
```dart
PeakHoursAnalysis analysis = await logic.analyzePeakHours(
  businessId,
  startDate,
  endDate,
);
// Identifies peak/slow hours, average orders per hour
```

#### Table Reservations
```dart
List<TableReservation> reservations = await logic.getTableReservations(
  businessId,
  date,
);
// Daily reservations, guest details, special requests
```

---

### Salon Logic

**File**: `salon_logic.dart`

#### Get Available Time Slots
```dart
final logic = SalonBusinessLogic();
List<TimeSlot> slots = await logic.getAvailableTimeSlots(
  businessId,
  date: DateTime(2025, 1, 15),
  serviceId: 'haircut',
);
// Real-time availability based on existing bookings
```

#### Get Stylist Availability
```dart
List<StylistAvailability> stylists = await logic.getStylistAvailability(
  businessId,
  'haircut',
  date,
);
// Filtered by service, sorted by rating
```

#### Calculate Appointment Price
```dart
AppointmentPricing pricing = await logic.calculateAppointmentPrice(
  businessId,
  'haircut',
  customerId,
);
// Includes loyalty discounts for repeat customers
```

#### Get Customer Profile
```dart
CustomerSalonProfile profile = await logic.getCustomerProfile(
  businessId,
  customerId,
);
// Appointment history, preferences, visit count, total spent
```

---

### Real Estate Logic

**File**: `realestate_logic.dart`

#### Lease Status
```dart
final logic = RealEstateBusinessLogic();
LeaseStatus status = await logic.getLeaseStatus(businessId, propertyId);
// Status, days until expiry, monthly rent, next payment date
```

#### Maintenance Tracking
```dart
List<MaintenanceRequest> requests = await logic.getMaintenanceRequests(
  businessId,
  propertyId,
);
// Organized by priority, status tracking
```

#### Property Analytics
```dart
PropertyAnalytics analytics = await logic.getPropertyAnalytics(
  businessId,
  startDate,
  endDate,
);
// Occupancy rate, revenue projections, outstanding payments
```

#### Tenant Payment History
```dart
TenantPaymentHistory history = await logic.getTenantPaymentHistory(
  businessId,
  tenantId,
);
// Total paid, overdue amounts, missed payments, payment records
```

---

## Common Business Metrics

**File**: `business_logic_registry.dart`

### Revenue Summary
```dart
RevenueSummary summary = BusinessMetricsCalculator.calculateRevenue(
  transactions,
  startDate,
  endDate,
);
// Total revenue, transactions count, average transaction value, category breakdown
```

### Growth Rate
```dart
double growthRate = BusinessMetricsCalculator.calculateGrowthRate(
  currentValue: 10000,
  previousValue: 8000,
);
// Returns: 25.0 (25% growth)
```

### Business KPIs
```dart
BusinessKPIs kpis = BusinessKPIs(
  dailyRevenue: 1000,
  weeklyRevenue: 7000,
  monthlyRevenue: 30000,
  activeCustomers: 500,
  newCustomers: 50,
  // ... more metrics
);

String health = kpis.getHealthStatus(); // Excellent, Good, Fair, Needs Attention
List<String> insights = kpis.getInsights(); // Actionable recommendations
```

---

## Integration Guide

### Step 1: Initialize Business Logic Registry

In your `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize business logic
  BusinessLogicRegistry().initialize();
  
  runApp(const MyApp());
}
```

### Step 2: Use in Providers

```dart
class SalesProvider extends ChangeNotifier {
  final createOrderUseCase = CreateOrderUseCase();
  final applyPricingUseCase = ApplyPricingUseCase();
  
  Future<void> createOrder(CreateOrderParams params) async {
    try {
      final order = await createOrderUseCase.call(params);
      notifyListeners();
    } catch (e) {
      print('Error creating order: $e');
    }
  }
}
```

### Step 3: Use in Screens

```dart
class CheckoutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        return ElevatedButton(
          onPressed: () => provider.createOrder(orderParams),
          child: Text('Create Order'),
        );
      },
    );
  }
}
```

### Step 4: Get Industry-Specific Logic

```dart
class PharmacyDashboard extends StatefulWidget {
  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  final _logic = BusinessLogicRegistry().pharmacyLogic;
  
  @override
  void initState() {
    super.initState();
    _loadDrugInteractions();
  }
  
  Future<void> _loadDrugInteractions() async {
    final interactions = await _logic.checkDrugInteractions(drugIds);
    setState(() {
      // Update UI with interactions
    });
  }
}
```

---

## Examples

### Example 1: Restaurant Order Management

```dart
// Create order with pricing
final orderParams = CreateOrderParams(
  businessId: userBusiness.id,
  customerId: currentCustomer.id,
  items: cartItems,
  orderType: 'delivery',
  deliveryAddress: selectedAddress,
);

final order = await createOrderUseCase.call(orderParams);

// Apply discounts if applicable
final pricingParams = ApplyPricingParams(
  businessId: userBusiness.id,
  customerId: currentCustomer.id,
  items: cartItems,
  couponCode: appliedCoupon,
  loyaltyTier: customer.loyaltyTier,
);

final pricing = await applyPricingUseCase.call(pricingParams);

// Get queue status
final restaurantLogic = BusinessLogicRegistry().restaurantLogic;
final queueStatus = await restaurantLogic.getCurrentQueueStatus(
  userBusiness.id,
);

// Show estimated wait time
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Order Placed!'),
    content: Text(
      'Estimated wait: ${queueStatus.estimatedWaitTimeMinutes} minutes\n'
      'Current queue: ${queueStatus.totalInQueue} orders',
    ),
  ),
);
```

### Example 2: Salon Appointment Booking

```dart
// Get available slots
final slots = await salonLogic.getAvailableTimeSlots(
  businessId,
  selectedDate,
  selectedService,
);

// Get stylists for service
final stylists = await salonLogic.getStylistAvailability(
  businessId,
  selectedService,
  selectedDate,
);

// Calculate price with loyalty discount
final pricing = await salonLogic.calculateAppointmentPrice(
  businessId,
  selectedService,
  customerId,
);

// Book appointment
final appointment = Appointment(
  customerId: customerId,
  stylistId: selectedStylist,
  timeSlot: selectedSlot,
  price: pricing.finalPrice,
);

// Get customer history for future reference
final profile = await salonLogic.getCustomerProfile(businessId, customerId);
print('Customer visit count: ${profile.visitCount}');
print('Total spent: ${profile.totalSpent}');
```

### Example 3: Pharmacy Medication Alerts

```dart
// Check expiring medications
final pharmacy = BusinessLogicRegistry().pharmacyLogic;
final expiring = await pharmacy.getExpiringMedications(
  businessId,
  daysThreshold: 30,
);

// Alert for critically expiring items
final critical = expiring.where((m) => m.daysUntilExpiry <= 7);
if (critical.isNotEmpty) {
  showNotification(
    'Critical: ${critical.length} medications expiring soon!',
    severity: 'high',
  );
}

// Check drug interactions
final interactions = await pharmacy.checkDrugInteractions(
  prescriptionDrugIds,
);

if (interactions.any((i) => i.severity == 'severe')) {
  showWarning('Severe drug interaction detected! Consult prescriber.');
}

// Generate prescription report
final report = await pharmacy.generatePrescriptionReport(
  businessId,
  monthStart,
  monthEnd,
);

print('Monthly revenue: ${report.totalRevenue}');
print('Prescriptions: ${report.totalPrescriptions}');
```

---

## Best Practices

1. **Error Handling**: Always wrap business logic calls in try-catch blocks
2. **Async/Await**: Use async patterns consistently
3. **Caching**: Cache frequently accessed data to reduce API calls
4. **Performance**: Use pagination for large datasets
5. **Notifications**: Implement real-time alerts for critical business events
6. **Validation**: Validate inputs before calling business logic
7. **Testing**: Write unit tests for all business logic calculations
8. **Monitoring**: Log important business events for analytics

---

## Next Steps

1. **Integrate use cases** into your provider classes
2. **Implement repository methods** for use cases
3. **Create screens** that leverage the business logic
4. **Add error handling** and user feedback
5. **Test thoroughly** with real business scenarios
6. **Optimize performance** based on user feedback

---

**Document Version**: 1.0
**Last Updated**: December 5, 2025
**Status**: Ready for Production

