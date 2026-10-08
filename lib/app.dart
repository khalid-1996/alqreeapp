import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'state/providers.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/shell.dart';

class AlqareeApp extends ConsumerWidget {
  const AlqareeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(stringsProvider);
    return MaterialApp(
      title: s.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: Locale(settings.english ? 'en' : 'ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settings.seenWelcome ? const Shell() : const WelcomeScreen(),
    );
  }
}
