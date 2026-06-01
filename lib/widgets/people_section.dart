import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/payer.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';
import 'paper_background.dart';
import 'payer_avatar.dart';

/// Horizontal row of payer chips. Tap a chip to manage (rename / remove) via a
/// bottom sheet. "+ Add" appends a new payer.
class PeopleSection extends StatelessWidget {
  const PeopleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BillState>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionCaption('People'),
            const Spacer(),
            Text(
              '${state.payers.length}',
              style: AppFonts.label(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: state.payers.length + 1,
            separatorBuilder: (ctx, i) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (i == state.payers.length) {
                return _AddPersonChip(onTap: () => _addPerson(context, state));
              }
              return _PersonChip(
                payer: state.payers[i],
                index: i,
                onTap: () =>
                    _showManageSheet(context, state, state.payers[i], i),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showManageSheet(
    BuildContext context,
    BillState state,
    Payer payer,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _ManageSheet(
            payer: payer,
            index: index,
            canRemove: state.payers.length > 1,
            onRename: (name) => state.renamePayer(payer.id, name),
            onRemove: () {
              state.removePayer(payer.id);
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
    );
  }

  Future<void> _addPerson(BuildContext context, BillState state) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    state.addPayer(name: name);
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.payer,
    required this.index,
    required this.onTap,
  });

  final Payer payer;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PayerAvatar(payer: payer, colorIndex: index, size: 46, qty: 1),
            const SizedBox(height: 6),
            Text(
              payer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppFonts.flex(
                size: 12,
                weight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPersonChip extends StatelessWidget {
  const _AddPersonChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 22, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Add',
              style: AppFonts.flex(
                size: 12,
                weight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageSheet extends StatefulWidget {
  const _ManageSheet({
    required this.payer,
    required this.index,
    required this.canRemove,
    required this.onRename,
    required this.onRemove,
  });

  final Payer payer;
  final int index;
  final bool canRemove;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;

  @override
  State<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends State<_ManageSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.payer.name,
  );
  late final FocusNode _focusNode = FocusNode();
  bool _didAutoSelect = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PayerAvatar(
                payer: widget.payer,
                colorIndex: widget.index,
                size: 48,
                qty: 1,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.payer.name,
                      style: AppFonts.serif(
                        size: 22,
                        color: scheme.onSurface,
                        weight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Edit details',
                      style: AppFonts.flex(
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: _submit,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.canRemove)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                  ),
                ),
              if (widget.canRemove) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _submit(_controller.text),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit(String v) {
    final name = v.trim();
    if (name.isNotEmpty) widget.onRename(name);
    Navigator.of(context).maybePop();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus || _didAutoSelect) return;
    _didAutoSelect = true;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }
}
