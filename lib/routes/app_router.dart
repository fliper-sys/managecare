import 'package:flutter/material.dart';
import '../core/constants/routes.dart';
import '../presentation/auth/screens/splash_screen.dart';
import '../presentation/auth/screens/login_screen.dart';
import '../presentation/auth/screens/register_screen.dart';
import '../presentation/auth/screens/business_selection_screen.dart';
import '../presentation/auth/screens/business_details_screen.dart';
import '../presentation/auth/screens/forgot_password_screen.dart';
import '../presentation/auth/screens/restricted_business_screen.dart';
import '../presentation/auth/screens/subscription_payment_screen.dart';
import '../presentation/auth/screens/subscription_status_screen.dart';
import '../presentation/dashboard/owner/owner_dashboard_screen.dart';
import '../presentation/dashboard/owner/product_installation_screen.dart';
import '../presentation/dashboard/owner/installation_receipt_upload_screen.dart';
import '../presentation/dashboard/worker/worker_dashboard_screen.dart';
import '../presentation/dashboard/analytics/advanced_analytics_dashboard_screen.dart';
import '../presentation/industry_specific/gas/screens/gas_dashboard_screen.dart';
import '../presentation/industry_specific/gas/screens/gas_pump_screen.dart';
import '../presentation/industry_specific/gas/screens/gas_sales_history_screen.dart';
import '../presentation/industry_specific/gas/screens/gas_stock_screen.dart';
import '../presentation/industry_specific/wholesale/screens/warehouse_reports_screen.dart';
import '../presentation/inventory/screens/product_details_screen.dart';
import '../presentation/reports/screens/aggregated_reports_screen.dart';
import '../presentation/business/screens/business_switcher_screen.dart';
import '../presentation/sales/screens/sales_screen.dart';
import '../presentation/sales/screens/sales_history_screen.dart';
import '../presentation/inventory/screens/inventory_list_screen.dart';
import '../presentation/inventory/screens/low_stock_products_screen.dart';
import '../presentation/inventory/screens/add_inventory_screen.dart';
import '../presentation/inventory/screens/edit_inventory_screen.dart';
import '../presentation/customers/screens/customer_list_screen.dart';
import '../presentation/customers/screens/add_customer_screen.dart';
import '../presentation/customers/screens/customer_details_screen.dart';
import '../presentation/reports/screens/reports_dashboard_screen.dart';
import '../presentation/reports/screens/financial_report_screen.dart';
import '../presentation/reports/screens/sales_report_screen.dart';
import '../presentation/reports/screens/inventory_report_screen.dart';
import '../presentation/reports/screens/expense_report_screen.dart';
import '../presentation/reports/screens/export_report_screen.dart';
import '../presentation/reports/screens/customer_report_screen.dart';
import '../presentation/settings/screens/settings_screen.dart';

import '../presentation/notifications/screens/notifications_screen.dart';
import '../presentation/settings/screens/profile_screen.dart';
import '../presentation/settings/screens/business_settings_screen.dart';
import '../presentation/settings/screens/whatsapp_settings_screen.dart';
import '../presentation/settings/screens/notification_logs_screen.dart';
import '../presentation/settings/screens/thermal_receipt_settings_screen.dart';
import '../presentation/settings/screens/printer_settings_screen.dart';
import '../presentation/settings/screens/subscription_screen.dart';
import '../presentation/settings/screens/tax_settings_screen.dart';

// Restaurant screens
import '../presentation/industry_specific/restaurant/screens/manage_tables_screen.dart';
import '../presentation/industry_specific/restaurant/screens/manage_staff_screen.dart';
import '../presentation/industry_specific/restaurant/screens/reservations_screen.dart';
import '../presentation/settings/screens/export_sales_history_screen.dart';
import '../presentation/auth/screens/admin_login_screen.dart';
import '../app_admin/app_admin_dashboard_screen.dart';
import '../app_admin/dunning_status_screen.dart';
import '../widgets/error_widget.dart' as custom;
import '../presentation/admin/installation_requests_admin_screen.dart';
import '../presentation/dashboard/owner/my_installation_requests_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/prescription_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/prescription_detail_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/add_prescription_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/drug_inventory_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/expiry_tracker_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/patient_records_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/pharmacy_pos_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/pharmacy_dashboard.dart';
import '../presentation/industry_specific/pharmacy/screens/add_edit_drug_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/pharmacy_sales_history_screen.dart';
import '../presentation/industry_specific/pharmacy/screens/pharmacy_sales_report_screen.dart';

import '../presentation/industry_specific/retail/screens/pos_screen.dart';
import '../presentation/industry_specific/retail/screens/product_catalog_screen.dart';
import '../presentation/industry_specific/retail/screens/supplier_management_screen.dart';
import '../presentation/industry_specific/retail/screens/multi_store_screen.dart';
import '../presentation/industry_specific/retail/screens/promotions_screen.dart';
import '../presentation/industry_specific/retail/screens/wholesale_orders_screen.dart';
import '../presentation/industry_specific/retail/screens/product_management_screen.dart';
import '../presentation/industry_specific/retail/screens/add_product_screen.dart';
import '../presentation/industry_specific/retail/screens/add_supplier_screen.dart';
import '../presentation/industry_specific/retail/screens/retail_dashboard.dart';
import '../presentation/industry_specific/retail/screens/store_reports_screen.dart';
import '../presentation/industry_specific/wholesale/screens/warehouse_dashboard_screen.dart';
import '../presentation/industry_specific/wholesale/screens/warehouses_screen.dart';
import '../presentation/industry_specific/wholesale/screens/inventory_management_screen.dart';
import '../presentation/industry_specific/wholesale/screens/warehouse_pos_screen.dart';
import '../presentation/industry_specific/wholesale/screens/purchase_orders_screen.dart';
import '../presentation/industry_specific/wholesale/screens/stock_transfers_screen.dart';

import '../presentation/sales/screens/receipt_screen.dart';
import '../presentation/sales/screens/sales_receipt_loader_screen.dart';

import '../presentation/industry_specific/agri/screens/agri_dashboard.dart';
import '../presentation/industry_specific/agri/screens/farm_inventory_screen.dart';
import '../presentation/industry_specific/agri/screens/crop_orders_screen.dart';
import '../presentation/industry_specific/agri/screens/livestock_screen.dart';
import '../presentation/industry_specific/agri/screens/add_livestock_screen.dart';

import '../presentation/industry_specific/auto/screens/auto_dashboard_screen.dart';
import '../presentation/industry_specific/auto/screens/repair_jobs_screen.dart';
import '../presentation/industry_specific/auto/screens/create_service_order_screen.dart';
import '../presentation/industry_specific/auto/screens/parts_inventory_screen.dart';
import '../presentation/industry_specific/auto/screens/bookings_screen.dart'
    as auto_bookings;
import '../presentation/industry_specific/auto/screens/invoices_screen.dart';
import '../presentation/industry_specific/auto/screens/mechanic_schedule_screen.dart';

import '../presentation/industry_specific/barber_shop/screens/barber_shop_dashboard_screen.dart';
import '../presentation/industry_specific/barber_shop/screens/barber_shop_appointments_screen.dart';
import '../presentation/industry_specific/barber_shop/screens/barber_shop_services_screen.dart';
import '../presentation/industry_specific/barber_shop/screens/barber_shop_payments_screen.dart';
import '../presentation/industry_specific/barber_shop/screens/barber_shop_sales_history_screen.dart';
import '../presentation/industry_specific/barber_shop/screens/barber_commission_screen.dart';

import '../presentation/industry_specific/salon/screens/salon_dashboard_screen.dart';
import '../presentation/industry_specific/salon/screens/salon_appointments_screen.dart';
import '../presentation/industry_specific/salon/screens/salon_services_screen.dart';
import '../presentation/industry_specific/salon/screens/salon_staff_management_screen.dart';
import '../presentation/industry_specific/salon/screens/commission_screen.dart';
import '../presentation/industry_specific/salon/screens/commission_tracker_screen.dart';

import '../presentation/industry_specific/hotel/screens/hotel_dashboard_screen.dart';
import '../presentation/industry_specific/hotel/screens/room_list_screen.dart';
import '../presentation/industry_specific/hotel/screens/create_room_screen.dart';
import '../presentation/industry_specific/hotel/screens/bookings_screen.dart'
    as hotel_bookings;
import '../presentation/industry_specific/hotel/screens/check_in_screen.dart';
import '../presentation/industry_specific/hotel/screens/check_out_screen.dart';
import '../presentation/industry_specific/hotel/screens/front_desk_screen.dart';
import '../presentation/industry_specific/hotel/screens/guest_management_screen.dart';
import '../presentation/industry_specific/hotel/screens/housekeeping_screen.dart';
import '../presentation/industry_specific/hotel/screens/billing_screen.dart';
import '../presentation/industry_specific/hotel/screens/hall_bookings_screen.dart';
import '../presentation/industry_specific/hotel/screens/pool_bookings_screen.dart';

import '../presentation/industry_specific/drink/screens/drink_dashboard_screen.dart';
import '../presentation/industry_specific/drink/screens/drink_orders_history_screen.dart';
import '../presentation/industry_specific/drink/screens/inventory_screen.dart';
import '../presentation/industry_specific/drink/screens/bottle_tracking_screen.dart';
import '../presentation/industry_specific/drink/screens/bar_tabs_screen.dart';
import '../presentation/industry_specific/drink/screens/distribution_orders_screen.dart';
import '../presentation/industry_specific/drink/screens/bar_pos_screen.dart';
import '../presentation/industry_specific/drink/screens/pos_orders_screen.dart';
import '../presentation/industry_specific/drink/screens/drink_management_screen.dart';

// Gym screens
import '../presentation/industry_specific/gym/screens/gym_dashboard_screen.dart';
import '../presentation/industry_specific/gym/screens/memberships_screen.dart';
import '../presentation/industry_specific/gym/screens/class_schedule_screen.dart';
import '../presentation/industry_specific/gym/screens/member_detail_screen.dart';
import '../presentation/industry_specific/gym/screens/trainer_management_screen.dart';
import '../presentation/industry_specific/gym/screens/gym_calendar_screen.dart';
import '../presentation/industry_specific/gym/screens/equipment_management_screen.dart';
import '../presentation/industry_specific/gym/screens/attendance_tracking_screen.dart';
import '../presentation/industry_specific/gym/screens/member_progress_screen.dart';

import '../presentation/industry_specific/restaurant/screens/restaurant_owner_dashboard.dart';
import '../presentation/industry_specific/restaurant/screens/create_order_screen.dart';
import '../presentation/industry_specific/restaurant/screens/kitchen_orders_screen.dart';
import '../presentation/industry_specific/restaurant/screens/manage_menu_screen.dart';
import '../presentation/industry_specific/restaurant/screens/pending_orders_checkout_screen.dart';
import '../presentation/industry_specific/restaurant/screens/restaurant_stock_screen.dart';


import '../presentation/industry_specific/realestate/screens/realestate_dashboard_screen.dart';
import '../presentation/industry_specific/realestate/screens/property_listings_screen.dart';
import '../presentation/industry_specific/realestate/screens/property_details_screen.dart';
import '../presentation/industry_specific/realestate/screens/add_property_screen.dart';
import '../presentation/industry_specific/realestate/screens/tenant_management_enhanced_screen.dart';
import '../presentation/industry_specific/realestate/screens/lease_management_screen.dart';
import '../presentation/industry_specific/realestate/screens/rent_collection_screen.dart';
import '../presentation/industry_specific/realestate/screens/tenant_rent_history_screen.dart';
import '../presentation/industry_specific/realestate/screens/property_rent_history_screen.dart';
import '../presentation/industry_specific/realestate/screens/create_ticket_screen.dart';
import '../presentation/industry_specific/realestate/screens/maintenance_screen.dart';
import '../presentation/industry_specific/realestate/screens/property_documents_screen.dart';
import '../presentation/industry_specific/apartment/screens/apartment_dashboard_screen.dart';
import '../presentation/industry_specific/apartment/screens/unit_management_screen.dart';
import '../presentation/industry_specific/apartment/screens/booking_list_screen.dart';
import '../presentation/industry_specific/apartment/screens/booking_form_screen.dart';
import '../data/models/apartment_model.dart';

// Workers screens
import '../presentation/workers/screens/workers_list_screen.dart';
import '../presentation/marketer/marketer_dashboard_screen.dart';
import '../presentation/marketer/marketer_login_screen.dart';
import '../presentation/marketer/marketer_forgot_password_screen.dart';
import '../presentation/marketer/marketer_change_password_screen.dart';
import '../presentation/marketer/register_user_screen.dart';
import '../presentation/marketer/register_business_screen.dart';
import '../presentation/workers/screens/add_worker_screen.dart';
import '../presentation/workers/screens/worker_details_screen.dart';
import '../presentation/workers/screens/attendance_screen.dart';
import '../presentation/workers/screens/payroll_screen.dart';
import '../presentation/workers/screens/worker_sales_screen.dart';
import '../presentation/workers/screens/worker_inventory_screen.dart';

// Loyalty screens
import '../presentation/loyalty/screens/loyalty_dashboard_screen.dart';

// Batch Operations screens
import '../presentation/batch_operations/screens/batch_operations_screen.dart';

// Procurement screens
import '../presentation/dashboard/owner/screens/procurement_screen.dart';
import '../presentation/dashboard/owner/screens/procurement_history_screen.dart';

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth Routes
      case Routes.splash:
        return _buildRoute(const SplashScreen());

      case Routes.login:
        return _buildRoute(const LoginScreen());

      case Routes.register:
        return _buildRoute(const RegisterScreen());

      case Routes.businessSelection:
        return _buildRoute(BusinessSelectionScreen());

      case Routes.businessDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(BusinessDetailsScreen(
          businessType: args?['businessType'] ?? '',
        ));

      case Routes.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen());

      case Routes.restrictedBusiness:
        final args = settings.arguments as Map<String, dynamic>? ?? const {};
        return _buildRoute(
          RestrictedBusinessScreen(
            businessName: args['businessName']?.toString() ?? 'This business',
            restrictionReason:
                args['restrictionReason']?.toString() ?? '',
            customerCareWhatsapp:
                args['customerCareWhatsapp']?.toString() ?? '',
          ),
        );

      case Routes.subscriptionPayment:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(SubscriptionPaymentScreen(
          userId: args?['userId'] ?? '',
          userEmail: args?['userEmail'] ?? '',
          userName: args?['userName'] ?? '',
          businessId: args?['businessId'] as String?,
          businessType: args?['businessType'] as String?,
          businessTier: args?['businessTier'] as String?,
          businessClass: args?['businessClass'] as String?,
        ));

      case '/subscription-status':
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(SubscriptionStatusScreen(
          userId: args?['userId'] ?? '',
          userEmail: args?['userEmail'] ?? '',
          userName: args?['userName'] ?? '',
          businessId: args?['businessId'] as String?,
          businessType: args?['businessType'] as String?,
          subscriptionPlan: args?['subscriptionPlan'] ?? 'tier1',
          subscriptionAmount:
              (args?['subscriptionAmount'] as num?)?.toDouble() ?? 0.0,
        ));

      // Dashboard Routes
      case Routes.ownerDashboard:
        return _buildRoute(const OwnerDashboardScreen());

      case Routes.workerDashboard:
        return _buildRoute(const WorkerDashboardScreen());

      // Common Routes
      case Routes.sales:
        return _buildRoute(const SalesScreen());

      case Routes.salesHistory:
        return _buildRoute(const SalesHistoryScreen());

      case Routes.productInstallation:
        return _buildRoute(const ProductInstallationScreen());

      case Routes.installationReceiptUpload:
        return _buildRoute(const InstallationReceiptUploadScreen());

      case Routes.inventory:
        return _buildRoute(const InventoryListScreen());

      case Routes.productDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(ProductDetailsScreen(
          productId: args?['productId'] ?? '',
        ));

      case Routes.lowStockProducts:
        return _buildRoute(const LowStockProductsScreen());

      case Routes.inventoryAdd:
        return _buildRoute(const AddInventoryScreen());

      case Routes.inventoryEdit:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(EditInventoryScreen(
          inventoryId: args?['productId'] ?? args?['inventoryId'] ?? '',
        ));

      case Routes.customers:
        return _buildRoute(const CustomerListScreen());

      case Routes.customersAdd:
        return _buildRoute(const AddCustomerScreen());

      case Routes.customerDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(CustomerDetailsScreen(
          customerId: args?['customerId'] ?? '',
        ));

      case Routes.loyaltyDashboard:
        return _buildRoute(const LoyaltyDashboardScreen());

      case Routes.reports:
        return _buildRoute(const ReportsDashboardScreen());

      case Routes.aggregatedReports:
        return _buildRoute(const AggregatedReportsScreen());
      case Routes.businessSwitcher:
        return _buildRoute(const BusinessSwitcherScreen());

      case Routes.advancedAnalytics:
        return _buildRoute(const AdvancedAnalyticsDashboardScreen());

      case Routes.financialReport:
        return _buildRoute(const FinancialReportScreen());

      case Routes.salesReport:
        return _buildRoute(const SalesReportScreen());

      case Routes.inventoryReport:
        return _buildRoute(const InventoryReportScreen());

      case Routes.expenseReport:
        return _buildRoute(const ExpenseReportScreen());

      case Routes.exportReport:
        return _buildRoute(const ExportReportScreen());

      case Routes.customerReport:
        return _buildRoute(const CustomerReportScreen());

      case Routes.settings:
        return _buildRoute(const SettingsScreen());

      case Routes.profile:
        return _buildRoute(const ProfileScreen());

      case Routes.businessSettings:
        return _buildRoute(const BusinessSettingsScreen());

      case Routes.subscription:
        return _buildRoute(const SubscriptionScreen());

      case Routes.taxSettings:
        return _buildRoute(const TaxSettingsScreen());

      case Routes.exportSalesHistory:
        return _buildRoute(const ExportSalesHistoryScreen());

      case Routes.notifications:
        return _buildRoute(const NotificationsScreen());

      case Routes.whatsappSettings:
        return _buildRoute(const WhatsAppSettingsScreen());

      case Routes.notificationLogs:
        return _buildRoute(const NotificationLogsScreen());

      case Routes.thermalReceiptSettings:
        return _buildRoute(const ThermalReceiptSettingsScreen());

      case Routes.printerSettings:
        return _buildRoute(const PrinterSettingsScreen());

      case Routes.procurement:
        return _buildRoute(const ProcurementScreen());

      case Routes.procurementHistory:
        return _buildRoute(const ProcurementHistoryScreen());

      case Routes.adminDunning:
        return _buildRoute(const DunningStatusScreen());

      case Routes.adminSubscriptions:
        return _buildRoute(const AdminDashboardApp(initialIndex: 2));

      case Routes.adminPayments:
        return _buildRoute(const AdminDashboardApp(initialIndex: 2));

      case Routes.adminPaymentsApproval:
        return _buildRoute(const AdminDashboardApp(initialIndex: 2));

      case Routes.allBusinessesAdmin:
        return _buildRoute(const AdminDashboardApp(initialIndex: 1));

      case Routes.adminUsersAndWorkers:
        return _buildRoute(const AdminDashboardApp(initialIndex: 3));

      case Routes.adminDashboard:
        return _buildRoute(const AdminDashboardApp());

      case Routes.batchOperations:
        return _buildRoute(const BatchOperationsScreen());

      case Routes.installationRequestsAdmin:
        return _buildRoute(const InstallationRequestsAdminScreen());

      case Routes.installationRequestsMy:
        return _buildRoute(const MyInstallationRequestsScreen());

      // Workers Routes
      case Routes.workers:
        return _buildRoute(const WorkersListScreen());

      case Routes.workersAdd:
        return _buildRoute(const AddWorkerScreen());

      case Routes.workerDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(WorkerDetailsScreen(
          workerId: args?['id'] ?? '',
          businessId: args?['businessId'] ?? '',
          businessType: args?['businessType'] ?? '',
        ));

      case Routes.attendance:
        return _buildRoute(const AttendanceScreen());

      case Routes.payroll:
        return _buildRoute(const PayrollScreen());

      case Routes.workerSales:
        return _buildRoute(const WorkerSalesScreen());

      case Routes.workerInventory:
        return _buildRoute(const WorkerInventoryScreen());

      case Routes.adminLogin:
        return _buildRoute(const AdminLoginScreen());

      case Routes.marketerLogin:
        return _buildRoute(const MarketerLoginScreen());

      case Routes.marketerForgotPassword:
        return _buildRoute(const MarketerForgotPasswordScreen());

      case Routes.marketerChangePassword:
        return _buildRoute(const MarketerChangePasswordScreen());

      case Routes.marketerRegisterUser:
        return _buildRoute(const RegisterUserScreen());

      case Routes.marketerRegisterBusiness:
        final marketerArgs = settings.arguments;
        if (marketerArgs is String) {
          return _buildRoute(RegisterBusinessScreen(userId: marketerArgs));
        }
        if (marketerArgs is Map<String, dynamic>) {
          return _buildRoute(
            RegisterBusinessScreen(
              userId: marketerArgs['userId'] ?? '',
              userEmail: marketerArgs['userEmail'] as String?,
              ownerName: marketerArgs['ownerName'] as String?,
            ),
          );
        }
        return _buildRoute(
          const Scaffold(
            body: Center(child: Text('Missing marketer registration details')),
          ),
        );

      case Routes.marketerDashboard:
        return _buildRoute(const MarketerDashboardScreen());

      // Receipt Routes
      case Routes.receipt:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(ReceiptScreen(
          sale: args ?? {},
          isSubscriptionReceipt: args?['isSubscriptionReceipt'] ?? false,
          isInvoice: args?['isInvoice'] ?? false,
        ));

      case Routes.salesReceipt:
        // Accept multiple argument shapes: Map with 'saleId', 'orderId', 'receiptId', a full sale Map, or a plain String id
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          // If a full sale map was passed (contains items), show ReceiptScreen directly to avoid Firestore race
          if (args.containsKey('items') && (args.containsKey('id') || args.containsKey('saleId') || args.containsKey('orderId'))) {
            final saleMap = args.containsKey('id') ? args : ({
              'id': args['saleId'] ?? args['orderId'] ?? args['id'],
              ...args,
            });
            return _buildRoute(ReceiptScreen(sale: saleMap, isSubscriptionReceipt: false, isInvoice: false));
          }
          final saleId = (args['saleId'] ?? args['orderId'] ?? args['receiptId'] ?? args['id']) as String? ?? '';
          return _buildRoute(SalesReceiptLoaderScreen(saleId: saleId));
        } else if (args is String) {
          return _buildRoute(SalesReceiptLoaderScreen(saleId: args));
        }
        return _buildRoute(const Scaffold(body: Center(child: Text('Invalid sale reference'))));

      case Routes.retailReceipt:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(ReceiptScreen(
          sale: args ?? {},
          isSubscriptionReceipt: false,
          isInvoice: false,
        ));

      // Industry Specific Routes - Pharmacy
      case Routes.pharmacyDashboard:
        return _buildRoute(const PharmacyDashboard());

      case Routes.pharmacyPrescriptions:
        return _buildRoute(const PrescriptionScreen());

      case Routes.pharmacyViewPrescription:
        final args = settings.arguments as String?;
        return _buildRoute(
            PrescriptionDetailScreen(prescriptionId: args ?? ''));

      case Routes.pharmacyPos:
        return _buildRoute(const PharmacyPosScreen());

      case Routes.pharmacyAddPrescription:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(AddPrescriptionScreen(
          patientId: args?['patientId']?.toString(),
          patientName: args?['patientName']?.toString(),
        ));

      case Routes.pharmacyDrugInventory:
        return _buildRoute(const DrugInventoryScreen());

      case Routes.pharmacyExpiryTracker:
        return _buildRoute(const ExpiryTrackerScreen());

      case Routes.pharmacyPatients:
        return _buildRoute(const PatientRecordsScreen());

      case Routes.pharmacyAddDrug:
        return _buildRoute(const AddEditDrugScreen());

      case Routes.pharmacyEditDrug:
        final drugId = settings.arguments as String?;
        return _buildRoute(AddEditDrugScreen(drugId: drugId));

      case Routes.pharmacyDrugDetails:
        final drugId = settings.arguments as String?;
        return _buildRoute(AddEditDrugScreen(drugId: drugId));

      case Routes.pharmacySalesHistory:
        return _buildRoute(const PharmacySalesHistoryScreen());

      case Routes.pharmacySalesReport:
        return _buildRoute(const PharmacySalesReportScreen());

      // Industry Specific Routes - Retail
      case Routes.retailDashboard:
        return _buildRoute(const RetailDashboard());

      case Routes.wholesaleDashboard:
        return _buildRoute(const WarehouseDashboardScreen());

      case Routes.retailPos:
        return _buildRoute(const PosScreen());

      case Routes.retailCatalog:
        return _buildRoute(const ProductCatalogScreen());

      case Routes.retailSuppliers:
        return _buildRoute(const SupplierManagementScreen());

      case Routes.retailStores:
        return _buildRoute(const MultiStoreScreen());

      case Routes.wholesaleWarehouses:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(WarehousesScreen(openAdd: args?['openAdd'] == true));

      case Routes.wholesaleInventory:
        return _buildRoute(const InventoryManagementScreen());

      case Routes.wholesalePos:
        return _buildRoute(const WarehousePosScreen());

      case Routes.wholesalePurchaseOrders:
        return _buildRoute(const PurchaseOrdersScreen());

      case Routes.wholesaleTransfers:
        return _buildRoute(const StockTransfersScreen());

      case Routes.wholesaleReports:
        return _buildRoute(const WarehouseReportsScreen());

      case Routes.retailStoreReports:
        return _buildRoute(const StoreReportsScreen());

      case Routes.retailPromotions:
        return _buildRoute(const PromotionsScreen());

      case Routes.retailWholesale:
        return _buildRoute(const WholesaleOrdersScreen());

      case Routes.retailProducts:
        return _buildRoute(const ProductManagementScreen());

      case Routes.retailAddProduct:
        return _buildRoute(const AddProductScreen());

      case Routes.retailAddSupplier:
        return _buildRoute(const AddSupplierScreen());

      // Industry Specific Routes - Agriculture
      case Routes.agriDashboard:
        return _buildRoute(const AgriDashboardScreen());

      case Routes.agriFarms:
        return _buildRoute(const FarmInventoryScreen());

      case Routes.agriCrops:
        return _buildRoute(const CropOrdersScreen());

      case Routes.agriLivestock:
        return _buildRoute(const LivestockScreen());

      case Routes.agriAddLivestock:
        return _buildRoute(const AddLivestockScreen());

      // Industry Specific Routes - Auto
      case Routes.autoDashboard:
        return _buildRoute(const AutoDashboardScreen());

      case Routes.autoServiceOrders:
        return _buildRoute(const RepairJobsScreen());

      case Routes.autoCreateServiceOrder:
        return _buildRoute(const CreateServiceOrderScreen());

      case Routes.autoPartsInventory:
        return _buildRoute(const PartsInventoryScreen());

      case Routes.autoMechanicSchedule:
        return _buildRoute(const MechanicScheduleScreen());

      case Routes.autoBookings:
        return _buildRoute(const auto_bookings.BookingsScreen());

      case Routes.autoInvoices:
        return _buildRoute(const InvoicesScreen());

      case Routes.autoJobCards:
        return _buildRoute(const RepairJobsScreen());

      // Industry Specific Routes - Barbershop
      case Routes.barberShopDashboard:
        return _buildRoute(const BarberShopDashboardScreen());

      case Routes.barberShopAppointments:
        return _buildRoute(const BarberShopAppointmentsScreen());

      case Routes.barberShopServices:
        return _buildRoute(const BarberShopServicesScreen());

      case Routes.barberShopCreateService:
        return _buildRoute(const BarberShopServicesScreen(openCreate: true));

      case Routes.barberShopPayments:
        return _buildRoute(const BarberShopPaymentsScreen());

      case Routes.barberCommission:
        return _buildRoute(const BarberCommissionScreen());

      case Routes.barberShopSalesHistory:
        return _buildRoute(const BarberShopSalesHistoryScreen());

      // Industry Specific Routes - Salon
      case Routes.salonDashboard:
        return _buildRoute(const SalonDashboardScreen());

      case Routes.salonAppointments:
        return _buildRoute(const SalonAppointmentsScreen());

      case Routes.salonServices:
        return _buildRoute(const SalonServicesScreen());

      case Routes.salonStylists:
        return _buildRoute(const SalonStaffManagementScreen());

      case Routes.salonCommission:
        return _buildRoute(const CommissionScreen());
      case Routes.salonCommissionTracker:
        return _buildRoute(const CommissionTrackerScreen());

      // Industry Specific Routes - Hotel
      case Routes.hotelDashboard:
        return _buildRoute(const HotelDashboardScreen());

      case Routes.hotelRooms:
        return _buildRoute(const RoomListScreen());

      case Routes.hotelCreateRoom:
        return _buildRoute(const CreateRoomScreen());

      case Routes.hotelBookings:
        return _buildRoute(const hotel_bookings.BookingsScreen());

      case Routes.hotelCheckIn:
        return _buildRoute(const CheckInScreen());

      case Routes.hotelCheckOut:
        return _buildRoute(const CheckOutScreen());

      case Routes.hotelFrontDesk:
        return _buildRoute(const FrontDeskScreen());

      case Routes.hotelRestaurant:
        return _buildRoute(const RestaurantDashboardScreen());

      case Routes.hotelBar:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(BarPosScreenDrink(
          invoiceId: args?['invoiceId']?.toString(),
        ));

      case Routes.hotelGuests:
        return _buildRoute(const GuestManagementScreen());

      case Routes.hotelHousekeeping:
        return _buildRoute(const HousekeepingScreen());

      case Routes.hotelBilling:
        return _buildRoute(const BillingScreen());

      case Routes.hotelHallBookings:
        return _buildRoute(const HallBookingsScreen());

      case Routes.hotelPoolBookings:
        return _buildRoute(const PoolBookingsScreen());

      // Industry Specific Routes - Drink
      case Routes.drinkDashboard:
        return _buildRoute(const DrinkDashboardScreen());

      case Routes.drinkInventory:
        return _buildRoute(const DrinkInventoryScreen());

      case Routes.drinkBottleTracking:
        return _buildRoute(const BottleTrackingScreen());

      case Routes.drinkPos:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(BarPosScreenDrink(
          invoiceId: args?['invoiceId']?.toString(),
        ));

      case Routes.drinkTabs:
        return _buildRoute(const BarTabsScreen());

      case Routes.drinkMenu:
        return _buildRoute(const DistributionOrdersScreen());

      case Routes.drinkOrders:
        return _buildRoute(const POSOrdersScreen());

      case Routes.drinkOrdersHistory:
        return _buildRoute(const DrinkOrdersHistoryScreen());

      case Routes.drinkManage:
        return _buildRoute(const DrinkManagementScreen());

      // Industry Specific Routes - Gym
      case Routes.gymDashboard:
        return _buildRoute(const GymDashboardScreen());

      case Routes.gymMemberships:
        return _buildRoute(const MembershipsScreen());

      case Routes.gymClasses:
        return _buildRoute(const ClassScheduleScreen());

      case Routes.gymCalendar:
        return _buildRoute(const GymCalendarScreen());

      case Routes.gymEquipment:
        return _buildRoute(const EquipmentManagementScreen());

      case Routes.gymAttendance:
        return _buildRoute(const AttendanceTrackingScreen());

      case Routes.gymMemberProgress:
        final args = settings.arguments as Map<String, dynamic>?;
        final memberId = args?['memberId'] as String?;
        if (memberId != null) {
          return _buildRoute(MemberProgressScreen(memberId: memberId));
        }
        return _buildRoute(const Scaffold(
          body: Center(child: Text('Member ID required')),
        ));

      case Routes.gymMembers:
        // fallback to dashboard for full members list for now
        return _buildRoute(const GymDashboardScreen());

      case Routes.gymMemberDetails:
        final args = settings.arguments as String?;
        return _buildRoute(MemberDetailScreen(memberId: args ?? ''));

      case Routes.gymTrainers:
        return _buildRoute(const TrainerManagementScreen());

      // Industry Specific Routes - Restaurant
      case Routes.restaurantDashboard:
        return _buildRoute(const RestaurantDashboardScreen());

      case Routes.restaurantMenu:
        return _buildRoute(const CreateOrderScreen());

      case Routes.restaurantManageMenu:
        return _buildRoute(const ManageMenuScreen());

      case Routes.restaurantStock:
        return _buildRoute(const RestaurantStockScreen());

      case Routes.restaurantOrders:
        return _buildRoute(const PendingOrdersAndCheckoutScreen());

      case Routes.restaurantReservations:
        return _buildRoute(const ReservationsScreen());

      case Routes.restaurantTables:
        return _buildRoute(const ManageTablesScreen());

      case Routes.restaurantWaiters:
        return _buildRoute(const ManageStaffScreen());

      case Routes.restaurantKitchen:
        return _buildRoute(const KitchenOrdersScreen());

      case Routes.gasDashboard:
        return _buildRoute(const GasDashboardScreen());

      case Routes.gasPump:
        return _buildRoute(const GasPumpScreen());

      case Routes.gasStock:
        return _buildRoute(const GasStockScreen());

      case Routes.gasSalesHistory:
        return _buildRoute(const GasSalesHistoryScreen());

      case '/restaurant/history':
        return _buildRoute(const PendingOrdersAndCheckoutScreen());

      // Industry Specific Routes - Real Estate
      case Routes.realEstateDashboard:
        return _buildRoute(const RealestateDashboardScreen());

      case Routes.realEstateProperties:
        return _buildRoute(const PropertyListingsScreen());

      case Routes.realEstatePropertyDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
            PropertyDetailsScreen(propertyId: args?['id'] ?? ''));

      case Routes.realEstateTenants:
        return _buildRoute(const TenantManagementScreenEnhanced());

      case Routes.realEstateLeases:
        return _buildRoute(const LeaseManagementScreenEnhanced());

      case Routes.realEstateRentCollection:
        return _buildRoute(const RentCollectionScreen());

      case Routes.realEstateTenantRentHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
            TenantRentHistoryScreen(tenantId: args?['tenantId'] ?? ''));

      case Routes.realEstatePropertyRentHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
            PropertyRentHistoryScreen(propertyId: args?['propertyId'] ?? ''));

      case Routes.realEstateMaintenance:
        return _buildRoute(const MaintenanceScreen());

      case Routes.realEstateAddProperty:
        return _buildRoute(const AddPropertyScreen());

      case Routes.realEstateCreateTicket:
        return _buildRoute(const CreateTicketScreen());

      case Routes.realEstateDocuments:
        return _buildRoute(const PropertyDocumentsScreen());

      // Industry Specific Routes - Apartment
      case Routes.apartmentDashboard:
        return _buildRoute(const ApartmentDashboardScreen());

      case Routes.apartmentUnits:
        final apartment = settings.arguments;
        if (apartment is Apartment) {
          return _buildRoute(UnitManagementScreen(apartment: apartment));
        }
        return _buildRoute(const Scaffold(
          body: Center(child: Text('Apartment details required')),
        ));

      case Routes.apartmentBookings:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          BookingListScreen(apartmentId: args?['apartmentId'] as String?),
        );

      case Routes.apartmentCreateBooking:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          BookingFormScreen(apartmentId: args?['apartmentId'] as String?),
        );

      default:
        return _buildRoute(
          custom.CustomErrorWidget(
            message: 'Route not found: ${settings.name}',
          ),
        );
    }
  }

  MaterialPageRoute _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  // placeholder helper removed; routes now point to real screens

  void dispose() {
    // Cleanup if needed
  }
}

