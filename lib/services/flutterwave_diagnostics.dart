import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Diagnostic tool for Flutterwave payment issues
class FlutterwaveDiagnostics {
  /// Check Firestore credentials and validity
  static Future<Map<String, dynamic>> checkFirestoreCredentials() async {
    print('[FlutterwaveDiagnostics] 🔍 Checking Firestore credentials...');

    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore.collection('secure').doc('secure').get();

      if (!doc.exists) {
        print('[FlutterwaveDiagnostics] ❌ secure/secure document not found');
        return {
          'exists': false,
          'message': 'secure/secure document not found in Firestore',
        };
      }

      final data = doc.data() ?? {};
      final publicKey = data['publicKey'] as String?;
      final secretKey = data['secretKey'] as String?;

      print('[FlutterwaveDiagnostics] ✓ Document found');
      print('[FlutterwaveDiagnostics] Public Key exists: ${publicKey != null}');
      print('[FlutterwaveDiagnostics] Secret Key exists: ${secretKey != null}');

      if (publicKey == null) {
        return {
          'exists': true,
          'hasPublicKey': false,
          'message': 'publicKey field missing from secure/secure document',
        };
      }

      // Validate key format
      print('[FlutterwaveDiagnostics] 📋 Key Analysis:');
      print('[FlutterwaveDiagnostics]   Length: ${publicKey.length}');
      print(
          '[FlutterwaveDiagnostics]   Starts with FLWPUBK: ${publicKey.startsWith('FLWPUBK')}');
      print(
          '[FlutterwaveDiagnostics]   Contains TEST: ${publicKey.contains('TEST')}');
      print(
          '[FlutterwaveDiagnostics]   Contains LIVE: ${publicKey.contains('LIVE')}');
      print(
          '[FlutterwaveDiagnostics]   First 30 chars: ${publicKey.substring(0, 30)}...');

      final isValid = publicKey.startsWith('FLWPUBK') && publicKey.length > 30;
      final keyType = publicKey.contains('TEST')
          ? 'TEST'
          : (publicKey.contains('LIVE') ? 'LIVE' : 'UNKNOWN');

      return {
        'exists': true,
        'hasPublicKey': true,
        'publicKeyValid': isValid,
        'keyType': keyType,
        'keyLength': publicKey.length,
        'message':
            isValid ? 'Key format appears valid' : 'Key format is INVALID',
        'publicKeyPreview': publicKey.substring(0, 30),
      };
    } catch (e, stackTrace) {
      print('[FlutterwaveDiagnostics] ❌ Error checking credentials: $e');
      print(stackTrace);
      return {
        'error': true,
        'message': 'Error accessing Firestore: ${e.toString()}',
      };
    }
  }

  /// Generate complete diagnostic report
  static Future<String> generateFullDiagnosticReport() async {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('FLUTTERWAVE PAYMENT DIAGNOSTIC REPORT');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');

    // Check credentials
    buffer.writeln('━━━━━━━ FIRESTORE CREDENTIALS ━━━━━━━');
    final credResult = await checkFirestoreCredentials();
    credResult.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln('');

    // Analysis
    buffer.writeln('━━━━━━━ ANALYSIS ━━━━━━━');
    if (credResult['error'] == true) {
      buffer.writeln('❌ Cannot access Firestore');
      buffer.writeln('   Ensure: Firestore security rules allow reads');
      buffer.writeln('   Ensure: User is authenticated');
    } else if (credResult['exists'] == false) {
      buffer.writeln('❌ secure/secure document missing');
      buffer.writeln('   Action: Create document in Firestore');
      buffer.writeln('   Path: Collection "secure" → Document "secure"');
      buffer.writeln('   Fields needed:');
      buffer.writeln('     - publicKey: FLWPUBK_TEST-[key]');
      buffer.writeln('     - secretKey: [secret]');
    } else if (credResult['hasPublicKey'] == false) {
      buffer.writeln('❌ publicKey field missing');
      buffer.writeln('   Action: Add publicKey field to secure/secure');
    } else if (credResult['publicKeyValid'] == false) {
      buffer.writeln('❌ Public Key format invalid');
      buffer.writeln('   Current: ${credResult['publicKeyPreview']}');
      buffer.writeln('   Should start with: FLWPUBK_TEST or FLWPUBK_LIVE');
      buffer.writeln('   Should be 40+ characters long');
      buffer.writeln('   Current length: ${credResult['keyLength']}');
    } else {
      buffer.writeln('✓ Public Key format valid');
      buffer.writeln('  Type: ${credResult['keyType']}');
      buffer.writeln('  Length: ${credResult['keyLength']}');
    }
    buffer.writeln('');

    // Recommendations
    buffer.writeln('━━━━━━━ RECOMMENDATIONS ━━━━━━━');
    if (credResult['error'] == true) {
      buffer.writeln('1. Check Firestore security rules');
      buffer.writeln('2. Verify user is authenticated to Firebase');
      buffer.writeln('3. Check internet connection');
    } else if (credResult['publicKeyValid'] != true) {
      buffer.writeln('1. Get correct key from Flutterwave Dashboard');
      buffer.writeln(
          '   Visit: https://app.flutterwave.com → Settings → API Keys');
      buffer.writeln('2. Copy the test key (starts with FLWPUBK_TEST)');
      buffer.writeln('3. Update Firestore document with correct key');
    } else {
      buffer.writeln('1. Credentials appear correct');
      buffer.writeln('2. Try payment again');
      buffer.writeln('3. Check Flutterwave account status');
      buffer.writeln('4. Verify payment methods enabled in test account');
    }
    buffer.writeln('');

    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }

  /// Show diagnostic results in app
  static Future<void> showDiagnosticsDialog(BuildContext context) async {
    final report = await generateFullDiagnosticReport();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Flutterwave Payment Diagnostics'),
        content: SingleChildScrollView(
          child: SelectableText(
            report,
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

/// Quick test function for debugging
void testFlutterwaveDiagnostics() async {
  print('[TEST] Running Flutterwave diagnostics...');
  final report = await FlutterwaveDiagnostics.generateFullDiagnosticReport();
  print(report);
}

