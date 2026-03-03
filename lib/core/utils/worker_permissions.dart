/// Worker permissions and role-based access control
class WorkerPermissions {
  static const Map<String, List<String>> rolePermissions = {
    'cashier': ['sales', 'view_inventory', 'view_sales_history'],
    'manager': [
      'sales',
      'view_inventory',
      'manage_inventory',
      'view_sales_history',
      'attendance',
      'payroll_view'
    ],
    'staff': ['sales', 'view_inventory', 'attendance'],
    'worker': ['sales', 'view_inventory', 'attendance'],
    'pharmacist': [
      'sales',
      'manage_prescriptions',
      'view_inventory',
      'view_sales_history'
    ],
    'pharmacy_assistant': ['sales', 'view_inventory'],
    'bartender': ['sales', 'view_inventory'],
    'pump_operator': ['sales', 'view_inventory'],
    'chef': ['manage_menu', 'view_orders'],
    'waiter': ['sales', 'view_orders'],
    'receptionist': ['bookings', 'guest_checkin', 'view_inventory'],
    'housekeeper': ['room_status', 'maintenance_requests'],
    'mechanic': ['job_quotes', 'work_orders', 'parts_management'],
    'beautician': ['appointments', 'services', 'attendance'],
    'trainer': ['memberships', 'classes', 'attendance'],
    'field_officer': ['leads', 'properties', 'viewings'],
  };

  static bool hasPermission(String role, String permission) {
    final permissions = rolePermissions[role.toLowerCase()] ?? [];
    return permissions.contains(permission);
  }

  static List<String> getPermissionsForRole(String role) {
    return rolePermissions[role.toLowerCase()] ?? [];
  }

  static bool canManageSales(String role) => hasPermission(role, 'sales');

  static bool canViewInventory(String role) =>
      hasPermission(role, 'view_inventory');

  static bool canManageInventory(String role) =>
      hasPermission(role, 'manage_inventory');

  static bool canEditPrice(String role) =>
      ['admin', 'owner', 'manager'].contains(role.toLowerCase());

  static bool canViewAnalytics(String role) =>
      hasPermission(role, 'view_sales_history');

  static bool canManageStaff(String role) =>
      role.toLowerCase() == 'owner' || role.toLowerCase() == 'manager';

  static bool canAccessPayroll(String role) =>
      role.toLowerCase() == 'owner' || hasPermission(role, 'payroll_view');

  static bool canAttendance(String role) => hasPermission(role, 'attendance');

  static List<String> getAvailableRoles(String businessType) {
    final rolesByBusiness = <String, List<String>>{
      'pharmacy': ['cashier', 'pharmacist', 'pharmacy_assistant', 'manager'],
      'retail': ['cashier', 'manager', 'staff'],
      'restaurant': ['waiter', 'bartender', 'chef', 'manager'],
      'hotel': ['receptionist', 'housekeeper', 'manager'],
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
      'manager': 'Manager',
      'staff': 'Staff',
      'worker': 'Worker',
      'pharmacist': 'Pharmacist',
      'pharmacy_assistant': 'Pharmacy Assistant',
      'bartender': 'Bartender',
      'chef': 'Chef',
      'waiter': 'Waiter',
      'receptionist': 'Receptionist',
      'housekeeper': 'Housekeeper',
      'mechanic': 'Mechanic',
      'beautician': 'Beautician',
      'trainer': 'Trainer',
      'pump_operator': 'Pump Operator',
      'field_officer': 'Field Officer',
    };
    return displayNames[role.toLowerCase()] ?? role;
  }
}
