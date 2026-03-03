import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ReportService {
  /// Send a trigger payload to a webhook URL (application/json with optional X-Hook-Token)
  Future<bool> sendToWebhook({required String webhookUrl, required Map<String, dynamic> payload, String? hookToken}) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (hookToken != null && hookToken.isNotEmpty) headers['X-Hook-Token'] = hookToken;
      final resp = await http.post(Uri.parse(webhookUrl), headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 15));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Fallback: send a form-encoded POST to the server trigger endpoint using configured API key
  Future<bool> sendToTriggerEndpoint({required String triggerUrl, required Map<String, dynamic> payload, required String apiKey}) async {
    try {
      final form = {
        'api_key': apiKey,
        'businessId': payload['businessId'] ?? '',
        'businessName': payload['businessName'] ?? '',
        'date': payload['date'] ?? '',
        'transactions': jsonEncode(payload['transactions'] ?? []),
        'total': (payload['total'] ?? 0).toString(),
      };
      final resp = await http.post(Uri.parse(triggerUrl), body: form).timeout(const Duration(seconds: 15));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// High-level trigger that will prefer webhookUrl (JSON), otherwise use fallback triggerUrl + apiKey from AppConfig
  Future<bool> triggerForBusiness({required String businessId, String? webhookUrl, Map<String, dynamic>? payload, String? hookToken}) async {
    final body = payload ?? {'businessId': businessId, 'date': DateTime.now().toIso8601String()};
    if (webhookUrl != null && webhookUrl.isNotEmpty) {
      final ok = await sendToWebhook(webhookUrl: webhookUrl, payload: body, hookToken: hookToken ?? AppConfig.dailyReportHookToken);
      if (ok) return true;
    }

    // fallback
    if (AppConfig.dailyReportTriggerUrl.isNotEmpty && AppConfig.dailyReportApiKey.isNotEmpty) {
      final ok = await sendToTriggerEndpoint(triggerUrl: AppConfig.dailyReportTriggerUrl, payload: body, apiKey: AppConfig.dailyReportApiKey);
      return ok;
    }

    return false;
  }
}
