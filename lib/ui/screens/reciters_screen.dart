import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

class RecitersScreen extends ConsumerStatefulWidget {
  const RecitersScreen({super.key});

  @override
  ConsumerState<RecitersScreen> createState() => _RecitersScreenState();
}

class _RecitersScreenState extends ConsumerState<RecitersScreen> {
  String _query = '';
  String? _riwaya; // null = all

  static String _riwayaOf(Moshaf m) {
    // "Rewayat Hafs A'n Assem - Murattal" / "حفص عن عاصم - مرتل"
    final parts = m.name.split(' - ');
    return parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final reciters = ref.watch(recitersProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.reciters, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          SearchField(hint: s.searchReciter, onChanged: (v) => setState(() => _query = v.trim())),
          const SizedBox(height: 12),
          Expanded(
            child: reciters.when(
              loading: () => const Loading(),
              error: (e, _) => Center(
                child: ErrorRetry(message: s.loadFailed, retryLabel: s.retry, onRetry: () => ref.invalidate(recitersProvider)),
              ),
              data: (list) {
                final counts = <String, int>{};
                for (final r in list) {
                  for (final m in r.moshaf) {
                    final k = _riwayaOf(m);
                    counts[k] = (counts[k] ?? 0) + 1;
                  }
                }
                final top = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
                final riwayat = top.take(4).toList();

                final filtered = list.where((r) {
                  if (_query.isNotEmpty && !r.name.contains(_query)) return false;
                  if (_riwaya != null && !r.moshaf.any((m) => _riwayaOf(m) == _riwaya)) return false;
                  return true;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Pill(label: s.all, selected: _riwaya == null, onTap: () => setState(() => _riwaya = null)),
                          for (final rw in riwayat) ...[
                            const SizedBox(width: 8),
                            Pill(label: rw, selected: _riwaya == rw, onTap: () => setState(() => _riwaya = rw)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ReciterTile(reciter: filtered[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  final Reciter reciter;
  const _ReciterTile({required this.reciter});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.of(context).push(ReciterScreen.route(reciter)),
      child: Row(
        children: [
          LetterAvatar(letter: reciter.letter),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reciter.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(reciter.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// A reciter's recitations (moshaf) and the surahs available in each.
class ReciterScreen extends ConsumerStatefulWidget {
  final Reciter reciter;
  const ReciterScreen({super.key, required this.reciter});

  static Route<void> route(Reciter r) => MaterialPageRoute(builder: (_) => ReciterScreen(reciter: r));

  @override
  ConsumerState<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends ConsumerState<ReciterScreen> {
  int _moshaf = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = widget.reciter;
    final m = r.moshaf[_moshaf < r.moshaf.length ? _moshaf : 0];
    final names = ref.watch(suwarProvider).valueOrNull ?? const <int, String>{};
    final favKey = 'reciter:${r.id}';
    final isFav = ref.watch(isFavoriteProvider(favKey));
    final current = ref.watch(mediaItemProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          HeartButton(
            active: isFav,
            label: s.favorites,
            onTap: () => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
                  key: favKey,
                  type: FavoriteType.reciter,
                  title: r.name,
                  subtitle: r.subtitle,
                  payload: r.toJson(),
                )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              LetterAvatar(letter: r.letter, size: 64, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(s.surahCount(m.surahs.length), style: const TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
          if (r.moshaf.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.moshaf.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Pill(
                  label: r.moshaf[i].name,
                  selected: i == _moshaf,
                  onTap: () => setState(() => _moshaf = i),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(m.name, style: const TextStyle(fontSize: 13, color: AppColors.soft)),
          ],
          const SizedBox(height: 16),
          for (final surah in m.surahs) ...[
            _SurahRow(
              number: surah,
              name: names[surah] ?? 'سورة $surah',
              playing: current?.id == m.urlFor(surah),
              onTap: () {
                ref.read(audioHandlerProvider).playSurah(reciter: r, moshaf: m, surah: surah, names: names);
                Navigator.of(context).push(PlayerScreen.route());
              },
              favKey: 'surah:${r.id}:${m.id}:$surah',
              onFav: () => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
                    key: 'surah:${r.id}:${m.id}:$surah',
                    type: FavoriteType.surah,
                    title: names[surah] ?? 'سورة $surah',
                    subtitle: r.name,
                    payload: {'reciter': r.toJson(), 'moshafId': m.id, 'surah': surah},
                  )),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SurahRow extends ConsumerWidget {
  final int number;
  final String name;
  final bool playing;
  final VoidCallback onTap;
  final String favKey;
  final VoidCallback onFav;

  const _SurahRow({
    required this.number,
    required this.name,
    required this.playing,
    required this.onTap,
    required this.favKey,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider(favKey));
    final s = ref.watch(stringsProvider);
    return GlassCard(
      radius: 16,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
      borderColor: playing ? AppColors.accent : null,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('$number', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(child: Text(name, style: AppTheme.scripture(size: 18, height: 1.6))),
          if (playing) const Icon(Icons.graphic_eq_rounded, color: AppColors.accent, size: 20),
          HeartButton(active: isFav, label: s.favorites, onTap: onFav, size: 20),
        ],
      ),
    );
  }
}
