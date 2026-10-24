import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import 'nexted_shell.dart';
import '../../app/widgets/app_tour.dart';

/// Study abroad · Guidance: the whole road from deciding to flying, eight
/// steps in the order they happen. Each step opens to say what it involves,
/// how long it usually takes and the one thing to do in the app.
class NextedJourneyScreen extends StatefulWidget {
  const NextedJourneyScreen({super.key, this.embedded = false});

  /// A tab of the study-abroad shell: no back arrow, room for the bottom nav.
  final bool embedded;

  @override
  State<NextedJourneyScreen> createState() => _NextedJourneyScreenState();
}

/// One step: icon, title, one-line summary, what it involves, how long, and
/// an optional action.
class _Step {
  const _Step(this.icon, this.title, this.summary, this.points, this.timing, [this.action, this.go]);

  final IconData icon;
  final String title;
  final String summary;
  final List<String> points;
  final String timing;
  final String? action;
  final _Go? go;
}

/// Where a step's button goes.
enum _Go { profile, ielts, counsellor, scholarships, documents, applications }

class _NextedJourneyScreenState extends State<NextedJourneyScreen> {
  static const List<_Step> _steps = <_Step>[
    _Step(
      AppIcons.target,
      'Decide what you want',
      'Country, subject and level - before anything else',
      <String>[
        'Pick the level first: Foundation, Diploma, Bachelor’s, Master’s or PhD.',
        'Then the subject - the one your results and your plans actually support.',
        'Then two or three countries, not one. Costs, work rights and visa rules differ a lot.',
      ],
      'Start 12 to 18 months before you want to begin.',
      'Fill in my profile',
      _Go.profile,
    ),
    _Step(
      AppIcons.school,
      'Sit IELTS',
      'Almost every country and university asks for it',
      <String>[
        'Find the band your course asks for - overall and for each skill.',
        'Practise until your mock band is there, then book the test.',
        'Results come in a few days. If one skill is short, you can retake just that one at many centres.',
      ],
      'Allow 2 to 3 months of practice before your test date.',
      'Practise IELTS',
      _Go.ielts,
    ),
    _Step(
      AppIcons.person,
      'Talk to a counsellor',
      'What a shortlist is, and why you cannot build one alone',
      <String>[
        'A shortlist is 4 to 6 universities: a couple you can reach, a couple that are a stretch, one safe choice.',
        'Which universities accept your board, your result and your district changes every intake - your counsellor knows the current rules.',
        'Your counsellor also checks the deadlines and the scholarships that fit you.',
      ],
      'One or two sessions, as soon as you know your country and level.',
      'Ask what to do next',
      _Go.counsellor,
    ),
    _Step(
      AppIcons.wallet,
      'Work out the money',
      'Tuition is only one of four things you pay for',
      <String>[
        'Tuition - set by the university, usually paid in part before the visa.',
        'Living costs - most visas ask you to show them in a bank account for a set time.',
        'Visa and health fees, and your flight.',
        'Scholarships and waivers can cut the first one - check them before you apply, not after.',
      ],
      'Plan this before you apply: bank statements often need months of history.',
      'Find scholarships',
      _Go.scholarships,
    ),
    _Step(
      AppIcons.doc,
      'Get your papers together',
      'The slowest step, and the only one you can start today',
      <String>[
        'Passport - valid well beyond your course end date.',
        'SSC, HSC and degree transcripts and certificates.',
        'IELTS result, CV, and your statement of purpose.',
        'Reference letters from teachers or employers.',
      ],
      'Start now - attested copies and references take weeks.',
      'Upload documents',
      _Go.documents,
    ),
    _Step(
      AppIcons.checkCircleOutline,
      'Apply, and wait',
      'From submitted to an unconditional offer',
      <String>[
        'Your counsellor submits the applications with you.',
        'A conditional offer means "yes, if" - usually your final results or your IELTS band.',
        'Send what the conditions ask for, then the offer becomes unconditional.',
        'Accept one offer and pay the deposit the university asks for.',
      ],
      'Usually 2 to 8 weeks per university for a decision.',
      'My applications',
      _Go.applications,
    ),
    _Step(
      AppIcons.visa,
      'The visa',
      'A separate process, with its own rules and its own refusals',
      <String>[
        'The university sends the letter your visa needs (CAS, CoE, I-20 or similar).',
        'You show the funds, your documents and sometimes attend an interview.',
        'A refusal is often about the money or the reason for study - prepare both carefully.',
      ],
      'Apply as soon as you have the letter - processing times vary by country.',
      'Ask about the visa',
      _Go.counsellor,
    ),
    _Step(
      AppIcons.flight,
      'Before you fly',
      'The last four weeks',
      <String>[
        'Book your flight and your first accommodation.',
        'Carry your passport, visa, offer letter and key documents in your hand luggage.',
        'Arrange some money for the first weeks and register with the university when you arrive.',
      ],
      'The last month before your course starts.',
    ),
  ];

  final Set<int> _open = <int>{};

  void _go(_Go go) {
    final shell = NextedShell.of(context);
    switch (go) {
      case _Go.profile:
        shell != null ? shell.select(NextedShell.profileTab) : context.push(Routes.nextedProfile);
      case _Go.documents:
        shell != null ? shell.select(NextedShell.documentsTab) : context.push(Routes.nextedDocuments);
      case _Go.ielts:
        context.resetTo(Routes.home);
      case _Go.counsellor:
        context.push(Routes.nextedCounsellor);
      case _Go.scholarships:
        context.push(Routes.nextedScholarships);
      case _Go.applications:
        context.push(Routes.nextedApplications);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppScreen(
      gap: 0,
      padding: EdgeInsets.fromLTRB(20, 12, 20, widget.embedded ? 112 : 24),
      children: [
        if (!widget.embedded) TopBar(title: 'Guidance', onBack: () => context.back()),
        if (widget.embedded) ...[
          const Text('Guidance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('Everything, in the order it happens', style: TextStyle(fontSize: 15, color: t.textMuted)),
        ],
        const SizedBox(height: 16),
        _hero(t),
        const SizedBox(height: 18),
        for (var i = 0; i < _steps.length; i++)
          PopIn(delayMs: 40 * i, child: TourTarget(id: i == 0 ? 'guidance.first' : null, child: _stepRow(t, i))),
        const SizedBox(height: 18),
        AppCard(
          radius: 24,
          color: t.surfaceAlt,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                'Where you are on this road depends on your profile, your band and your '
                'papers. A nextED counsellor reads all three and tells you the next thing '
                'to do - not the whole list again.',
                style: TextStyle(fontSize: 15, height: 1.5, color: t.textSoft),
              ),
              PrimaryButton(
                label: 'Ask what to do next',
                trailing: AppIcons.forward,
                onTap: () => context.push(Routes.nextedCounsellor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Timings are typical, not promised - a university or a visa office can take longer. '
          'Your counsellor gives the real dates for the country and intake you choose.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: t.textMuted),
        ),
      ],
    );
  }

  Widget _hero(AppTokens t) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: t.heroGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                Text(
                  'From deciding to flying',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: t.heroText),
                ),
                Text(
                  'Eight steps, in the order they happen',
                  style: TextStyle(fontSize: 14, color: t.heroMuted),
                ),
              ],
            ),
          ),
          const FloatY(child: Nexi(NexiPose.point, height: 118)),
        ],
      ),
    );
  }

  /// Number and line on the left, the step's card on the right.
  Widget _stepRow(AppTokens t, int i) {
    final s = _steps[i];
    final open = _open.contains(i);
    final last = i == _steps.length - 1;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 6), color: t.border),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: AppCard(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(s.icon, size: 20, color: t.isNight ? t.iconAccent : t.warning),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                Text(s.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                                Text(s.summary, style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textSoft)),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: open ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(AppIcons.chevronDown, size: 22, color: t.textMuted),
                          ),
                        ],
                      ),
                      if (open) ...[
                        const SizedBox(height: 12),
                        for (final p in s.points)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle),
                                  ),
                                ),
                                Expanded(
                                  child: Text(p, style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textSoft)),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 30, top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Icon(AppIcons.clock, size: 15, color: t.textMuted),
                              Expanded(
                                child: Text(
                                  s.timing,
                                  style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (s.action != null && s.go != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, top: 12),
                            child: SoftButton(
                              label: s.action!,
                              trailing: AppIcons.chevronRight,
                              height: 38,
                              onTap: () => _go(s.go!),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
