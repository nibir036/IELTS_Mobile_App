import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/audio_clip.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_answers_parts.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// Mock answer review: every Listening / Reading question with the student's
/// answer and the key, both Writing essays and the Speaking parts.
///
/// Args: `{'attemptId': id}` (default: the latest mock), `{'session': true}`
/// (the mock being scored on G8), optional `{'tab': 0-3}`.
class MockAnswersScreen extends StatefulWidget {
  const MockAnswersScreen({super.key});

  @override
  State<MockAnswersScreen> createState() => _MockAnswersScreenState();
}

class _MockAnswersScreenState extends State<MockAnswersScreen> {
  static const List<String> _tabs = <String>['Listening', 'Reading', 'Writing', 'Speaking'];
  static const List<String> _writingKeys = <String>['TA', 'CC', 'LR', 'GRA'];
  static const List<String> _speakingKeys = <String>['FC', 'LR', 'GRA', 'P'];

  bool _inited = false;
  MockReview? _review;
  MockObjective? _listening;
  MockObjective? _reading;
  int _tab = 0;
  final List<int> _filters = <int>[0, 0];
  final Set<String> _toggled = <String>{};

  AudioClip? _clip;
  int _clipPart = 0;
  bool _clipLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final args = context.routeArgs;
    final tab = args['tab'];
    if (tab is int && tab >= 0 && tab < _tabs.length) _tab = tab;
    MockReview? r;
    if (args['session'] == true && MockSession.active) {
      r = MockReview.fromSession();
    } else {
      final a = Store.I.resolveAttempt(args, skill: Skill.mock, kind: 'mock');
      if (a != null) r = MockReview.fromAttempt(a);
    }
    _review = r;
    if (r != null) {
      _listening = MockObjective(
        listening: true,
        groups: mockListeningGroups(r.mock),
        units: mockListeningSets(r.mock),
        answers: r.listening,
      );
      _reading = MockObjective(
        listening: false,
        groups: mockReadingGroups(r.mock),
        units: mockReadingPassages(r.mock),
        answers: r.reading,
      );
    }
  }

  @override
  void dispose() {
    _clip?.dispose();
    super.dispose();
  }

  // ── Empty ─────────────────────────────────────────────────────────────────

  Widget _backButton() => IconBox(
        icon: AppIcons.back,
        size: 56,
        radius: 20,
        iconSize: 18,
        tooltip: 'Back',
        onTap: () => context.back(),
      );

  Widget _empty() {
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      gap: 16,
      children: [
        Row(children: [_backButton()]),
        EmptyState(
          icon: AppIcons.checklist,
          title: 'No mock answers yet',
          message: 'Finish a full mock test to review every answer against the key.',
          actionLabel: 'Start a mock test',
          onAction: () => context.push(Routes.mockSystemCheck),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _review;
    final l = _listening;
    final rd = _reading;
    if (r == null || l == null || rd == null) return _empty();
    final t = context.tk;

    final List<Widget> body;
    switch (_tab) {
      case 0:
        body = _objectiveTab(r, l, 0);
      case 1:
        body = _objectiveTab(r, rd, 1);
      case 2:
        body = _writingTab(r);
      default:
        body = _speakingTab(r);
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gap: 14,
      children: [
        Row(
          children: [
            _backButton(),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Answer review',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${r.title} · ${mockTestName(r.mock)} · ${Store.weekdayDate(r.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
        SegmentedTabs(
          labels: _tabs,
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        ...body,
      ],
    );
  }

  // ── Listening / Reading ───────────────────────────────────────────────────

  bool _passes(MockMark m, int filter) {
    switch (filter) {
      case 1:
        return m == MockMark.wrong || m == MockMark.partial;
      case 2:
        return m == MockMark.blank;
      default:
        return true;
    }
  }

  List<Widget> _objectiveTab(MockReview r, MockObjective o, int which) {
    final t = context.tk;
    final name = which == 0 ? 'Listening' : 'Reading';
    if (o.groups.isEmpty) {
      return <Widget>[
        EmptyState(
          icon: which == 0 ? AppIcons.listening : AppIcons.reading,
          title: 'Questions unavailable',
          message: 'The $name test of this mock is not in the content bank any more.',
        ),
      ];
    }
    final recorded = o.recorded;
    final filter = recorded ? _filters[which] : 0;
    final out = <Widget>[_scoreCard(r, o, which)];

    if (recorded) {
      out.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (final (i, label, count) in <(int, String, int)>[
                (0, 'All', o.total),
                (1, 'Wrong', o.wrong),
                (2, 'Blank', o.blank),
              ])
                ChipPill(
                  label: label,
                  count: '$count',
                  selected: filter == i,
                  onTap: () => setState(() => _filters[which] = i),
                ),
            ],
          ),
        ),
      );
    } else {
      out.add(
        AppCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.info, size: 18, color: t.textMuted),
              Expanded(
                child: Text(
                  'Your answers were not recorded for this mock, so this is the answer key only.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    String? heading;
    var shown = 0;
    for (final g in o.groups) {
      final qs = g.questions.where((q) => _passes(o.markOf(q), filter)).toList();
      if (qs.isEmpty) continue;
      if (g.heading != heading) {
        heading = g.heading;
        out.add(_unitHeader(r, o, g));
      }
      out.add(_groupCard(r, o, g, qs, which));
      shown += qs.length;
    }
    if (shown == 0) {
      out.add(
        EmptyState(
          icon: AppIcons.checkCircle,
          title: filter == 1 ? 'No wrong answers' : 'No blank answers',
          message: filter == 1
              ? 'Every answered question in $name was correct.'
              : 'You answered every $name question.',
        ),
      );
    }
    return out;
  }

  Widget _scoreCard(MockReview r, MockObjective o, int which) {
    final t = context.tk;
    final key = which == 0 ? 'listening' : 'reading';
    final total = o.total;
    int? correct;
    if (o.recorded) {
      correct = o.correct;
    } else {
      final stored = r.data.m(which == 0 ? 'listeningScore' : 'readingScore');
      if (stored.isNotEmpty) correct = stored.i('correct');
    }
    double? band = r.band(key);
    if (band == null && correct != null && total > 0) {
      band = which == 0
          ? Scoring.listeningBand(correct, total)
          : Scoring.readingBand(correct, total);
    }
    final ratio = correct == null || total == 0 ? 0.0 : (correct / total).clamp(0.0, 1.0).toDouble();

    return HeroCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      '${_tabs[which]} score',
                      style: TextStyle(fontSize: 13, color: t.heroMuted),
                    ),
                    Text(
                      '${correct == null ? '–' : '$correct'} / $total',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                        letterSpacing: -1.2,
                        color: t.heroText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.heroChip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Band ${band == null ? '–' : mockBand(band)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.heroText),
                ),
              ),
            ],
          ),
          ProgressBar(value: ratio, onHero: true, height: 8),
          if (o.recorded)
            Text(
              '${o.correct} correct · ${o.wrong} wrong · ${o.blank} blank',
              style: TextStyle(fontSize: 12, color: t.heroMuted),
            ),
        ],
      ),
    );
  }

  Widget _unitHeader(MockReview r, MockObjective o, MockGroup g) {
    final t = context.tk;
    final title = o.unitTitle(g.unitIndex);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.heading,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
              ],
            ),
          ),
          if (o.listening && r.mock.s('listeningTest').isNotEmpty)
            LinkText(
              'Transcript',
              fontSize: 13,
              color: t.textMuted,
              onTap: () => _openTranscript(r, g.unitIndex),
            ),
        ],
      ),
    );
  }

  void _openTranscript(MockReview r, int unitIndex) {
    _clip?.pause();
    context.push(
      Routes.listeningTranscript,
      args: <String, dynamic>{'testId': r.mock.s('listeningTest'), 'part': unitIndex},
    );
  }

  Widget _groupCard(MockReview r, MockObjective o, MockGroup g, List<MockQuestion> qs, int which) {
    final t = context.tk;
    final title = g.type == 'form' && g.formTitle.isNotEmpty ? g.formTitle : g.title;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            g.instruction.isEmpty ? g.range : '${g.range} · ${g.instruction}',
            style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
          ),
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.35),
            ),
          for (final q in qs) _row(r, o, g, q, which),
        ],
      ),
    );
  }

  Widget _row(MockReview r, MockObjective o, MockGroup g, MockQuestion q, int which) {
    final mark = o.markOf(q);
    final key = '$which-${q.number}';
    final defaultOpen = mark == MockMark.wrong || mark == MockMark.partial || mark == MockMark.blank;
    final open = defaultOpen != _toggled.contains(key);
    final details = o.listening ? _transcriptDetails(r, o, g, q) : _readingDetails(o, g, q);
    return MockAnswerRow(
      key: ValueKey<String>(key),
      number: q.span > 1 ? '${q.number}–${q.lastNumber}' : '${q.number}',
      question: mockQuestionText(q),
      mark: mark,
      given: mockGivenLabel(q, g, o.given(q)),
      correct: mockCorrectLabel(q, g),
      alsoAccepted: mockAlsoAccepted(q),
      marksLabel: '${o.marksOf(q)}/${q.span}',
      open: open,
      detailsLabel: o.listening ? 'transcript' : 'explanation',
      onToggle: () => setState(() {
        if (!_toggled.remove(key)) _toggled.add(key);
      }),
      details: details,
    );
  }

  List<Widget> _transcriptDetails(MockReview r, MockObjective o, MockGroup g, MockQuestion q) {
    final t = context.tk;
    final lines = o.transcriptFor(q, g.unitIndex);
    if (lines.isEmpty) return const <Widget>[];
    final base = TextStyle(fontSize: 13, height: 1.5, color: t.isNight ? t.text : t.textSoft);
    final hi = base.copyWith(
      fontWeight: FontWeight.w600,
      color: t.text,
      backgroundColor: t.accentSoft,
    );
    return <Widget>[
      MockReviewBox(
        title: 'Where you hear it',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            for (final (line, phrases) in lines)
              Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: '${mockShortClock(line.d('start').round())}  ${line.s('speaker')}: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textMuted),
                    ),
                    ...mockHighlightSpans(line.s('text'), phrases, base, hi),
                  ],
                ),
              ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: SoftButton(
          label: 'Open transcript',
          leading: AppIcons.article,
          height: 36,
          fontSize: 13,
          onTap: () => _openTranscript(r, g.unitIndex),
        ),
      ),
    ];
  }

  List<Widget> _readingDetails(MockObjective o, MockGroup g, MockQuestion q) {
    final t = context.tk;
    final raw = o.raw(q.number);
    final explanation = raw.s('explanation').trim();
    final letter = raw.s('evidenceParagraph').trim();
    final evidence = raw.s('evidence').trim();
    final paragraph = o.paragraph(g.unitIndex, letter);
    final base = TextStyle(fontSize: 13, height: 1.5, color: t.isNight ? t.text : t.textSoft);
    final hi = base.copyWith(
      fontWeight: FontWeight.w600,
      color: t.text,
      backgroundColor: t.accentSoft,
    );
    return <Widget>[
      if (explanation.isNotEmpty)
        Text.rich(TextSpan(children: mockBoldSpans(explanation, base))),
      if (paragraph.isNotEmpty)
        MockReviewBox(
          title: 'Evidence · Paragraph $letter',
          child: Text.rich(
            TextSpan(
              children: mockHighlightSpans(
                paragraph,
                evidence.isEmpty ? const <String>[] : <String>[evidence],
                base,
                hi,
              ),
            ),
          ),
        )
      else if (evidence.isNotEmpty)
        MockReviewBox(
          title: letter.isEmpty ? 'Evidence' : 'Evidence · Paragraph $letter',
          child: Text('“$evidence”', style: base),
        ),
    ];
  }

  // ── Writing ───────────────────────────────────────────────────────────────

  List<Widget> _writingTab(MockReview r) {
    final t = context.tk;
    final band = r.band('writing');
    final crit = r.data.m('writingCriteria');
    return <Widget>[
      HeroCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('Writing band', style: TextStyle(fontSize: 13, color: t.heroMuted)),
                      Text(
                        band == null ? '–' : mockBand(band),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                          letterSpacing: -1.2,
                          color: t.heroText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  r.attempt == null ? 'Being scored…' : 'Task 2 counts double',
                  style: TextStyle(fontSize: 12, color: t.heroMuted),
                ),
              ],
            ),
            if (crit.isNotEmpty)
              Row(
                spacing: 6,
                children: [
                  for (final k in _writingKeys)
                    Expanded(
                      child: MockCriterionTile(
                        label: k,
                        value: crit[k] is num ? mockBand(crit.d(k)) : '–',
                        onHero: true,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      _taskCard(r, 1),
      _taskCard(r, 2),
    ];
  }

  Widget _taskCard(MockReview r, int task) {
    final t = context.tk;
    final prompt = task == 1 ? mockTask1(r.mock) : mockTask2(r.mock);
    final w = r.data.m('writing');
    final essay = (r.essays[task] ?? '').trim();
    final tb = w['task${task}Band'];
    final bandText = tb is num && tb > 0 ? mockBand(tb.toDouble()) : null;
    final words = essay.isEmpty ? w.i('task${task}Words') : mockWordCount(essay);
    final crit = w.m('task${task}Criteria');
    final summary = w.s('task${task}Summary').trim();
    final hasModel = prompt.isNotEmpty && prompt.s('modelAnswer').isNotEmpty;
    final body = t.isNight ? t.text : t.textSoft;

    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              Tag('Task $task'),
              Expanded(
                child: Text(
                  prompt.s('title').isEmpty ? 'Writing Task $task' : prompt.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              if (bandText != null) Tag('Band $bandText', tone: TagTone.primary),
            ],
          ),
          Text(
            prompt.s('prompt').isEmpty ? 'Prompt not found in the content bank.' : prompt.s('prompt'),
            style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted),
          ),
          const Hairline(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your answer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (words > 0)
                Text('$words words', style: TextStyle(fontSize: 12, color: t.textMuted)),
            ],
          ),
          if (essay.isEmpty)
            Text(
              'Essay not recorded for this mock.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: t.textMuted),
            )
          else
            MockReviewBox(
              child: Text(essay, style: TextStyle(fontSize: 14, height: 1.55, color: body)),
            ),
          if (crit.isNotEmpty)
            Row(
              spacing: 6,
              children: [
                for (final k in _writingKeys)
                  Expanded(
                    child: MockCriterionTile(
                      label: k,
                      value: crit[k] is num && crit.d(k) > 0 ? mockBand(crit.d(k)) : '–',
                    ),
                  ),
              ],
            ),
          if (summary.isNotEmpty)
            Text(summary, style: TextStyle(fontSize: 13, height: 1.45, color: body)),
          if (hasModel)
            OutlineButtonX(
              label: 'See the model answer',
              leading: AppIcons.article,
              height: 46,
              fontSize: 14,
              onTap: () => context.push(
                Routes.writingSampleAnswer,
                args: <String, dynamic>{'promptId': prompt.s('id'), 'task': task},
              ),
            ),
        ],
      ),
    );
  }

  // ── Speaking ──────────────────────────────────────────────────────────────

  Future<void> _play(int part, String path) async {
    final current = _clip;
    if (current != null && _clipPart == part) {
      if (!_clipLoading) current.toggle();
      return;
    }
    current?.dispose();
    final clip = AudioClip();
    setState(() {
      _clip = clip;
      _clipPart = part;
      _clipLoading = true;
    });
    final ok = await clip.loadRecording(path);
    if (!mounted || _clip != clip) return;
    if (ok) {
      setState(() => _clipLoading = false);
      clip.play();
    } else {
      clip.dispose();
      setState(() {
        _clip = null;
        _clipPart = 0;
        _clipLoading = false;
      });
      context.toast('This recording is no longer on this device');
    }
  }

  List<Widget> _speakingTab(MockReview r) {
    final t = context.tk;
    final band = r.band('speaking');
    final crit = r.data.m('speakingCriteria');
    final summary = r.data.s('speakingSummary').trim();
    var spoken = r.data.i('spokenSec');
    if (spoken == 0) spoken = r.spokenSec.values.fold<int>(0, (s, v) => s + v);
    final topic = mockPart1Topic(r.mock);
    final cue = mockCueCard(r.mock);

    return <Widget>[
      HeroCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('Speaking band', style: TextStyle(fontSize: 13, color: t.heroMuted)),
                      Text(
                        band == null ? '–' : mockBand(band),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                          letterSpacing: -1.2,
                          color: t.heroText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  r.attempt == null
                      ? 'Being scored…'
                      : (spoken > 0 ? 'Spoke ${mockShortClock(spoken)} min' : ''),
                  style: TextStyle(fontSize: 12, color: t.heroMuted),
                ),
              ],
            ),
            if (crit.isNotEmpty)
              Row(
                spacing: 6,
                children: [
                  for (final k in _speakingKeys)
                    Expanded(
                      child: MockCriterionTile(
                        label: k,
                        value: crit[k] is num ? mockBand(crit.d(k)) : '–',
                        onHero: true,
                      ),
                    ),
                ],
              ),
            if (summary.isNotEmpty)
              Text(summary, style: TextStyle(fontSize: 13, height: 1.45, color: t.heroText)),
          ],
        ),
      ),
      _partCard(
        r,
        part: 1,
        title: 'Part 1 · Introduction',
        subtitle: topic.s('topic'),
        questions: topic.ls('questions'),
      ),
      _partCard(
        r,
        part: 2,
        title: 'Part 2 · Long turn',
        subtitle: cue.s('title'),
        questions: <String>[if (cue.s('prompt').isNotEmpty) cue.s('prompt')],
        bullets: cue.ls('bullets'),
      ),
      _partCard(
        r,
        part: 3,
        title: 'Part 3 · Discussion',
        subtitle: cue.s('topic'),
        questions: cue.ls('part3'),
      ),
    ];
  }

  Widget _playButton(int part, String path) {
    final t = context.tk;
    final clip = _clip;
    if (clip == null || _clipPart != part) {
      return IconBox(
        icon: AppIcons.play,
        circle: true,
        size: 44,
        bg: t.primary,
        fg: t.onPrimary,
        tooltip: 'Play recording',
        onTap: () => _play(part, path),
      );
    }
    return ListenableBuilder(
      listenable: clip,
      builder: (context, _) => IconBox(
        icon: clip.playing ? AppIcons.pause : AppIcons.play,
        circle: true,
        size: 44,
        bg: t.primary,
        fg: t.onPrimary,
        tooltip: clip.playing ? 'Pause' : 'Play recording',
        onTap: () => _play(part, path),
      ),
    );
  }

  Widget _partCard(
    MockReview r, {
    required int part,
    required String title,
    required String subtitle,
    required List<String> questions,
    List<String> bullets = const <String>[],
  }) {
    final t = context.tk;
    final body = t.isNight ? t.text : t.textSoft;
    final path = r.recordings[part] ?? '';
    final secs = r.spokenSec[part] ?? 0;
    final transcript = r.transcripts[part] ?? '';
    final clip = _clip;
    final sub = <String>[
      if (subtitle.isNotEmpty) subtitle,
      if (secs > 0) 'spoke ${mockShortClock(secs)}',
    ].join(' · ');

    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              LetterBadge('P$part'),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                  ],
                ),
              ),
              if (path.isNotEmpty) _playButton(part, path),
            ],
          ),
          if (path.isNotEmpty && clip != null && _clipPart == part)
            ListenableBuilder(
              listenable: clip,
              builder: (context, _) => Row(
                spacing: 10,
                children: [
                  Expanded(child: ProgressBar(value: clip.progress, height: 6)),
                  Text(
                    _clipLoading
                        ? 'Loading…'
                        : '${mockShortClock(clip.positionSec.round())} / ${mockShortClock(clip.durationSec.round())}',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
          if (questions.isEmpty)
            Text(
              'Questions not found in the content bank.',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          for (var i = 0; i < questions.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(questions[i], style: TextStyle(fontSize: 14, height: 1.4, color: body)),
                ),
              ],
            ),
          if (bullets.isNotEmpty)
            MockReviewBox(
              title: 'You should say',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  for (final b in bullets)
                    Text('•  $b', style: TextStyle(fontSize: 13, height: 1.4, color: body)),
                ],
              ),
            ),
          if (transcript.isNotEmpty)
            MockReviewBox(
              title: 'Your answer (transcript)',
              child: Text(transcript, style: TextStyle(fontSize: 14, height: 1.5, color: body)),
            )
          else
            Text(
              path.isNotEmpty
                  ? 'Transcript not recorded · play your recording above.'
                  : 'Transcript and recording not recorded for this part.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: t.textMuted),
            ),
        ],
      ),
    );
  }
}
