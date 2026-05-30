import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_bill_split/services/debt_simplifier.dart';

void main() {
  group('simplifyDebts', () {
    test('returns no transfers when balances are zero', () {
      final out = simplifyDebts({'a': 0, 'b': 0, 'c': 0});
      expect(out, isEmpty);
    });

    test('two-payer: debtor pays creditor', () {
      final out = simplifyDebts({'alice': 30.0, 'bob': -30.0});
      expect(out, hasLength(1));
      expect(out.first.fromPayerId, 'bob');
      expect(out.first.toPayerId, 'alice');
      expect(out.first.amount, 30.0);
    });

    test('three-payer with one creditor produces two transfers', () {
      final out = simplifyDebts({'alice': 40.0, 'bob': -25.0, 'carol': -15.0});
      expect(out, hasLength(2));
      expect(out.every((t) => t.toPayerId == 'alice'), isTrue);
      final total = out.fold<double>(0, (s, t) => s + t.amount);
      expect(total, closeTo(40.0, 0.01));
    });

    test('four-payer with two creditors and two debtors → at most 3 transfers',
        () {
      final out = simplifyDebts({
        'a': 50.0,
        'b': 20.0,
        'c': -30.0,
        'd': -40.0,
      });
      expect(out.length, lessThanOrEqualTo(3));
      // Conservation: total transferred equals creditor sum (≈ debtor sum).
      final total = out.fold<double>(0, (s, t) => s + t.amount);
      expect(total, closeTo(70.0, 0.02));
    });

    test('ignores sub-cent residuals', () {
      final out = simplifyDebts({'a': 0.001, 'b': -0.001});
      expect(out, isEmpty);
    });
  });
}
