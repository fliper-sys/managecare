/// User permissions for different roles
enum UserRole {
  owner,
  manager,
  cashier,
  staff,
  viewer,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.manager:
        return 'Manager';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.staff:
        return 'Staff';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  List<String> get permissions {
    switch (this) {
      case UserRole.owner:
        return [
          'view_all',
          'edit_all',
          'delete_all',
          'manage_staff',
          'view_analytics',
          'manage_subscription',
        ];
      case UserRole.manager:
        return [
          'view_sales',
          'edit_sales',
          'view_inventory',
          'edit_inventory',
          'manage_staff',
          'view_analytics',
        ];
      case UserRole.cashier:
        return [
          'view_sales',
          'create_sale',
          'view_inventory',
          'generate_receipt',
        ];
      case UserRole.staff:
        return [
          'view_inventory',
          'clock_in_out',
        ];
      case UserRole.viewer:
        return [
          'view_sales',
          'view_inventory',
        ];
    }
  }
}

