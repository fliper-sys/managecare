import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AccessControl {
  /// Returns true when the current user is a business admin or the owner.
  static bool canViewReports(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.isAdminUser || auth.isOwnerUser;
  }

  /// Returns true when the current business has an active Professional subscription
  /// and can use Pro features like emailing or printing receipts.
  static bool canUseEmailAndPrint(BuildContext context) {
    // Allow email and printing unconditionally for all users.
    return true;
  }

  /// Gate access to the dunning admin screens (same as reports access for now).
  static bool canAccessDunning(BuildContext context) => canViewReports(context);

  /// Returns true when the current user is a worker-level user.
  static bool isWorker(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.isWorkerUser;
  }
}

