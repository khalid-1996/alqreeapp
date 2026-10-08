import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

/// Shown once, on first launch. Asks for no permissions.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final english = ref.watch(settingsProvider).english;

    Widget feature(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.glassSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => ref.read(settingsProvider.notifier).setEnglish(!english),
                  child: Text(english ? 'العربية' : 'English', style: const TextStyle(color: AppColors.muted)),
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Image.asset('assets/icon/logo_white.png'),
                ),
              ),
              const SizedBox(height: 18),
              Text(s.appName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(s.welcomeLine, textAlign: TextAlign.center, style: AppTheme.scripture(size: 22, color: AppColors.soft, height: 1.7)),
              const Spacer(),
              feature(Icons.menu_book_outlined, s.featureReciters),
              const SizedBox(height: 12),
              feature(Icons.radio_outlined, s.featureRadios),
              const SizedBox(height: 12),
              feature(Icons.favorite_border_rounded, s.featureDaily),
              const Spacer(),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () => ref.read(settingsProvider.notifier).markWelcomeSeen(),
                  child: Text(s.start, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 14),
              Text(s.noAccount, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
