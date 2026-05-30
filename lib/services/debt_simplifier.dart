import '../models/split_result.dart';

/// Reduces a map of payer balances (paid - owed) into the minimum-effort
/// transfer list. Greedy creditor/debtor pairing: produces at most N-1
/// transfers, near-optimal in practice.
List<Transfer> simplifyDebts(Map<String, double> balances, {double epsilon = 0.005}) {
  final creditors = <MapEntry<String, double>>[];
  final debtors = <MapEntry<String, double>>[];
  balances.forEach((id, bal) {
    if (bal > epsilon) creditors.add(MapEntry(id, bal));
    if (bal < -epsilon) debtors.add(MapEntry(id, -bal));
  });

  creditors.sort((a, b) => b.value.compareTo(a.value));
  debtors.sort((a, b) => b.value.compareTo(a.value));

  final cr = creditors.map((e) => [e.key, e.value]).toList();
  final db = debtors.map((e) => [e.key, e.value]).toList();

  final out = <Transfer>[];
  int ci = 0, di = 0;
  while (ci < cr.length && di < db.length) {
    final credit = cr[ci][1] as double;
    final debt = db[di][1] as double;
    final amount = credit < debt ? credit : debt;
    if (amount > epsilon) {
      out.add(Transfer(
        fromPayerId: db[di][0] as String,
        toPayerId: cr[ci][0] as String,
        amount: _round2(amount),
      ));
    }
    cr[ci][1] = credit - amount;
    db[di][1] = debt - amount;
    if ((cr[ci][1] as double) <= epsilon) ci++;
    if ((db[di][1] as double) <= epsilon) di++;
  }
  return out;
}

double _round2(double v) => (v * 100).round() / 100.0;
