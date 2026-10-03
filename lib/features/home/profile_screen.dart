import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/user_avatar.dart';
import '../access/legal_screen.dart';
import '../shell/main_shell.dart';
import 'account_sheets.dart';
import 'certificates_screen.dart';
import 'language_sheet.dart';
import 'plans_screen.dart';
import 'profile_sheet.dart';
import 'widgets.dart';

/// B7 · Profile & Settings (tab 4 of the shell).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _remindersKey = 'home.studyReminders';

  /// Count shown on a "Learning" row, from the student's own data.
  int _learningCount(Store store, String id) {
    switch (id) {
      case 'saved':
        return store.kvSet('resources.savedWords').length;
      case 'calendar':
        final today = Store.dateKey(DateTime.now());
        return store.tasks
            .where((x) => x['done'] != true && '${x['date']}'.compareTo(today) >= 0)
            .length;
      case 'certificates':
        return earnedCertificateCount(store);
      case 'recordings':
        return practiceAttempts(store, skill: Skill.speaking)
            .where((a) => a.kind != 'pronunciation')
            .length;
      default:
        return 0;
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showAppDialog<bool>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const Text(
              'Reset my progress?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Text(
              'This clears your scores, essays, recordings, study time, schedule and saved items on this device. Your account stays.',
              style: TextStyle(fontSize: 14, height: 1.45, color: ctx.tk.textMuted),
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: OutlineButtonX(
                    label: 'Cancel',
                    height: 48,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                Expanded(
                  child: PrimaryButton(
                    label: 'Reset',
                    height: 48,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await Store.I.resetProgress();
    if (!mounted) return;
    context.toast('Progress reset');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final theme = ThemeScope.of(context);
    final store = context.store;
    final acc = store.current;
    final data = Demo.section('home').m('profile');
    final learning = data.l('learning');
    final reminders = store.kv<bool>(_remindersKey) ?? true;
    final days = acc?.daysToExam;
    final exam = acc?.examDate;
    final streak = store.streakDays;
    final identityLine = <String>[
      acc?.targetBand == null ? 'No target yet' : 'Target ${Store.formatBand(acc!.targetBand)}',
      'Academic',
    ].join(' · ');
    final contactLine = <String>[
      acc?.phoneMasked ?? '',
      '${currentPlanName(store)} plan',
    ].where((x) => x.isNotEmpty).join(' · ');
    final examLine = exam == null
        ? 'Exam date not set'
        : 'Exam ${Store.weekdayDate(exam)}${days != null && days >= 0 ? ' · $days days left' : ''}';

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, MainShell.navClearance),
      gap: 13,
      children: [
        Row(
          children: [
            const Spacer(),
            IconBox(
              icon: AppIcons.bell,
              tooltip: 'Notifications',
              size: 56,
              radius: 20,
              iconSize: 22,
              dot: store.unreadNotifications > 0,
              onTap: () => context.push(Routes.notifications),
            ),
          ],
        ),
        const Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.6,
          ),
        ),

        // Identity card
        AppCard(
          radius: 30,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                spacing: 14,
                children: [
                  Semantics(
                    button: true,
                    label: 'Change profile photo',
                    child: GestureDetector(
                      onTap: () => showAvatarSheet(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(size: 72),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: t.surface, width: 2),
                              ),
                              child: Icon(
                                AppIcons.camera,
                                size: 13,
                                color: t.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          acc?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 24),
                        ),
                        Text(
                          identityLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: t.textMuted),
                        ),
                        Text(
                          contactLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                        Text(
                          examLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: t.surfaceAlt2,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showEditProfileSheet(context),
                      child: SizedBox(
                        width: 48,
                        height: 64,
                        child: Icon(AppIcons.pen, size: 20, color: t.text),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _StatPill(
                      icon: AppIcons.trendUp,
                      title: 'Study time',
                      value: studyTimeLabel(store.totalMinutes),
                      bg: t.isNight
                          ? const Color(0xFF1E3A3A)
                          : t.alert.withValues(alpha: 0.12),
                      fg: t.isNight ? const Color(0xFF7FD1C7) : t.alert,
                      onTap: () => context.push(Routes.analytics),
                    ),
                  ),
                  Expanded(
                    child: _StatPill(
                      icon: AppIcons.fire,
                      title: 'Streak',
                      value: streak == 1 ? '1 day' : '$streak days',
                      bg: t.isNight
                          ? const Color(0xFF3A2418)
                          : t.alert.withValues(alpha: 0.12),
                      fg: t.isNight ? const Color(0xFFF2A14A) : t.textMuted,
                      onTap: () => context.push(Routes.notifications),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        _SectionLabel('Learning'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            for (final row in learning)
              _SettingRow(
                icon: homeIconFor(row.s('icon')),
                title: row.s('title'),
                trailingText: _learningCount(store, row.s('id')) > 0
                    ? '${_learningCount(store, row.s('id'))}'
                    : null,
                onTap: () => openHomeTarget(context, row.s('target')),
              ),
          ],
        ),

        _SectionLabel('Account'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            _SettingRow(
              icon: AppIcons.star,
              title: 'Plan',
              subtitle: currentPlanName(store) == 'Pro'
                  ? 'You’re on Pro'
                  : 'Compare Free and Pro',
              trailingText: currentPlanName(store),
              onTap: () => context.push(Routes.plans),
            ),
            _SettingRow(
              icon: AppIcons.lock,
              title: 'Change password',
              onTap: () => showChangePasswordSheet(context),
            ),
          ],
        ),

        _SectionLabel('App settings'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            _SettingRow(
              icon: AppIcons.moon,
              title: 'Appearance',
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              trailing: _AppearanceToggle(
                night: theme.isNight,
                onChanged: theme.setNight,
              ),
            ),
            _SettingRow(
              icon: AppIcons.bell,
              title: 'Study reminders',
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
              onTap: () => Store.I.setKv(_remindersKey, !reminders),
              trailing: PillSwitch(
                value: reminders,
                onChanged: (v) => Store.I.setKv(_remindersKey, v),
              ),
            ),
            _SettingRow(
              icon: AppIcons.translate,
              title: 'Explanation language',
              trailingText: contentLang(FeedbackLanguage.current).native,
              onTap: () => showLanguageSheet(context),
            ),
            _SettingRow(
              icon: AppIcons.doc,
              title: 'Terms of use',
              onTap: () => openLegal(context, 'terms'),
            ),
            _SettingRow(
              icon: AppIcons.shield,
              title: 'Privacy policy',
              onTap: () => openLegal(context, 'privacy'),
            ),
            _SettingRow(
              icon: AppIcons.refresh,
              title: 'Reset my progress',
              subtitle: acc?.isDemo == true
                  ? 'Restore the demo history'
                  : 'Start again from a blank account',
              onTap: _confirmReset,
            ),
            _SettingRow(
              icon: AppIcons.logout,
              title: 'Log out',
              danger: true,
              showChevron: false,
              onTap: () async {
                await Store.I.signOut();
                if (context.mounted) context.resetTo(Routes.login);
              },
            ),
            _SettingRow(
              icon: AppIcons.delete,
              title: 'Delete account',
              subtitle: 'Permanently remove your account and data',
              danger: true,
              onTap: () => showDeleteAccountDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: context.tk.textMuted),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.title,
    required this.value,
    required this.bg,
    required this.fg,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceAlt2,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            spacing: 10,
            children: [
              TintCircle(icon: icon, bg: bg, fg: fg, size: 36, iconSize: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final iconColor =
        danger ? t.dangerText : (t.isNight ? t.text : t.textMuted);
    return AppCard(
      radius: 20,
      height: 56,
      padding: padding,
      onTap: onTap,
      child: Row(
        spacing: 14,
        children: [
          Icon(icon, size: 22, color: iconColor),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: subtitle == null ? null : 1.15,
                    color: danger ? t.dangerText : t.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
              ],
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          if (trailing != null)
            trailing!
          else if (showChevron)
            Icon(AppIcons.chevronRight, size: 20, color: iconColor),
        ],
      ),
    );
  }
}

class _AppearanceToggle extends StatelessWidget {
  const _AppearanceToggle({required this.night, required this.onChanged});

  final bool night;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget seg(String label, bool active, bool value) {
      return Material(
        color: active ? t.primary : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(value),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: active ? t.onPrimary : t.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Appearance',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: t.surfaceAlt2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('Light', !night, false),
            seg('Dark', night, true),
          ],
        ),
      ),
    );
  }
}
