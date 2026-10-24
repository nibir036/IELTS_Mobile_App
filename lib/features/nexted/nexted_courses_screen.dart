import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/cross_nudge.dart';
import '../../app/widgets/kit.dart';
import 'nexted_apply.dart';
import 'widgets.dart';

/// nexted.app · AI course matching and search.
///
/// Profile in, ranked course list out, each with a confidence score and a
/// tuition disclaimer. The catalogue lives in the shared backend and the web
/// platform's match logic is reused - the mobile module only calls it.
class NextedCoursesScreen extends StatefulWidget {
  const NextedCoursesScreen({super.key});

  @override
  State<NextedCoursesScreen> createState() => _NextedCoursesScreenState();
}

class _NextedCoursesScreenState extends State<NextedCoursesScreen> {
  final TextEditingController _query = TextEditingController();
  List<Map<String, dynamic>> _courses = <Map<String, dynamic>>[];
  bool _busy = false;
  bool _searched = false;
  bool _catalogueEmpty = false;
  /// Set when the search had to widen to find anything, so the student is
  /// told rather than left wondering why their word is missing.
  String _searchNote = '';
  String? _error;

  /// Set while the list on screen is the saved one from the last search.
  String _savedLabel = '';

  /// Required profile fields still empty. The finder stays locked until
  /// this is empty (the server refuses too - this just says it nicely first).
  List<String> _missing = const <String>[];
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    NextedUsage.I.refresh();
    _checkProfile();
    _loadLast();
  }

  /// Opens on the student's last results (kept on the server) until they
  /// search again.
  Future<void> _loadLast() async {
    final r = await nextedLastSearch(NextedConfig.courseMatchLast);
    final saved = r.l('courses');
    if (!mounted || saved.isEmpty || _searched || _busy) return;
    setState(() {
      _courses = saved;
      _searchNote = r.s('searchNote');
      _searched = true;
      _savedLabel = nextedSavedLabel(r.s('savedAt'), r.s('query'));
      if (_query.text.isEmpty) _query.text = r.s('query');
    });
  }

  Future<void> _checkProfile() async {
    final missing = await NextedProfileRules.fetchMissing();
    if (!mounted) return;
    setState(() {
      _missing = missing;
      _checking = false;
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _match() async {
    if (_busy || _checking) return;
    if (_missing.isNotEmpty) return;
    if (!NextedApi.ready) {
      context.toast('Connect the study-abroad server to match courses.');
      return;
    }
    if (NextedUsage.I.exhausted) {
      context.toast(NextedUsage.limitMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await NextedApi.post(NextedConfig.courseMatch, <String, dynamic>{
        if (_query.text.trim().isNotEmpty) 'query': _query.text.trim(),
      });
      NextedUsage.I.apply(r);
      // The server's figure already includes this call; count locally only without one.
      if (r['usage'] is! Map) NextedUsage.I.countOne();
      if (!mounted) return;
      setState(() {
        _courses = r.l('courses').isNotEmpty ? r.l('courses') : r.l('items');
        _catalogueEmpty = r.b('catalogueEmpty');
        _searchNote = r.s('searchNote');
        _busy = false;
        _searched = true;
        _savedLabel = '';
      });
      // Matches are in: a nudge to raise the IELTS band they ask for.
      CrossNudge.toIelts(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      final missing = NextedProfileRules.fromError(e);
      if (missing != null) {
        // The profile changed somewhere else (web) or was never checked.
        setState(() {
          _busy = false;
          _missing = missing.isEmpty ? const <String>['Profile details'] : missing;
        });
        return;
      }
      setState(() {
        _busy = false;
        _searched = true;
        _error = NextedUsage.isLimit(e) ? NextedUsage.limitMessage : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    if (_missing.isNotEmpty) {
      return AppScreen(
        gap: 13,
        children: [
          TopBar(title: 'Course matching', subtitle: 'Ranked for your profile', onBack: () => context.back()),
          NextedProfileGate(
            missing: _missing,
            feature: 'courses',
            // Back from the profile: check again, and unlock if it is done.
            onBack: _checkProfile,
          ),
        ],
      );
    }

    return AppScreen(
      gap: 13,
      footer: PrimaryButton(
        label: _busy ? 'Matching…' : 'Match courses to my profile',
        leading: AppIcons.sparkle,
        enabled: !_busy && !_checking,
        onTap: _match,
      ),
      children: [
        TopBar(
          title: 'Course matching',
          subtitle: 'Ranked for your profile',
          onBack: () => context.back(),
        ),

        if (!NextedConfig.hasApi) const NextedOfflineNotice(),
        const NextedQuotaBar(),

        AppTextField(
          hint: 'Narrow it down - subject, country, budget (optional)',
          controller: _query,
          prefixIcon: AppIcons.search,
        ),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t match courses',
            message: _error,
            icon: AppIcons.school,
            actionLabel: 'Try again',
            onAction: () {
              setState(() => _error = null);
              _match();
            },
          )
        else if (_busy)
          const NextedMatchingWait(scholarships: false)
        else if (!_searched)
          const EmptyState(
            title: 'Find courses that fit you',
            message: 'Your profile - level, result, IELTS band and where you want to '
                'study - decides the ranking. Add a subject or country above to narrow it.',
            icon: AppIcons.school,
          )
        else if (_courses.isEmpty)
          EmptyState(
            title: _catalogueEmpty ? 'No courses loaded yet' : 'No matching courses yet',
            // The AI says why (e.g. "We could not find Masters Microbiology
            // courses in UK yet ..."), which beats a generic message.
            message: _searchNote.isNotEmpty
                ? _searchNote
                : 'Try another country or a related subject, or check that your profile '
                    'shows the subject and level you want.',
            icon: AppIcons.school,
            actionLabel: 'Edit my profile',
            onAction: () async {
              await context.push(Routes.nextedProfile);
              if (mounted) _checkProfile();
            },
          )
        else ...[
          if (_searchNote.isNotEmpty)
            AppCard(
              radius: 20,
              color: t.surfaceAlt,
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Icon(AppIcons.info, size: 18, color: t.textMuted),
                  Expanded(
                    child: Text(
                      _searchNote,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textSoft),
                    ),
                  ),
                ],
              ),
            ),
          if (_savedLabel.isNotEmpty)
            Row(
              spacing: 8,
              children: [
                Icon(AppIcons.history, size: 16, color: t.textMuted),
                Expanded(
                  child: Text(_savedLabel, style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted)),
                ),
              ],
            ),
          SectionTitle('${_courses.length} matches', fontSize: 15),
          for (final c in _courses) _CourseCard(course: c),
          Text(
            'Tuition figures are indicative and set by the institution. Your counsellor '
            'confirms the exact fee before you pay anything.',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: t.textMuted),
          ),
        ],
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final score = course.d('confidence') > 1 ? course.d('confidence') / 100 : course.d('confidence');
    final university = course.s('university');
    final country = course.s('country');
    final tuition = course.s('tuition');
    final duration = course.s('duration');
    final intake = course.s('intake');
    final why = course.s('why');
    // Decided on the server from NextED's partner rules, never by the AI.
    final restriction = course.m('restriction');
    final blocked = restriction.s('status') == 'closed';
    final uncertain = restriction.s('status') == 'check';
    final line = <String>[university, country].where((x) => x.isNotEmpty).join(' · ');
    final facts = <String>[
      if (duration.isNotEmpty) duration,
      if (intake.isNotEmpty) intake,
      if (tuition.isNotEmpty) tuition,
    ].join(' · ');

    return AppCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              IconCircle(AppIcons.school, size: 42, iconSize: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      course.s('title').isEmpty ? 'Course' : course.s('title'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
                    ),
                    if (line.isNotEmpty)
                      Text(line, style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (score > 0) ...[
            Row(
              spacing: 10,
              children: [
                Expanded(child: ProgressBar(value: score, height: 5)),
                Text(
                  '${(score * 100).round()}% match',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ],
          if (facts.isNotEmpty)
            Text(facts, style: TextStyle(fontSize: 12.5, color: t.textSoft)),
          if (why.isNotEmpty) NextedAnswer(why),
          // From the AI service: where these facts came from, and a "check"
          // note when a figure may have changed since it was read.
          NextedSourceRow(
            label: course.s('sourceLabel'),
            url: course.s('officialUrl'),
            note: course.s('tuitionNote').isNotEmpty ? course.s('tuitionNote') : course.s('deadlineNote'),
          ),

          // A restricted course is shown with its reason rather than dropped
          // from the list. A student who cannot find the university they had
          // in mind assumes the app is broken; told why, they have an answer -
          // and a counsellor to take it to.
          if (blocked || uncertain)
            AppCard(
              radius: 18,
              color: blocked ? t.dangerSoft : t.surfaceAlt,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Icon(
                    blocked ? AppIcons.info : AppIcons.help,
                    size: 18,
                    color: blocked ? t.dangerText : t.textMuted,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 3,
                      children: [
                        Text(
                          restriction.s('message'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: blocked ? t.dangerText : t.textSoft,
                          ),
                        ),
                        if (restriction.s('detail').isNotEmpty)
                          Text(
                            restriction.s('detail'),
                            style: TextStyle(fontSize: 11, height: 1.35, color: t.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              const Spacer(),
              SoftButton(
                // Applying to something that is closed wastes a student's
                // time and a counsellor's; the honest move is to offer the
                // conversation instead.
                label: blocked ? 'Ask a counsellor' : 'Apply',
                height: 38,
                onTap: () => nextedApply(
                  context,
                  type: 'course',
                  refId: course.s('id'),
                  title: course.s('title'),
                  provider: line,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
