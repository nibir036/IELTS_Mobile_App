import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small motion helpers that make the app feel alive: a press "squish" on
/// everything tappable, gentle floating, count-up numbers, a shine sweep and
/// a pulsing "live" dot. All of them stand still when the phone asks for
/// reduced motion, and pause on tabs that aren't showing (TickerMode).

bool _reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Shrinks [child] a little while a finger is on it and springs back on
/// release (food-delivery-app style). Purely visual: the tap itself is still
/// handled by the InkWell / GestureDetector inside. A finger that starts
/// scrolling releases the squish straight away.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.965, this.enabled = true});

  final Widget child;

  /// Size while pressed (1 = no change).
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset _start = Offset.zero;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Same tree whether or not it's enabled, so the child keeps its state
    // when a button turns on / off.
    final active = widget.enabled && !_reduced(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _start = e.position;
        if (active) _set(true);
      },
      onPointerMove: (e) {
        if (_down && (e.position - _start).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && active ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 110 : 320),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Bobs [child] up and down forever (mascots, hero icons).
class FloatY extends StatefulWidget {
  const FloatY({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(milliseconds: 2600),
    this.rotate = 0,
    this.delay = 0,
  });

  final Widget child;

  /// Pixels up / down.
  final double amplitude;
  final Duration period;

  /// Radians of sway that go with the bob (0 = none).
  final double rotate;

  /// 0..1: where in the loop this one starts, so several don't move in step.
  final double delay;

  @override
  State<FloatY> createState() => _FloatYState();
}

class _FloatYState extends State<FloatY> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)
    ..value = widget.delay.clamp(0.0, 1.0);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_reduced(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final s = math.sin(_c.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, -widget.amplitude * s),
          child: widget.rotate == 0 ? child : Transform.rotate(angle: widget.rotate * s, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Pops [child] in with a little overshoot when it first appears.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delayMs = 0, this.from = 0.6});

  final Widget child;
  final int delayMs;

  /// Starting size.
  final double from;

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return child;
    final total = 520 + delayMs;
    final start = delayMs / total;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, v, child) {
        final p = start >= 1 ? 1.0 : ((v - start) / (1 - start)).clamp(0.0, 1.0);
        final k = Curves.easeOutBack.transform(p);
        return Opacity(
          opacity: Curves.easeOut.transform(p),
          child: Transform.scale(scale: from + (1 - from) * k, child: child),
        );
      },
      child: child,
    );
  }
}

/// Counts a number up from 0 when it first shows (band scores, minutes).
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double value;
  final String Function(double v) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// A soft diagonal light that sweeps across [child] every few seconds
/// (hero cards, banners). Put it in a clipped box.
class ShineSweep extends StatefulWidget {
  const ShineSweep({super.key, this.period = const Duration(milliseconds: 4200), this.opacity = 0.18});

  final Duration period;
  final double opacity;

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_reduced(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              // The light crosses during the first 35% of the loop, then rests.
              final p = (_c.value / 0.35).clamp(0.0, 1.0);
              final x = -w * 0.85 + (w * 1.7) * Curves.easeInOut.transform(p);
              return Transform.translate(
                offset: Offset(x, 0),
                child: Transform.rotate(
                  angle: 0.35,
                  child: FractionallySizedBox(
                    widthFactor: 0.32,
                    heightFactor: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: widget.opacity),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A dot with a ring that pulses outward ("live", unread, recording).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_reduced(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s + s * 1.4 * _c.value,
              height: s + s * 1.4 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.45 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-off wiggle whenever [trigger] changes (bell when a new
/// notification arrives, a heart when saved).
class WiggleOnChange extends StatelessWidget {
  const WiggleOnChange({super.key, required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey<Object?>(trigger),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (context, v, child) => Transform.rotate(
        angle: math.sin(v * math.pi * 5) * 0.22 * (1 - v),
        child: child,
      ),
      child: child,
    );
  }
}

/// A soft ring that breathes out from behind [child] (the current step of a
/// timeline). No layout of its own: the ring is painted, so it never moves
/// anything around it.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, required this.child, this.color});

  final Widget child;

  /// Ring colour; defaults to the theme's primary colour.
  final Color? color;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_reduced(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _RingPainter(_c, color),
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.anim, this.color) : super(repaint: anim);

  final Animation<double> anim;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = anim.value;
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      size.center(Offset.zero),
      r + r * 0.6 * v,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.4 * (1 - v)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
