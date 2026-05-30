class ChargeEntry {
  const ChargeEntry({required this.label, required this.amount, this.percent});
  final String label;
  final double amount;
  final double? percent; // e.g. 0.09 for 9%; null for flat-amount charges

  String get displayLabel {
    if (percent == null) return label;
    final pct = percent! * 100;
    final pctStr = pct % 1 == 0 ? '${pct.toInt()}%' : '${pct}%';
    return '$label ($pctStr)';
  }
}

class PayerTotal {
  PayerTotal({
    required this.payerId,
    required this.itemTotal,
    required this.chargeShare,
    this.chargeBreakdown = const [],
  });

  final String payerId;
  final double itemTotal;
  final double chargeShare;
  final List<ChargeEntry> chargeBreakdown;

  double get total => itemTotal + chargeShare;
}

class Transfer {
  Transfer({required this.fromPayerId, required this.toPayerId, required this.amount});

  final String fromPayerId;
  final String toPayerId;
  final double amount;
}

class SplitResult {
  SplitResult({required this.totals, required this.transfers, required this.grandTotal});

  final List<PayerTotal> totals;
  final List<Transfer> transfers;
  final double grandTotal;
}
