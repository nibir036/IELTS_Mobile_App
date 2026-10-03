import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'editor_common.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C4 · Live AI Line-by-Line Review of `args['attemptId']` (or the newest
/// essay). Accepted fixes are remembered on the attempt (`data.accepted`).
class WritingLineReviewScreen extends StatefulWidget {
  const WritingLineReviewScreen({super.key});

  @override
  State<WritingLineReviewScreen> createState() =>
      _WritingLineReviewScreenState();
}

class _WritingLineReviewScreenState extends State<WritingLineReviewScreen> {
  Attempt? _attempt;
  List<Map<String, dynamic>> _issues = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _strengths = <Map<String, dynamic>>[];
  int _current = 0;
  final Set<String> _accepted = <String>{};
  bool _inited = false;

  static const double _sheetHeight = 390;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final a = Store.I.resolveAttempt(
      context.routeArgs,
      skill: Skill.writing,
      kindPrefix: 'task',
    );
    _attempt = a;
    if (a == null) return;
    _issues = WritingService.issuesOf(a);
    _strengths = WritingService.strengthsOf(a);
    _accepted.addAll(a.data.ls('accepted'));
    final firstOpen = _issues.indexWhere((e) => !_accepted.contains(e.s('id')));
    _current = firstOpen < 0 ? 0 : firstOpen;
  }

  Map<String, dynamic> get _issue =>
      _issues.isEmpty ? <String, dynamic>{} : _issues[_current];

  void _move(int delta) {
    if (_issues.isEmpty) return;
    setState(() {
      _current = (_current + delta) % _issues.length;
      if (_current < 0) _current += _issues.length;
    });
  }

  void _accept() {
    final a = _attempt;
    if (_issues.isEmpty || a == null) return;
    setState(() => _accepted.add(_issue.s('id')));
    a.data['accepted'] = _accepted.toList();
    Store.I.commit();
    context.toast('Fix applied');
    _move(1);
  }

  void _select(String id) {
    final i = _issues.indexWhere((e) => e.s('id') == id);
    if (i >= 0) setState(() => _current = i);
  }

  Map<String, dynamic>? _issueById(String id) {
    for (final e in _issues) {
      if (e.s('id') == id) return e;
    }
    return null;
  }

  /// "Issue 2 of 4 · fixed phrase" (numbered within its type).
  String _position(Map<String, dynamic> issue) {
    final same = _issues.where((e) => e.s('type') == issue.s('type')).toList();
    final k = same.indexWhere((e) => e.s('id') == issue.s('id')) + 1;
    return 'Issue $k of ${same.length} · ${issue.s('label')}';
  }

  InlineSpan _segment(Map<String, dynamic> seg) {
    final t = context.tk;
    final mark = seg.s('mark');
    final issueId = seg.s('issueId');
    var text = seg.s('text');
    if (mark.isEmpty) return TextSpan(text: text);

    final issue = issueId.isEmpty ? null : _issueById(issueId);
    var accepted = false;
    var selected = false;
    if (issue != null) {
      accepted = _accepted.contains(issueId);
      if (accepted) text = issue.s('suggestion');
      selected = identical(issue, _issue);
    }

    Color bg;
    Color? underline;
    switch (mark) {
      case 'strong':
        bg = const Color(0xFFF7EDC4);
      case 'vocab':
        bg = const Color(0xFFE4E5FC);
        underline = t.isNight ? const Color(0xFFFFFFFF) : const Color(0xFF9FA2EE);
      default:
        bg = const Color(0xFFFCE0DA);
        underline = t.isNight
            ? const Color(0xFFFFFFFF)
            : (selected ? const Color(0xFFD9503A) : const Color(0xFFF29A8A));
    }
    if (accepted) {
      bg = const Color(0xFFF7EDC4);
      underline = null;
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        onTap: issue == null ? null : () => _select(issueId),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: (underline != null && !selected)
                ? null
                : BorderRadius.circular(3),
            border: selected
                ? Border.all(color: t.text, width: 2)
                : (underline == null
                    ? null
                    : Border(bottom: BorderSide(color: underline, width: 2))),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              color: Color(0xFF151515),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final attempt = _attempt;
    if (attempt == null) return const WritingNoEssay(title: 'AI review');
    final text = attempt.data.s('text');
    final grammar = _issues.where((e) => e.s('type') != 'vocab').length;
    final vocab = _issues.where((e) => e.s('type') == 'vocab').length;
    final counts = <Map<String, dynamic>>[
      <String, dynamic>{'type': 'grammar', 'label': 'Grammar', 'count': grammar},
      <String, dynamic>{'type': 'vocab', 'label': 'Vocabulary', 'count': vocab},
      <String, dynamic>{'type': 'strong', 'label': 'Strong', 'count': _strengths.length},
    ];
    final marks = <Map<String, dynamic>>[
      for (final i in _issues)
        <String, dynamic>{
          'start': i.i('start'),
          'end': i.i('end'),
          'mark': i.s('type') == 'vocab' ? 'vocab' : 'grammar',
          'issueId': i.s('id'),
        },
      for (final st in _strengths)
        <String, dynamic>{
          'start': st.i('start'),
          'end': st.i('end'),
          'mark': 'strong',
        },
    ];
    final paraList = EssayAnalysis.paragraphs(text, marks);
    final issue = _issue;
    final sheetIssue = issue.isEmpty
        ? <String, dynamic>{
            'type': 'strong',
            'title': 'No issues found',
            'position': 'Nothing to fix in this essay',
            'original': '–',
            'suggestion': '–',
            'note': 'The AI found no grammar or vocabulary problems. Compare your essay with the improved version for the next step up.',
          }
        : <String, dynamic>{...issue, 'position': _position(issue)};

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, _sheetHeight + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  WHeader(
                    title: 'AI review',
                    trailing: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        Store.formatBand(attempt.band),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 6,
                      children: [
                        for (final c in counts) _CountChip(c: c),
                      ],
                    ),
                  ),
                  AppCard(
                    radius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        for (final p in paraList)
                          Text.rich(
                            TextSpan(
                              children: [for (final s in p) _segment(s)],
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.75,
                              color: t.isNight
                                  ? t.text
                                  : const Color(0xFF2A2629),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _sheetHeight + MediaQuery.paddingOf(context).bottom,
            child: _IssueSheet(
              issue: sheetIssue,
              accepted: _accepted.contains(issue.s('id')),
              onPrev: () => _move(-1),
              onNext: () => _move(1),
              onSkip: () => _move(1),
              onAccept: issue.isEmpty ? () => context.back() : _accept,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color sq;
    switch (c.s('type')) {
      case 'vocab':
        sq = const Color(0xFF9FA2EE);
      case 'strong':
        sq = const Color(0xFFE8D48A);
      default:
        sq = const Color(0xFFF29A8A);
    }
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: sq,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Text(
            '${c.s('label')} ${c.i('count')}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _IssueSheet extends StatelessWidget {
  const _IssueSheet({
    required this.issue,
    required this.accepted,
    required this.onPrev,
    required this.onNext,
    required this.onSkip,
    required this.onAccept,
  });

  final Map<String, dynamic> issue;
  final bool accepted;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isVocab = issue.s('type') == 'vocab';
    final softBtn = t.isNight ? t.surfaceAlt2 : t.surface;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F50283C),
            blurRadius: 40,
            offset: Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: wc(t, 0xFFE3D6DE, 0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              spacing: 10,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isVocab
                        ? const Color(0xFFE4E5FC)
                        : const Color(0xFFFCE0DA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppIcons.sparkle,
                    size: 18,
                    color: isVocab
                        ? const Color(0xFF3B3C6B)
                        : const Color(0xFFB63A26),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        issue.s('title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        issue.s('position'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                IconBox(
                  icon: AppIcons.chevronLeft,
                  radius: 14,
                  bg: softBtn,
                  borderColor: t.border,
                  tooltip: 'Previous issue',
                  onTap: onPrev,
                ),
                IconBox(
                  icon: AppIcons.chevronRight,
                  radius: 14,
                  bg: softBtn,
                  borderColor: t.border,
                  tooltip: 'Next issue',
                  onTap: onNext,
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: wc(t, 0xFFF8F3F6, 0xFF1F1F1F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                spacing: 10,
                children: [
                  _CompareLine(
                    label: 'Yours',
                    text: issue.s('original'),
                    style: TextStyle(
                      fontSize: 16,
                      color: t.danger,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: t.danger,
                    ),
                  ),
                  _CompareLine(
                    label: 'Fix',
                    text: issue.s('suggestion'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                issue.s('note'),
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: wc(t, 0xFF4A4549, 0xFF9A9A9A),
                ),
              ),
            ),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  flex: 1,
                  child: WFlatButton(
                    label: 'Skip',
                    height: 54,
                    fontSize: 16,
                    bg: softBtn,
                    fg: t.text,
                    borderColor: t.border,
                    onTap: onSkip,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: issue.s('type') == 'strong'
                        ? 'Done'
                        : (accepted ? 'Fixed' : 'Accept fix'),
                    leading: accepted ? AppIcons.check : null,
                    height: 54,
                    radius: 18,
                    onTap: accepted ? onNext : onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareLine extends StatelessWidget {
  const _CompareLine({
    required this.label,
    required this.text,
    required this.style,
  });

  final String label;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.tk.textMuted),
          ),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
