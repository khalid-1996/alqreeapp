import 'dart:convert';

import '../core/db.dart';
import 'api.dart';
import 'models.dart';

/// Single entry point for content. Screens never call an API directly:
/// every response is cached in SQLite and served from cache when offline.
class Repository {
  final AppDb db;
  final Mp3QuranApi mp3;
  final HadithApi hadith;

  Repository({required this.db, required this.mp3, required this.hadith});

  static const _listMaxAge = Duration(hours: 24);

  Future<String> _cachedFetch(String key, Future<String> Function() fetch, Duration maxAge) async {
    final cached = await db.cached(key);
    final at = await db.cachedAt(key);
    if (cached != null && at != null && DateTime.now().difference(at) < maxAge) {
      return cached;
    }
    try {
      final fresh = await fetch();
      await db.putCache(key, fresh);
      return fresh;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<Reciter>> reciters(String lang) async =>
      Mp3QuranApi.parseReciters(await _cachedFetch('reciters:$lang', () => mp3.recitersRaw(lang), _listMaxAge));

  Future<Map<int, String>> suwar(String lang) async =>
      Mp3QuranApi.parseSuwar(await _cachedFetch('suwar:$lang', () => mp3.suwarRaw(lang), const Duration(days: 30)));

  Future<List<RadioStation>> radios(String lang) async =>
      Mp3QuranApi.parseRadios(await _cachedFetch('radios:$lang', () => mp3.radiosRaw(lang), _listMaxAge));

  /// Same hadith for everyone on the same day, from Sahih al-Bukhari or Sahih Muslim only.
  Future<Hadith> hadithOfDay(DateTime now) async {
    final day = DateTime.utc(now.year, now.month, now.day);
    final key = 'hod:${day.toIso8601String().substring(0, 10)}';
    final cached = await db.cached(key);
    if (cached != null) return Hadith.fromJson(jsonDecode(cached) as Map<String, dynamic>);

    final dayIndex = day.millisecondsSinceEpoch ~/ 86400000;
    final collection = dayIndex.isEven ? 'bukhari' : 'muslim';
    final max = HadithApi.maxNumber[collection]!;
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      final number = ((dayIndex * 7919 + attempt * 104729) % max) + 1;
      try {
        final h = await hadith.fetch(collection, number);
        await db.putCache(key, jsonEncode(h.toJson()));
        return h;
      } catch (e) {
        lastError = e;
      }
    }
    // Offline fallback: the most recent hadith we have.
    final fallback = await db.cached('hod:last');
    if (fallback != null) return Hadith.fromJson(jsonDecode(fallback) as Map<String, dynamic>);
    throw lastError ?? StateError('hadith unavailable');
  }

  Future<void> rememberLastHadith(Hadith h) => db.putCache('hod:last', jsonEncode(h.toJson()));
}
