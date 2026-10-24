import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/cross_promo.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/vivid.dart';
import 'widgets.dart';
import '../../app/widgets/app_tour.dart';

/// nexted.app · module home.
///
/// The app-inside-an-app: reached from its own button in the IELTS app,
/// running on the same shell with the same login. This phase carries the
/// student profile and documents (build order steps 1-2); the AI counsellor,
/// course match, scholarship finder and Apply arrive in the next phase.
class NextedHubScreen extends StatefulWidget {
  const NextedHubScreen({super.key});

  @override
  State<NextedHubScreen> createState() => _NextedHubScreenState();
}

class _NextedHubScreenState extends State<NextedHubScreen> {
  Map<String, dynamic> _profile = <String, dynamic>{};
  int _documents = 0;
  int _applications = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    NextedUsage.I.refresh();
  }

  Future<void> _load() async {
    if (!NextedApi.ready) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    try {
      final results = await Future.wait<Map<String, dynamic>>(<Future<Map<String, dynamic>>>[
        NextedApi.get(NextedConfig.profile),
        NextedApi.get(NextedConfig.documents),
        NextedApi.get(NextedConfig.applications),
      ]);
      if (!mounted) return;
      final profile = results[0].m('profile');
      setState(() {
        _profile = profile.isEmpty ? results[0] : profile;
        _documents = results[1].l('documents').length + results[1].l('items').length;
        _applications = results[2].l('applications').length + results[2].l('items').length;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// How complete the profile is, so the student knows what to finish first.
  (int, int) get _completeness {
    // The same fields the AI finders need (NextedProfileRules), so "complete"
    // here means Course matching and the Scholarship finder will open.
    final fields = NextedProfileRules.required.map((f) => f.$1).toList();
    final done = fields.where((f) => _profile.s(f).trim().isNotEmpty).length;
    return (done, fields.length);
  }

  /// Opens a module screen and reloads the counts when the student comes back.
  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _load();
  }

  static const List<(String, String)> _destinations = <(String, String)>[
    ('🇬🇧', 'UK'),
    ('🇺🇸', 'USA'),
    ('🇨🇦', 'Canada'),
    ('🇦🇺', 'Australia'),
    ('🇩🇪', 'Germany'),
    ('🇮🇪', 'Ireland'),
    ('🇳🇿', 'New Zealand'),
    ('🇲🇾', 'Malaysia'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final acc = Store.I.current;
    final name = _profile.s('fullName').isNotEmpty ? _profile.s('fullName') : (acc?.name ?? '');
    final first = name.trim().isEmpty ? '' : name.trim().split(' ').first;
    final (done, total) = _completeness;
    final live = NextedApi.ready && !_loading;
    final profileDone = live && total > 0 && done >= total;
    final step1Done = profileDone && _documents > 0;
    final step3Started = live && _applications > 0;

    // Home tab of the study-abroad shell (nexted_shell.dart), which holds
    // the bottom nav, the "IELTS AI" pill and the phone's back button.
    return AppScreen(
      gap: 18,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        _header(context, t, first),
        TourTarget(id: 'abroad.hero', child: _hero(context, t, first, done, total, live, profileDone)),

        if (!NextedConfig.hasApi) const NextedOfflineNotice(),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t load your file',
            message: _error,
            icon: AppIcons.cloudOff,
            actionLabel: 'Try again',
            onAction: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _load();
            },
          ),

        // The journey as a quiet three-step timeline: the order reads off the
        // screen, and each step lists just what's in it.
        const SectionHeader('Your journey', subtitle: 'Three steps from here to campus'),
        _JourneyStep(
          number: 1,
          title: 'Tell us about you',
          pose: NexiPose.writing,
          done: step1Done,
          active: !step1Done,
          children: [
            _StepItem(
              icon: AppIcons.person,
              title: 'Student profile',
              subtitle: 'Everything else is matched against this',
              trailing: live ? '$done/$total' : null,
              onTap: () => _open(Routes.nextedProfile),
            ),
            _StepItem(
              icon: AppIcons.doc,
              title: 'Documents',
              subtitle: 'Upload once – your counsellor uses the same copies',
              trailing: live && _documents > 0 ? '$_documents' : null,
              onTap: () => _open(Routes.nextedDocuments),
            ),
          ],
        ),
        TourTarget(
          id: 'abroad.match',
          child: _JourneyStep(
          number: 2,
          title: 'Find where you fit',
          pose: NexiPose.point,
          done: step3Started,
          active: step1Done && !step3Started,
          footer: const NextedQuotaBar(),
          children: [
            _StepItem(
              icon: AppIcons.brain,
              title: 'AI Counsellor',
              subtitle: 'Countries, costs, visas – it knows your profile',
              onTap: () => context.push(Routes.nextedCounsellor),
            ),
            _StepItem(
              icon: AppIcons.school,
              title: 'Course matching',
              subtitle: 'Ranked for you, with a score and the reason',
              onTap: () => context.push(Routes.nextedCourses),
            ),
            _StepItem(
              icon: AppIcons.medal,
              title: 'Scholarships',
              subtitle: 'Eligible, borderline or not – and why',
              onTap: () => context.push(Routes.nextedScholarships),
            ),
          ],
        ),
        ),
        _JourneyStep(
          number: 3,
          title: 'Apply and follow it',
          pose: NexiPose.thumbs,
          done: false,
          active: step3Started,
          last: true,
          children: [
            _StepItem(
              icon: AppIcons.taskDone,
              title: 'Applications',
              subtitle: 'Twelve steps from submitted to enrolled',
              trailing: live && _applications > 0 ? '$_applications' : null,
              onTap: () => _open(Routes.nextedApplications),
            ),
          ],
        ),

        const SectionHeader('Popular destinations'),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _destinations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (flag, label) = _destinations[i];
              return PopIn(
                delayMs: 50 * i.clamp(0, 6),
                from: 0.85,
                child: _Destination(
                  flag: flag,
                  label: label,
                  onTap: () => context.push(Routes.nextedCourses),
                ),
              );
            },
          ),
        ),

        // Back across to IELTS practice.
        const IeltsPromo(),

        Text(
          'Your NextED counsellor works on your applications from the web platform. '
          'Everything you add here reaches them straight away.',
          style: TextStyle(fontSize: 12, height: 1.45, color: t.textMuted),
        ),
        // Room under the last line so the pill never covers it.
        const SizedBox(height: 64),
      ],
    );
  }

  Widget _header(BuildContext context, AppTokens t, String first) {
    return Row(
      spacing: 10,
      children: [
        // Back goes to the start screen, not into the IELTS app.
        IconBox(
          icon: AppIcons.back,
          tooltip: 'Back',
          iconSize: 18,
          onTap: () => context.resetTo(Routes.chooser),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Study abroad',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
              Text(
                first.isEmpty ? 'Your journey' : first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4),
              ),
            ],
          ),
        ),
        WiggleOnChange(
          trigger: Store.I.unreadIn('nexted'),
          child: IconBox(
            icon: AppIcons.bell,
            tooltip: 'Notifications',
            size: 46,
            radius: 16,
            dot: Store.I.unreadIn('nexted') > 0,
            onTap: () => context.push(Routes.notifications, args: {'scope': 'nexted'}),
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, AppTokens t, String first, int done, int total, bool live, bool profileDone) {
    final pct = total == 0 ? 0.0 : done * 100 / total;
    return Stack(
      children: [
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Text(
                          first.isEmpty ? 'Your future starts here' : 'Your future starts here, $first',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w700, color: t.heroText),
                        ),
                        Text(
                          live
                              ? 'Finish your profile and we’ll match you with courses and scholarships.'
                              : 'Profile, matches, scholarships and applications – in order.',
                          maxLines: 3,
                          style: TextStyle(fontSize: 13, height: 1.4, color: t.heroMuted),
                        ),
                      ],
                    ),
                  ),
                  const FloatY(amplitude: 4, child: Nexi(NexiPose.grad, height: 104)),
                ],
              ),
              if (live) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text('Profile ready', style: TextStyle(fontSize: 12.5, color: t.heroMuted)),
                    ),
                    CountUp(
                      value: pct,
                      format: (v) => '${v.round()}%',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.heroText),
                    ),
                  ],
                ),
                ProgressBar(value: total == 0 ? 0 : done / total, height: 6, onHero: true),
              ],
              PrimaryButton(
                label: profileDone ? 'Ask the AI counsellor' : 'Complete my profile',
                trailing: AppIcons.forward,
                height: 48,
                fontSize: 14.5,
                onTap: () => profileDone ? context.push(Routes.nextedCounsellor) : _open(Routes.nextedProfile),
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
}

/// One step of the journey timeline: a numbered dot (filled when done,
/// ringed when it's the current step), a line down to the next step, and the
/// step's items in one card.
class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.number,
    required this.title,
    required this.children,
    this.done = false,
    this.active = false,
    this.last = false,
    this.footer,
    this.pose,
  });

  /// Nexi shown beside the title while this is the current step.
  final NexiPose? pose;

  final int number;
  final String title;
  final List<Widget> children;
  final bool done;
  final bool active;
  final bool last;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? t.primary : (active ? t.surface : t.surfaceAlt),
        border: Border.all(color: done || active ? t.primary : t.border, width: 2),
      ),
      child: done
          ? Icon(AppIcons.check, size: 16, color: t.onPrimary)
          : Text(
              '$number',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? t.text : t.textMuted),
            ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Column(
            children: [
              if (active) PulseRing(child: dot) else dot,
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: done ? t.primary : t.border,
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: t.text),
                          ),
                        ),
                      ),
                      // Nexi walks along with the student: he stands on the
                      // step they're on now.
                      if (active && pose != null)
                        PopIn(
                          from: 0.7,
                          child: FloatY(amplitude: 3, child: Nexi(pose!, height: 58)),
                        ),
                    ],
                  ),
                  AppCard(
                    radius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) const Padding(padding: EdgeInsets.only(left: 60), child: Hairline()),
                          children[i],
                        ],
                      ],
                    ),
                  ),
                  ?footer,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row inside a journey step: soft icon, title, one line, count or chevron.
class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Pressable(
      scale: 0.98,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            spacing: 12,
            children: [
              VividIcon(icon, size: 38, iconSize: 19, radius: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 1,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.3, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textSoft)),
              Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A destination: the flag on a soft circle and the country name.
class _Destination extends StatelessWidget {
  const _Destination({required this.flag, required this.label, required this.onTap});

  final String flag;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: 'Courses in $label',
      child: Pressable(
        scale: 0.92,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 70,
            child: Column(
              spacing: 6,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.surfaceAlt, shape: BoxShape.circle),
                  child: Text(flag, style: const TextStyle(fontSize: 26)),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.textSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
