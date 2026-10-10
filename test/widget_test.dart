import 'package:alqaree/core/home_widgets.dart';
import 'package:alqaree/core/notifications.dart';
import 'package:alqaree/core/strings.dart';
import 'package:alqaree/core/theme.dart';
import 'package:alqaree/data/api.dart';
import 'package:alqaree/data/local_content.dart';
import 'package:alqaree/data/models.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(LocalContent.load);

  test('surah urls use zero-padded file names', () {
    const m = Moshaf(id: 1, name: 'حفص', server: 'https://server6.mp3quran.net/akdr', surahs: [1, 18]);
    expect(m.urlFor(1), 'https://server6.mp3quran.net/akdr/001.mp3');
    expect(m.urlFor(18), 'https://server6.mp3quran.net/akdr/018.mp3');
  });

  test('reciters parse from the mp3quran v3 shape', () {
    const raw = '{"reciters":[{"id":1,"name":"إبراهيم الأخضر","letter":"إ","moshaf":[{"id":1,"name":"حفص عن عاصم - مرتل","server":"https://server6.mp3quran.net/akdr/","surah_total":2,"moshaf_type":116,"surah_list":"1,2"}]}]}';
    final list = Mp3QuranApi.parseReciters(raw);
    expect(list.single.letter, 'إ');
    expect(list.single.moshaf.single.surahs, [1, 2]);
  });

  test('long texts get a smaller font, never cut', () {
    expect(autoScriptureSize('قصير'), 20);
    expect(autoScriptureSize('ا' * 300), 14.5);
  });

  test('bundled content loads', () {
    expect(LocalContent.morning, isNotEmpty);
    expect(LocalContent.evening, isNotEmpty);
    for (final t in WamdaType.values) {
      expect(LocalContent.wamdat[t], isNotEmpty);
    }
  });

  test('wamda is stable within a day and mixes hadith, dua, ayah', () {
    final a = LocalContent.wamdaFor(DateTime(2026, 10, 8, 1));
    final b = LocalContent.wamdaFor(DateTime(2026, 10, 8, 23));
    expect(a.key, b.key);
    final types = {for (var d = 0; d < 30; d++) LocalContent.wamdaFor(DateTime(2026, 10, 8 + d)).type};
    expect(types, WamdaType.values.toSet());
    expect(LocalContent.mixRank('hadith:0'), 0x47f98b5c, reason: 'same FNV-1a as the widgets and the video');
  });

  test('positions format as mm:ss', () {
    expect(HomeWidgets.formatPosition(492000), '08:12');
    expect(HomeWidgets.formatPosition(3723000), '1:02:03');
  });

  test('content is long enough not to repeat for weeks, and valid', () {
    expect(LocalContent.wamdat[WamdaType.hadith]!.length, greaterThanOrEqualTo(30));
    expect(LocalContent.wamdat[WamdaType.dua]!.length, greaterThanOrEqualTo(15));
    expect(LocalContent.wamdat[WamdaType.ayah]!.length, greaterThanOrEqualTo(30));
    expect(LocalContent.friday, isNotEmpty);
    final seen = <String>{};
    for (var d = 0; d < 60; d++) {
      seen.add(LocalContent.wamdaFor(DateTime(2026, 10, 1).add(Duration(days: d))).key);
    }
    expect(seen.length, 60, reason: 'no ومضة repeats within two months');
    expect(LocalContent.isValid({'hadith': [], 'dua': [], 'ayah': [], 'friday': []}), isFalse);
  });

  test('every hadith is agreed upon (متفق عليه), every other item is Quran', () {
    bool isQuran(Wamda w) => w.source.startsWith('سورة') && w.text.startsWith('﴿');
    bool agreedUpon(Wamda w) => RegExp(r'^صحيح البخاري \d+$').hasMatch(w.source) && w.text.contains('«') && (w.url ?? '').contains('hadeethenc.com');
    for (final w in LocalContent.wamdat[WamdaType.hadith]!) {
      expect(agreedUpon(w), isTrue, reason: 'hadith not agreed upon: ${w.text} (${w.source})');
    }
    for (final w in LocalContent.wamdat[WamdaType.ayah]!) {
      expect(isQuran(w), isTrue, reason: w.text);
    }
    for (final w in [...LocalContent.wamdat[WamdaType.dua]!, ...LocalContent.friday]) {
      expect(isQuran(w) || agreedUpon(w), isTrue, reason: 'neither Quran nor agreed upon: ${w.text} (${w.source})');
    }
  });

  test('friday text changes weekly, not daily', () {
    final fri = DateTime(2026, 10, 9); // a Friday
    expect(LocalContent.fridayFor(fri).text, LocalContent.fridayFor(fri.add(const Duration(days: 1))).text);
    expect(LocalContent.fridayFor(fri).text, isNot(LocalContent.fridayFor(fri.add(const Duration(days: 7))).text));
  });

  test('notification prefs round-trip', () {
    final p = const NotificationPrefs().copyWith(
      asked: true,
      wamdaTime: const TimeOfDay(hour: 21, minute: 5),
      frequency: WamdaFrequency.threeWeekly,
      morning: true,
      silent: true,
      pausedUntil: DateTime(2026, 10, 16),
    );
    final q = NotificationPrefs.decode(p.encode());
    expect(q.asked, isTrue);
    expect(q.wamdaTime, const TimeOfDay(hour: 21, minute: 5));
    expect(q.frequency, WamdaFrequency.threeWeekly);
    expect(q.morning, isTrue);
    expect(q.silent, isTrue);
    expect(q.pausedUntil, DateTime(2026, 10, 16));
    expect(NotificationPrefs.decode('not json').wamda, isTrue);
  });

  test('defaults send at most one notification a day', () {
    // Daily ومضة on 6 days + the Friday reminder in its place on Friday.
    expect(const NotificationPrefs().perWeek(), 7);
    expect(const NotificationPrefs(frequency: WamdaFrequency.weekly).perWeek(), 2);
    expect(const NotificationPrefs(wamda: false, friday: false).perWeek(), 0);
    expect(const NotificationPrefs(morning: true, evening: true).perWeek(), 21);
  });

  test('strings switch language', () {
    expect(const S(false).home, 'الرئيسية');
    expect(const S(true).home, 'Home');
  });
}
