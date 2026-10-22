import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/cross_promo.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/speak_button.dart';
import '../../app/widgets/user_avatar.dart';
import '../../app/widgets/vivid.dart';
import '../plan/plan_widgets.dart';
import '../shell/main_shell.dart';
import 'dashboard_empty_screen.dart';
import 'profile_sheet.dart';
import 'signature_tools.dart';
import 'widgets.dart';

/// B1 · Main Student Dashboard (tab 0 of the shell).
///
/// Calm and clear, in the style of the big ride and food apps: a greeting,
/// one dark hero with the estimated band (the only place Nexi appears),
/// today's plan, a quiet link to Study abroad, our tools, and
/// the weekly and recent details. Mostly neutral surfaces; colour is used
/// only as a soft hint on icons.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    if (!store.hasActivity) {
      return const FirstTimeDashboard(bottomPadding: MainShell.navClearance);
    }
    final acc = store.current;
    final dash = Demo.section('home').m('dashboard');
    final scored = store.attempts.where((a) => a.band != null).take(8).toList();

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, MainShell.navClearance),
      gap: 18,
      children: [
        _header(context, store, acc),
        _hero(context, store),
        const TodayPlanCard(),
        // The way across to the study-abroad side.
        const StudyAbroadPromo(),
        // Our own tools: always one tap away.
        const SignatureTools(),
        _studyTime(context, store),
        _wordOfDay(context, store, _shortPos(ResBank.wordOfTheDay(dash.m('wordOfTheDay')))),
        SectionHeader(
          'Recent scores',
          action: 'Insights',
          onAction: () => context.push(Routes.analytics),
        ),
        _recentScores(context, scored),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, Store store, Account? acc) {
    final t = context.tk;
    final unread = store.unreadIn('ielts');
    return Row(
      spacing: 12,
      children: [
        // Same as the Profile tab in the nav bar.
        Semantics(
          button: true,
          label: 'Profile and settings',
          child: Pressable(
            scale: 0.92,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => MainShell.of(context)?.select(4),
              child: const UserAvatar(size: 46),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Store.greeting(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
              Text(
                acc?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4),
              ),
            ],
          ),
        ),
        // Straight across to the study-abroad side (only for students who
        // have access to it).
        AnimatedBuilder(
          animation: NextedAccess.I,
          builder: (context, _) => NextedAccess.I.enabled
              ? IconBox(
                  icon: AppIcons.flight,
                  tooltip: 'Study abroad',
                  size: 46,
                  radius: 16,
                  onTap: () => context.resetTo(Routes.nexted),
                )
              : const SizedBox.shrink(),
        ),
        WiggleOnChange(
          trigger: unread,
          child: IconBox(
            icon: unread > 0 ? AppIcons.bellActive : AppIcons.bell,
            tooltip: 'Notifications',
            size: 46,
            radius: 16,
            dot: unread > 0,
            onTap: () => context.push(Routes.notifications, args: {'scope': 'ielts'}),
          ),
        ),
      ],
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, Store store) {
    final t = context.tk;
    final acc = store.current;
    final est = store.estimatedBand;
    final target = acc?.targetBand;
    final days = acc?.daysToExam;
    final streak = store.streakDays;
    final resume = store.kv<Map>('resume');
    final resumeLabel = resume == null ? '' : '${resume['label'] ?? ''}';
    final resumeRoute = resume == null ? '' : '${resume['route'] ?? ''}';
    final resumeArgs = resume != null && resume['args'] is Map
        ? (resume['args'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final hasResume = resumeLabel.isNotEmpty && resumeRoute.isNotEmpty;
    final gap = est != null && target != null ? target - est : null;

    return Stack(
      children: [
        HeroCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Text(
                          'Estimated band',
                          style: TextStyle(fontSize: 13, color: t.heroMuted),
                        ),
                        if (est == null)
                          Text('–', style: _bandStyle(t))
                        else
                          CountUp(value: est, format: (v) => v.toStringAsFixed(1), style: _bandStyle(t)),
                        Text(
                          gap == null
                              ? 'Finish a test to get your estimate'
                              : (gap <= 0 ? 'You’re at your target' : '${gap.toStringAsFixed(1)} to your target'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: t.heroMuted),
                        ),
                      ],
                    ),
                  ),
                  const FloatY(amplitude: 4, child: Nexi(NexiPose.wave, height: 104)),
                ],
              ),
              ProgressBar(value: est == null ? 0 : est / 9, height: 6, onHero: true),
              // Target · exam countdown · streak, as one quiet line of facts.
              Row(
                children: [
                  _HeroFact(
                    label: 'Target',
                    value: target == null ? 'Set' : Store.formatBand(target),
                    onTap: () => showEditProfileSheet(context),
                  ),
                  _HeroFact(
                    label: 'Exam in',
                    value: days == null ? 'Set' : (days < 0 ? 'Done' : (days == 1 ? '1 day' : '$days days')),
                    onTap: () => showEditProfileSheet(context),
                  ),
                  _HeroFact(
                    label: 'Streak',
                    value: streak == 1 ? '1 day' : '$streak days',
                    onTap: () => context.push(Routes.analytics),
                  ),
                ],
              ),
              PrimaryButton(
                label: hasResume ? resumeLabel : 'Start practising',
                trailing: AppIcons.forward,
                height: 48,
                fontSize: 14.5,
                onTap: () {
                  if (hasResume) {
                    openStoredRoute(context, resumeRoute, resumeArgs);
                  } else {
                    MainShell.of(context)?.select(1);
                  }
                },
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: const ShineSweep(opacity: 0.06, period: Duration(milliseconds: 6000)),
          ),
        ),
      ],
    );
  }

  static TextStyle _bandStyle(AppTokens t) => TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: -1.5,
        color: t.heroText,
      );

  // ── Study time ────────────────────────────────────────────────────────────

  Widget _studyTime(BuildContext context, Store store) {
    final t = context.tk;
    final week = store.weekMinutes();
    final total = week.fold<int>(0, (a, b) => a + b);
    final today = DateTime.now().weekday - 1;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      onTap: () => context.push(Routes.analytics),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Study time this week',
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                    CountUp(
                      value: total.toDouble(),
                      format: (v) {
                        final hm = Store.hoursMinutes(v.round());
                        return '${hm.$1} hr ${hm.$2.toString().padLeft(2, '0')} min';
                      },
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: t.text),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, color: t.textMuted),
            ],
          ),
          MiniBars(
            height: 90,
            values: [for (final m in week) m.toDouble()],
            labels: [for (var i = 1; i <= 7; i++) Store.weekdayShort(i)],
            highlight: today,
          ),
        ],
      ),
    );
  }

  // ── Word of the day ───────────────────────────────────────────────────────

  /// The dashboard card uses the short part of speech ("adj.").
  static Map<String, dynamic> _shortPos(Map<String, dynamic> w) =>
      w.s('partOfSpeechShort').isEmpty ? w : <String, dynamic>{...w, 'partOfSpeech': w.s('partOfSpeechShort')};

  Widget _wordOfDay(BuildContext context, Store store, Map<String, dynamic> w) {
    final t = context.tk;
    final saved = store.kvSetHas('resources.savedWords', w.s('id'));
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  'Word of the day',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ),
              SpeakButton(text: w.s('word'), size: 36, radius: 12, iconSize: 18, bg: t.surfaceAlt),
              WiggleOnChange(
                trigger: saved,
                child: IconBox(
                  icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                  tooltip: 'Save word',
                  size: 36,
                  radius: 12,
                  iconSize: 18,
                  bg: t.surfaceAlt,
                  fg: t.iconAccent,
                  onTap: () {
                    Store.I.kvSetToggle('resources.savedWords', w.s('id'));
                    context.toast(saved ? 'Removed from your vault' : 'Saved to your vault');
                  },
                ),
              ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${w.s('word')} ',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: t.text),
                ),
                TextSpan(
                  text: w.s('partOfSpeech'),
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: t.textMuted),
                ),
              ],
            ),
          ),
          Text(
            w.s('example').isEmpty ? w.s('definition') : '${w.s('definition')} “${w.s('example')}”',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textSoft),
          ),
        ],
      ),
    );
  }

  // ── Recent scores ─────────────────────────────────────────────────────────

  Widget _recentScores(BuildContext context, List<Attempt> scores) {
    final t = context.tk;
    if (scores.isEmpty) {
      return AppCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Text(
          'No band scores yet. Finish a test and your score lands here.',
          style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textMuted),
        ),
      );
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: scores.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => PopIn(
          delayMs: 60 * i.clamp(0, 6),
          from: 0.9,
          child: _ScoreCard(attempt: scores[i]),
        ),
      ),
    );
  }
}

/// One fact on the hero (label above, value below), a third of the width.
class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, maxLines: 1, style: TextStyle(fontSize: 12, color: t.heroMuted)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.heroText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One recent score: skill icon, band, title and when.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = attempt;
    return AppCard(
      width: 152,
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: () => openAttempt(context, a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VividIcon(homeIconFor(a.skill), tone: Vivid.forKey(a.skill), size: 32, iconSize: 17, radius: 10),
              const Spacer(),
              Text(
                Store.formatBand(a.band),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text),
              ),
            ],
          ),
          const Spacer(),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            '${Skill.label(a.skill)} · ${Store.relativeDay(a.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}
