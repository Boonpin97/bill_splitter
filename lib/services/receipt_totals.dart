import '../models/receipt.dart';

class ReceiptTotals {
  const ReceiptTotals({
    required this.itemSubtotal,
    required this.discountTotal,
    required this.discountedSubtotal,
    required this.chargesTotal,
    required this.total,
  });

  final double itemSubtotal;
  final double discountTotal;
  final double discountedSubtotal;
  final double chargesTotal;
  final double total;
}

ReceiptTotals calculateReceiptTotals(Receipt receipt) {
  final itemSubtotal = receipt.items.fold<double>(
    0,
    (sum, item) => sum + item.lineTotal,
  );
  var discountedSubtotal = itemSubtotal;
  var discountTotal =
      receipt.charges.any(
        (charge) =>
            charge.mode == ChargeMode.exclusive &&
            charge.kind == ChargeKind.discount,
      )
      ? 0.0
      : _receiptSubtotalDiscount(receipt, itemSubtotal);
  discountedSubtotal -= discountTotal;

  for (final charge in receipt.charges) {
    if (charge.mode != ChargeMode.exclusive ||
        charge.kind != ChargeKind.discount) {
      continue;
    }
    final discount = _chargeAmount(charge, discountedSubtotal).abs();
    discountTotal += discount;
    discountedSubtotal -= discount;
  }

  var runningTotal = discountedSubtotal;
  for (final charge in receipt.charges) {
    if (charge.mode != ChargeMode.exclusive ||
        charge.kind == ChargeKind.discount) {
      continue;
    }
    runningTotal += _chargeAmount(charge, runningTotal);
  }

  return ReceiptTotals(
    itemSubtotal: itemSubtotal,
    discountTotal: discountTotal,
    discountedSubtotal: discountedSubtotal,
    chargesTotal: runningTotal - discountedSubtotal,
    total: runningTotal,
  );
}

double chargeAmountForBase(Charge charge, double base) =>
    _chargeAmount(charge, base);

// Prefer the amount printed on the receipt. Only fall back to the
// percentage when the receipt gave no explicit amount for the charge.
double _chargeAmount(Charge charge, double base) =>
    charge.amount != null
    ? charge.amount!
    : (charge.percent != null ? base * charge.percent! : 0);

double _receiptSubtotalDiscount(Receipt receipt, double itemSubtotal) {
  final printedSubtotal = receipt.subtotal;
  if (printedSubtotal <= 0 || printedSubtotal >= itemSubtotal) return 0;
  return itemSubtotal - printedSubtotal;
}
