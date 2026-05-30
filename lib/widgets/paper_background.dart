import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard page shell — caps content at [kMaxContentWidth] for tablet/desktop
/// while letting mobile portrait use full width.
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.child,
    this.padHorizontal = 20,
    this.padTop = 8,
    this.padBottom = 24,
  });

  final Widget child;
  final double padHorizontal;
  final double padTop;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                padHorizontal, padTop, padHorizontal, padBottom),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Compact section caption — small uppercase title used above grouped content.
class SectionCaption extends StatelessWidget {
  const SectionCaption(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: AppFonts.label(color: color ?? scheme.onSurfaceVariant),
    );
  }
}

/// One-shot fade + slide-up reveal for page entries.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: widget.child,
        ),
      ),
    );
  }
}
