import 'dart:convert';

class Moshaf {
  final int id;
  final String name;
  final String server;
  final List<int> surahs;

  const Moshaf({required this.id, required this.name, required this.server, required this.surahs});

  factory Moshaf.fromJson(Map<String, dynamic> j) {
    final list = (j['surah_list'] ?? '').toString();
    return Moshaf(
      id: _int(j['id']),
      name: (j['name'] ?? '').toString(),
      server: (j['server'] ?? '').toString(),
      surahs: list
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList(),
    );
  }

  /// mp3quran file naming: server + 001.mp3
  String urlFor(int surah) {
    final base = server.endsWith('/') ? server : '$server/';
    return '$base${surah.toString().padLeft(3, '0')}.mp3';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'server': server,
        'surah_list': surahs.join(','),
      };
}

class Reciter {
  final int id;
  final String name;
  final String letter;
  final List<Moshaf> moshaf;

  const Reciter({required this.id, required this.name, required this.letter, required this.moshaf});

  factory Reciter.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString().trim();
    final letter = (j['letter'] ?? '').toString().trim();
    return Reciter(
      id: _int(j['id']),
      name: name,
      letter: letter.isNotEmpty ? letter : (name.isNotEmpty ? name.characters1 : '؟'),
      moshaf: ((j['moshaf'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Moshaf.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  /// Short description of the first recitation, e.g. "حفص عن عاصم - مرتل".
  String get subtitle => moshaf.isEmpty ? '' : moshaf.first.name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'letter': letter,
        'moshaf': moshaf.map((m) => m.toJson()).toList(),
      };
}

class RadioStation {
  final int id;
  final String name;
  final String url;

  const RadioStation({required this.id, required this.name, required this.url});

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: _int(j['id']),
        name: (j['name'] ?? '').toString().trim(),
        url: (j['url'] ?? '').toString().trim(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};
}

class Hadith {
  final String collection; // bukhari | muslim
  final int number;
  final String text;

  const Hadith({required this.collection, required this.number, required this.text});

  String get bookName => collection == 'muslim' ? 'صحيح مسلم' : 'صحيح البخاري';
  String get narratedBy => collection == 'muslim' ? 'رواه مسلم' : 'رواه البخاري';
  String get key => 'hadith:$collection:$number';

  Map<String, dynamic> toJson() => {'collection': collection, 'number': number, 'text': text};

  factory Hadith.fromJson(Map<String, dynamic> j) => Hadith(
        collection: (j['collection'] ?? 'bukhari').toString(),
        number: _int(j['number']),
        text: (j['text'] ?? '').toString(),
      );
}

class Dhikr {
  final String id;
  final String text;
  final String source;
  final int count;

  const Dhikr({required this.id, required this.text, required this.source, required this.count});
}

class Dua {
  final String id;
  final String text;
  final String source;

  const Dua({required this.id, required this.text, required this.source});

  String get key => 'dua:$id';
}

enum FavoriteType { reciter, surah, radio, hadith, dua }

class FavoriteItem {
  final String key;
  final FavoriteType type;
  final String title;
  final String subtitle;
  final Map<String, dynamic> payload;

  const FavoriteItem({
    required this.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.payload = const {},
  });

  Map<String, Object?> toRow() => {
        'key': key,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'payload': jsonEncode(payload),
        'created': DateTime.now().millisecondsSinceEpoch,
      };

  factory FavoriteItem.fromRow(Map<String, Object?> r) => FavoriteItem(
        key: r['key'] as String,
        type: FavoriteType.values.firstWhere(
          (t) => t.name == r['type'],
          orElse: () => FavoriteType.hadith,
        ),
        title: (r['title'] ?? '') as String,
        subtitle: (r['subtitle'] ?? '') as String,
        payload: _decodeMap(r['payload'] as String?),
      );
}

Map<String, dynamic> _decodeMap(String? s) {
  if (s == null || s.isEmpty) return const {};
  try {
    final v = jsonDecode(s);
    return v is Map ? Map<String, dynamic>.from(v) : const {};
  } catch (_) {
    return const {};
  }
}

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

extension _FirstChar on String {
  String get characters1 => isEmpty ? '' : substring(0, 1);
}
