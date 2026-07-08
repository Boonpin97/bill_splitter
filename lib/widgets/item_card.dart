import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/payer.dart';
import '../models/receipt.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';
import 'payer_avatar.dart';

/// One receipt item row: name, price, and a wrap of tappable payer avatars.
/// Tap toggles 0↔1. Long-press opens a numeric quantity dialog.
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.item, required this.fmt});

  final LineItem item;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final scheme = Theme.of(context).colorScheme;
    final qty = item.quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppFonts.flex(
                        size: 15,
                        weight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _QuantityBadge(
                      qty: qty,
                      onTap: () => _editReceiptQty(context, state),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _editLineTotal(context, state),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        fmt.format(item.unitPrice * item.quantity),
                        style: AppFonts.mono(
                          size: 15,
                          weight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (item.quantity > 1) ...[
                    const SizedBox(height: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _editUnitPrice(context, state),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          '${fmt.format(item.unitPrice)} each',
                          style: AppFonts.mono(
                            size: 11,
                            weight: FontWeight.w400,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AvatarRow(item: item, payers: state.payers, state: state),
        ],
      ),
    );
  }

  Future<void> _editReceiptQty(BuildContext context, BillState state) async {
    final next = await _showSignedNumberDialog(
      context,
      title: 'Edit quantity',
      label: 'Quantity',
      initialValue: item.quantity.toString(),
      decimal: false,
    );
    if (next == null) return;
    state.updateItemQuantity(item.id, next.round());
  }

  Future<void> _editLineTotal(BuildContext context, BillState state) async {
    final next = await _showSignedNumberDialog(
      context,
      title: 'Edit line amount',
      label: 'Amount',
      initialValue: item.lineTotal.toStringAsFixed(2),
    );
    if (next == null) return;
    state.updateItemLineTotal(item.id, next);
  }

  Future<void> _editUnitPrice(BuildContext context, BillState state) async {
    final next = await _showSignedNumberDialog(
      context,
      title: 'Edit unit price',
      label: 'Unit price',
      initialValue: item.unitPrice.toStringAsFixed(2),
    );
    if (next == null) return;
    state.updateItemUnitPrice(item.id, next);
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.qty, required this.onTap});

  final int qty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 12,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              'Qty $qty',
              style: AppFonts.mono(
                size: 11,
                weight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({
    required this.item,
    required this.payers,
    required this.state,
  });

  final LineItem item;
  final List<Payer> payers;
  final BillState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (int i = 0; i < payers.length; i++)
          _PayerQtyChip(
            payer: payers[i],
            index: i,
            qty: state.qty(payers[i].id, item.id),
            onToggle: () {
              final cur = state.qty(payers[i].id, item.id);
              state.setQty(payers[i].id, item.id, cur > 0 ? 0 : 1);
            },
            onDecrement: () => state.decrementQty(payers[i].id, item.id),
            onIncrement: () => state.incrementQty(payers[i].id, item.id),
            onEdit: () => _editQty(context, payers[i], item),
          ),
      ],
    );
  }

  Future<void> _editQty(
    BuildContext context,
    Payer payer,
    LineItem item,
  ) async {
    final cur = state.qty(payer.id, item.id);
    final controller = TextEditingController(text: '$cur');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${payer.name} — ${item.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v) ?? cur),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text) ?? cur),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) state.setQty(payer.id, item.id, result);
  }
}

Future<double?> _showSignedNumberDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  bool decimal = true,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          signed: true,
          decimal: decimal,
        ),
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) =>
            Navigator.of(ctx).pop(double.tryParse(controller.text.trim())),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(ctx).pop(double.tryParse(controller.text.trim())),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// A payer's avatar with a −/+ stepper beneath it, so each person's
/// quantity for the item can be set directly. Tapping the avatar toggles
/// the person in/out (0↔1); tapping the number opens a dialog to type an
/// exact quantity.
class _PayerQtyChip extends StatelessWidget {
  const _PayerQtyChip({
    required this.payer,
    required this.index,
    required this.qty,
    required this.onToggle,
    required this.onDecrement,
    required this.onIncrement,
    required this.onEdit,
  });

  final Payer payer;
  final int index;
  final int qty;
  final VoidCallback onToggle;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '${payer.name}${qty > 0 ? ' · ×$qty' : ''}',
          child: GestureDetector(
            onTap: onToggle,
            onLongPress: onEdit,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: PayerAvatar(
                payer: payer,
                colorIndex: index,
                size: 40,
                qty: qty,
                outlined: true,
                showCount: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _QtyStepper(
          qty: qty,
          onDecrement: onDecrement,
          onIncrement: onIncrement,
        ),
      ],
    );
  }
}

/// Compact −/+ pill for adjusting one payer's quantity of an item. The
/// current count is not shown here — it overlaps the avatar's bottom-right
/// corner instead.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            enabled: qty > 0,
            onTap: onDecrement,
          ),
          const SizedBox(width: 4),
          _StepButton(
            icon: Icons.add,
            enabled: true,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? scheme.onSurfaceVariant : scheme.outlineVariant,
        ),
      ),
    );
  }
}
