import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'share_sheet.dart';

class HadithScreen extends ConsumerStatefulWidget {
  final Hadith hadith;
  const HadithScreen({super.key, required this.hadith});

  static Route<void> route(Hadith h) => MaterialPageRoute(builder: (_) => HadithScreen(hadith: h));

  @override
  ConsumerState<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends ConsumerState<HadithScreen> {
  double _size = 22;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final scale = ref.watch(settingsProvider).textScale;
    final h = widget.hadith;
    final isFav = ref.watch(isFavoriteProvider(h.key));
    final fullText = '${h.text}\n\n${h.narratedBy} (${h.number})\n— ${s.appName}';

    void toggleFav() => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
          key: h.key,
          type: FavoriteType.hadith,
          title: h.text,
          subtitle: h.narratedBy,
          payload: h.toJson(),
        ));

    return Scaffold(
      appBar: AppBar(title: Text(s.hadithOfDay, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(999)),
                  child: const Text('صحيح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ),
                const SizedBox(height: 16),
                SelectableText(h.text, style: AppTheme.scripture(size: _size * scale, height: 2)),
                const SizedBox(height: 16),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 8),
                Text(h.bookName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${s.hadiths} ${h.number}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _Action(icon: Icons.text_increase_rounded, label: s.fontUp, onTap: () => setState(() => _size = (_size + 2).clamp(16, 34).toDouble())),
              _Action(icon: Icons.text_decrease_rounded, label: s.fontDown, onTap: () => setState(() => _size = (_size - 2).clamp(16, 34).toDouble())),
              _Action(
                icon: Icons.copy_rounded,
                label: s.copy,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: fullText));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied)));
                },
              ),
              _Action(icon: Icons.share_rounded, label: s.shareText, onTap: () => SharePlus.instance.share(ShareParams(text: fullText))),
              _Action(
                icon: Icons.image_rounded,
                label: s.shareImage,
                primary: true,
                onTap: () => ShareImageSheet.show(context, label: s.hadithOfDay, text: h.text, source: h.narratedBy),
              ),
              _Action(
                icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: s.favorites,
                onTap: toggleFav,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _Action({required this.icon, required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.accent : AppColors.glassSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: primary ? BorderSide.none : const BorderSide(color: AppColors.glassBorderSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: primary ? AppColors.background : Colors.white),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: primary ? FontWeight.w700 : FontWeight.w400, color: primary ? AppColors.background : Colors.white)),
          ],
        ),
      ),
    );
  }
}
