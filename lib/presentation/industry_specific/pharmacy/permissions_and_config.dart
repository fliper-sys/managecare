import 'package:flutter/material.dart';

/// Pharmacy-specific worker permissions and roles
class PharmacyWorkerPermissions {
  static const String pharmacist = 'pharmacist';
  static const String pharmacyAssistant = 'pharmacy_assistant';
  static const String pharmacyManager = 'pharmacy_manager';

  /// Define what actions each role can perform
  static final Map<String, Set<String>> rolePermissions = {
    pharmacist: {
      'view_drugs',
      'view_prescriptions',
      'create_prescription',
      'dispense_prescription',
      'view_patients',
      'check_drug_interactions',
      'view_inventory',
      'approve_controlled_substance',
      'view_reports',
    },
    pharmacyAssistant: {
      'view_drugs',
      'view_prescriptions',
      'view_patients',
      'view_inventory',
      'assist_dispensing',
      'scan_barcodes',
      'manage_stock',
    },
    pharmacyManager: {
      'view_drugs',
      'add_drug',
      'edit_drug',
      'delete_drug',
      'manage_inventory',
      'view_prescriptions',
      'create_prescription',
      'dispense_prescription',
      'view_patients',
      'manage_patients',
      'check_drug_interactions',
      'generate_reports',
      'manage_workers',
      'manage_settings',
      'approve_controlled_substance',
      'view_audit_logs',
    },
  };

  /// Check if a worker with given role can perform an action
  static bool canPerformAction(String role, String action) {
    return rolePermissions[role]?.contains(action) ?? false;
  }

  /// Get all permissions for a role
  static Set<String> getPermissionsForRole(String role) {
    return rolePermissions[role] ?? {};
  }

  /// Get all available roles
  static List<String> getAllRoles() {
    return rolePermissions.keys.toList();
  }

  /// Check if worker is a pharmacist or higher
  static bool isPharmacist(String role) {
    return role == pharmacist || role == pharmacyManager;
  }

  /// Check if worker can create prescriptions
  static bool canCreatePrescription(String role) {
    return canPerformAction(role, 'create_prescription');
  }

  /// Check if worker can dispense prescriptions
  static bool canDispensePrescription(String role) {
    return canPerformAction(role, 'dispense_prescription');
  }

  /// Check if worker can approve controlled substances
  static bool canApproveControlledSubstance(String role) {
    return canPerformAction(role, 'approve_controlled_substance');
  }

  /// Check if worker can manage inventory
  static bool canManageInventory(String role) {
    return canPerformAction(role, 'manage_inventory');
  }

  /// Check if worker can generate reports
  static bool canGenerateReports(String role) {
    return canPerformAction(role, 'generate_reports');
  }

  /// Get role display name
  static String getRoleDisplayName(String role) {
    switch (role) {
      case pharmacist:
        return 'Pharmacist';
      case pharmacyAssistant:
        return 'Pharmacy Assistant';
      case pharmacyManager:
        return 'Pharmacy Manager';
      default:
        return role;
    }
  }

  /// Get role description
  static String getRoleDescription(String role) {
    switch (role) {
      case pharmacist:
        return 'Licensed pharmacist who can create and dispense prescriptions, check drug interactions, and manage controlled substances';
      case pharmacyAssistant:
        return 'Pharmacy assistant who can assist with inventory management, dispensing, and customer service';
      case pharmacyManager:
        return 'Pharmacy manager with full control over inventory, prescriptions, workers, and reporting';
      default:
        return '';
    }
  }
}

/// Drug interaction severity levels
class DrugInteractionSeverity {
  static const String mild = 'mild';
  static const String moderate = 'moderate';
  static const String severe = 'severe';
  static const String contraindicated = 'contraindicated';

  static int getSeverityLevel(String severity) {
    switch (severity) {
      case mild:
        return 1;
      case moderate:
        return 2;
      case severe:
        return 3;
      case contraindicated:
        return 4;
      default:
        return 0;
    }
  }

  static Color getSeverityColor(String severity) {
    switch (severity) {
      case mild:
        return Colors.yellow;
      case moderate:
        return Colors.orange;
      case severe:
        return Colors.red;
      case contraindicated:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

/// Pharmacy-specific audit log actions
class PharmacyAuditActions {
  static const String prescriptionCreated = 'prescription_created';
  static const String prescriptionDispensed = 'prescription_dispensed';
  static const String prescriptionCancelled = 'prescription_cancelled';
  static const String drugAdded = 'drug_added';
  static const String drugUpdated = 'drug_updated';
  static const String drugRemoved = 'drug_removed';
  static const String stockAdjusted = 'stock_adjusted';
  static const String controlledSubstanceAccessed =
      'controlled_substance_accessed';
  static const String interactionWarning = 'interaction_warning';
  static const String expiredDrugRemoved = 'expired_drug_removed';
  static const String lowStockAlert = 'low_stock_alert';
}

/// Notification types for pharmacy
class PharmacyNotificationType {
  static const String expiringSoon = 'expiring_soon';
  static const String expired = 'expired';
  static const String lowStock = 'low_stock';
  static const String outOfStock = 'out_of_stock';
  static const String drugInteraction = 'drug_interaction';
  static const String prescriptionReady = 'prescription_ready';
  static const String prescriptionPending = 'prescription_pending';
}

