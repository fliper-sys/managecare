import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Direct Flutterwave account diagnostic tool
class FlutterwaveAccountDiagnostic {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Comprehensive account diagnostic
  static Future<String> diagnoseAccount() async {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('FLUTTERWAVE ACCOUNT DIAGNOSTIC');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('');

    // 1. Check Firestore key
    buffer.writeln('━━━━━━━ FIRESTORE KEY CHECK ━━━━━━━');
    try {
      final doc = await _firestore.collection('secure').doc('secure').get();
      if (!doc.exists) {
        buffer.writeln('❌ Document does not exist');
        buffer.writeln('   Path: secure/secure');
        buffer.writeln('   Action: Create this document with publicKey field');
      } else {
        final data = doc.data();
        final publicKey = data?['publicKey'] as String?;

        if (publicKey == null) {
          buffer.writeln('❌ publicKey field is missing');
        } else if (publicKey.isEmpty) {
          buffer.writeln('❌ publicKey is empty');
        } else {
          buffer.writeln('✓ publicKey found');
          buffer.writeln('  Length: ${publicKey.length}');
          buffer.writeln('  Preview: ${publicKey.substring(0, 30)}...');

          // Analyze format
          if (publicKey.startsWith('FLWPUBK_TEST')) {
            buffer.writeln('  Format: ✓ TEST KEY');
          } else if (publicKey.startsWith('FLWPUBK_LIVE')) {
            buffer.writeln('  Format: ✓ LIVE KEY');
          } else if (publicKey.startsWith('FLWPUBK-')) {
            buffer.writeln(
                '  Format: ❌ MALFORMED (uses hyphen, should use underscore)');
          } else if (publicKey.startsWith('FLWPUBK')) {
            buffer.writeln('  Format: ⚠ UNCLEAR (should have _TEST or _LIVE)');
          } else {
            buffer.writeln(
                '  Format: ❌ INVALID (should start with FLWPUBK_TEST or FLWPUBK_LIVE)');
          }
        }
      }
    } catch (e) {
      buffer.writeln('❌ Error reading Firestore: $e');
    }
    buffer.writeln('');

    // 2. Key requirements
    buffer.writeln('━━━━━━━ VALID KEY FORMAT ━━━━━━━');
    buffer.writeln('For TEST: FLWPUBK_TEST-[40+ alphanumeric]');
    buffer.writeln('For LIVE: FLWPUBK_LIVE-[40+ alphanumeric]');
    buffer.writeln('');
    buffer.writeln('Examples:');
    buffer.writeln('✓ FLWPUBK_TEST-81241a6c8f7e9b3a2d5c4e1f0a9b8c7d6e');
    buffer.writeln('✓ FLWPUBK_LIVE-81241a6c8f7e9b3a2d5c4e1f0a9b8c7d6e');
    buffer.writeln('❌ FLWPUBK-81241a6c8f7e9b3a2d5c4e1f0a9b8c7d6e');
    buffer.writeln('❌ FLWPUBK_TEST');
    buffer.writeln('');

    // 3. Common issues
    buffer.writeln('━━━━━━━ COMMON ISSUES & SOLUTIONS ━━━━━━━');
    buffer.writeln('');
    buffer.writeln('Issue 1: Key copied from wrong place');
    buffer.writeln('  Solution: Go to https://app.flutterwave.com');
    buffer.writeln('           Settings → API Keys');
    buffer.writeln('           Copy TEST PUBLIC KEY');
    buffer.writeln('');
    buffer.writeln('Issue 2: Account not activated');
    buffer.writeln('  Solution: Login to Flutterwave dashboard');
    buffer.writeln('           Complete account verification');
    buffer.writeln('           Enable test payments');
    buffer.writeln('');
    buffer.writeln('Issue 3: Key truncated/incomplete');
    buffer.writeln('  Solution: Copy the ENTIRE key (should be 50+ chars)');
    buffer.writeln('           No spaces before or after');
    buffer.writeln('');
    buffer.writeln('Issue 4: WebView not loading (Android)');
    buffer.writeln('  Solution: Update Android WebView');
    buffer.writeln('           Settings → Apps → Android System WebView');
    buffer.writeln('           Tap "Update" if available');
    buffer.writeln('');

    // 4. Next steps
    buffer.writeln('━━━━━━━ NEXT STEPS ━━━━━━━');
    buffer.writeln('1. Verify key format above matches Valid Key Format');
    buffer.writeln('2. If key is wrong:');
    buffer.writeln('   a. Get correct key from Flutterwave dashboard');
    buffer.writeln('   b. Update Firestore document');
    buffer.writeln('   c. Restart app');
    buffer.writeln('3. If key is correct but still error:');
    buffer.writeln('   a. Login to Flutterwave: https://app.flutterwave.com');
    buffer.writeln('   b. Check account status (Settings → Account)');
    buffer.writeln('   c. Verify payment methods are enabled');
    buffer.writeln('4. Try payment again');
    buffer.writeln('');

    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }

  /// Show diagnostic in dialog
  static Future<void> showDiagnosticDialog(BuildContext context) async {
    final diagnostic = await diagnoseAccount();
    print(diagnostic);

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Diagnostic'),
        content: SingleChildScrollView(
          child: SelectableText(
            diagnostic,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

