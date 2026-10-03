import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Pastel hues from the canvas that stay the same in Day and Night (they are
/// always paired with dark #151515 text/icons).
class ResPalette {
  ResPalette._();

  static const Color pink = Color(0xFFF9D6E2);
  static const Color lavender = Color(0xFFDCDDFA);
  static const Color rose = Color(0xFFF7C6D6);
  static const Color blush = Color(0xFFF4B8CB);
  static const Color lilac = Color(0xFFB9BAF2);
  static const Color periwinkleDay = Color(0xFFEEEFFD);
  static const Color ink = Color(0xFF151515);
  static const Color white = Color(0xFFFFFFFF);
  static const Color creamChip = Color(0xFFFFF8E2);
  static const Color creamBorder = Color(0xFFDCCFA5);
  static const Color indigoDot = Color(0xFF8C8EE8);
  static const Color onlineGreen = Color(0xFF2FA35F);
  static const Color onlineTextDay = Color(0xFF2E7D4F);
}

/// Background colour for a JSON `tone` value.
Color toneBg(AppTokens t, String tone) {
  switch (tone) {
    case 'pink':
      return ResPalette.pink;
    case 'lavender':
      return ResPalette.lavender;
    case 'rose':
      return ResPalette.rose;
    case 'blush':
      return ResPalette.blush;
    case 'lilac':
      return ResPalette.lilac;
    case 'periwinkle':
      return t.isNight ? t.surfaceAlt2 : ResPalette.periwinkleDay;
    case 'white':
      return t.isNight ? ResPalette.creamChip : ResPalette.white;
    case 'dark':
      return t.primary;
    default:
      return t.surfaceAlt2;
  }
}

/// Foreground (text / icon) colour matching [toneBg].
Color toneFg(AppTokens t, String tone) {
  switch (tone) {
    case 'pink':
    case 'lavender':
    case 'rose':
    case 'blush':
    case 'lilac':
    case 'white':
      return ResPalette.ink;
    case 'dark':
      return t.onPrimary;
    default:
      return t.text;
  }
}

/// Icon for a JSON `icon` key.
IconData resIcon(String key) {
  switch (key) {
    case 'checklist':
      return AppIcons.checklist;
    case 'doc':
      return AppIcons.doc;
    case 'bulb':
      return AppIcons.bulb;
    case 'calendar':
      return AppIcons.calendar;
    case 'translate':
      return AppIcons.translate;
    case 'school':
      return AppIcons.school;
    case 'video':
      return AppIcons.video;
    case 'layers':
      return AppIcons.layers;
    case 'quote':
      return AppIcons.quote;
    case 'swap':
      return AppIcons.swap;
    case 'chart':
      return AppIcons.chart;
    default:
      return AppIcons.article;
  }
}

/// Route for a JSON `target` key (null → not built yet).
String? resRoute(String key) {
  switch (key) {
    case 'vocabVault':
      return Routes.vocabVault;
    case 'academicWords':
      return Routes.academicWords;
    case 'irregularVerbs':
      return Routes.irregularVerbs;
    case 'scoringCriteria':
      return Routes.scoringCriteria;
    case 'articleTips':
      return Routes.articleTips;
    case 'vocabQuiz':
      return Routes.vocabQuiz;
    case 'writingSampleAnswer':
      return Routes.writingSampleAnswer;
    case 'writingTemplate':
      return Routes.writingTemplate;
    case 'ideasTopics':
      return Routes.ideasTopics;
    case 'cueCardVault':
      return Routes.cueCardVault;
    case 'listeningMiniList':
      return Routes.listeningMiniList;
    case 'readingLibrary':
      return Routes.readingLibrary;
    case 'phrasalVerbs':
      return Routes.phrasalVerbs;
    case 'writingSelector':
      return Routes.writingSelector;
    case 'masterclass':
      return Routes.masterclass;
    case 'sentenceBuilder':
      return Routes.sentenceBuilder;
    case 'writingGuide':
      return Routes.writingGuide;
    case 'speakingGuide':
      return Routes.speakingGuide;
    case 'grammarGuide':
      return Routes.grammarGuide;
    case 'speakingHub':
      return Routes.speakingHub;
    case 'speakingPart13':
      return Routes.speakingPart13;
    case 'pronunciation':
      return Routes.pronunciation;
    case 'speakingLibrary':
      return Routes.speakingLibrary;
    case 'idioms':
      return Routes.idioms;
    case 'topicVocab':
      return Routes.topicVocab;
    case 'vocabGuide':
      return Routes.vocabGuide;
    case 'listeningGuide':
      return Routes.listeningGuide;
    default:
      return null;
  }
}

/// Header used by the resource sub-pages: back button, small overline
/// ("Resources") above an 18px title, optional trailing actions.
class ResTopBar extends StatelessWidget {
  const ResTopBar({
    super.key,
    required this.title,
    this.overline = 'Resources',
    this.actions = const <Widget>[],
  });

  final String title;
  final String overline;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 10,
      children: [
        IconBox(
          icon: AppIcons.back,
          tooltip: 'Back',
          iconSize: 18,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                overline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Small rounded count badge (unread messages).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.alert,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.onAlert,
        ),
      ),
    );
  }
}

/// Overlapping round initials avatars (live room / partner practice).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.size = 34,
    this.overlap = 10,
    this.fontSize = 12,
    this.borderColor,
  });

  /// Rows with `initials` and `tone`.
  final List<Map<String, dynamic>> people;
  final double size;
  final double overlap;
  final double fontSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final n = people.length;
    final width = n == 0 ? 0.0 : size + (n - 1) * (size - overlap);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * (size - overlap),
              top: 0,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: toneBg(t, '${people[i]['tone'] ?? ''}'),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor ??
                        (t.isNight ? ResPalette.creamBorder : t.bg),
                    width: 2,
                  ),
                ),
                child: Text(
                  '${people[i]['initials'] ?? ''}',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: ResPalette.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline search box (48–50px, radius 16–18) with a live [onChanged].
class ResSearchField extends StatelessWidget {
  const ResSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.height = 48,
    this.radius = 16,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double height;
  final double radius;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.isNight ? t.surface : t.raised,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(AppIcons.search, size: 20, color: t.textMuted),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 15, color: t.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(fontSize: 15, color: t.textMuted),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small filled pill button (Known / Learning toggles, 34px).
class ResMiniPill extends StatelessWidget {
  const ResMiniPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    this.onTap,
    this.bold = false,
    this.height = 34,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final VoidCallback? onTap;
  final bool bold;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-rect segmented switcher (Day #EDE3E9 track / white segment,
/// Night #151515 track / #1F1F1F segment).
class ResSegments extends StatelessWidget {
  const ResSegments({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 44,
    this.fontSize = 15,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.isNight ? t.surface : const Color(0xFFEDE3E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: SizedBox(
                height: height,
                child: Material(
                  color: i == index
                      ? (t.isNight ? t.surfaceAlt2 : t.surface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight:
                              i == index ? FontWeight.w500 : FontWeight.w400,
                          color: i == index ? t.text : t.textMuted,
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

// ═════════════════════════════════════════════════════════════════════════════
// Per-user state (Store kv) for the Resources / Community section.
// ═════════════════════════════════════════════════════════════════════════════

/// kv keys used by section H. Home's word-of-the-day shares [savedWords].
class ResKeys {
  ResKeys._();

  /// Set of saved word ids ('word_ubiquitous', 'aw_derive' …).
  static const savedWords = 'resources.savedWords';

  /// Map word id → 'learning' | 'mastered' (absent = 'new').
  static const wordMastery = 'resources.wordMastery';

  /// Academic Words Mastery: current day (int, default 1).
  static const academicDay = 'resources.academicDay';

  /// Academic words learned on earlier days (int, default 0).
  static const academicLearnedPrior = 'resources.academicLearnedPrior';

  /// Set of bookmarked article ids.
  static const articleBookmarks = 'resources.articleBookmarks';

  /// Map article id → furthest tip index read.
  static const articleProgress = 'resources.articleProgress';

  /// Set of room / DM ids the user has opened.
  static const readRooms = 'community.readRooms';

  /// The user's direct-message threads: [{id, letter, name, tone, unread, messages}].
  static const dms = 'community.dms';

  /// The user's own sent messages in a room / DM.
  static String sent(String roomId) => 'community.sent.$roomId';

  /// Rooms the user created: [{id, name, topic, description, letter, tone, createdAt}].
  static const myRooms = 'community.myRooms';
}

/// Reads a kv map as `Map<String, String>`.
Map<String, String> kvStringMap(Store s, String key) {
  final m = s.kv<Map>(key);
  if (m == null) return <String, String>{};
  return m.map((k, v) => MapEntry<String, String>('$k', '$v'));
}

/// Reads a kv map as `Map<String, int>`.
Map<String, int> kvIntMap(Store s, String key) {
  final m = s.kv<Map>(key);
  if (m == null) return <String, int>{};
  final out = <String, int>{};
  m.forEach((k, v) {
    if (v is num) out['$k'] = v.toInt();
  });
  return out;
}

/// Reads a kv int (e.g. academic day), falling back to [fallback].
int kvInt(Store s, String key, int fallback) {
  final v = s.kv<num>(key);
  return v == null ? fallback : v.toInt();
}

/// Adds [value] to a kv string set (no-op if already present).
void kvSetAdd(Store s, String key, String value) {
  final set = s.kvSet(key);
  if (set.contains(value)) return;
  set.add(value);
  s.setKv(key, set.toList());
}

/// 'new' | 'learning' | 'mastered' for a word id.
String wordMasteryOf(Store s, String id) =>
    kvStringMap(s, ResKeys.wordMastery)[id] ?? 'new';

/// Sets a word's mastery state ('new' removes it).
void setWordMastery(String id, String state) {
  final s = Store.I;
  final m = kvStringMap(s, ResKeys.wordMastery);
  if (state == 'new') {
    m.remove(id);
  } else {
    m[id] = state;
  }
  s.setKv(ResKeys.wordMastery, m);
}

bool isWordSaved(Store s, String id) => s.kvSetHas(ResKeys.savedWords, id);

/// Save / unsave a word everywhere (vault, quiz, word of the day, home).
/// Returns true if the word is now saved.
bool toggleSavedWord(String id) {
  Store.I.kvSetToggle(ResKeys.savedWords, id);
  return Store.I.kvSetHas(ResKeys.savedWords, id);
}

/// Resolves a word id against all word content in this section:
/// {id, word, partOfSpeech, definition}, or null if unknown.
Map<String, dynamic>? resolveWord(String id) {
  final bank = ResBank.word(id);
  if (bank != null) {
    final w = bank.s('word');
    return <String, dynamic>{
      'id': id,
      'word': w.isEmpty ? w : w.substring(0, 1).toUpperCase() + w.substring(1),
      'partOfSpeech': bank.s('partOfSpeech'),
      'definition': bank.s('definition'),
    };
  }
  final res = Demo.section('resources');
  for (final w in res.m('vault').l('words')) {
    if (w.s('id') == id) {
      return <String, dynamic>{
        'id': id,
        'word': w.s('word'),
        'partOfSpeech': w.s('partOfSpeech'),
        'definition': w.s('definition'),
      };
    }
  }
  final wod = res.m('hub').m('wordOfTheDay');
  if (wod.s('id') == id) {
    return <String, dynamic>{
      'id': id,
      'word': wod.s('word'),
      'partOfSpeech': wod.s('partOfSpeech'),
      'definition': wod.s('definition'),
    };
  }
  for (final quiz in Content.quizzes) {
    for (final q in quiz.l('questions')) {
      if (q.s('wordId') == id) {
        final w = q.s('word');
        return <String, dynamic>{
          'id': id,
          'word': w.isEmpty ? w : w.substring(0, 1).toUpperCase() + w.substring(1),
          'partOfSpeech': q.s('partOfSpeech'),
          'definition': q.s('meaningShort'),
        };
      }
    }
  }
  for (final w in res.m('academicWords').l('words')) {
    if (w.s('id') == id) {
      return <String, dynamic>{
        'id': id,
        'word': w.s('word'),
        'partOfSpeech': w.s('partOfSpeech'),
        'definition': w.s('meaning'),
      };
    }
  }
  for (final kind in const <String>['phrasalVerbs', 'idioms']) {
    for (final p in phraseItems(kind)) {
      if (p.s('id') == id) {
        final w = p.s('phrase');
        return <String, dynamic>{
          'id': id,
          'word': w.isEmpty ? w : w.substring(0, 1).toUpperCase() + w.substring(1),
          'partOfSpeech': kind == 'idioms' ? 'idiom' : 'phrasal verb',
          'definition': p.s('meaning'),
        };
      }
    }
  }
  return null;
}

/// Phrasal verbs / idioms: the Resources bank (1,250+ phrasal verbs, 580+
/// idioms), with the IELTS topic / register / usage notes of the curated
/// content list merged in where the same phrase appears, plus curated phrases
/// the bank does not have. Without the bank: the curated list
/// (`content.resources.phrasalVerbs` | `content.resources.idioms`).
List<Map<String, dynamic>> phraseItems(String kind) {
  if (kind == 'topicVocab') {
    // 23 IELTS topic sets: {id, phrase, meaning, example, topic}.
    return <Map<String, dynamic>>[
      for (final tp in ResBank.topics)
        for (final x in tp.l('items'))
          <String, dynamic>{
            'id': x.s('id'),
            'phrase': x.s('term'),
            'meaning': x.s('meaning'),
            'example': x.s('example'),
            'topic': tp.s('title'),
          },
    ];
  }
  final curated = Demo.section('content').m('resources').l(kind);
  final bank = kind == 'idioms' ? ResBank.idioms : ResBank.phrasalVerbs;
  if (bank.isEmpty) return curated;
  final cached = _phraseCache[kind];
  if (cached != null && identical(_phraseSrc[kind], Demo.resourcesBank)) return cached;
  String key(String p) => p.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
  final extra = <String, Map<String, dynamic>>{for (final c in curated) key(c.s('phrase')): c};
  final used = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final b in bank) {
    final c = extra[key(b.s('phrase'))];
    if (c != null && used.add(key(b.s('phrase')))) {
      out.add(<String, dynamic>{
        ...b,
        'id': c.s('id'), // keeps students' saved curated phrases
        'register': c.s('register'),
        'topic': c.s('topic'),
        if (c.s('care').isNotEmpty) 'care': c.s('care'),
        'ieltsExample': c.s('example'),
      });
    } else {
      out.add(b);
    }
  }
  for (final c in curated) {
    if (!used.contains(key(c.s('phrase')))) out.add(c);
  }
  out.sort((a, b) => a.s('phrase').toLowerCase().compareTo(b.s('phrase').toLowerCase()));
  _phraseSrc[kind] = Demo.resourcesBank;
  return _phraseCache[kind] = out;
}

final Map<String, Map<String, dynamic>> _phraseSrc = <String, Map<String, dynamic>>{};
final Map<String, List<Map<String, dynamic>>> _phraseCache = <String, List<Map<String, dynamic>>>{};

/// "1,382" style thousands.
String groupThousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Live size of a resource list (hub `lists` item / module row) from the
/// Resources bank; null when the bank is missing or the list is not a bank list.
String? resLiveCount(String id) {
  if (id == 'vocab_lessons' || id == 'vocabGuide') {
    final n = Demo.guide('vocab').l('chapters').length;
    return n == 0 ? null : '$n lessons';
  }
  if (!ResBank.has) return null;
  return switch (id) {
    'vocabulary' || 'vaultWords' => '${groupThousands(ResBank.allWords.length)} words',
    'academic_words' || 'academicWords' => '${groupThousands(ResBank.academicWords.length)} words',
    'phrasal_verbs' || 'phrasalVerbs' => '${groupThousands(phraseItems('phrasalVerbs').length)} verbs',
    'idioms' => '${groupThousands(phraseItems('idioms').length)} idioms',
    'irregular_verbs' || 'irregularVerbs' => '${ResBank.irregularVerbs.length} verbs',
    'topic_vocab' || 'topicVocab' =>
      '${groupThousands(ResBank.topics.fold<int>(0, (n, t) => n + t.l('items').length))} terms',
    _ => null,
  };
}

/// The user's DM threads (empty for a new account).
List<Map<String, dynamic>> communityDms(Store s) => s.kvList(ResKeys.dms);

/// Unread count of a room / DM row: content (or seeded) unread minus read markers.
int roomUnread(Store s, Map<String, dynamic> row) =>
    s.kvSetHas(ResKeys.readRooms, row.s('id')) ? 0 : row.i('unread');

/// Total unread across public rooms and the user's DMs (for the Community
/// tab badge).
int communityUnreadCount(Store s) {
  var n = 0;
  for (final r in Demo.section('resources').m('community').l('rooms')) {
    if (!r.b('live')) n += roomUnread(s, r);
  }
  for (final d in communityDms(s)) {
    n += roomUnread(s, d);
  }
  return n;
}

/// Number of rooms / DMs with unread messages (Community tab badge).
int communityUnreadThreads(Store s) {
  var n = 0;
  for (final r in Demo.section('resources').m('community').l('rooms')) {
    if (!r.b('live') && roomUnread(s, r) > 0) n++;
  }
  for (final d in communityDms(s)) {
    if (roomUnread(s, d) > 0) n++;
  }
  return n;
}

/// Marks a room / DM as read.
void markRoomRead(String id) => kvSetAdd(Store.I, ResKeys.readRooms, id);

/// Topics a user-created room can have.
const List<String> kRoomTopics = <String>['Speaking', 'Writing', 'Reading', 'Listening', 'General'];

/// The user's own rooms, newest first.
List<Map<String, dynamic>> communityMyRooms(Store s) =>
    s.kvList(ResKeys.myRooms).reversed.toList();

/// One of the user's own rooms, or null.
Map<String, dynamic>? communityMyRoom(Store s, String id) {
  for (final r in s.kvList(ResKeys.myRooms)) {
    if (r.s('id') == id) return r;
  }
  return null;
}

/// Creates a user room and returns it.
Map<String, dynamic> createMyRoom({
  required String name,
  required String topic,
  required String description,
}) {
  const tones = <String, String>{
    'Speaking': 'pink',
    'Writing': 'lavender',
    'Reading': 'rose',
    'Listening': 'lilac',
    'General': 'periwinkle',
  };
  final clean = name.trim();
  final room = <String, dynamic>{
    'id': Store.newId('myroom'),
    'name': clean,
    'topic': topic,
    'description': description.trim(),
    'letter': clean.isEmpty ? '#' : clean.substring(0, 1).toUpperCase(),
    'tone': tones[topic] ?? 'periwinkle',
    'createdAt': DateTime.now().toIso8601String(),
  };
  Store.I.kvListAdd(ResKeys.myRooms, room);
  return room;
}

/// Deletes one of the user's rooms and its messages.
void deleteMyRoom(String id) {
  final s = Store.I;
  final rooms = s.kvList(ResKeys.myRooms)..removeWhere((r) => r.s('id') == id);
  s.setKv(ResKeys.myRooms, rooms);
  s.setKv(ResKeys.sent(id), null);
}

/// The word's meaning in the chosen content language (e.g. easy Bangla) under
/// its English meaning; nothing in English or when untranslated. Rebuilds
/// when the language changes.
class TrMeaning extends StatelessWidget {
  const TrMeaning(this.id, {super.key, this.fontSize = 13, this.maxLines});

  final String id;
  final double fontSize;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ValueListenableBuilder<String>(
      valueListenable: ContentL10n.lang,
      builder: (context, _, _) {
        final s = ContentL10n.meaning(id);
        if (s.isEmpty) return const SizedBox.shrink();
        return Text(
          s,
          textDirection: ContentL10n.currentLang.direction,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: TextStyle(fontSize: fontSize, height: 1.4, color: t.textSoft),
        );
      },
    );
  }
}
