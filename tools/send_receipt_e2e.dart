import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';
const base = 'https://globalthrivealliance.com/emailtemplate';

Future<void> main() async {
  final tmpGif = File('./tmp_test.gif');
  if (!await tmpGif.exists()) {
    // minimal 1x1 GIF
    final bytes = base64Decode(
        'R0lGODlhAQABAPAAAP///wAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw==');
    await tmpGif.writeAsBytes(bytes);
    print('Created ./tmp_test.gif');
  }

  // 1) Upload the file to upload.php
  final uploadUri = Uri.parse('$base/upload.php');
  final uploadReq = http.MultipartRequest('POST', uploadUri);
  uploadReq.fields['api_key'] = apiKey;
  uploadReq.files.add(await http.MultipartFile.fromPath('image', tmpGif.path));

  print('Uploading test image to $uploadUri ...');
  final uploadStreamed = await uploadReq.send();
  final uploadResp = await http.Response.fromStream(uploadStreamed);
  print('Upload status: ${uploadResp.statusCode}');
  try {
    final body = jsonDecode(uploadResp.body);
    print('Upload response JSON: ${jsonEncode(body)}');
    if (body is Map && body.containsKey('url')) {
      print('Uploaded file URL: ${body['url']}');
    }
  } catch (e) {
    print('Upload response not JSON: ${uploadResp.body}');
  }

  // 2) Send receipt to receipt_email_listener.php referencing uploaded file (if any)
  final receiptUri = Uri.parse('$base/receipt_email_listener.php');
  final receiptReq = http.MultipartRequest('POST', receiptUri);
  receiptReq.fields['api_key'] = apiKey;
  receiptReq.fields['recipient'] = 'test+e2e@example.com';
  receiptReq.fields['businessName'] = 'Manage Care E2E Test';
  receiptReq.fields['receiptText'] = 'E2E receipt from automated test';
  receiptReq.fields['orderId'] = 'E2E-${DateTime.now().millisecondsSinceEpoch}';
  receiptReq.fields['businessId'] = 'E2E-BUS';
  receiptReq.fields['businessEmail'] = 'owner@example.com';
  receiptReq.fields['businessPhone'] = '+10000000000';
  receiptReq.fields['customerName'] = 'E2E Customer';
  receiptReq.fields['isPro'] = 'true';
  receiptReq.fields['generatePDF'] = 'true';
  receiptReq.fields['sendCopyToSender'] = 'true';
  receiptReq.fields['theme'] = 'professional';
  receiptReq.fields['receiptType'] = 'detailed';

  // Attach the same file as an attachment to the email request
  receiptReq.files
      .add(await http.MultipartFile.fromPath('attachment', tmpGif.path));

  print('Sending receipt to $receiptUri ...');
  final receiptStreamed = await receiptReq.send();
  final receiptResp = await http.Response.fromStream(receiptStreamed);
  print('Receipt endpoint status: ${receiptResp.statusCode}');
  try {
    final body = jsonDecode(receiptResp.body);
    print('Receipt response JSON: ${jsonEncode(body)}');
  } catch (e) {
    print('Receipt response not JSON: ${receiptResp.body}');
  }

  // 3) Try to fetch accessible server logs (may be protected)
  final logUri = Uri.parse('$base/error.log');
  print('Attempting to GET $logUri (may be protected)...');
  try {
    final logResp = await http.get(logUri).timeout(const Duration(seconds: 6));
    print('Log fetch status: ${logResp.statusCode}');
    if (logResp.statusCode == 200) {
      final content = logResp.body;
      print('--- Begin error.log (first 1000 chars) ---');
      print(content.length > 1000 ? content.substring(0, 1000) : content);
      print('--- End error.log preview ---');
    } else {
      print('Unable to fetch error.log (status ${logResp.statusCode})');
    }
  } catch (e) {
    print('Error fetching error.log: $e');
  }

  print('E2E script completed.');
}

