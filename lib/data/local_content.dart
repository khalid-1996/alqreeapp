import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Content bundled with the app (assets/data/*.json). The home-screen widgets
/// read the same files, so the app and the widgets always agree.
class LocalContent {
  static List<Dhikr> morning = const [];
  static List<Dhikr> evening = const [];
  static List<Dhikr> general = const [];
  static Map<WamdaType, List<Wamda>> wamdat = const {};

  static Future<void> load() async {
    final adhkar = jsonDecode(await rootBundle.loadString('assets/data/adhkar.json')) as Map<String, dynamic>;
    List<Dhikr> list(String k) => ((adhkar[k] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((e) => Dhikr(id: '${e['id']}', text: '${e['text']}', source: '${e['source']}', count: (e['count'] as num).toInt()))
        .toList();
    morning = list('morning');
    evening = list('evening');
    general = list('general');

    final w = jsonDecode(await rootBundle.loadString('assets/data/wamdat.json')) as Map<String, dynamic>;
    final parsed = <WamdaType, List<Wamda>>{};
    for (final t in WamdaType.values) {
      final raw = (w[t.name] as List?) ?? const [];
      parsed[t] = [
        for (var i = 0; i < raw.length; i++)
          Wamda(type: t, index: i, text: '${(raw[i] as Map)['text']}', source: '${(raw[i] as Map)['source']}'),
      ];
    }
    wamdat = parsed;
  }

  /// Days since epoch for the local calendar date. The widgets use the same formula.
  static int dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Same ومضة for everyone on the same day: hadith, then dua, then ayah.
  static Wamda wamdaFor(DateTime day) {
    final i = dayIndex(day);
    final type = WamdaType.values[i % 3];
    final list = wamdat[type] ?? const [];
    if (list.isEmpty) {
      return const Wamda(type: WamdaType.dua, index: 0, text: '«ربنا آتنا في الدنيا حسنة، وفي الآخرة حسنة، وقنا عذاب النار»', source: 'متفق عليه');
    }
    return list[(i ~/ 3) % list.length];
  }

  /// Evening adhkar from 15:00 until 04:00, morning otherwise.
  static bool isEvening(DateTime now) => now.hour >= 15 || now.hour < 4;
}
