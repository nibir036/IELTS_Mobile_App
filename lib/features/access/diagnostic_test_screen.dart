import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/audio_clip.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../mock/mock_content.dart';
import '../mock/mock_questions.dart';
import '../speaking/speaking_ai.dart';
import '../speaking/widgets.dart' show buildSpeakingAttempt;
import 'diagnostic_data.dart';
import 'diagnostic_widgets.dart';

/// Short onboarding diagnostic (≈45 min): Listening (one Part 1 set) →
/// Reading (one easy passage) → Writing (one Task 2 paragraph) → Speaking
/// (two Part 1 questions). Progress is kept in memory only; on finish one
/// attempt per assessed skill is saved and the result screen opens.
class DiagnosticTestScreen extends StatefulWidget {
  const DiagnosticTestScreen({super.key});

  @override
  State<DiagnosticTestScreen> createState() => _DiagnosticTestScreenState();
}

class _DiagnosticTestScreenState extends State<DiagnosticTestScreen> {
  static const List<String> _skills = Skill.core;
  static const int _bars = 28;

  final String _id = Store.newId('diag');
  int _step = 0;
  int _remaining = 0;
  int _sectionElapsed = 0;
  final Map<String, int> _elapsed = <String, int>{};
  Timer? _ticker;
  bool _saving = false;
  bool _advancing = false;
  String _stage = '';

  // Listening
  late final Map<String, dynamic> _set;
  late final List<MockGroup> _lGroups;
  final Map<int, String> _lAnswers = <int, String>{};
  final AudioClip _clip = AudioClip();
  bool _audioStarted = false;
  bool _audioFailed = false;

  // Reading
  late final Map<String, dynamic> _passage;
  late final List<MockGroup> _rGroups;
  final Map<int, String> _rAnswers = <int, String>{};
  int _rTab = 0;

  // Writing
  late final Map<String, dynamic> _prompt;
  final TextEditingController _essay = TextEditingController();

  // Speaking
  late final Map<String, dynamic> _topic;
  late final List<String> _questions;
  final VoiceRecorder _rec = VoiceRecorder();
  int _spIndex = 0;
  bool _recording = false;
  bool _busy = false;
  int _recElapsed = 0;
  bool _speakingSkipped = false;
  final Map<int, int> _spoken = <int, int>{};
  final Map<int, SpeakingClip> _clips = <int, SpeakingClip>{};
  List<double> _levels = List<double>.filled(_bars, 0);

  String get _skill => _skills[_step];

  @override
  void initState() {
    super.initState();
    _set = Diagnostic.pickListeningSet();
    _lGroups = _set.isEmpty
        ? <MockGroup>[]
        : mockGroupsOf(_set, offset: 0, unitIndex: 0, heading: 'Part ${_set.i('part')}');
    _passage = Diagnostic.pickReadingPassage();
    _rGroups = _passage.isEmpty
        ? <MockGroup>[]
        : mockGroupsOf(_passage, offset: 0, unitIndex: 0, heading: 'Passage');
    _prompt = Diagnostic.pickWritingPrompt();
    _topic = Diagnostic.pickSpeakingTopic();
    _questions = Diagnostic.speakingQuestions(_topic);
    _remaining = Diagnostic.minutesFor(_skill) * 60;
    _rec.level.addListener(_onLevel);
    _loadAudio();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _loadAudio() async {
    if (_set.isEmpty) {
      _audioFailed = true;
      return;
    }
    final ok = await _clip.loadAsset(Content.setAudio(_set));
    if (!mounted) return;
    if (!ok) setState(() => _audioFailed = true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rec.level.removeListener(_onLevel);
    final rec = _rec;
    rec.cancel().whenComplete(rec.dispose);
    _clip.dispose();
    _essay.dispose();
    super.dispose();
  }

  void _onLevel() {
    if (!mounted || !_recording) return;
    setState(() {
      _levels = <double>[..._levels.skip(1), _rec.level.value];
    });
  }

  void _tick() {
    if (!mounted || _saving) return;
    setState(() {
      _remaining--;
      _sectionElapsed++;
      if (_recording) _recElapsed++;
    });
    if (_recording && _recElapsed >= Diagnostic.speakingMaxSeconds) {
      _stopAnswer();
    }
    if (_remaining <= 0 && !_advancing) {
      context.toast('Time’s up — moving on');
      _advance();
    }
  }

  // ── navigation ────────────────────────────────────────────────────────────

  int _unanswered() {
    switch (_skill) {
      case Skill.listening:
        return mockQuestionTotal(_lGroups) - mockAnsweredNumbers(_lGroups, _lAnswers).length;
      case Skill.reading:
        return mockQuestionTotal(_rGroups) - mockAnsweredNumbers(_rGroups, _rAnswers).length;
      default:
        return 0;
    }
  }

  Future<void> _next() async {
    if (_busy || _saving || _advancing) return;
    final step = _step;
    final left = _unanswered();
    final words = Diagnostic.wordCount(_essay.text);
    String? warning;
    if (left > 0) {
      warning = '$left question${left == 1 ? '' : 's'} not answered yet. '
          'You can’t come back to this section.';
    } else if (_skill == Skill.writing && words < Diagnostic.writingMinWords) {
      warning = 'You’ve written $words words (aim for ${Diagnostic.writingMinWords}+). '
          'You can’t come back to this section.';
    } else if (_skill == Skill.speaking && !_speakingSkipped && _spoken.length < _questions.length) {
      warning = 'Not every question has an answer yet. Finish anyway?';
    }
    if (warning != null) {
      final go = await showDiagConfirm(
        context,
        title: _step < _skills.length - 1 ? 'Move on?' : 'Finish the diagnostic?',
        body: warning,
        confirm: _step < _skills.length - 1 ? 'Next section' : 'Finish',
        cancel: 'Keep working',
      );
      if (!go || !mounted || _step != step) return;
    }
    await _advance();
  }

  Future<void> _advance() async {
    if (_saving || _advancing) return;
    _advancing = true;
    try {
      if (_skill == Skill.listening) _clip.pause();
      if (_recording) await _stopAnswer();
      if (!mounted) return;
      _elapsed[_skill] = _sectionElapsed;
      if (_step >= _skills.length - 1) {
        await _finish();
        return;
      }
      setState(() {
        _step++;
        _sectionElapsed = 0;
        _remaining = Diagnostic.minutesFor(_skill) * 60;
      });
    } finally {
      _advancing = false;
    }
  }

  Future<void> _exit() async {
    if (_saving) return;
    final copy = Diagnostic.config.m('exit');
    final stay = await showDiagConfirm(
      context,
      title: copy.s('title').isEmpty ? 'Leave the diagnostic?' : copy.s('title'),
      body: copy.s('body'),
      confirm: 'Keep going',
      cancel: 'Leave',
      icon: AppIcons.warning,
    );
    if (stay || !mounted) return;
    _ticker?.cancel();
    _clip.pause();
    if (_recording) await _rec.cancel();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.resetTo(Routes.home);
    }
  }

  // ── listening ─────────────────────────────────────────────────────────────

  void _playAudio() {
    if (_audioFailed || _clip.completed) return;
    setState(() => _audioStarted = true);
    _clip.toggle();
  }

  // ── speaking ──────────────────────────────────────────────────────────────

  Future<void> _startAnswer() async {
    if (_busy || _recording || _saving) return;
    _busy = true;
    final ok = await _rec.start();
    _busy = false;
    if (!mounted) return;
    if (!ok) {
      final copy = Diagnostic.config.m('micOff');
      final skip = await showDiagConfirm(
        context,
        title: copy.s('title').isEmpty ? 'Microphone is off' : copy.s('title'),
        body: copy.s('body'),
        confirm: 'Skip speaking',
        cancel: 'Try again',
        icon: AppIcons.micOff,
      );
      if (skip && mounted) setState(() => _speakingSkipped = true);
      return;
    }
    setState(() {
      _recording = true;
      _recElapsed = 0;
      _levels = List<double>.filled(_bars, 0);
    });
  }

  Future<void> _stopAnswer() async {
    if (!_recording || _busy) return;
    final i = _spIndex;
    _busy = true;
    final r = await _rec.stop();
    _busy = false;
    if (r != null) {
      final bytes = r.bytes;
      if (bytes != null) speakingAudioCache[r.path] = bytes;
      final sec = r.durationSec > 0 ? r.durationSec : _recElapsed;
      _spoken[i] = sec;
      _clips[i] = SpeakingClip(path: r.path, durationSec: sec, bytes: bytes);
    } else {
      _spoken[i] = _recElapsed;
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (_spIndex < _questions.length - 1) _spIndex++;
    });
  }

  Future<void> _skipSpeaking() async {
    if (_busy) return;
    if (_recording) {
      _busy = true;
      await _rec.cancel();
      _busy = false;
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _speakingSkipped = true;
    });
  }

  // ── finish ────────────────────────────────────────────────────────────────

  void _setStage(String s) {
    if (mounted) setState(() => _stage = s);
  }

  Future<void> _finish() async {
    if (_saving) return;
    _ticker?.cancel();
    setState(() {
      _saving = true;
      _stage = 'Marking your answers…';
    });
    final store = Store.I;
    final bands = <String, double?>{};
    int dur(String skill) => math.max(60, _elapsed[skill] ?? 0);

    // Listening & Reading (auto-marked), Writing (AI or offline heuristic).
    final lg = Diagnostic.grade(_lGroups, _lAnswers);
    if (lg.anyAnswered) {
      bands[Skill.listening] =
          Diagnostic.saveListening(_id, _set, lg, dur(Skill.listening)).band;
    }
    final rg = Diagnostic.grade(_rGroups, _rAnswers);
    if (rg.anyAnswered) {
      bands[Skill.reading] =
          Diagnostic.saveReading(_id, _passage, rg, dur(Skill.reading)).band;
    }
    final text = _essay.text.trim();
    if (Diagnostic.wordCount(text) > 0) {
      _setStage('Scoring your writing…');
      final r = await Diagnostic.scoreWriting(_prompt, text);
      bands[Skill.writing] =
          Diagnostic.saveWriting(_id, _prompt, text, r, dur(Skill.writing)).band;
    }

    // Speaking (same upload → transcribe → evaluate path as Parts 1–3, with
    // the offline demo scorer as fallback).
    final spokenTotal = _spoken.values.fold<int>(0, (s, v) => s + v);
    if (!_speakingSkipped && spokenTotal > 0) {
      _setStage('Scoring your speaking…');
      final answers = <Map<String, dynamic>>[
        for (var i = 0; i < _questions.length; i++)
          <String, dynamic>{'q': _questions[i], 'spokenSec': _spoken[i] ?? 0},
      ];
      final job = SpeakingJob(
        kind: Diagnostic.kind,
        title: Diagnostic.title(Skill.speaking),
        refId: _topic.s('id'),
        part: 1,
        questions: answers,
        clips: <SpeakingClip>[
          for (var i = 0; i < _questions.length; i++)
            if (_clips[i] != null) _clips[i]!,
        ],
        spokenSec: spokenTotal,
        expectedSec: _questions.length * Diagnostic.speakingExpectedSeconds,
        seed: _questions.length,
        durationSec: dur(Skill.speaking),
        cardTitle: 'Topic: ${_topic.s('topic')}',
      );
      Attempt? a;
      try {
        final out = await processSpeaking(
          job,
          onStage: (stage, _) => _setStage(stage),
          queueOnUploadFail: false,
        );
        a = out.attempt;
      } catch (_) {
        a = null;
      }
      final Attempt saved = a ??
          store.addAttempt(
            buildSpeakingAttempt(
              kind: job.kind,
              title: job.title,
              refId: job.refId,
              spokenSec: job.spokenSec,
              expectedSec: job.expectedSec,
              seed: job.seed,
              durationSec: job.durationSec,
              questions: job.questions,
            ),
          );
      saved.data['diagnosticId'] = _id;
      store.commit();
      bands[Skill.speaking] = saved.band;
    }

    if (bands.values.whereType<double>().isNotEmpty) {
      Diagnostic.saveProfile(_id, bands);
      final overall = Scoring.overall(bands.values.whereType<double>().toList());
      store.addNotification(<String, dynamic>{
        'type': 'score',
        'title': 'Diagnostic complete · Band ${Store.formatBand(overall)}',
        'body': 'See your skill bands and what to practise next.',
        'target': Routes.diagnosticResult,
        'args': <String, dynamic>{'diagnosticId': _id},
      });
    }
    if (!mounted) return;
    context.replace(Routes.diagnosticResult, args: <String, dynamic>{'diagnosticId': _id});
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  static IconData _icon(String skill) => switch (skill) {
        Skill.listening => AppIcons.listening,
        Skill.reading => AppIcons.reading,
        Skill.writing => AppIcons.writing,
        _ => AppIcons.speaking,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final copy = Diagnostic.step(_skill);
    final last = _step == _skills.length - 1;
    final List<Widget> body = switch (_skill) {
      Skill.listening => _listening(),
      Skill.reading => _reading(),
      Skill.writing => _writing(),
      _ => _speaking(),
    };
    final screen = AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: last ? 'Finish & see my band' : 'Next section',
        trailing: AppIcons.forward,
        enabled: !_saving,
        onTap: _next,
      ),
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(icon: AppIcons.close, tooltip: 'Exit', iconSize: 20, onTap: _exit),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Diagnostic · ${Skill.label(_skill)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Step ${_step + 1} of ${_skills.length} · about ${Diagnostic.totalMinutes} min in total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            DiagTimerPill(seconds: _remaining),
          ],
        ),
        SegmentBar(count: _skills.length, filled: _step + 1),
        DiagIntroCard(
          icon: _icon(_skill),
          title: copy.s('title').isEmpty ? Skill.label(_skill) : copy.s('title'),
          part: copy.s('part'),
          intro: copy.s('intro'),
        ),
        ...body,
      ],
    );

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _exit();
      },
      child: Stack(
        children: [
          screen,
          if (_saving) Positioned.fill(child: DiagSavingOverlay(stage: _stage)),
        ],
      ),
    );
  }

  Widget _groupCard(MockGroup g, Map<int, String> answers) => AppCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: MockGroupView(
          key: ValueKey<String>('diag_${g.id}'),
          group: g,
          answers: answers,
          onChanged: (n, v) => setState(() => answers[n] = v),
        ),
      );

  List<Widget> _listening() {
    if (_lGroups.isEmpty) {
      return <Widget>[
        const EmptyState(
          title: 'Listening isn’t available',
          message: 'Move on to the next section.',
          icon: AppIcons.listening,
        ),
      ];
    }
    return <Widget>[
      DiagAudioCard(
        clip: _clip,
        title: _set.s('title'),
        started: _audioStarted,
        failed: _audioFailed,
        onPlay: _playAudio,
      ),
      for (final g in _lGroups) _groupCard(g, _lAnswers),
    ];
  }

  List<Widget> _reading() {
    if (_rGroups.isEmpty) {
      return <Widget>[
        const EmptyState(
          title: 'Reading isn’t available',
          message: 'Move on to the next section.',
          icon: AppIcons.reading,
        ),
      ];
    }
    final total = mockQuestionTotal(_rGroups);
    final answered = mockAnsweredNumbers(_rGroups, _rAnswers).length;
    return <Widget>[
      SegmentedTabs(
        labels: <String>['Passage', 'Questions $answered/$total'],
        index: _rTab,
        onChanged: (i) => setState(() => _rTab = i),
      ),
      if (_rTab == 0) ...<Widget>[
        DiagPassageCard(passage: _passage),
        SoftButton(
          label: 'Go to the questions',
          trailing: AppIcons.forward,
          expand: true,
          height: 48,
          onTap: () => setState(() => _rTab = 1),
        ),
      ] else ...<Widget>[
        for (final g in _rGroups) _groupCard(g, _rAnswers),
      ],
    ];
  }

  List<Widget> _writing() => <Widget>[
        DiagWritingPanel(
          prompt: _prompt,
          controller: _essay,
          minWords: Diagnostic.writingMinWords,
          onChanged: () => setState(() {}),
        ),
      ];

  List<Widget> _speaking() {
    final t = context.tk;
    if (_speakingSkipped || _questions.isEmpty) {
      return <Widget>[
        EmptyState(
          title: 'Speaking skipped',
          message: 'Your speaking band will show as “Not assessed”. '
              'Finish to see your other bands.',
          icon: AppIcons.micOff,
          actionLabel: _questions.isEmpty ? null : 'Try recording',
          onAction: () => setState(() => _speakingSkipped = false),
        ),
      ];
    }
    final max = Diagnostic.speakingMaxSeconds;
    final answeredCurrent = _spoken.containsKey(_spIndex);
    return <Widget>[
      for (var i = 0; i < _questions.length; i++)
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          borderColor: i == _spIndex ? t.text : null,
          child: Row(
            spacing: 12,
            children: [
              LetterBadge('Q${i + 1}', size: 34, radius: 11),
              Expanded(
                child: Text(
                  _questions[i],
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: i == _spIndex ? FontWeight.w500 : FontWeight.w400,
                    color: i == _spIndex ? t.text : t.textMuted,
                  ),
                ),
              ),
              if (_spoken.containsKey(i))
                Tag('${_spoken[i]} s', tone: TagTone.success, icon: AppIcons.check),
            ],
          ),
        ),
      AppCard(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          spacing: 14,
          children: [
            Text(
              _recording
                  ? 'Recording · ${diagClock(_recElapsed)} / ${diagClock(max)}'
                  : (answeredCurrent
                      ? 'All answers recorded'
                      : 'Question ${_spIndex + 1} of ${_questions.length} · tap to answer'),
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
            DiagLevelBars(levels: _levels),
            IconBox(
              icon: _recording ? AppIcons.stop : AppIcons.mic,
              tooltip: _recording ? 'Stop' : 'Record',
              size: 72,
              circle: true,
              iconSize: 30,
              bg: _recording ? t.alert : t.primary,
              fg: _recording ? t.onAlert : t.onPrimary,
              onTap: _recording
                  ? _stopAnswer
                  : (answeredCurrent ? null : _startAnswer),
            ),
            if (_recording) ProgressBar(value: _recElapsed / max, height: 4),
          ],
        ),
      ),
      Center(
        child: LinkText(
          'Skip speaking',
          color: t.textMuted,
          fontSize: 13,
          onTap: _skipSpeaking,
        ),
      ),
    ];
  }
}
