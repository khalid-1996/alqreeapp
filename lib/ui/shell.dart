import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/home_widgets.dart';
import '../core/notifications.dart';
import '../data/local_content.dart';
import '../core/theme.dart';
import '../state/actions.dart';
import '../state/providers.dart';
import 'screens/adhkar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/player_screen.dart';
import 'screens/radios_screen.dart';
import 'screens/reciters_screen.dart';
import 'screens/wamda_screen.dart';
import 'widgets/mini_player.dart';

final tabProvider = StateProvider<int>((ref) => 0);

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClicks;
  StreamSubscription<NotificationTap>? _notifTaps;

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    handler.onProgress = (v, force) => ref.read(lastListeningProvider.notifier).save(v, force: force);
    WidgetsBinding.instance.addObserver(this);
    // Taps on the home-screen widgets: alqaree://resume, alqaree://adhkar
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_openFromWidget);
    _widgetClicks = HomeWidget.widgetClicked.listen(_openFromWidget);
    // Taps on notifications, including the one that launched the app.
    _notifTaps = Notifications.taps.listen((t) => _openPayload(t.payload));
    Notifications.launchPayload().then((p) {
      if (p != null) _openPayload(p);
    });
    // Plan the coming weeks once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) => syncNotifications(ref.read));
    handler.errors.listen((_) {
      if (!mounted) return;
      final s = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.playFailed)));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    _notifTaps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(adhkarCounterProvider.notifier).reload().then((_) => syncNotifications(ref.read));
      HomeWidgets.refreshAll();
    }
  }

  Future<void> _openPayload(String payload) async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (payload.startsWith('wamda:')) {
      final day = DateTime.tryParse(payload.substring(6)) ?? DateTime.now();
      ref.read(tabProvider.notifier).state = 0;
      nav.push(WamdaScreen.route(LocalContent.wamdaFor(day)));
    } else if (payload.startsWith('adhkar')) {
      ref.read(tabProvider.notifier).state = 3;
    } else if (payload == 'friday') {
      await _playKahf();
    }
  }

  /// Friday: Surah Al-Kahf with the last reciter, else a well-known one.
  Future<void> _playKahf() async {
    const kahf = 18;
    final handler = ref.read(audioHandlerProvider);
    final names = ref.read(suwarProvider).valueOrNull ?? const {kahf: 'الكهف'};
    final last = ref.read(lastListeningProvider);
    var reciter = last?.reciter;
    var moshaf = last?.moshaf;
    if (moshaf == null || !moshaf.surahs.contains(kahf)) {
      try {
        final all = await ref.read(recitersProvider.future);
        final withKahf = all.where((r) => r.moshaf.any((m) => m.surahs.contains(kahf))).toList();
        reciter = withKahf.firstWhere((r) => r.name.contains('العفاسي'), orElse: () => withKahf.first);
        moshaf = reciter.moshaf.firstWhere((m) => m.surahs.contains(kahf));
      } catch (_) {
        reciter = null;
      }
    }
    if (!mounted) return;
    if (reciter == null || moshaf == null) {
      ref.read(tabProvider.notifier).state = 1;
      final s = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.chooseReciterForKahf)));
      return;
    }
    await handler.playSurah(reciter: reciter, moshaf: moshaf, surah: kahf, names: names);
    if (mounted) Navigator.of(context).push(PlayerScreen.route());
  }

  Future<void> _openFromWidget(Uri? uri) async {
    if (uri == null || !mounted) return;
    switch (uri.host) {
      case 'resume':
        ref.read(tabProvider.notifier).state = 0;
        if (await resumeLastListening(ref) && mounted) {
          Navigator.of(context).push(PlayerScreen.route());
        }
      case 'adhkar':
        ref.read(tabProvider.notifier).state = 3;
      case 'wamda':
        ref.read(tabProvider.notifier).state = 0;
        Navigator.of(context).push(WamdaScreen.route(ref.read(wamdaOfDayProvider)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final tab = ref.watch(tabProvider);
    const pages = [HomeScreen(), RecitersScreen(), RadiosScreen(), AdhkarScreen(), MoreScreen()];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: AppColors.background,
              indicatorColor: AppColors.glass,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 11,
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
                  color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
                ),
              ),
            ),
            child: NavigationBar(
              height: 68,
              selectedIndex: tab,
              onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.home),
                NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book_rounded), label: s.reciters),
                NavigationDestination(icon: const Icon(Icons.radio_outlined), selectedIcon: const Icon(Icons.radio_rounded), label: s.radios),
                NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), selectedIcon: const Icon(Icons.auto_awesome), label: s.adhkar),
                NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), label: s.more),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
