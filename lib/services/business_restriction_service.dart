import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessRestrictionState {
  final String businessId;
  final String businessName;
  final bool isRestricted;
  final String restrictionReason;
  final String customerCareWhatsapp;

  const BusinessRestrictionState({
    required this.businessId,
    required this.businessName,
    required this.isRestricted,
    required this.restrictionReason,
    required this.customerCareWhatsapp,
  });
}

class BusinessRestrictionService {
  final FirebaseFirestore _firestore;

  BusinessRestrictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'active';
  }

  String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  bool _isRestrictedBusiness(Map<String, dynamic> businessData) {
    final restrictionStatus = _readString(
      businessData['restrictionStatus'] ?? businessData['status'],
    ).toLowerCase();

    return _readBool(businessData['isRestricted']) ||
        businessData['isDeleted'] == true ||
        businessData['isActive'] == false ||
        restrictionStatus == 'restricted' ||
        restrictionStatus == 'suspended' ||
        restrictionStatus == 'blocked';
  }

  Future<BusinessRestrictionState?> getRestrictionState({
    String? userId,
    String? businessId,
  }) async {
    try {
      var resolvedBusinessId = _readString(businessId);

      if (resolvedBusinessId.isEmpty && userId != null && userId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? const <String, dynamic>{};
        resolvedBusinessId = _readString(
          userData['currentBusinessId'] ?? userData['businessId'],
        );
      }

      if (resolvedBusinessId.isEmpty) return null;

      final businessDoc =
          await _firestore.collection('businesses').doc(resolvedBusinessId).get();
      if (!businessDoc.exists) return null;

      final businessData = businessDoc.data() ?? const <String, dynamic>{};
      final settingsDoc =
          await _firestore.collection('system').doc('admin_settings').get();
      final settings = settingsDoc.data() ?? const <String, dynamic>{};

      return BusinessRestrictionState(
        businessId: resolvedBusinessId,
        businessName: _readString(businessData['name']).isNotEmpty
            ? _readString(businessData['name'])
            : resolvedBusinessId,
        isRestricted: _isRestrictedBusiness(businessData),
        restrictionReason: _readString(businessData['restrictionReason']).isNotEmpty
            ? _readString(businessData['restrictionReason'])
            : businessData['isDeleted'] == true
                ? 'This business was deleted by admin and can only be restored by support.'
                : businessData['isActive'] == false
                    ? 'This business is currently deactivated. Contact customer care for support.'
                    : '',
        customerCareWhatsapp: _readString(
          settings['customerCareWhatsapp'] ??
              settings['supportWhatsapp'] ??
              settings['customerCarePhone'],
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String buildWhatsAppUrl(String phoneNumber, {String? message}) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final query = Uri.encodeComponent(message ?? '');
    if (query.isEmpty) {
      return 'https://wa.me/$digits';
    }
    return 'https://wa.me/$digits?text=$query';
  }
}
