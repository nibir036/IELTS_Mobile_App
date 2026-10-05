import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/lessons.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import 'widgets.dart';

/// One milestone certificate evaluated against the student's attempts.
class CertStatus {
  CertStatus({
    required this.def,
    required this.earned,
    required this.progress,
    required this.progressLabel,
    this.earnedAt,
    this.detail = '',
  });

  /// Definition row from home.json › certificates.items.
  final Map<String, dynamic> def;
  final bool earned;
  final DateTime? earnedAt;

  /// 0..1 toward the milestone.
  final double progress;

  /// "3 of 10 essays", "Best 6.5 of 7.0" …
  final String progressLabel;

  /// Extra line for the certificate (e.g. "Band 7.5").
  final String detail;

  String get id => def.s('id');
  String get title => def.s('title');
  String get description => def.s('description');
}

/// Evaluates every certificate in home.json › certificates.items.
List<CertStatus> evaluateCertificates(Store store) {
  final defs = Demo.section('home').m('certificates').l('items');
  final chron = store.attemptsFor().toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final target = store.current?.targetBand ?? 7.0;
  return <CertStatus>[
    for (final d in defs) _evaluate(d, chron, target, store),
  ];
}

/// Number of certificates the signed-in student has earned.
int earnedCertificateCount(Store store) =>
    evaluateCertificates(store).where((c) => c.earned).length;

CertStatus _evaluate(
  Map<String, dynamic> def,
  List<Attempt> chron,
  double target,
  Store store,
) {
  final rule = def.m('rule');
  final type = rule.s('type');
  switch (type) {
    case 'count':
      return _count(def, rule, chron);
    case 'mockOverall':
      return _mockOverall(def, rule, chron);
    case 'skillTarget':
      return _skillTarget(def, rule, chron, target);
    case 'streak':
      return _streak(def, rule, chron, Lessons.days(store));
    case 'lessons':
      return _lessons(def, rule, store);
    case 'xp':
      return _xp(def, rule, store);
    case 'stage':
    case 'course':
      return _courseStage(def, rule, store);
    case 'listeningParts':
      return _listeningParts(def, rule, chron);
    default:
      return CertStatus(def: def, earned: false, progress: 0, progressLabel: '');
  }
}

CertStatus _count(Map<String, dynamic> def, Map<String, dynamic> rule, List<Attempt> chron) {
  final skill = rule.s('skill');
  final kinds = rule.ls('kinds');
  final goal = rule.i('goal') < 1 ? 1 : rule.i('goal');
  final list = chron
      .where((a) => a.skill == skill && (kinds.isEmpty || kinds.contains(a.kind)))
      .toList();
  final n = list.length;
  final shown = n > goal ? goal : n;
  final unit = def.s('unit');
  return CertStatus(
    def: def,
    earned: n >= goal,
    earnedAt: n >= goal ? list[goal - 1].createdAt : null,
    progress: (shown / goal).clamp(0.0, 1.0).toDouble(),
    progressLabel: '$shown of $goal${unit.isEmpty ? '' : ' $unit'}',
  );
}

double? _mockBand(Attempt a) {
  if (a.band != null) return a.band;
  final o = a.data['overall'];
  return o is num ? o.toDouble() : null;
}

CertStatus _mockOverall(Map<String, dynamic> def, Map<String, dynamic> rule, List<Attempt> chron) {
  final need = rule.d('band');
  double? best;
  DateTime? at;
  double? atBand;
  for (final a in chron) {
    if (a.skill != Skill.mock) continue;
    final b = _mockBand(a);
    if (b == null) continue;
    if (best == null || b > best) best = b;
    if (at == null && b >= need) {
      at = a.createdAt;
      atBand = b;
    }
  }
  return CertStatus(
    def: def,
    earned: at != null,
    earnedAt: at,
    progress: best == null || need <= 0 ? 0.0 : (best / need).clamp(0.0, 1.0).toDouble(),
    progressLabel: best == null
        ? 'No mock test yet · need ${Store.formatBand(need)}'
        : 'Best ${Store.formatBand(best)} of ${Store.formatBand(need)}',
    detail: atBand == null ? '' : 'Overall Band ${Store.formatBand(atBand)}',
  );
}

double? _bandFor(Attempt a, String skill) {
  if (a.skill == skill) return a.band;
  if (a.skill == Skill.mock) {
    final s = a.data['sections'];
    if (s is Map && s[skill] is num) return (s[skill] as num).toDouble();
  }
  return null;
}

CertStatus _skillTarget(
  Map<String, dynamic> def,
  Map<String, dynamic> rule,
  List<Attempt> chron,
  double target,
) {
  final skill = rule.s('skill');
  double? best;
  DateTime? at;
  double? atBand;
  for (final a in chron) {
    final b = _bandFor(a, skill);
    if (b == null) continue;
    if (best == null || b > best) best = b;
    if (at == null && b >= target) {
      at = a.createdAt;
      atBand = b;
    }
  }
  final tgt = Store.formatBand(target);
  return CertStatus(
    def: def,
    earned: at != null,
    earnedAt: at,
    progress: best == null ? 0.0 : (best / target).clamp(0.0, 1.0).toDouble(),
    progressLabel: best == null
        ? 'Not practised yet · target $tgt'
        : 'Best ${Store.formatBand(best)} of target $tgt',
    detail: atBand == null ? '' : '${Skill.label(skill)} Band ${Store.formatBand(atBand)}',
  );
}

/// Lessons finished (any course, or `module`).
CertStatus _lessons(Map<String, dynamic> def, Map<String, dynamic> rule, Store store) {
  final goal = rule.i('goal') < 1 ? 1 : rule.i('goal');
  final module = rule.s('module');
  final n = Lessons.doneCount(store, module: module.isEmpty ? null : module);
  final times = Lessons.completions(store);
  final shown = n > goal ? goal : n;
  return CertStatus(
    def: def,
    earned: n >= goal,
    earnedAt: n >= goal && times.length >= goal ? times[goal - 1] : null,
    progress: (shown / goal).clamp(0.0, 1.0).toDouble(),
    progressLabel: '$shown of $goal lessons',
  );
}

/// Total lesson XP.
CertStatus _xp(Map<String, dynamic> def, Map<String, dynamic> rule, Store store) {
  final goal = rule.i('goal') < 1 ? 1 : rule.i('goal');
  final n = Lessons.xp(store);
  final times = Lessons.completions(store);
  return CertStatus(
    def: def,
    earned: n >= goal,
    earnedAt: n >= goal && times.isNotEmpty ? times.last : null,
    progress: (n / goal).clamp(0.0, 1.0).toDouble(),
    progressLabel: '${n > goal ? goal : n} of $goal XP',
  );
}

/// Every lesson of a course stage (`stage`) or of the whole course.
CertStatus _courseStage(Map<String, dynamic> def, Map<String, dynamic> rule, Store store) {
  final module = rule.s('module').isEmpty ? 'writing' : rule.s('module');
  final stageId = rule.s('stage');
  final lessons = stageId.isEmpty
      ? Lessons.all(module)
      : <Map<String, dynamic>>[
          for (final st in Lessons.stages(module))
            if (st.s('id') == stageId) ...st.l('lessons'),
        ];
  final goal = lessons.isEmpty ? 1 : lessons.length;
  final n = lessons.where((l) => Lessons.isDone(store, l.s('id'))).length;
  final earned = lessons.isNotEmpty && n == goal;
  final times = Lessons.completions(store);
  return CertStatus(
    def: def,
    earned: earned,
    earnedAt: earned && times.isNotEmpty ? times.last : null,
    progress: (n / goal).clamp(0.0, 1.0).toDouble(),
    progressLabel: '$n of $goal lessons',
  );
}

CertStatus _streak(Map<String, dynamic> def, Map<String, dynamic> rule, List<Attempt> chron, Set<DateTime> lessonDays) {
  final goal = rule.i('goal') < 1 ? 1 : rule.i('goal');
  final days = <DateTime>{...chron.map((a) => DateUtils.dateOnly(a.createdAt)), ...lessonDays}.toList()..sort();
  var run = 0;
  var longest = 0;
  DateTime? prev;
  DateTime? at;
  for (final d in days) {
    if (prev != null &&
        DateUtils.isSameDay(DateTime(prev.year, prev.month, prev.day + 1), d)) {
      run++;
    } else {
      run = 1;
    }
    prev = d;
    if (run > longest) longest = run;
    if (at == null && run >= goal) at = d;
  }
  final shown = longest > goal ? goal : longest;
  return CertStatus(
    def: def,
    earned: at != null,
    earnedAt: at,
    progress: (shown / goal).clamp(0.0, 1.0).toDouble(),
    progressLabel: 'Best run $shown of $goal days',
    detail: at == null ? '' : 'Longest streak $longest days',
  );
}

CertStatus _listeningParts(Map<String, dynamic> def, Map<String, dynamic> rule, List<Attempt> chron) {
  final goal = rule.i('goal') < 1 ? 4 : rule.i('goal');
  final parts = <int>{};
  DateTime? at;
  for (final a in chron) {
    if (a.skill == Skill.listening && a.kind == 'mini') {
      final p = Content.listeningSet(a.refId).i('part');
      if (p >= 1 && p <= 4) parts.add(p);
    } else if ((a.skill == Skill.listening && a.kind == 'test') || a.skill == Skill.mock) {
      parts.addAll(const <int>[1, 2, 3, 4]);
    }
    if (at == null && parts.length >= goal) at = a.createdAt;
  }
  final shown = parts.length > goal ? goal : parts.length;
  return CertStatus(
    def: def,
    earned: at != null,
    earnedAt: at,
    progress: (shown / goal).clamp(0.0, 1.0).toDouble(),
    progressLabel: '$shown of $goal parts',
    detail: at == null ? '' : 'Parts 1–4 completed',
  );
}

/// "IA-FM-20260921-3K9Q"- stable per account + certificate.
String certificateId(String accountId, CertStatus c) {
  var h = 7;
  for (final u in '$accountId:${c.id}'.codeUnits) {
    h = (h * 31 + u) & 0xFFFFFF;
  }
  final d = c.earnedAt ?? DateTime.now();
  final date = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  final code = c.def.s('code').isEmpty ? 'C' : c.def.s('code');
  final hash = h.toRadixString(36).toUpperCase().padLeft(4, '0');
  return 'IA-$code-$date-${hash.substring(hash.length - 4)}';
}

String _longDate(DateTime d) => '${d.day} ${Store.monthShort(d.month)} ${d.year}';

IconData _certIcon(String key) {
  switch (key) {
    case 'mock':
      return AppIcons.mock;
    case 'trophy':
      return AppIcons.trophy;
    case 'listening':
      return AppIcons.listening;
    case 'reading':
      return AppIcons.reading;
    case 'writing':
      return AppIcons.writing;
    case 'speaking':
      return AppIcons.speaking;
    case 'pen':
      return AppIcons.pen;
    case 'mic':
      return AppIcons.mic;
    case 'fire':
      return AppIcons.fire;
    case 'headphones':
      return AppIcons.headsetMic;
    case 'school':
      return AppIcons.school;
    case 'check':
      return AppIcons.check;
    case 'layers':
      return AppIcons.layers;
    case 'star':
      return AppIcons.star;
    case 'bolt':
      return AppIcons.bolt;
    default:
      return AppIcons.medal;
  }
}

/// Where to practise for a locked certificate ('' = nowhere specific).
String _practiceRoute(CertStatus c) {
  final rule = c.def.m('rule');
  switch (rule.s('type')) {
    case 'mockOverall':
      return Routes.mockLibrary;
    case 'count':
    case 'skillTarget':
      final skill = rule.s('skill');
      return skill == Skill.mock ? Routes.mockLibrary : skillLandingRoute(skill);
    case 'listeningParts':
      return Routes.listeningMiniList;
    case 'lessons':
    case 'xp':
    case 'stage':
    case 'course':
      return Routes.course;
    default:
      return '';
  }
}

/// Profile › Learning › Milestones: badges grouped by Learning, Practice,
/// Streaks and Scores. Earned badges open their certificate; locked ones
/// show progress and lead to where you earn them.
class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  static const _groups = <String>['Learning', 'Practice', 'Streaks', 'Scores'];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final all = evaluateCertificates(store);
    final earned = all.where((c) => c.earned).length;
    final intro = Demo.section('home').m('certificates').s('intro');
    final groups = <String, List<CertStatus>>{};
    for (final c in all) {
      final g = c.def.s('group').isEmpty ? 'Practice' : c.def.s('group');
      groups.putIfAbsent(g, () => <CertStatus>[]).add(c);
    }
    final order = <String>[
      ..._groups.where(groups.containsKey),
      ...groups.keys.where((g) => !_groups.contains(g)),
    ];

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'Milestones',
          subtitle: '$earned of ${all.length} badges earned',
        ),
        HeroCard(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 6,
                      children: [
                        Text(
                          '$earned',
                          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w600, height: 1, color: t.heroText),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('/ ${all.length} badges', style: TextStyle(fontSize: 14, color: t.heroMuted)),
                        ),
                      ],
                    ),
                    ProgressBar(value: all.isEmpty ? 0.0 : earned / all.length, height: 6, onHero: true),
                    Text(intro, style: TextStyle(fontSize: 12.5, height: 1.4, color: t.heroMuted)),
                    Row(
                      spacing: 14,
                      children: [
                        _HeroStat(icon: AppIcons.star, text: '${Lessons.xp(store)} XP'),
                        _HeroStat(icon: AppIcons.fire, text: '${store.streakDays}-day streak'),
                      ],
                    ),
                  ],
                ),
              ),
              const Nexi(NexiPose.grad, height: 112),
            ],
          ),
        ),
        for (final g in order) ...[
          SectionTitle(g, fontSize: 16),
          _BadgeGrid(items: groups[g]!),
        ],
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: 16, color: t.peach),
        Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.heroText)),
      ],
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.items});

  final List<CertStatus> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final cols = box.maxWidth > 520 ? 4 : 3;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in items) SizedBox(width: w, child: _Badge(status: c)),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status});

  final CertStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final on = status.earned;
    final route = _practiceRoute(status);
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      onTap: on
          ? () => showCertificateSheet(context, status)
          : () => _lockedSheet(context, status, route),
      child: Column(
        spacing: 8,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!on)
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: status.progress,
                      strokeWidth: 3.5,
                      backgroundColor: t.track,
                      color: t.peach,
                    ),
                  ),
                Container(
                  width: on ? 62 : 50,
                  height: on ? 62 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: on
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFC9B8), Color(0xFFFF8F7A), Color(0xFF8DA6FF)],
                          )
                        : null,
                    color: on ? null : t.surfaceAlt,
                    boxShadow: on
                        ? [BoxShadow(color: const Color(0xFFFF8F7A).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]
                        : null,
                  ),
                  child: Icon(
                    _certIcon(status.def.s('icon')),
                    size: on ? 28 : 22,
                    color: on ? const Color(0xFF151515) : t.textFaint,
                  ),
                ),
                if (!on)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: t.sheet, shape: BoxShape.circle),
                      child: Icon(AppIcons.lock, size: 12, color: t.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            status.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w600, color: on ? t.text : t.textSoft),
          ),
          Text(
            on ? (status.earnedAt == null ? 'Earned' : _longDate(status.earnedAt!)) : status.progressLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, height: 1.25, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A locked badge: what it takes, progress, and where to earn it.
Future<void> _lockedSheet(BuildContext context, CertStatus c, String route) {
  return showAppSheet<void>(
    context,
    Builder(
      builder: (context) {
        final t = context.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                IconCircle(_certIcon(c.def.s('icon')), size: 48, fg: t.textMuted),
                Expanded(
                  child: Text(c.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(c.description, style: TextStyle(fontSize: 14, height: 1.45, color: t.textSoft)),
            ProgressBar(value: c.progress, height: 8),
            Text(c.progressLabel, style: TextStyle(fontSize: 12.5, color: t.textMuted)),
            if (route.isNotEmpty)
              PrimaryButton(
                label: 'Work on it',
                trailing: AppIcons.forward,
                height: 52,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(route);
                },
              ),
          ],
        );
      },
    ),
  );
}

/// Certificate view with Share.
Future<void> showCertificateSheet(BuildContext context, CertStatus c) {
  return showAppSheet<void>(context, _CertificateSheet(status: c));
}

class _CertificateSheet extends StatelessWidget {
  const _CertificateSheet({required this.status});

  final CertStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final acc = Store.I.current;
    final name = acc?.name ?? 'Student';
    final date = status.earnedAt == null ? '' : _longDate(status.earnedAt!);
    final certId = certificateId(acc?.id ?? 'guest', status);
    final shareText = <String>[
      'Certificate of achievement - IELTS AI by nextED',
      '$name earned "${status.title}".',
      status.description,
      if (status.detail.isNotEmpty) status.detail,
      'Awarded $date · Certificate ID $certId',
    ].join('\n');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox(height: 4),
          HeroCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: kPeachGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'IA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: kOnPeach,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'IELTS AI',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.heroText,
                            ),
                          ),
                          Text(
                            'by nextED',
                            style: TextStyle(fontSize: 12, color: t.heroMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(_certIcon(status.def.s('icon')), size: 28, color: t.peach),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'CERTIFICATE OF ACHIEVEMENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: t.peach,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This certifies that',
                  style: TextStyle(fontSize: 13, color: t.heroMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.6,
                    height: 1.15,
                    color: t.heroText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'has earned',
                  style: TextStyle(fontSize: 13, color: t.heroMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  status.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: t.heroText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.detail.isEmpty
                      ? status.description
                      : '${status.description} ${status.detail}.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: t.heroText),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: t.heroDivider),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: _CertField(label: 'Date', value: date),
                    ),
                    Expanded(
                      flex: 2,
                      child: _CertField(label: 'Certificate ID', value: certId),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            'A practice milestone from IELTS AI by nextED - not an official IELTS result.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          PrimaryButton(
            label: 'Share',
            leading: AppIcons.share,
            onTap: () => ShareService.shareText(
              context,
              shareText,
              subject: 'IELTS AI certificate · ${status.title}',
            ),
          ),
          OutlineButtonX(
            label: 'Close',
            height: 50,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _CertField extends StatelessWidget {
  const _CertField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: t.heroMuted)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: t.heroText,
          ),
        ),
      ],
    );
  }
}
