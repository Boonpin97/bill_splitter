import 'package:flutter/foundation.dart';

import '../models/payer.dart';
import '../models/receipt.dart';
import '../models/split_result.dart';
import '../services/split_math.dart';

class BillState extends ChangeNotifier {
  Receipt? _receipt;
  Receipt? get receipt => _receipt;

  static const _suggestedNames = [
    'Alice',
    'Bob',
    'Charlie',
    'Dave',
    'Erin',
    'Frank',
    'Grace',
    'Henry',
    'Iris',
    'Jack',
    'Kate',
    'Liam',
    'Mia',
    'Noah',
    'Olivia',
    'Paul',
    'Quinn',
    'Riley',
    'Sam',
    'Tara',
    'Uma',
    'Vera',
    'Will',
    'Xena',
    'Yuki',
    'Zoe',
  ];

  final List<Payer> _payers = [
    Payer(name: 'Alice'),
    Payer(name: 'Bob'),
    Payer(name: 'Charlie'),
  ];
  List<Payer> get payers => List.unmodifiable(_payers);

  /// payerId -> itemId -> quantity claimed
  final Map<String, Map<String, int>> _assignments = {};

  /// payerId -> amount paid at the till. Default: first payer paid the total.
  final Map<String, double> _paid = {};

  /// Grand total derived from item line totals + compounded exclusive charges.
  /// This is the authoritative total — receipt.total is only kept for reference.
  double get derivedTotal {
    final r = _receipt;
    if (r == null) return 0;
    final subtotal = r.items.fold<double>(0, (s, item) => s + item.lineTotal);
    double running = subtotal;
    for (final c in r.charges) {
      if (c.mode != ChargeMode.exclusive) continue;
      final amt = c.amount ?? (c.percent != null ? running * c.percent! : 0);
      if (c.kind == ChargeKind.discount) {
        running -= amt.abs();
      } else {
        running += amt;
      }
    }
    return running;
  }

  void setReceipt(Receipt receipt) {
    _receipt = receipt;
    _assignments.clear();
    for (final p in _payers) {
      _assignments[p.id] = {for (final it in receipt.items) it.id: 0};
    }
    _paid
      ..clear()
      ..[_payers.first.id] = derivedTotal;
    notifyListeners();
  }

  int qty(String payerId, String itemId) => _assignments[payerId]?[itemId] ?? 0;

  void setQty(String payerId, String itemId, int value) {
    final v = value < 0 ? 0 : value;
    _assignments.putIfAbsent(payerId, () => {})[itemId] = v;
    notifyListeners();
  }

  void incrementQty(String payerId, String itemId) {
    setQty(payerId, itemId, qty(payerId, itemId) + 1);
  }

  void decrementQty(String payerId, String itemId) {
    setQty(payerId, itemId, qty(payerId, itemId) - 1);
  }

  int assignedFor(String itemId) {
    var sum = 0;
    for (final row in _assignments.values) {
      sum += row[itemId] ?? 0;
    }
    return sum;
  }

  void renamePayer(String id, String name) {
    final p = _payers.firstWhere((p) => p.id == id);
    p.name = name.isEmpty ? p.name : name;
    notifyListeners();
  }

  void addPayer({String? name}) {
    final n = _payers.length;
    final resolvedName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (n < _suggestedNames.length ? _suggestedNames[n] : 'Person ${n + 1}');
    final next = Payer(name: resolvedName);
    _payers.add(next);
    _assignments[next.id] = {
      for (final it in _receipt?.items ?? const <LineItem>[]) it.id: 0,
    };
    _paid[next.id] = 0;
    notifyListeners();
  }

  void removePayer(String id) {
    if (_payers.length <= 1) return;
    _payers.removeWhere((p) => p.id == id);
    _assignments.remove(id);
    final removedPaid = _paid.remove(id) ?? 0;
    if (removedPaid > 0 && _payers.isNotEmpty) {
      _paid[_payers.first.id] = (_paid[_payers.first.id] ?? 0) + removedPaid;
    }
    notifyListeners();
  }

  double paidBy(String payerId) => _paid[payerId] ?? 0;

  void setPaid(String payerId, double amount) {
    _paid[payerId] = amount;
    notifyListeners();
  }

  /// Convenience: set a single payer as the sole bill payer for the
  /// current receipt total.
  void setSolePayer(String payerId) {
    _paid.clear();
    _paid[payerId] = derivedTotal;
    notifyListeners();
  }

  void updateChargeMode(int chargeIndex, ChargeMode mode) {
    final r = _receipt;
    if (r == null) return;
    if (chargeIndex < 0 || chargeIndex >= r.charges.length) return;
    r.charges[chargeIndex].mode = mode;
    notifyListeners();
  }

  void updateChargeAmount(int chargeIndex, double amount) {
    final r = _receipt;
    if (r == null) return;
    if (chargeIndex < 0 || chargeIndex >= r.charges.length) return;
    r.charges[chargeIndex].amount = amount;
    r.charges[chargeIndex].percent = null;
    notifyListeners();
  }

  void updateChargePercent(int chargeIndex, double percent) {
    final r = _receipt;
    if (r == null) return;
    if (chargeIndex < 0 || chargeIndex >= r.charges.length) return;
    r.charges[chargeIndex].percent = percent;
    r.charges[chargeIndex].amount = null;
    notifyListeners();
  }

  void updateItemQuantity(String itemId, int quantity) {
    final item = _findItem(itemId);
    if (item == null) return;
    item.quantity = quantity;
    notifyListeners();
  }

  void updateItemUnitPrice(String itemId, double unitPrice) {
    final item = _findItem(itemId);
    if (item == null) return;
    item.unitPrice = unitPrice;
    notifyListeners();
  }

  void updateItemLineTotal(String itemId, double lineTotal) {
    final item = _findItem(itemId);
    if (item == null) return;
    item.unitPrice = item.quantity == 0 ? lineTotal : lineTotal / item.quantity;
    notifyListeners();
  }

  void updateSubtotal(double subtotal) {
    final r = _receipt;
    if (r == null) return;
    r.subtotal = subtotal;
    notifyListeners();
  }

  void updateTotal(double total) {
    final r = _receipt;
    if (r == null) return;
    r.total = total;
    notifyListeners();
  }

  LineItem? _findItem(String itemId) {
    final r = _receipt;
    if (r == null) return null;
    for (final item in r.items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  SplitResult? splitResult() {
    final r = _receipt;
    if (r == null) return null;
    return computeSplit(
      receipt: r,
      payers: _payers,
      assignments: _assignments,
      paid: _paid,
    );
  }
}
