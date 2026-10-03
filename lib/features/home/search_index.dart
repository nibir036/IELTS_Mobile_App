import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/res_bank.dart';
import '../../app/routes.dart';

/// Everything the app's search can find, built once (and again when the
/// explanation language changes, since guide and tip titles follow it).
///
/// Each entry is a result map for the search screen:
/// `{type, category, title, subtitle, route?, args?, word?, target?, _hay, _title}`
/// with category one of practice · lessons · vocab (the student's own work —
/// category mine — is added live by the screen).
class SearchIndex {
  SearchIndex._();

  static List<Map<String, dynamic>>? _cache;
  static String _builtFor = '';

  /// Old demo index categories → the search filters.
  static const Map<String, String> _legacy = <String, String>{
    'resources': 'lessons',
    'drills': 'practice',
    'essays': 'mine',
    'vocab': 'vocab',
  };

  static List<Map<String, dynamic>> get entries {
    final lang = ContentL10n.current;
    if (_cache == null || _builtFor != lang) {
      _cache = _build();
      _builtFor = lang;
    }
    return _cache!;
  }

  /// Drops the cache (after content reloads).
  static void reset() => _cache = null;

  /// Entries matching every word of [query], best first: title prefix, then
  /// all words in the title, then subtitle, then body text.
  static List<Map<String, dynamic>> search(String query) {
    final words = _words(query);
    if (words.isEmpty) return <Map<String, dynamic>>[];
    final scored = <(int, int, Map<String, dynamic>)>[];
    final list = entries;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final hay = e['_hay'] as String;
      if (!words.every(hay.contains)) continue;
      scored.add((score(e, words, query.trim().toLowerCase()), i, e));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    return <Map<String, dynamic>>[for (final s in scored) s.$3];
  }

  static List<String> _words(String q) =>
      q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static int score(Map<String, dynamic> e, List<String> words, String phrase) {
    final title = e['_title'] as String;
    if (title == phrase) return 5;
    if (title.startsWith(phrase)) return 4;
    if (words.every(title.contains)) return 3;
    final sub = '${e['subtitle']}'.toLowerCase();
    if (words.every((w) => title.contains(w) || sub.contains(w))) return 2;
    return 1;
  }

  static List<Map<String, dynamic>> _build() {
    final out = <Map<String, dynamic>>[];

    void add({
      required String type,
      required String category,
      required String title,
      String subtitle = '',
      String body = '',
      String route = '',
      Map<String, dynamic>? args,
      String word = '',
      String target = '',
      String resWord = '',
    }) {
      if (title.trim().isEmpty) return;
      out.add(<String, dynamic>{
        'type': type,
        'category': category,
        'title': title,
        'subtitle': subtitle,
        if (route.isNotEmpty) 'route': route,
        if (args != null) 'args': args,
        if (word.isNotEmpty) 'word': word,
        if (resWord.isNotEmpty) 'resWord': resWord,
        if (target.isNotEmpty) 'target': target,
        '_title': title.toLowerCase(),
        '_hay': '$title $subtitle $type $body'.toLowerCase(),
      });
    }

    // Hand-made entries (drills, vault, guides) from the home JSON.
    for (final item in Demo.section('home').m('search').l('index')) {
      add(
        type: item.s('type'),
        category: _legacy[item.s('category')] ?? item.s('category'),
        title: item.s('title'),
        subtitle: item.s('subtitle'),
        body: item.s('keywords'),
        target: item.s('target'),
      );
    }

    // ── Reading ──────────────────────────────────────────────────────────
    for (final t in Content.readingTests) {
      add(type: 'Reading', category: 'practice', title: t.s('title'),
          subtitle: 'Reading · full test · 3 passages · 60 min', body: 'reading full test',
          route: Routes.readingPassage, args: <String, dynamic>{'testId': t.s('id')});
    }
    for (final t in Content.writingTests) {
      final p1 = Content.writingPrompt(t.s('task1'));
      final p2 = Content.writingPrompt(t.s('task2'));
      add(type: 'Writing', category: 'practice', title: t.s('title'),
          subtitle: 'Writing · full test · Task 1 + Task 2 · 60 min',
          body: 'writing full test ${p1.s('title')} ${p2.s('title')} ${p2.s('question')}',
          route: Routes.writingTests);
    }
    for (final t in Content.speakingTests) {
      add(type: 'Speaking', category: 'practice', title: t.s('title'),
          subtitle: 'Speaking · full test · Parts 1–3',
          body: 'speaking full test ${t.s('description')}', route: Routes.speakingTests);
    }
    for (final t in Content.readingPracticeTests) {
      add(type: 'Reading', category: 'practice', title: t.s('title'),
          subtitle: 'Reading · short practice test · ${t.i('questionCount')} questions',
          body: 'reading practice test ${t.ls('questionTypes').join(' ')}',
          route: Routes.readingPassage, args: <String, dynamic>{'testId': t.s('id')});
    }
    for (final p in Content.readingPassages) {
      add(type: 'Reading', category: 'practice', title: p.s('title'),
          subtitle: 'Reading passage · ${p.s('topic')}', body: 'reading passage ${p.s('difficulty')}',
          route: Routes.readingPassage, args: <String, dynamic>{'passageId': p.s('id')});
    }
    for (final p in Content.readingBankPassages) {
      add(type: 'Reading', category: 'practice', title: p.s('title'),
          subtitle: 'Reading · ${p.s('questionTypeName')} · Set ${p.i('bankSet')} · ${p.s('difficulty')}',
          body: 'reading ${p.s('topic')} ${p.m('lesson').s('title')}',
          route: Routes.readingPassage, args: <String, dynamic>{'passageId': p.s('id')});
    }
    for (final l in Content.readingTypeLessons) {
      final tr = ContentL10n.typeLesson(l);
      add(type: 'Lesson', category: 'lessons', title: tr.s('title'),
          subtitle: 'Reading · ${l.s('name')} lesson',
          body: '${l.s('title')} ${[for (final s in l.l('sections')) '${s.s('heading')} ${s.s('text')}'].join(' ')}',
          route: Routes.readingTypeLesson,
          args: <String, dynamic>{'type': l.s('id').replaceFirst('rtl_', '')});
    }
    for (final l in Demo.section('reading').l('lessons')) {
      final tr = ContentL10n.skillLesson(l);
      add(type: 'Lesson', category: 'lessons', title: tr.s('title'), subtitle: 'Reading · skill lesson',
          body: '${l.s('title')} ${l.s('keyIdea')} ${tr.s('keyIdea')}',
          route: Routes.readingLesson, args: <String, dynamic>{'lessonId': l.s('id')});
    }

    // ── Listening ────────────────────────────────────────────────────────
    for (final st in Content.listeningSets) {
      add(type: 'Listening', category: 'practice', title: st.s('title'),
          subtitle: 'Listening · Part ${st.i('part')}'
              '${st.s('formatLabel').isEmpty ? '' : ' · ${st.s('formatLabel')}'}',
          body: 'listening ${st.s('context')} ${st.s('scenario')}',
          route: Routes.listeningPlayer, args: <String, dynamic>{'setId': st.s('id')});
    }

    // ── Writing ──────────────────────────────────────────────────────────
    for (final w in Content.writingTask1) {
      add(type: 'Writing', category: 'practice', title: w.s('title'),
          subtitle: 'Writing Task 1 · ${w.s('typeLabel').isEmpty ? w.s('type') : w.s('typeLabel')}',
          body: 'writing task 1 chart ${w.s('prompt')}',
          route: Routes.writingTask1Editor, args: <String, dynamic>{'promptId': w.s('id')});
      if (w.l('samples').isNotEmpty) {
        add(type: 'Sample', category: 'lessons', title: '${w.s('title')} — sample answers',
            subtitle: 'Writing Task 1 · Band 6, 7 and 8 answers', body: 'model answer ${w.s('prompt')}',
            route: Routes.writingSampleAnswer, args: <String, dynamic>{'promptId': w.s('id'), 'task': 1});
      }
    }
    for (final w in Content.writingTask2) {
      add(type: 'Writing', category: 'practice', title: w.s('title'),
          subtitle: 'Writing Task 2 · ${w.s('typeLabel').isEmpty ? w.s('type') : w.s('typeLabel')} · ${w.s('topic')}',
          body: 'writing task 2 essay ${w.s('prompt')}',
          route: Routes.writingEditor, args: <String, dynamic>{'promptId': w.s('id')});
      if (w.l('samples').isNotEmpty) {
        add(type: 'Sample', category: 'lessons', title: '${w.s('title')} — sample answers',
            subtitle: 'Writing Task 2 · Band 6, 7 and 8 essays', body: 'model answer essay ${w.s('prompt')}',
            route: Routes.writingSampleAnswer, args: <String, dynamic>{'promptId': w.s('id'), 'task': 2});
      }
    }

    // ── Speaking ─────────────────────────────────────────────────────────
    for (final c in Content.cueCards) {
      add(type: 'Speaking', category: 'practice', title: c.s('title'),
          subtitle: 'Speaking Part 2 · cue card · ${c.s('topic')}',
          body: 'speaking part 2 cue card ${c.ls('bullets').join(' ')}',
          route: Routes.speakingSamples, args: <String, dynamic>{'part': 2, 'cardId': c.s('id')});
    }
    for (final t in Content.speakingBankPart1) {
      add(type: 'Speaking', category: 'practice', title: t.s('topic'),
          subtitle: 'Speaking Part 1 · ${t.ls('questions').length} questions',
          body: 'speaking part 1 ${t.ls('questions').join(' ')}',
          route: Routes.speakingSamples, args: <String, dynamic>{'part': 1, 'topicId': t.s('id')});
    }
    for (final t in Content.part3Topics) {
      add(type: 'Speaking', category: 'practice', title: t.s('topic'),
          subtitle: 'Speaking Part 3 · discussion',
          body: 'speaking part 3 discussion ${t.s('description')} ${[for (final q in t.l('questions')) q.s('q')].join(' ')}',
          route: Routes.speakingSamples, args: <String, dynamic>{'part': 3, 'topicId': t.s('id')});
    }
    final vocab = Content.speakingVocab;
    final seen = <String>{};
    for (final k in vocab.keys) {
      final v = vocab.m(k);
      final head = v.s('headword');
      if (!seen.add(head.toLowerCase())) continue;
      add(type: 'Vocab', category: 'vocab', title: head,
          subtitle: '${v.s('pos')} · ${v.s('meaning')}',
          body: '${v.ls('synonyms').join(' ')} ${v.s('level')}', word: k);
    }

    // Resources bank: IELTS vocabulary, phrasal verbs, idioms, linking and
    // academic words (open the word sheet).
    const kinds = <String, String>{
      'vocab': 'Vocab',
      'phrasal': 'Phrasal verb',
      'idiom': 'Idiom',
      'linking': 'Linking word',
      'academic': 'Academic word',
      'topic': 'Topic vocab',
    };
    for (final w in ResBank.allWords) {
      final head = w.s('word');
      if (w.s('kind') == 'vocab' && !seen.add(head.toLowerCase())) continue;
      final band = ResBank.bandLabel(w.d('band'));
      add(type: kinds[w.s('kind')] ?? 'Vocab', category: 'vocab', title: head,
          subtitle: '${w.s('partOfSpeech')}${band.isEmpty ? '' : ' · $band'} · ${w.s('definition')}',
          body: '${w.ls('synonyms').join(' ')} ${w.ls('family').join(' ')} ${w.s('group')}', resWord: w.s('id'));
    }
    for (final v in ResBank.irregularVerbs) {
      add(type: 'Irregular verb', category: 'vocab', title: '${v.s('base')} – ${v.s('past')} – ${v.s('participle')}',
          subtitle: v.s('meaning'), body: 'irregular verb', route: Routes.irregularVerbs);
    }

    // ── Guides and tips ──────────────────────────────────────────────────
    const guides = <String, (String, String)>{
      'reading': ('Reading Guide', Routes.readingGuide),
      'writing': ('Writing Guide', Routes.writingGuide),
      'speaking': ('Speaking Guide', Routes.speakingGuide),
      'grammar': ('Grammar Course', Routes.grammarGuide),
      'listening': ('Listening Guide', Routes.listeningGuide),
      'vocab': ('Vocabulary Lessons', Routes.vocabGuide),
    };
    for (final g in guides.entries) {
      final chapters = Demo.guide(g.key).l('chapters');
      for (var i = 0; i < chapters.length; i++) {
        final en = chapters[i];
        final tr = ContentL10n.guideChapter(en, module: g.key);
        add(type: 'Guide', category: 'lessons', title: tr.s('title'),
            subtitle: '${g.value.$1} · chapter ${i + 1}',
            body: '${en.s('title')} ${_blocksText(en['blocks'])}'
                '${identical(tr, en) ? '' : ' ${_blocksText(tr['blocks'])}'}',
            route: g.value.$2, args: <String, dynamic>{'chapter': en.s('id')});
      }
    }
    for (final a in Demo.section('resources').l('articles')) {
      final tr = ContentL10n.tipArticle(a);
      final series = a.s('series');
      add(type: 'Tips', category: 'lessons', title: tr.s('title'),
          subtitle: '${series.isEmpty ? '' : '${series[0].toUpperCase()}${series.substring(1)} '}tips · ${a.s('chip')}',
          body: '${a.s('title')} ${[for (final t in a.l('tips')) '${t.s('title')} ${t.s('body')}'].join(' ')}'
              ' ${[for (final t in tr.l('tips')) '${t.s('title')} ${t.s('body')}'].join(' ')}',
          route: Routes.articleTips, args: <String, dynamic>{'series': series, 'articleId': a.s('id')});
    }
    return out;
  }

  static String _blocksText(Object? blocks) {
    final sb = StringBuffer();
    void walk(Object? x) {
      if (x is String) {
        sb
          ..write(x)
          ..write(' ');
      } else if (x is List) {
        x.forEach(walk);
      }
    }

    if (blocks is List) {
      for (final b in blocks) {
        if (b is List && b.isNotEmpty && b.first != 'img') walk(b.sublist(1));
      }
    }
    return sb.toString().replaceAll('**', '');
  }
}
