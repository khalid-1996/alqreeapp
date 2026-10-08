import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Resumes the last surah from where the user stopped. Returns false if there is none.
Future<bool> resumeLastListening(WidgetRef ref) async {
  final last = ref.read(lastListeningProvider);
  if (last == null) return false;
  final handler = ref.read(audioHandlerProvider);
  if (handler.currentSurah == last.surah && handler.reciter?.id == last.reciter.id && handler.mediaItem.value != null) {
    await handler.play();
    return true;
  }
  final names = ref.read(suwarProvider).valueOrNull ?? {last.surah: last.surahName};
  await handler.playSurah(
    reciter: last.reciter,
    moshaf: last.moshaf,
    surah: last.surah,
    names: names,
    start: Duration(milliseconds: last.positionMs),
  );
  return true;
}
