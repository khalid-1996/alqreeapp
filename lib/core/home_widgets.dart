import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../audio/audio_handler.dart';

/// Bridge to the home-screen widgets (Android AppWidgets, iOS WidgetKit).
///
/// - "ومضات اليوم" is computed by the widgets themselves from assets/data/wamdat.json,
///   so it changes every day without opening the app.
/// - "أكمل الاستماع" and the adhkar counter are shared through home_widget storage.
/// Failures are swallowed: a widget must never break the app.
class HomeWidgets {
  static const appGroup = 'group.net.alqareeapp.alqaree';

  static const iosWamda = 'AlqareeWidget';
  static const iosListening = 'AlqareeListeningWidget';
  static const iosAdhkar = 'AlqareeAdhkarWidget';
  static const androidWamda = 'DailyWidgetProvider';
  static const androidListening = 'ListeningWidgetProvider';
  static const androidAdhkar = 'AdhkarWidgetProvider';

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroup);
    } catch (e) {
      debugPrint('home_widget init: $e');
    }
  }

  static Future<void> refreshAll() async {
    await _update(androidWamda, iosWamda);
    await _update(androidListening, iosListening);
    await _update(androidAdhkar, iosAdhkar);
  }

  static Future<void> _update(String android, String ios) async {
    try {
      await HomeWidget.updateWidget(androidName: android, iOSName: ios);
    } catch (e) {
      debugPrint('home_widget update $android: $e');
    }
  }

  // ---------- Continue listening ----------

  static String? _lastKey;
  static DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pushed when the surah changes, when playback pauses ([force]) and at most once a minute otherwise.
  static Future<void> updateListening(LastListening v, {bool force = false}) async {
    final key = '${v.reciter.id}:${v.moshaf.id}:${v.surah}';
    final now = DateTime.now();
    if (!force && key == _lastKey && now.difference(_lastPush) < const Duration(minutes: 1)) return;
    _lastKey = key;
    _lastPush = now;
    try {
      await HomeWidget.saveWidgetData<String>('last_title', v.surahName);
      await HomeWidget.saveWidgetData<String>('last_artist', v.reciter.name);
      await HomeWidget.saveWidgetData<String>('last_letter', v.reciter.letter);
      await HomeWidget.saveWidgetData<String>('last_position', formatPosition(v.positionMs));
      await _update(androidListening, iosListening);
    } catch (e) {
      debugPrint('home_widget listening: $e');
    }
  }

  static String formatPosition(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ---------- Adhkar counter (shared with the adhkar widget) ----------

  static const _adhkarKey = 'adhkar_state';

  static String today([DateTime? d]) {
    final n = d ?? DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Today's counts, by dhikr id. Counts from a previous day are dropped.
  static Future<Map<String, int>> loadAdhkar() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>(_adhkarKey);
      if (raw == null || raw.isEmpty) return {};
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['date'] != today()) return {};
      return (j['counts'] as Map? ?? const {}).map((k, v) => MapEntry('$k', (v as num).toInt()));
    } catch (e) {
      debugPrint('home_widget adhkar load: $e');
      return {};
    }
  }

  static Future<void> saveAdhkar(Map<String, int> counts) async {
    try {
      await HomeWidget.saveWidgetData<String>(_adhkarKey, jsonEncode({'date': today(), 'counts': counts}));
      await _update(androidAdhkar, iosAdhkar);
    } catch (e) {
      debugPrint('home_widget adhkar save: $e');
    }
  }
}
