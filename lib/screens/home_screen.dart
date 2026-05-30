import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/receipt_api.dart';
import '../state/bill_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_background.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Uint8List? _bytes;
  String _mimeType = 'image/jpeg';
  bool _analyzing = false;
  ReceiptAnalysisStage _analysisStage = ReceiptAnalysisStage.warmingServer;
  String? _error;
  late final AnimationController _scanController;
  late final AnimationController _buttonMotionController;

  static const Map<ReceiptAnalysisStage, String> _analysisStageLabels = {
    ReceiptAnalysisStage.warmingServer: 'Shaking up the server...',
    ReceiptAnalysisStage.sendingImage: 'Humbly offering the image...',
    ReceiptAnalysisStage.waitingForGoogle: 'Waiting for me answers...',
  };

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _buttonMotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    // Fire-and-forget warmup so the Cloud Run instance is hot by the time
    // the user has picked a photo and tapped Analyze.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceiptAnalyzer>().warm();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 92);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _bytes = bytes;
      _mimeType = file.mimeType ?? 'image/jpeg';
      _error = null;
    });
  }

  Future<void> _analyze() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() {
      _analyzing = true;
      _analysisStage = ReceiptAnalysisStage.warmingServer;
      _error = null;
    });
    _scanController.repeat();
    _buttonMotionController.repeat(reverse: true);
    try {
      final analyzer = context.read<ReceiptAnalyzer>();
      final receipt = await analyzer.analyze(
        bytes,
        mimeType: _mimeType,
        onStage: (stage) {
          if (!mounted) return;
          setState(() => _analysisStage = stage);
        },
      );
      if (!mounted) return;
      context.read<BillState>().setReceipt(receipt);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(imageBytes: bytes, mimeType: _mimeType),
        ),
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      _scanController.stop();
      _scanController.reset();
      _buttonMotionController.stop();
      _buttonMotionController.reset();
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _clearImage() => setState(() => _bytes = null);

  @override
  void dispose() {
    _scanController.dispose();
    _buttonMotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = _bytes != null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.receipt_long,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'BillSplitt',
              style: AppFonts.flex(
                size: 16,
                weight: FontWeight.w600,
                color: scheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'About',
            onPressed: _showAbout,
            icon: const Icon(Icons.help_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageShell(
        padTop: 8,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Split a bill',
                        style: AppFonts.serif(
                          size: 36,
                          weight: FontWeight.w400,
                          color: scheme.onSurface,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ' Snap it | Settle up',
                        style: AppFonts.flex(
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Reveal(
                delay: const Duration(milliseconds: 60),
                child: _ReceiptCard(
                  bytes: _bytes,
                  analyzing: _analyzing,
                  scanAnimation: _scanController,
                  onPickGallery: () => _pickImage(ImageSource.gallery),
                  onPickCamera: () => _pickImage(ImageSource.camera),
                  onClear: _clearImage,
                ),
              ),
              const SizedBox(height: 16),
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: SizedBox(
                  height: 56,
                  child: _AnalyzeButton(
                    analyzing: _analyzing,
                    motionAnimation: _buttonMotionController,
                    onPressed: hasImage && !_analyzing ? _analyze : null,
                    label: _analyzing
                        ? _analysisStageLabels[_analysisStage]!
                        : 'Analyze',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorCard(error: _error!),
              ],
              const SizedBox(height: 28),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Receipts aren’t saved.',
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
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Split',
      applicationVersion: 'beta',
      applicationLegalese:
          'A small app for splitting receipts between friends. Photos are sent only to the parsing function and not stored.',
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.bytes,
    required this.analyzing,
    required this.scanAnimation,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  final Uint8List? bytes;
  final bool analyzing;
  final Animation<double> scanAnimation;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (bytes != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(bytes!, fit: BoxFit.contain),
                      if (analyzing)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: scanAnimation,
                              builder: (context, child) {
                                final raw = scanAnimation.value;
                                final y = raw < 0.5
                                    ? 1 -
                                          (Curves.easeOutCubic.transform(
                                                raw * 2,
                                              ) *
                                              2)
                                    : -1 +
                                          (Curves.easeOutCubic.transform(
                                                (raw - 0.5) * 2,
                                              ) *
                                              2);
                                return Align(
                                  alignment: Alignment(0, y),
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          scheme.primary.withValues(alpha: 0.8),
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 18,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onPickGallery,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Replace'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: onPickGallery,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 28,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add a receipt',
                style: AppFonts.serif(
                  size: 22,
                  color: scheme.onSurface,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JPG or PNG. Photo from a camera works best.',
                textAlign: TextAlign.center,
                style: AppFonts.flex(size: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickGallery,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Upload'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPickCamera,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({
    required this.analyzing,
    required this.motionAnimation,
    required this.onPressed,
    required this.label,
  });

  final bool analyzing;
  final Animation<double> motionAnimation;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: analyzing
            ? AnimatedBuilder(
                animation: motionAnimation,
                builder: (context, child) {
                  final bounce = Curves.easeOutBack.transform(
                    motionAnimation.value,
                  );
                  return Transform.translate(
                    offset: Offset(0, -7 * bounce),
                    child: Transform.rotate(
                      angle: -0.38 + (bounce * 0.76),
                      child: Transform.scale(
                        scale: 0.9 + (bounce * 0.28),
                        child: child,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.receipt_long, size: 18),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: scheme.onErrorContainer,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Something didn’t work',
                style: AppFonts.flex(
                  size: 13,
                  weight: FontWeight.w600,
                  color: scheme.onErrorContainer,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy error',
                icon: Icon(
                  Icons.copy_outlined,
                  size: 16,
                  color: scheme.onErrorContainer,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: error));
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Error copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            error,
            style: AppFonts.mono(
              size: 12,
              color: scheme.onErrorContainer,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
