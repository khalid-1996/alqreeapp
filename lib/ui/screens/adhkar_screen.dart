import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/local_content.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key});

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    final h = DateTime.now().hour;
    _tab = (h >= 15 || h < 4) ? 1 : 0;
  }

  List<Dhikr> get _list => switch (_tab) {
        0 => LocalContent.morning,
        1 => LocalContent.evening,
        _ => LocalContent.general,
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final scale = ref.watch(settingsProvider).textScale;
    final counts = ref.watch(adhkarCounterProvider);
    final list = _list;
    final done = list.where((d) => (counts[d.id] ?? 0) >= d.count).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.adhkar, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
              Text(s.fromHisn, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 14),
          Segmented(
            labels: [s.morning, s.evening, s.general],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(s.progress(done, list.length), style: const TextStyle(fontSize: 12, color: AppColors.muted))),
              if (done > 0)
                TextButton(
                  onPressed: () => ref.read(adhkarCounterProvider.notifier).reset(list),
                  child: Text(s.resetCounters, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                )
              else
                Text(s.tapToCount, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: list.isEmpty ? 0 : done / list.length,
              minHeight: 4,
              color: AppColors.accent,
              backgroundColor: const Color(0x1FFFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = list[i];
                final used = counts[d.id] ?? 0;
                final left = d.count - used;
                final complete = left <= 0;
                return Opacity(
                  opacity: complete ? 0.6 : 1,
                  child: GlassCard(
                    radius: 20,
                    strong: !complete,
                    onTap: complete
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            ref.read(adhkarCounterProvider.notifier).tap(d);
                          },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.text, style: AppTheme.scripture(size: 18 * scale)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: Text(d.source, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
                            Container(
                              constraints: const BoxConstraints(minWidth: 52),
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: complete ? AppColors.accent : const Color(0x1AFFFFFF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: complete
                                  ? const Icon(Icons.check_rounded, size: 18, color: AppColors.background)
                                  : Text('$left', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
