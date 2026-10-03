import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/speak_button.dart';
import '../../app/widgets/user_avatar.dart';
import '../shell/main_shell.dart';
import 'dashboard_empty_screen.dart';
import 'profile_sheet.dart';
import 'widgets.dart';

/// B1 · Main Student Dashboard (tab 0 of the shell).
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
    final scored = store.attempts.where((a) => a.band != null).take(5).toList();
    const skills = Skill.core;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, MainShell.navClearance),
      gap: 14,
      children: [
        _header(context, store, acc),
        _hero(context, store, acc),
        _studyTime(context, store),
        for (var r = 0; r < skills.length; r += 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Expanded(child: _SkillCard(skill: skills[r])),
              Expanded(
                child: r + 1 < skills.length
                    ? _SkillCard(skill: skills[r + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        _wordOfDay(context, store, _shortPos(ResBank.wordOfTheDay(dash.m('wordOfTheDay')))),
        _recentScores(context, context.tk, scored),
      ],
    );
  }

  Widget _header(BuildContext context, Store store, Account? acc) {
    final t = context.tk;
    return Row(
      spacing: 12,
      children: [
        UserAvatar(size: 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Store.greeting(),
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
              Text(
                acc?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
        IconBox(
          icon: AppIcons.search,
          tooltip: 'Search',
          size: 48,
          radius: 18,
          onTap: () => context.push(Routes.search),
        ),
        IconBox(
          icon: AppIcons.bell,
          tooltip: 'Notifications',
          size: 48,
          radius: 18,
          dot: store.unreadNotifications > 0,
          onTap: () => context.push(Routes.notifications),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, Store store, Account? acc) {
    final t = context.tk;
    final est = store.estimatedBand;
    final days = acc?.daysToExam;
    final resume = store.kv<Map>('resume');
    final resumeLabel = resume == null ? '' : '${resume['label'] ?? ''}';
    final resumeRoute = resume == null ? '' : '${resume['route'] ?? ''}';
    final resumeArgs = resume != null && resume['args'] is Map
        ? (resume['args'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final hasResume = resumeLabel.isNotEmpty && resumeRoute.isNotEmpty;

    return HeroCard(
      padding: const EdgeInsets.all(18),
      radius: 32,
      child: Row(
        spacing: 16,
        children: [
          RingProgress(
            value: est == null ? 0 : est / 9,
            size: 116,
            stroke: 10,
            onHero: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Store.formatBand(est),
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w400,
                    height: 1,
                    letterSpacing: -1,
                    color: t.heroText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Est. band',
                  style: TextStyle(fontSize: 11, color: t.heroMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                InkWell(
                  onTap: () => showEditProfileSheet(context),
                  child: KeyValueRow(
                    'Target',
                    acc?.targetBand == null ? 'Set' : Store.formatBand(acc!.targetBand),
                    labelColor: t.heroMuted,
                  ),
                ),
                InkWell(
                  onTap: () => showEditProfileSheet(context),
                  child: days == null
                      ? KeyValueRow('Exam in', 'Set exam date', labelColor: t.heroMuted)
                      : KeyValueRow(
                          'Exam in',
                          days < 0 ? 'Done' : (days == 1 ? '1 day' : '$days days'),
                          labelColor: t.heroMuted,
                        ),
                ),
                Hairline(color: t.heroDivider),
                InkWell(
                  onTap: () {
                    if (hasResume) {
                      openStoredRoute(context, resumeRoute, resumeArgs);
                    } else {
                      MainShell.of(context)?.select(1);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasResume ? resumeLabel : 'Start practising',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                      ),
                      Icon(AppIcons.forward, size: 18, color: t.heroText),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyTime(BuildContext context, Store store) {
    final t = context.tk;
    final week = store.weekMinutes();
    final total = week.fold<int>(0, (a, b) => a + b);
    final hm = Store.hoursMinutes(total);
    final hrs = hm.$1.toString().padLeft(2, '0');
    final mins = hm.$2.toString().padLeft(2, '0');
    final today = DateTime.now().weekday - 1;
    return AppCard(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      onTap: () => context.push(Routes.analytics),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
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
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 22, color: t.text),
                        children: [
                          TextSpan(
                            text: hrs,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: ' hr '),
                          TextSpan(
                            text: mins,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: ' mins'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SoftButton(
                label: 'This week',
                trailing: AppIcons.chevronDown,
                height: 36,
                fontSize: 13,
                bg: t.surfaceAlt2,
                onTap: () => context.push(Routes.analytics),
              ),
            ],
          ),
          MiniBars(
            height: 92,
            values: [for (final m in week) m.toDouble()],
            labels: [for (var i = 1; i <= 7; i++) Store.weekdayShort(i)],
            highlight: today,
          ),
        ],
      ),
    );
  }

  /// The dashboard card uses the short part of speech ("adj.").
  static Map<String, dynamic> _shortPos(Map<String, dynamic> w) =>
      w.s('partOfSpeechShort').isEmpty ? w : <String, dynamic>{...w, 'partOfSpeech': w.s('partOfSpeechShort')};

  Widget _wordOfDay(BuildContext context, Store store, Map<String, dynamic> w) {
    final t = context.tk;
    final saved = store.kvSetHas('resources.savedWords', w.s('id'));
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            children: [
              const Tag('Word of the day', tone: TagTone.primary),
              const Spacer(),
              SpeakButton(
                text: w.s('word'),
                size: 36,
                radius: 12,
                iconSize: 18,
                bg: t.surfaceAlt2,
              ),
              const SizedBox(width: 6),
              IconBox(
                icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                tooltip: 'Save word',
                size: 36,
                radius: 12,
                iconSize: 18,
                bg: t.surfaceAlt2,
                fg: t.iconAccent,
                onTap: () {
                  Store.I.kvSetToggle('resources.savedWords', w.s('id'));
                  context.toast(
                    saved ? 'Removed from your vault' : 'Saved to your vault',
                  );
                },
              ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${w.s('word')} ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.5,
                    color: t.text,
                  ),
                ),
                TextSpan(
                  text: w.s('partOfSpeech'),
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${w.s('definition')} “${w.s('example')}”',
            style: TextStyle(fontSize: 13, height: 1.45, color: t.textSoft),
          ),
        ],
      ),
    );
  }

  Widget _recentScores(
    BuildContext context,
    AppTokens t,
    List<Attempt> scores,
  ) {
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text(
                    'Recent scores',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  scores.isEmpty ? 'band est.' : 'Last ${scores.length} · band est.',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          if (scores.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
              child: Text(
                'No band scores yet. Finish a test to see it here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
            ),
          for (final a in scores)
            ListRow(
              divider: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              leading: LetterBadge(Skill.letter(a.skill)),
              title: a.title,
              subtitle: '${Skill.label(a.skill)} · ${Store.relativeDay(a.createdAt)}',
              trailing: Text(
                Store.formatBand(a.band),
                style: const TextStyle(fontSize: 16),
              ),
              onTap: () => openAttempt(context, a),
            ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});

  final String skill;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.all(14),
      onTap: () => openStoredRoute(context, skillLandingRoute(skill)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconCircle(homeIconFor(skill), size: 40),
              const Spacer(),
              Text(
                Store.formatBand(store.skillBand(skill)),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
              ),
            ],
          ),
          Text(
            Skill.label(skill),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          ProgressBar(value: store.skillProgress(skill)),
        ],
      ),
    );
  }
}
