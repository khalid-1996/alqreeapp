import 'dart:convert';

import 'package:dio/dio.dart';

import 'models.dart';

/// mp3quran.net v3 — reciters, surah names and radios. Public, no key.
class Mp3QuranApi {
  final Dio _dio;
  Mp3QuranApi(this._dio);

  static const _base = 'https://mp3quran.net/api/v3';

  Future<String> recitersRaw(String lang) => _get('$_base/reciters', {'language': lang});
  Future<String> suwarRaw(String lang) => _get('$_base/suwar', {'language': lang});
  Future<String> radiosRaw(String lang) => _get('$_base/radios', {'language': lang});

  Future<String> _get(String url, Map<String, dynamic> q) async {
    final res = await _dio.get<dynamic>(url, queryParameters: q);
    final data = res.data;
    return data is String ? data : jsonEncode(data);
  }

  static List<Reciter> parseReciters(String raw) {
    final j = jsonDecode(raw);
    final list = (j is Map ? j['reciters'] : null) as List? ?? const [];
    final out = list
        .whereType<Map>()
        .map((e) => Reciter.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.name.isNotEmpty && r.moshaf.isNotEmpty)
        .toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  static Map<int, String> parseSuwar(String raw) {
    final j = jsonDecode(raw);
    final list = (j is Map ? j['suwar'] : null) as List? ?? const [];
    final out = <int, String>{};
    for (final e in list.whereType<Map>()) {
      final id = e['id'] is int ? e['id'] as int : int.tryParse('${e['id']}');
      if (id != null) out[id] = '${e['name']}'.trim();
    }
    return out;
  }

  static List<RadioStation> parseRadios(String raw) {
    final j = jsonDecode(raw);
    final list = (j is Map ? j['radios'] : null) as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => RadioStation.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.name.isNotEmpty && r.url.startsWith('http'))
        .toList();
  }
}

/// fawazahmed0/hadith-api via jsDelivr — public domain (The Unlicense), no key.
class HadithApi {
  final Dio _dio;
  HadithApi(this._dio);

  static const _base = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';

  /// Conservative upper bounds so every picked number exists in the edition.
  static const maxNumber = {'bukhari': 7500, 'muslim': 7400};

  Future<Hadith> fetch(String collection, int number) async {
    final res = await _dio.get<dynamic>('$_base/ara-$collection/$number.min.json');
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final list = (data is Map ? data['hadiths'] : null) as List? ?? const [];
    final maps = list.whereType<Map>().toList();
    final first = maps.isEmpty ? null : maps.first;
    final text = (first?['text'] ?? '').toString().trim();
    if (text.isEmpty) throw StateError('empty hadith $collection/$number');
    return Hadith(collection: collection, number: number, text: text);
  }
}

Dio buildDio() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json'},
      ),
    );
