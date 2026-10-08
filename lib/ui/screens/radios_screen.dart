import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

class RadiosScreen extends ConsumerStatefulWidget {
  const RadiosScreen({super.key});

  @override
  ConsumerState<RadiosScreen> createState() => _RadiosScreenState();
}

class _RadiosScreenState extends ConsumerState<RadiosScreen> {
  String _query = '';
  bool _favOnly = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final radios = ref.watch(radiosProvider);
    final favs = ref.watch(favoritesProvider);
    final current = ref.watch(mediaItemProvider).valueOrNull;
    final playing = ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.radios, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
              LiveBadge(label: s.liveAllDay),
            ],
          ),
          const SizedBox(height: 14),
          SearchField(hint: s.searchRadio, onChanged: (v) => setState(() => _query = v.trim())),
          const SizedBox(height: 12),
          Row(
            children: [
              Pill(label: s.all, selected: !_favOnly, onTap: () => setState(() => _favOnly = false)),
              const SizedBox(width: 8),
              Pill(label: s.favorites, selected: _favOnly, onTap: () => setState(() => _favOnly = true)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: radios.when(
              loading: () => const Loading(),
              error: (e, _) => Center(
                child: ErrorRetry(message: s.loadFailed, retryLabel: s.retry, onRetry: () => ref.invalidate(radiosProvider)),
              ),
              data: (list) {
                final favKeys = favs.map((f) => f.key).toSet();
                final filtered = list.where((r) {
                  if (_query.isNotEmpty && !r.name.contains(_query)) return false;
                  if (_favOnly && !favKeys.contains('radio:${r.id}')) return false;
                  return true;
                }).toList();
                if (filtered.isEmpty) {
                  return Center(child: Text(s.noFavorites, style: const TextStyle(color: AppColors.muted)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = filtered[i];
                    final isCurrent = current?.id == r.url;
                    return _RadioTile(
                      radio: r,
                      active: isCurrent && playing,
                      isFav: favKeys.contains('radio:${r.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioTile extends ConsumerWidget {
  final RadioStation radio;
  final bool active;
  final bool isFav;

  const _RadioTile({required this.radio, required this.active, required this.isFav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    void toggle() => active ? handler.pause() : handler.playRadio(radio);
    return GlassCard(
      // The whole card plays the station, not only the round button.
      onTap: toggle,
      radius: 20,
      color: active ? AppColors.card : null,
      borderColor: active ? AppColors.accent : null,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: active ? AppColors.accent : const Color(0x1AFFFFFF),
                foregroundColor: active ? AppColors.background : Colors.white,
              ),
              onPressed: toggle,
              icon: Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(radio.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(active ? s.nowPlaying : s.liveStream,
                    style: TextStyle(fontSize: 12, color: active ? AppColors.accent : AppColors.muted)),
              ],
            ),
          ),
          HeartButton(
            active: isFav,
            label: s.favorites,
            size: 20,
            onTap: () => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
                  key: 'radio:${radio.id}',
                  type: FavoriteType.radio,
                  title: radio.name,
                  subtitle: s.liveStream,
                  payload: radio.toJson(),
                )),
          ),
        ],
      ),
    );
  }
}
