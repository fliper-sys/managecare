class Routes {
  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String businessSelection = '/business-selection';
  static const String businessDetails = '/business-details';
  static const String forgotPassword = '/forgot-password';
  static const String subscriptionSelection = '/subscription-selection';
  static const String subscriptionPayment = '/subscription-payment';

  // Dashboard Routes
  static const String ownerDashboard = '/owner-dashboard';
  static const String workerDashboard = '/worker-dashboard';

  // Common Routes
  static const String sales = '/sales';
  static const String salesHistory = '/sales/history';
  static const String salesReceipt = '/sales/receipt';
  static const String cart = '/sales/cart';
  static const String checkout = '/sales/checkout';

  // Receipt Routes
  static const String receipt = '/receipt';
  static const String retailReceipt = '/retail/receipt';

  // Worker-specific quick routes
  static const String workerSales = '/worker/sales';
  static const String workerInventory = '/worker/inventory';

  static const String inventory = '/inventory';
  static const String inventoryAdd = '/inventory/add';
  static const String inventoryEdit = '/inventory/edit';
  static const String inventorySearch = '/inventory/search';
  static const String productDetails = '/inventory/product-details';
  static const String stockAlert = '/inventory/stock-alert';
  static const String inventoryAlerts = '/inventory/alerts';
  static const String lowStockProducts = '/inventory/low-stock';

  static const String customers = '/customers';
  static const String customersAdd = '/customers/add';
  static const String customerDetails = '/customers/details';
  static const String loyalty = '/customers/loyalty';
  static const String loyaltyDashboard = '/loyalty/dashboard';

  static const String reports = '/reports';
  static const String salesReport = '/reports/sales';
  static const String inventoryReport = '/reports/inventory';
  static const String customerReport = '/reports/customers';
  static const String financialReport = '/reports/financial';
  static const String expenseReport = '/reports/expense';
  static const String exportReport = '/reports/export';
  static const String advancedAnalytics = '/analytics/advanced';
  static const String aggregatedReports = '/reports/aggregated';
  static const String businessSwitcher = '/business/switch';
  static const String batchOperations = '/batch-operations';

  static const String workers = '/workers';
  static const String workersAdd = '/workers/add';
  static const String workerDetails = '/workers/details';
  static const String workerLeaderboard = '/workers/leaderboard';
  static const String attendance = '/workers/attendance';
  static const String payroll = '/workers/payroll';

  static const String settings = '/settings';
  static const String businessSettings = '/settings/business';
  static const String subscription = '/settings/subscription';
  static const String printerSettings = '/settings/printer';
  static const String taxSettings = '/settings/tax';
  static const String profile = '/settings/profile';
  static const String exportSalesHistory = '/settings/export-sales';

  static const String notifications = '/notifications';
  static const String procurement = '/procurement';
  static const String procurementHistory = '/procurement/history';
  static const String whatsappSettings = '/settings/whatsapp';
  static const String notificationLogs = '/settings/notification-logs';
  static const String thermalReceiptSettings = '/settings/thermal-receipt';

  // Industry-Specific Routes - Pharmacy
  // Industry-Specific Routes - Gas
  static const String gasDashboard = '/gas';
  static const String gasPump = '/gas/pump';
  static const String gasSalesHistory = '/gas/history';

  // Product Installation
  static const String productInstallation = '/install/product';
  static const String installationReceiptUpload = '/install/receipt-upload';

  
  static const String pharmacyDashboard = '/pharmacy';
  static const String pharmacyPrescriptions = '/pharmacy/prescriptions';
  static const String pharmacyAddPrescription = '/pharmacy/prescriptions/add';
  static const String pharmacyViewPrescription = '/pharmacy/prescriptions/view';
  static const String pharmacyDrugInventory = '/pharmacy/drugs';
  static const String pharmacyExpiryTracker = '/pharmacy/expiry-tracker';
  static const String pharmacyPatients = '/pharmacy/patients';
  static const String pharmacyPos = '/pharmacy/pos';
  static const String pharmacyControlledSubstances =
      '/pharmacy/controlled-substances';

  // Additional Pharmacy Routes
  static const String pharmacyAddDrug = '/pharmacy/drugs/add';
  static const String pharmacyEditDrug = '/pharmacy/drugs/edit';
  static const String pharmacyDrugDetails = '/pharmacy/drugs/details';
  static const String pharmacySalesHistory = '/pharmacy/sales/history';
  static const String pharmacySalesReport = '/pharmacy/sales/report';

  // Industry-Specific Routes - Retail
  static const String retailDashboard = '/retail';
  static const String wholesaleDashboard = '/wholesale';
  static const String wholesaleInventory = '/wholesale/inventory';
  static const String wholesalePos = '/wholesale/pos';
  static const String wholesalePurchaseOrders = '/wholesale/purchase-orders';
  static const String wholesaleTransfers = '/wholesale/transfers';
  static const String wholesaleReports = '/wholesale/reports';
  static const String retailPos = '/retail/pos';
  static const String retailCatalog = '/retail/catalog';
  static const String retailSuppliers = '/retail/suppliers';
  static const String retailStores = '/retail/stores';
  static const String wholesaleWarehouses = '/wholesale/warehouses';
  static const String retailStoreReports = '/retail/store-reports';
  static const String retailPromotions = '/retail/promotions';
  static const String retailWholesale = '/retail/wholesale';
  static const String retailProducts = '/retail/products';
  static const String retailAddProduct = '/retail/products/add';
  static const String retailEditProduct = '/retail/products/edit';
  static const String retailAddSupplier = '/retail/suppliers/add';

  // Industry-Specific Routes - Agriculture
  static const String agriDashboard = '/agri';
  static const String agriFarms = '/agri/farms';
  static const String agriCrops = '/agri/crops';
  static const String agriAddCrop = '/agri/crops/add';
  static const String agriLivestock = '/agri/livestock';
  static const String agriAddLivestock = '/agri/livestock/add';
  static const String agriHarvest = '/agri/harvest';
  static const String agriInputs = '/agri/inputs';
  static const String agriWeather = '/agri/weather';
  static const String agriMarketPrices = '/agri/market-prices';

  // Industry-Specific Routes - Auto
  static const String autoDashboard = '/auto';
  static const String autoServiceOrders = '/auto/service-orders';
  static const String autoCreateServiceOrder = '/auto/service-orders/create';
  static const String autoJobCards = '/auto/job-cards';
  static const String autoVehicleHistory = '/auto/vehicles';
  static const String autoPartsInventory = '/auto/parts';
  static const String autoMechanicSchedule = '/auto/mechanics';
  static const String autoDiagnostics = '/auto/diagnostics';
  static const String autoBookings = '/auto/bookings';
  static const String autoInvoices = '/auto/invoices';

  // Industry-Specific Routes - Barbershop
  static const String barberShopDashboard = '/barbershop';
  static const String barberShopAppointments = '/barbershop/appointments';
  static const String barberShopServices = '/barbershop/services';
  static const String barberShopCreateService = '/barbershop/services/create';
  static const String barberShopBarbers = '/barbershop/barbers';
  static const String barberCommission = '/barbershop/commission';
  static const String barberShopPayments = '/barbershop/payments';
  static const String barberShopSalesHistory = '/barbershop/sales-history';

  // Industry-Specific Routes - Salon
  static const String salonDashboard = '/salon';
  static const String salonAppointments = '/salon/appointments';
  static const String salonBookAppointment = '/salon/appointments/book';
  static const String salonCalendar = '/salon/calendar';
  static const String salonServices = '/salon/services';
  static const String salonStylists = '/salon/stylists';
  static const String salonTips = '/salon/tips';
  static const String salonCommission = '/salon/commission';
  static const String salonCommissionTracker = '/salon/commission/tracker';

  // Industry-Specific Routes - Hotel
  static const String hotelDashboard = '/hotel';
  static const String hotelFrontDesk = '/hotel/front-desk';
  static const String hotelRooms = '/hotel/rooms';
  static const String hotelCreateRoom = '/hotel/rooms/create';
  static const String hotelBookings = '/hotel/bookings';
  static const String hotelCreateBooking = '/hotel/bookings/create';
  static const String hotelCheckIn = '/hotel/check-in';
  static const String hotelCheckOut = '/hotel/check-out';
  static const String hotelGuests = '/hotel/guests';
  static const String hotelHousekeeping = '/hotel/housekeeping';
  static const String hotelRestaurant = '/hotel/restaurant';
  static const String hotelBar = '/hotel/bar';
  static const String hotelBilling = '/hotel/billing';

  // Industry-Specific Routes - Drink/Bar
  static const String drinkDashboard = '/drink';
  static const String drinkPos = '/drink/pos';

  static const String drinkInventory = '/drink/inventory';
  static const String drinkBottleTracking = '/drink/bottles';
  static const String drinkTabs = '/drink/tabs';
  static const String drinkMenu = '/drink/menu';
  static const String drinkLicense = '/drink/license';
  static const String drinkOrders = '/drink/orders';
  static const String drinkOrdersHistory = '/drink/orders/history';
  static const String drinkManage = '/drink/manage';

  // Industry-Specific Routes - Restaurant
  static const String restaurantDashboard = '/restaurant';
  static const String restaurantTables = '/restaurant/tables';
  static const String restaurantOrders = '/restaurant/orders';
  static const String restaurantKitchen = '/restaurant/kitchen';
  static const String restaurantMenu = '/restaurant/menu';
  static const String restaurantManageMenu = '/restaurant/manage-menu';
  static const String restaurantReservations = '/restaurant/reservations';
  static const String restaurantDelivery = '/restaurant/delivery';
  static const String restaurantWaiters = '/restaurant/waiters';

  // Industry-Specific Routes - Real Estate
  static const String realEstateDashboard = '/realestate';
  static const String realEstateProperties = '/realestate/properties';
  static const String realEstateAddProperty = '/realestate/properties/add';
  static const String realEstatePropertyDetails =
      '/realestate/properties/details';
  static const String realEstateTenants = '/realestate/tenants';
  static const String realEstateLeases = '/realestate/leases';
  static const String realEstateRentCollection = '/realestate/rent-collection';
  static const String realEstateTenantRentHistory = '/realestate/tenants/rent-history';
  static const String realEstatePropertyRentHistory = '/realestate/properties/rent-history';
  static const String realEstateMaintenance = '/realestate/maintenance';
  static const String realEstateCreateTicket = '/realestate/maintenance/create';
  static const String realEstateDocuments = '/realestate/documents';

  // Industry-Specific Routes - Gym
  static const String gymDashboard = '/gym';
  static const String gymMembers = '/gym/members';
  static const String gymMemberDetails = '/gym/members/details';
  static const String gymTrainers = '/gym/trainers';
  static const String gymMemberships = '/gym/memberships';
  static const String gymClasses = '/gym/classes';
  static const String gymCalendar = '/gym/calendar';

  // Admin Routes
  static const String adminLogin = '/admin_login';
  static const String adminDunning = '/admin/dunning';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminDashboard = '/admin/dashboard';
  static const String allBusinessesAdmin = '/admin/businesses';
  static const String adminUsersAndWorkers = '/admin/users-and-workers';
  static const String adminPayments = '/admin/payments';
  static const String adminPaymentsApproval = '/admin/payments-approval';
  static const String installationRequestsAdmin = '/admin/installation-requests';
  static const String installationRequestsMy = '/install/my-requests';

  // Marketer/worker dashboard
  static const String marketerLogin = '/marketer/login';
  static const String marketerForgotPassword = '/marketer/forgot-password';
  static const String marketerChangePassword = '/marketer/change-password';
  static const String marketerRegisterUser = '/marketer/register-user';
  static const String marketerRegisterBusiness = '/marketer/register-business';
  static const String marketerDashboard = '/marketer/dashboard';
}

