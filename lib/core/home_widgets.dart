import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../audio/audio_handler.dart';
import '../data/models.dart';

/// Pushes data to the home-screen widgets (Android AppWidgets, iOS WidgetKit).
/// Failures are swallowed: a widget must never break the app.
class HomeWidgets {
  static const appGroup = 'group.net.alqareeapp.alqaree';
  static const iosDaily = 'AlqareeWidget';
  static const iosListening = 'AlqareeListeningWidget';
  static const androidDaily = 'DailyWidgetProvider';
  static const androidListening = 'ListeningWidgetProvider';

  /// Widgets have a fixed size, so long hadiths are replaced by the dua of the day.
  static const maxWidgetText = 150;

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroup);
    } catch (e) {
      debugPrint('home_widget init: $e');
    }
  }

  static Future<void> updateDaily({Hadith? hadith, required Dua dua}) async {
    final useHadith = hadith != null && hadith.text.length <= maxWidgetText;
    try {
      await HomeWidget.saveWidgetData<String>('daily_label', useHadith ? 'حديث اليوم' : 'دعاء اليوم');
      await HomeWidget.saveWidgetData<String>('daily_text', useHadith ? hadith!.text : dua.text);
      await HomeWidget.saveWidgetData<String>('daily_source', useHadith ? hadith!.narratedBy : dua.source);
      await HomeWidget.updateWidget(androidName: androidDaily, iOSName: iosDaily);
    } catch (e) {
      debugPrint('home_widget daily: $e');
    }
  }

  static String? _lastSurahKey;

  static Future<void> updateListening(LastListening v) async {
    final key = '${v.reciter.id}:${v.moshaf.id}:${v.surah}';
    if (key == _lastSurahKey) return; // only when the surah changes, not on every progress tick
    _lastSurahKey = key;
    try {
      await HomeWidget.saveWidgetData<String>('last_title', v.surahName);
      await HomeWidget.saveWidgetData<String>('last_artist', v.reciter.name);
      await HomeWidget.saveWidgetData<String>('last_letter', v.reciter.letter);
      await HomeWidget.updateWidget(androidName: androidListening, iOSName: iosListening);
    } catch (e) {
      debugPrint('home_widget listening: $e');
    }
  }
}
