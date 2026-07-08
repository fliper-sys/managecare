/// Worker permissions and role-based access control
class WorkerPermissions {
  static const String permissionOverrideMarker = '__permissions_override__';
  static const Set<String> _fullAccessRoles = {'owner', 'admin', 'sub_admin'};
  static const Map<String, String> _roleAliases = {
    'worker': 'staff',
    'mechanic technician': 'mechanic',
    'body technician': 'body_technician',
    'body-technician': 'body_technician',
    'paint technician': 'painter',
    'paint-technician': 'painter',
    'valuconizer': 'vulcanizer',
    'valucnizer': 'vulcanizer',
    'frontdesk': 'receptionist',
    'front_desk': 'receptionist',
    'front_office': 'receptionist',
    'guest_services': 'receptionist',
    'bartender': 'cashier',
    'kitchen': 'chef',
    'floor_manager': 'supervisor',
    'captain': 'supervisor',
    'room_attendant': 'housekeeper',
    'maintenance': 'maintenance_staff',
    'station attendant': 'station_attendant',
    'fuel attendant': 'station_attendant',
    'petroleum attendant': 'station_attendant',
    'petrol attendant': 'station_attendant',
    'sales rep': 'sales_rep',
    'sales representative': 'sales_rep',
    'mini mart attendant': 'sales_rep',
    'minimart attendant': 'sales_rep',
    'bakery cashier': 'cashier',
    'pastry chef': 'pastry_chef',
  };

  static const Map<String, List<String>> rolePermissions = {
    'cashier': [
      'sales',
      'view_inventory',
      'view_sales_history',
      'view_orders',
    ],
    'manager': [
      'sales',
      'view_inventory',
      'manage_inventory',
      'view_sales_history',
      'access_inventory_screen',
      'access_procurement_screen',
      'access_reports_dashboard',
      'access_analytics_dashboard',
      'access_expenses_screen',
      'access_workers_screen',
      'attendance',
      'payroll_view',
      'apply_discount',
      'manage_staff',
      'manage_menu',
      'procurement_management',
      'table_management',
      'view_orders',
      'view_reports',
      'view_low_stock',
    ],
    'sub_admin': [
      'sales',
      'view_inventory',
      'manage_inventory',
      'view_sales_history',
      'access_inventory_screen',
      'access_procurement_screen',
      'access_reports_dashboard',
      'access_analytics_dashboard',
      'access_expenses_screen',
      'access_workers_screen',
      'access_settings_screen',
      'attendance',
      'payroll_view',
      'apply_discount',
      'manage_staff',
      'manage_menu',
      'procurement_management',
      'table_management',
      'view_orders',
      'view_reports',
      'view_low_stock',
    ],
    'staff': ['sales', 'view_inventory', 'attendance'],
    'pharmacist': [
      'sales',
      'manage_prescriptions',
      'view_inventory',
      'view_sales_history'
    ],
    'pharmacy_assistant': ['sales', 'view_inventory'],
    'bartender': ['sales', 'view_inventory'],
    'pump_operator': ['sales'],
    'sales_rep': ['sales', 'view_inventory'],
    'station_attendant': ['sales', 'view_inventory', 'view_sales_history'],
    'fuel_manager': [
      'sales',
      'view_inventory',
      'manage_inventory',
      'view_sales_history',
      'access_inventory_screen',
      'access_procurement_screen',
      'access_reports_dashboard',
      'access_analytics_dashboard',
      'access_expenses_screen',
      'procurement_management',
      'view_reports',
      'view_low_stock',
      'manage_staff',
    ],
    'chef': [
      'manage_menu',
      'view_orders',
      'procurement_management',
      'view_inventory',
      'view_low_stock',
    ],
    'baker': [
      'sales',
      'view_inventory',
      'manage_inventory',
      'procurement_management',
      'view_low_stock',
    ],
    'pastry_chef': [
      'sales',
      'view_inventory',
      'manage_inventory',
      'view_low_stock',
    ],
    'waiter': ['sales', 'view_orders', 'table_management'],
    'host': ['view_orders', 'table_management', 'bookings'],
    'runner': ['view_orders', 'table_management'],
    'supervisor': [
      'sales',
      'view_inventory',
      'view_sales_history',
      'apply_discount',
      'manage_menu',
      'table_management',
      'view_orders',
      'view_reports',
      'view_low_stock',
      'bookings',
    ],
    'receptionist': [
      'bookings',
      'guest_checkin',
      'guest_checkout',
      'billing',
      'view_inventory',
      'manage_rooms',
      'manage_guests',
      'manage_pool_bookings',
      'room_service',
    ],
    'housekeeper': ['room_status', 'maintenance_requests', 'room_service'],
    'maintenance_staff': ['room_status', 'maintenance_requests'],
    'night_auditor': [
      'bookings',
      'guest_checkin',
      'guest_checkout',
      'billing',
      'view_reports',
      'view_sales_history',
    ],
    'hr': ['manage_staff', 'attendance', 'payroll_view'],
    'mechanic': ['job_quotes', 'work_orders', 'parts_management'],
    'electrician': ['job_quotes', 'work_orders', 'diagnostics'],
    'body_technician': ['job_quotes', 'work_orders', 'body_work'],
    'painter': ['job_quotes', 'work_orders', 'painting'],
    'vulcanizer': ['job_quotes', 'work_orders', 'tyre_service'],
    'beautician': ['appointments', 'services', 'attendance'],
    'trainer': ['memberships', 'classes', 'attendance', 'manage_gym_bookings'],
    'field_officer': ['leads', 'properties', 'viewings'],
  };

  static String normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    return _roleAliases[normalized] ?? normalized;
  }

  static bool hasPermission(String role, String permission) {
    final normalizedRole = normalizeRole(role);
    if (_fullAccessRoles.contains(normalizedRole)) {
      return true;
    }
    final permissions = rolePermissions[normalizedRole] ?? [];
    return permissions.contains(permission);
  }

  static bool hasEffectivePermission(
    String role,
    List<String> customPermissions,
    String permission,
  ) {
    final normalizedRole = normalizeRole(role);
    if (_fullAccessRoles.contains(normalizedRole)) {
      return true;
    }
    final hasCustomOverride =
        customPermissions.contains(permissionOverrideMarker);
    final normalizedCustomPermissions = customPermissions
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != permissionOverrideMarker);
    if (hasCustomOverride || normalizedCustomPermissions.isNotEmpty) {
      return normalizedCustomPermissions.contains(permission);
    }
    return hasPermission(role, permission);
  }

  static List<String> getEffectivePermissions(
    String role,
    List<String> customPermissions,
  ) {
    final normalizedRole = normalizeRole(role);
    if (_fullAccessRoles.contains(normalizedRole)) {
      return rolePermissions.values.expand((p) => p).toSet().toList()..sort();
    }
    final hasCustomOverride =
        customPermissions.contains(permissionOverrideMarker);
    if (hasCustomOverride || customPermissions.isNotEmpty) {
      final permissions = customPermissions
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty && p != permissionOverrideMarker)
          .toSet()
          .toList();
      permissions.sort();
      return permissions;
    }
    final permissions = List<String>.from(getPermissionsForRole(role));
    permissions.sort();
    return permissions;
  }

  static List<String> getPermissionsForRole(String role) {
    return rolePermissions[normalizeRole(role)] ?? [];
  }

  static List<String> getPermissionsForRoles(Iterable<String> roles) {
    final permissions = <String>{};
    for (final role in roles) {
      permissions.addAll(getPermissionsForRole(role));
    }
    final list = permissions.toList()..sort();
    return list;
  }

  static List<String> getAllPermissions() {
    final permissions = rolePermissions.values.expand((p) => p).toSet().toList();
    permissions.sort();
    return permissions;
  }

  static List<String> getAdminGrantablePermissions() {
    return const [
      'access_inventory_screen',
      'access_procurement_screen',
      'access_reports_dashboard',
      'access_analytics_dashboard',
      'access_expenses_screen',
      'access_workers_screen',
      'access_settings_screen',
      'access_owner_dashboard',
      'access_fuel_stock_screen',
      'access_pump_configuration_screen',
      'manage_inventory',
      'procurement_management',
      'view_reports',
      'manage_staff',
      'attendance',
      'payroll_view',
    ];
  }

  static String getPermissionLabel(String permission) {
    const labels = {
      'sales': 'Sales',
      'view_inventory': 'View Inventory',
      'manage_inventory': 'Manage Inventory',
      'view_sales_history': 'View Sales History',
      'access_inventory_screen': 'Inventory Screen',
      'access_procurement_screen': 'Procurement Screen',
      'access_reports_dashboard': 'Reports Dashboard',
      'access_analytics_dashboard': 'Advanced Analytics',
      'access_expenses_screen': 'Expenses Screen',
      'access_workers_screen': 'Workers Screen',
      'access_settings_screen': 'Settings Screen',
      'access_owner_dashboard': 'Owner Dashboard',
      'access_fuel_stock_screen': 'Fuel Stock Screen',
      'access_pump_configuration_screen': 'Pump Configuration Screen',
      'attendance': 'Attendance',
      'payroll_view': 'Payroll View',
      'apply_discount': 'Apply Discount',
      'manage_staff': 'Manage Staff',
      'manage_menu': 'Manage Menu',
      'procurement_management': 'Procurement Management',
      'table_management': 'Table Management',
      'view_orders': 'View Orders',
      'view_reports': 'View Reports',
      'view_low_stock': 'View Low Stock',
      'bookings': 'Bookings',
      'guest_checkin': 'Guest Check-in',
      'guest_checkout': 'Guest Check-out',
      'billing': 'Billing',
      'manage_rooms': 'Manage Rooms',
      'manage_guests': 'Manage Guests',
      'manage_pool_bookings': 'Manage Pool Bookings',
      'room_service': 'Room Service',
      'room_status': 'Room Status',
      'maintenance_requests': 'Maintenance Requests',
      'manage_gym_bookings': 'Manage Gym Bookings',
      'job_quotes': 'Job Quotes',
      'work_orders': 'Work Orders',
      'parts_management': 'Parts Management',
      'diagnostics': 'Diagnostics',
      'body_work': 'Body Work',
      'painting': 'Painting',
      'tyre_service': 'Tyre Service',
      'appointments': 'Appointments',
      'services': 'Services',
      'leads': 'Leads',
      'properties': 'Properties',
      'viewings': 'Viewings',
    };
    return labels[permission] ?? permission.replaceAll('_', ' ').toUpperCase();
  }

  static bool canManageSales(String role) => hasPermission(role, 'sales');

  static bool canManageSalesForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'sales');

  static bool canViewInventory(String role) =>
      hasPermission(role, 'view_inventory');

  static bool canViewInventoryForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'view_inventory');

  static bool canManageInventory(String role) =>
      hasPermission(role, 'manage_inventory');

  static bool canManageInventoryForUser(
    String role,
    List<String> permissions,
  ) =>
      hasEffectivePermission(role, permissions, 'manage_inventory') ||
      hasEffectivePermission(role, permissions, 'access_inventory_screen');

  static bool canEditPrice(String role) {
    final normalizedRole = normalizeRole(role);
    return normalizedRole == 'owner' || normalizedRole == 'manager';
  }

  static bool canViewAnalytics(String role) =>
      hasPermission(role, 'view_sales_history') ||
      hasPermission(role, 'view_reports') ||
      hasPermission(role, 'access_reports_dashboard') ||
      hasPermission(role, 'access_analytics_dashboard');

  static bool canViewAnalyticsForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'view_sales_history') ||
      hasEffectivePermission(role, permissions, 'view_reports') ||
      hasEffectivePermission(role, permissions, 'access_reports_dashboard') ||
      hasEffectivePermission(role, permissions, 'access_analytics_dashboard');

  static bool canManageStaff(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_staff');

  static bool canManageStaffForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'manage_staff') ||
      hasEffectivePermission(role, permissions, 'access_workers_screen');

  static bool canAccessAdminScreenForUser(
    String role,
    List<String> permissions,
    String permission,
  ) =>
      hasEffectivePermission(role, permissions, permission);

  static bool canAccessReportsForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'view_reports') ||
      hasEffectivePermission(role, permissions, 'access_reports_dashboard');

  static bool canAccessAdvancedAnalyticsForUser(
    String role,
    List<String> permissions,
  ) =>
      hasEffectivePermission(role, permissions, 'access_analytics_dashboard');

  static bool canAccessProcurementForUser(
    String role,
    List<String> permissions,
  ) =>
      hasEffectivePermission(role, permissions, 'procurement_management') ||
      hasEffectivePermission(role, permissions, 'access_procurement_screen');

  static bool canAccessFuelStockForUser(
    String role,
    List<String> permissions,
  ) =>
      hasEffectivePermission(role, permissions, 'access_fuel_stock_screen');

  static bool canAccessPumpConfigurationForUser(
    String role,
    List<String> permissions,
  ) =>
      hasEffectivePermission(role, permissions, 'access_pump_configuration_screen');

  static bool canAccessExpensesForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'access_expenses_screen');

  static bool canAccessPayroll(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      hasPermission(role, 'payroll_view');

  static bool canAttendance(String role) => hasPermission(role, 'attendance');

  static bool canAttendanceForUser(String role, List<String> permissions) =>
      hasEffectivePermission(role, permissions, 'attendance');

  static bool canApplyDiscount(String role) {
    final normalizedRole = normalizeRole(role);
    return normalizedRole == 'owner' || normalizedRole == 'manager';
  }

  static bool canManageRooms(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_rooms') ||
      hasPermission(role, 'room_status');

  static bool canManageGuestBookings(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'bookings') ||
      hasPermission(role, 'guest_checkin') ||
      hasPermission(role, 'guest_checkout');

  static bool canManageHospitalityBilling(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'billing');

  static bool canManagePoolBookings(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_pool_bookings');

  static bool canManageHotelServices(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'guest_checkin') ||
      hasPermission(role, 'manage_rooms') ||
      hasPermission(role, 'room_service') ||
      hasPermission(role, 'maintenance_requests');

  static bool canManageHousekeeping(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'room_status') ||
      hasPermission(role, 'maintenance_requests') ||
      hasPermission(role, 'manage_rooms');

  static bool canManageGymBookings(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_gym_bookings') ||
      hasPermission(role, 'memberships');

  static List<String> getAvailableRoles(String businessType) {
    final rolesByBusiness = <String, List<String>>{
      'pharmacy': ['cashier', 'pharmacist', 'pharmacy_assistant', 'manager'],
      'retail': ['cashier', 'manager', 'staff'],
      'bakery': ['cashier', 'baker', 'pastry_chef', 'manager', 'staff'],
      'restaurant': [
        'sub_admin',
        'manager',
        'supervisor',
        'host',
        'waiter',
        'runner',
        'cashier',
        'chef',
        'staff',
      ],
      'hotel': [
        'receptionist',
        'night_auditor',
        'supervisor',
        'waiter',
        'housekeeper',
        'maintenance_staff',
        'manager',
        'cashier',
      ],
      'hospitality': [
        'receptionist',
        'night_auditor',
        'supervisor',
        'host',
        'waiter',
        'runner',
        'housekeeper',
        'maintenance_staff',
        'manager',
        'cashier',
        'chef',
      ],
      'apartment': [
        'receptionist',
        'frontdesk',
        'waiter',
        'housekeeper',
        'hr',
        'manager',
      ],
      'auto': [
        'mechanic',
        'electrician',
        'body_technician',
        'painter',
        'vulcanizer',
        'manager',
        'staff',
      ],
      'salon': ['beautician', 'staff', 'manager'],
      'gym': ['trainer', 'staff', 'manager'],
      'agriculture': ['field_officer', 'manager', 'staff'],
      'real_estate': ['field_officer', 'manager'],
      'bar': ['bartender', 'manager', 'staff'],
      'gas': ['pump_operator', 'sales_rep', 'staff', 'cashier', 'manager'],
      'petroleum': [
        'pump_operator',
        'sales_rep',
        'staff',
        'cashier',
        'manager'
      ],
      'petrol_station': [
        'pump_operator',
        'sales_rep',
        'staff',
        'cashier',
        'manager'
      ],
      'petroleum_station': [
        'pump_operator',
        'sales_rep',
        'staff',
        'cashier',
        'manager'
      ],
    };
    final normalizedBusinessType =
        businessType.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const aliases = {
      'petrolstation': 'petroleum',
      'petroleumstation': 'petroleum',
      'fillingstation': 'petroleum',
      'gasstation': 'gas',
      'retailstore': 'retail',
      'bakeryshop': 'bakery',
      'bakeshop': 'bakery',
    };
    final lookupKey = aliases[normalizedBusinessType] ??
        rolesByBusiness.keys.firstWhere(
          (key) =>
              key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
              normalizedBusinessType,
          orElse: () => businessType.toLowerCase(),
        );
    return rolesByBusiness[lookupKey] ??
        ['staff', 'manager', 'worker'];
  }

  static String getRoleDisplayName(String role) {
    final displayNames = {
      'cashier': 'Cashier',
      'sub_admin': 'Sub Admin',
      'manager': 'Manager',
      'staff': 'Staff',
      'worker': 'Worker',
      'pharmacist': 'Pharmacist',
      'pharmacy_assistant': 'Pharmacy Assistant',
      'bartender': 'Bartender',
      'chef': 'Chef',
      'waiter': 'Waiter',
      'host': 'Host',
      'runner': 'Runner',
      'supervisor': 'Supervisor',
      'receptionist': 'Receptionist',
      'frontdesk': 'Front Desk',
      'housekeeper': 'Housekeeper',
      'maintenance_staff': 'Maintenance Staff',
      'night_auditor': 'Night Auditor',
      'hr': 'HR',
      'mechanic': 'Mechanic',
      'electrician': 'Electrician',
      'body_technician': 'Body Technician',
      'painter': 'Painter',
      'vulcanizer': 'Vulcanizer',
      'beautician': 'Beautician',
      'trainer': 'Trainer',
      'pump_operator': 'Pump Operator',
      'sales_rep': 'Sales Rep',
      'station_attendant': 'Station Attendant',
      'fuel_manager': 'Fuel Manager',
      'baker': 'Baker',
      'pastry_chef': 'Pastry Chef',
      'field_officer': 'Field Officer',
    };
    return displayNames[role.toLowerCase()] ?? role;
  }

  static String getRoleDescription(String role) {
    final descriptions = {
      'cashier': 'Handles sales, receipts, and customer checkout.',
      'sub_admin': 'Supports management with broader operational control.',
      'mechanic': 'Handles engine, suspension, and repair work.',
      'electrician': 'Diagnoses and fixes wiring and electrical faults.',
      'body_technician': 'Restores panels, dents, and structural bodywork.',
      'painter': 'Manages prep, spray, and finishing work.',
      'vulcanizer': 'Handles tyres, wheel balancing, and alignment support.',
      'manager':
          'Oversees operations, reports, uploads, expenses, inventory, and staff coordination.',
      'staff':
          'General staff support with access to both sales and inventory where allowed.',
      'receptionist': 'Welcomes customers, manages bookings, and assigns jobs.',
      'pharmacist': 'Dispenses medications and manages prescriptions.',
      'trainer': 'Leads classes, sessions, and member guidance.',
      'beautician': 'Delivers beauty services and customer care.',
      'field_officer': 'Manages field visits, follow-ups, and property updates.',
      'pump_operator':
          'Dispenses fuel and records pump sales only. No minimart, uploads, reports, or pump history access.',
      'sales_rep':
          'Operates the station mini mart and sells gas cylinders, oil, accessories, and other retail products.',
      'station_attendant': 'Serves customers, records fuel sales, and checks stock.',
      'fuel_manager': 'Oversees fuel stock, procurement, reports, and station staff.',
      'baker': 'Manages baked goods, production stock, and bakery inventory.',
      'pastry_chef': 'Prepares pastries and helps monitor finished goods stock.',
      'supervisor': 'Monitors operations and keeps service moving smoothly.',
    };
    return descriptions[normalizeRole(role)] ?? '';
  }
}
