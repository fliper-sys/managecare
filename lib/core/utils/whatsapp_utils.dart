import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class WhatsAppUtils {
  /// Opens WhatsApp customer support with a pre-formatted message
  static Future<void> openCustomerSupport(
    BuildContext context, {
    String? businessName,
    String? additionalMessage,
  }) async {
    const supportPhone = AppConfig.ownerWhatsappNumber;
    final displayBusinessName = businessName ?? 'my business';
    
    final baseMessage = 'Hello, I need support for $displayBusinessName on Manage Care.';
    final message = Uri.encodeComponent(
      additionalMessage != null ? '$baseMessage\n$additionalMessage' : baseMessage,
    );
    
    final phoneDigits = supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$phoneDigits?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open customer support.')),
    );
  }

  /// Opens WhatsApp with a custom message to the support phone
  static Future<void> openCustomerSupportWithMessage(
    BuildContext context,
    String message,
  ) async {
    const supportPhone = AppConfig.ownerWhatsappNumber;
    final encodedMessage = Uri.encodeComponent(message);
    final phoneDigits = supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$phoneDigits?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open WhatsApp.')),
    );
  }
}
