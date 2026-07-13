import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_bill_split/models/receipt.dart';
import 'package:receipt_bill_split/state/bill_state.dart';

void main() {
  test(
    'quantity warning becomes eligible only after moving to another dish',
    () {
      final first = LineItem(name: 'First dish', unitPrice: 10, quantity: 2);
      final second = LineItem(name: 'Second dish', unitPrice: 8);
      final state = BillState()
        ..setReceipt(
          Receipt(
            currency: 'SGD',
            items: [first, second],
            charges: [],
            subtotal: 28,
            total: 28,
          ),
        );
      final payer = state.payers.first;

      state.setQty(payer.id, first.id, 1);
      expect(state.shouldShowQuantityWarning(first.id), isFalse);

      state.focusAssignmentItem(second.id);
      expect(state.shouldShowQuantityWarning(first.id), isTrue);
      expect(state.shouldShowQuantityWarning(second.id), isFalse);

      state.focusAssignmentItem(first.id);
      expect(state.shouldShowQuantityWarning(first.id), isFalse);
      expect(state.shouldShowQuantityWarning(second.id), isFalse);

      state.setQty(payer.id, second.id, 1);
      state.focusAssignmentItem(first.id);
      expect(state.shouldShowQuantityWarning(second.id), isTrue);
    },
  );

  test('loading a receipt resets assignment warning history', () {
    final first = LineItem(name: 'First dish', unitPrice: 10);
    final second = LineItem(name: 'Second dish', unitPrice: 8);
    final receipt = Receipt(
      currency: 'SGD',
      items: [first, second],
      charges: [],
      subtotal: 18,
      total: 18,
    );
    final state = BillState()..setReceipt(receipt);
    final payer = state.payers.first;

    state.setQty(payer.id, first.id, 2);
    state.setQty(payer.id, second.id, 1);
    expect(state.shouldShowQuantityWarning(first.id), isTrue);

    state.setReceipt(receipt);
    expect(state.shouldShowQuantityWarning(first.id), isFalse);
  });

  test('quantity mismatches compare total shares with receipt quantities', () {
    final first = LineItem(name: 'First dish', unitPrice: 10, quantity: 2);
    final second = LineItem(name: 'Second dish', unitPrice: 8);
    final state = BillState()
      ..setReceipt(
        Receipt(
          currency: 'SGD',
          items: [first, second],
          charges: [],
          subtotal: 28,
          total: 28,
        ),
      );
    final payer = state.payers.first;

    expect(state.quantityMismatchItems, containsAll([first, second]));

    state.setQty(payer.id, first.id, 2);
    expect(state.quantityMismatchItems, [second]);

    state.setQty(payer.id, second.id, 1);
    expect(state.quantityMismatchItems, isEmpty);
  });
}
