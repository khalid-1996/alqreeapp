import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';

enum PlayMode { next, repeat, shuffle }

/// What the user last listened to, for the "continue listening" card.
class LastListening {
  final Reciter reciter;
  final Moshaf moshaf;
  final int surah;
  final String surahName;
  final int positionMs;

  const LastListening({
    required this.reciter,
    required this.moshaf,
    required this.surah,
    required this.surahName,
    required this.positionMs,
  });

  Map<String, dynamic> toJson() => {
        'reciter': reciter.toJson(),
        'moshaf': moshaf.toJson(),
        'surah': surah,
        'surahName': surahName,
        'positionMs': positionMs,
      };

  factory LastListening.fromJson(Map<String, dynamic> j) => LastListening(
        reciter: Reciter.fromJson(Map<String, dynamic>.from(j['reciter'] as Map)),
        moshaf: Moshaf.fromJson(Map<String, dynamic>.from(j['moshaf'] as Map)),
        surah: j['surah'] as int,
        surahName: (j['surahName'] ?? '') as String,
        positionMs: (j['positionMs'] ?? 0) as int,
      );
}

/// Streams only: nothing is ever saved to disk as an audio file.
class AlqariAudioHandler extends BaseAudioHandler with SeekHandler {
  /// App logo shown on the lock screen, notification, CarPlay/Android Auto and AirPlay.
  static Uri? artUri;

  final AudioPlayer _player = AudioPlayer();
  final _rnd = Random();

  Reciter? _reciter;
  Moshaf? _moshaf;
  Map<int, String> _names = const {};
  int _index = 0; // index into _moshaf.surahs
  bool _isLive = false;
  PlayMode _mode = PlayMode.next;

  final _modeCtrl = StreamController<PlayMode>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  /// Called whenever a surah starts or periodically while playing.
  void Function(LastListening v, bool force)? onProgress;

  AlqariAudioHandler() {
    _player.playbackEventStream.map(_transform).pipe(playbackState);
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && !_isLive) _onCompleted();
    });
    _player.positionStream
        .where((_) => !_isLive && _player.playing)
        .distinct((a, b) => a.inSeconds ~/ 5 == b.inSeconds ~/ 5)
        .listen((pos) => _report(pos));
    // Save exactly where the user stopped.
    _player.playingStream.listen((playing) {
      if (!playing && !_isLive) _report(_player.position, force: true);
    });
  }

  Stream<Duration> get position => _player.positionStream;
  Stream<Duration?> get duration => _player.durationStream;
  Stream<PlayMode> get modeStream => _modeCtrl.stream;
  Stream<String> get errors => _errorCtrl.stream;
  PlayMode get mode => _mode;
  bool get isLive => _isLive;
  Reciter? get reciter => _reciter;
  Moshaf? get moshaf => _moshaf;
  int? get currentSurah => (_moshaf == null || _moshaf!.surahs.isEmpty) ? null : _moshaf!.surahs[_index];

  void setMode(PlayMode m) {
    _mode = m;
    _modeCtrl.add(m);
  }

  Future<void> playSurah({
    required Reciter reciter,
    required Moshaf moshaf,
    required int surah,
    required Map<int, String> names,
    Duration start = Duration.zero,
  }) async {
    _isLive = false;
    _reciter = reciter;
    _moshaf = moshaf;
    _names = names;
    final i = moshaf.surahs.indexOf(surah);
    _index = i < 0 ? 0 : i;
    await _loadCurrent(start: start);
  }

  Future<void> playRadio(RadioStation radio) async {
    _isLive = true;
    _reciter = null;
    _moshaf = null;
    final item = MediaItem(
      id: radio.url,
      title: radio.name,
      artist: 'بث مباشر',
      album: 'القارئ',
      artUri: artUri,
      extras: {'type': 'radio', 'radioId': radio.id},
    );
    mediaItem.add(item);
    await _open(radio.url);
  }

  Future<void> _loadCurrent({Duration start = Duration.zero}) async {
    final m = _moshaf;
    final r = _reciter;
    if (m == null || r == null || m.surahs.isEmpty) return;
    final surah = m.surahs[_index];
    final name = _names[surah] ?? 'سورة $surah';
    final item = MediaItem(
      id: m.urlFor(surah),
      title: name,
      artist: r.name,
      album: m.name,
      artUri: artUri,
      extras: {'type': 'surah', 'reciterId': r.id, 'moshafId': m.id, 'surah': surah},
    );
    mediaItem.add(item);
    await _open(item.id, start: start);
    _report(start);
  }

  Future<void> _open(String url, {Duration start = Duration.zero}) async {
    try {
      await _player.stop();
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)), initialPosition: start);
      await _player.play();
    } catch (_) {
      _errorCtrl.add('play_failed');
    }
  }

  void _report(Duration pos, {bool force = false}) {
    final m = _moshaf;
    final r = _reciter;
    final cb = onProgress;
    if (m == null || r == null || cb == null || m.surahs.isEmpty) return;
    final surah = m.surahs[_index];
    cb(LastListening(
      reciter: r,
      moshaf: m,
      surah: surah,
      surahName: _names[surah] ?? 'سورة $surah',
      positionMs: pos.inMilliseconds,
    ), force);
  }

  Future<void> _onCompleted() async {
    final m = _moshaf;
    if (m == null || m.surahs.isEmpty) return;
    switch (_mode) {
      case PlayMode.repeat:
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      case PlayMode.shuffle:
        _index = _rnd.nextInt(m.surahs.length);
        await _loadCurrent();
        return;
      case PlayMode.next:
        if (_index < m.surahs.length - 1) {
          _index++;
          await _loadCurrent();
        } else {
          await _player.pause();
          await _player.seek(Duration.zero);
        }
        return;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    final m = _moshaf;
    if (_isLive || m == null || m.surahs.isEmpty) return;
    _index = _mode == PlayMode.shuffle ? _rnd.nextInt(m.surahs.length) : (_index + 1) % m.surahs.length;
    await _loadCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    final m = _moshaf;
    if (_isLive || m == null || m.surahs.isEmpty) return;
    if (_player.position > const Duration(seconds: 5)) {
      await _player.seek(Duration.zero);
      return;
    }
    _index = (_index - 1 + m.surahs.length) % m.surahs.length;
    await _loadCurrent();
  }

  PlaybackState _transform(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (!_isLive) MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        if (!_isLive) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: _isLive ? const <MediaAction>{} : const <MediaAction>{MediaAction.seek},
      androidCompactActionIndices: _isLive ? const [0] : const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }
}
