import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_bill_split/services/receipt_api.dart';

void main() {
  test('mock analyzer exposes deterministic local sample data', () {
    final receipt = MockReceiptAnalyzer().sampleReceipt;

    expect(receipt.currency, 'SGD');
    expect(receipt.items, hasLength(5));
    expect(receipt.total, 47.36);
  });

  group('formatReceiptAnalysisError', () {
    test('maps unreachable server errors', () {
      expect(
        formatReceiptAnalysisError(
          Exception('ClientException: Failed to fetch https://googleapis.com'),
        ),
        "Can't reach the server :/",
      );
    });

    test('maps gemini high demand errors', () {
      expect(
        formatReceiptAnalysisError(
          Exception(
            '{"error":"Gemini call failed: 429","detail":"high demand"}',
          ),
        ),
        "Opss it's in high demand right now",
      );
    });

    test('maps limit exceeded errors', () {
      expect(
        formatReceiptAnalysisError(
          Exception('{"error":"limit exceeded","detail":"daily quota"}'),
        ),
        "Alright that's all I can process for today",
      );
    });
  });
}
