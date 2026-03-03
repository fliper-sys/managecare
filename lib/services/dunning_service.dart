import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/models/business_model.dart';
import 'email_service.dart';
import 'notification_service.dart';

/// Dunning Management Service
/// Handles payment follow-up, retries, and account suspension
/// Implements automated payment recovery workflows
class DunningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmailService _emailService = EmailService();
  final NotificationService? _notificationService;

  DunningService({NotificationService? notificationService})
      : _notificationService = notificationService;

  /// Execute dunning cycle for all overdue businesses
  /// Call this from a scheduled background job or cron
  Future<DunningReport> processDunningCycle() async {
    final report = DunningReport();

    try {
      final overdueBusinesses = await _getOverdueBusinesses();

      for (final business in overdueBusinesses) {
        final daysOverdue = DateTime.now()
            .difference(business.subscriptionEndDate ?? DateTime.now())
            .inDays;

        report.totalProcessed++;

        if (daysOverdue <= 0) {
          // Subscription not yet expired
          continue;
        } else if (daysOverdue == 3) {
          await _sendPaymentFailedAlert(business);
          report.remindersLevel1++;
        } else if (daysOverdue == 7) {
          await _sendUpdatePaymentMethodAlert(business);
          report.remindersLevel2++;
        } else if (daysOverdue == 10) {
          await _sendUrgentWarning(business);
          report.remindersLevel3++;
        } else if (daysOverdue == 15) {
          await _downgradeToFreeTier(business);
          report.downgrades++;
        } else if (daysOverdue == 30) {
          await _suspendAccount(business);
          report.suspensions++;
        } else if (daysOverdue > 60) {
          await _markForCancellation(business);
          report.cancellations++;
        }
      }
    } catch (e) {
      report.errors.add('Dunning cycle error: $e');
    }

    return report;
  }

  /// Poll a remote trigger URL and run the dunning cycle if a newer trigger exists.
  /// The remote trigger (e.g. `emailtemplate/dunning_trigger.php`) should return JSON
  /// with a `triggered_at` ISO timestamp and `timestamp` unix epoch. Example:
  /// { "triggered_at": "2025-11-30T12:00:00Z", "timestamp": 1767153600 }
  Future<bool> checkAndRunRemoteTrigger(String triggerUrl) async {
    const int maxAttempts = 3;
    int attempt = 0;
    int delaySeconds = 1;
    http.Response? resp;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final uri = Uri.parse(triggerUrl);
        resp = await http.get(uri).timeout(const Duration(seconds: 8));

        // If successful (200) break out, otherwise decide whether to retry
        if (resp.statusCode == 200) break;

        if (resp.statusCode >= 500) {
          print('[DunningService] Remote trigger returned ${resp.statusCode} (attempt $attempt/$maxAttempts)');
          if (attempt < maxAttempts) await Future.delayed(Duration(seconds: delaySeconds));
          delaySeconds *= 2;
          continue;
        }

        // For client errors (4xx) we don't retry
        print('[DunningService] Remote trigger returned ${resp.statusCode}: ${resp.body}');
        return false;
      } on FormatException catch (e) {
        print('[DunningService] Invalid trigger URL: $e');
        return false;
      } on http.ClientException catch (e) {
        print('[DunningService] Network error while fetching remote trigger (attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2;
        continue;
      } catch (e) {
        print('[DunningService] Error fetching remote trigger (attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2;
        continue;
      }
    }

    if (resp == null || resp.statusCode != 200) {
      print('[DunningService] Failed to fetch remote trigger after $maxAttempts attempts');
      return false;
    }

    try {
      final body = resp.body;
      if (body.isEmpty) {
        print('[DunningService] Remote trigger body empty');
        return false;
      }

      final Map<String, dynamic> json = Map<String, dynamic>.from(jsonDecode(body));
      if (!json.containsKey('timestamp')) {
        print('[DunningService] Remote trigger missing "timestamp" key');
        return false;
      }

      final remoteTs = (json['timestamp'] is int)
          ? json['timestamp'] as int
          : int.tryParse(json['timestamp'].toString()) ?? 0;

      // Read last run timestamp from Firestore system doc
      final docRef = _firestore.collection('system').doc('dunning');
      final doc = await docRef.get();
      final lastRun = doc.exists &&
              doc.data() != null &&
              doc.data()!['last_trigger_ts'] != null
          ? (doc.data()!['last_trigger_ts'] as int)
          : 0;

      if (remoteTs > lastRun) {
        // Run dunning
        final report = await processDunningCycle();

        // Update last run
        await docRef.set({
          'last_trigger_ts': remoteTs,
          'last_run_at': DateTime.now().toIso8601String(),
          'report': report.toString()
        });
        return true;
      }
      return false;
    } catch (e) {
      print('[DunningService] Failed to parse or handle remote trigger JSON: $e');
      return false;
    }
  }

  /// Get businesses with expired or upcoming expired subscriptions
  Future<List<BusinessModel>> _getOverdueBusinesses() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('subscriptionEndDate', isLessThan: DateTime.now())
          .orderBy('subscriptionEndDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching overdue businesses: $e');
      return [];
    }
  }

  /// Send payment failed alert (Day 3)
  Future<void> _sendPaymentFailedAlert(BusinessModel business) async {
    try {
      final email = business.email ?? '';
      if (email.isEmpty) return;

      await _emailService.sendPaymentReminder(
        email,
        {
          'businessName': business.name,
          'businessEmail': business.email ?? '',
          'daysOverdue': '3',
          'planName': _getPlanName(business.subscriptionTier),
          'renewalAmount': _getPlanPrice(business.subscriptionTier),
          'actionUrl': 'https://globalthrivealliance.com/renew',
        },
      );

      await _notificationService?.sendNotification('Payment Failed',
          'Your subscription payment failed. Please update your payment method.');

      await _recordDunningEvent(business.id, 'alert_level_1', 3);
    } catch (e) {
      print('Error sending payment failed alert: $e');
    }
  }

  /// Send update payment method alert (Day 7)
  Future<void> _sendUpdatePaymentMethodAlert(BusinessModel business) async {
    try {
      final email = business.email ?? '';
      if (email.isEmpty) return;

      await _emailService.sendPaymentReminder(
        email,
        {
          'businessName': business.name,
          'subject': 'URGENT: Update Your Payment Method',
          'daysOverdue': '7',
          'message':
              'Your subscription will be downgraded to Free plan in 3 days.',
          'actionUrl': 'https://globalthrivealliance.com/payment-method',
        },
      );

      await _notificationService?.sendNotification('Update Payment Method',
          'Your subscription will be downgraded in 3 days. Update now.');

      await _recordDunningEvent(business.id, 'alert_level_2', 7);
    } catch (e) {
      print('Error sending update payment alert: $e');
    }
  }

  /// Send urgent warning (Day 10)
  Future<void> _sendUrgentWarning(BusinessModel business) async {
    try {
      final email = business.email ?? '';
      if (email.isEmpty) return;

      await _emailService.sendPaymentReminder(
        email,
        {
          'businessName': business.name,
          'subject': 'FINAL NOTICE: Your Subscription Expires Today',
          'message': 'Update payment immediately to maintain access.',
          'actionUrl': 'https://globalthrivealliance.com/emergency-payment',
        },
      );

      await _notificationService?.sendNotification(
          'Final Notice', 'Update payment immediately to maintain access.');

      await _recordDunningEvent(business.id, 'alert_level_3', 10);
    } catch (e) {
      print('Error sending urgent warning: $e');
    }
  }

  /// Downgrade to Free tier (Day 15)
  Future<void> _downgradeToFreeTier(BusinessModel business) async {
    try {
      await _firestore.collection('businesses').doc(business.id).update({
        'subscriptionTier': 'free',
        'subscriptionEndDate': null,
        'isSubscriptionActive': false,
      });

      final email = business.email ?? '';
      if (email.isNotEmpty) {
        await _emailService.sendPaymentReminder(
          email,
          {
            'businessName': business.name,
            'subject': 'Your Subscription Has Been Downgraded',
            'message':
                'Due to non-payment, your account has been downgraded to Free tier.',
          },
        );
      }

      await _notificationService?.sendNotification('Subscription Downgraded',
          'Your account has been downgraded to Free tier.');

      await _recordDunningEvent(business.id, 'downgraded', 15);
    } catch (e) {
      print('Error downgrading subscription: $e');
    }
  }

  /// Suspend account (Day 30)
  Future<void> _suspendAccount(BusinessModel business) async {
    try {
      await _firestore.collection('businesses').doc(business.id).update({
        'isActive': false,
        'suspendedReason': 'Payment overdue > 30 days',
        'suspendedDate': DateTime.now(),
      });

      final email = business.email ?? '';
      if (email.isNotEmpty) {
        await _emailService.sendPaymentReminder(
          email,
          {
            'businessName': business.name,
            'subject': 'Your Account Has Been Suspended',
            'message':
                'Your account access has been suspended due to non-payment.',
          },
        );
      }

      await _notificationService?.sendNotification('Account Suspended',
          'Your account access has been suspended due to non-payment.');

      await _recordDunningEvent(business.id, 'suspended', 30);
    } catch (e) {
      print('Error suspending account: $e');
    }
  }

  /// Mark for cancellation (Day 60)
  Future<void> _markForCancellation(BusinessModel business) async {
    try {
      await _firestore.collection('businesses').doc(business.id).update({
        'isActive': false,
        'canceledReason': 'Payment overdue > 60 days',
        'canceledDate': DateTime.now(),
      });

      await _recordDunningEvent(business.id, 'marked_for_cancellation', 60);
    } catch (e) {
      print('Error marking for cancellation: $e');
    }
  }

  /// Record dunning event in analytics
  Future<void> _recordDunningEvent(
    String businessId,
    String eventType,
    int daysOverdue,
  ) async {
    try {
      await _firestore.collection('dunning_events').add({
        'businessId': businessId,
        'eventType': eventType,
        'daysOverdue': daysOverdue,
        'timestamp': DateTime.now(),
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error recording dunning event: $e');
    }
  }

  /// Get plan name from tier
  String _getPlanName(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
        return 'Free Plan';
      case 'starter':
        return 'Starter Plan';
      case 'professional':
        return 'Professional Plan';
      case 'enterprise':
        return 'Enterprise Plan';
      default:
        return tier;
    }
  }

  /// Get plan price (simplified)
  String _getPlanPrice(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
        return '₦0';
      case 'starter':
        return '₦2,999';
      case 'professional':
        return '₦7,999';
      case 'enterprise':
        return 'Custom';
      default:
        return '₦0';
    }
  }
}

/// Report from dunning cycle
class DunningReport {
  int totalProcessed = 0;
  int remindersLevel1 = 0; // Day 3
  int remindersLevel2 = 0; // Day 7
  int remindersLevel3 = 0; // Day 10
  int downgrades = 0; // Day 15
  int suspensions = 0; // Day 30
  int cancellations = 0; // Day 60
  List<String> errors = [];

  @override
  String toString() => '''
DunningReport {
  Total Processed: $totalProcessed,
  Level 1 Reminders: $remindersLevel1,
  Level 2 Reminders: $remindersLevel2,
  Level 3 Reminders: $remindersLevel3,
  Downgrades: $downgrades,
  Suspensions: $suspensions,
  Cancellations: $cancellations,
  Errors: ${errors.length}
}
  ''';
}

