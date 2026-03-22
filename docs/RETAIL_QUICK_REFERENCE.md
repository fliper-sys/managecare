# Retail Business - Quick Reference Guide

## 🚀 Quick Start

### For Admin Users - Add Your First Product

1. **Navigate to Retail Dashboard**
   - Tap "Manage Products" or find Products button

2. **Add Product**
   - Tap the + FAB button
   - Fill in form:
     - **Name:** Product name (required)
     - **Category:** Product category (required)
     - **Price:** Price in Naira (required)
     - **Stock:** Quantity (required)
     - **Barcode:** Optional for scanning
   - Tap "Add Product"

3. **Verify in Firestore**
   - Check: `businesses/{businessId}/products/{productId}`

### For Workers - Process a Sale

1. **Navigate to POS Screen**
   - Tap "Point of Sale" from dashboard

2. **Add Items**
   - Tap product cards to add to cart
   - Badge shows count in cart

3. **Checkout**
   - Tap "Cart" FAB
   - Review items and total
   - Tap "Confirm & Pay"
   - Choose receipt action

4. **Receipt Options**
   - Print (thermal printer)
   - Email (to customer)
   - Share (send digitally)

---

## 📁 File Structure - Retail Module

```
lib/presentation/industry_specific/retail/
├── screens/
│   ├── retail_dashboard.dart              ← Main hub
│   ├── pos_screen.dart                    ← Point of sale
│   ├── product_catalog_screen.dart        ← Product listing
│   ├── product_management_screen.dart     ← Admin: Manage products
│   ├── add_product_screen.dart            ← Admin: Add/edit form
│   ├── supplier_management_screen.dart    ← Admin: Manage suppliers
│   ├── add_supplier_screen.dart           ← Admin: Add supplier form
│   ├── multi_store_screen.dart            ← Store locations
│   ├── promotions_screen.dart             ← Promotions listing (Phase 2)
│   └── wholesale_orders_screen.dart       ← Wholesale orders
├── widgets/
│   ├── checkout_sheet.dart                ← Checkout UI
│   ├── pos_product_card.dart              ← Product card
│   ├── category_grid.dart
│   ├── discount_calculator.dart
│   ├── inventory_sync.dart
│   ├── product_card.dart
│   └── store_selector.dart
└── providers/
    └── (none - uses main RetailProvider)

lib/providers/
└── retail_provider.dart                   ← State management

lib/routes/
└── app_router.dart                        ← Navigation routing

lib/core/constants/
└── routes.dart                            ← Route constants
```

---

## 🔑 Key Classes & Methods

### RetailProvider - Main State Management

```dart
// Initialization
Future<void> initialize(String businessId)

// Load data from Firestore
Future<void> loadProducts()
Future<void> loadSuppliers()
Future<void> loadStores()
Future<void> loadPromotions()

// Product operations
Future<void> addProduct(Product product)
Future<void> updateProduct(String id, Product product)
Future<void> deleteProduct(String id)

// Supplier operations
Future<void> addSupplier(Supplier supplier)

// Cart operations
void addToCart(String productId, {int qty = 1})
void removeFromCart(String productId)
void updateQty(String productId, int qty)
void clearCart()

// Sales
Future<void> checkout({
  required String paymentMethod,
  double discount = 0.0,
})

// Getters
List<Product> get products              // All products
List<Supplier> get suppliers            // All suppliers
List<StoreLocation> get stores          // All stores
List<Promotion> get promotions          // Active promotions
Map<Product, int> get cartItems         // Cart contents
int get cartCount                       // Total items in cart
double get cartTotal                    // Total price
bool get isLoading                      // Loading state
String? get errorMessage                // Error feedback
```

### Product Class

```dart
class Product {
  final String id;
  final String name;
  final double price;
  int stock;
  final String category;
  final String? imageUrl;
  final String? barcode;
  
  // Firestore methods
  Map<String, dynamic> toFirestore()
  factory Product.fromFirestore(DocumentSnapshot doc)
}
```

### Firestore Collections

```
businesses/{businessId}/
├── products/{productId}
│   ├── name: string
│   ├── price: double
│   ├── stock: integer
│   ├── category: string
│   ├── imageUrl: string
│   ├── barcode: string
│   └── updatedAt: timestamp
│
├── suppliers/{supplierId}
│   ├── name: string
│   ├── contact: string
│   ├── email: string
│   ├── address: string
│   └── updatedAt: timestamp
│
├── sales/{saleId}
│   ├── items: array
│   │   └── [{ productId, productName, quantity, unitPrice, total }]
│   ├── subtotal: double
│   ├── discount: double
│   ├── total: double
│   ├── paymentMethod: string
│   └── timestamp: timestamp
│
└── promotions/{promotionId}
    ├── name: string
    ├── description: string
    ├── discountPercentage: double
    ├── startDate: timestamp
    ├── endDate: timestamp
    └── updatedAt: timestamp
```

---

## 🛣️ Navigation Routes

```dart
// Route constants
Routes.retailDashboard      // '/retail'
Routes.retailPos            // '/retail/pos'
Routes.retailCatalog        // '/retail/catalog'
Routes.retailSuppliers      // '/retail/suppliers'
Routes.retailStores         // '/retail/stores'
Routes.retailPromotions     // '/retail/promotions'
Routes.retailWholesale      // '/retail/wholesale'
Routes.retailProducts       // '/retail/products' (NEW)
Routes.retailAddProduct     // '/retail/products/add' (NEW)
Routes.retailAddSupplier    // '/retail/suppliers/add' (NEW)

// Navigation example
Navigator.of(context).pushNamed(Routes.retailProducts);
```

---

## 🧪 Common Operations

### Add Product Programmatically

```dart
final retailProvider = Provider.of<RetailProvider>(context, listen: false);

final product = Product(
  id: '', // Will be auto-generated by Firestore
  name: 'Laptop',
  price: 450000,
  stock: 5,
  category: 'Electronics',
  imageUrl: null,
  barcode: '123456789',
);

await retailProvider.addProduct(product);
```

### Add to Cart

```dart
final retailProvider = Provider.of<RetailProvider>(context, listen: false);

// Add product to cart
retailProvider.addToCart(productId, qty: 2);

// Check cart
print('Cart count: ${retailProvider.cartCount}');
print('Cart total: ₦${retailProvider.cartTotal}');
```

### Process Checkout

```dart
await retailProvider.checkout(
  paymentMethod: 'Cash',
  discount: 5000.0, // Optional discount
);

// This will:
// 1. Create sale record in Firestore
// 2. Decrease product stock
// 3. Send low stock alerts if needed
// 4. Clear cart
// 5. Send sale notifications
```

### Search Products

```dart
final products = retailProvider.products
    .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
    .toList();
```

### Filter by Category

```dart
final categoryProducts = retailProvider.products
    .where((p) => p.category == selectedCategory)
    .toList();
```

### Check Stock Status

```dart
final lowStockProducts = retailProvider.products
    .where((p) => p.stock < 10)
    .toList();

final outOfStockProducts = retailProvider.products
    .where((p) => p.stock == 0)
    .toList();
```

---

## 🔐 Security & Access Control

### Firestore Security Rules

**Owner Access:**
- Full CRUD on all collections
- Can manage workers
- Can delete records

**Worker Access:**
- Read: products, sales, stores
- Write: Only sales (via checkout)
- Cannot delete or edit products

**Implementation:**
```javascript
// In firestore.rules
function isOwner(businessId) {
  return get(/databases/$(database)/documents/businesses/$(businessId))
    .data.ownerId == request.auth.uid;
}

function isWorker(businessId) {
  return get(/databases/$(database)/documents/businesses/$(businessId)/workers/$(request.auth.uid))
    .exists;
}

function canManageBusiness(businessId) {
  return isSignedIn() && (isOwner(businessId) || isWorker(businessId));
}
```

---

## ⚠️ Common Issues & Solutions

### Issue: Products not loading
**Solution:** Make sure `initialize(businessId)` is called in RetailDashboard initState

### Issue: Cart not updating UI
**Solution:** Wrap with `Consumer<RetailProvider>` not just `Provider.of()`

### Issue: Firestore security error
**Solution:** Verify user is authenticated and check Firestore rules

### Issue: Low stock alerts not triggering
**Solution:** Ensure stock drops below 10 (rule is < 10, not <= 10)

### Issue: Cannot add product
**Solution:** Validate all required fields are filled and user is owner

---

## 📊 Performance Tips

1. **Use Consumer for real-time updates**
   ```dart
   Consumer<RetailProvider>(
     builder: (context, retailProvider, _) {
       return ListView(...)
     }
   )
   ```

2. **Lazy load products**
   ```dart
   // Only load 20 at a time for large catalogs
   itemCount: min(products.length, 20)
   ```

3. **Debounce search**
   ```dart
   // Wait 300ms before filtering
   Timer.periodic(Duration(milliseconds: 300), (_) {
     setState(() => _searchQuery = _controller.text);
   });
   ```

4. **Cache expensive operations**
   ```dart
   // Cache category list
   final categories = <Set>[...products.map((p) => p.category)];
   ```

---

## 🧬 Debugging

### Check Firestore Data
```dart
// In RetailProvider
print('Products: ${_products.length}');
print('First product: ${_products.first.name}');
```

### Monitor Provider State
```dart
// In any widget
final provider = Provider.of<RetailProvider>(context);
print('Loading: ${provider.isLoading}');
print('Error: ${provider.errorMessage}');
print('Cart count: ${provider.cartCount}');
```

### Enable Firestore Logging
```dart
// In main.dart
import 'package:firebase_core/firebase_core.dart';

void main() {
  Firebase.initializeApp().then((_) {
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
    );
    runApp(const MyApp());
  });
}
```

---

## 📱 UI Patterns Used

### Product List with Actions
```dart
ListView.builder(
  itemCount: products.length,
  itemBuilder: (context, index) {
    final product = products[index];
    return Card(
      child: ListTile(
        title: Text(product.name),
        subtitle: Text('₦${product.price}'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(child: Text('Edit')),
            PopupMenuItem(child: Text('Delete')),
          ],
        ),
      ),
    );
  },
)
```

### Form Validation
```dart
if (_nameController.text.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Name is required'))
  );
  return;
}
```

### Confirmation Dialog
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Delete?'),
    content: Text('This cannot be undone'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
      ElevatedButton(
        onPressed: () async {
          await deleteItem();
          Navigator.pop(context);
        },
        child: Text('Delete'),
      ),
    ],
  ),
)
```

---

## 🎓 Best Practices

1. **Always initialize provider**
   ```dart
   @override
   void initState() {
     super.initState();
     final provider = Provider.of<RetailProvider>(context, listen: false);
     provider.initialize(businessId);
   }
   ```

2. **Handle async operations**
   ```dart
   Future<void> saveProduct() async {
     setState(() => _isLoading = true);
     try {
       await provider.addProduct(product);
       // Show success
     } catch (e) {
       // Show error
     } finally {
       setState(() => _isLoading = false);
     }
   }
   ```

3. **Validate user input**
   ```dart
   // Check required fields
   if (product.name.isEmpty) return showError('Name required');
   if (product.price <= 0) return showError('Price must be positive');
   if (product.stock < 0) return showError('Stock cannot be negative');
   ```

4. **Provide user feedback**
   ```dart
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Text('Product added'),
       backgroundColor: Colors.green,
     ),
   );
   ```

---

## 📞 Contact & Support

### For Implementation Questions
- Check Phase 1 docs: `RETAIL_FIRESTORE_PHASE1_COMPLETE.md`
- Check Phase 2 guide: `PHASE2_PLANNING_GUIDE.md`
- Review code comments in source files

### For Bug Reports
- Check console for errors
- Verify Firestore rules
- Check network connectivity
- Review user permissions

### For Feature Requests
- Document use case
- Check Phase 2 planning guide
- Coordinate with team

---

**Document Version:** 1.0
**Last Updated:** December 5, 2025
**Status:** Ready for Production (Phase 1)
**Next Major Update:** December 9, 2025 (Phase 2 Kickoff)

