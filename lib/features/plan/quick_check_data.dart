/// Quick check (optional, at set-up): 20 short questions across four levels
/// (1 ≈ band 4.5 · 2 ≈ 5.5 · 3 ≈ 6.5 · 4 ≈ 7.5) plus one paragraph.
/// `answer` is the index of the right option before shuffling.
/// Listening items are read aloud with the phone's voice (`say`).
class QuickCheckData {
  QuickCheckData._();

  static const List<Map<String, Object>> items = <Map<String, Object>>[
    // ── grammar ──
    {'id': 'g1', 'focus': 'present simple (he/she goes)', 'section': 'grammar', 'level': 1, 'q': 'She ___ to work by bus every day.',
      'options': ['goes', 'go', 'going', 'gone'], 'answer': 0},
    {'id': 'g2', 'focus': 'first conditional', 'section': 'grammar', 'level': 2, 'q': 'If it ___ tomorrow, we will cancel the trip.',
      'options': ['rains', 'will rain', 'rained', 'would rain'], 'answer': 0},
    {'id': 'g3', 'focus': 'since and for', 'section': 'grammar', 'level': 2, 'q': 'I have lived in this city ___ 2019.',
      'options': ['since', 'for', 'from', 'during'], 'answer': 0},
    {'id': 'g4', 'focus': 'subject-verb agreement', 'section': 'grammar', 'level': 3, 'q': 'The number of students ___ increased sharply since 2010.',
      'options': ['has', 'have', 'are', 'were'], 'answer': 0},
    {'id': 'g5', 'focus': 'inversion after "hardly"', 'section': 'grammar', 'level': 4, 'q': 'Hardly ___ the station when the train left.',
      'options': ['had we reached', 'we had reached', 'we reached', 'did we reached'], 'answer': 0},
    {'id': 'g6', 'focus': 'third conditional', 'section': 'grammar', 'level': 4, 'q': 'Had I known about the delay, I ___ a later flight.',
      'options': ['would have booked', 'will book', 'would book', 'had booked'], 'answer': 0},
    // ── vocabulary ──
    {'id': 'v1', 'focus': 'common synonyms', 'section': 'vocab', 'level': 1, 'q': 'Which word means almost the same as "big"?',
      'options': ['large', 'small', 'quick', 'quiet'], 'answer': 0},
    {'id': 'v2', 'focus': 'word partners (impose a tax)', 'section': 'vocab', 'level': 2, 'q': 'The government plans to ___ a tax on sugary drinks.',
      'options': ['impose', 'oppose', 'suppose', 'compose'], 'answer': 0},
    {'id': 'v3', 'focus': 'word partners (strike a balance)', 'section': 'vocab', 'level': 2, 'q': 'Many students find it hard to ___ a balance between work and study.',
      'options': ['strike', 'hit', 'take', 'put'], 'answer': 0},
    {'id': 'v4', 'focus': 'easily confused words', 'section': 'vocab', 'level': 3, 'q': 'Rising sea levels pose a serious ___ to coastal cities.',
      'options': ['threat', 'treat', 'thread', 'trend'], 'answer': 0},
    {'id': 'v5', 'focus': 'academic adjectives', 'section': 'vocab', 'level': 3, 'q': 'The results were ___: they could be explained in more than one way.',
      'options': ['ambiguous', 'unanimous', 'ambitious', 'anonymous'], 'answer': 0},
    {'id': 'v6', 'focus': 'advanced academic verbs', 'section': 'vocab', 'level': 4, 'q': 'Critics argue the policy will ___ inequality rather than reduce it.',
      'options': ['exacerbate', 'alleviate', 'mitigate', 'eradicate'], 'answer': 0},
    // ── reading ──
    {'id': 'r1', 'focus': 'finding a detail', 'section': 'reading', 'level': 1,
      'text': 'The library opens at 9 a.m. on weekdays and at 10 a.m. on Saturdays. It is closed on Sundays.',
      'q': 'When can you visit the library on a Saturday morning?',
      'options': ['From 10 a.m.', 'From 9 a.m.', 'Not at all', 'Only in the afternoon'], 'answer': 0},
    {'id': 'r2', 'focus': 'understanding a reason', 'section': 'reading', 'level': 2,
      'text': 'Although electric cars are cheaper to run than petrol cars, their high purchase price still puts many '
          'buyers off. Prices are expected to fall as battery production grows.',
      'q': 'What stops many people from buying an electric car?',
      'options': ['The cost of buying one', 'The cost of running one', 'A lack of batteries', 'Falling prices'], 'answer': 0},
    {'id': 'r3', 'focus': 'following a change of view', 'section': 'reading', 'level': 3,
      'text': 'Early studies suggested that bilingual children were slower to learn language. More recent research, '
          'using much larger samples, has largely overturned this view and found few lasting differences.',
      'q': 'What does the writer say about the early studies?',
      'options': [
        'Later research mostly contradicted them',
        'They used larger samples than recent research',
        'They showed bilingual children learn faster',
        'Recent research fully confirmed them',
      ],
      'answer': 0},
    {'id': 'r4', 'focus': "the writer's opinion", 'section': 'reading', 'level': 4,
      'text': 'Supporters of green roofs often point to their cooling effect, yet the evidence is mixed: the benefits '
          'are clear in hot, dry climates but marginal where humidity is high, and maintenance costs can cancel out '
          'the energy savings.',
      'q': 'Which statement best matches the writer\'s view?',
      'options': [
        'The value of green roofs depends on local conditions',
        'Green roofs always save money',
        'Green roofs work best in humid cities',
        'The cooling effect of green roofs is a myth',
      ],
      'answer': 0},
    // ── listening (read aloud) ──
    {'id': 'l1', 'focus': 'times and numbers', 'section': 'listening', 'level': 1,
      'say': 'The bus to the city centre leaves at a quarter past eight.',
      'q': 'When does the bus leave?', 'options': ['8:15', '8:45', '8:50', '7:45'], 'answer': 0},
    {'id': 'l2', 'focus': 'spelling names', 'section': 'listening', 'level': 2,
      'say': 'Hello, I would like to book a table for Friday evening. The name is Thompson. That is T, H, O, M, P, S, O, N.',
      'q': 'What is the name on the booking?', 'options': ['Thompson', 'Thomson', 'Tompson', 'Thompsen'], 'answer': 0},
    {'id': 'l3', 'focus': 'catching corrections', 'section': 'listening', 'level': 3,
      'say': 'Please note that the essay deadline has changed. It was the twelfth of March, but it is now the '
          'nineteenth, because the library will be closed next week.',
      'q': 'When is the new deadline?', 'options': ['19 March', '12 March', '9 March', '29 March'], 'answer': 0},
    {'id': 'l4', 'focus': "speakers' problems and attitudes", 'section': 'listening', 'level': 4,
      'say': 'While most participants found the online course convenient, a significant minority felt that the lack '
          'of face-to-face contact made it harder to stay motivated, which the researchers say future courses should address.',
      'q': 'What problem did some participants report?',
      'options': [
        'Staying motivated without meeting people',
        'The course was inconvenient',
        'The course was too short',
        'The researchers ignored their views',
      ],
      'answer': 0},
  ];

  static const String writingQuestion =
      'Some people think students should do unpaid work in their free time to help others. '
      'Do you agree or disagree? Write one paragraph (60 to 120 words) with your opinion and a reason.';

  /// What a section band means, in one line.
  static String meaning(double band) {
    if (band >= 8) return 'Very strong: you handled even the hardest questions.';
    if (band >= 7) return 'Strong: only the hardest questions caught you out.';
    if (band >= 6) return 'Good: solid on the basics, some harder points to work on.';
    if (band >= 5) return 'Fair: the basics are there; mid-level points need work.';
    return 'Developing: start with the basics; the plan builds them first.';
  }

  /// Full names of the writing criteria.
  static const Map<String, String> criteriaNames = <String, String>{
    'TA': 'Task response',
    'CC': 'Coherence and cohesion',
    'LR': 'Vocabulary (lexical resource)',
    'GRA': 'Grammar range and accuracy',
  };

  static const Map<String, String> sectionLabels = <String, String>{
    'grammar': 'Grammar',
    'vocab': 'Vocabulary',
    'reading': 'Reading',
    'listening': 'Listening',
    'writing': 'Writing',
  };

  /// Band for one section: level-weighted share of right answers,
  /// 0 → 4.0 … all → 8.0 (half bands).
  static double band(List<Map<String, Object>> asked, Map<String, int> chosen) {
    var got = 0;
    var all = 0;
    for (final it in asked) {
      final level = it['level']! as int;
      all += level;
      if (chosen[it['id']] == it['answer']) got += level;
    }
    if (all == 0) return 0;
    // 4.0 (none right) to 8.0 (all right): six short questions cannot
    // separate band 8 from 9, so the top is shown as "8.0+".
    final raw = 4.0 + 4.0 * got / all;
    return ((raw * 2).round() / 2).clamp(4.0, 8.0).toDouble();
  }
}
