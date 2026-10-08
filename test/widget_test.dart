import 'package:alqaree/core/home_widgets.dart';
import 'package:alqaree/core/strings.dart';
import 'package:alqaree/core/theme.dart';
import 'package:alqaree/data/api.dart';
import 'package:alqaree/data/local_content.dart';
import 'package:alqaree/data/models.dart';
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

  test('wamda is stable within a day and rotates hadith, dua, ayah', () {
    final a = LocalContent.wamdaFor(DateTime(2026, 10, 8, 1));
    final b = LocalContent.wamdaFor(DateTime(2026, 10, 8, 23));
    expect(a.key, b.key);
    final types = {for (var d = 0; d < 3; d++) LocalContent.wamdaFor(DateTime(2026, 10, 8 + d)).type};
    expect(types, WamdaType.values.toSet());
  });

  test('positions format as mm:ss', () {
    expect(HomeWidgets.formatPosition(492000), '08:12');
    expect(HomeWidgets.formatPosition(3723000), '1:02:03');
  });

  test('strings switch language', () {
    expect(const S(false).home, 'الرئيسية');
    expect(const S(true).home, 'Home');
  });
}
