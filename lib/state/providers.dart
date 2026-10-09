import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_handler.dart';
import '../core/db.dart';
import '../core/home_widgets.dart';
import '../core/notifications.dart';
import '../core/strings.dart';
import '../data/local_content.dart';
import '../data/models.dart';
import '../data/repository.dart';

// Overridden in main() once they are initialised.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final dbProvider = Provider<AppDb>((ref) => throw UnimplementedError());
final repositoryProvider = Provider<Repository>((ref) => throw UnimplementedError());
final audioHandlerProvider = Provider<AlqariAudioHandler>((ref) => throw UnimplementedError());

// ---------- Settings ----------

class Settings {
  final bool english;
  final double textScale; // 0.9 / 1.0 / 1.15
  final bool seenWelcome;

  const Settings({required this.english, required this.textScale, required this.seenWelcome});

  Settings copyWith({bool? english, double? textScale, bool? seenWelcome}) => Settings(
        english: english ?? this.english,
        textScale: textScale ?? this.textScale,
        seenWelcome: seenWelcome ?? this.seenWelcome,
      );
}

class SettingsNotifier extends StateNotifier<Settings> {
  final SharedPreferences _p;
  SettingsNotifier(this._p)
      : super(Settings(
          english: _p.getBool('english') ?? false,
          textScale: _p.getDouble('textScale') ?? 1.0,
          seenWelcome: _p.getBool('seenWelcome') ?? false,
        ));

  void setEnglish(bool v) {
    _p.setBool('english', v);
    state = state.copyWith(english: v);
  }

  void setTextScale(double v) {
    _p.setDouble('textScale', v);
    state = state.copyWith(textScale: v);
  }

  void markWelcomeSeen() {
    _p.setBool('seenWelcome', true);
    state = state.copyWith(seenWelcome: true);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
  (ref) => SettingsNotifier(ref.watch(prefsProvider)),
);

final stringsProvider = Provider<S>((ref) => S(ref.watch(settingsProvider).english));

String _lang(Ref ref) => ref.watch(settingsProvider).english ? 'eng' : 'ar';

// ---------- Content ----------

final recitersProvider = FutureProvider<List<Reciter>>(
  (ref) => ref.watch(repositoryProvider).reciters(_lang(ref)),
);

final suwarProvider = FutureProvider<Map<int, String>>(
  // Surah names stay Arabic: they are part of the Quran, not the UI.
  (ref) => ref.watch(repositoryProvider).suwar('ar'),
);

final radiosProvider = FutureProvider<List<RadioStation>>(
  (ref) => ref.watch(repositoryProvider).radios(_lang(ref)),
);

final hadithOfDayProvider = FutureProvider<Hadith>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final h = await repo.hadithOfDay(DateTime.now());
  await repo.rememberLastHadith(h);
  return h;
});

final wamdaOfDayProvider = Provider<Wamda>((ref) => LocalContent.wamdaFor(DateTime.now()));

// ---------- Favorites ----------

class FavoritesNotifier extends StateNotifier<List<FavoriteItem>> {
  final AppDb _db;
  FavoritesNotifier(this._db) : super(const []) {
    _load();
  }

  Future<void> _load() async => state = await _db.favorites();

  bool contains(String key) => state.any((f) => f.key == key);

  Future<void> toggle(FavoriteItem item) async {
    if (contains(item.key)) {
      await _db.removeFavorite(item.key);
    } else {
      await _db.addFavorite(item);
    }
    await _load();
  }

  Future<void> remove(String key) async {
    await _db.removeFavorite(key);
    await _load();
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<FavoriteItem>>(
  (ref) => FavoritesNotifier(ref.watch(dbProvider)),
);

final isFavoriteProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(favoritesProvider).any((f) => f.key == key),
);

// ---------- Player ----------

final mediaItemProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
);

final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioHandlerProvider).position,
);

final durationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(audioHandlerProvider).duration,
);

final playModeProvider = StreamProvider<PlayMode>((ref) async* {
  final h = ref.watch(audioHandlerProvider);
  yield h.mode;
  yield* h.modeStream;
});

class LastListeningNotifier extends StateNotifier<LastListening?> {
  final SharedPreferences _p;
  LastListeningNotifier(this._p) : super(_read(_p));

  static LastListening? _read(SharedPreferences p) {
    final raw = p.getString('lastListening');
    if (raw == null) return null;
    try {
      return LastListening.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void save(LastListening v, {bool force = false}) {
    _p.setString('lastListening', jsonEncode(v.toJson()));
    state = v;
    HomeWidgets.updateListening(v, force: force);
  }
}

final lastListeningProvider = StateNotifierProvider<LastListeningNotifier, LastListening?>(
  (ref) => LastListeningNotifier(ref.watch(prefsProvider)),
);

// ---------- Adhkar counters (per day, shared with the adhkar widget) ----------

class AdhkarCounter extends StateNotifier<Map<String, int>> {
  AdhkarCounter() : super(const {}) {
    reload();
  }

  /// Picks up counts made from the home-screen widget.
  Future<void> reload() async {
    state = await HomeWidgets.loadAdhkar();
  }

  void tap(Dhikr d) {
    final used = state[d.id] ?? 0;
    if (used >= d.count) return;
    state = {...state, d.id: used + 1};
    HomeWidgets.saveAdhkar(state);
    if (LocalContent.allDone(LocalContent.morning, state)) Notifications.cancelToday(evening: false);
    if (LocalContent.allDone(LocalContent.evening, state)) Notifications.cancelToday(evening: true);
  }

  void reset(List<Dhikr> list) {
    final next = Map<String, int>.from(state);
    for (final d in list) {
      next.remove(d.id);
    }
    state = next;
    HomeWidgets.saveAdhkar(state);
  }
}

final adhkarCounterProvider = StateNotifierProvider<AdhkarCounter, Map<String, int>>((ref) => AdhkarCounter());

// ---------- Notifications ----------

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  final SharedPreferences _p;
  NotificationPrefsNotifier(this._p) : super(NotificationPrefs.decode(_p.getString('notifPrefs')));

  void update(NotificationPrefs next) {
    _p.setString('notifPrefs', next.encode());
    state = next;
  }
}

final notificationPrefsProvider = StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  (ref) => NotificationPrefsNotifier(ref.watch(prefsProvider)),
);

/// Whether the OS currently allows notifications. Refreshed on resume and after asking.
final notificationsPermittedProvider = StateProvider<bool>((ref) => false);

typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Re-plans every notification and the widgets' upcoming ومضات from the current state.
Future<void> syncNotifications(Reader read) async {
  final permitted = await Notifications.isPermitted();
  read(notificationsPermittedProvider.notifier).state = permitted;
  final counts = read(adhkarCounterProvider);
  await Notifications.reschedule(
    read(notificationPrefsProvider),
    morningDone: LocalContent.allDone(LocalContent.morning, counts),
    eveningDone: LocalContent.allDone(LocalContent.evening, counts),
  );
  await HomeWidgets.saveUpcomingWamdat();
}
