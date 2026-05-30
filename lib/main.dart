import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/receipt_api.dart';

const bool _useMockAnalyzer =
    bool.fromEnvironment('USE_MOCK_ANALYZER', defaultValue: true);

/// For local dev against the deployed backend, pass
/// `--dart-define=API_BASE=https://bill-splitt.web.app`.
/// When the bundle is served by Firebase Hosting itself, leave this empty so
/// the request goes to the same origin (`/api/analyzeReceipt`).
const String _apiBase = String.fromEnvironment('API_BASE', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final ReceiptAnalyzer analyzer;
  if (_useMockAnalyzer) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[receipt_bill_split] Using MockReceiptAnalyzer.');
    }
    analyzer = MockReceiptAnalyzer();
  } else {
    analyzer = FirebaseReceiptAnalyzer(apiBase: _apiBase);
  }

  runApp(BillApp(analyzer: analyzer));
}
