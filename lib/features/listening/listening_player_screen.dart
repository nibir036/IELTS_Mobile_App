
import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// F2 · Listening Audio Player (audio playback + question panel).
class ListeningPlayerScreen extends StatefulWidget {
  const ListeningPlayerScreen({super.key});

  @override
  State<ListeningPlayerScreen> createState() => _ListeningPlayerScreenState();
}

class _ListeningPlayerScreenState extends State<ListeningPlayerScreen> {
  Map<String, dynamic> _set = <String, dynamic>{};
  List<ListeningItem> _items = <ListeningItem>[];
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};
  SimAudio? _audio;
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final args = context.routeArgs;
    final setId = args['setId'];
    final mode = args['mode'];
    ListeningSession.openPlayer(
      setId: setId is String ? setId : null,
      mode: mode is String ? mode : '',
      fresh: args['fresh'] == true,
    );
    _set = ListeningSession.playerSet;
    _items = ListeningSession.playerItems;
    final audio = SimAudio(
      duration: _set.d('durationSeconds'),
      start: ListeningSession.playerAudioSec,
      asset: Content.setAudio(_set),
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    _audio = audio;
    audio.play(notify: false);
  }

  @override
  void dispose() {
    final audio = _audio;
    if (audio != null) {
      if (audio.loaded) ListeningSession.playerAudioSec = audio.position;
      audio.dispose();
    }
    ListeningSession.savePlayer();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int n) => _controllers.putIfAbsent(
        n,
        () => TextEditingController(text: ListeningSession.playerAnswers[n] ?? ''),
      );

  void _submit() {
    FocusScope.of(context).unfocus();
    _audio?.pause();
    final a = ListeningSession.submitPlayer();
    context.replace(Routes.listeningResults, args: <String, dynamic>{'attemptId': a.id});
  }

  int get _currentIndex {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].contains(ListeningSession.playerCurrent)) return i;
    }
    return 0;
  }

  void _goTo(int index) {
    if (index < 0 || index >= _items.length) return;
    FocusScope.of(context).unfocus();
    setState(() => ListeningSession.playerCurrent = _items[index].number);
  }

  void _next() {
    final idx = _currentIndex;
    if (idx >= _items.length - 1) {
      _submit();
      return;
    }
    _goTo(idx + 1);
  }

  void _changed() {
    final audio = _audio;
    if (audio != null && audio.loaded) ListeningSession.playerAudioSec = audio.position;
    ListeningSession.savePlayer();
  }

  bool _answered(ListeningItem it) {
    for (final n in it.numbers) {
      if ((ListeningSession.playerAnswers[n] ?? '').trim().isEmpty) return false;
    }
    return true;
  }

  Widget _body(ListeningItem it, AppTokens t) {
    final answers = ListeningSession.playerAnswers;
    final n = it.number;
    switch (it.type) {
      case 'mcq':
      case 'matching':
      case 'multi':
      case 'map':
        final multi = it.type == 'multi';
        final chosen = multi
            ? multiChosen(it, answers)
            : <String>{(answers[n] ?? '').trim().toUpperCase()};
        // Plan labelling: the drawing (or the plan's orientation line) above;
        // each option is a letter with its written position.
        final plan = it.type == 'map' &&
            (it.group.s('image').isNotEmpty || it.group.s('layoutIntro').isNotEmpty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            if (plan) ListeningGroupContext(group: it.group, showOptions: false),
            Text(it.q.s('text'), style: const TextStyle(fontSize: 16, height: 1.4)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                for (final o in it.options)
                  ListeningOption(
                    letter: o.s('key'),
                    text: o.s('text'),
                    selected: chosen.contains(o.s('key').toUpperCase()),
                    onTap: () {
                      setState(() {
                        if (multi) {
                          toggleMultiLetter(it, answers, o.s('key'));
                        } else {
                          answers[n] = o.s('key');
                        }
                      });
                      _changed();
                    },
                  ),
              ],
            ),
          ],
        );
      default:
        // form / table: label, then before [gap] after; short answer: the
        // question, then the box; notes, sentences, summaries: text with a gap.
        final labelled = it.type == 'form' || it.type == 'table';
        final short = it.type == 'short';
        final (before, after) = labelled
            ? (it.q.s('before'), it.q.s('after'))
            : (short ? ('', '') : splitGap(it.q.s('text')));
        final heading = labelled ? it.q.s('label') : (short ? it.q.s('text') : '');
        final whole = it.type == 'table' ? 'table' : (it.type == 'summary' ? 'summary' : '');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            if (heading.isNotEmpty)
              Text(heading, style: const TextStyle(fontSize: 16, height: 1.4)),
            GapLine(
              before: before,
              after: after,
              gap: GapBox(
                number: n,
                value: (answers[n] ?? '').trim(),
                state: GapState.active,
                activeBorder: t.text,
                editor: GapEditor(
                  key: ValueKey<int>(n),
                  controller: _controllerFor(n),
                  onChanged: (v) {
                    answers[n] = v;
                    setState(() {});
                  },
                  onSubmitted: (_) {
                    _changed();
                    _next();
                  },
                ),
              ),
            ),
            if (whole.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: LinkText(
                  'See the whole $whole',
                  fontSize: 13,
                  onTap: () => showAppSheet<void>(
                    context,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        ListeningGroupContext(
                          group: it.group,
                          answers: ListeningSession.playerAnswers,
                          current: n,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final audio = _audio;
    if (_items.isEmpty || audio == null) {
      return AppScreen(
        gap: 16,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          ListeningHeader(title: 'Listening', onLeading: () => context.back()),
          EmptyState(
            title: 'Set not found',
            message: 'This practice set is not available any more.',
            icon: AppIcons.listening,
            actionLabel: 'All sets',
            onAction: () => context.replace(Routes.listeningMiniList),
          ),
        ],
      );
    }
    final idx = _currentIndex;
    final it = _items[idx];
    final n = it.number;
    final bookmarked = ListeningSession.playerBookmarks.contains(n);
    final last = _items.last.last;
    final instruction = it.group.s('instruction');

    return AppScreen(
      gap: 16,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footer: Row(
        spacing: 10,
        children: [
          IconBox(
            icon: AppIcons.chevronLeft,
            tooltip: 'Previous question',
            size: 56,
            radius: 20,
            iconSize: 24,
            onTap: idx == 0 ? null : () => _goTo(idx - 1),
          ),
          Expanded(
            child: PrimaryButton(
              label: idx >= _items.length - 1 ? 'Submit' : 'Next question',
              trailing: AppIcons.forward,
              height: 56,
              radius: 999,
              onTap: _next,
            ),
          ),
        ],
      ),
      children: [
        ListeningHeader(
          title: '${ListeningSession.playerMode} · Part ${_set.i('part')}',
          subtitle: _set.s('context'),
          onLeading: () => context.back(),
          trailingIcon: AppIcons.article,
          trailingTooltip: 'Transcript',
          onTrailing: () {
            audio.pause();
            context.push(
              Routes.listeningTranscript,
              args: <String, dynamic>{'setId': ListeningSession.playerSetId},
            );
          },
        ),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => showListeningSetInfo(context, _set),
                          child: Row(
                            spacing: 6,
                            children: [
                              Flexible(
                                child: Text(
                                  isBankSet(_set)
                                      ? '${_set.s('code')} · ${listeningFormatLabel(_set.s('formatCode'))} · ${listeningSpeakers(_set)}'
                                      : 'Part ${_set.i('part')} · ${listeningSpeakers(_set)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: t.heroMuted),
                                ),
                              ),
                              Icon(AppIcons.info, size: 14, color: t.heroMuted),
                            ],
                          ),
                        ),
                        Text(
                          _set.s('title'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            height: 1.15,
                            letterSpacing: -0.4,
                            color: t.heroText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SpeedPill(
                    speed: audio.speed,
                    fontSize: 13,
                    onTap: () => setState(() => audio.speed = nextSpeed(audio.speed)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  WaveformBars(
                    count: 45,
                    height: 40,
                    progress: audio.progress,
                    color: t.heroTrack,
                    playedColor: t.heroFill,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          timeLabel(audio.position),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text(
                        timeLabel(audio.loaded ? audio.duration : _set.d('durationSeconds')),
                        style: TextStyle(
                          fontSize: 13,
                          color: t.heroMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _fit(
                    13,
                    _HeroKey(
                      tooltip: 'Playback speed 0.75',
                      selected: audio.speed == 0.75,
                      onTap: () => setState(() => audio.speed = 0.75),
                      child: const Text('0.75'),
                    ),
                  ),
                  _fit(
                    13,
                    _HeroKey(
                      tooltip: 'Back 10 seconds',
                      onTap: () => audio.skip(-10),
                      child: const Icon(AppIcons.rewind10, size: 22),
                    ),
                  ),
                  _fit(
                    18,
                    DarkPlayButton(
                      playing: audio.playing,
                      loading: audio.loading,
                      size: 72,
                      radius: 26,
                      iconSize: 32,
                      onTap: audio.toggle,
                    ),
                  ),
                  _fit(
                    13,
                    _HeroKey(
                      tooltip: 'Forward 10 seconds',
                      onTap: () => audio.skip(10),
                      child: const Icon(AppIcons.forward10, size: 22),
                    ),
                  ),
                  _fit(
                    13,
                    _HeroKey(
                      tooltip: 'Playback speed 1.25',
                      selected: audio.speed == 1.25,
                      onTap: () => setState(() => audio.speed = 1.25),
                      child: const Text('1.25'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < _items.length; i++)
                _QChip(
                  label: _items[i].label,
                  current: i == idx,
                  answered: _answered(_items[i]),
                  onTap: () => _goTo(i),
                ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${it.span > 1 ? 'Questions' : 'Question'} ${it.label} of $last · ${it.group.s('title')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() {
                      if (bookmarked) {
                        ListeningSession.playerBookmarks.remove(n);
                      } else {
                        ListeningSession.playerBookmarks.add(n);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        bookmarked ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                        size: 18,
                        color: t.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (instruction.isNotEmpty)
                Text(instruction, style: TextStyle(fontSize: 12, color: t.textMuted)),
              _body(it, t),
            ],
          ),
        ),
      ],
    );
  }
}

/// 52px translucent key on the hero card (speed / skip).
/// Lets a fixed-size control shrink (never grow) when the row is too narrow;
/// [flex] is proportional to the control's natural width.
Widget _fit(int flex, Widget child) => Flexible(
      flex: flex,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );

class _HeroKey extends StatelessWidget {
  const _HeroKey({
    required this.child,
    required this.tooltip,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.heroChip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: selected ? BorderSide(color: t.peach, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: t.heroText,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: t.heroText),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QChip extends StatelessWidget {
  const _QChip({
    required this.label,
    required this.current,
    required this.answered,
    this.onTap,
  });

  final String label;
  final bool current;
  final bool answered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg = Colors.transparent;
    Color fg = t.textMuted;
    BorderSide side = BorderSide(color: t.border);
    if (current) {
      bg = t.text;
      fg = t.onPrimary;
      side = BorderSide.none;
    } else if (answered) {
      bg = t.isNight ? t.surfaceAlt2 : t.surface;
      side = BorderSide.none;
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    color: fg,
                  ),
                ),
              ),
              if (answered && !current)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
