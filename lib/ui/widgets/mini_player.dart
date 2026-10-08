import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemProvider).valueOrNull;
    if (item == null) return const SizedBox.shrink();
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final playing = state?.playing ?? false;
    final loading = state?.processingState == AudioProcessingState.loading ||
        state?.processingState == AudioProcessingState.buffering;
    final handler = ref.read(audioHandlerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: AppColors.miniPlayer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(PlayerScreen.route()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _Wave(active: playing),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        )
                      : IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.background),
                          onPressed: playing ? handler.pause : handler.play,
                          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wave extends StatefulWidget {
  final bool active;
  const _Wave({required this.active});

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Wave old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = [10.0, 20.0, 14.0, 18.0];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => SizedBox(
        width: 24,
        height: 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < base.length; i++)
              Container(
                width: 3,
                height: widget.active ? 4 + (base[i] - 4) * (i.isEven ? _c.value : 1 - _c.value) : base[i] * 0.5,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}
