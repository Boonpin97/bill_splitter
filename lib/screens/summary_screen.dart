import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/split_result.dart';
import '../services/receipt_totals.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_background.dart';
import '../widgets/payer_avatar.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final receipt = state.receipt;
    final split = state.splitResult();
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.simpleCurrency(
      name: receipt?.currency ?? 'USD',
      decimalDigits: 2,
    );
    final payersById = {for (final p in state.payers) p.id: p};
    final payerIndex = {
      for (int i = 0; i < state.payers.length; i++) state.payers[i].id: i,
    };

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Summary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: receipt == null || split == null
          ? const Center(child: Text('Nothing to summarize.'))
          : PageShell(
              padBottom: 32,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Reveal(
                      child: Card(
                        color: scheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grand total',
                                style: AppFonts.label(
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fmt.format(split.grandTotal),
                                style: AppFonts.serif(
                                  size: 48,
                                  weight: FontWeight.w400,
                                  color: scheme.onSecondaryContainer,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                split.transfers.isEmpty
                                    ? 'All settled.'
                                    : '${split.transfers.length} transfer${split.transfers.length == 1 ? '' : 's'} to settle.',
                                style: AppFonts.flex(
                                  size: 13,
                                  color: scheme.onSecondaryContainer.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Reveal(
                      delay: const Duration(milliseconds: 60),
                      child: Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.groups_2_outlined,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Per person',
                                    style: AppFonts.flex(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (int i = 0; i < split.totals.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  color: scheme.outlineVariant,
                                  height: 1,
                                  indent: 20,
                                  endIndent: 20,
                                ),
                              _PersonRow(
                                payer: payersById[split.totals[i].payerId]!,
                                colorIndex:
                                    payerIndex[split.totals[i].payerId]!,
                                payerTotal: split.totals[i],
                                fmt: fmt,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Reveal(
                      delay: const Duration(milliseconds: 120),
                      child: Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Settle up',
                                    style: AppFonts.flex(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (split.transfers.isEmpty)
                              const _SettledTile()
                            else
                              for (
                                int i = 0;
                                i < split.transfers.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  Divider(
                                    color: scheme.outlineVariant,
                                    height: 1,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                _TransferRow(
                                  from:
                                      payersById[split
                                          .transfers[i]
                                          .fromPayerId]!,
                                  to: payersById[split.transfers[i].toPayerId]!,
                                  fromIdx:
                                      payerIndex[split
                                          .transfers[i]
                                          .fromPayerId]!,
                                  toIdx:
                                      payerIndex[split.transfers[i].toPayerId]!,
                                  amount: split.transfers[i].amount,
                                  fmt: fmt,
                                ),
                              ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(
                                  text: _summaryText(
                                    split: split,
                                    payersById: payersById,
                                    fmt: fmt,
                                    state: state,
                                  ),
                                ),
                              );
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Summary copied')),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Copy summary'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit assignments'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _summaryText({
    required dynamic split,
    required Map<String, dynamic> payersById,
    required NumberFormat fmt,
    required BillState state,
  }) {
    final receipt = state.receipt!;
    final totals = calculateReceiptTotals(receipt);
    const sep = '--------------------------';
    final lines = <String>['Bill Summary', sep];

    for (final total in split.totals) {
      final name = payersById[total.payerId]!.name;
      lines.add('$name: ${fmt.format(total.total)}');

      for (final item in receipt.items) {
        final myQty = state.qty(total.payerId, item.id);
        if (myQty == 0) continue;
        final totalClaimed = state.payers.fold<int>(
          0,
          (s, p) => s + state.qty(p.id, item.id),
        );
        final sharePrice = totalClaimed > 0
            ? (myQty / totalClaimed) * item.lineTotal
            : 0.0;
        lines.add('- ${item.name}: ${fmt.format(sharePrice)}');
      }

      for (final charge in total.chargeBreakdown) {
        lines.add('- ${charge.displayLabel}: ${fmt.format(charge.amount)}');
      }

      lines.add('');
    }

    lines.add('Sub Total: ${fmt.format(totals.discountedSubtotal)}');
    lines.add('Grand Total: ${fmt.format(split.grandTotal)}');
    lines.add(sep);
    lines.add('');
    lines.add('Simplified Debt');

    if (split.transfers.isEmpty) {
      lines.add('All settled.');
    } else {
      for (final transfer in split.transfers) {
        final from = payersById[transfer.fromPayerId]!.name;
        final to = payersById[transfer.toPayerId]!.name;
        lines.add('- $from pays $to: ${fmt.format(transfer.amount)}');
      }
    }

    lines.add('');
    return '```\n${lines.join('\n')}\n```';
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.payer,
    required this.colorIndex,
    required this.payerTotal,
    required this.fmt,
  });

  final dynamic payer;
  final int colorIndex;
  final PayerTotal payerTotal;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.read<BillState>();
    final receipt = state.receipt!;

    final claimedItems = [
      for (final item in receipt.items)
        if (state.qty(payer.id, item.id) > 0)
          (
            item: item,
            sharePrice: () {
              final myQty = state.qty(payer.id, item.id);
              final totalClaimed = state.payers.fold<int>(
                0,
                (s, p) => s + state.qty(p.id, item.id),
              );
              return totalClaimed > 0
                  ? (myQty / totalClaimed) * item.lineTotal
                  : 0.0;
            }(),
          ),
    ];

    final paidAmt = state.paidBy(payer.id);
    final muted = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PayerAvatar(
                payer: payer,
                colorIndex: colorIndex,
                size: 42,
                qty: 1,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  payer.name,
                  style: AppFonts.flex(
                    size: 15,
                    weight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                fmt.format(payerTotal.total),
                style: AppFonts.mono(
                  size: 16,
                  weight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          if (claimedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final entry in claimedItems)
              Padding(
                padding: const EdgeInsets.only(left: 56, bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.item.name,
                        style: AppFonts.flex(size: 13, color: muted),
                      ),
                    ),
                    Text(
                      fmt.format(entry.sharePrice),
                      style: AppFonts.mono(size: 13, color: muted),
                    ),
                  ],
                ),
              ),
          ],
          if (payerTotal.chargeBreakdown.isNotEmpty) ...[
            const SizedBox(height: 2),
            for (final charge in payerTotal.chargeBreakdown)
              Padding(
                padding: const EdgeInsets.only(left: 56, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        charge.displayLabel,
                        style: AppFonts.flex(size: 12, color: muted),
                      ),
                    ),
                    Text(
                      fmt.format(charge.amount),
                      style: AppFonts.mono(size: 12, color: muted),
                    ),
                  ],
                ),
              ),
          ],
          if (paidAmt > 0) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Paid at till',
                      style: AppFonts.flex(
                        size: 12,
                        weight: FontWeight.w500,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    fmt.format(paidAmt),
                    style: AppFonts.mono(
                      size: 12,
                      weight: FontWeight.w500,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.from,
    required this.to,
    required this.fromIdx,
    required this.toIdx,
    required this.amount,
    required this.fmt,
  });

  final dynamic from;
  final dynamic to;
  final int fromIdx;
  final int toIdx;
  final double amount;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          PayerAvatar(payer: from, colorIndex: fromIdx, size: 32, qty: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.arrow_forward,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          PayerAvatar(payer: to, colorIndex: toIdx, size: 32, qty: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${from.name} pays ${to.name}',
                  style: AppFonts.flex(
                    size: 14,
                    weight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'one transfer',
                  style: AppFonts.flex(
                    size: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            fmt.format(amount),
            style: AppFonts.mono(
              size: 16,
              weight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettledTile extends StatelessWidget {
  const _SettledTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Square. Nobody owes anyone.',
              style: AppFonts.flex(
                size: 14,
                weight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
