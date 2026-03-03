import 'package:flutter/material.dart';
import '../screens/business_dashboard_screen.dart';
import '../screens/gym_member_management_screen.dart';
import '../screens/pharmacy_management_screen.dart';

/// Navigation routes for business logic screens
class BusinessLogicRoutes {
  static const String businessDashboard = '/business-dashboard';
  static const String gymManagement = '/gym-management';
  static const String pharmacyManagement = '/pharmacy-management';

  /// Get named routes for navigation
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      businessDashboard: (context) {
        final businessId =
            ModalRoute.of(context)?.settings.arguments as String? ?? 'default';
        return BusinessDashboardScreen(
          businessId: businessId,
          businessType: 'general',
        );
      },
      gymManagement: (context) {
        final businessId =
            ModalRoute.of(context)?.settings.arguments as String? ?? 'default';
        return GymMemberManagementScreen(businessId: businessId);
      },
      pharmacyManagement: (context) {
        final businessId =
            ModalRoute.of(context)?.settings.arguments as String? ?? 'default';
        return PharmacyManagementScreen(businessId: businessId);
      },
    };
  }

  /// Navigate to business dashboard
  static void toDashboard(BuildContext context, String businessId) {
    Navigator.of(context).pushNamed(
      businessDashboard,
      arguments: businessId,
    );
  }

  /// Navigate to gym management
  static void toGymManagement(BuildContext context, String businessId) {
    Navigator.of(context).pushNamed(
      gymManagement,
      arguments: businessId,
    );
  }

  /// Navigate to pharmacy management
  static void toPharmacyManagement(BuildContext context, String businessId) {
    Navigator.of(context).pushNamed(
      pharmacyManagement,
      arguments: businessId,
    );
  }
}

