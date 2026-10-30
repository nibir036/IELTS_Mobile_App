import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/vivid.dart';

/// Tone for a document or application status.
TagTone nextedStatusTone(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
    case 'verified':
    case 'accepted':
    case 'enrolled':
      return TagTone.success;
    case 'rejected':
    case 'failed':
      return TagTone.danger;
    case 'uploading':
    case 'pending':
    case 'submitted':
    case 'under review':
    case 'awaiting review':
      return TagTone.accent;
    default:
      return TagTone.soft;
  }
}

/// A status label in the app's pill style ("Under review", "Approved" …).
class NextedStatusTag extends StatelessWidget {
  const NextedStatusTag(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final text = status.isEmpty ? 'Pending' : status;
    return Tag(text, tone: nextedStatusTone(text), height: 24, fontSize: 11.5);
  }
}

/// One tappable row of the module home: icon, title, one line of explanation.
/// [locked] draws it dimmed with a "Next phase" tag instead of a chevron, for
/// the features that are not built yet.
class NextedRow extends StatelessWidget {
  const NextedRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.locked = false,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool locked;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      // A soft drop shadow lifts each row off the page, so the list reads as
      // six things you can press rather than six paragraphs of text. Flat
      // cards on a flat background give the eye no cue that they can be
      // tapped at all.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.isNight ? 0.32 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          onTap: locked ? null : onTap,
          child: Row(
            spacing: 13,
            children: [
              // The same tile the IELTS side uses for its own tools: a filled
              // rounded square in the app's action colour. A pale outlined
              // circle reads as an illustration; this reads as a button.
              VividIcon(icon, size: 44, iconSize: 22, radius: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.3, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (locked)
                const Tag('Next phase', height: 24, fontSize: 11)
              else if (trailingText != null && trailingText!.isNotEmpty)
                Text(trailingText!, style: TextStyle(fontSize: 13, color: t.textMuted))
              else
                Icon(AppIcons.forward, size: 18, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The eligibility verdict of a scholarship: Eligible, Borderline or Not
/// Eligible. The verdict is a plain rules comparison done against the
/// scholarship's stored criteria - the AI explains it, it does not invent it.
class NextedVerdictTag extends StatelessWidget {
  const NextedVerdictTag(this.verdict, {super.key});

  final String verdict;

  @override
  Widget build(BuildContext context) {
    final v = verdict.trim().toLowerCase();
    final (String text, TagTone tone) = switch (v) {
      'eligible' => ('Eligible', TagTone.success),
      'borderline' => ('Borderline', TagTone.alert),
      'not eligible' || 'not_eligible' || 'ineligible' => ('Not eligible', TagTone.danger),
      _ => (verdict.isEmpty ? 'Unknown' : verdict, TagTone.soft),
    };
    return Tag(text, tone: tone, height: 24, fontSize: 11.5);
  }
}

/// Today's AI allowance, shown above every AI screen so the student knows
/// what is left before they start typing. The cap is enforced in the backend.
class NextedQuotaBar extends StatelessWidget {
  const NextedQuotaBar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AnimatedBuilder(
      animation: NextedUsage.I,
      builder: (context, _) {
        final u = NextedUsage.I;
        if (!u.loaded || u.unlimited) return const SizedBox.shrink();
        final left = u.left;
        final reset = u.resetsAt;
        return AppCard(
          radius: 18,
          color: u.exhausted ? t.accentSoft : t.surfaceAlt,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            spacing: 10,
            children: [
              Icon(
                u.exhausted ? AppIcons.hourglass : AppIcons.sparkle,
                size: 17,
                color: t.textMuted,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Text(
                      u.exhausted
                          ? NextedUsage.limitMessage
                          : '$left of ${u.limit} AI actions left today',
                      style: TextStyle(fontSize: 12.5, color: t.textSoft),
                    ),
                    if (!u.exhausted)
                      ProgressBar(value: u.limit == 0 ? 0 : u.used / u.limit, height: 3),
                  ],
                ),
              ),
              if (u.exhausted && reset != null)
                Text(
                  '${reset.hour.toString().padLeft(2, '0')}:${reset.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Renders the AI's CMS-style answer: `#` / `##` / `###` headings, short
/// paragraphs, `- ` / `* ` / `1. ` lists and **bold** words - never emoji-
/// numbered walls of text (25.3). Markdown the models add anyway (bold,
/// italics, code ticks, table rows) is shown cleanly instead of as symbols.
class NextedAnswer extends StatelessWidget {
  const NextedAnswer(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  static final RegExp _numbered = RegExp(r'^(\d{1,2})[.)]\s+');
  static final RegExp _rule = RegExp(r'^\s*([-*_])\s*\1\s*\1[\s\-*_]*$');
  static final RegExp _tableDivider = RegExp(r'^\s*\|?\s*:?-{2,}');

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final body = color ?? t.text;
    final base = TextStyle(fontSize: 13.5, height: 1.5, color: body);
    final lines = text.replaceAll('\r', '').split('\n');
    final blocks = <Widget>[];

    Widget heading(String s, double size) => Text.rich(
          _inline(s, TextStyle(fontSize: size, height: 1.3, fontWeight: FontWeight.w600, color: body)),
        );

    Widget bullet(Widget marker, String s) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            marker,
            Expanded(child: Text.rich(_inline(s, base.copyWith(height: 1.45)))),
          ],
        );

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty || _rule.hasMatch(trimmed) || _tableDivider.hasMatch(trimmed)) continue;

      if (trimmed.startsWith('### ')) {
        blocks.add(heading(trimmed.substring(4).trim(), 13.8));
      } else if (trimmed.startsWith('## ')) {
        blocks.add(heading(trimmed.substring(3).trim(), 14.5));
      } else if (trimmed.startsWith('# ')) {
        blocks.add(heading(trimmed.substring(2).trim(), 16.5));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('• ') || trimmed.startsWith('* ')) {
        blocks.add(bullet(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: body.withValues(alpha: 0.6), shape: BoxShape.circle),
            ),
          ),
          trimmed.substring(2).trim(),
        ));
      } else if (_numbered.hasMatch(trimmed)) {
        final m = _numbered.firstMatch(trimmed)!;
        blocks.add(bullet(
          SizedBox(
            width: 16,
            child: Text('${m.group(1)}.', style: base.copyWith(fontWeight: FontWeight.w600)),
          ),
          trimmed.substring(m.end).trim(),
        ));
      } else if (trimmed.startsWith('|')) {
        // A table row: its cells as one plain line.
        final cells = trimmed.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).join('  ·  ');
        if (cells.isNotEmpty) blocks.add(Text.rich(_inline(cells, base)));
      } else if (trimmed.startsWith('**') && trimmed.endsWith('**') && trimmed.length > 4 &&
          !trimmed.substring(2, trimmed.length - 2).contains('**')) {
        // A line that is all bold is a heading the model wrote the other way.
        blocks.add(heading(trimmed.substring(2, trimmed.length - 2).trim(), 14.5));
      } else {
        blocks.add(Text.rich(_inline(trimmed, base)));
      }
    }

    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: blocks,
    );
  }

  /// `**bold**` / `__bold__` as bold; `*italic*`, `_italic_` and `code`
  /// ticks shown as plain text. An unmatched marker is dropped, never shown.
  static TextSpan _inline(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    final bold = RegExp(r'\*\*(.+?)\*\*|__(.+?)__');
    var at = 0;
    for (final m in bold.allMatches(s)) {
      if (m.start > at) spans.add(TextSpan(text: _plain(s.substring(at, m.start))));
      spans.add(TextSpan(
        text: _plain(m.group(1) ?? m.group(2) ?? ''),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      at = m.end;
    }
    if (at < s.length) spans.add(TextSpan(text: _plain(s.substring(at))));
    return TextSpan(style: style, children: spans);
  }

  static String _plain(String s) => s
      .replaceAll('**', '')
      .replaceAll('`', '')
      .replaceAllMapped(RegExp(r'(?<![\w*])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![\w*])'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'(?<![\w_])_(?!\s)([^_\n]+?)(?<!\s)_(?![\w_])'), (m) => m.group(1)!);
}

/// Shown on every module screen while no study-abroad server is configured,
/// so the screens stay usable instead of failing (see NextedConfig).
class NextedOfflineNotice extends StatelessWidget {
  const NextedOfflineNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 22,
      color: t.surfaceAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(AppIcons.cloudOff, size: 20, color: t.textMuted),
          Expanded(
            child: Text(
              message ??
                  'The study-abroad server isn’t connected in this build. '
                      'Screens below show what the module will look like; build with '
                      '--dart-define=NEXTED_API_BASE_URL=… to use real data.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a course or scholarship fact came from: a small label ("VERIFIED",
/// "FOUND JUST NOW", "FROM THE UNIVERSITY'S PAGE"), a "check this" note when
/// a figure may be out of date, and a link to the official page. Shows
/// nothing when there is nothing to say.
class NextedSourceRow extends StatelessWidget {
  const NextedSourceRow({super.key, this.label = '', this.url = '', this.note = ''});

  final String label;
  final String url;
  final String note;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    // Source links are web pages only (they come from research, not from us).
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t open the page')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (label.isEmpty && url.isEmpty && note.isEmpty) return const SizedBox.shrink();
    final verified = label == 'VERIFIED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (note.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Icon(AppIcons.info, size: 14, color: t.warning),
              Expanded(
                child: Text(note, style: TextStyle(fontSize: 11.5, height: 1.35, color: t.textMuted)),
              ),
            ],
          ),
        Row(
          spacing: 8,
          children: [
            if (label.isNotEmpty)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: verified ? t.successSoft : t.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(verified ? AppIcons.verified : AppIcons.link, size: 12, color: verified ? t.success : t.textMuted),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: verified ? t.success : t.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (url.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _open(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 3,
                    children: [
                      Text(
                        'Official page',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.text),
                      ),
                      Icon(AppIcons.openExternal, size: 13, color: t.text),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}


/// What the AI finders need before they can match honestly. The API server
/// checks the same list (REQUIRED_FOR_AI in server/src/routes/nexted.ts).
class NextedProfileRules {
  NextedProfileRules._();

  /// key → label, in the order the profile screen shows them.
  static const List<(String, String)> required = <(String, String)>[
    ('fullName', 'Full name'),
    ('nationality', 'Nationality'),
    ('highestLevel', 'Highest education'),
    ('result', 'Result / GPA'),
    ('ieltsBand', 'IELTS band'),
    ('studyLevel', 'Level you want to study'),
    ('subject', 'Subject you want to study'),
    ('preferredCountry', 'Preferred country'),
    ('hasPublication', 'Publications'),
  ];

  static bool isRequired(String key) => required.any((f) => f.$1 == key);

  /// Labels of the required fields still empty in [profile].
  static List<String> missing(Map<String, dynamic> profile) => <String>[
        for (final f in required)
          if (profile.s(f.$1).trim().isEmpty) f.$2,
      ];

  /// Reads the profile and returns what is missing. Empty when complete -
  /// and also when the server can't be reached, so a network blip never
  /// locks a student out (the server checks again anyway).
  static Future<List<String>> fetchMissing() async {
    if (!NextedApi.ready) return const <String>[];
    try {
      final r = await NextedApi.get(NextedConfig.profile);
      return missing(r.m('profile').isEmpty ? r : r.m('profile'));
    } on ApiException {
      return const <String>[];
    }
  }

  /// The server's "profile_incomplete" refusal, with its list of fields.
  static List<String>? fromError(ApiException e) {
    if (e.code != 'profile_incomplete') return null;
    final list = e.data['missing'];
    return list is List ? list.map((x) => '$x').toList() : const <String>[];
  }
}

/// Shown instead of a finder until the profile is complete: what is missing
/// and one button to go and fill it in. [onBack] runs when the student
/// returns from the profile screen, so the finder can check again.
class NextedProfileGate extends StatelessWidget {
  const NextedProfileGate({
    super.key,
    required this.missing,
    required this.feature,
    this.onBack,
  });

  final List<String> missing;

  /// "course matching", "scholarship finding" ...
  final String feature;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const Center(child: FloatY(amplitude: 3, child: Nexy(NexyPose.point, height: 96))),
          const Text(
            'Complete your profile first',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            'Nexy matches $feature to you - your level, result, IELTS band, the subject '
            'and the country you want. Without them the results would be guesses, '
            'so please go back and finish your profile.',
            style: TextStyle(fontSize: 13, height: 1.45, color: t.textSoft),
          ),
          if (missing.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in missing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(m, style: TextStyle(fontSize: 12, color: t.textSoft)),
                  ),
              ],
            ),
          PrimaryButton(
            label: 'Complete my profile',
            leading: AppIcons.person,
            onTap: () async {
              await context.push(Routes.nextedProfile);
              onBack?.call();
            },
          ),
        ],
      ),
    );
  }
}

/// The finder's last results, as the server kept them ({} when none yet).
/// Never throws: no saved search just means the screen starts empty.
Future<Map<String, dynamic>> nextedLastSearch(String path) async {
  if (!NextedApi.ready) return <String, dynamic>{};
  try {
    return await NextedApi.get(path);
  } on ApiException {
    return <String, dynamic>{};
  }
}

/// "Your last search · 24 Oct" above results that came from the saved search.
String nextedSavedLabel(String savedAtIso, String query) {
  final at = DateTime.tryParse(savedAtIso)?.toLocal();
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final when = at == null ? '' : ' · ${at.day} ${months[at.month - 1]}';
  final what = query.trim().isEmpty ? 'matched to your profile' : '"${query.trim()}"';
  return 'Your last search$when - $what. Search again to refresh it.';
}

/// What the student sees while Course matching / the Scholarship finder
/// works: Nexy and a line that changes every couple of seconds, so a long
/// search reads as work being done rather than a frozen screen.
class NextedMatchingWait extends StatefulWidget {
  const NextedMatchingWait({super.key, required this.scholarships});

  /// true: the Scholarship finder's lines; false: Course matching's.
  final bool scholarships;

  @override
  State<NextedMatchingWait> createState() => _NextedMatchingWaitState();
}

class _NextedMatchingWaitState extends State<NextedMatchingWait> {
  static const List<String> _courseLines = <String>[
    'We are matching courses with your profile…',
    'Reading your level, result and IELTS band…',
    'Searching universities that teach your subject…',
    'Checking entry requirements against your profile…',
    'Ranking the best fits for you…',
    'Almost there - putting your list together…',
  ];

  static const List<String> _scholarshipLines = <String>[
    'We are matching scholarships with your profile…',
    'Working on your profile - GPA, IELTS band and level…',
    'Looking for awards open to students from Bangladesh…',
    'Checking each scholarship’s eligibility rules…',
    'Sorting what you qualify for…',
    'Almost there - putting your list together…',
  ];

  int _i = 0;
  Timer? _timer;

  List<String> get _lines => widget.scholarships ? _scholarshipLines : _courseLines;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      // Stays on the last line once it gets there.
      if (mounted && _i < _lines.length - 1) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        spacing: 12,
        children: [
          FloatY(child: Nexy(widget.scholarships ? NexyPose.grad : NexyPose.reading, height: 110)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              _lines[_i],
              key: ValueKey<int>(_i),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: t.text),
            ),
          ),
          Text(
            'This can take up to a minute - we check live university pages.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
          ),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: t.track,
                valueColor: AlwaysStoppedAnimation<Color>(t.isNight ? t.primary : t.peach),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
