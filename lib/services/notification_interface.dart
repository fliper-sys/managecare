abstract class INotificationService {
  Future<void> requestPermissions();

  Future<List<int>> getDaysBeforeThresholds();

  Future<void> scheduleExpiryAlert(
      {required String businessId,
      required String memberId,
      required String memberName,
      required DateTime expiry,
      int daysBefore = 1});

  Future<List<Map<String, dynamic>>> getScheduledAlertMetadata(
      {String? businessId});

  Future<void> cancelNotification(int id);

  // Added for compatibility with NotificationService usages
  Future<void> sendNotification(String title, String body, {int id});
  Future<void> scheduleNotificationAt({required int id, required String title, required String body, required DateTime at});
} 

