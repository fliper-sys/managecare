/// Worker permissions and role-based access control
class WorkerPermissions {
  static const Set<String> _fullAccessRoles = {'owner', 'admin', 'sub_admin'};
  static const Map<String, String> _roleAliases = {
    'worker': 'staff',
    'frontdesk': 'receptionist',
    'front_desk': 'receptionist',
    'bartender': 'cashier',
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
    'pump_operator': ['sales', 'view_inventory'],
    'chef': [
      'manage_menu',
      'view_orders',
      'procurement_management',
      'view_inventory',
      'view_low_stock',
    ],
    'waiter': ['sales', 'view_orders', 'table_management'],
    'receptionist': [
      'bookings',
      'guest_checkin',
      'view_inventory',
      'manage_rooms',
      'manage_guests',
      'manage_pool_bookings',
    ],
    'housekeeper': ['room_status', 'maintenance_requests'],
    'hr': ['manage_staff', 'attendance', 'payroll_view'],
    'mechanic': ['job_quotes', 'work_orders', 'parts_management'],
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

  static List<String> getPermissionsForRole(String role) {
    return rolePermissions[normalizeRole(role)] ?? [];
  }

  static bool canManageSales(String role) => hasPermission(role, 'sales');

  static bool canViewInventory(String role) =>
      hasPermission(role, 'view_inventory');

  static bool canManageInventory(String role) =>
      hasPermission(role, 'manage_inventory');

  static bool canEditPrice(String role) {
    final normalizedRole = role.toLowerCase();
    return _fullAccessRoles.contains(normalizedRole);
  }

  static bool canViewAnalytics(String role) =>
      hasPermission(role, 'view_sales_history');

  static bool canManageStaff(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_staff');

  static bool canAccessPayroll(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      hasPermission(role, 'payroll_view');

  static bool canAttendance(String role) => hasPermission(role, 'attendance');

  static bool canApplyDiscount(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      hasPermission(role, 'apply_discount');

  static bool canManageRooms(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_rooms') ||
      hasPermission(role, 'room_status');

  static bool canManageGuestBookings(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'bookings') ||
      hasPermission(role, 'guest_checkin');

  static bool canManagePoolBookings(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'manage_pool_bookings');

  static bool canManageHotelServices(String role) =>
      _fullAccessRoles.contains(normalizeRole(role)) ||
      normalizeRole(role) == 'manager' ||
      hasPermission(role, 'guest_checkin') ||
      hasPermission(role, 'manage_rooms') ||
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
      'restaurant': [
        'sub_admin',
        'manager',
        'waiter',
        'cashier',
        'chef',
        'staff',
      ],
      'hotel': [
        'receptionist',
        'waiter',
        'housekeeper',
        'manager',
        'cashier',
      ],
      'hospitality': [
        'receptionist',
        'waiter',
        'housekeeper',
        'manager',
        'cashier',
      ],
      'apartment': [
        'receptionist',
        'frontdesk',
        'waiter',
        'housekeeper',
        'hr',
        'manager',
      ],
      'auto': ['mechanic', 'manager'],
      'salon': ['beautician', 'staff', 'manager'],
      'gym': ['trainer', 'staff', 'manager'],
      'agriculture': ['field_officer', 'manager', 'staff'],
      'real_estate': ['field_officer', 'manager'],
      'bar': ['bartender', 'manager', 'staff'],
      'gas': ['pump_operator', 'cashier', 'manager'],
    };
    return rolesByBusiness[businessType.toLowerCase()] ??
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
      'receptionist': 'Receptionist',
      'frontdesk': 'Front Desk',
      'housekeeper': 'Housekeeper',
      'hr': 'HR',
      'mechanic': 'Mechanic',
      'beautician': 'Beautician',
      'trainer': 'Trainer',
      'pump_operator': 'Pump Operator',
      'field_officer': 'Field Officer',
    };
    return displayNames[role.toLowerCase()] ?? role;
  }
}
