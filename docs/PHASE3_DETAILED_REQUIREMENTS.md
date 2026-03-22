# 📱 PHASE 3: FEATURE SCREENS IMPLEMENTATION GUIDE

**Date**: December 5, 2025  
**Timeline**: 3-4 hours (after Phase 2 complete)  
**Status**: PLANNING PHASE - Ready for implementation

---

## 🎯 PHASE 3 OVERVIEW

Once all dashboards are wired to real data (Phase 2), Phase 3 focuses on implementing the core feature screens with full business logic integration.

**Core Features to Build**:
1. Sales Management (with barcode scanner)
2. Inventory Management
3. Customer Management
4. Reports & Analytics
5. Workers Management

---

## 1️⃣ SALES MANAGEMENT SCREEN

### File
`lib/presentation/screens/sales/screens/sales_screen.dart`

### Current State
- Basic screen exists
- TODO placeholders present
- Not connected to providers

### Required Features

#### 1.1 Product Selection
```dart
// Use barcode scanner OR manual search

// Option A: Barcode Scanner
final barcode = await BarcodeScanner.scan();
final product = provider.findProductByBarcode(barcode);
setState(() => selectedProduct = product);

// Option B: Manual Search
final searchResults = provider.searchProducts(query);
showSearchDialog(searchResults);
```

#### 1.2 Cart Management
```dart
class SalesCart {
  List<CartItem> items = [];
  
  void addItem(Product product, int qty) {
    items.add(CartItem(product: product, quantity: qty));
    notifyListeners();
  }
  
  void removeItem(int index) {
    items.removeAt(index);
    notifyListeners();
  }
  
  double getTotal() => items.fold(0, (sum, item) => sum + item.total);
  double getTax() => getTotal() * 0.075; // 7.5% tax
}
```

#### 1.3 Payment Processing
```dart
// Multiple payment methods
enum PaymentMethod {
  cash,
  card,
  mobileMoney,
  bankTransfer,
  credit,
}

void processPayment(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      final change = cashReceived - total;
      showChangeDialog(change);
      break;
    case PaymentMethod.card:
      processPosPayment();
      break;
    case PaymentMethod.mobileMoney:
      initiateMobileMoneyPayment();
      break;
    // ... others
  }
}
```

#### 1.4 Receipt Generation
```dart
// Generate receipt
final receipt = Receipt(
  saleId: sale.id,
  date: DateTime.now(),
  items: cartItems,
  subtotal: subtotal,
  tax: tax,
  total: total,
  paymentMethod: paymentMethod,
);

// Options to print/email
options = [
  'Print Receipt', // Thermal printer
  'Email Receipt', // Email service
  'SMS Receipt',   // SMS service
  'Save Receipt',  // PDF download
];
```

#### 1.5 Offline Mode
```dart
// When offline, add to queue instead of immediate save
if (connectivity.isOnline) {
  await provider.recordSale(saleData);
} else {
  await syncQueue.add(
    operation: 'recordSale',
    data: saleData,
    timestamp: DateTime.now(),
  );
  showOfflineNotification('Sale saved. Will sync when online.');
}
```

### Implementation Checklist
- [ ] Build sales form with product search
- [ ] Implement barcode scanner integration
- [ ] Create cart widget with add/remove
- [ ] Build payment method selector
- [ ] Implement payment processing
- [ ] Add receipt generation
- [ ] Test offline mode
- [ ] Add sales history view
- [ ] Implement refund/return logic
- [ ] Add receipt printing options

### Expected Output
```
┌─────────────────────────────┐
│  NEW SALE                   │
├─────────────────────────────┤
│ Search or Scan Barcode      │
│ [Input] or [🔍 Scan]      │
├─────────────────────────────┤
│ CART (3 items)              │
│ ┌─────────────────────┐     │
│ │ Item 1  x 2   ₦1000 │     │
│ │ Item 2  x 1   ₦2500 │     │
│ │ Item 3  x 5   ₦750  │     │
│ └─────────────────────┘     │
├─────────────────────────────┤
│ Subtotal:        ₦4250      │
│ Tax (7.5%):      ₦319       │
│ Total:           ₦4569      │
├─────────────────────────────┤
│ Payment Method: [Cash ▼]    │
│ Cash Received:   [₦5000  ]  │
│ Change Due:      ₦431       │
├─────────────────────────────┤
│ [Complete Sale] [Cancel]    │
└─────────────────────────────┘
```

---

## 2️⃣ INVENTORY MANAGEMENT SCREEN

### File
`lib/presentation/screens/inventory/screens/inventory_screen.dart`

### Required Features

#### 2.1 Inventory Listing
```dart
// Display all products with stock levels
class InventoryItem {
  String productId;
  String name;
  String sku;
  int quantity;
  double unitPrice;
  int minStock;
  int maxStock;
  String category;
  DateTime lastUpdated;
  
  bool get isLowStock => quantity <= minStock;
  bool get isOverstock => quantity > maxStock;
}

// Show with indicators
_buildInventoryList() {
  return ListView.builder(
    itemBuilder: (context, index) {
      final item = inventory[index];
      return ListTile(
        title: Text(item.name),
        subtitle: Text('SKU: ${item.sku}'),
        trailing: _buildStockIndicator(item),
        onTap: () => showItemDetails(item),
      );
    },
  );
}

// Stock color indicators
_buildStockIndicator(InventoryItem item) {
  Color color = Colors.green;
  String status = 'OK';
  
  if (item.isLowStock) {
    color = Colors.orange;
    status = 'LOW';
  }
  if (item.isOverstock) {
    color = Colors.blue;
    status = 'OVER';
  }
  
  return Column(
    children: [
      Text('${item.quantity} ${item.category}'),
      Text(status, style: TextStyle(color: color)),
    ],
  );
}
```

#### 2.2 Stock Adjustments
```dart
// Receive stock from supplier
void receiveStock(String productId, int quantity, String supplier) {
  provider.updateStock(
    productId: productId,
    adjustment: quantity,
    type: 'receive',
    supplier: supplier,
    notes: 'Stock received from $supplier',
    timestamp: DateTime.now(),
  );
}

// Issue stock (damage, loss, return)
void issueStock(String productId, int quantity, String reason) {
  provider.updateStock(
    productId: productId,
    adjustment: -quantity,
    type: 'issue',
    reason: reason,
    notes: 'Stock issued: $reason',
    timestamp: DateTime.now(),
  );
}

// Stock transfer between locations
void transferStock(String fromLocation, String toLocation, String productId, int qty) {
  provider.transferStock(
    fromLocation: fromLocation,
    toLocation: toLocation,
    productId: productId,
    quantity: qty,
    timestamp: DateTime.now(),
  );
}
```

#### 2.3 Add/Edit Product Form
```dart
// Reusable product form
class ProductForm extends StatefulWidget {
  final Product? product; // null = add new
  
  const ProductForm({this.product});
  
  @override
  State<ProductForm> createState() => _ProductFormState();
}

// Form fields
- Product Name (required)
- SKU/Barcode (required)
- Category (dropdown)
- Unit Price (required)
- Cost Price
- Minimum Stock Level
- Maximum Stock Level
- Description
- Image (camera/gallery)
- Barcode Generator

// On save
void saveProduct(ProductInput input) {
  if (product == null) {
    provider.addProduct(input);
  } else {
    provider.updateProduct(product!.id, input);
  }
}
```

#### 2.4 Stock Alerts
```dart
// Low stock alert system
_buildLowStockAlert() {
  final lowStockItems = provider.getLowStockItems();
  
  if (lowStockItems.isEmpty) return SizedBox.shrink();
  
  return Container(
    color: Colors.orange[100],
    child: ListTile(
      title: Text('⚠️ ${lowStockItems.length} Items Low in Stock'),
      onTap: () => showLowStockDetails(lowStockItems),
      trailing: Icon(Icons.arrow_forward),
    ),
  );
}
```

#### 2.5 Inventory Reports
```dart
// Valuation report
double totalValue = inventory.fold(0, (sum, item) => 
  sum + (item.quantity * item.unitPrice)
);

// Turnover analysis
Map<String, int> getCategoryTurnover() {
  // Group by category and calculate turnover rate
  // Show fast movers vs slow movers
}

// Aging report (old stock)
List<InventoryItem> getAgedStock(int daysThreshold) {
  return inventory.where((item) => 
    item.lastUpdated.isBefore(
      DateTime.now().subtract(Duration(days: daysThreshold))
    )
  ).toList();
}
```

### Implementation Checklist
- [ ] Build inventory list with filtering/search
- [ ] Create product form (add/edit)
- [ ] Implement stock adjustment UI
- [ ] Build low stock alert section
- [ ] Add stock transfer functionality
- [ ] Create inventory reports
- [ ] Implement barcode generation
- [ ] Add stock history view
- [ ] Test offline sync
- [ ] Add inventory valuation

---

## 3️⃣ CUSTOMER MANAGEMENT SCREEN

### File
`lib/presentation/screens/customers/screens/customers_screen.dart`

### Required Features

#### 3.1 Customer List
```dart
// Paginated customer list with search
class CustomerListView extends StatefulWidget {
  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

// Build list with infinite scroll
_buildCustomerList() {
  return ListView.builder(
    itemBuilder: (context, index) {
      if (index == customers.length) {
        return _buildLoadMoreButton();
      }
      
      final customer = customers[index];
      return _buildCustomerTile(customer);
    },
  );
}

// Customer tile
_buildCustomerTile(Customer customer) {
  return ListTile(
    leading: CircleAvatar(
      backgroundImage: NetworkImage(customer.avatar),
      child: customer.avatar == null ? 
        Text(customer.initials) : null,
    ),
    title: Text(customer.name),
    subtitle: Text('${customer.phone} • ${customer.totalPurchases} purchases'),
    trailing: Text('₦${customer.totalSpent.toStringAsFixed(0)}'),
    onTap: () => navigateToCustomerDetail(customer),
  );
}
```

#### 3.2 Customer Search & Filter
```dart
// Multi-criteria search
void searchCustomers(String query) {
  final results = provider.searchCustomers(query);
  // Search by: name, phone, email, id
}

// Filters
class CustomerFilter {
  String? tier; // VIP, Regular, New
  int? minPurchases;
  int? maxDaysSinceVisit;
  double? minSpent;
  
  List<Customer> apply(List<Customer> customers) {
    return customers.where((c) {
      if (tier != null && c.tier != tier) return false;
      if (minPurchases != null && c.totalPurchases < minPurchases!) return false;
      if (minSpent != null && c.totalSpent < minSpent!) return false;
      return true;
    }).toList();
  }
}
```

#### 3.3 Customer Detail View
```dart
// Complete customer profile
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile section
          _buildProfileCard(customer),
          
          // Contact information
          _buildContactSection(customer),
          
          // Statistics
          _buildStatisticsCard(customer),
          
          // Purchase history
          _buildPurchaseHistory(customer),
          
          // Contact preferences
          _buildPreferencesSection(customer),
          
          // Credit limit
          _buildCreditSection(customer),
        ],
      ),
    );
  }
}
```

#### 3.4 Add/Edit Customer
```dart
// Customer form
- Full Name (required)
- Phone (required)
- Email
- Business Name
- Customer Type (retail/wholesale/corporate)
- Address
- City/State
- Contact Person
- Tax ID (for corporate)
- Credit Limit
- Payment Terms
- Loyalty Program (yes/no)

// On save
void saveCustomer(CustomerInput input) {
  if (isNewCustomer) {
    provider.addCustomer(input);
  } else {
    provider.updateCustomer(customerId, input);
  }
}
```

#### 3.5 Communication Tools
```dart
// Send communication to customer
void sendCommunication(String customerId, String type, String content) {
  switch (type) {
    case 'sms':
      smsService.send(customer.phone, content);
      break;
    case 'email':
      emailService.send(customer.email, 'Update', content);
      break;
    case 'whatsapp':
      launchWhatsapp(customer.phone, content);
      break;
    case 'notification':
      pushNotificationService.send(customerId, content);
      break;
  }
}

// Templates for common messages
templates = [
  'Thank you for your purchase',
  'Your order is ready for pickup',
  'We have a special offer for you',
  'Reminder: Your invoice is due',
];
```

### Implementation Checklist
- [ ] Build customer list with pagination
- [ ] Implement search functionality
- [ ] Create advanced filters
- [ ] Build customer detail view
- [ ] Create add/edit customer form
- [ ] Implement contact information management
- [ ] Add purchase history
- [ ] Implement communication tools (SMS, Email)
- [ ] Create loyalty program view
- [ ] Add credit limit management

---

## 4️⃣ REPORTS & ANALYTICS SCREEN

### File
`lib/presentation/reports/screens/reports_dashboard_screen.dart`

### Required Features

#### 4.1 Report Types

**Sales Reports**
```dart
// Daily/Weekly/Monthly/YTD
class SalesReport {
  DateTime startDate;
  DateTime endDate;
  double totalRevenue;
  int totalTransactions;
  double averageTransaction;
  int itemsSold;
  
  // By category
  Map<String, double> revenueByCategory;
  
  // By product
  List<ProductSales> topProducts;
  
  // By customer
  List<CustomerSpending> topCustomers;
}
```

**Inventory Reports**
```dart
class InventoryReport {
  double totalValue;
  int itemCount;
  int lowStockCount;
  
  // Turnover analysis
  Map<String, double> turnoverByCategory;
  
  // Aged inventory
  List<AgedItem> itemsOver30days;
  
  // Valuation
  double fifoValue;
  double wavelValue;
}
```

**Customer Reports**
```dart
class CustomerReport {
  int totalCustomers;
  int newCustomersThisPeriod;
  double averageCustomerValue;
  
  // Segmentation
  int vipCount;
  int regularCount;
  int inactiveCount;
  
  // Analysis
  List<Customer> topSpenders;
  List<Customer> mostFrequent;
  List<Customer> atRisk; // Haven't purchased in 90 days
}
```

**Performance Metrics**
```dart
class PerformanceMetrics {
  double grossProfit;
  double profitMargin;
  double roi;
  double grosMarginByCategory;
  
  // Growth
  double monthOverMonthGrowth;
  double yearOverYearGrowth;
  
  // Efficiency
  double inventoryTurnover;
  double daysInventoryOutstanding;
  double receivablesDays;
}
```

#### 4.2 Date Range Selection
```dart
// Preset date ranges
enum DateRange {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
}

// Custom date picker
_buildDateRangeSelector() {
  return Row(
    children: [
      GestureDetector(
        onTap: () => selectStartDate(),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            DateFormat('MMM dd, yyyy').format(startDate),
          ),
        ),
      ),
      Text(' to '),
      GestureDetector(
        onTap: () => selectEndDate(),
        child: Container(
          // similar to above
          child: Text(
            DateFormat('MMM dd, yyyy').format(endDate),
          ),
        ),
      ),
    ],
  );
}
```

#### 4.3 Charts & Visualizations
```dart
// Revenue trend chart
_buildRevenueChart(List<DailySales> data) {
  return LineChart(
    LineChartData(
      spots: data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.revenue.toDouble()))
          .toList(),
    ),
  );
}

// Category distribution
_buildCategoryChart(Map<String, double> data) {
  return PieChart(
    PieChartData(
      sections: data.entries
          .map((e) => PieChartSectionData(
            value: e.value,
            title: e.key,
          ))
          .toList(),
    ),
  );
}

// Compare periods
_buildComparisonChart(List<double> currentPeriod, List<double> previousPeriod) {
  return BarChart(
    BarChartData(
      barGroups: List.generate(currentPeriod.length, (index) {
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(toY: currentPeriod[index], color: Colors.blue),
            BarChartRodData(toY: previousPeriod[index], color: Colors.grey),
          ],
        );
      }),
    ),
  );
}
```

#### 4.4 Export Functionality
```dart
// Export to PDF
void exportToPDF(Report report) {
  final pdf = Document();
  
  pdf.addPage(
    Page(
      build: (context) => Column(
        children: [
          Text('${report.title} - ${DateFormat('MMM dd, yyyy').format(report.generatedDate)}'),
          Table.fromTextArray(
            data: report.toTableData(),
          ),
          // Charts as images
          ...report.charts.map((chart) => Image(chart.toImage())),
        ],
      ),
    ),
  );
  
  pdf.save().then((bytes) {
    // Share or save file
  });
}

// Export to Excel
void exportToExcel(Report report) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  
  // Add headers
  report.toTableData().forEach((row) {
    sheet.appendRow(row.map((cell) => cell.toString()).toList());
  });
  
  excel.save().then((bytes) {
    // Save file
  });
}

// Email report
void emailReport(Report report, String recipientEmail) {
  final attachments = [
    report.exportToPDF(),
    report.exportToExcel(),
  ];
  
  emailService.send(
    to: recipientEmail,
    subject: 'Business Report - ${report.title}',
    body: report.getSummary(),
    attachments: attachments,
  );
}

// Schedule recurring reports
void scheduleReport(Report report, String frequency, List<String> recipients) {
  taskScheduler.schedule(
    name: report.id,
    frequency: frequency, // daily, weekly, monthly
    time: '06:00', // 6 AM
    action: () => emailReport(report, recipients),
  );
}
```

#### 4.5 Dashboard Summary
```dart
// Quick overview cards
_buildSummaryCards(Report report) {
  return Row(
    children: [
      _buildSummaryCard(
        title: 'Total Revenue',
        value: '₦${report.totalRevenue.toStringAsFixed(0)}',
        change: '${report.revenueGrowth}%',
        icon: Icons.trending_up,
      ),
      _buildSummaryCard(
        title: 'Transactions',
        value: '${report.transactionCount}',
        change: '${report.transactionGrowth}%',
        icon: Icons.shopping_cart,
      ),
      _buildSummaryCard(
        title: 'Profit Margin',
        value: '${(report.profitMargin * 100).toStringAsFixed(1)}%',
        change: '${report.marginChange}%',
        icon: Icons.show_chart,
      ),
    ],
  );
}
```

### Implementation Checklist
- [ ] Create report type selector
- [ ] Implement date range selection
- [ ] Build sales report view
- [ ] Build inventory report view
- [ ] Build customer report view
- [ ] Add performance metrics
- [ ] Implement charts/graphs
- [ ] Add export to PDF functionality
- [ ] Add export to Excel functionality
- [ ] Implement email scheduling
- [ ] Create dashboard summary cards
- [ ] Add filters to reports

---

## 5️⃣ WORKERS MANAGEMENT SCREEN

### File
`lib/presentation/screens/workers/screens/workers_screen.dart`

### Required Features

#### 5.1 Worker List
```dart
// Display all workers with roles
class WorkerListView extends StatefulWidget {
  @override
  State<WorkerListView> createState() => _WorkerListViewState();
}

_buildWorkerList() {
  return ListView.builder(
    itemBuilder: (context, index) {
      final worker = workers[index];
      return _buildWorkerTile(worker);
    },
  );
}

_buildWorkerTile(Worker worker) {
  return ListTile(
    leading: CircleAvatar(
      backgroundImage: NetworkImage(worker.avatar),
    ),
    title: Text(worker.name),
    subtitle: Text('${worker.role} • Status: ${worker.status}'),
    trailing: PopupMenuButton(
      itemBuilder: (_) => [
        PopupMenuItem(
          child: Text('View Profile'),
          value: 'view',
        ),
        PopupMenuItem(
          child: Text('Permissions'),
          value: 'permissions',
        ),
        PopupMenuItem(
          child: Text('Attendance'),
          value: 'attendance',
        ),
      ],
      onSelected: (value) => handleWorkerAction(value, worker),
    ),
  );
}
```

#### 5.2 Add/Edit Worker
```dart
// Worker form
- Full Name (required)
- Email (required)
- Phone
- Role (dropdown: Admin, Manager, Staff, etc.)
- Department
- Start Date
- Hourly/Salary Rate
- Commission %
- Permissions (checkboxes)
- Avatar (photo)
- Emergency Contact

void saveWorker(WorkerInput input) {
  if (isNewWorker) {
    provider.addWorker(input);
  } else {
    provider.updateWorker(workerId, input);
  }
}
```

#### 5.3 Permissions Management
```dart
// Permission assignment
class WorkerPermissions {
  bool canViewSales;
  bool canCreateSale;
  bool canEditSale;
  bool canDeleteSale;
  
  bool canViewInventory;
  bool canUpdateInventory;
  
  bool canViewCustomers;
  bool canEditCustomers;
  
  bool canViewReports;
  bool canExportReports;
  
  bool canManageWorkers;
  bool canViewPayroll;
}

_buildPermissionsEditor(Worker worker) {
  return ListView(
    children: [
      _buildPermissionSection('Sales', [
        'Can View Sales',
        'Can Create Sale',
        'Can Edit Sale',
        'Can Delete Sale',
      ]),
      _buildPermissionSection('Inventory', [
        'Can View Inventory',
        'Can Update Stock',
      ]),
      _buildPermissionSection('Customers', [
        'Can View Customers',
        'Can Edit Customers',
      ]),
      _buildPermissionSection('Reports', [
        'Can View Reports',
        'Can Export Reports',
      ]),
      _buildPermissionSection('Administration', [
        'Can Manage Workers',
        'Can View Payroll',
      ]),
    ],
  );
}
```

#### 5.4 Attendance Tracking
```dart
// Clock in/out system
class AttendanceRecord {
  DateTime clockIn;
  DateTime? clockOut;
  String notes;
  
  Duration get workDuration => 
    clockOut != null ? clockOut!.difference(clockIn) : Duration.zero;
  
  bool get isActive => clockOut == null;
}

_buildAttendanceView(Worker worker) {
  final today = provider.getAttendance(worker.id, DateTime.now());
  
  return Column(
    children: [
      if (today?.isActive ?? false)
        ElevatedButton(
          onPressed: () => provider.clockOut(worker.id),
          child: Text('Clock Out - ${today?.workDuration}'),
        )
      else
        ElevatedButton(
          onPressed: () => provider.clockIn(worker.id),
          child: Text('Clock In'),
        ),
      
      // Attendance history
      _buildAttendanceHistory(worker),
    ],
  );
}
```

#### 5.5 Performance Metrics
```dart
// Worker performance data
class WorkerPerformance {
  int salesCount;
  double totalSalesValue;
  double averageTransactionValue;
  
  int customersServed;
  double averageRating;
  
  int tasksCompleted;
  double attendanceRate;
  
  DateTime evaluationDate;
  String notes;
}

_buildPerformanceCard(Worker worker) {
  final perf = provider.getPerformance(worker.id);
  
  return Card(
    child: Column(
      children: [
        _buildMetricRow('Sales', '${perf.salesCount}', '₦${perf.totalSalesValue}'),
        _buildMetricRow('Customers', '${perf.customersServed}', '★${perf.averageRating}'),
        _buildMetricRow('Attendance', '${perf.attendanceRate}%', '${perf.tasksCompleted} tasks'),
      ],
    ),
  );
}
```

#### 5.6 Commission Calculation
```dart
// Commission tracking
void calculateCommission(String workerId, String period) {
  // Get all sales by worker for period
  final sales = provider.getSalesByWorker(workerId, period);
  
  // Apply commission structure
  double commission = 0;
  for (var sale in sales) {
    commission += sale.amount * (worker.commissionRate / 100);
  }
  
  // Add performance bonus if applicable
  if (worker.performance > 100) {
    commission *= 1.1; // 10% bonus
  }
  
  return commission;
}
```

### Implementation Checklist
- [ ] Build worker list with search
- [ ] Create add/edit worker form
- [ ] Implement permissions editor
- [ ] Add attendance tracking (clock in/out)
- [ ] Build attendance history view
- [ ] Create performance metrics view
- [ ] Implement commission calculator
- [ ] Add performance evaluation form
- [ ] Create worker schedule view
- [ ] Implement payroll integration

---

## 🎯 IMPLEMENTATION ORDER

**Week 1 - Phase 3**:
1. **Day 1** (2 hours): Sales Management
   - Product search
   - Barcode scanner
   - Cart management
   - Payment processing
   - Receipt printing

2. **Day 2** (2 hours): Inventory Management
   - Product listing
   - Stock adjustments
   - Add/edit products
   - Low stock alerts
   - Reports

3. **Day 3** (2 hours): Customer Management
   - Customer list
   - Search & filters
   - Customer details
   - Add/edit customer
   - Communication

**Week 2 - Phase 3 Continued**:
4. **Day 1** (2 hours): Reports & Analytics
   - Report types
   - Date selection
   - Charts & graphs
   - Export functionality

5. **Day 2** (1 hour): Workers Management
   - Worker list
   - Permissions
   - Attendance
   - Performance metrics

---

## ✅ SUCCESS CRITERIA FOR PHASE 3

- ✅ All 5 feature screens fully functional
- ✅ Real data flowing from providers to UI
- ✅ Offline mode working with sync queue
- ✅ Payment processing complete
- ✅ Reports generating and exporting
- ✅ Worker management complete
- ✅ No compilation errors
- ✅ Less than 250 analyzer issues
- ✅ Performance acceptable (no lag)
- ✅ All screens support dark mode

---


