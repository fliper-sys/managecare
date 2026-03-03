abstract class AlertRepository {
  Future<List<Map<String, dynamic>>> getAlerts(
    String businessId, {
    String? type,
  });

  Future<void> createAlert(
    String businessId,
    Map<String, dynamic> alertData,
  );

  Future<void> dismissAlert(String alertId);

  Future<void> resolveAlert(String alertId);
}

