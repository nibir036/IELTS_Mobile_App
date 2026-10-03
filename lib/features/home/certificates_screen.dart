import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
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
    for (final d in defs) _evaluate(d, chron, target),
  ];
}

/// Number of certificates the signed-in student has earned.
int earnedCertificateCount(Store store) =>
    evaluateCertificates(store).where((c) => c.earned).length;

CertStatus _evaluate(
  Map<String, dynamic> def,
  List<Attempt> chron,
  double target,
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
      return _streak(def, rule, chron);
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

CertStatus _streak(Map<String, dynamic> def, Map<String, dynamic> rule, List<Attempt> chron) {
  final goal = rule.i('goal') < 1 ? 1 : rule.i('goal');
  final days = chron.map((a) => DateUtils.dateOnly(a.createdAt)).toSet().toList()..sort();
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

/// "IA-FM-20260921-3K9Q" — stable per account + certificate.
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
    default:
      return '';
  }
}

/// Profile › Learning › Certificates.
class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final all = evaluateCertificates(store);
    final earned = all.where((c) => c.earned).toList()
      ..sort((a, b) => b.earnedAt!.compareTo(a.earnedAt!));
    final locked = all.where((c) => !c.earned).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final intro = Demo.section('home').m('certificates').s('intro');

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'Certificates',
          subtitle: '${earned.length} of ${all.length} earned',
        ),
        HeroCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    '${earned.length}',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w500,
                      height: 1,
                      letterSpacing: -1,
                      color: t.heroText,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'of ${all.length} milestones unlocked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: t.heroMuted),
                      ),
                    ),
                  ),
                  Icon(AppIcons.medal, size: 28, color: t.heroText),
                ],
              ),
              ProgressBar(
                value: all.isEmpty ? 0.0 : earned.length / all.length,
                height: 6,
                onHero: true,
              ),
              Text(
                intro,
                style: TextStyle(fontSize: 13, height: 1.4, color: t.heroMuted),
              ),
            ],
          ),
        ),
        if (earned.isEmpty)
          EmptyState(
            title: 'No certificates yet',
            message:
                'Finish your first practice test or mock to start unlocking milestones. Your progress on each one is shown below.',
            icon: AppIcons.medal,
            actionLabel: 'Take a mock test',
            onAction: () => context.push(Routes.mockLibrary),
          )
        else ...[
          const SectionTitle('Earned', fontSize: 16),
          for (final c in earned)
            _EarnedCard(status: c, onTap: () => showCertificateSheet(context, c)),
        ],
        if (locked.isNotEmpty) const SectionTitle('Locked', fontSize: 16),
        for (final c in locked) _LockedCard(status: c),
      ],
    );
  }
}

class _EarnedCard extends StatelessWidget {
  const _EarnedCard({required this.status, required this.onTap});

  final CertStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        spacing: 12,
        children: [
          IconCircle(
            _certIcon(status.def.s('icon')),
            size: 44,
            bg: t.accentSoft,
            fg: t.text,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  status.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Earned ${_longDate(status.earnedAt!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          const Tag('View', tone: TagTone.primary),
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.status});

  final CertStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final route = _practiceRoute(status);
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: route.isEmpty ? null : () => context.push(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              IconCircle(
                _certIcon(status.def.s('icon')),
                size: 44,
                fg: t.textMuted,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      status.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      status.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.lock, size: 18, color: t.textMuted),
            ],
          ),
          ProgressBar(value: status.progress, height: 6),
          Text(
            status.progressLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }
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
      'Certificate of achievement — IELTS AI by nextED',
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
                        color: kInk,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'IA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: t.isNight ? t.primary : t.accentStrong,
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
                    Icon(_certIcon(status.def.s('icon')), size: 28, color: t.heroText),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'CERTIFICATE OF ACHIEVEMENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: t.heroMuted,
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
            'A practice milestone from IELTS AI by nextED — not an official IELTS result.',
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
