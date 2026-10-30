import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/nexted_brand.dart';

/// The launch splash: Nexy, the nextED wordmark and a loading bar, for a
/// moment on every app start. Then the start screen (signed in) or the
/// welcome screen (signed out). Follows Day / Night like every screen.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  /// How long it stays.
  static const Duration hold = Duration(milliseconds: 1400);

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bar = AnimationController(vsync: this, duration: LaunchScreen.hold)..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LaunchScreen.hold, () {
      if (!mounted) return;
      context.resetTo(Store.I.isLoggedIn ? Routes.chooser : Routes.splash);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          // A soft peach glow behind the logo.
          Positioned.fill(
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      t.peach.withValues(alpha: t.isNight ? 0.16 : 0.28),
                      t.peach.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 14,
              children: [
                const Nexy(NexyPose.grad, height: 120),
                const NextedWordmark(size: 56),
                Text(
                  'IELTS · STUDY ABROAD',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w500,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Center(
              child: Semantics(
                label: 'Loading',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 120,
                    height: 4,
                    child: AnimatedBuilder(
                      animation: _bar,
                      builder: (context, _) => LinearProgressIndicator(
                        value: Curves.easeOut.transform(_bar.value),
                        backgroundColor: t.isNight ? t.track : t.border,
                        valueColor: AlwaysStoppedAnimation<Color>(t.isNight ? t.primary : t.peach),
                      ),
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
