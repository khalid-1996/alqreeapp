import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/local_content.dart';
import '../data/models.dart';

/// How often ومضات اليوم arrives.
enum WamdaFrequency { daily, threeWeekly, weekly }

/// Everything the user can choose about notifications. Stored as JSON in SharedPreferences.
class NotificationPrefs {
  /// Set once the user has answered the in-app invitation (or the system prompt).
  final bool asked;
  final bool wamda;
  final TimeOfDay wamdaTime;
  final WamdaFrequency frequency;
  final bool friday;
  final TimeOfDay fridayTime;
  final bool morning;
  final TimeOfDay morningTime;
  final bool evening;
  final TimeOfDay eveningTime;
  final bool silent;
  final DateTime? pausedUntil;

  const NotificationPrefs({
    this.asked = false,
    this.wamda = true,
    this.wamdaTime = const TimeOfDay(hour: 8, minute: 30),
    this.frequency = WamdaFrequency.daily,
    this.friday = true,
    this.fridayTime = const TimeOfDay(hour: 10, minute: 0),
    this.morning = false,
    this.morningTime = const TimeOfDay(hour: 6, minute: 30),
    this.evening = false,
    this.eveningTime = const TimeOfDay(hour: 17, minute: 30),
    this.silent = false,
    this.pausedUntil,
  });

  bool get anyEnabled => wamda || friday || morning || evening;

  bool isPaused(DateTime at) => pausedUntil != null && at.isBefore(pausedUntil!);

  NotificationPrefs copyWith({
    bool? asked,
    bool? wamda,
    TimeOfDay? wamdaTime,
    WamdaFrequency? frequency,
    bool? friday,
    TimeOfDay? fridayTime,
    bool? morning,
    TimeOfDay? morningTime,
    bool? evening,
    TimeOfDay? eveningTime,
    bool? silent,
    DateTime? pausedUntil,
    bool clearPause = false,
  }) =>
      NotificationPrefs(
        asked: asked ?? this.asked,
        wamda: wamda ?? this.wamda,
        wamdaTime: wamdaTime ?? this.wamdaTime,
        frequency: frequency ?? this.frequency,
        friday: friday ?? this.friday,
        fridayTime: fridayTime ?? this.fridayTime,
        morning: morning ?? this.morning,
        morningTime: morningTime ?? this.morningTime,
        evening: evening ?? this.evening,
        eveningTime: eveningTime ?? this.eveningTime,
        silent: silent ?? this.silent,
        pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
      );

  static String _t(TimeOfDay t) => '${t.hour}:${t.minute}';
  static TimeOfDay _p(Object? s, TimeOfDay fallback) {
    final parts = '${s ?? ''}'.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return (h == null || m == null) ? fallback : TimeOfDay(hour: h, minute: m);
  }

  String encode() => jsonEncode({
        'asked': asked,
        'wamda': wamda,
        'wamdaTime': _t(wamdaTime),
        'frequency': frequency.name,
        'friday': friday,
        'fridayTime': _t(fridayTime),
        'morning': morning,
        'morningTime': _t(morningTime),
        'evening': evening,
        'eveningTime': _t(eveningTime),
        'silent': silent,
        'pausedUntil': pausedUntil?.toIso8601String(),
      });

  factory NotificationPrefs.decode(String? raw) {
    const d = NotificationPrefs();
    if (raw == null) return d;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPrefs(
        asked: j['asked'] as bool? ?? d.asked,
        wamda: j['wamda'] as bool? ?? d.wamda,
        wamdaTime: _p(j['wamdaTime'], d.wamdaTime),
        frequency: WamdaFrequency.values.firstWhere((f) => f.name == j['frequency'], orElse: () => d.frequency),
        friday: j['friday'] as bool? ?? d.friday,
        fridayTime: _p(j['fridayTime'], d.fridayTime),
        morning: j['morning'] as bool? ?? d.morning,
        morningTime: _p(j['morningTime'], d.morningTime),
        evening: j['evening'] as bool? ?? d.evening,
        eveningTime: _p(j['eveningTime'], d.eveningTime),
        silent: j['silent'] as bool? ?? d.silent,
        pausedUntil: DateTime.tryParse('${j['pausedUntil'] ?? ''}'),
      );
    } catch (_) {
      return d;
    }
  }

  /// Days ومضات arrives on (DateTime.weekday). Friday is left to the Friday reminder.
  static const threeWeeklyDays = {DateTime.saturday, DateTime.monday, DateTime.wednesday};
  static const weeklyDays = {DateTime.monday};

  bool wamdaOn(DateTime day) => switch (frequency) {
        WamdaFrequency.daily => true,
        WamdaFrequency.threeWeekly => threeWeeklyDays.contains(day.weekday),
        WamdaFrequency.weekly => weeklyDays.contains(day.weekday),
      };

  /// Roughly how many notifications a week these settings produce (shown to the user).
  int perWeek() {
    var n = 0;
    for (var wd = 1; wd <= 7; wd++) {
      final isFriday = wd == DateTime.friday;
      if (friday && isFriday) n++;
      final probe = DateTime(2026, 1, 4 + wd); // 2026-01-05 is a Monday
      if (wamda && wamdaOn(probe) && !(friday && isFriday)) n++;
      if (morning) n++;
      if (evening) n++;
    }
    return n;
  }
}

/// A notification tap, routed by the app shell.
class NotificationTap {
  final String payload;
  const NotificationTap(this.payload);
}

/// Local notifications only: nothing is sent from a server, and nothing leaves the device.
/// The next weeks are scheduled ahead (well under iOS's 64-notification limit) and
/// rescheduled whenever the app opens, settings change, or content updates.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _taps = StreamController<NotificationTap>.broadcast();
  static bool _ready = false;

  static Stream<NotificationTap> get taps => _taps.stream;

  // Ids are deterministic per day, so one day's reminder can be cancelled on its own.
  static int _id(int base, DateTime day) => base * 100000 + LocalContent.dayIndex(day) % 100000;
  static int wamdaId(DateTime d) => _id(1, d);
  static int fridayId(DateTime d) => _id(2, d);
  static int morningId(DateTime d) => _id(3, d);
  static int eveningId(DateTime d) => _id(4, d);

  static const _channelNormal = 'alqaree_daily';
  static const _channelQuiet = 'alqaree_quiet';

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Never prompt on launch: the app asks politely, in context.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) _taps.add(NotificationTap(p));
        },
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications init: $e');
    }
  }

  /// The payload of the notification that launched the app, if any.
  static Future<String?> launchPayload() async {
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) return d?.notificationResponse?.payload;
    } catch (_) {}
    return null;
  }

  static Future<bool> isPermitted() async {
    try {
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false;
      }
      if (Platform.isIOS) {
        final o = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
        return o?.isEnabled ?? false;
      }
    } catch (_) {}
    return false;
  }

  /// Shows the system prompt. Returns whether notifications are allowed afterwards.
  static Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: false, sound: true);
      }
    } catch (_) {}
    return isPermitted();
  }

  static NotificationDetails _details({
    required String title,
    required String bigText,
    required String thread,
    required bool silent,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        silent ? _channelQuiet : _channelNormal,
        silent ? 'القارئ (بدون صوت)' : 'القارئ',
        channelDescription: 'ومضات اليوم وتذكير الجمعة والأذكار',
        importance: silent ? Importance.low : Importance.defaultImportance,
        priority: silent ? Priority.low : Priority.defaultPriority,
        playSound: !silent,
        enableVibration: !silent,
        icon: 'ic_notification',
        color: const Color(0xFF3BA7FF),
        category: AndroidNotificationCategory.reminder,
        groupKey: 'alqaree.$thread',
        styleInformation: BigTextStyleInformation(bigText, contentTitle: title, summaryText: 'القارئ'),
      ),
      iOS: DarwinNotificationDetails(
        presentSound: !silent,
        presentBadge: false,
        threadIdentifier: thread,
        interruptionLevel: silent ? InterruptionLevel.passive : InterruptionLevel.active,
      ),
    );
  }

  static String wamdaTitle(Wamda w) => switch (w.type) {
        WamdaType.hadith => 'ومضات اليوم · حديث',
        WamdaType.dua => 'ومضات اليوم · دعاء',
        WamdaType.ayah => 'ومضات اليوم · آية',
      };

  static const fridayTitle = 'جمعة مباركة';
  static const fridayNote = 'لا تنسَ قراءة سورة الكهف، والإكثار من الصلاة على النبي ﷺ';

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Cancels everything and schedules the coming weeks from [prefs].
  /// [morningDone]/[eveningDone]: today's adhkar are finished, so today's reminder is skipped.
  static Future<int> reschedule(
    NotificationPrefs prefs, {
    bool morningDone = false,
    bool eveningDone = false,
  }) async {
    if (!_ready) await init();
    try {
      await _plugin.cancelAll();
      if (!prefs.anyEnabled || !await isPermitted()) return 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var count = 0;

      Future<void> at(int id, DateTime day, TimeOfDay t, String title, String body, String bigText, String thread, String payload) async {
        final when = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (!when.isAfter(now) || prefs.isPaused(when)) return;
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          // An absolute instant: correct in any time zone without a time-zone database lookup.
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _details(title: title, bigText: bigText, thread: thread, silent: prefs.silent),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        count++;
      }

      // 30 days of ومضات + 5 Fridays + 7 days of each adhkar reminder = at most 49 (< 64 on iOS).
      for (var d = 0; d < 35; d++) {
        final day = today.add(Duration(days: d));
        final isFriday = day.weekday == DateTime.friday;

        if (prefs.friday && isFriday) {
          final f = LocalContent.fridayFor(day);
          await at(fridayId(day), day, prefs.fridayTime, fridayTitle, fridayNote,
              '${f.text}\n— ${f.source}\n\n$fridayNote', 'friday', 'friday');
        }

        // One gentle notification a day: on Friday the Friday reminder takes the ومضة's place.
        if (d < 30 && prefs.wamda && prefs.wamdaOn(day) && !(prefs.friday && isFriday)) {
          final w = LocalContent.wamdaFor(day);
          await at(wamdaId(day), day, prefs.wamdaTime, wamdaTitle(w), w.text, '${w.text}\n— ${w.source}', 'wamda',
              'wamda:${dateKey(day)}');
        }

        if (d < 7 && prefs.morning && !(d == 0 && morningDone)) {
          await at(morningId(day), day, prefs.morningTime, 'أذكار الصباح', 'ابدأ يومك بذكر الله',
              'ابدأ يومك بذكر الله · ${LocalContent.morning.length} أذكار', 'adhkar', 'adhkar:morning');
        }
        if (d < 7 && prefs.evening && !(d == 0 && eveningDone)) {
          await at(eveningId(day), day, prefs.eveningTime, 'أذكار المساء', 'اختم يومك بذكر الله',
              'اختم يومك بذكر الله · ${LocalContent.evening.length} أذكار', 'adhkar', 'adhkar:evening');
        }
      }
      return count;
    } catch (e) {
      debugPrint('notifications reschedule: $e');
      return 0;
    }
  }

  /// Today's adhkar are done: drop today's reminder only.
  static Future<void> cancelToday({required bool evening}) async {
    final today = DateTime.now();
    try {
      await _plugin.cancel(id: evening ? eveningId(today) : morningId(today));
    } catch (_) {}
  }

  /// A sample, so the user sees exactly what will arrive.
  static Future<void> showSample(NotificationPrefs prefs) async {
    if (!_ready) await init();
    final w = LocalContent.wamdaFor(DateTime.now());
    try {
      await _plugin.show(
        id: 99,
        title: wamdaTitle(w),
        body: w.text,
        notificationDetails: _details(title: wamdaTitle(w), bigText: '${w.text}\n— ${w.source}', thread: 'wamda', silent: prefs.silent),
        payload: 'wamda:${dateKey(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('notifications sample: $e');
    }
  }
}
