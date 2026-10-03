import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'demo.dart';
import 'store.dart';

/// A language for explanations, lessons and AI feedback. The IELTS content
/// itself (passages, questions, options, model answers) always stays English.
class ContentLang {
  const ContentLang(this.code, this.native, this.english, {this.rtl = false, this.regions = ''});

  final String code;
  final String native;
  final String english;
  final bool rtl;
  final String regions;

  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;
}

const List<ContentLang> kContentLangs = <ContentLang>[
  ContentLang('en', 'English', 'English'),
  ContentLang('bn', 'বাংলা', 'Bangla', regions: 'Bangladesh, India'),
  ContentLang('ne', 'नेपाली', 'Nepali', regions: 'Nepal'),
  ContentLang('ar', 'العربية', 'Arabic', rtl: true, regions: 'UAE, Saudi Arabia, Qatar, Oman, Kuwait'),
  ContentLang('id', 'Bahasa Indonesia', 'Indonesian', regions: 'Indonesia'),
];

ContentLang contentLang(String code) =>
    kContentLangs.firstWhere((l) => l.code == code, orElse: () => kContentLangs.first);

/// Translated study content (assets/content/l10n/<lang>/<module>.json, built
/// by tool/build_l10n.py) with English fallback, plus the student's chosen
/// explanation language (Store kv `feedbackLanguage`, shared with the AI
/// feedback setting).
///
/// ```dart
/// ContentL10n.explanation(passageId, number, fallback: q.s('explanation'))
/// ```
class ContentL10n {
  ContentL10n._();

  static const String kvKey = 'feedbackLanguage';

  /// Languages that have content per module, from index.json.
  static Map<String, List<String>> _index = <String, List<String>>{};
  /// Loaded content per language, then per module ('reading', 'writing').
  static final Map<String, Map<String, Map<String, dynamic>>> _content =
      <String, Map<String, Map<String, dynamic>>>{};

  /// Current language code; listen to rebuild when it changes.
  static final ValueNotifier<String> lang = ValueNotifier<String>('en');

  /// Choice made while logged out (written to the account after log-in).
  static String? _pending;

  static String get current => lang.value;
  static ContentLang get currentLang => contentLang(lang.value);

  /// Reads the index and the saved choice; loads that language's content.
  static Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/content/l10n/index.json');
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _index = <String, List<String>>{
        for (final e in m.entries)
          if (e.value is List) e.key: <String>[for (final v in e.value as List) '$v'],
      };
    } catch (_) {
      _index = <String, List<String>>{};
    }
    await set(_saved(), persist: false);
    _account = Store.I.current?.id;
    Store.I.removeListener(_onStore);
    Store.I.addListener(_onStore);
  }

  static String? _account;

  /// Log-in, log-out or account switch: follow the new account's language.
  static void _onStore() {
    final id = Store.I.current?.id;
    if (id == _account) return;
    _account = id;
    if (id != null) applyPending();
    syncFromAccount();
  }

  static String _saved() {
    final store = Store.I;
    final v = store.isLoggedIn ? store.kv<String>(kvKey) : _pending;
    return kContentLangs.any((l) => l.code == v) ? v! : 'en';
  }

  /// Picks [code] (saving it on the account) and loads its content.
  static Future<void> set(String code, {bool persist = true}) async {
    final c = kContentLangs.any((l) => l.code == code) ? code : 'en';
    if (persist) {
      if (Store.I.isLoggedIn) {
        Store.I.setKv(kvKey, c);
      } else {
        _pending = c;
      }
    }
    if (c != 'en') {
      for (final m in _index.keys) {
        await _load(c, m);
      }
    }
    lang.value = c;
  }

  /// Copies a logged-out choice onto the account that just signed in.
  static void applyPending() {
    final p = _pending;
    if (p == null || !Store.I.isLoggedIn) return;
    Store.I.setKv(kvKey, p);
    _pending = null;
  }

  /// After log-in / account switch: follow that account's saved language.
  static Future<void> syncFromAccount() => set(_saved(), persist: false);

  /// Languages (English first) that have [module] content ('reading', …).
  static List<ContentLang> available(String module) => <ContentLang>[
        kContentLangs.first,
        for (final l in kContentLangs.skip(1))
          if ((_index[module] ?? const <String>[]).contains(l.code)) l,
      ];

  static Future<void> _load(String code, String module) async {
    final byModule = _content.putIfAbsent(code, () => <String, Map<String, dynamic>>{});
    if (byModule.containsKey(module)) return;
    if (!(_index[module] ?? const <String>[]).contains(code)) return;
    try {
      final raw = await rootBundle.loadString('assets/content/l10n/$code/$module.json');
      byModule[module] = await compute(_decode, raw);
    } catch (_) {
      byModule[module] = <String, dynamic>{};
    }
  }

  /// Current language's content of [module] (empty when not translated).
  static Map<String, dynamic> _m(String module) =>
      _content[lang.value]?[module] ?? const <String, dynamic>{};

  static Map<String, dynamic> get _r => _m('reading');

  // ── reading ────────────────────────────────────────────────────────────

  /// Answer explanation of question [number] of bank passage [passageId].
  static String explanation(String passageId, int number, {required String fallback}) {
    final t = _r.m('passages').m(passageId).m('explanations').s('$number');
    return t.isEmpty ? fallback : t;
  }

  /// Per-passage mini-lesson {title, text, example?} (English when missing).
  static Map<String, dynamic> passageLesson(String passageId, Map<String, dynamic> english) {
    final t = _r.m('passages').m(passageId).m('lesson');
    return t.s('text').isEmpty ? english : <String, dynamic>{...english, ...t};
  }

  /// Question-type lesson with translated title and section headings/texts;
  /// exhibits stay those of the English lesson. A table-only section gets
  /// the translated gloss under its table; a section whose layout points at
  /// paragraphs keeps English unless the paragraph count matches.
  static Map<String, dynamic> typeLesson(Map<String, dynamic> english) {
    final t = _r.m('typeLessons').m(english.s('id'));
    final tr = t.l('sections');
    final en = english.l('sections');
    if (t.isEmpty || tr.length != en.length) return english;
    return <String, dynamic>{
      ...english,
      'title': t.s('title').isEmpty ? english.s('title') : t.s('title'),
      'sections': <Map<String, dynamic>>[
        for (var i = 0; i < en.length; i++) _section(en[i], tr[i]),
      ],
    };
  }

  static int _paras(String s) => s.split('\n').where((l) => l.trim().isNotEmpty).length;

  static Map<String, dynamic> _section(Map<String, dynamic> en, Map<String, dynamic> tr) {
    final out = <String, dynamic>{...en};
    if (tr.s('heading').isNotEmpty) out['heading'] = tr.s('heading');
    final text = tr.s('text');
    if (text.isEmpty) return out;
    final layout = en.l('layout');
    if (en.s('text').isEmpty) {
      out['text'] = text;
      if (layout.isNotEmpty) {
        out['layout'] = <Map<String, dynamic>>[
          ...layout,
          for (var p = 0; p < _paras(text); p++) <String, dynamic>{'paragraph': p},
        ];
      }
    } else if (layout.isEmpty || _paras(text) == _paras(en.s('text'))) {
      out['text'] = text;
    }
    return out;
  }

  /// Reading skill lesson (rl_…): translated title, key idea and "uses".
  static Map<String, dynamic> skillLesson(Map<String, dynamic> english) {
    final t = _r.m('skillLessons').m(english.s('id'));
    if (t.s('keyIdea').isEmpty) return english;
    final en = english.l('uses');
    final tr = t.l('uses');
    return <String, dynamic>{
      ...english,
      if (t.s('title').isNotEmpty) 'title': t.s('title'),
      'keyIdea': t.s('keyIdea'),
      if (tr.length == en.length)
        'uses': <Map<String, dynamic>>[
          for (var i = 0; i < en.length; i++) <String, dynamic>{...en[i], ...tr[i]},
        ],
    };
  }

  /// Tips article: translated title, tips and try-it line (chip, links and
  /// layout stay English).
  static Map<String, dynamic> tipArticle(Map<String, dynamic> english) {
    final series = english.s('series');
    final t = _m(series.isEmpty ? 'reading' : series).m('tips').m(english.s('id'));
    final en = english.l('tips');
    final tr = t.l('tips');
    if (t.isEmpty || tr.length != en.length) return english;
    return <String, dynamic>{
      ...english,
      if (t.s('title').isNotEmpty) 'title': t.s('title'),
      'tips': <Map<String, dynamic>>[
        for (var i = 0; i < en.length; i++) <String, dynamic>{...en[i], ...tr[i]},
      ],
      if (t.s('tryIt').isNotEmpty) 'tryIt': <String, dynamic>{...english.m('tryIt'), 'text': t.s('tryIt')},
    };
  }

  /// Study-guide chapter {id, title, blocks}; the translation replaces the
  /// blocks only when their layout matches the English chapter.
  static Map<String, dynamic> guideChapter(Map<String, dynamic> english, {String module = 'reading'}) {
    final t = _m(module).m('guide').m(english.s('id'));
    final tr = t['blocks'];
    final en = english['blocks'];
    if (tr is! List || en is! List || tr.length != en.length) return english;
    return <String, dynamic>{
      ...english,
      if (t.s('title').isNotEmpty) 'title': t.s('title'),
      if (t.s('group').isNotEmpty) 'group': t.s('group'),
      'blocks': tr,
    };
  }

  /// Easy meaning of a Resources word (vocabulary bank, idiom, phrasal verb,
  /// linking / academic word, topic term, irregular verb `iv_<base>`) in the
  /// current language; '' when English or not translated.
  static String meaning(String id) => _m('resources').m('meanings').s(id);

  /// True when the current language has reading content.
  static bool get readingTranslated => _r.isNotEmpty;
}

Map<String, dynamic> _decode(String raw) => (jsonDecode(raw) as Map).cast<String, dynamic>();

/// Wraps [child] in the current content language's text direction (RTL for
/// Arabic). English quotes inside still read left-to-right (Unicode bidi).
class ContentDirection extends StatelessWidget {
  const ContentDirection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: ContentL10n.currentLang.direction,
        child: child,
      );
}
