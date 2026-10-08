import 'package:alqaree/core/strings.dart';
import 'package:alqaree/core/theme.dart';
import 'package:alqaree/data/api.dart';
import 'package:alqaree/data/local_content.dart';
import 'package:alqaree/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('dua of the day is stable within a day', () {
    final a = LocalContent.duaFor(DateTime(2026, 10, 8, 1));
    final b = LocalContent.duaFor(DateTime(2026, 10, 8, 23));
    expect(a.id, b.id);
  });

  test('strings switch language', () {
    expect(const S(false).home, 'الرئيسية');
    expect(const S(true).home, 'Home');
  });
}
