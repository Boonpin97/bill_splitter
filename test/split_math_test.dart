import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_bill_split/models/payer.dart';
import 'package:receipt_bill_split/models/receipt.dart';
import 'package:receipt_bill_split/services/split_math.dart';

void main() {
  group('computeSplit', () {
    test('exclusive GST + service: apportioned by subtotal share', () {
      final i1 = LineItem(name: 'Item A', unitPrice: 10, quantity: 1);
      final i2 = LineItem(name: 'Item B', unitPrice: 30, quantity: 1);
      final receipt = Receipt(
        currency: 'SGD',
        items: [i1, i2],
        charges: [
          Charge(
              kind: ChargeKind.serviceCharge,
              mode: ChargeMode.exclusive,
              percent: 0.10),
          Charge(
              kind: ChargeKind.gst,
              mode: ChargeMode.exclusive,
              percent: 0.09),
        ],
        subtotal: 40,
        total: 47.60,
      );

      final alice = Payer(name: 'Alice');
      final bob = Payer(name: 'Bob');

      final result = computeSplit(
        receipt: receipt,
        payers: [alice, bob],
        assignments: {
          alice.id: {i1.id: 1, i2.id: 0},
          bob.id: {i1.id: 0, i2.id: 1},
        },
        paid: {alice.id: 0, bob.id: 47.60},
      );

      final aliceTotal =
          result.totals.firstWhere((t) => t.payerId == alice.id);
      final bobTotal = result.totals.firstWhere((t) => t.payerId == bob.id);

      // Alice: 10 + 10*(0.19) = 11.90; Bob: 30 + 30*(0.19) = 35.70
      expect(aliceTotal.total, closeTo(11.90, 0.02));
      expect(bobTotal.total, closeTo(35.70, 0.02));

      // Sum of totals ≈ grand total
      final sum =
          result.totals.fold<double>(0, (s, t) => s + t.total);
      expect(sum, closeTo(result.grandTotal, 0.01));

      // Bob paid the bill, Alice owes him her share.
      expect(result.transfers, hasLength(1));
      expect(result.transfers.first.fromPayerId, alice.id);
      expect(result.transfers.first.toPayerId, bob.id);
    });

    test('inclusive charge does not double-count', () {
      final item = LineItem(name: 'X', unitPrice: 21.80, quantity: 1);
      final receipt = Receipt(
        currency: 'SGD',
        items: [item],
        charges: [
          // Already in the unit price; should not be added on top.
          Charge(
              kind: ChargeKind.gst,
              mode: ChargeMode.inclusive,
              percent: 0.09),
        ],
        subtotal: 21.80,
        total: 21.80,
      );
      final a = Payer(name: 'A');
      final b = Payer(name: 'B');
      final result = computeSplit(
        receipt: receipt,
        payers: [a, b],
        assignments: {
          a.id: {item.id: 1},
          b.id: {item.id: 0},
        },
        paid: {a.id: 21.80, b.id: 0},
      );
      final aTotal =
          result.totals.firstWhere((t) => t.payerId == a.id);
      expect(aTotal.total, closeTo(21.80, 0.01));
      expect(result.grandTotal, closeTo(21.80, 0.01));
    });

    test('split item: 1+1 of qty-2 item, exclusive 10% service', () {
      final shared = LineItem(name: 'Pizza', unitPrice: 20, quantity: 2);
      final receipt = Receipt(
        currency: 'USD',
        items: [shared],
        charges: [
          Charge(
              kind: ChargeKind.serviceCharge,
              mode: ChargeMode.exclusive,
              percent: 0.10),
        ],
        subtotal: 40,
        total: 44,
      );
      final a = Payer(name: 'A');
      final b = Payer(name: 'B');
      final result = computeSplit(
        receipt: receipt,
        payers: [a, b],
        assignments: {
          a.id: {shared.id: 1},
          b.id: {shared.id: 1},
        },
        paid: {a.id: 44, b.id: 0},
      );
      final aT = result.totals.firstWhere((t) => t.payerId == a.id);
      final bT = result.totals.firstWhere((t) => t.payerId == b.id);
      expect(aT.total, closeTo(22.0, 0.01));
      expect(bT.total, closeTo(22.0, 0.01));
      expect(result.transfers, hasLength(1));
      expect(result.transfers.first.amount, closeTo(22.0, 0.01));
    });

    test('discount charge subtracts proportionally', () {
      final i = LineItem(name: 'X', unitPrice: 50, quantity: 1);
      final receipt = Receipt(
        currency: 'USD',
        items: [i],
        charges: [
          Charge(
              kind: ChargeKind.discount,
              mode: ChargeMode.exclusive,
              amount: 10),
        ],
        subtotal: 50,
        total: 40,
      );
      final a = Payer(name: 'A');
      final result = computeSplit(
        receipt: receipt,
        payers: [a],
        assignments: {
          a.id: {i.id: 1},
        },
        paid: {a.id: 40},
      );
      expect(result.totals.first.total, closeTo(40.0, 0.01));
      expect(result.grandTotal, closeTo(40.0, 0.01));
    });
  });
}
