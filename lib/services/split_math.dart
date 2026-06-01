import '../models/receipt.dart';
import '../models/payer.dart';
import '../models/split_result.dart';
import 'debt_simplifier.dart';
import 'receipt_totals.dart';

/// Computes per-payer totals and simplified transfers from the receipt,
/// the assignment grid (payerId -> itemId -> quantity), and how much each
/// payer actually paid at the till.
SplitResult computeSplit({
  required Receipt receipt,
  required List<Payer> payers,
  required Map<String, Map<String, int>> assignments,
  required Map<String, double> paid,
}) {
  final itemById = {for (final it in receipt.items) it.id: it};

  // Sum claimed shares per item across all payers so we can split proportionally.
  // Only count non-zero claims so we never divide by zero.
  final totalClaimed = <String, int>{};
  for (final p in payers) {
    for (final entry in (assignments[p.id] ?? const {}).entries) {
      if (entry.value > 0) {
        totalClaimed[entry.key] = (totalClaimed[entry.key] ?? 0) + entry.value;
      }
    }
  }

  final itemTotals = <String, double>{for (final p in payers) p.id: 0};
  for (final p in payers) {
    final perItem = assignments[p.id] ?? const {};
    for (final entry in perItem.entries) {
      if (entry.value == 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      final shares = totalClaimed[entry.key] ?? 1;
      itemTotals[p.id] =
          (itemTotals[p.id] ?? 0) + (entry.value / shares) * item.lineTotal;
    }
  }

  final subtotalAcross = itemTotals.values.fold<double>(0, (a, b) => a + b);
  final discountedItemTotals = Map<String, double>.from(itemTotals);
  var discountedSubtotal = subtotalAcross;
  if (!_hasExclusiveDiscount(receipt)) {
    final discount = _receiptSubtotalDiscount(receipt, subtotalAcross);
    _applyDiscount(discountedItemTotals, payers, discountedSubtotal, discount);
    discountedSubtotal -= discount;
  }

  for (final c in receipt.charges) {
    if (c.mode != ChargeMode.exclusive || c.kind != ChargeKind.discount) {
      continue;
    }
    final discount = chargeAmountForBase(c, discountedSubtotal).abs();
    _applyDiscount(discountedItemTotals, payers, discountedSubtotal, discount);
    discountedSubtotal -= discount;
  }

  // Exclusive charges compound on each other in receipt order
  // (e.g. service charge first, then GST on subtotal + service).
  // Also build a per-payer breakdown for display on the summary screen.
  final perPayerBreakdowns = <String, List<ChargeEntry>>{
    for (final p in payers) p.id: [],
  };
  double runningTotal = discountedSubtotal;
  for (final c in receipt.charges) {
    if (c.mode != ChargeMode.exclusive || c.kind == ChargeKind.discount) {
      continue;
    }
    final amt = chargeAmountForBase(c, runningTotal);
    for (final p in payers) {
      final proportion = discountedSubtotal > 0
          ? (discountedItemTotals[p.id] ?? 0) / discountedSubtotal
          : 0.0;
      final personAmt = _round2(amt * proportion);
      perPayerBreakdowns[p.id]!.add(
        ChargeEntry(
          label: c.displayName(),
          amount: personAmt,
          percent: c.percent,
        ),
      );
    }
    runningTotal += amt;
  }
  final exclusiveCharges = runningTotal - discountedSubtotal;

  final chargeShare = <String, double>{};
  for (final p in payers) {
    if (discountedSubtotal <= 0) {
      chargeShare[p.id] = 0;
    } else {
      chargeShare[p.id] =
          exclusiveCharges *
          ((discountedItemTotals[p.id] ?? 0) / discountedSubtotal);
    }
  }

  // Round totals; absorb residual into first payer with a non-zero subtotal.
  final rawTotals = <String, double>{
    for (final p in payers)
      p.id: (discountedItemTotals[p.id] ?? 0) + (chargeShare[p.id] ?? 0),
  };
  final rounded = <String, double>{
    for (final entry in rawTotals.entries) entry.key: _round2(entry.value),
  };
  final grand = discountedSubtotal + exclusiveCharges;
  final residual =
      _round2(grand) - rounded.values.fold<double>(0, (a, b) => a + b);
  if (residual.abs() > 0.0001 && payers.isNotEmpty) {
    final anchor = payers
        .firstWhere(
          (p) => (discountedItemTotals[p.id] ?? 0) > 0,
          orElse: () => payers.first,
        )
        .id;
    rounded[anchor] = _round2((rounded[anchor] ?? 0) + residual);
  }

  final totals = payers
      .map(
        (p) => PayerTotal(
          payerId: p.id,
          itemTotal: _round2(discountedItemTotals[p.id] ?? 0),
          chargeShare: _round2(
            (rounded[p.id] ?? 0) - (discountedItemTotals[p.id] ?? 0),
          ),
          chargeBreakdown: perPayerBreakdowns[p.id] ?? [],
        ),
      )
      .toList();

  final balances = <String, double>{
    for (final p in payers) p.id: (paid[p.id] ?? 0) - (rounded[p.id] ?? 0),
  };
  final transfers = simplifyDebts(balances);

  return SplitResult(
    totals: totals,
    transfers: transfers,
    grandTotal: _round2(grand),
  );
}

double _round2(double v) => (v * 100).round() / 100.0;

bool _hasExclusiveDiscount(Receipt receipt) => receipt.charges.any(
  (charge) =>
      charge.mode == ChargeMode.exclusive && charge.kind == ChargeKind.discount,
);

double _receiptSubtotalDiscount(Receipt receipt, double itemSubtotal) {
  final printedSubtotal = receipt.subtotal;
  if (printedSubtotal <= 0 || printedSubtotal >= itemSubtotal) return 0;
  return itemSubtotal - printedSubtotal;
}

void _applyDiscount(
  Map<String, double> itemTotals,
  List<Payer> payers,
  double subtotal,
  double discount,
) {
  if (subtotal <= 0 || discount <= 0) return;
  for (final p in payers) {
    final current = itemTotals[p.id] ?? 0;
    final proportion = current / subtotal;
    itemTotals[p.id] = current - (discount * proportion);
  }
}
