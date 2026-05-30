import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Compact framed receipt image used inline on the review screen.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage({super.key, required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: scheme.surfaceContainerHigh,
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.memory(bytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
