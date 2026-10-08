import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

enum ShareFormat { story, post, wide }

extension on ShareFormat {
  /// Logical size of the card; exported at [exportWidth] pixels wide.
  Size get logical => switch (this) {
        ShareFormat.story => const Size(360, 640),
        ShareFormat.post => const Size(360, 450),
        ShareFormat.wide => const Size(400, 225),
      };
  double get exportWidth => this == ShareFormat.wide ? 1600 : 1080;
}

/// Bottom sheet that renders the text as a designed image and shares it as a PNG file.
class ShareImageSheet extends ConsumerStatefulWidget {
  final String label;
  final String text;
  final String source;

  const ShareImageSheet({super.key, required this.label, required this.text, required this.source});

  static Future<void> show(BuildContext context, {required String label, required String text, required String source}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1A5C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => ShareImageSheet(label: label, text: text, source: source),
    );
  }

  @override
  ConsumerState<ShareImageSheet> createState() => _ShareImageSheetState();
}

class _ShareImageSheetState extends ConsumerState<ShareImageSheet> {
  final _key = GlobalKey();
  ShareFormat _format = ShareFormat.story;
  bool _busy = false;

  Future<void> _share() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ratio = _format.exportWidth / _format.logical.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('no bytes');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/alqaree_${_format.name}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: s.appName));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final size = _format.logical;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 14),
            Text(s.shareImage, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Container(
              height: 330,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x40000000), borderRadius: BorderRadius.circular(20)),
              child: FittedBox(
                child: RepaintBoundary(
                  key: _key,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: _ShareCard(format: _format, label: widget.label, text: widget.text, source: widget.source, appName: s.appName),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Segmented(
              labels: [s.story, s.post, s.wide],
              selected: _format.index,
              onChanged: (i) => setState(() => _format = ShareFormat.values[i]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share_rounded),
                label: Text(s.share, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final ShareFormat format;
  final String label;
  final String text;
  final String source;
  final String appName;

  const _ShareCard({required this.format, required this.label, required this.text, required this.source, required this.appName});

  @override
  Widget build(BuildContext context) {
    final wide = format == ShareFormat.wide;
    final base = switch (format) {
      ShareFormat.story => 27.0,
      ShareFormat.post => 24.0,
      ShareFormat.wide => 19.0,
    };
    // Long texts shrink so the whole text always fits on the image.
    final len = text.length;
    final fontSize = len <= 90 ? base : len <= 180 ? base * 0.8 : len <= 320 ? base * 0.62 : base * 0.5;

    final textWidget = Text(
      text,
      textAlign: wide ? TextAlign.start : TextAlign.center,
      style: AppTheme.scripture(size: fontSize, height: 1.9),
    );
    final labelChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent, decoration: TextDecoration.none)),
    );
    final brand = Text(appName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, decoration: TextDecoration.none));
    final sourceText = Text(source, style: const TextStyle(fontSize: 13, color: AppColors.soft, decoration: TextDecoration.none));

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.all(wide ? 14 : 20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(wide ? 18 : 24),
        ),
        padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 24, vertical: wide ? 16 : 28),
        child: Material(
          type: MaterialType.transparency,
          child: wide
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [labelChip, const SizedBox(height: 8), Flexible(child: textWidget), const SizedBox(height: 6), sourceText],
                      ),
                    ),
                    Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: AppColors.glassBorder),
                    brand,
                  ],
                )
              : Column(
                  children: [
                    labelChip,
                    const Spacer(),
                    Flexible(flex: 8, child: Center(child: textWidget)),
                    const SizedBox(height: 14),
                    Container(width: 48, height: 2, color: AppColors.accent),
                    const SizedBox(height: 10),
                    sourceText,
                    const Spacer(),
                    brand,
                  ],
                ),
        ),
      ),
    );
  }
}
