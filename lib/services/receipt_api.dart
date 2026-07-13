import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/receipt.dart';

enum ReceiptAnalysisStage { warmingServer, sendingImage, waitingForGoogle }

typedef ReceiptAnalysisStageCallback =
    void Function(ReceiptAnalysisStage stage);

String formatReceiptAnalysisError(Object error) {
  final raw = '$error';
  final normalized = raw.toLowerCase();

  if (_isServerUnreachableError(normalized)) {
    return "Can't reach the server :/";
  }
  if (_isGeminiHighDemandError(normalized)) {
    return "Opss it's in high demand right now";
  }
  if (_isLimitExceededError(normalized)) {
    return "Alright that's all I can process for today";
  }
  return raw;
}

bool _isServerUnreachableError(String normalized) {
  return normalized.contains('failed host lookup') ||
      normalized.contains('socketexception') ||
      normalized.contains('xmlhttprequest error') ||
      normalized.contains('clientexception') ||
      normalized.contains('failed to fetch') ||
      normalized.contains('network request failed') ||
      (normalized.contains('google') &&
          (normalized.contains('unreachable') ||
              normalized.contains('unavailable') ||
              normalized.contains('dns') ||
              normalized.contains('econnreset') ||
              normalized.contains('enotfound')));
}

bool _isGeminiHighDemandError(String normalized) {
  return normalized.contains('gemini call failed: 429') ||
      normalized.contains('resource exhausted') ||
      normalized.contains('high demand') ||
      normalized.contains('currently overloaded') ||
      normalized.contains('too many requests');
}

bool _isLimitExceededError(String normalized) {
  return normalized.contains('limit exceeded') ||
      normalized.contains('quota exceeded') ||
      normalized.contains('daily limit') ||
      normalized.contains('daily quota');
}

abstract class ReceiptAnalyzer {
  Receipt? get sampleReceipt => null;

  Future<Receipt> analyze(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    bool useOcr = false,
    ReceiptAnalysisStageCallback? onStage,
  });

  /// Fire a no-op request at the backend so a warm Cloud Run instance is
  /// ready by the time the user actually uploads a receipt. Best-effort —
  /// failures are swallowed so they never affect the UI.
  Future<void> warm() async {}
}

/// HTTP analyzer pointing at the Cloud Function via the Firebase Hosting rewrite
/// `/api/analyzeReceipt`. When built and served from the same Hosting origin the
/// relative path works directly; for local dev set `--dart-define=API_BASE=https://bill-splitt.web.app`
/// to call the deployed instance.
class FirebaseReceiptAnalyzer extends ReceiptAnalyzer {
  FirebaseReceiptAnalyzer({String apiBase = ''})
    : _endpoint = Uri.parse(
        '${apiBase.isEmpty ? '' : apiBase}/api/analyzeReceipt',
      );

  final Uri _endpoint;

  @override
  Future<void> warm() async {
    try {
      await http.get(_endpoint).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Warmup is best-effort.
    }
  }

  @override
  Future<Receipt> analyze(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    bool useOcr = false,
    ReceiptAnalysisStageCallback? onStage,
  }) async {
    onStage?.call(ReceiptAnalysisStage.warmingServer);
    await warm();

    onStage?.call(ReceiptAnalysisStage.sendingImage);
    final body = jsonEncode({
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
      if (useOcr) 'analysisMode': 'ocr',
    });

    onStage?.call(ReceiptAnalysisStage.waitingForGoogle);
    final res = await http.post(
      _endpoint,
      headers: const {'content-type': 'application/json'},
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Receipt analysis failed (${res.statusCode}): ${res.body}',
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Receipt.fromJson(data);
  }
}

/// Local stand-in used until the Cloud Function is deployed.
class MockReceiptAnalyzer extends ReceiptAnalyzer {
  @override
  Receipt get sampleReceipt => Receipt.fromJson({
    'currency': 'SGD',
    'items': [
      {'name': 'Char Kway Teow', 'unitPrice': 8.5, 'quantity': 1},
      {'name': 'Hokkien Mee', 'unitPrice': 9.0, 'quantity': 1},
      {'name': 'Satay (10 sticks)', 'unitPrice': 12.0, 'quantity': 1},
      {'name': 'Iced Milo', 'unitPrice': 3.5, 'quantity': 2},
      {'name': 'Sugarcane Juice', 'unitPrice': 3.0, 'quantity': 1},
    ],
    'charges': [
      {'kind': 'service', 'mode': 'exclusive', 'percent': 0.10},
      {'kind': 'gst', 'mode': 'exclusive', 'percent': 0.09},
    ],
    'subtotal': 39.5,
    'total': 47.36,
  });

  @override
  Future<void> warm() async {}

  @override
  Future<Receipt> analyze(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    bool useOcr = false,
    ReceiptAnalysisStageCallback? onStage,
  }) async {
    onStage?.call(ReceiptAnalysisStage.warmingServer);
    await Future.delayed(const Duration(milliseconds: 250));
    onStage?.call(ReceiptAnalysisStage.sendingImage);
    await Future.delayed(const Duration(milliseconds: 250));
    onStage?.call(ReceiptAnalysisStage.waitingForGoogle);
    await Future.delayed(const Duration(milliseconds: 5000));
    return sampleReceipt;
  }
}
