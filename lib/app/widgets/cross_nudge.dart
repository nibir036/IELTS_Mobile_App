import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../nav.dart';
import '../routes.dart';
import '../services/nexted_api.dart';
import '../theme/tokens.dart';
import 'kit.dart';
import 'mascot.dart';
import 'motion.dart';
import 'promo_cards.dart';
import 'vivid.dart';

/// The pop-up that sends a student across to the other half of the app, at
/// a moment that has just earned it:
///
///  * IELTS → Study abroad: a practice or mock result has just come up
///    (watched by [CrossNudgeObserver]; only for students with access).
///  * Study abroad → IELTS: course matches or scholarships have just loaded,
///    or an application was just sent ([CrossNudge.toIelts]).
///
/// A bottom sheet with Nexi, one headline, one line and one button. Shown
/// at every such moment, never twice at once, never over another screen.
/// The lines can be replaced from the content (`promos.messages.ielts_nudge`
/// / `abroad_nudge`, see [PromoCards]) like the banners.
class CrossNudge {
  CrossNudge._();

  /// Added once to the app's `navigatorObservers`.
  static final CrossNudgeObserver observer = CrossNudgeObserver();

  static bool _showing = false;
  static final math.Random _random = math.Random();

  /// IELTS → Study abroad.
  static const List<JourneyMessage> _toAbroad = <JourneyMessage>[
    JourneyMessage(
      'Make your parents proud',
      'Turn this practice into an offer letter from a university abroad.',
    ),
    JourneyMessage(
      'Your score is your boarding pass',
      'See which universities your band can open today.',
    ),
    JourneyMessage(
      'Scholarships are waiting for you',
      'Find the awards you are eligible for in a minute.',
    ),
    JourneyMessage(
      'Picture yourself on campus abroad',
      'Courses, scholarships and visas, with a free AI counsellor who knows your profile.',
    ),
    JourneyMessage(
      'This is how dreams start',
      'Every practice gets you closer. See where your IELTS can take you.',
    ),
  ];

  /// Study abroad → IELTS.
  static const List<JourneyMessage> _toIelts = <JourneyMessage>[
    JourneyMessage(
      'Your dream university is waiting',
      'A higher IELTS band unlocks more of it. Practise with Nexi.',
    ),
    JourneyMessage(
      'Half a band can change everything',
      'More universities, more scholarships. Score higher by practising with us.',
    ),
    JourneyMessage(
      'Make your parents proud',
      'Score higher in IELTS with daily practice and instant AI band scores.',
    ),
    JourneyMessage(
      'Don’t let IELTS hold your offer back',
      'Full mock tests, scored like the real exam.',
    ),
    JourneyMessage(
      'You are one test away',
      'Get the band your university asks for. Start a practice now.',
    ),
  ];

  /// Study abroad → IELTS, [delay] after the moment (so the student sees
  /// their results first). Skipped if they have already left the screen.
  static void toIelts(BuildContext context, {Duration delay = const Duration(milliseconds: 2200)}) {
    final route = ModalRoute.of(context);
    Future<void>.delayed(delay, () {
      if (!context.mounted || route == null || !route.isCurrent) return;
      final pick = _pick(PromoCards.messages('abroad_nudge', _toIelts));
      _show(
        context,
        message: pick,
        tag: 'IELTS AI',
        cta: 'Practise IELTS now',
        icon: Icons.menu_book_rounded,
        target: Routes.home,
      );
    });
  }

  /// IELTS → Study abroad, over [route] once it is still on top.
  static void toAbroad(Route<dynamic> route, {Duration delay = const Duration(milliseconds: 1800)}) {
    if (!NextedAccess.I.enabled) {
      debugPrint('[nudge] no study-abroad access: not offered');
      return;
    }
    Future<void>.delayed(delay, () {
      final nav = appNavigatorKey.currentState;
      final context = nav?.overlay?.context;
      if (context == null || !context.mounted || !route.isCurrent) {
        debugPrint('[nudge] ${route.settings.name} is no longer on top: not offered');
        return;
      }
      final band = Store.I.latest()?.band;
      final message = band != null && band >= 6
          ? JourneyMessage(
              'Band ${Store.formatBand(band)} opens doors abroad',
              'See the universities and scholarships that accept your score.',
            )
          : null;
      _show(
        context,
        // A strong band is the best reason of all; otherwise rotate.
        message: message != null && _random.nextBool()
            ? message
            : _pick(PromoCards.messages('ielts_nudge', _toAbroad)),
        tag: 'STUDY ABROAD',
        cta: 'Explore study abroad',
        icon: Icons.flight_takeoff_rounded,
        target: Routes.nexted,
      );
    });
  }

  static JourneyMessage _pick(List<JourneyMessage> list) => list[_random.nextInt(list.length)];

  static Future<void> _show(
    BuildContext context, {
    required JourneyMessage message,
    required String tag,
    required String cta,
    required IconData icon,
    required String target,
  }) async {
    if (_showing) return;
    _showing = true;
    debugPrint('[nudge] showing "${message.title}"');
    try {
      final go = await showAppSheet<bool>(
        context,
        _NudgeSheet(message: message, tag: tag, cta: cta, icon: icon),
      );
      if (go == true) {
        final ctx = appNavigatorKey.currentState?.overlay?.context;
        if (ctx != null && ctx.mounted) await openPromoTarget(ctx, route: target);
      }
    } catch (e) {
      debugPrint('[nudge] could not show: $e');
    } finally {
      _showing = false;
    }
  }
}

/// Watches for IELTS result screens and offers Study abroad over them.
/// Added to the app's `navigatorObservers`.
class CrossNudgeObserver extends NavigatorObserver {
  /// Screens that show a finished practice or mock. Short and part
  /// practices end on these too (speaking parts end on the transcript).
  static const Set<String> _resultScreens = <String>{
    Routes.listeningResults,
    Routes.readingSolution,
    Routes.writingBandReport,
    Routes.speakingTranscript,
    Routes.speakingEvaluation,
    Routes.mockResults,
    Routes.vocabQuizScore,
  };

  void _check(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (!_resultScreens.contains(name)) return;
    // A result just earned, not an old one reopened from a library or the
    // history.
    if (!_fresh(route.settings.arguments)) {
      debugPrint('[nudge] $name shows an older result: not offered');
      return;
    }
    debugPrint('[nudge] $name: offering study abroad');
    CrossNudge.toAbroad(route);
  }

  /// The attempt on the screen was finished in the last few minutes (or is
  /// still being scored, so has no saved attempt yet).
  static bool _fresh(Object? args) {
    final id = args is Map ? args['attemptId'] : null;
    final attempt = id is String ? Store.I.attemptById(id) : Store.I.latest();
    if (attempt == null) return true;
    return DateTime.now().difference(attempt.createdAt) < const Duration(minutes: 5);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _check(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _check(newRoute);
}

class _NudgeSheet extends StatelessWidget {
  const _NudgeSheet({required this.message, required this.tag, required this.cta, required this.icon});

  final JourneyMessage message;
  final String tag;
  final String cta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 14,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: kPeachGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Icon(icon, size: 14, color: kOnPeach),
                        Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: kOnPeach,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    message.title,
                    style: const TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    message.subtitle,
                    style: TextStyle(fontSize: 14, height: 1.45, color: t.textSoft),
                  ),
                ],
              ),
            ),
            const FloatY(child: Nexi(NexiPose.grad, height: 112)),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: cta,
          leading: icon,
          onTap: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Not now', style: TextStyle(color: t.textMuted)),
        ),
      ],
    );
  }
}
