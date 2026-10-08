import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../core/home_widgets.dart';
import '../../state/actions.dart';
import '../../state/providers.dart';
import '../shell.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';
import 'wamda_screen.dart';
import 'player_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        ref.invalidate(radiosProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _Header(),
          const SizedBox(height: 18),
          const _WamdaCard(),
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

/// "ومضات اليوم": one card, one item per day — a hadith one day, a dua the next, then an ayah.
class _WamdaCard extends ConsumerWidget {
  const _WamdaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scale = ref.watch(settingsProvider).textScale;
    final w = ref.watch(wamdaOfDayProvider);
    final saved = ref.watch(isFavoriteProvider(w.key));

    return GlassCard(
      strong: true,
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 6),
      onTap: () => Navigator.of(context).push(WamdaScreen.route(w)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(s.wamdat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(999)),
                child: Text(wamdaTypeLabel(s, w.type), style: const TextStyle(fontSize: 11, color: AppColors.soft)),
              ),
              const Spacer(),
              HeartButton(
                active: saved,
                label: s.favorites,
                onTap: () => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
                      key: w.key,
                      type: w.favoriteType,
                      title: w.text,
                      subtitle: w.source,
                      payload: w.toJson(),
                    )),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(
              w.text,
              // Long text shrinks instead of being cut off.
              style: AppTheme.scripture(size: autoScriptureSize(w.text, max: 21) * scale),
            ),
          ),
          Row(
            children: [
              Text(w.source, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              if (saved) ...[
                const SizedBox(width: 10),
                Text(s.savedToFav, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(WamdaScreen.route(w)),
                child: Text(s.moreLink, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ),
            ],
          ),
        ],
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
          await resumeLastListening(ref);
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
                  Text(s.stoppedAt(HomeWidgets.formatPosition(last.positionMs)),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
