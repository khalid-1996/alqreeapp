import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';
import 'hadith_screen.dart';
import 'notifications_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final hadith = ref.watch(hadithOfDayProvider).valueOrNull;

    String sizeLabel(double v) => v < 1 ? s.fontSmall : (v > 1 ? s.fontLarge : s.fontMedium);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(s.more, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.favorite_rounded,
                iconColor: AppColors.accent,
                label: s.favorites,
                onTap: () => Navigator.of(context).push(FavoritesScreen.route()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(
                icon: Icons.format_quote_rounded,
                iconColor: Colors.white,
                label: s.hadithOfDay,
                onTap: hadith == null ? null : () => Navigator.of(context).push(HadithScreen.route(hadith)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _GroupTitle(s.settings),
        _Group(children: [
          _Row(
            label: s.notifications,
            value: ref.watch(notificationsPermittedProvider) && ref.watch(notificationPrefsProvider).anyEnabled ? s.notifOn : s.notifOff,
            onTap: () => Navigator.of(context).push(NotificationsScreen.route()),
          ),
          _Row(
            label: s.language,
            value: s.languageValue,
            onTap: () => ref.read(settingsProvider.notifier).setEnglish(!settings.english),
          ),
          _Row(
            label: s.fontSize,
            value: sizeLabel(settings.textScale),
            onTap: () {
              final next = settings.textScale < 1 ? 1.0 : (settings.textScale == 1.0 ? 1.15 : 0.9);
              ref.read(settingsProvider.notifier).setTextScale(next);
            },
          ),
        ]),
        const SizedBox(height: 20),
        _GroupTitle(s.about),
        _Group(children: [
          _Row(label: s.sources, onTap: () => Navigator.of(context).push(InfoScreen.sources(s.en))),
          _Row(label: s.privacy, onTap: () => Navigator.of(context).push(InfoScreen.privacy(s.en))),
        ]),
        const SizedBox(height: 28),
        Center(child: Text(s.appName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Center(child: Text(s.noAccount, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _Shortcut({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      strong: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.glassBorderSoft),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _Row({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Static pages: sources & credits, privacy policy.
class InfoScreen extends StatelessWidget {
  final String title;
  final List<(String, String, String?)> items; // heading, body, link

  const InfoScreen({super.key, required this.title, required this.items});

  static Route<void> sources(bool en) => MaterialPageRoute(
        builder: (_) => InfoScreen(
          title: en ? 'Sources & credits' : 'المصادر والحقوق',
          items: [
            (
              'MP3Quran.net',
              en
                  ? 'Recitations, surah names and Quran radio streams, via the public mp3quran.net API. Audio is streamed only, never downloaded.'
                  : 'التلاوات وأسماء السور وإذاعات القرآن، عبر واجهة mp3quran.net العامة. الصوت يُبث فقط ولا يُحمَّل.',
              'https://mp3quran.net'
            ),
            (
              'Hadith API (fawazahmed0)',
              en
                  ? 'Hadith of the day from Sahih al-Bukhari and Sahih Muslim. Public domain (The Unlicense).'
                  : 'حديث اليوم من صحيح البخاري وصحيح مسلم. النص في الملكية العامة (The Unlicense).',
              'https://github.com/fawazahmed0/hadith-api'
            ),
            (
              'Tanzil Quran Text',
              en
                  ? 'Quranic verses in ومضات and duas are the Uthmani text of the Tanzil Project, copied verbatim (CC BY 3.0).'
                  : 'الآيات في الومضات والأدعية من نص التنزيل العثماني (Tanzil)، منقولة كما هي دون تعديل (CC BY 3.0).',
              'https://tanzil.net'
            ),
            (
              en ? 'Adhkar and duas' : 'الأذكار والأدعية',
              en
                  ? 'Selected authentic adhkar and duas from Hisn al-Muslim and the Sunnah, bundled in the app.'
                  : 'أذكار وأدعية صحيحة مختارة من حصن المسلم والسنة، مضمنة في التطبيق.',
              null
            ),
            (
              en ? 'Fonts' : 'الخطوط',
              en ? 'Amiri and Tajawal, under the SIL Open Font License.' : 'خطا Amiri و Tajawal، برخصة SIL Open Font License.',
              null
            ),
          ],
        ),
      );

  static Route<void> privacy(bool en) => MaterialPageRoute(
        builder: (_) => InfoScreen(
          title: en ? 'Privacy policy' : 'سياسة الخصوصية',
          items: [
            (
              en ? 'No data collected' : 'لا نجمع أي بيانات',
              en
                  ? 'Al-Qari has no accounts, no analytics and no tracking. We do not collect, store or share any personal information.'
                  : 'تطبيق القارئ بدون حسابات ولا أدوات تحليل ولا تتبع. لا نجمع ولا نخزن ولا نشارك أي معلومات شخصية.',
              null
            ),
            (
              en ? 'Stored on your device only' : 'محفوظ على جهازك فقط',
              en
                  ? 'Favorites, settings and the last surah you listened to are saved locally on your device and are removed when you delete the app.'
                  : 'المفضلة والإعدادات وآخر سورة استمعت لها تُحفظ محليًا على جهازك فقط، وتُحذف بحذف التطبيق.',
              null
            ),
            (
              en ? 'Third-party services' : 'خدمات خارجية',
              en
                  ? 'To stream audio and load content, the app connects to mp3quran.net and cdn.jsdelivr.net. These services receive standard network information such as your IP address, as with any website.'
                  : 'لتشغيل الصوت وتحميل المحتوى يتصل التطبيق بـ mp3quran.net و cdn.jsdelivr.net، وتصلها معلومات الاتصال المعتادة مثل عنوان IP كأي موقع.',
              null
            ),
            (
              en ? 'Notifications' : 'الإشعارات',
              en
                  ? 'Reminders are scheduled locally on your device. There is no push server, and you can change or turn them off at any time.'
                  : 'التذكيرات تُجدول محليًا على جهازك، بدون أي خادم. تقدر تغيّرها أو توقفها متى ما تبي.',
              null
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (heading, body, link) = items[i];
          return GlassCard(
            radius: 18,
            onTap: link == null ? null : () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(fontSize: 14, color: AppColors.soft, height: 1.6)),
                if (link != null) ...[
                  const SizedBox(height: 6),
                  Text(link, style: const TextStyle(fontSize: 12, color: AppColors.accent)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
