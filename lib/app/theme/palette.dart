import 'package:flutter/material.dart';

import '../widgets/app_icons.dart';
import 'tokens.dart';

/// One colour family: a bright gradient for icons / banners, a pastel tile
/// colour for Day and a deep tint for Night.
///
/// Every module has its own family (Listening violet, Reading green, Writing
/// orange, Speaking pink, Mock blue, Vocabulary amber, Community cyan), so a
/// student learns the colours and finds things faster - the way food apps
/// colour their categories.
@immutable
class VividTone {
  const VividTone({
    required this.light,
    required this.deep,
    required this.soft,
    required this.softNight,
    this.emoji = '',
  });

  /// Top-left of the gradient.
  final Color light;

  /// Bottom-right of the gradient; also the colour for text on a pastel tile.
  final Color deep;

  /// Pastel tile behind content (Day).
  final Color soft;

  /// Deep tint behind content (Night).
  final Color softNight;

  /// A small emoji that goes with the module (badges, empty states).
  final String emoji;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[light, deep],
      );

  /// Pastel (Day) / deep tint (Night) tile colour.
  Color tile(AppTokens t) => t.isNight ? softNight : soft;

  /// Readable accent on the tile: the deep colour in Day, the light one at Night.
  Color ink(AppTokens t) => t.isNight ? light : deep;

  /// Coloured shadow under gradient icons and banners.
  Color glow([double alpha = 0.38]) => deep.withValues(alpha: alpha);
}

/// The app's colour families. `Vivid.forKey('speaking')`, `Vivid.forIcon(icon)`.
class Vivid {
  Vivid._();

  static const listening = VividTone(
    light: Color(0xFFB39BFF),
    deep: Color(0xFF7346F0),
    soft: Color(0xFFF1ECFF),
    softNight: Color(0xFF29224A),
    emoji: '🎧',
  );
  static const reading = VividTone(
    light: Color(0xFF4FE0A8),
    deep: Color(0xFF0C9A6A),
    soft: Color(0xFFE3F8EF),
    softNight: Color(0xFF163A30),
    emoji: '📖',
  );
  static const writing = VividTone(
    light: Color(0xFFFFBE6E),
    deep: Color(0xFFFF6A2B),
    soft: Color(0xFFFFF0E2),
    softNight: Color(0xFF3E2A19),
    emoji: '✍️',
  );
  static const speaking = VividTone(
    light: Color(0xFFFF8FBA),
    deep: Color(0xFFE5216B),
    soft: Color(0xFFFFE6EF),
    softNight: Color(0xFF3F1C2C),
    emoji: '🎙️',
  );
  static const mock = VividTone(
    light: Color(0xFF6FB1FF),
    deep: Color(0xFF2F62F0),
    soft: Color(0xFFE5EEFF),
    softNight: Color(0xFF192848),
    emoji: '📝',
  );
  static const vocab = VividTone(
    light: Color(0xFFFFD84D),
    deep: Color(0xFFF08A00),
    soft: Color(0xFFFFF5D6),
    softNight: Color(0xFF3B3017),
    emoji: '💡',
  );
  static const community = VividTone(
    light: Color(0xFF5FE3F5),
    deep: Color(0xFF0791B5),
    soft: Color(0xFFDDF8FC),
    softNight: Color(0xFF13343C),
    emoji: '💬',
  );

  /// The brand's own peach (Nexy's fur).
  static const brand = VividTone(
    light: Color(0xFFFFC2AE),
    deep: Color(0xFFFF6F55),
    soft: Color(0xFFFFEDE6),
    softNight: Color(0xFF3A2328),
    emoji: '✨',
  );
  static const fire = VividTone(
    light: Color(0xFFFFA24C),
    deep: Color(0xFFF2441D),
    soft: Color(0xFFFFEADB),
    softNight: Color(0xFF3F2117),
    emoji: '🔥',
  );

  /// Families used, in turn, for icons that have no family of their own.
  static const List<VividTone> cycle = <VividTone>[
    listening,
    reading,
    writing,
    speaking,
    mock,
    vocab,
    community,
    brand,
  ];

  /// Family for a skill / module / home.json key.
  static VividTone forKey(String key) => switch (key) {
        'listening' || 'hearing' => listening,
        'reading' || 'article' || 'doc' || 'school' => reading,
        'writing' || 'pen' => writing,
        'speaking' || 'mic' || 'voice' => speaking,
        'mock' || 'chart' || 'check' || 'clock' || 'calendar' => mock,
        'vocab' || 'resources' || 'bookmark' || 'sparkle' || 'medal' => vocab,
        'community' || 'chat' || 'forum' => community,
        'streak' || 'fire' => fire,
        _ => brand,
      };

  static final Map<int, VividTone> _byIcon = <int, VividTone>{
    for (final i in <IconData>[
      AppIcons.listening,
      AppIcons.hearing,
      AppIcons.headsetMic,
      AppIcons.volume,
      AppIcons.play,
      AppIcons.playCircle,
    ])
      i.codePoint: listening,
    for (final i in <IconData>[
      AppIcons.reading,
      AppIcons.library,
      AppIcons.article,
      AppIcons.doc,
      AppIcons.school,
      AppIcons.highlight,
      AppIcons.layers,
    ])
      i.codePoint: reading,
    for (final i in <IconData>[
      AppIcons.writing,
      AppIcons.pen,
      AppIcons.note,
      AppIcons.spellcheck,
      AppIcons.textFields,
      AppIcons.link,
      AppIcons.quote,
    ])
      i.codePoint: writing,
    for (final i in <IconData>[
      AppIcons.speaking,
      AppIcons.mic,
      AppIcons.voice,
      AppIcons.waveform,
      AppIcons.record,
    ])
      i.codePoint: speaking,
    for (final i in <IconData>[
      AppIcons.mock,
      AppIcons.chart,
      AppIcons.insights,
      AppIcons.trendUp,
      AppIcons.lineChart,
      AppIcons.timer,
      AppIcons.clock,
      AppIcons.calendar,
      AppIcons.calendarMonth,
      AppIcons.event,
      AppIcons.checklist,
      AppIcons.taskDone,
      AppIcons.target,
    ])
      i.codePoint: mock,
    for (final i in <IconData>[
      AppIcons.translate,
      AppIcons.quiz,
      AppIcons.bookmark,
      AppIcons.bookmarkFilled,
      AppIcons.bulb,
      AppIcons.sparkle,
      AppIcons.star,
      AppIcons.trophy,
      AppIcons.medal,
      AppIcons.brain,
      AppIcons.bolt,
    ])
      i.codePoint: vocab,
    for (final i in <IconData>[
      AppIcons.chat,
      AppIcons.forum,
      AppIcons.groups,
      AppIcons.send,
      AppIcons.emoji,
    ])
      i.codePoint: community,
    AppIcons.fire.codePoint: fire,
  };

  /// Family for an icon: skill icons get their skill's colours, every other
  /// icon a steady colour of its own (the same icon is always the same colour).
  static VividTone forIcon(IconData icon) =>
      _byIcon[icon.codePoint] ?? cycle[icon.codePoint % cycle.length];
}
