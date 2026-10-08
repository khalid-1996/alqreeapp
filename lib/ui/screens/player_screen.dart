import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_handler.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static Route<void> route() => MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PlayerScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    final item = ref.watch(mediaItemProvider).valueOrNull;
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final playing = state?.playing ?? false;
    final loading = state?.processingState == AudioProcessingState.loading ||
        state?.processingState == AudioProcessingState.buffering;
    final isLive = handler.isLive;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isLive ? s.liveStream : s.recitation, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        centerTitle: true,
      ),
      body: item == null
          ? Center(child: Text(s.nothingPlaying, style: const TextStyle(color: AppColors.muted)))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    const Spacer(),
                    _Artwork(letter: handler.reciter?.letter, subtitle: item.album ?? '', isLive: isLive),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: AppTheme.scripture(size: 28, weight: FontWeight.w700, height: 1.4)),
                              Text(item.artist ?? '', style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        if (!isLive) _FavButton(handler: handler, title: item.title),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isLive)
                      Align(alignment: AlignmentDirectional.centerStart, child: LiveBadge(label: s.liveStream))
                    else
                      const _Progress(),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isLive)
                          IconButton(
                            iconSize: 34,
                            onPressed: handler.skipToPrevious,
                            icon: Icon(rtl ? Icons.skip_next_rounded : Icons.skip_previous_rounded),
                          ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: loading
                              ? const CircularProgressIndicator(color: AppColors.accent)
                              : IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.background),
                                  iconSize: 40,
                                  onPressed: playing ? handler.pause : handler.play,
                                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                ),
                        ),
                        const SizedBox(width: 20),
                        if (!isLive)
                          IconButton(
                            iconSize: 34,
                            onPressed: handler.skipToNext,
                            icon: Icon(rtl ? Icons.skip_previous_rounded : Icons.skip_next_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!isLive) const _Modes(),
                    const Spacer(),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final String? letter;
  final String subtitle;
  final bool isLive;

  const _Artwork({required this.letter, required this.subtitle, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 2)),
            child: isLive
                ? const Icon(Icons.radio_rounded, color: Colors.white, size: 52)
                : Text(letter ?? '', style: AppTheme.scripture(size: 56, weight: FontWeight.w700, height: 1.2)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress();

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final dur = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
    final value = pos.inMilliseconds.clamp(0, max.toInt()).toDouble();
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: const Color(0x24FFFFFF),
            thumbColor: Colors.white,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value,
            max: max,
            onChanged: (v) => ref.read(audioHandlerProvider).seek(Duration(milliseconds: v.toInt())),
          ),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(_fmt(dur), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Modes extends ConsumerWidget {
  const _Modes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final mode = ref.watch(playModeProvider).valueOrNull ?? PlayMode.next;
    final handler = ref.read(audioHandlerProvider);
    Widget chip(PlayMode m, IconData icon, String label) {
      final on = m == mode;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: on ? AppColors.accent : AppColors.soft,
            side: BorderSide(color: on ? AppColors.accent : const Color(0x2EFFFFFF)),
            shape: const StadiumBorder(),
          ),
          onPressed: () => handler.setMode(m),
          icon: Icon(icon, size: 16),
          label: Text(label, style: TextStyle(fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(PlayMode.next, Icons.repeat_rounded, s.modeNext),
        chip(PlayMode.repeat, Icons.repeat_one_rounded, s.modeRepeat),
        chip(PlayMode.shuffle, Icons.shuffle_rounded, s.modeShuffle),
      ],
    );
  }
}

class _FavButton extends ConsumerWidget {
  final AlqariAudioHandler handler;
  final String title;
  const _FavButton({required this.handler, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = handler.reciter;
    final m = handler.moshaf;
    final surah = handler.currentSurah;
    if (r == null || m == null || surah == null) return const SizedBox.shrink();
    final key = 'surah:${r.id}:${m.id}:$surah';
    final s = ref.watch(stringsProvider);
    return HeartButton(
      active: ref.watch(isFavoriteProvider(key)),
      label: s.favorites,
      size: 26,
      onTap: () => ref.read(favoritesProvider.notifier).toggle(FavoriteItem(
            key: key,
            type: FavoriteType.surah,
            title: title,
            subtitle: r.name,
            payload: {'reciter': r.toJson(), 'moshafId': m.id, 'surah': surah},
          )),
    );
  }
}
