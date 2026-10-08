import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'share_sheet.dart';

String wamdaTypeLabel(S s, WamdaType t) => switch (t) {
      WamdaType.hadith => s.typeHadith,
      WamdaType.dua => s.typeDua,
      WamdaType.ayah => s.typeAyah,
    };

/// Full view of today's ومضة with copy, share (text or image) and favorite.
class WamdaScreen extends ConsumerStatefulWidget {
  final Wamda wamda;
  const WamdaScreen({super.key, required this.wamda});

  static Route<void> route(Wamda w) => MaterialPageRoute(builder: (_) => WamdaScreen(wamda: w));

  @override
  ConsumerState<WamdaScreen> createState() => _WamdaScreenState();
}

class _WamdaScreenState extends ConsumerState<WamdaScreen> {
  double _size = 26;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final scale = ref.watch(settingsProvider).textScale;
    final w = widget.wamda;
    final isFav = ref.watch(isFavoriteProvider(w.key));
    final fullText = '${w.text}\n${w.source}\n— ${s.appName}';
    final typeLabel = wamdaTypeLabel(s, w.type);

    void toggleFav() => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
          key: w.key,
          type: w.favoriteType,
          title: w.text,
          subtitle: w.source,
          payload: w.toJson(),
        ));

    Widget action(IconData icon, String label, VoidCallback onTap, {bool primary = false}) => Material(
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

    return Scaffold(
      appBar: AppBar(title: Text(s.wamdat, style: const TextStyle(fontWeight: FontWeight.w800))),
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
                  child: Text(typeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ),
                const SizedBox(height: 18),
                SelectableText(w.text, textAlign: TextAlign.center, style: AppTheme.scripture(size: _size * scale, height: 2)),
                const SizedBox(height: 16),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 6),
                Text(w.source, style: const TextStyle(fontSize: 14, color: AppColors.soft)),
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
              action(Icons.text_increase_rounded, s.fontUp, () => setState(() => _size = (_size + 2).clamp(18, 40).toDouble())),
              action(Icons.text_decrease_rounded, s.fontDown, () => setState(() => _size = (_size - 2).clamp(18, 40).toDouble())),
              action(Icons.copy_rounded, s.copy, () async {
                await Clipboard.setData(ClipboardData(text: fullText));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied)));
              }),
              action(Icons.share_rounded, s.shareText, () => SharePlus.instance.share(ShareParams(text: fullText))),
              action(Icons.image_rounded, s.shareImage,
                  () => ShareImageSheet.show(context, label: s.wamdat, text: w.text, source: w.source),
                  primary: true),
              action(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, s.favorites, toggleFav),
            ],
          ),
        ],
      ),
    );
  }
}
