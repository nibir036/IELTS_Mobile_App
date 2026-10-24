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
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import 'nexted_apply.dart';
import 'widgets.dart';

/// nexted.app · AI scholarship finder.
///
/// Same shape as course matching, plus an eligibility verdict per scholarship:
/// Eligible, Borderline or Not Eligible, with one or two reasons (GPA, IELTS
/// band, nationality, level). The verdict is a plain rules comparison against
/// the scholarship's stored criteria - the AI explains it, it does not invent
/// the rule.
class NextedScholarshipsScreen extends StatefulWidget {
  const NextedScholarshipsScreen({super.key});

  @override
  State<NextedScholarshipsScreen> createState() => _NextedScholarshipsScreenState();
}

class _NextedScholarshipsScreenState extends State<NextedScholarshipsScreen> {
  final TextEditingController _query = TextEditingController();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _busy = false;
  bool _searched = false;
  bool _catalogueEmpty = false;
  /// Set when the search had to widen to find anything.
  String _searchNote = '';

  /// The one profile change that would unlock the most scholarships
  /// ({field, message, unlocks}), when the AI service found one.
  Map<String, dynamic> _gap = <String, dynamic>{};
  String? _error;

  /// Required profile fields still empty. The finder stays locked until
  /// this is empty (the server refuses too - this just says it nicely first).
  List<String> _missing = const <String>[];
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    NextedUsage.I.refresh();
    _checkProfile();
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

  Future<void> _find() async {
    if (_busy || _checking) return;
    if (_missing.isNotEmpty) return;
    if (!NextedApi.ready) {
      context.toast('Connect the study-abroad server to find scholarships.');
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
      final r = await NextedApi.post(NextedConfig.scholarshipMatch, <String, dynamic>{
        if (_query.text.trim().isNotEmpty) 'query': _query.text.trim(),
      });
      NextedUsage.I.apply(r);
      // The server's figure already includes this call; count locally only without one.
      if (r['usage'] is! Map) NextedUsage.I.countOne();
      if (!mounted) return;
      setState(() {
        _items = r.l('scholarships').isNotEmpty ? r.l('scholarships') : r.l('items');
        _catalogueEmpty = r.b('catalogueEmpty');
        _searchNote = r.s('searchNote');
        _gap = r.m('gap');
        _busy = false;
        _searched = true;
      });
      // Scholarships are in: a nudge to raise the IELTS band they ask for.
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
    final eligible = _items.where((s) => s.s('verdict').toLowerCase() == 'eligible').length;

    if (_missing.isNotEmpty) {
      return AppScreen(
        gap: 13,
        children: [
          TopBar(title: 'Scholarship finder', subtitle: 'With an eligibility verdict', onBack: () => context.back()),
          NextedProfileGate(
            missing: _missing,
            feature: 'scholarships',
            // Back from the profile: check again, and unlock if it is done.
            onBack: _checkProfile,
          ),
        ],
      );
    }

    return AppScreen(
      gap: 13,
      footer: PrimaryButton(
        label: _busy ? 'Checking…' : 'Find scholarships for me',
        leading: AppIcons.medal,
        enabled: !_busy && !_checking,
        onTap: _find,
      ),
      children: [
        TopBar(
          title: 'Scholarship finder',
          subtitle: 'With an eligibility verdict',
          onBack: () => context.back(),
        ),

        if (!NextedConfig.hasApi) const NextedOfflineNotice(),
        const NextedQuotaBar(),

        AppTextField(
          hint: 'Country, subject or provider (optional)',
          controller: _query,
          prefixIcon: AppIcons.search,
        ),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t check scholarships',
            message: _error,
            icon: AppIcons.medal,
            actionLabel: 'Try again',
            onAction: () {
              setState(() => _error = null);
              _find();
            },
          )
        else if (_busy)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (!_searched)
          const EmptyState(
            title: 'See what you qualify for',
            message: 'Each scholarship is checked against your GPA, IELTS band, '
                'nationality and level, and comes back Eligible, Borderline or Not eligible.',
            icon: AppIcons.medal,
          )
        else if (_items.isEmpty)
          EmptyState(
            title: _catalogueEmpty ? 'No scholarships loaded yet' : 'No matching scholarships yet',
            // The AI says why (e.g. "We could not find Masters Microbiology
            // courses in UK yet ..."), which beats a generic message.
            message: _searchNote.isNotEmpty
                ? _searchNote
                : 'Try another country or a related subject, or check that your profile '
                    'shows the subject and level you want.',
            icon: AppIcons.medal,
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
          if (_gap.s('message').isNotEmpty)
            AppCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                spacing: 12,
                children: [
                  const FloatY(amplitude: 3, child: Nexi(NexiPose.point, height: 64)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 3,
                      children: [
                        const Text(
                          'Nexi’s tip',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _gap.s('message'),
                          style: TextStyle(fontSize: 13, height: 1.4, color: t.textSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SectionTitle(
            '${_items.length} checked',
            fontSize: 15,
            subtitle: eligible > 0 ? '$eligible you qualify for' : null,
          ),
          for (final s in _items) _ScholarshipCard(item: s),
          Text(
            'The verdict compares your profile with the criteria each provider has set. '
            'Your counsellor confirms before you apply.',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: t.textMuted),
          ),
        ],
      ],
    );
  }
}

class _ScholarshipCard extends StatelessWidget {
  const _ScholarshipCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final verdict = item.s('verdict');
    final notEligible = verdict.toLowerCase().replaceAll('_', ' ') == 'not eligible';
    final reasons = item.ls('reasons');
    final provider = <String>[item.s('provider'), item.s('country')]
        .where((x) => x.isNotEmpty)
        .join(' · ');
    final amount = item.s('amount');
    final deadline = item.s('deadline');

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      item.s('title').isEmpty ? 'Scholarship' : item.s('title'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
                    ),
                    if (provider.isNotEmpty)
                      Text(provider, style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                  ],
                ),
              ),
              NextedVerdictTag(verdict),
            ],
          ),
          if (amount.isNotEmpty || deadline.isNotEmpty)
            Text(
              <String>[
                if (amount.isNotEmpty) amount,
                if (deadline.isNotEmpty) 'Deadline $deadline',
              ].join(' · '),
              style: TextStyle(fontSize: 12.5, color: t.textSoft),
            ),
          NextedSourceRow(
            label: item.s('sourceLabel'),
            url: item.s('officialUrl'),
            note: item.s('deadlineNote').isNotEmpty ? item.s('deadlineNote') : item.s('amountNote'),
          ),
          if (reasons.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                for (final r in reasons.take(3))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r,
                          style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textSoft),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          Row(
            children: [
              const Spacer(),
              SoftButton(
                label: notEligible ? 'Apply anyway' : 'Apply',
                height: 38,
                onTap: () => nextedApply(
                  context,
                  type: 'scholarship',
                  refId: item.s('id'),
                  title: item.s('title'),
                  provider: provider,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
