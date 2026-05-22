import 'package:cloud_functions/cloud_functions.dart';

class KoraCheckoutInitialization {
  final String checkoutUrl;
  final String reference;
  final String redirectUrl;

  const KoraCheckoutInitialization({
    required this.checkoutUrl,
    required this.reference,
    required this.redirectUrl,
  });
}

class KoraPaymentVerification {
  final bool success;
  final String message;
  final String reference;
  final String status;
  final String? paymentMethod;
  final Map<String, dynamic> raw;

  const KoraPaymentVerification({
    required this.success,
    required this.message,
    required this.reference,
    required this.status,
    required this.raw,
    this.paymentMethod,
  });
}

class KoraPaymentService {
  KoraPaymentService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const String redirectUrl =
      'https://managecare.app/subscription/kora-complete';

  static String buildReference({
    required String prefix,
    required String userId,
  }) {
    final safePrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeUserId = userId
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .padRight(10, '0')
        .substring(0, 10);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final reference = '${safePrefix}_${safeUserId}_$timestamp';
    return reference.length <= 50 ? reference : reference.substring(0, 50);
  }

  Future<KoraCheckoutInitialization> initializeSubscriptionPayment({
    required String reference,
    required double amount,
    required String currency,
    required String email,
    required String fullName,
    required String planId,
    required String businessId,
    required String userId,
    String? businessType,
    List<String>? channels,
    bool recurringEnabled = false,
    String? recurrenceInterval,
  }) async {
    final callable =
        _functions.httpsCallable('initializeKoraSubscriptionPayment');
    final response = await callable.call(<String, dynamic>{
      'reference': reference,
      'amount': amount,
      'currency': currency,
      'email': email,
      'fullName': fullName,
      'redirectUrl': redirectUrl,
      'planId': planId,
      'businessId': businessId,
      'userId': userId,
      'businessType': businessType,
      'channels': channels,
      'recurringEnabled': recurringEnabled,
      'recurrenceInterval': recurrenceInterval,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    return KoraCheckoutInitialization(
      checkoutUrl: data['checkoutUrl']?.toString() ?? '',
      reference: data['reference']?.toString() ?? reference,
      redirectUrl: data['redirectUrl']?.toString() ?? redirectUrl,
    );
  }

  Future<KoraPaymentVerification> verifySubscriptionPayment({
    required String reference,
    required String planId,
    required String userId,
    required String businessId,
  }) async {
    final callable = _functions.httpsCallable('verifyKoraSubscriptionPayment');
    final response = await callable.call(<String, dynamic>{
      'reference': reference,
      'planId': planId,
      'userId': userId,
      'businessId': businessId,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    return KoraPaymentVerification(
      success: data['success'] == true,
      message: data['message']?.toString() ?? 'Unable to verify payment.',
      reference: data['reference']?.toString() ?? reference,
      status: data['status']?.toString() ?? 'unknown',
      paymentMethod: data['paymentMethod']?.toString(),
      raw: Map<String, dynamic>.from(data['raw'] as Map? ?? const {}),
    );
  }
}
