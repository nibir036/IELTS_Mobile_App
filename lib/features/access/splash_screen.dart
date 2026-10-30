import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';

/// A1 · Welcome (signed out), the "night glow" design: Nexy in a blue
/// spotlight among twinkling stars, the headline with a sky-blue second line,
/// both halves of the app, and a glowing peach Get started.
///
/// Night: deep navy sky. Day: the same layout on a soft sky-blue morning.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final night = t.isNight;
    final c = _Palette(night);

    return Scaffold(
      backgroundColor: c.bgBottom,
      body: Stack(
        children: [
          // The sky.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1),
                  radius: 1.3,
                  colors: <Color>[c.bgTop, c.bgMid, c.bgBottom],
                  stops: const <double>[0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(child: _Stars(color: c.star)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                      // Top part and the buttons; the gap between them grows
                      // on tall phones (no IntrinsicHeight: the shine and the
                      // animations can't report an intrinsic size).
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Row(
                            children: [
                              Semantics(
                                label: 'nextED',
                                child: Image.asset(
                                  night ? 'assets/branding/nexted_logo_white.png' : 'assets/branding/nexted_logo_navy.png',
                                  height: 26,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: c.pillBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: c.pillBorder),
                                ),
                                child: Text('IELTS · Study abroad', style: TextStyle(fontSize: 12, color: c.pillText)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _Stage(palette: c),
                          const SizedBox(height: 10),
                          Text(
                            'Your band score.',
                            style: TextStyle(
                              fontSize: 31,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: c.ink,
                            ),
                          ),
                          // The second line in sky blue.
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (r) => LinearGradient(colors: c.sky).createShader(r),
                            child: const Text(
                              'Your dream campus.',
                              style: TextStyle(
                                fontSize: 31,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'AI practice that scores you in seconds, and a counsellor that gets you there.',
                            style: TextStyle(fontSize: 15, height: 1.45, color: c.soft),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 10,
                            children: [
                              Expanded(
                                child: _Half(
                                  palette: c,
                                  icon: AppIcons.listening,
                                  title: 'IELTS AI',
                                  body: 'Mocks & band scores',
                                ),
                              ),
                              Expanded(
                                child: _Half(
                                  palette: c,
                                  icon: AppIcons.flight,
                                  title: 'Study abroad',
                                  body: 'Courses & scholarships',
                                ),
                              ),
                            ],
                          ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          const SizedBox(height: 18),
                          _GlowCta(onTap: () => context.push(Routes.signup)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => context.push(Routes.login),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text.rich(
                                TextSpan(
                                  text: 'I already have an account · ',
                                  style: TextStyle(fontSize: 15, color: c.soft),
                                  children: [
                                    TextSpan(
                                      text: 'Log in',
                                      style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
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
        ],
      ),
    );
  }
}

/// The colours of the screen, night and day.
class _Palette {
  _Palette(this.night);

  final bool night;

  Color get bgTop => night ? const Color(0xFF1B2A6B) : const Color(0xFFDCE7FF);
  Color get bgMid => night ? const Color(0xFF0B1030) : const Color(0xFFF1F5FF);
  Color get bgBottom => night ? const Color(0xFF05071A) : const Color(0xFFFFFFFF);
  Color get star => night ? Colors.white : const Color(0xFF3977F7);
  Color get ink => night ? Colors.white : const Color(0xFF0B1033);
  Color get soft => night ? const Color(0xFFAAB4D8) : const Color(0xFF4A5578);

  /// "Your dream campus." - sky blue (deeper by day so it reads on white).
  List<Color> get sky =>
      night ? const <Color>[Color(0xFF9FE3FF), Color(0xFF4FA3FF)] : const <Color>[Color(0xFF2F8CFF), Color(0xFF0B3AC3)];

  Color get pillBg => night ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.75);
  Color get pillBorder => night ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFD6E1FF);
  Color get pillText => night ? const Color(0xFFC9D3FF) : const Color(0xFF3A4A7A);

  Color get spot => night ? const Color(0xFF3977F7) : const Color(0xFF8DB2FF);
}

/// Nexy on a glowing podium in a blue spotlight, with a warm peach rim.
class _Stage extends StatelessWidget {
  const _Stage({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final c = palette;
    return SizedBox(
      height: 290,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 10,
            child: _Glow(size: 300, color: c.spot.withValues(alpha: c.night ? 0.75 : 0.55)),
          ),
          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Align(
              alignment: const Alignment(0.35, 0),
              child: _Glow(size: 220, color: const Color(0xFFFF9C82).withValues(alpha: c.night ? 0.45 : 0.35)),
            ),
          ),
          Positioned(
            bottom: 2,
            child: Container(
              width: 220,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(110, 23)),
                gradient: RadialGradient(
                  colors: <Color>[
                    (c.night ? const Color(0xFF78A0FF) : const Color(0xFF3977F7)).withValues(alpha: c.night ? 0.6 : 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: FloatY(
              amplitude: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: c.spot.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 24)),
                  ],
                ),
                child: const Nexy(NexyPose.speaking, height: 262),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: <Color>[color, color.withValues(alpha: 0)], stops: const <double>[0, 0.68]),
          ),
        ),
      );
}

/// One half of the app as a glass card.
class _Half extends StatelessWidget {
  const _Half({required this.palette, required this.icon, required this.title, required this.body});

  final _Palette palette;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: c.night
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.03)],
              )
            : null,
        color: c.night ? null : Colors.white,
        border: Border.all(color: c.night ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFDCE6FF)),
        boxShadow: c.night
            ? null
            : <BoxShadow>[BoxShadow(color: const Color(0xFF0B3AC3).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Icon(icon, size: 20, color: c.night ? const Color(0xFF9FE3FF) : const Color(0xFF2F6BFF)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
          Text(body, style: TextStyle(fontSize: 12.5, height: 1.3, color: c.soft)),
        ],
      ),
    );
  }
}

/// The warm peach "Get started" with a soft glow and a shine sweeping across.
class _GlowCta extends StatelessWidget {
  const _GlowCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const r = BorderRadius.all(Radius.circular(999));
    return Semantics(
      button: true,
      label: 'Get started',
      child: Pressable(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: const LinearGradient(colors: <Color>[Color(0xFFFFB49E), Color(0xFFFF9C82)]),
            boxShadow: <BoxShadow>[
              BoxShadow(color: const Color(0xFFFF9C82).withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 10)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    Positioned.fill(child: ShineSweep(opacity: 0.35)),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          Text(
                            'Get started',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF2A1208)),
                          ),
                          Icon(AppIcons.forward, size: 20, color: Color(0xFF2A1208)),
                        ],
                      ),
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

/// Small stars that twinkle (still when the phone asks for less motion).
class _Stars extends StatefulWidget {
  const _Stars({required this.color});

  final Color color;

  @override
  State<_Stars> createState() => _StarsState();
}

class _StarsState extends State<_Stars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) _c.stop();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _StarPainter(_c, widget.color)),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.anim, this.color) : super(repaint: anim);

  final Animation<double> anim;
  final Color color;

  /// (x, y as a share of the screen, size, phase).
  static const List<(double, double, double, double)> _stars = <(double, double, double, double)>[
    (0.08, 0.10, 1.4, 0.0),
    (0.30, 0.05, 1.0, 0.3),
    (0.86, 0.14, 1.6, 0.6),
    (0.62, 0.24, 1.0, 0.15),
    (0.15, 0.32, 1.2, 0.8),
    (0.92, 0.36, 1.0, 0.45),
    (0.05, 0.50, 1.0, 0.7),
    (0.78, 0.07, 1.0, 0.9),
    (0.45, 0.13, 0.9, 0.55),
  ];

  /// Four-point sparkles near Nexy.
  static const List<(double, double, double, double)> _sparkles = <(double, double, double, double)>[
    (0.16, 0.24, 7, 0.1),
    (0.84, 0.21, 6, 0.6),
    (0.22, 0.40, 5, 0.35),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (final (x, y, r, phase) in _stars) {
      final a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * (anim.value + phase)));
      p.color = color.withValues(alpha: a * 0.9);
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
    }
    for (final (x, y, s, phase) in _sparkles) {
      final k = 0.6 + 0.4 * math.sin(2 * math.pi * (anim.value + phase));
      p.color = color.withValues(alpha: 0.45 + 0.5 * k);
      final c = Offset(x * size.width, y * size.height);
      final h = s * k;
      final path = Path()
        ..moveTo(c.dx, c.dy - h)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + h, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + h)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - h, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - h)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}
