import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../shell.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';
import 'hadith_screen.dart';
import 'player_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        ref.invalidate(hadithOfDayProvider);
        ref.invalidate(radiosProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _Header(),
          const SizedBox(height: 18),
          const _DailyCard(),
          const SizedBox(height: 16),
          const _ContinueListening(),
          _Tiles(),
          const SizedBox(height: 18),
          SectionHeader(
            title: s.radios,
            action: s.seeAll,
            onAction: () => ref.read(tabProvider.notifier).state = 2,
          ),
          const SizedBox(height: 6),
          const _RadiosStrip(),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    HijriCalendar.setLocal(s.en ? 'en' : 'ar');
    final h = HijriCalendar.now();
    final hijri = '${h.hDay} ${h.longMonthName} ${h.hYear}${s.en ? ' AH' : ' هـ'}';
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.greeting, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              Text(s.appName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(hijri, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('${now.day}/${now.month}/${now.year}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

/// One card that switches between the hadith and the dua of the day.
class _DailyCard extends ConsumerStatefulWidget {
  const _DailyCard();

  @override
  ConsumerState<_DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends ConsumerState<_DailyCard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final scale = ref.watch(settingsProvider).textScale;
    final hadith = ref.watch(hadithOfDayProvider);
    final dua = ref.watch(duaOfDayProvider);

    String label;
    String? text;
    String source;
    FavoriteItem? fav;
    VoidCallback? openMore;

    if (_page == 0) {
      label = s.hadithOfDay;
      final h = hadith.valueOrNull;
      text = h?.text;
      source = h?.narratedBy ?? '';
      if (h != null) {
        fav = FavoriteItem(key: h.key, type: FavoriteType.hadith, title: h.text, subtitle: h.narratedBy, payload: h.toJson());
        openMore = () => Navigator.of(context).push(HadithScreen.route(h));
      }
    } else {
      label = s.duaOfDay;
      text = dua.text;
      source = dua.source;
      fav = FavoriteItem(key: dua.key, type: FavoriteType.dua, title: dua.text, subtitle: dua.source);
      openMore = () => ref.read(tabProvider.notifier).state = 3;
    }

    final saved = fav != null && ref.watch(isFavoriteProvider(fav.key));

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0).abs() > 150) setState(() => _page = 1 - _page);
      },
      child: GlassCard(
        strong: true,
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent))),
                if (fav != null)
                  HeartButton(
                    active: saved,
                    label: s.favorites,
                    onTap: () => ref.read(favoritesProvider.notifier).toggle(fav!),
                  ),
              ],
            ),
            if (_page == 0 && hadith.isLoading && text == null)
              const SizedBox(height: 90, child: Loading())
            else if (_page == 0 && hadith.hasError && text == null)
              ErrorRetry(message: s.loadFailed, retryLabel: s.retry, onRetry: () => ref.invalidate(hadithOfDayProvider))
            else
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Text(
                  text ?? '',
                  // Long text shrinks instead of being cut off.
                  style: AppTheme.scripture(size: autoScriptureSize(text ?? '') * scale),
                ),
              ),
            Row(
              children: [
                Text(source, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (saved) ...[
                  const SizedBox(width: 10),
                  Text(s.savedToFav, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ],
                const Spacer(),
                if (openMore != null)
                  TextButton(
                    onPressed: openMore,
                    child: Text(s.moreLink, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  GestureDetector(
                    onTap: () => setState(() => _page = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.accent : const Color(0x40FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
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
}

class _ContinueListening extends ConsumerWidget {
  const _ContinueListening();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastListeningProvider);
    if (last == null) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        color: AppColors.card,
        borderColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () async {
          final handler = ref.read(audioHandlerProvider);
          final names = ref.read(suwarProvider).valueOrNull ?? {last.surah: last.surahName};
          if (handler.currentSurah != last.surah || handler.reciter?.id != last.reciter.id) {
            await handler.playSurah(
              reciter: last.reciter,
              moshaf: last.moshaf,
              surah: last.surah,
              names: names,
              start: Duration(milliseconds: last.positionMs),
            );
          }
          if (context.mounted) Navigator.of(context).push(PlayerScreen.route());
        },
        child: Row(
          children: [
            LetterAvatar(letter: last.reciter.letter, size: 48, radius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.continueListening, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text('${last.surahName} · ${last.reciter.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 34),
          ],
        ),
      ),
    );
  }
}

class _Tiles extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final hour = DateTime.now().hour;
    final evening = hour >= 15 || hour < 4;
    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.favorite_rounded,
            iconColor: AppColors.accent,
            title: s.favorites,
            subtitle: s.favoritesSub,
            onTap: () => Navigator.of(context).push(FavoritesScreen.route()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            icon: evening ? Icons.nightlight_round : Icons.wb_sunny_outlined,
            iconColor: Colors.white,
            title: evening ? s.eveningAdhkar : s.morningAdhkar,
            subtitle: s.adhkarTileSub,
            onTap: () => ref.read(tabProvider.notifier).state = 3,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _RadiosStrip extends ConsumerWidget {
  const _RadiosStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final radios = ref.watch(radiosProvider);
    return radios.when(
      loading: () => const SizedBox(height: 96, child: Loading()),
      error: (e, _) => ErrorRetry(message: s.loadFailed, retryLabel: s.retry, onRetry: () => ref.invalidate(radiosProvider)),
      data: (list) => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length < 10 ? list.length : 10,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final r = list[i];
            return SizedBox(
              width: 140,
              child: GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(12),
                onTap: () => ref.read(audioHandlerProvider).playRadio(r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiveBadge(label: s.live),
                    const Spacer(),
                    Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.35)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
