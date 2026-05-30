import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';

class ChargesPanel extends StatelessWidget {
  const ChargesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final receipt = state.receipt;
    if (receipt == null || receipt.charges.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;

    final derivedSubtotal =
        receipt.items.fold<double>(0, (s, item) => s + item.lineTotal);

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
            for (int i = 0; i < receipt.charges.length; i++)
              _ChargeTile(
                charge: receipt.charges[i],
                subtotal: derivedSubtotal,
                onModeChange: (m) => state.updateChargeMode(i, m),
                onAmountChange: (v) => state.updateChargeAmount(i, v),
                onPercentChange: (v) => state.updateChargePercent(i, v),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChargeTile extends StatelessWidget {
  const _ChargeTile({
    required this.charge,
    required this.subtotal,
    required this.onModeChange,
    required this.onAmountChange,
    required this.onPercentChange,
  });

  final Charge charge;
  final double subtotal;
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

    final computedAmount = pct != null
        ? subtotal * pct
        : (charge.amount ?? 0);
    final descriptor = computedAmount.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
              ButtonSegment(value: ChargeMode.exclusive, label: Text('Excl')),
              ButtonSegment(value: ChargeMode.inclusive, label: Text('Incl')),
            ],
            selected: {charge.mode},
            onSelectionChanged: (s) => onModeChange(s.first),
          ),
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
