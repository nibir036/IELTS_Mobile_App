import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/entitlements.dart';
import '../../app/services/audio_clip.dart';
import '../../app/services/tts.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../home/upgrade_sheet.dart';
import 'widgets.dart';

/// D7 · Pronunciation & intonation trainer. Hold to record uses the real mic
/// and AI scoring ([AiService.scorePronunciation]: Goodness of Pronunciation
/// per expected sound, from the speaking service); simulated offline.
/// Each "hold to record" try stores its match score per word in kv
/// ([kPronScoresKey]); finishing the list saves an Attempt (kind
/// 'pronunciation', no band).
class PronunciationScreen extends StatefulWidget {
  const PronunciationScreen({super.key});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  late final Map<String, dynamic> _data = speakingData().m('pronunciation');

  /// Route args `{'vocab': [keys], 'title'?}` practise speaking-bank words.
  late final List<Map<String, dynamic>> _bankWords = () {
    final v = context.routeArgs['vocab'];
    if (v is! List) return <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final k in v)
        if (pronunciationWordFor('$k').isNotEmpty) pronunciationWordFor('$k'),
    ];
  }();

  /// Without route words: a set generated from the speaking word bank -
  /// today's mix, or one topic ([_topic]). Falls back to the demo set.
  late bool _daily = _bankWords.isEmpty && _generated(null).isNotEmpty;
  String? _topic;
  late List<Map<String, dynamic>> _words =
      _bankWords.isNotEmpty ? _bankWords : (_daily ? _generated(null) : _data.l('words'));
  late int _index = _bankWords.isNotEmpty || _daily
      ? 0
      : _data.i('startIndex').clamp(0, _words.isEmpty ? 0 : _words.length - 1).toInt();

  static List<Map<String, dynamic>> _generated(String? topic) => <Map<String, dynamic>>[
        for (final k in dailyPronunciationKeys(DateTime.now(), topic: topic))
          if (pronunciationWordFor(k).isNotEmpty) pronunciationWordFor(k),
      ];

  /// Switches the generated set to [topic] (null = today's mix).
  void _pickTopic(String? topic) {
    final words = _generated(topic);
    if (words.isEmpty) return;
    _goTo(0);
    setState(() {
      _topic = topic;
      _daily = true;
      _words = words;
    });
  }

  void _showTopics() {
    final t = context.tk;
    final topics = pronunciationTopics();
    showAppSheet<void>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Choose words', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '10 words from the speaking word bank. A new set every day.',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (i, label) in <String?>[null, ...topics.keys].indexed)
                    ListRow(
                      divider: i > 0,
                      title: label ?? 'Today’s mix',
                      subtitle: label == null
                          ? 'All topics'
                          : '${topics[label]!.length} words in the bank',
                      trailing: label == _topic
                          ? Icon(AppIcons.checkCircle, size: 20, color: t.iconAccent)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickTopic(label);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Timer? _playTimer;
  Timer? _recTimer;

  /// 'native' | 'you' | null
  String? _playing;
  double _playProgress = 0;
  bool _holding = false;
  bool _finished = false;
  final DateTime _startedAt = DateTime.now();

  final VoiceRecorder _rec = VoiceRecorder();
  final AudioClip _clip = AudioClip();

  bool _recStarting = false;
  bool _recActive = false;
  bool _scoring = false;
  bool _clipLoading = false;

  /// This session's AI results per word id: {tip, heard}.
  final Map<String, Map<String, dynamic>> _ai = <String, Map<String, dynamic>>{};

  /// This session's last recording per word id (path).
  final Map<String, String> _myAudio = <String, String>{};

  /// Waveform of this session's last recording per word id (bar heights).
  final Map<String, List<double>> _myWave = <String, List<double>>{};

  /// Live mic level bars while the button is held (newest last).
  final List<double> _live = <double>[];

  int get _barCount {
    final n = _data.ld('nativeWave').length;
    return n > 0 ? n : 18;
  }

  @override
  void initState() {
    super.initState();
    _clip.addListener(_onClip);
    _rec.level.addListener(_onLevel);
  }

  void _onLevel() {
    if (!mounted || !_recActive) return;
    setState(() {
      _live.add(4 + _rec.level.value * 32);
      if (_live.length > _barCount) _live.removeAt(0);
    });
  }

  /// Bar heights (4–36) of a 16-bit PCM WAV: peak level per slice,
  /// scaled to the loudest slice. Null when the bytes aren't WAV.
  static List<double>? _waveOf(Uint8List bytes, int bars) {
    // Find the "data" chunk (the header isn't always 44 bytes).
    var at = 12;
    var start = -1;
    var length = 0;
    while (at + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(at, at + 4));
      final size = bytes[at + 4] | bytes[at + 5] << 8 | bytes[at + 6] << 16 | bytes[at + 7] << 24;
      if (id == 'data') {
        start = at + 8;
        length = math.min(size, bytes.length - start);
        break;
      }
      at += 8 + size + (size & 1);
    }
    if (start < 0 || length < bars * 4 || bytes.length < 12 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') {
      return null;
    }
    final data = ByteData.sublistView(bytes, start, start + length - (length & 1));
    final samples = data.lengthInBytes ~/ 2;
    final per = samples ~/ bars;
    if (per == 0) return null;
    final peaks = <double>[];
    for (var b = 0; b < bars; b++) {
      var peak = 0;
      for (var i = b * per; i < (b + 1) * per; i += 4) {
        final v = data.getInt16(i * 2, Endian.little).abs();
        if (v > peak) peak = v;
      }
      peaks.add(peak.toDouble());
    }
    final top = peaks.reduce((a, b) => math.max(a, b));
    if (top <= 0) return List<double>.filled(bars, 2);
    return <double>[for (final p in peaks) 4 + 32 * p / top];
  }

  void _onClip() {
    if (!mounted || _playing != 'you' || _clipLoading) return;
    setState(() {
      _playProgress = _clip.progress;
      if (_clip.completed || (!_clip.playing && _clip.progress >= 1)) {
        _playing = null;
        _playProgress = 0;
      }
    });
  }

  /// Per-user tries: wordId → scores (oldest first).
  List<double> _scoresFor(String wordId) => _pronTries(Store.I, wordId);

  /// Saves a real AI score (0..1) for the word. Only AI scores are kept.
  void _recordTry({required double aiScore, Map<String, dynamic>? word}) {
    final w = word ?? _word;
    final id = w.s('id');
    if (id.isEmpty) return;
    final tries = _scoresFor(id);
    final score = aiScore;
    final raw = Store.I.kv<Map>(kPronScoresKey);
    final all = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);
    all[id] = <double>[...tries, score];
    Store.I.setKv(kPronScoresKey, all);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final words = <Map<String, dynamic>>[];
    var good = 0;
    for (final w in _words) {
      final tries = _scoresFor(w.s('id'));
      final score = tries.isEmpty ? 0.0 : tries.last;
      if (score >= 0.75) good++;
      words.add(<String, dynamic>{'word': w.s('word'), 'score': score});
    }
    if (!words.any((w) => w.d('score') > 0)) {
      context.toast('Hold to record at least one word first');
      _finished = false;
      return;
    }
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    Store.I.addAttempt(
      Attempt(
        id: Store.newId('att'),
        skill: Skill.speaking,
        kind: 'pronunciation',
        title: _bankWords.isNotEmpty
            ? 'Pronunciation · ${(context.routeArgs['title'] as String?) ?? 'Vocabulary'}'
            : _daily
                ? 'Pronunciation · ${_topic ?? 'Today’s mix'}'
                : 'Pronunciation · Word set',
        refId: _bankWords.isNotEmpty ? 'pron_vocab' : (_daily ? 'pron_daily' : 'pron_default'),
        score: good,
        total: _words.length,
        durationSec: elapsed < 60 ? 60 : elapsed,
        createdAt: DateTime.now(),
        data: <String, dynamic>{'words': words, if (_topic != null) 'topic': _topic},
      ),
    );
    context.toast('Word set complete · $good of ${_words.length} clear');
    context.back();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    if (_playing == 'native') Tts.I.stop();
    _recTimer?.cancel();
    _clip.removeListener(_onClip);
    _clip.dispose();
    _rec.level.removeListener(_onLevel);
    final rec = _rec;
    rec.cancel().whenComplete(rec.dispose);
    super.dispose();
  }

  Map<String, dynamic> get _word =>
      _words.isEmpty ? <String, dynamic>{} : _words[_index];

  void _play(String which) {
    _playTimer?.cancel();
    if (_playing == which) {
      if (which == 'you') _clip.pause();
      if (which == 'native') Tts.I.stop();
      setState(() => _playing = null);
      return;
    }
    if (_playing == 'you') _clip.pause();
    if (_playing == 'native') Tts.I.stop();
    if (which == 'native') Tts.I.speak(_word.s('word'));
    final mine = which == 'you' ? _myAudio[_word.s('id')] : null;
    setState(() {
      _playing = which;
      _playProgress = 0;
    });
    if (mine != null) {
      _clipLoading = true;
      _clip.loadRecording(mine).then((ok) {
        _clipLoading = false;
        if (!mounted || _playing != 'you') return;
        if (ok) {
          _clip.play();
        } else {
          _simulatePlay();
        }
      });
      return;
    }
    _simulatePlay();
  }

  void _simulatePlay() {
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) return;
      setState(() {
        _playProgress += 0.03;
        if (_playProgress >= 1) {
          _playProgress = 0;
          _playing = null;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _startHold() async {
    if (_scoring || _recStarting || _recActive) return;
    // Free plan: 5 scored words.
    if (Entitlements.I.pronunciationUsedUp) {
      await showUpgradeSheet(context, feature: 'pronunciation');
      return;
    }
    _playTimer?.cancel();
    if (_playing == 'you') _clip.pause();
    setState(() {
      _holding = true;
      _live.clear();
      _playing = null;
    });
    _recStarting = true;
    final ok = await _rec.start();
    _recStarting = false;
    if (!mounted) return;
    if (!ok) {
      setState(() => _holding = false);
      // No microphone, no score (nothing is made up).
      await showMicOffDialog(context);
      return;
    }
    _recActive = true;
    // Released while the mic was starting → finish straight away.
    if (!_holding) await _finishRealTry();
  }

  void _endHold() {
    if (!_holding) return;
    setState(() => _holding = false);
    if (_recStarting) return;
    if (_recActive) _finishRealTry();
  }

  Future<void> _finishRealTry() async {
    if (!_recActive) return;
    _recActive = false;
    final w = _word;
    final id = w.s('id');
    setState(() => _scoring = true);
    final r = await _rec.stop();
    if (!mounted) return;
    final bytes = r?.bytes;
    if (r == null || bytes == null || r.durationMs < 250) {
      setState(() => _scoring = false);
      context.toast(
        r != null && r.durationMs < 250
            ? 'Hold the button while you say the word'
            : 'We couldn’t record that. Try again.',
      );
      return;
    }
    _myAudio[id] = r.path;
    final wave = _waveOf(bytes, _barCount);
    if (wave != null) setState(() => _myWave[id] = wave);
    final res = await AiService.scorePronunciation(word: w.s('word'), bytes: bytes);
    if (!mounted) return;
    setState(() => _scoring = false);
    if (res == null || res['score'] is! num) {
      // Not scored: say why (no made-up score).
      if (AiService.upgradeNeeded) {
        await showUpgradeSheet(context, feature: 'pronunciation');
      } else {
        context.toast(AiService.failure('We couldn’t score that word. Try again.').message);
      }
      return;
    }
    unawaited(Entitlements.I.refresh());
    final score = ((res['score'] as num).toDouble() / 100).clamp(0.0, 1.0).toDouble();
    _ai[id] = <String, dynamic>{'tip': res.s('tip'), 'heard': res.s('heard'), 'phonemes': res.l('phonemes')};
    _recordTry(aiScore: score, word: w);
    context.toast('Attempt scored');
  }

  void _goTo(int i) {
    _playTimer?.cancel();
    _recTimer?.cancel();
    if (_playing == 'you') _clip.pause();
    if (_recActive || _recStarting) {
      _recActive = false;
      _rec.cancel();
    }
    setState(() {
      _index = i;
      _playing = null;
      _holding = false;
    });
  }

  void _next() {
    if (_index >= _words.length - 1) {
      _finish();
      return;
    }
    _goTo(_index + 1);
  }

  void _showList() {
    final t = context.tk;
    showAppSheet<void>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Word list', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
          for (var i = 0; i < _words.length; i++)
            ListRow(
              divider: i > 0,
              title: _words[i].s('word'),
              subtitle: _words[i].s('ipa'),
              leading: LetterBadge('${i + 1}', size: 32, radius: 10),
              trailing: _scoresFor(_words[i].s('id')).isNotEmpty
                  ? Text(
                      '${(_scoresFor(_words[i].s('id')).last * 100).round()}%',
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    )
                  : (i == _index
                      ? Icon(AppIcons.checkCircle, size: 20, color: t.iconAccent)
                      : null),
              onTap: () {
                Navigator.of(context).pop();
                _goTo(i);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final w = _word;
    final tries = _pronTries(context.store, w.s('id'));
    final tried = tries.isNotEmpty;
    final match = tried ? tries.last : 0.0;
    final ai = _ai[w.s('id')];
    final aiTip = ai == null ? '' : ai.s('tip');
    final heard = ai == null ? '' : ai.s('heard');
    final sounds = ai == null ? <Map<String, dynamic>>[] : ai.l('phonemes');
    final tip = !tried
        ? 'Hold the button, say the word, then release to compare.'
        : (aiTip.isNotEmpty ? aiTip : w.s('tip'));

    return AppScreen(
      fill: true,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 20,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                spacing: 2,
                children: [
                  Text(
                    'Word ${_index + 1} of ${_words.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: t.textMuted),
                  ),
                  if (_daily)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _showTopics,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '${_topic ?? 'Today’s mix'} · Change',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.iconAccent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.grid,
              size: 56,
              radius: 20,
              iconSize: 22,
              tooltip: 'Word list',
              onTap: _showList,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  w.s('word'),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${w.s('ipa')} · ${w.s('pos')}',
                style: TextStyle(fontSize: 15, color: t.textMuted),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final syl in w.l('syllables'))
                  // A real try is shown sound by sound (the sample's "error"
                  // syllable was for the old simulated try).
                  _Syllable(
                    syllable: syl.s('state') == 'error'
                        ? <String, dynamic>{...syl, 'state': 'normal'}
                        : syl,
                  ),
              ],
            ),
            if (sounds.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final p in sounds) _SoundChip(sound: p)],
              ),
            if (heard.isNotEmpty)
              Text(
                'We heard “$heard”',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
          ],
        ),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 14,
            children: [
              IconBox(
                icon: _playing == 'native' ? AppIcons.pause : AppIcons.play,
                size: 52,
                circle: true,
                iconSize: 20,
                bg: t.peach,
                fg: kOnPeach,
                tooltip: 'Play native audio',
                onTap: () => _play('native'),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text('Native speaker', style: TextStyle(fontSize: 12, color: t.heroMuted)),
                    BarWave(
                      heights: _data.ld('nativeWave'),
                      color: t.heroText,
                      progress: _playing == 'native' ? _playProgress : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 14,
            children: [
              IconBox(
                icon: _playing == 'you' ? AppIcons.pause : AppIcons.play,
                size: 52,
                circle: true,
                iconSize: 20,
                bg: t.surfaceAlt,
                fg: t.text,
                tooltip: 'Play your audio',
                onTap: () => _play('you'),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text('You', style: TextStyle(fontSize: 12, color: t.textMuted)),
                    BarWave(
                      // Live mic level while held, then the real recording's
                      // waveform; the sample wave only for simulated tries.
                      heights: _holding && _live.isNotEmpty
                          ? <double>[..._live, ...List<double>.filled(_barCount - _live.length, 2)]
                          : _myWave[w.s('id')] ??
                              List<double>.filled(_barCount, 2),
                      color: t.isNight ? const Color(0xFFBDBDBD) : t.text,
                      highlightFrom: -1,
                      highlightTo: -1,
                      highlightColor: t.alert,
                      progress: _playing == 'you' ? _playProgress : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            spacing: 16,
            children: [
              RingProgress(
                value: match,
                size: 72,
                stroke: 7,
                track: t.isNight ? t.track : t.border,
                child: Text(
                  _scoring ? '…' : (tried ? '${(match * 100).round()}%' : '–'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sound match', style: TextStyle(fontSize: 16)),
                    Text(
                      tip,
                      style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => _startHold(),
                onTapUp: (_) => _endHold(),
                onTapCancel: _endHold,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 60,
                  decoration: BoxDecoration(
                    color: _holding ? t.alert : null,
                    gradient: _holding ? null : kPeachGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 10,
                    children: [
                      Icon(AppIcons.mic, size: 20, color: _holding ? t.onPrimary : kOnPeach),
                      Flexible(
                        child: Text(
                          _scoring
                              ? 'Scoring…'
                              : (_holding ? 'Recording… release to stop' : 'Hold to record'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _holding ? t.onPrimary : kOnPeach,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconBox(
              icon: AppIcons.forward,
              size: 60,
              circle: true,
              iconSize: 20,
              tooltip: 'Next word',
              onTap: _next,
            ),
          ],
        ),
      ],
    );
  }
}

/// Stored pronunciation tries for a word (oldest first).
List<double> _pronTries(Store store, String wordId) {
  final all = store.kv<Map>(kPronScoresKey);
  final v = all == null ? null : all[wordId];
  if (v is List) return v.whereType<num>().map((e) => e.toDouble()).toList();
  return <double>[];
}

/// One expected sound of the word, coloured by how clearly it came through
/// (score 0–100 from the speaking service; null = couldn't be aligned).
class _SoundChip extends StatelessWidget {
  const _SoundChip({required this.sound});

  final Map<String, dynamic> sound;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = sound['score'];
    final score = v is num ? v.toDouble() : null;
    final Color fg;
    final Color bg;
    if (score == null) {
      fg = t.textMuted;
      bg = t.raised;
    } else if (score >= 85) {
      fg = t.success;
      bg = t.successSoft;
    } else if (score >= 60) {
      fg = t.warning;
      bg = t.warning.withValues(alpha: 0.12);
    } else {
      fg = t.isNight ? t.dangerText : t.alert;
      bg = t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12);
    }
    return Tooltip(
      message: score == null ? 'Not scored' : '${score.round()}%',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(
          '/${sound.s('phoneme')}/',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg),
        ),
      ),
    );
  }
}

class _Syllable extends StatelessWidget {
  const _Syllable({required this.syllable});

  final Map<String, dynamic> syllable;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final state = syllable.s('state');
    Color bg = t.raised;
    Color fg = t.text;
    Border? border;
    FontWeight weight = FontWeight.w400;
    if (state == 'stress') {
      bg = t.primary;
      fg = t.onPrimary;
      weight = FontWeight.w600;
    } else if (state == 'error') {
      bg = t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12);
      fg = t.isNight ? t.dangerText : t.alert;
      border = Border.all(color: t.alert, width: 1.5);
    }
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          syllable.s('text'),
          style: TextStyle(fontSize: 16, fontWeight: weight, color: fg),
        ),
      ),
    );
  }
}
