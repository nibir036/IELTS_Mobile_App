import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/tokens.dart';
import 'app_icons.dart';
import 'kit.dart';
import 'mascot.dart';

// The first-time tour: Nexi walks a new student through the app.
//
// The screen dims, one real part of it is lit up, and a card next to it
// says what it is. Some steps are read ("Next"); others ask the student to
// tap the lit-up button themselves - the real button, so the tab really
// opens - and the tour moves on once they do.
//
//   AppTour.I                  which tour is running and which step.
//   TourTarget(id: ..)         marks a widget the tour can point at.
//   TourLayer                  draws the tour over the whole app
//                              (MaterialApp.builder, app.dart).
//
// Each tour runs once per install (startOnce) and can be replayed from
// Profile (start). The steps live in features/shell/app_tours.dart.

/// What moves a step on.
enum TourAction {
  /// The student reads it and presses Next.
  next,

  /// The student taps the lit-up widget itself.
  tap,
}

/// One stop on a tour.
class TourStep {
  const TourStep({
    this.target,
    required this.title,
    required this.body,
    this.action = TourAction.next,
    this.pose = NexiPose.point,
    this.button = 'Next',
    this.radius = 22,
    this.pad = 6,
    this.when,
  });

  /// [TourTarget.id] to light up; null = a card in the middle of the screen.
  final String? target;
  final String title;
  final String body;
  final TourAction action;
  final NexiPose pose;

  /// Label of the button on a [TourAction.next] step.
  final String button;

  /// Corner radius and margin of the lit-up hole around the target.
  final double radius;
  final double pad;

  /// Shown only when this returns true (e.g. study-abroad access).
  final bool Function()? when;
}

/// The running tour.
class AppTour extends ChangeNotifier {
  AppTour._();

  static final AppTour I = AppTour._();

  static const String ielts = 'ielts';
  static const String abroad = 'abroad';

  static String _seenKey(String id) => 'tour_seen_${id}_v1';

  final Map<String, List<GlobalKey>> _targets = <String, List<GlobalKey>>{};
  String? _tour;
  List<TourStep> _steps = const <TourStep>[];
  int _index = 0;

  bool get active => _tour != null;
  int get index => _index;
  int get count => _steps.length;

  /// Steps actually shown (the [TourStep.when] ones that pass), for the dots.
  int get shownCount => _steps.where((s) => s.when?.call() ?? true).length;
  int get shownIndex => _steps.take(_index).where((s) => s.when?.call() ?? true).length;

  TourStep? get step => active && _index >= 0 && _index < _steps.length ? _steps[_index] : null;
  bool get isLast {
    for (var i = _index + 1; i < _steps.length; i++) {
      if (_steps[i].when?.call() ?? true) return false;
    }
    return true;
  }

  void _register(String id, GlobalKey key) => (_targets[id] ??= <GlobalKey>[]).add(key);

  void _unregister(String id, GlobalKey key) {
    final list = _targets[id];
    if (list == null) return;
    list.remove(key);
    if (list.isEmpty) _targets.remove(id);
  }

  /// Every mounted widget marked [id], newest last.
  List<BuildContext> contextsOf(String id) => <BuildContext>[
        for (final k in _targets[id] ?? const <GlobalKey>[])
          if (k.currentContext != null) k.currentContext!,
      ];

  Future<bool> seen(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_seenKey(id)) ?? false;
    } catch (_) {
      return true; // No storage: better no tour than one on every open.
    }
  }

  /// Runs [id] once per install, as soon as [ready] says its screen is up.
  Future<void> startOnce(String id, List<TourStep> Function() steps, {required bool Function() ready}) async {
    if (active || await seen(id)) return;
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (active) return;
      if (ready()) {
        start(id, steps());
        return;
      }
    }
  }

  /// Starts [id] now (also the "Replay the tour" rows).
  void start(String id, List<TourStep> steps) {
    if (steps.isEmpty) return;
    _tour = id;
    _steps = steps;
    _index = -1;
    _advance();
  }

  void next() {
    if (!active) return;
    HapticFeedback.selectionClick();
    _advance();
  }

  void _advance() {
    var i = _index + 1;
    while (i < _steps.length && !(_steps[i].when?.call() ?? true)) {
      i++;
    }
    if (i >= _steps.length) {
      unawaited(finish());
      return;
    }
    _index = i;
    notifyListeners();
  }

  /// Ends the tour (done or skipped); it won't start by itself again.
  Future<void> finish() async {
    final id = _tour;
    if (id == null) return;
    _tour = null;
    _steps = const <TourStep>[];
    _index = 0;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_seenKey(id), true);
    } catch (_) {}
  }
}

/// Marks [child] as something a tour step can light up. A null [id] marks
/// nothing (handy inside loops).
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.id, required this.child});

  final String? id;
  final Widget child;

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (id != null) AppTour.I._register(id, _key);
  }

  @override
  void didUpdateWidget(TourTarget old) {
    super.didUpdateWidget(old);
    if (old.id == widget.id) return;
    final was = old.id, now = widget.id;
    if (was != null) AppTour.I._unregister(was, _key);
    if (now != null) AppTour.I._register(now, _key);
  }

  @override
  void dispose() {
    final id = widget.id;
    if (id != null) AppTour.I._unregister(id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

/// Puts the running tour over [child] (the whole app).
class TourLayer extends StatelessWidget {
  const TourLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: AppTour.I,
            builder: (context, _) => AppTour.I.active ? const _TourOverlay() : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay();

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);

  /// Where the target is now, and the hole as drawn (it glides after it).
  Rect? _target;
  Rect? _shown;

  Duration _now = Duration.zero;
  Duration _stepStart = Duration.zero;
  int _step = -2;
  bool _revealed = false;
  bool _moving = false;
  Offset? _down;

  /// How long a step waits for its target (a tab sliding in, a list
  /// loading) before it carries on without the spotlight.
  static const Duration _patience = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    AppTour.I.addListener(_onTour);
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _onTour();
    _ticker.start();
  }

  @override
  void dispose() {
    AppTour.I.removeListener(_onTour);
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _ticker.dispose();
    super.dispose();
  }

  /// The phone's back button ends the tour instead of moving the app.
  @override
  Future<bool> didPopRoute() async {
    if (!AppTour.I.active) return false;
    unawaited(AppTour.I.finish());
    return true;
  }

  void _onTour() {
    if (AppTour.I.index == _step) return;
    _step = AppTour.I.index;
    _stepStart = _now;
    _revealed = false;
    _moving = false;
    _down = null;
    _target = null;
    if (AppTour.I.step?.target == null) _shown = null;
    if (mounted) setState(() {});
  }

  RenderBox? get _box {
    final b = context.findRenderObject();
    return b is RenderBox && b.hasSize ? b : null;
  }

  /// The target's rectangle in this layer, or null while it isn't on a
  /// page that is showing (a tab still sliding in counts as showing).
  Rect? _locate(String id) {
    final me = _box;
    if (me == null) return null;
    final contexts = AppTour.I.contextsOf(id);
    for (final c in contexts.reversed) {
      final b = c.findRenderObject();
      if (b is! RenderBox || !b.attached || !b.hasSize || b.size.isEmpty) continue;
      final topLeft = me.globalToLocal(b.localToGlobal(Offset.zero));
      final r = topLeft & b.size;
      // A tab kept alive beside the one showing sits off to the side.
      if (r.right <= 0 || r.left >= me.size.width) continue;
      return r;
    }
    return null;
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    final step = AppTour.I.step;
    final id = step?.target;
    final r = id == null ? null : _locate(id);
    if (id != null && r != null && !_revealed) {
      _revealed = true;
      _reveal(id, r);
    }
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (r != null) {
      final s = _shown;
      _shown = s == null || reduce ? r : Rect.lerp(s, r, 0.24);
    } else if (id == null) {
      _shown = null;
    }
    _target = r;
    setState(() {});
  }

  /// Scrolls the target into view, clear of the status bar and the nav.
  void _reveal(String id, Rect r) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final low = size.height - pad.bottom - 120;
    if (r.top >= pad.top + 8 && r.bottom <= low) return;
    final contexts = AppTour.I.contextsOf(id);
    if (contexts.isEmpty) return;
    unawaited(Scrollable.ensureVisible(
      contexts.last,
      alignment: 0.28,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    ).catchError((Object _) {}));
  }

  Rect? get _hole {
    final step = AppTour.I.step;
    final r = _target;
    return step == null || r == null ? null : r.inflate(step.pad);
  }

  /// A tap on the lit-up widget (it goes through to the widget itself)
  /// moves a [TourAction.tap] step on once the tab has had time to open.
  void _onPointer(PointerEvent e) {
    final step = AppTour.I.step;
    if (step == null || step.action != TourAction.tap || _moving) return;
    final hole = _hole, me = _box;
    if (hole == null || me == null) return;
    final p = me.globalToLocal(e.position);
    if (e is PointerDownEvent) {
      _down = hole.contains(p) ? p : null;
    } else if (e is PointerUpEvent) {
      final d = _down;
      _down = null;
      if (d == null || !hole.contains(p) || (p - d).distance > 24) return;
      _moving = true;
      final at = AppTour.I.index;
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (AppTour.I.active && AppTour.I.index == at) AppTour.I.next();
      });
    } else if (e is PointerCancelEvent) {
      _down = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tour = AppTour.I;
    final step = tour.step;
    if (step == null) return const SizedBox.shrink();
    final t = context.tk;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);

    final hole = _hole;
    final drawn = _shown?.inflate(step.pad);
    final onScreen = hole != null && hole.bottom > pad.top && hole.top < size.height - pad.bottom;
    final waiting = step.target != null && !onScreen && _now - _stepStart < _patience;
    // The target never showed: carry on without the spotlight.
    final lost = step.target != null && !onScreen && !waiting;
    final tapHere = step.action == TourAction.tap && !lost;
    final pulse = (math.sin(_now.inMilliseconds / 1000 * 2 * math.pi / 1.3) + 1) / 2;

    final card = _TourCard(
      key: ValueKey<int>(tour.index),
      step: step,
      dot: tour.shownIndex,
      dots: tour.shownCount,
      last: tour.isLast,
      tapHere: tapHere,
      big: step.target == null || lost,
      onNext: tour.next,
      onSkip: () => unawaited(tour.finish()),
    );

    Widget placed;
    if (waiting) {
      placed = const SizedBox.shrink();
    } else if (!onScreen) {
      placed = Positioned(
        left: 16,
        right: 16,
        top: pad.top + 16,
        bottom: pad.bottom + 16,
        child: Center(child: _enter(card)),
      );
    } else {
      final spot = hole!;
      // The card goes on the roomier side of the lit-up widget.
      final below = size.height - pad.bottom - spot.bottom;
      final above = spot.top - pad.top;
      final goAbove = above > below;
      final room = (goAbove ? above : below) - 14;
      if (room < 190) {
        // Too tall to sit beside: the card covers the bottom of the screen.
        placed = Positioned(left: 16, right: 16, bottom: pad.bottom + 16, child: _enter(card));
      } else {
        placed = Positioned(
          left: 16,
          right: 16,
          top: goAbove ? null : spot.bottom + 14,
          bottom: goAbove ? size.height - spot.top + 14 : null,
          child: _enter(card),
        );
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: _Barrier(
        // Only a "tap it yourself" step lets taps through to the widget.
        hole: tapHere && onScreen ? hole : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _Spotlight(
                  // While the next target slides in, the last hole stays put.
                  hole: onScreen || waiting ? drawn : null,
                  radius: step.radius,
                  dim: Colors.black.withValues(alpha: t.isNight ? 0.72 : 0.62),
                  ring: tapHere && onScreen ? pulse : null,
                  ringColor: t.peach,
                ),
              ),
            ),
            placed,
          ],
        ),
      ),
    );
  }

  Widget _enter(Widget card) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: card,
      );
}

/// Takes every tap except those on [hole], which go to the app beneath.
class _Barrier extends SingleChildRenderObjectWidget {
  const _Barrier({required this.hole, super.child});

  final Rect? hole;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarrier(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderBarrier renderObject) => renderObject.hole = hole;
}

class _RenderBarrier extends RenderProxyBox {
  _RenderBarrier(this.hole);

  Rect? hole;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final h = hole;
    if (h != null && h.contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => true;
}

/// The dimmed screen with a rounded hole over the target, and a ring that
/// pulses out of it when the student should tap.
class _Spotlight extends CustomPainter {
  _Spotlight({required this.hole, required this.radius, required this.dim, required this.ring, required this.ringColor});

  final Rect? hole;
  final double radius;
  final Color dim;
  final double? ring;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final h = hole;
    if (h == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = dim);
      return;
    }
    final rr = RRect.fromRectAndRadius(h, Radius.circular(radius));
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rr);
    canvas.drawPath(shade, Paint()..color = dim);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    final r = ring;
    if (r != null) {
      canvas.drawRRect(
        rr.inflate(3 + 12 * r),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ringColor.withValues(alpha: 0.9 * (1 - r)),
      );
    }
  }

  @override
  bool shouldRepaint(_Spotlight old) => true;
}

/// Nexi, the step's words, the progress dots and the buttons.
class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.dot,
    required this.dots,
    required this.last,
    required this.tapHere,
    required this.big,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int dot;
  final int dots;
  final bool last;
  final bool tapHere;
  final bool big;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final card = Color.alphaBlend(t.surface, t.bg);
    return Semantics(
      liveRegion: true,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: t.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (big) ...[
                    Center(child: Nexi(step.pose, height: 104)),
                    const SizedBox(height: 8),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: t.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, height: 1.45, color: t.textSoft),
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        Nexi(step.pose, height: 62),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: t.text),
                              ),
                              Text(
                                step.body,
                                style: TextStyle(fontSize: 13.5, height: 1.42, color: t.textSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Dots(index: dot, count: dots),
                      const Spacer(),
                      if (!last)
                        TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                            foregroundColor: t.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('Skip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      const SizedBox(width: 4),
                      if (tapHere)
                        const _TapHint()
                      else
                        PrimaryButton(
                          label: step.button,
                          trailing: last ? null : AppIcons.forward,
                          height: 42,
                          fontSize: 14,
                          expand: false,
                          onTap: onNext,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Tap it" with a finger that nudges towards the lit-up widget.
class _TapHint extends StatefulWidget {
  const _TapHint();

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.peach.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.peach.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -3 * Curves.easeInOut.transform(_c.value)),
              child: child,
            ),
            child: Icon(Icons.touch_app_rounded, size: 20, color: t.text),
          ),
          Text('Tap it', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Text(
      '${index + 1} of $count',
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.textMuted),
    );
  }
}
