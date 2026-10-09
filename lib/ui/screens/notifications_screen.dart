import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Everything the user controls about notifications, in one calm page.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const NotificationsScreen());

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Notifications.isPermitted().then((v) {
      if (mounted) ref.read(notificationsPermittedProvider.notifier).state = v;
    });
  }

  Future<void> _set(NotificationPrefs next) async {
    ref.read(notificationPrefsProvider.notifier).update(next.copyWith(asked: true));
    await syncNotifications(ref.read);
  }

  Future<void> _pickTime(TimeOfDay current, void Function(TimeOfDay) apply) async {
    final t = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.accent, surface: AppColors.card, onPrimary: AppColors.background),
        ),
        child: child!,
      ),
    );
    if (t != null) apply(t);
  }

  Future<void> _allow() async {
    final ok = await Notifications.requestPermission();
    ref.read(notificationsPermittedProvider.notifier).state = ok;
    final prefs = ref.read(notificationPrefsProvider);
    await _set(prefs);
  }

  String _time(TimeOfDay t) => MaterialLocalizations.of(context).formatTimeOfDay(t, alwaysUse24HourFormat: false);

  String _date(DateTime d) => MaterialLocalizations.of(context).formatMediumDate(d);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final p = ref.watch(notificationPrefsProvider);
    final permitted = ref.watch(notificationsPermittedProvider);
    final paused = p.pausedUntil != null && p.pausedUntil!.isAfter(DateTime.now());
    final pauseIndex = !paused ? 0 : (p.pausedUntil!.difference(DateTime.now()).inHours > 30 ? 2 : 1);

    return Scaffold(
      appBar: AppBar(title: Text(s.notifications, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!permitted)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                strong: true,
                child: Row(
                  children: [
                    const Icon(Icons.notifications_off_outlined, color: AppColors.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.permissionOff, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(s.permissionHelp, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.background),
                      onPressed: _allow,
                      child: Text(s.allow),
                    ),
                  ],
                ),
              ),
            ),

          // Summary: how much the user will hear from us.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Icon(paused ? Icons.pause_circle_outline_rounded : Icons.notifications_active_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paused ? s.pausedUntil(_date(p.pausedUntil!)) : s.perWeek(permitted ? p.perWeek() : 0),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _Section(title: s.wamdaNotif, children: [
            _SwitchRow(label: s.wamdaNotif, sub: s.wamdaNotifSub, value: p.wamda, onChanged: (v) => _set(p.copyWith(wamda: v))),
            if (p.wamda) ...[
              _TapRow(label: s.time, value: _time(p.wamdaTime), onTap: () => _pickTime(p.wamdaTime, (t) => _set(p.copyWith(wamdaTime: t)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.howOften, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Segmented(
                      labels: [s.daily, s.threeWeekly, s.weekly],
                      selected: p.frequency.index,
                      onChanged: (i) => _set(p.copyWith(frequency: WamdaFrequency.values[i])),
                    ),
                    if (p.frequency != WamdaFrequency.daily) ...[
                      const SizedBox(height: 8),
                      Text(p.frequency == WamdaFrequency.weekly ? s.weeklyHint : s.threeWeeklyHint,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ]),

          _Section(title: s.fridayNotif, children: [
            _SwitchRow(label: s.fridayNotif, sub: s.fridayNotifSub, value: p.friday, onChanged: (v) => _set(p.copyWith(friday: v))),
            if (p.friday)
              _TapRow(label: s.time, value: _time(p.fridayTime), onTap: () => _pickTime(p.fridayTime, (t) => _set(p.copyWith(fridayTime: t)))),
          ]),

          _Section(title: s.adhkarNotif, footer: s.adhkarNotifSub, children: [
            _SwitchRow(label: s.morningAdhkar, value: p.morning, onChanged: (v) => _set(p.copyWith(morning: v))),
            if (p.morning)
              _TapRow(label: s.time, value: _time(p.morningTime), onTap: () => _pickTime(p.morningTime, (t) => _set(p.copyWith(morningTime: t)))),
            _SwitchRow(label: s.eveningAdhkar, value: p.evening, onChanged: (v) => _set(p.copyWith(evening: v))),
            if (p.evening)
              _TapRow(label: s.time, value: _time(p.eveningTime), onTap: () => _pickTime(p.eveningTime, (t) => _set(p.copyWith(eveningTime: t)))),
          ]),

          _Section(title: s.quiet, children: [
            _SwitchRow(label: s.silent, sub: s.silentSub, value: p.silent, onChanged: (v) => _set(p.copyWith(silent: v))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.pause, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Segmented(
                    labels: [s.pauseNone, s.pauseDay, s.pauseWeek],
                    selected: pauseIndex,
                    onChanged: (i) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      switch (i) {
                        case 0:
                          _set(p.copyWith(clearPause: true));
                        case 1:
                          _set(p.copyWith(pausedUntil: today.add(const Duration(days: 1))));
                        default:
                          _set(p.copyWith(pausedUntil: today.add(const Duration(days: 7))));
                      }
                    },
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.glassBorder),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: permitted
                ? () async {
                    await Notifications.showSample(p);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.sampleSent)));
                  }
                : null,
            icon: const Icon(Icons.notifications_outlined),
            label: Text(s.tryIt),
          ),
          const SizedBox(height: 14),
          Text(s.notifPrivacy, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? footer;
  final List<Widget> children;

  const _Section({required this.title, required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
          Container(
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
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
              child: Text(footer!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.sub});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.background,
      activeTrackColor: AppColors.accent,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      subtitle: sub == null ? null : Text(sub!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TapRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent)),
          const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
