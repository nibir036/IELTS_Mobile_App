import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/nexted_api.dart';
import 'mascot.dart';
import 'promo_cards.dart';
import 'vivid.dart';

/// The two halves of the app point at each other with a live banner:
/// [StudyAbroadPromo] on the IELTS side, [IeltsPromo] on the Study abroad
/// side. The headlines roll every few seconds; they can be replaced from the
/// content (`promos.messages.ielts_cross` / `abroad_cross`, see [PromoCards]).

/// IELTS → Study abroad. Only for students who can open that side.
class StudyAbroadPromo extends StatelessWidget {
  const StudyAbroadPromo({super.key});

  static const List<JourneyMessage> _builtIn = <JourneyMessage>[
    JourneyMessage(
      'Your dream campus is closer than you think',
      'Your IELTS score is the first step – let’s plan the rest.',
    ),
    JourneyMessage(
      'It’s time to make your parents proud',
      'Courses, scholarships and visas – all in one place.',
    ),
    JourneyMessage(
      'Your band score is your boarding pass',
      'See which universities your score can open today.',
    ),
    JourneyMessage(
      'From practice room to lecture hall abroad',
      'Free AI counsellor that knows your profile.',
    ),
    JourneyMessage(
      'Scholarships are waiting for students like you',
      'Find out what you’re eligible for in a minute.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NextedAccess.I,
      builder: (context, _) {
        if (!NextedAccess.I.enabled) return const SizedBox.shrink();
        return JourneyBanner(
          tag: '✈️  STUDY ABROAD',
          messages: PromoCards.messages('ielts_cross', _builtIn),
          cta: 'Start my journey',
          colors: const <Color>[Color(0xFF3B82F6), Color(0xFF6D28D9)],
          pose: NexyPose.grad,
          emojis: const <String>['🌍'],
          onTap: () => openPromoTarget(context, route: Routes.nexted),
        );
      },
    );
  }
}

/// Study abroad → IELTS.
class IeltsPromo extends StatelessWidget {
  const IeltsPromo({super.key});

  static const List<JourneyMessage> _builtIn = <JourneyMessage>[
    JourneyMessage(
      'Your visa journey starts with a band score',
      'Practise all four skills with instant AI feedback.',
    ),
    JourneyMessage(
      'Band 7 opens doors. Let’s get you there',
      'Daily plans, mock tests and a coach in your pocket.',
    ),
    JourneyMessage(
      'Make them proud: ace IELTS, fly abroad',
      'A few minutes a day adds up to the score you need.',
    ),
    JourneyMessage(
      'The world is waiting – IELTS is your key',
      'Speaking, Writing, Reading, Listening, all with Nexy.',
    ),
    JourneyMessage(
      'Your dream is one score away',
      'Take a free mock test and see where you stand.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return JourneyBanner(
      tag: '🎯  IELTS PREP',
      messages: PromoCards.messages('abroad_cross', _builtIn),
      cta: 'Practise IELTS now',
      colors: const <Color>[Color(0xFFFF8A5B), Color(0xFFE5216B)],
      pose: NexyPose.speaking,
      emojis: const <String>['🏆'],
      onTap: () => openPromoTarget(context, route: Routes.home),
    );
  }
}
