import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'speaking_ai.dart';
import 'widgets.dart';

/// D2 · Speaking Part 1 & 3 flow. Route args: `{'part': 1, 'topicId'?}`
/// (bank Part 1 topic; default the next topic by rotation, changeable before
/// the first answer), `{'part': 3, 'cardId'?}` (the cue card's Part 3
/// questions; default a card by rotation), `{'part': 3, 'part3TopicId'}`
/// (all questions of a bank Part 3 topic) or `{'mock': true}` for the mock
/// interview (Part 1 topic + a card's Part 3 questions). Bank questions carry
/// a sample answer, shown on request after the student has had a go.
/// Each answer is recorded with the real microphone ([VoiceRecorder]);
/// finishing uploads, transcribes and scores the answers (AI, or the demo
/// scorer offline), saves an Attempt and opens the transcript (D5). A failed
/// upload queues the session and opens D9.
class SpeakingPart13Screen extends StatefulWidget {
  const SpeakingPart13Screen({super.key});

  @override
  State<SpeakingPart13Screen> createState() => _SpeakingPart13ScreenState();
}

class _SpeakingPart13ScreenState extends State<SpeakingPart13Screen> {
  static const int _bars = 40;

  Timer? _ticker;
  int _tick = 0;
  Map<String, dynamic>? _session;
  int _index = 0;
  int _askedSeconds = 0;
  int _elapsed = 0;
  bool _recording = false;
  bool _mock = false;
  bool _finished = false;
  final DateTime _startedAt = DateTime.now();

  final VoiceRecorder _rec = VoiceRecorder();

  /// True after "Practise without recording" (no mic) — simulated timer.
  bool _simulated = false;
  bool _busy = false;

  /// Processing overlay label while the AI works (null = hidden).
  String? _stage;
  List<double> _levels = List<double>.filled(_bars, 0);

  /// Seconds spoken per question (index → seconds).
  final Map<int, int> _spoken = <int, int>{};

  /// Recording per question (index → clip).
  final Map<int, SpeakingClip> _clips = <int, SpeakingClip>{};

  @override
  void initState() {
    super.initState();
    _rec.level.addListener(_onLevel);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {
        _tick++;
        final second = _tick % 4 == 0;
        if (second) _askedSeconds++;
        if (_recording) {
          if (_simulated) {
            if (second) _elapsed++;
          } else {
            _elapsed = _rec.elapsed.inSeconds;
          }
        }
      });
    });
  }

  void _onLevel() {
    if (!_recording || _simulated) return;
    final aim = _aimHigh();
    pushLevel(_levels, _rec.elapsed.inMilliseconds / 1000 / aim, _rec.level.value);
  }

  int _aimHigh() {
    final qs = _questions;
    if (qs.isEmpty) return 60;
    final q = qs[_index < qs.length ? _index : qs.length - 1];
    final aim = q.containsKey('aim')
        ? q.ld('aim')
        : (_session ?? <String, dynamic>{}).ld('aimSeconds');
    final high = aim.length > 1 ? aim[1].round() : 60;
    return high <= 0 ? 60 : high;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null) return;
    final args = context.routeArgs;
    if (args['mock'] == true) {
      _mock = true;
      final p1 = _part1Session(nextPart1Topic());
      final p3 = _part3Session(nextPart3Card());
      final qs = <Map<String, dynamic>>[
        for (final q in p1.l('questions').take(4))
          <String, dynamic>{...q, 'aim': p1['aimSeconds'], 'part': 1},
        for (final q in p3.l('questions'))
          <String, dynamic>{...q, 'aim': p3['aimSeconds'], 'part': 3},
      ];
      _session = <String, dynamic>{
        'id': 'mock_interview',
        'part': 0,
        'label': 'Mock interview',
        'topic': '${p1.s('topic')} · ${p3.s('topic')}',
        'questions': qs,
      };
      return;
    }
    final part = args['part'];
    final topicId = args['topicId'];
    final cardId = cueCardArg(context);
    final p3Topic = Content.part3Topic(args['part3TopicId'] as String?);
    if (p3Topic.isNotEmpty) {
      _session = _part3TopicSession(p3Topic);
      return;
    }
    final wanted = part is int
        ? part
        : (topicId is String && topicId.isNotEmpty ? 1 : 3);
    if (wanted == 1) {
      final topic = Content.part1Topic(topicId is String ? topicId : null);
      _session = _part1Session(topic.isNotEmpty ? topic : nextPart1Topic());
    } else {
      final card = Content.cueCard(cardId);
      _session = _part3Session(card.isNotEmpty ? findCueCard(cardId) : nextPart3Card());
    }
  }

  /// Session copy (label, aim, hints) for Part 1 or Part 3 from speaking.json.
  static Map<String, dynamic> _copy(int part) =>
      speakingData().m('sessionCopy').m(part == 1 ? 'part1' : 'part3');

  static List<Map<String, dynamic>> _withHints(
    String id,
    List<String> questions,
    List<String> hints, {
    List<Map<String, dynamic>> samples = const <Map<String, dynamic>>[],
  }) {
    return <Map<String, dynamic>>[
      for (var i = 0; i < questions.length; i++)
        <String, dynamic>{
          'id': '${id}_q${i + 1}',
          'text': questions[i],
          'hint': hints.isEmpty ? '' : hints[i % hints.length],
          'sample': _sampleFor(questions[i], samples),
        },
    ];
  }

  /// Sample answer (with `[[marks]]`) for question [q] from [samples]
  /// ({q, answer}); empty when there is none.
  static String _sampleFor(String q, List<Map<String, dynamic>> samples) {
    for (final x in samples) {
      if (x.s('q') == q) return x.s('answer');
    }
    return '';
  }

  /// Part 1 session for a bank topic (`Content.part1Topics`).
  static Map<String, dynamic> _part1Session(Map<String, dynamic> topic) {
    final copy = _copy(1);
    return <String, dynamic>{
      'id': topic.s('id'),
      'part': 1,
      'label': copy.s('label'),
      'topic': topic.s('topic'),
      'aimSeconds': copy['aimSeconds'],
      'questions': _withHints(
        topic.s('id'),
        topic.ls('questions'),
        copy.ls('hints'),
        samples: topic.l('samples'),
      ),
    };
  }

  /// Part 3 session from a cue card's `part3` discussion questions.
  static Map<String, dynamic> _part3Session(Map<String, dynamic> card) {
    final copy = _copy(3);
    final title = card.s('shortTitle').isNotEmpty ? card.s('shortTitle') : shortCueTitle(card.s('title'));
    return <String, dynamic>{
      'id': card.s('id'),
      'part': 3,
      'label': copy.s('label'),
      'topic': title,
      'aimSeconds': copy['aimSeconds'],
      'questions': _withHints(
        card.s('id'),
        card.ls('part3'),
        copy.ls('hints'),
        samples: card.l('part3Samples'),
      ),
    };
  }

  /// Part 3 session with every question of a bank discussion topic.
  static Map<String, dynamic> _part3TopicSession(Map<String, dynamic> topic) {
    final copy = _copy(3);
    final qs = topic.l('questions');
    return <String, dynamic>{
      'id': topic.s('id'),
      'part': 3,
      'label': copy.s('label'),
      'topic': topic.s('topic'),
      'aimSeconds': copy['aimSeconds'],
      'questions': _withHints(
        topic.s('id'),
        <String>[for (final q in qs) q.s('q')],
        copy.ls('hints'),
        samples: qs,
      ),
    };
  }

  /// Part 1 only, before the first answer: the topic can still be changed.
  bool get _canPickTopic =>
      !_mock &&
      (_session ?? <String, dynamic>{}).i('part') == 1 &&
      _index == 0 &&
      !_recording &&
      _spoken.isEmpty &&
      _stage == null &&
      !_busy;

  void _useTopic(Map<String, dynamic> topic) {
    if (topic.isEmpty || !_canPickTopic) return;
    setState(() {
      _session = _part1Session(topic);
      _askedSeconds = 0;
      _elapsed = 0;
      _levels = List<double>.filled(_bars, 0);
    });
  }

  void _randomTopic() {
    final topics = Content.part1Topics;
    if (topics.length < 2) return;
    final current = (_session ?? <String, dynamic>{}).s('id');
    final others = topics.where((tp) => tp.s('id') != current).toList();
    final pick = others[DateTime.now().microsecondsSinceEpoch % others.length];
    _useTopic(pick);
  }

  /// Part 1 topics grouped by category label (one unnamed group for the
  /// demo topics, which have no category).
  static List<(String, List<Map<String, dynamic>>)> _topicGroups() {
    final out = <(String, List<Map<String, dynamic>>)>[];
    for (final tp in Content.part1Topics) {
      final label = tp.s('categoryLabel');
      if (out.isEmpty || out.last.$1 != label) {
        out.add((label, <Map<String, dynamic>>[]));
      }
      out.last.$2.add(tp);
    }
    return out;
  }

  void _pickTopic() {
    final current = (_session ?? <String, dynamic>{}).s('id');
    showAppSheet<void>(
      context,
      Builder(
        builder: (ctx) {
          final t = ctx.tk;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Text(
                'Choose a Part 1 topic',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              Text(
                '${Content.part1Topics.length} topics · ${part1QuestionCount()} questions',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      for (final group in _topicGroups())
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            if (group.$1.isNotEmpty)
                              Text(group.$1, style: TextStyle(fontSize: 13, color: t.textMuted)),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tp in group.$2)
                                  ChipPill(
                                    label: tp.s('topic'),
                                    selected: tp.s('id') == current,
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _useTopic(tp);
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rec.level.removeListener(_onLevel);
    final rec = _rec;
    rec.cancel().whenComplete(rec.dispose);
    super.dispose();
  }

  List<Map<String, dynamic>> get _questions =>
      (_session ?? <String, dynamic>{}).l('questions');

  Future<void> _startAnswer() async {
    if (_busy) return;
    if (_simulated) {
      setState(() {
        _elapsed = 0;
        _recording = true;
      });
      return;
    }
    _busy = true;
    final ok = await _rec.start();
    _busy = false;
    if (!mounted) return;
    if (!ok) {
      final practise = await showMicOffDialog(context);
      if (!mounted || !practise) return;
      setState(() {
        _simulated = true;
        _elapsed = 0;
        _recording = true;
      });
      return;
    }
    setState(() {
      _elapsed = 0;
      _levels = List<double>.filled(_bars, 0);
      _recording = true;
    });
  }

  /// Stops the current answer and keeps its recording.
  Future<void> _stopAnswer() async {
    if (!_recording) return;
    final i = _index;
    if (_simulated) {
      _spoken[i] = _elapsed;
      setState(() => _recording = false);
      return;
    }
    _busy = true;
    final r = await _rec.stop();
    _busy = false;
    if (r != null) {
      final bytes = r.bytes;
      if (bytes != null) speakingAudioCache[r.path] = bytes;
      _spoken[i] = r.durationSec;
      _clips[i] = SpeakingClip(path: r.path, durationSec: r.durationSec, bytes: bytes);
    } else {
      _spoken[i] = _elapsed;
    }
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _toggleRecord() async {
    if (_busy || _stage != null) return;
    if (_recording) {
      await _stopAnswer();
      if (mounted) await _next();
    } else {
      await _startAnswer();
    }
  }

  Future<void> _reRecord() async {
    if (_busy || _stage != null) return;
    if (_recording && !_simulated) {
      _busy = true;
      await _rec.cancel();
      _busy = false;
    }
    _clips.remove(_index);
    _spoken.remove(_index);
    if (!mounted) return;
    setState(() => _recording = false);
    await _startAnswer();
  }

  Future<void> _next() async {
    if (_busy || _stage != null) return;
    if (_recording) await _stopAnswer();
    if (!mounted) return;
    if (_index >= _questions.length - 1) {
      await _finish();
      return;
    }
    setState(() {
      _index++;
      _elapsed = 0;
      _askedSeconds = 0;
      _recording = false;
      _levels = List<double>.filled(_bars, 0);
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final session = _session ?? <String, dynamic>{};
    final qs = _questions;
    final answers = <Map<String, dynamic>>[
      for (var i = 0; i < qs.length; i++)
        <String, dynamic>{'q': qs[i].s('text'), 'spokenSec': _spoken[i] ?? 0},
    ];
    final spoken = _spoken.values.fold<int>(0, (a, b) => a + b);
    final part = session.i('part');
    final String kind;
    final String title;
    if (_mock) {
      kind = 'part3';
      title = 'Mock interview · Parts 1 & 3';
    } else {
      kind = part == 1 ? 'part1' : 'part3';
      title = 'Part $part · ${session.s('topic')}';
    }
    if (part == 1 || _mock) {
      var answered = 0;
      for (var i = 0; i < qs.length; i++) {
        final p1 = _mock ? qs[i].i('part') == 1 : true;
        if (p1 && (_spoken[i] ?? 0) > 0) answered++;
      }
      if (answered > 0) {
        final prev = Store.I.kv<num>(kPart1AnsweredKey)?.toInt() ?? 0;
        Store.I.setKv(kPart1AnsweredKey, prev + answered);
      }
    }
    final clips = <SpeakingClip>[
      for (var i = 0; i < qs.length; i++)
        if (_clips[i] != null) _clips[i]!,
    ];
    final job = SpeakingJob(
      kind: kind,
      title: title,
      refId: session.s('id'),
      part: _mock ? 3 : (part == 1 ? 1 : 3),
      questions: answers,
      clips: clips,
      spokenSec: spoken,
      expectedSec: qs.length * 30,
      seed: qs.length,
      durationSec: DateTime.now().difference(_startedAt).inSeconds,
      cardTitle: 'Topic: ${session.s('topic')}',
      test: _mock,
    );
    if (AiService.available && clips.isNotEmpty) {
      setState(() => _stage = 'Uploading…');
    }
    final out = await processSpeaking(
      job,
      onStage: (stage, _) {
        if (mounted) setState(() => _stage = stage);
      },
    );
    if (!mounted) return;
    if (out.pending) {
      context.replace(Routes.uploadFailed);
      return;
    }
    final a = out.attempt;
    if (a == null) return;
    if (AiService.available && clips.isNotEmpty && a.data.s('source') != 'ai') {
      context.toast(offlineScoreReason('Scored offline (demo)'));
    }
    context.replace(Routes.speakingTranscript, args: {'attemptId': a.id});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final session = _session ?? <String, dynamic>{};
    final qs = _questions;
    final total = qs.length;
    final safeIndex = _index < total ? _index : total - 1;
    final q = total == 0 ? <String, dynamic>{} : qs[safeIndex];
    final aim = q.containsKey('aim') ? q.ld('aim') : session.ld('aimSeconds');
    final aimLow = aim.isNotEmpty ? aim.first.round() : 45;
    final aimHigh = aim.length > 1 ? aim[1].round() : 60;
    final ringValue = aimHigh == 0 ? 0.0 : _elapsed / aimHigh;

    final screen = AppScreen(
      fill: true,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.close,
              size: 56,
              radius: 20,
              iconSize: 22,
              tooltip: 'End session',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    session.s('label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Topic: ${session.s('topic')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.border),
              ),
              child: Text(
                '${_index + 1} / $total',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
            ),
          ],
        ),
        Row(
          spacing: 4,
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < _index
                        ? t.fill
                        : (i == _index
                            ? (t.isNight ? t.text : t.fill)
                            : (t.isNight ? t.border : t.surface)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        if (_canPickTopic)
          Row(
            spacing: 8,
            children: [
              Flexible(
                child: _TopicPill(
                  icon: AppIcons.chevronDown,
                  label: 'Topic: ${session.s('topic')}',
                  onTap: _pickTopic,
                ),
              ),
              _TopicPill(
                icon: AppIcons.refresh,
                label: 'Random topic',
                onTap: _randomTopic,
              ),
            ],
          ),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 10,
                children: [
                  LetterBadge(
                    'E',
                    size: 36,
                    radius: 12,
                    fontSize: 14,
                    bg: t.heroText,
                    fg: const Color(0xFFF6ECC8),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examiner',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                        Text(
                          'Asked ${clockShort(_askedSeconds)} ago',
                          style: TextStyle(fontSize: 12, color: t.heroMuted),
                        ),
                      ],
                    ),
                  ),
                  IconBox(
                    icon: AppIcons.replay,
                    size: 44,
                    radius: 15,
                    iconSize: 18,
                    bg: t.heroChip,
                    fg: t.heroText,
                    tooltip: 'Replay question',
                    onTap: () {
                      setState(() => _askedSeconds = 0);
                      context.toast('Replaying question');
                    },
                  ),
                ],
              ),
              Text(
                q.s('text'),
                style: TextStyle(
                  fontSize: 23,
                  height: 1.3,
                  letterSpacing: -0.3,
                  color: t.heroText,
                ),
              ),
            ],
          ),
        ),
        Center(
          child: RingProgress(
            value: ringValue,
            size: 112,
            stroke: 8,
            track: t.isNight ? t.track : t.border,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clockShort(_elapsed),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'aim $aimLow–$aimHigh s',
                  style: TextStyle(fontSize: 11, color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: SizedBox(
            width: 277,
            child: _recording && !_simulated
                ? LevelWave(
                    levels: _levels,
                    height: 44,
                    color: t.isNight ? const Color(0xFF333333) : t.surface,
                  )
                : WaveformBars(
                    count: _bars,
                    height: 44,
                    progress: (_elapsed / aimHigh).clamp(0.0, 1.0).toDouble(),
                    seed: 3 + _index,
                    color: t.isNight ? const Color(0xFF333333) : t.surface,
                  ),
          ),
        ),
        Center(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(
                  AppIcons.sparkle,
                  size: 14,
                  color: t.isNight ? t.textSoft : t.text,
                ),
                Flexible(
                  child: Text(
                    q.s('hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: t.isNight ? t.textSoft : t.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (q.s('sample').isNotEmpty && !_recording)
          Center(
            child: LinkText(
              _spoken.containsKey(safeIndex) ? 'Compare with a sample answer' : 'Stuck? See a sample answer',
              fontSize: 13,
              underline: true,
              color: t.textMuted,
              onTap: () => showSampleAnswerSheet(
                context,
                question: q.s('text'),
                answer: q.s('sample'),
                label: 'Sample answer · ${session.i('part') == 0 ? 'Mock interview' : 'Part ${session.i('part')}'}',
              ),
            ),
          ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconBox(
              icon: AppIcons.replay,
              size: 56,
              radius: 20,
              iconSize: 22,
              tooltip: 'Re-record',
              onTap: _reRecord,
            ),
            IconBox(
              icon: _recording ? AppIcons.stop : AppIcons.mic,
              size: 84,
              radius: 30,
              iconSize: 30,
              bg: t.alert,
              fg: const Color(0xFF151515),
              tooltip: _recording ? 'Stop and next question' : 'Start answering',
              onTap: _toggleRecord,
            ),
            IconBox(
              icon: AppIcons.chevronRight,
              size: 56,
              radius: 20,
              iconSize: 24,
              tooltip: 'Next question',
              onTap: _next,
            ),
          ],
        ),
      ],
    );
    final stage = _stage;
    return PopScope(
      canPop: stage == null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          screen,
          if (stage != null)
            Positioned.fill(child: SpeakingProcessingOverlay(stage: stage)),
        ],
      ),
    );
  }
}

/// Compact outlined pill for the Part 1 topic picker (label may ellipsize).
class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 36,
      child: Material(
        color: t.raised,
        shape: StadiumBorder(side: BorderSide(color: t.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.text),
                  ),
                ),
                Icon(icon, size: 16, color: t.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
