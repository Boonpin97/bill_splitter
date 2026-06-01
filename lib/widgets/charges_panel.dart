import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../services/receipt_totals.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';

class ChargesPanel extends StatelessWidget {
  const ChargesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final receipt = state.receipt;
    final charges =
        receipt?.charges
            .where((charge) => charge.kind != ChargeKind.discount)
            .toList() ??
        const <Charge>[];
    if (receipt == null || charges.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.simpleCurrency(
      name: receipt.currency,
      decimalDigits: 2,
    );

    final chargeRows = _chargeRows(receipt);
    final totalCharges = chargeRows.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.percent_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tax & service',
                  style: AppFonts.flex(
                    size: 14,
                    weight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'How were they charged?',
              style: AppFonts.flex(size: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final row in chargeRows)
              _ChargeTile(
                charge: row.charge,
                amount: row.amount,
                printedAmount: row.printedAmount,
                onModeChange: (m) => state.updateChargeMode(row.index, m),
                onAmountChange: (v) => state.updateChargeAmount(row.index, v),
                onPercentChange: (v) => state.updateChargePercent(row.index, v),
              ),
            Divider(color: scheme.outlineVariant, height: 18),
            Row(
              children: [
                Text(
                  'Total tax and service',
                  style: AppFonts.flex(
                    size: 13,
                    weight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  fmt.format(totalCharges),
                  style: AppFonts.mono(
                    size: 13,
                    weight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<_ChargeRow> _chargeRows(Receipt receipt) {
  final rows = <_ChargeRow>[];
  var running = calculateReceiptTotals(receipt).discountedSubtotal;

  for (int i = 0; i < receipt.charges.length; i++) {
    final charge = receipt.charges[i];
    if (charge.mode != ChargeMode.exclusive) {
      if (charge.kind != ChargeKind.discount) {
        rows.add(_ChargeRow(index: i, charge: charge, amount: 0));
      }
      continue;
    }
    if (charge.kind == ChargeKind.discount) continue;

    final amount = chargeAmountForBase(charge, running);
    rows.add(_ChargeRow(index: i, charge: charge, amount: amount));
    running += amount;
  }

  return rows;
}

class _ChargeRow {
  const _ChargeRow({
    required this.index,
    required this.charge,
    required this.amount,
  });

  final int index;
  final Charge charge;
  final double amount;

  double? get printedAmount => charge.percent != null ? charge.amount : null;
}

class _ChargeTile extends StatelessWidget {
  const _ChargeTile({
    required this.charge,
    required this.amount,
    required this.printedAmount,
    required this.onModeChange,
    required this.onAmountChange,
    required this.onPercentChange,
  });

  final Charge charge;
  final double amount;
  final double? printedAmount;
  final ValueChanged<ChargeMode> onModeChange;
  final ValueChanged<double> onAmountChange;
  final ValueChanged<double> onPercentChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pct = charge.percent;
    final pctStr = pct != null
        ? ((pct * 100) % 1 == 0
              ? '${(pct * 100).toInt()}%'
              : '${(pct * 100).toStringAsFixed(1)}%')
        : null;
    final title = pctStr != null
        ? '${charge.displayName()} ($pctStr)'
        : charge.displayName();

    final descriptor = amount.toStringAsFixed(2);
    final printed = printedAmount;
    final hasPrintedMismatch =
        pct != null && printed != null && (printed - amount).abs() > 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.flex(
                        size: 14,
                        weight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _editChargeValue(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          descriptor,
                          style: AppFonts.mono(
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<ChargeMode>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: ChargeMode.exclusive,
                    label: Text('Excl'),
                  ),
                  ButtonSegment(
                    value: ChargeMode.inclusive,
                    label: Text('Incl'),
                  ),
                ],
                selected: {charge.mode},
                onSelectionChanged: (s) => onModeChange(s.first),
              ),
            ],
          ),
          if (hasPrintedMismatch) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt amount differs from calculated amount.',
                    style: AppFonts.flex(
                      size: 12,
                      weight: FontWeight.w600,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Calculated: ${amount.toStringAsFixed(2)}  |  Receipt: ${printed.toStringAsFixed(2)}',
                    style: AppFonts.mono(
                      size: 12,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => onPercentChange(pct),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: scheme.onErrorContainer,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Text('Use calculated'),
                      ),
                      FilledButton(
                        onPressed: () => onAmountChange(printed),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        child: const Text('Use receipt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editChargeValue(BuildContext context) async {
    final isPercent = charge.percent != null;
    final next = await _showSignedNumberDialog(
      context,
      title: 'Edit ${charge.displayName()}',
      label: isPercent ? 'Percent' : 'Amount',
      initialValue: isPercent
          ? (charge.percent! * 100).toStringAsFixed(2)
          : (charge.amount ?? 0).toStringAsFixed(2),
    );
    if (next == null) return;
    if (isPercent) {
      onPercentChange(next / 100);
    } else {
      onAmountChange(next);
    }
  }
}

Future<double?> _showSignedNumberDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
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
