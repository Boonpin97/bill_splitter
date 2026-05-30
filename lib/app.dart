import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/receipt_api.dart';
import 'state/bill_state.dart';
import 'theme/app_theme.dart';

class BillApp extends StatelessWidget {
  const BillApp({super.key, required this.analyzer});

  final ReceiptAnalyzer analyzer;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ReceiptAnalyzer>.value(value: analyzer),
        ChangeNotifierProvider(create: (_) => BillState()),
      ],
      child: MaterialApp(
        title: 'Split / Receipt',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
