import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'audio/audio_handler.dart';
import 'core/db.dart';
import 'core/home_widgets.dart';
import 'core/notifications.dart';
import 'data/api.dart';
import 'data/local_content.dart';
import 'data/repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final db = await AppDb.open();
  await LocalContent.load(db: db);
  AlqariAudioHandler.artUri = await _artworkFile();
  await Notifications.init();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final handler = await AudioService.init<AlqariAudioHandler>(
    builder: AlqariAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'net.alqareeapp.alqaree.audio',
      androidNotificationChannelName: 'Al-Qari playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  await HomeWidgets.init();
  HomeWidgets.refreshAll();
  final prefs = await SharedPreferences.getInstance();
  final dio = buildDio();
  final repo = Repository(db: db, mp3: Mp3QuranApi(dio), hadith: HadithApi(dio));

  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      dbProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      audioHandlerProvider.overrideWithValue(handler),
    ],
  );

  // Weekly content refresh from the content API; offline, the cached or bundled copy is used.
  LocalContent.refreshRemote(db, dio).then((changed) {
    if (changed) {
      container.invalidate(wamdaOfDayProvider);
      syncNotifications(container.read);
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AlqareeApp(),
    ),
  );
}

/// Media artwork must be a file or URL, so the bundled logo is copied out once.
Future<Uri?> _artworkFile() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/now_playing_art.png');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/icon/icon.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return Uri.file(file.path);
  } catch (_) {
    return null;
  }
}
