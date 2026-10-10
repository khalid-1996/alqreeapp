import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/db.dart';
import 'models.dart';

/// ومضات, Friday texts and adhkar.
///
/// Source order: the newest valid copy from the content API (cached in SQLite),
/// else the copy bundled in assets/data/. The app always works offline.
class LocalContent {
  static List<Dhikr> morning = const [];
  static List<Dhikr> evening = const [];
  static List<Dhikr> general = const [];
  static Map<WamdaType, List<Wamda>> wamdat = const {};
  static List<Wamda> friday = const [];
  static int version = 0;

  /// Content API: the same JSON file, served from the app's repository through jsDelivr.
  /// Updating assets/data/wamdat.json on main refreshes every installed app within a week,
  /// without a new release.
  static const remoteUrl = 'https://cdn.jsdelivr.net/gh/khalid-1996/alqreeapp@main/assets/data/wamdat.json';
  static const _cacheKey = 'content:wamdat';
  static const _refreshEvery = Duration(days: 7);

  static Future<void> load({AppDb? db}) async {
    final adhkar = jsonDecode(await rootBundle.loadString('assets/data/adhkar.json')) as Map<String, dynamic>;
    List<Dhikr> list(String k) => ((adhkar[k] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((e) => Dhikr(id: '${e['id']}', text: '${e['text']}', source: '${e['source']}', count: (e['count'] as num).toInt()))
        .toList();
    morning = list('morning');
    evening = list('evening');
    general = list('general');

    final bundled = jsonDecode(await rootBundle.loadString('assets/data/wamdat.json')) as Map<String, dynamic>;
    _apply(bundled);

    if (db != null) {
      final cached = await db.cached(_cacheKey);
      if (cached != null) {
        try {
          final remote = jsonDecode(cached) as Map<String, dynamic>;
          if (isValid(remote) && _versionOf(remote) >= version) _apply(remote);
        } catch (_) {}
      }
    }
  }

  /// Fetches a newer copy at most once a week. Returns true if the content changed.
  static Future<bool> refreshRemote(AppDb db, Dio dio) async {
    try {
      final at = await db.cachedAt(_cacheKey);
      if (at != null && DateTime.now().difference(at) < _refreshEvery) return false;
      final res = await dio.get<dynamic>(remoteUrl, options: Options(responseType: ResponseType.plain));
      final raw = res.data is String ? res.data as String : jsonEncode(res.data);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (!isValid(j)) return false;
      await db.putCache(_cacheKey, raw);
      if (_versionOf(j) < version) return false;
      final before = jsonEncode(_snapshot());
      _apply(j);
      return jsonEncode(_snapshot()) != before;
    } catch (e) {
      debugPrint('content refresh: $e');
      return false;
    }
  }

  static int _versionOf(Map<String, dynamic> j) => ((j['meta'] as Map?)?['version'] as num?)?.toInt() ?? 0;

  /// Every list must be non-empty and every item must have text and a source.
  static bool isValid(Map<String, dynamic> j) {
    for (final k in ['hadith', 'dua', 'ayah', 'friday']) {
      final list = j[k];
      if (list is! List || list.isEmpty) return false;
      for (final e in list) {
        if (e is! Map || '${e['text'] ?? ''}'.trim().isEmpty || '${e['source'] ?? ''}'.trim().isEmpty) return false;
      }
    }
    return true;
  }

  static void _apply(Map<String, dynamic> j) {
    version = _versionOf(j);
    List<Wamda> parse(String key, WamdaType type) {
      final raw = (j[key] as List?) ?? const [];
      return [
        for (var i = 0; i < raw.length; i++)
          Wamda(
            type: type,
            index: i,
            text: '${(raw[i] as Map)['text']}'.trim(),
            source: '${(raw[i] as Map)['source']}'.trim(),
            url: (raw[i] as Map)['url'] as String?,
          ),
      ];
    }

    wamdat = {for (final t in WamdaType.values) t: parse(t.name, t)};
    _mixed = null;
    friday = parse('friday', WamdaType.hadith);
  }

  static Map<String, Object> _snapshot() => {
        for (final e in wamdat.entries) e.key.name: e.value.map((w) => w.text).toList(),
        'friday': friday.map((w) => w.text).toList(),
      };

  /// Days since epoch for the local calendar date. The widgets use the same formula.
  static int dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// 32-bit FNV-1a of an ASCII key such as "hadith:12", then the murmur3 finalizer so close keys spread out.
  static int mixRank(String key) {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    h ^= h >> 16;
    h = (h * 0x85ebca6b) & 0xffffffff;
    h ^= h >> 13;
    h = (h * 0xc2b2ae35) & 0xffffffff;
    return h ^ (h >> 16);
  }

  static List<Wamda>? _mixed;

  /// Hadiths, duas and ayahs in one shuffled order: sorted by mixRank("type:index").
  static List<Wamda> get mixed => _mixed ??= () {
        String k(Wamda w) => '${w.type.name}:${w.index}';
        final pool = [for (final t in WamdaType.values) ...?wamdat[t]];
        pool.sort((a, b) {
          final c = mixRank(k(a)).compareTo(mixRank(k(b)));
          return c != 0 ? c : k(a).compareTo(k(b));
        });
        return pool;
      }();

  /// Same ومضة for everyone on the same day, hadiths, duas and ayahs mixed at random;
  /// nothing repeats until the whole pool has been shown. Widgets and the video renderer
  /// use the same formula: mixed[dayIndex mod pool size].
  static Wamda wamdaFor(DateTime day) {
    final pool = mixed;
    if (pool.isEmpty) {
      return const Wamda(type: WamdaType.ayah, index: 0, text: '﴿رَبَّنَآ ءَاتِنَا فِى ٱلدُّنْيَا حَسَنَةً وَفِى ٱلْءَاخِرَةِ حَسَنَةً وَقِنَا عَذَابَ ٱلنَّارِ﴾', source: 'سورة البقرة · 201');
    }
    return pool[dayIndex(day) % pool.length];
  }

  /// A different Friday text each week.
  static Wamda fridayFor(DateTime day) {
    if (friday.isEmpty) {
      return const Wamda(type: WamdaType.hadith, index: 0, text: '«خير يوم طلعت عليه الشمس يوم الجمعة»', source: 'رواه مسلم');
    }
    return friday[(dayIndex(day) ~/ 7) % friday.length];
  }

  /// Evening adhkar from 15:00 until 04:00, morning otherwise.
  static bool isEvening(DateTime now) => now.hour >= 15 || now.hour < 4;

  static bool allDone(List<Dhikr> list, Map<String, int> counts) =>
      list.isNotEmpty && list.every((d) => (counts[d.id] ?? 0) >= d.count);
}
