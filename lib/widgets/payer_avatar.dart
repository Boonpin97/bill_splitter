import 'package:flutter/material.dart';

import '../models/payer.dart';
import '../theme/app_theme.dart';

/// Material You–style palette for avatar tints.
/// Each pair is (containerBackground, onContainerForeground) so the initial
/// is always legible.
class PayerPalette {
  static const List<(Color, Color)> swatches = [
    (Color(0xFFB7E4D8), Color(0xFF003E33)), // teal
    (Color(0xFFFFDAD0), Color(0xFF3A0B00)), // peach
    (Color(0xFFCCE3FA), Color(0xFF002B5C)), // blue
    (Color(0xFFFFE08A), Color(0xFF3D2E00)), // amber
    (Color(0xFFE3CFFB), Color(0xFF270F4B)), // lilac
    (Color(0xFFD2EBC1), Color(0xFF14391A)), // green
  ];

  static (Color, Color) colorsFor(int i) => swatches[i % swatches.length];
}

/// Circular avatar showing the payer's initial. Used both as a people chip
/// and as a per-item assignment cell. The `selected` state fills with a
/// primary tint to show the person is claiming an item.
class PayerAvatar extends StatelessWidget {
  const PayerAvatar({
    super.key,
    required this.payer,
    required this.colorIndex,
    this.size = 40,
    this.qty = 0,
    this.outlined = false,
  });

  final Payer payer;
  final int colorIndex;
  final double size;
  final int qty;
  final bool outlined;

  String get _initial =>
      payer.name.isEmpty ? '·' : payer.name.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = PayerPalette.colorsFor(colorIndex);
    final selected = qty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? bg
            : (outlined ? Colors.transparent : scheme.surfaceContainerHigh),
        border: selected
            ? null
            : Border.all(
                color: outlined ? scheme.outlineVariant : Colors.transparent,
                width: 1.2,
              ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Text(
            _initial,
            style: AppFonts.flex(
              size: size * 0.42,
              weight: FontWeight.w600,
              color: selected ? fg : scheme.onSurfaceVariant,
              letterSpacing: 0,
              height: 1.0,
            ),
          ),
          if (qty > 1)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: Text(
                  '$qty',
                  style: AppFonts.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
