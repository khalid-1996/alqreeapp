import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'hadith_screen.dart';
import 'player_screen.dart';
import 'reciters_screen.dart';
import 'share_sheet.dart';
import 'wamda_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const FavoritesScreen());

  IconData _icon(FavoriteType t) => switch (t) {
        FavoriteType.reciter => Icons.person_rounded,
        FavoriteType.surah => Icons.menu_book_rounded,
        FavoriteType.radio => Icons.radio_rounded,
        FavoriteType.hadith => Icons.format_quote_rounded,
        FavoriteType.dua => Icons.volunteer_activism_rounded,
        FavoriteType.ayah => Icons.auto_stories_rounded,
      };

  Future<void> _open(BuildContext context, WidgetRef ref, FavoriteItem f) async {
    final s = ref.read(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    switch (f.type) {
      case FavoriteType.reciter:
        Navigator.of(context).push(ReciterScreen.route(Reciter.fromJson(f.payload)));
      case FavoriteType.surah:
        final r = Reciter.fromJson(Map<String, dynamic>.from(f.payload['reciter'] as Map));
        final moshafId = f.payload['moshafId'];
        final m = r.moshaf.firstWhere((x) => x.id == moshafId, orElse: () => r.moshaf.first);
        final names = ref.read(suwarProvider).valueOrNull ?? {f.payload['surah'] as int: f.title};
        await handler.playSurah(reciter: r, moshaf: m, surah: f.payload['surah'] as int, names: names);
        if (context.mounted) Navigator.of(context).push(PlayerScreen.route());
      case FavoriteType.radio:
        await handler.playRadio(RadioStation.fromJson(f.payload));
        if (context.mounted) Navigator.of(context).push(PlayerScreen.route());
      case FavoriteType.hadith || FavoriteType.dua || FavoriteType.ayah:
        if (f.payload.containsKey('collection')) {
          // A hadith saved from "حديث اليوم" (Sahih al-Bukhari / Muslim).
          Navigator.of(context).push(HadithScreen.route(Hadith.fromJson(f.payload)));
        } else if (f.payload.containsKey('type')) {
          Navigator.of(context).push(WamdaScreen.route(Wamda.fromJson(f.payload)));
        } else {
          ShareImageSheet.show(context, label: s.wamdat, text: f.title, source: f.subtitle);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final favs = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.favorites, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: favs.isEmpty
          ? Center(child: Text(s.noFavorites, style: const TextStyle(color: AppColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: favs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final f = favs[i];
                final scripture = f.type == FavoriteType.hadith || f.type == FavoriteType.dua || f.type == FavoriteType.ayah;
                return Dismissible(
                  key: ValueKey(f.key),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: const Color(0x33FF5A5A), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.liveText),
                  ),
                  onDismissed: (_) => ref.read(favoritesProvider.notifier).remove(f.key),
                  child: GlassCard(
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    onTap: () => _open(context, ref, f),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(14)),
                          child: Icon(_icon(f.type), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                maxLines: scripture ? 2 : 1,
                                overflow: TextOverflow.fade,
                                style: scripture
                                    ? AppTheme.scripture(size: 16, height: 1.6)
                                    : const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              Text(f.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
