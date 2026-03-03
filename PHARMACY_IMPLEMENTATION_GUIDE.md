# Pharmacy Module - Complete Implementation Guide

## Overview
The Manage Care pharmacy module provides comprehensive drug inventory management, prescription handling, patient records, and pharmacy operations for pharmacy businesses.

## Module Structure

### 1. Core Provider: `PharmacyProvider`
**Location**: `lib/providers/pharmacy_provider.dart`

**Key Classes**:
- `Drug` - Represents a drug with id, name, batch, expiry, stock, price
- `Prescription` - Represents a prescription with id, patientId, items, status
- `Patient` - Represents a patient record with id, name, phone

**Key Methods**:

#### Inventory Management
```dart
// Get all drugs with low stock
List<Drug> getLowStockDrugs({int threshold = 5})

// Get all drugs expiring within specified days
List<Drug> getExpiringDrugs({int daysThreshold = 30})

// Get all expired drugs
List<Drug> getExpiredDrugs()

// Calculate total inventory value
double calculateInventoryValue()

// Get inventory statistics
Map<String, dynamic> getInventoryStats()
```

#### Prescription Management
```dart
// Add a new prescription
Future<Prescription> addPrescription(String patientId, List<Map<String, dynamic>> items, ...)

// Dispense a prescription (decrements stock, updates status)
Future<void> dispensePrescription(String prescriptionId, ...)

// Cancel a prescription
Future<void> cancelPrescription(String prescriptionId, ...)

// Get prescription history for a patient
List<Prescription> getPatientPrescriptionHistory(String patientId)

// Get prescription statistics
Map<String, dynamic> getPrescriptionStats()
```

#### Drug Search & Filtering
```dart
// Search drugs by name
List<Drug> searchDrugs(String query)

// Filter drugs by batch number
List<Drug> getDrugsByBatch(String batchNumber)

// Get top prescribed drugs
List<Map<String, dynamic>> getTopPrescribedDrugs({int limit = 5})
```

#### Drug Interactions
```dart
// Check for drug interactions
List<Map<String, dynamic>> checkDrugInteractions(List<String> drugIds)
```

#### Patient Management
```dart
// Add a new patient
void addPatient(Patient patient, {bool persist = false})

// Update patient information
void updatePatient(String patientId, String name, String phone, ...)

// Get patients with prescription count
List<Map<String, dynamic>> getPatientsWithPrescriptionCount()
```

#### Reporting & Analytics
```dart
// Generate comprehensive inventory report
Future<Map<String, dynamic>> generateInventoryReport({String? businessId})

// Calculate drug turnover rate
Map<String, dynamic> calculateDrugTurnover(String drugId, {Duration? period})

// Update drug price
Future<void> updateDrugPrice(String drugId, double newPrice, ...)

// Remove expired drugs
Future<void> removeExpiredDrugs({bool persist = true, String? businessId})
```

### 2. Screens (Presentation Layer)

#### Pharmacy Dashboard
**File**: `lib/presentation/industry_specific/pharmacy/screens/pharmacy_dashboard_enhanced.dart`

Features:
- Real-time inventory metrics
- Prescription analytics
- Alert system (expired, expiring, low stock)
- Top prescribed drugs
- Quick action buttons

#### Drug Inventory Management
**File**: `lib/presentation/industry_specific/pharmacy/screens/drug_inventory_screen.dart`

Features:
- View all drugs with filters (all, low stock, expiring, expired)
- Search functionality
- Add new drugs
- Edit drug information
- View drug details with batch and expiry info
- Status indicators (expired, expiring, low stock, healthy)

#### Prescription Management
**File**: `lib/presentation/industry_specific/pharmacy/screens/prescription_screen.dart`

Features:
- View all prescriptions
- Filter by status (pending, dispensed, cancelled)
- Create new prescriptions
- Dispense prescriptions
- Cancel prescriptions
- Track prescription history

#### Patient Records
**File**: `lib/presentation/industry_specific/pharmacy/screens/patient_records_enhanced.dart`

Features:
- View all patients with prescription counts
- Search and sort patients
- View patient prescription history
- Add new patients
- Edit patient information
- Track patient medication history

#### Expiry Tracking & Alerts
**File**: `lib/presentation/industry_specific/pharmacy/screens/expiry_tracker_enhanced.dart`

Features:
- Real-time alert system for:
  - Expired drugs (critical)
  - Expiring soon (7+ days)
  - Low stock
  - Out of stock
- Action recommendations
- Severity-based color coding
- Quick removal/reorder actions

#### Pharmacy POS/Sales
**File**: `lib/presentation/industry_specific/pharmacy/screens/pharmacy_pos_enhanced.dart`

Features:
- Drug selection and search
- Shopping cart management
- Quantity adjustment
- Real-time total calculation
- Quick checkout
- Transaction history
- Automatic stock deduction

### 3. Data Layer

#### Repository
**File**: `lib/data/repositories/industry_specific/pharmacy_repository_impl.dart`

Operations:
- `fetchDrugs()` - Get drugs from Firestore
- `fetchPrescriptions()` - Get prescriptions
- `fetchPatients()` - Get patient records
- `addPrescription()` - Save prescription
- `syncDrug()` - Sync drug data
- `getExpiringDrugs()` - Query expiring drugs
- `getLowStockDrugs()` - Query low stock drugs
- `logAudit()` - Log pharmacy actions

#### Models
- `DrugModel` - Drug data model
- `PrescriptionModel` - Prescription data model
- `PatientModel` - Patient data model

### 4. Worker Permissions & Configuration
**File**: `lib/presentation/industry_specific/pharmacy/permissions_and_config.dart`

**Roles**:

1. **Pharmacist**
   - View drugs and prescriptions
   - Create and dispense prescriptions
   - Check drug interactions
   - Approve controlled substances
   - View reports

2. **Pharmacy Assistant**
   - View drugs, prescriptions, patients
   - Assist with dispensing
   - Manage inventory
   - Scan barcodes

3. **Pharmacy Manager**
   - Full control over all operations
   - Manage drugs, inventory, workers
   - Generate reports
   - View audit logs

**Controlled Substance Management**:
- Track controlled drugs separately
- Require pharmacist approval
- Audit logging for all controlled substance access

## Integration with Main System

### 1. Business Provider Integration
```dart
// Pharmacy screens use BusinessProvider to get current business context
final business = context.read<BusinessProvider>().currentBusiness;
provider.loadFromRepository(businessId: business?.id);
```

### 2. Worker Integration
- Pharmacy workers authenticated via main auth system
- Role-based permission checking via PharmacyWorkerPermissions
- Audit logging of all worker actions

### 3. Notification System Integration
```dart
// Automatic alerts for critical inventory events
await BusinessNotificationManager.instance.notifyOutOfStock(
  businessId: businessId,
  itemName: drug.name,
);
```

## Firestore Collections

### Pharmacy Drugs
```
Collection: pharmacy_drugs
Document: {drug_id}
{
  "id": "D1",
  "name": "Aspirin",
  "manufacturer": "Batch-001",
  "dosageForm": "Tablet",
  "strength": "500mg",
  "expiryDate": "2025-12-31",
  "stock": 100,
  "price": 5.99,
  "businessId": "{business_id}"
}
```

### Pharmacy Prescriptions
```
Collection: pharmacy_prescriptions
Document: {prescription_id}
{
  "id": "RX-1001",
  "patientId": "P1",
  "drugIds": ["D1", "D2"],
  "issuedAt": "2024-12-06",
  "prescriber": "Dr. Smith",
  "businessId": "{business_id}",
  "status": "pending"
}
```

### Pharmacy Patients
```
Collection: pharmacy_patients
Document: {patient_id}
{
  "id": "P1",
  "name": "John Doe",
  "phone": "0800123456",
  "businessId": "{business_id}"
}
```

### Controlled Substances (Local Hive)
```
Box: pharmacy_controlled
{
  "controlled": ["D1", "D5", "D8"]  // Drug IDs for controlled substances
}
```

## Usage Examples

### Creating a Prescription
```dart
final provider = context.read<PharmacyProvider>();
final prescription = await provider.addPrescription(
  'P1',  // patientId
  [
    {'drugId': 'D1', 'qty': 2},
    {'drugId': 'D2', 'qty': 1},
  ],
  persist: true,
  businessId: businessId,
  userId: currentUserId,
);
```

### Dispensing a Prescription
```dart
await provider.dispensePrescription(
  'RX-1001',
  persist: true,
  businessId: businessId,
  userId: currentUserId,
);
// This automatically:
// - Updates prescription status to 'dispensed'
// - Decrements drug stock
// - Triggers low stock alerts if needed
// - Logs audit trail
```

### Getting Inventory Report
```dart
final report = await provider.generateInventoryReport(
  businessId: businessId,
);
// Returns: stats, lowStockDrugs, expiringDrugs, topDrugs
```

### Checking Drug Interactions
```dart
final interactions = provider.checkDrugInteractions([
  'aspirin',
  'warfarin',
]);
// Returns: list of interactions with severity and description
```

## Features Summary

✅ **Inventory Management**
- Add/edit/delete drugs
- Track stock levels
- Monitor expiry dates
- Automatic alerts for expired/expiring drugs

✅ **Prescription Management**
- Create prescriptions
- Dispense prescriptions
- Track prescription status
- Cancel prescriptions

✅ **Patient Management**
- Maintain patient records
- Track prescription history
- Search and filter patients

✅ **Drug Interactions**
- Check for medication interactions
- Severity-based warnings
- Pharmacist approval for controlled substances

✅ **POS/Sales**
- Quick sales interface
- Shopping cart
- Transaction processing

✅ **Reporting & Analytics**
- Inventory value calculations
- Top prescribed drugs
- Prescription statistics
- Turnover rates

✅ **Audit Trail**
- Log all pharmacy operations
- Track controlled substance access
- Worker action tracking

✅ **Role-Based Access**
- Pharmacist, Assistant, Manager roles
- Permission-based feature access
- Controlled substance oversight

## Error Handling

All methods include proper error handling:
- Try-catch blocks for Firestore operations
- Graceful fallbacks for offline mode
- User-friendly error messages
- Detailed logging for debugging

## Performance Considerations

- **Offline Support**: Uses Hive for local caching
- **Lazy Loading**: Prescriptions loaded on demand
- **Query Optimization**: Firestore queries filtered by businessId
- **Data Pagination**: Large lists are paginated
- **Caching**: Controlled substances cached locally

## Testing

Unit tests available in:
- `test/unit/pharmacy_provider_test.dart`

Tests cover:
- Drug inventory operations
- Prescription creation and dispensing
- Patient management
- Interaction checking
- Controlled substance tracking

## Future Enhancements

- [ ] Barcode scanning for quick drug selection
- [ ] Receipt printing integration
- [ ] Medicine expiry date warnings via SMS
- [ ] Advanced drug interaction database
- [ ] Insurance coverage verification
- [ ] Automated reordering system
- [ ] Medicine compounding support
- [ ] Refrigerated storage tracking

