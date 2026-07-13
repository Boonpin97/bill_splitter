import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../services/receipt_api.dart';
import '../services/receipt_totals.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charges_panel.dart';
import '../widgets/item_card.dart';
import '../widgets/paper_background.dart';
import '../widgets/people_section.dart';
import '../widgets/receipt_image.dart';
import 'summary_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.imageBytes,
    required this.mimeType,
  });

  final Uint8List? imageBytes;
  final String mimeType;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _showImage = false;
  bool _reanalyzingWithOcr = false;
  ReceiptAnalysisStage _ocrStage = ReceiptAnalysisStage.warmingServer;

  static const Map<ReceiptAnalysisStage, String> _ocrStageLabels = {
    ReceiptAnalysisStage.warmingServer: 'Shaking up the server...',
    ReceiptAnalysisStage.sendingImage: 'Humbly offering the image...',
    ReceiptAnalysisStage.waitingForGoogle:
        "Didn't work the first time, let me try again",
  };

  Future<void> _reanalyzeWithOcr() async {
    final imageBytes = widget.imageBytes;
    if (imageBytes == null) return;

    setState(() {
      _reanalyzingWithOcr = true;
      _ocrStage = ReceiptAnalysisStage.warmingServer;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final analyzer = context.read<ReceiptAnalyzer>();
      final receipt = await analyzer.analyze(
        imageBytes,
        mimeType: widget.mimeType,
        useOcr: true,
        onStage: (stage) {
          if (!mounted) return;
          setState(() => _ocrStage = stage);
        },
      );
      if (!mounted) return;
      context.read<BillState>().setReceipt(receipt);
      messenger.showSnackBar(
        const SnackBar(content: Text('Reanalyzed with OCR')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(formatReceiptAnalysisError(e))),
      );
    } finally {
      if (mounted) setState(() => _reanalyzingWithOcr = false);
    }
  }

  Future<void> _settleUp(BillState state) async {
    final mismatches = state.quantityMismatchItems;
    if (mismatches.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _QuantityMismatchDialog(state: state, items: mismatches),
      );
      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SummaryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final receipt = state.receipt;
    final scheme = Theme.of(context).colorScheme;
    if (receipt == null) {
      return const Scaffold(body: Center(child: Text('No receipt')));
    }
    final fmt = NumberFormat.simpleCurrency(
      name: receipt.currency,
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (widget.imageBytes != null)
            IconButton(
              tooltip: _showImage ? 'Hide receipt' : 'Show receipt',
              onPressed: () => setState(() => _showImage = !_showImage),
              icon: Icon(_showImage ? Icons.image : Icons.image_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageShell(
        padBottom: 112,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                child: _SummaryHero(receipt: receipt, fmt: fmt),
              ),
              if (widget.imageBytes != null)
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: _showImage
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: ReceiptImage(bytes: widget.imageBytes),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              const SizedBox(height: 24),
              const Reveal(
                delay: Duration(milliseconds: 60),
                child: ChargesPanel(),
              ),
              const SizedBox(height: 24),
              const Reveal(
                delay: Duration(milliseconds: 100),
                child: PeopleSection(),
              ),
              const SizedBox(height: 24),
              Reveal(
                delay: const Duration(milliseconds: 140),
                child: _ItemsCard(receipt: receipt, fmt: fmt),
              ),
              const SizedBox(height: 12),
              const Reveal(
                delay: Duration(milliseconds: 200),
                child: _PaidPanel(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _ReviewActions(
        reanalyzing: _reanalyzingWithOcr,
        reanalyzeLabel: _ocrStageLabels[_ocrStage]!,
        onReanalyze: widget.imageBytes == null ? null : _reanalyzeWithOcr,
        onSettleUp: () => _settleUp(state),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _QuantityMismatchDialog extends StatelessWidget {
  const _QuantityMismatchDialog({required this.state, required this.items});

  final BillState state;
  final List<LineItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const warning = Color(0xFFB45309);
    const warningSurface = Color(0xFFFFF4E5);

    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: warning, size: 32),
      title: const Text("Quantities don't tally"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Some assigned shares do not match the receipt quantities. '
                'You can review them or continue anyway.',
                style: AppFonts.flex(size: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final item in items) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: warningSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: warning.withValues(alpha: 0.24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.flex(
                            size: 12,
                            weight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${state.assignedFor(item.id)} / ${item.quantity}',
                        style: AppFonts.mono(
                          size: 12,
                          weight: FontWeight.w700,
                          color: warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Review quantities'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue anyway'),
        ),
      ],
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.reanalyzing,
    required this.reanalyzeLabel,
    required this.onReanalyze,
    required this.onSettleUp,
  });

  final bool reanalyzing;
  final String reanalyzeLabel;
  final VoidCallback? onReanalyze;
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (onReanalyze != null) ...[
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: 'reanalyze',
                onPressed: reanalyzing ? null : onReanalyze,
                icon: reanalyzing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(reanalyzing ? reanalyzeLabel : 'Reanalyze'),
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FloatingActionButton.extended(
              heroTag: 'settleUp',
              onPressed: onSettleUp,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Settle up'),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.receipt, required this.fmt});

  final Receipt receipt;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final totals = calculateReceiptTotals(receipt);

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total',
              style: AppFonts.label(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              fmt.format(totals.total),
              style: AppFonts.serif(
                size: 44,
                weight: FontWeight.w400,
                color: scheme.onPrimaryContainer,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${receipt.items.length} items',
              style: AppFonts.flex(
                size: 12,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'Subtotal',
                    value: fmt.format(totals.discountedSubtotal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroMetric(
                    label: 'Tax and service',
                    value: fmt.format(totals.chargesTotal),
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.label(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppFonts.mono(
              size: 15,
              weight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );

    return content;
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.receipt, required this.fmt});

  final Receipt receipt;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = calculateReceiptTotals(receipt);
    final itemSubtotal = receipt.items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.list_alt_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Items',
                  style: AppFonts.flex(
                    size: 14,
                    weight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${receipt.items.length}',
                  style: AppFonts.flex(
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap on who shared the dish',
              style: AppFonts.flex(size: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < receipt.items.length; i++) ...[
              Divider(color: scheme.outlineVariant, height: 1),
              ItemRow(item: receipt.items[i], fmt: fmt),
            ],
            Divider(color: scheme.outlineVariant, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
              child: Column(
                children: [
                  _ItemsTotalRow(
                    label: 'Items total',
                    value: fmt.format(itemSubtotal),
                  ),
                  if (totals.discountTotal > 0) ...[
                    const SizedBox(height: 6),
                    _ItemsTotalRow(
                      label: 'Discount',
                      value: '-${fmt.format(totals.discountTotal)}',
                    ),
                  ],
                  const SizedBox(height: 6),
                  _ItemsTotalRow(
                    label: 'Subtotal',
                    value: fmt.format(totals.discountedSubtotal),
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsTotalRow extends StatelessWidget {
  const _ItemsTotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weight = emphasized ? FontWeight.w700 : FontWeight.w500;
    final color = emphasized ? scheme.onSurface : scheme.onSurfaceVariant;

    return Row(
      children: [
        Text(
          label,
          style: AppFonts.flex(size: 13, weight: weight, color: color),
        ),
        const Spacer(),
        Text(
          value,
          style: AppFonts.mono(size: 13, weight: weight, color: color),
        ),
      ],
    );
  }
}

class _PaidPanel extends StatefulWidget {
  const _PaidPanel();

  @override
  State<_PaidPanel> createState() => _PaidPanelState();
}

class _PaidPanelState extends State<_PaidPanel> {
  bool _split = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_card_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Paid by',
                  style: AppFonts.flex(
                    size: 14,
                    weight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _split = !_split),
                  child: Text(_split ? 'Single' : 'Custom Amount'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_split)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in state.payers)
                    ChoiceChip(
                      label: Text(p.name),
                      selected:
                          state.paidBy(p.id) == state.derivedTotal &&
                          state.paidBy(p.id) > 0,
                      onSelected: (_) => state.setSolePayer(p.id),
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final p in state.payers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              p.name,
                              style: AppFonts.flex(
                                size: 14,
                                weight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              initialValue: state
                                  .paidBy(p.id)
                                  .toStringAsFixed(2),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              style: AppFonts.mono(
                                size: 14,
                                weight: FontWeight.w500,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^-?\d*\.?\d{0,2}'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixText: '\$ ',
                              ),
                              onChanged: (v) =>
                                  state.setPaid(p.id, double.tryParse(v) ?? 0),
                            ),
                          ),
                        ],
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
