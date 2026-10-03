
import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// F4 · Listening Transcript & Audio Sync.
class ListeningTranscriptScreen extends StatefulWidget {
  const ListeningTranscriptScreen({super.key});

  @override
  State<ListeningTranscriptScreen> createState() => _ListeningTranscriptScreenState();
}

class _ListeningTranscriptScreenState extends State<ListeningTranscriptScreen> {
  /// Sets shown (one, or the 4 parts of a full test) with their offsets.
  List<(Map<String, dynamic>, int)> _sets = <(Map<String, dynamic>, int)>[];
  int _index = 0;
  Map<String, dynamic> _set = <String, dynamic>{};
  int _offset = 0;
  List<Map<String, dynamic>> _lines = <Map<String, dynamic>>[];
  List<GlobalKey> _keys = <GlobalKey>[];
  SimAudio? _audioOrNull;
  bool _opened = false;

  static const _sizeKey = 'listening.transcriptSize';
  static const _answersKey = 'listening.transcriptAnswers';

  bool _keywords = true;
  bool _answers = Store.I.kv<bool>(_answersKey) ?? true;
  bool _autoScroll = true;
  bool _loop = false;
  int _loopLine = -1;
  int _currentLine = -1;

  SimAudio get _audio => _audioOrNull!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final args = context.routeArgs;
    final setId = args['setId'] is String ? args['setId'] as String : '';
    final testId = args['testId'] is String ? args['testId'] as String : '';
    var index = 0;
    if (setId.isNotEmpty && Content.listeningSet(setId).isNotEmpty) {
      _sets = listeningSetsFor(setId: setId);
    } else if (testId.isNotEmpty && Content.listeningTest(testId).isNotEmpty) {
      _sets = listeningSetsFor(testId: testId);
      final p = args['part'];
      if (p is int) index = p;
    } else if (ListeningSession.sheetActive && ListeningSession.sheetSets.isNotEmpty) {
      // Current part of the open answer sheet.
      _sets = ListeningSession.sheetSets;
      index = ListeningSession.sheetPart;
    } else {
      final id = ListeningSession.playerSetId.isNotEmpty
          ? ListeningSession.playerSetId
          : ListeningSession.nextSetId();
      _sets = listeningSetsFor(setId: id);
    }
    _load(index < 0 || index >= _sets.length ? 0 : index, autoplay: true);
  }

  void _load(int index, {bool autoplay = false}) {
    _audioOrNull?.dispose();
    _index = index;
    _set = _sets.isEmpty ? <String, dynamic>{} : _sets[index].$1;
    _offset = _sets.isEmpty ? 0 : _sets[index].$2;
    _lines = _set.l('transcript');
    _keys = List<GlobalKey>.generate(_lines.length, (_) => GlobalKey());
    _loop = false;
    _loopLine = -1;
    final audio = SimAudio(
      duration: _set.d('durationSeconds'),
      asset: Content.setAudio(_set),
      onTick: _onTick,
    );
    _audioOrNull = audio;
    _currentLine = _lineAt(0);
    if (autoplay) audio.play(notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: false));
  }

  void _switchPart(int index) {
    if (index == _index || index < 0 || index >= _sets.length) return;
    setState(() => _load(index, autoplay: true));
  }

  @override
  void dispose() {
    _audioOrNull?.dispose();
    super.dispose();
  }

  int _lineAt(double pos) {
    var idx = -1;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].d('start') <= pos) idx = i;
    }
    return idx;
  }

  double _lineEnd(int i) =>
      i + 1 < _lines.length ? _lines[i + 1].d('start') : _audio.duration;

  void _onTick() {
    if (!mounted || _audioOrNull == null) return;
    if (_loop && _loopLine >= 0 && _loopLine < _lines.length && _audio.loaded) {
      // Loop line: jump back to the line's start once playback passes its end.
      final ended = _audio.completed;
      if (ended || (_audio.playing && _audio.position >= _lineEnd(_loopLine) - 0.05)) {
        _audio.seek(_lines[_loopLine].d('start'));
        if (ended) _audio.play();
      }
    }
    // Current line = last line whose start <= position (or the looped line).
    final idx = _loop && _loopLine >= 0 ? _loopLine : _lineAt(_audio.position);
    final changed = idx != _currentLine;
    setState(() => _currentLine = idx);
    if (changed && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _scrollToCurrent({bool animate = true}) {
    if (!mounted || _currentLine < 0 || _currentLine >= _keys.length) return;
    final ctx = _keys[_currentLine].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  void _seekFraction(double f) {
    if (!_audio.loaded) return;
    final to = _audio.duration * f;
    if (_loop) _loopLine = _lineAt(to);
    _audio.seek(to);
  }

  void _seekLine(int i) {
    if (!_audio.loaded) return;
    if (_loop) _loopLine = i;
    _audio.seek(_lines[i].d('start'));
    if (!_audio.playing) _audio.play();
  }

  void _toggleLoop() {
    setState(() {
      _loop = !_loop;
      _loopLine = _loop ? (_currentLine >= 0 ? _currentLine : (_lines.isEmpty ? -1 : 0)) : -1;
    });
  }

  /// 'small' | 'normal' | 'large' (kv `listening.transcriptSize`).
  String get _size {
    final v = Store.I.kv<String>(_sizeKey);
    return v == 'small' || v == 'large' ? v! : 'normal';
  }

  double get _scale => switch (_size) {
        'small' => 0.87,
        'large' => 1.2,
        _ => 1.0,
      };

  void _setAnswers(bool on) {
    setState(() => _answers = on);
    Store.I.setKv(_answersKey, on);
  }

  /// The current part's transcript as plain text.
  String _plainText() {
    final b = StringBuffer('Part ${_set.i('part')} · ${_set.s('title')}\n\n');
    for (final l in _lines) {
      b.writeln('[${timeLabel(l.d('start'))}] ${l.s('speaker')}: ${l.s('text')}');
    }
    return b.toString().trim();
  }

  void _replayFromStart() {
    if (!_audio.loaded) {
      context.toast('Audio is still loading');
      return;
    }
    if (_loop) _loopLine = _lines.isEmpty ? -1 : 0;
    _audio.seek(0);
    _audio.play();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _openMore() {
    showAppSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setSheet) {
          final t = ctx.tk;
          final size = _size;
          const sizes = <String>['small', 'normal', 'large'];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Transcript options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              ListRow(
                title: 'Copy transcript',
                subtitle: 'Part ${_set.i('part')} · ${_lines.length} lines',
                leading: IconCircle(AppIcons.doc, size: 40, bg: t.surfaceAlt, fg: t.iconAccent),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ShareService.copy(context, _plainText(), message: 'Transcript copied');
                },
              ),
              ListRow(
                title: 'Replay audio from start',
                subtitle: _audio.loaded ? 'Restart Part ${_set.i('part')} at 0:00' : 'Audio is loading…',
                leading: IconCircle(AppIcons.replay, size: 40, bg: t.surfaceAlt, fg: t.iconAccent),
                divider: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _replayFromStart();
                },
              ),
              ListRow(
                title: 'Answer highlights',
                subtitle: _answers ? 'Question tags are shown in the text' : 'Question tags are hidden',
                leading: IconCircle(AppIcons.highlight, size: 40, bg: t.surfaceAlt, fg: t.iconAccent),
                divider: true,
                trailing: _MiniSwitch(on: _answers),
                onTap: () {
                  _setAnswers(!_answers);
                  setSheet(() {});
                },
              ),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.divider)),
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    IconCircle(AppIcons.textFields, size: 40, bg: t.surfaceAlt, fg: t.iconAccent),
                    const Expanded(
                      child: Text('Text size', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              SegmentedTabs(
                labels: const <String>['Small', 'Normal', 'Large'],
                index: sizes.indexOf(size),
                onChanged: (i) {
                  Store.I.setKv(_sizeKey, sizes[i]);
                  setState(() {});
                  setSheet(() {});
                },
              ),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }

  void _backToAnswers() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.replace(
        Routes.listeningPlayer,
        args: <String, dynamic>{'setId': _set.s('id')},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppScreen(
      scroll: false,
      gap: 16,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SoftButton(
              label: _loop ? 'Looping line' : 'Loop line',
              leading: _loop ? AppIcons.replay : null,
              height: 56,
              fontSize: 15,
              expand: true,
              bg: t.raised,
              onTap: _toggleLoop,
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'Back to answers',
              height: 56,
              radius: 999,
              fontSize: 15,
              onTap: _backToAnswers,
            ),
          ),
        ],
      ),
      children: [
        ListeningHeader(
          title: 'Transcript',
          subtitle: 'Part ${_set.i('part')} · ${_set.s('title')}',
          onLeading: () => context.back(),
          trailingIcon: AppIcons.more,
          trailingTooltip: 'More',
          onTrailing: _openMore,
        ),
        if (_sets.length > 1)
          OutlineChipRow(
            labels: <String>[for (final e in _sets) 'Part ${e.$1.i('part')}'],
            selected: _index,
            onChanged: _switchPart,
          ),
        HeroCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            spacing: 12,
            children: [
              DarkPlayButton(
                playing: _audio.playing,
                loading: _audio.loading,
                onTap: _audio.toggle,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            timeLabel(_audio.position),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: t.heroText,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Text(
                          timeLabel(_audio.duration),
                          style: TextStyle(fontSize: 12, color: t.heroMuted),
                        ),
                      ],
                    ),
                    _SeekBar(progress: _audio.progress, onSeek: _seekFraction),
                  ],
                ),
              ),
              SpeedPill(
                speed: _audio.speed,
                onTap: () => setState(() => _audio.speed = nextSpeed(_audio.speed)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _ToggleChip(
              label: 'Keywords',
              selected: _keywords,
              onTap: () => setState(() => _keywords = !_keywords),
            ),
            const SizedBox(width: 6),
            _ToggleChip(
              label: 'Answers',
              selected: _answers,
              onTap: () => _setAnswers(!_answers),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _autoScroll = !_autoScroll);
                      if (_autoScroll) _scrollToCurrent();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Text(
                          'Auto-scroll',
                          maxLines: 1,
                          style: TextStyle(fontSize: 13, color: t.textMuted),
                        ),
                        _MiniSwitch(on: _autoScroll),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      if (_lines.isEmpty)
                        const EmptyState(
                          icon: AppIcons.article,
                          title: 'No transcript for this recording',
                          message: 'You can still play the audio here and check your answers against the key.',
                        ),
                      for (var i = 0; i < _lines.length; i++)
                        KeyedSubtree(
                          key: _keys[i],
                          child: _LineView(
                            line: _lines[i],
                            offset: _offset,
                            state: i == _currentLine
                                ? _LineState.current
                                : (i < _currentLine ? _LineState.past : _LineState.future),
                            showKeywords: _keywords,
                            showAnswers: _answers,
                            scale: _scale,
                            onTap: () => _seekLine(i),
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
                height: 90,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.9],
                        colors: [t.bg.withValues(alpha: 0), t.bg],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _LineState { past, current, future }

class _LineView extends StatelessWidget {
  const _LineView({
    required this.line,
    this.offset = 0,
    required this.state,
    required this.showKeywords,
    required this.showAnswers,
    this.scale = 1.0,
    this.onTap,
  });

  final Map<String, dynamic> line;

  /// Added to local question numbers (Part 2 of a full test → +10).
  final int offset;
  final _LineState state;
  final bool showKeywords;
  final bool showAnswers;

  /// Text size factor (Small / Normal / Large).
  final double scale;
  final VoidCallback? onTap;

  List<InlineSpan> _spans(AppTokens t, bool current) {
    final text = line.s('text');
    final keywords = showKeywords ? line.ls('keywords') : <String>[];
    final tags = showAnswers ? line.l('answerTags') : <Map<String, dynamic>>[];

    // Collect marks: keyword ranges and tag insert positions.
    final ranges = <(int, int)>[];
    for (final k in keywords) {
      final idx = text.indexOf(k);
      if (idx >= 0) ranges.add((idx, idx + k.length));
    }
    final inserts = <(int, int)>[]; // (position, question)
    for (final tag in tags) {
      final after = tag.s('after');
      final idx = text.indexOf(after);
      if (idx >= 0) inserts.add((idx + after.length, tag.i('question') + offset));
    }
    final cuts = <int>{0, text.length};
    for (final r in ranges) {
      cuts
        ..add(r.$1)
        ..add(r.$2);
    }
    for (final ins in inserts) {
      cuts.add(ins.$1);
    }
    final sorted = cuts.toList()..sort();

    final underline = current ? t.heroText : const Color(0xFFF6ECC8);
    final tagBg = current ? kInk : t.primary;
    final tagFg = current ? kCream : t.onPrimary;

    final out = <InlineSpan>[];
    for (var i = 0; i < sorted.length; i++) {
      final pos = sorted[i];
      for (final ins in inserts) {
        if (ins.$1 == pos) {
          out.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.only(left: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Q${ins.$2}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tagFg),
              ),
            ),
          ));
        }
      }
      if (i == sorted.length - 1) break;
      final end = sorted[i + 1];
      if (end <= pos) continue;
      final inKeyword = ranges.any((r) => r.$1 <= pos && end <= r.$2);
      out.add(TextSpan(
        text: text.substring(pos, end),
        style: inKeyword
            ? TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: underline,
                decorationThickness: 2,
              )
            : null,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final time = timeLabel(line.d('start'));
    if (state == _LineState.current) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: t.heroGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.s('speaker'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.heroText,
                        ),
                      ),
                    ),
                    Text(time, style: TextStyle(fontSize: 12, color: t.heroMuted)),
                  ],
                ),
                Text.rich(
                  TextSpan(children: _spans(t, true)),
                  style: TextStyle(fontSize: 16 * scale, height: 1.5, color: t.heroText),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final past = state == _LineState.past;
    final bodyColor = past
        ? (t.isNight ? t.textSoft : t.text)
        : (t.isNight ? t.textFaint : t.textMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.s('speaker'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.textMuted,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: t.isNight ? t.textFaint : t.textMuted,
                  ),
                ),
              ],
            ),
            Text.rich(
              TextSpan(children: _spans(t, false)),
              style: TextStyle(fontSize: 15 * scale, height: 1.5, color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? t.text : t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: selected ? t.text : t.textMuted),
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40,
      height: 24,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? t.primary : t.border,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: on ? t.onPrimary : t.surface,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.progress, required this.onSeek});

  final double progress;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final x = w * progress;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (w > 0) onSeek((d.localPosition.dx / w).clamp(0.0, 1.0).toDouble());
          },
          onHorizontalDragUpdate: (d) {
            if (w > 0) onSeek((d.localPosition.dx / w).clamp(0.0, 1.0).toDouble());
          },
          child: SizedBox(
            height: 12,
            width: w,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 4,
                  child: ProgressBar(value: progress, onHero: true),
                ),
                Positioned(
                  left: (x - 6).clamp(-6.0, w - 6).toDouble(),
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: t.heroFill, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
