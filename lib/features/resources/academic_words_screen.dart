import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../../app/widgets/speak_button.dart';
import '../reading/widgets.dart' show boldSpans;
import 'widgets.dart';
import 'word_sheet.dart';

/// H7 · Academic Words Mastery - day-by-day word list. Per-word mastery
/// (new / learning / mastered) lives in the user's kv `resources.wordMastery`.
class AcademicWordsScreen extends StatefulWidget {
  const AcademicWordsScreen({super.key});

  @override
  State<AcademicWordsScreen> createState() => _AcademicWordsScreenState();
}

class _AcademicWordsScreenState extends State<AcademicWordsScreen> {
  late final Map<String, dynamic> _data =
      Demo.section('resources').m('academicWords');
  bool _searching = false;
  String _query = '';

  /// new → learning → mastered → new.
  void _cycle(String id) {
    final now = wordMasteryOf(Store.I, id);
    final next = switch (now) {
      'new' => 'learning',
      'learning' => 'mastered',
      _ => 'new',
    };
    setWordMastery(id, next);
  }

  int? _viewDay; // day whose words are listed (null = current day)
  int _tab = 0; // 0 academic words · 1 linking words (bank only)

  bool get _bank => ResBank.academicWords.isNotEmpty;

  void _tapDay(int day, int current) {
    if (day > current) {
      context.toast('Day $day unlocks after Day ${day - 1}');
      return;
    }
    if (!_bank) {
      if (day < current) context.toast('Day $day complete');
      return;
    }
    setState(() => _viewDay = day == current ? null : day);
  }

  /// Bank word → the row shape {id, word, partOfSpeech, meaning}.
  static Map<String, dynamic> _row(Map<String, dynamic> w) => <String, dynamic>{
        'id': w.s('id'),
        'word': w.s('word'),
        'partOfSpeech': w.s('pos'),
        'meaning': w.s('definition'),
      };

  void _nextDay(int current, int totalDays) {
    if (current >= totalDays) {
      context.toast('That was the last day. Well done!');
      return;
    }
    Store.I.setKv(ResKeys.academicDay, current + 1);
    setState(() => _viewDay = null);
    context.toast('Day ${current + 1} unlocked');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final mastery = kvStringMap(store, ResKeys.wordMastery);
    final bank = _bank;
    final totalDays = bank ? ResBank.academicDays : _data.i('totalDays');
    final current = kvInt(store, ResKeys.academicDay, 1).clamp(1, totalDays < 1 ? 1 : totalDays).toInt();
    final day = (_viewDay ?? current).clamp(1, current).toInt();
    final perDay = bank ? ResBank.wordsPerDay : _data.i('wordsPerDay');
    final total = bank ? ResBank.academicWords.length : _data.i('total');
    final today = bank ? <Map<String, dynamic>>[for (final w in ResBank.academicDay(day)) _row(w)] : _data.l('words');
    final mastered = today.where((w) => mastery[w.s('id')] == 'mastered').length;
    final done = today.where((w) => (mastery[w.s('id')] ?? 'new') != 'new').length;
    final learned = bank
        ? ResBank.academicWords.where((w) => mastery[w.s('id')] == 'mastered').length
        : kvInt(store, ResKeys.academicLearnedPrior, 0) + mastered;
    final shown = bank ? totalDays : _data.i('daysShown');
    final q = _query.trim().toLowerCase();
    final pool = bank && q.isNotEmpty ? <Map<String, dynamic>>[for (final w in ResBank.academicWords) _row(w)] : today;
    final words = pool
        .where((w) =>
            q.isEmpty ||
            w.s('word').toLowerCase().contains(q) ||
            w.s('meaning').toLowerCase().contains(q))
        .take(60)
        .toList();
    final dayLabel = bank
        ? 'Day $day · ${ResBank.academicDay(day).isNotEmpty && ResBank.academicDay(day).first.s('list') == 'extended' ? 'Extended academic words' : 'Academic Word List'}'
        : 'Day $current · ${_data.s('sublist')}';

    return AppScreen(
      gap: 12,
      footer: _tab == 1
          ? null
          : PrimaryButton(
              label: 'Quiz Day $day words',
              trailing: AppIcons.forward,
              height: 56,
              radius: 18,
              onTap: () => context.push(
                Routes.vocabQuiz,
                args: <String, dynamic>{'quizId': bank ? ResBank.academicQuizId(day) : 'quiz_academic'},
              ),
            ),
      children: [
        ResTopBar(
          title: 'Academic Words Mastery',
          actions: [
            IconBox(
              icon: _searching ? AppIcons.close : AppIcons.search,
              tooltip: 'Search words',
              onTap: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              }),
            ),
          ],
        ),
        if (bank)
          ResSegments(
            labels: <String>[
              'Academic words · $total',
              'Linking words · ${ResBank.connectorGroups.fold<int>(0, (n, g) => n + g.l('items').length)}',
            ],
            index: _tab,
            height: 40,
            fontSize: 14,
            onChanged: (i) => setState(() => _tab = i),
          ),
        if (bank) const ContentLangSwitch(module: 'resources'),
        if (_searching)
          ResSearchField(
            hint: bank ? (_tab == 1 ? 'Search linking words' : 'Search all $total academic words') : 'Search today’s words',
            onChanged: (v) => setState(() => _query = v),
          ),
        if (_tab == 1) ..._linking(context, q) else ...[
        HeroCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day $current of $totalDays · $perDay words a day'.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: t.peach,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$learned of $total words learned',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  color: t.heroText,
                ),
              ),
              const SizedBox(height: 10),
              ProgressBar(
                value: total == 0 ? 0 : learned / total,
                height: 5,
                onHero: true,
              ),
            ],
          ),
        ),
        if (q.isEmpty)
        for (var row = 0; row * 7 < shown; row++)
          Row(
            spacing: 6,
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: row * 7 + c + 1 <= shown
                      ? _DayCell(
                          day: row * 7 + c + 1,
                          current: current,
                          selected: bank && row * 7 + c + 1 == day,
                          onTap: () => _tapDay(row * 7 + c + 1, current),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.isNotEmpty && bank ? '${words.length}${words.length == 60 ? '+' : ''} matches' : dayLabel,
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    if (q.isEmpty)
                      Text(
                        '$done of ${today.length} done',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                  ],
                ),
              ),
              if (words.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No words match “$_query”.',
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
              for (final w in words)
                _WordRow(
                  data: w,
                  status: mastery[w.s('id')] ?? 'new',
                  onToggle: () => _cycle(w.s('id')),
                  onOpen: bank ? () => showResWord(context, w.s('id')) : null,
                  saved: store.kvSetHas(ResKeys.savedWords, w.s('id')),
                  onSave: () {
                    final now = toggleSavedWord(w.s('id'));
                    context.toast(now ? 'Saved to your words' : 'Removed from saved words');
                  },
                ),
            ],
          ),
        ),
        if (bank && q.isEmpty && day == current && done == today.length && today.isNotEmpty)
          SoftButton(
            label: current >= totalDays ? 'All $totalDays days done' : 'Start Day ${current + 1}',
            trailing: AppIcons.forward,
            height: 50,
            radius: 18,
            expand: true,
            bg: t.isNight ? t.surface : t.raised,
            onTap: () => _nextDay(current, totalDays),
          ),
        if (bank && q.isEmpty && day == current && done < today.length)
          Text(
            'Mark every word Known or Learning to unlock Day ${current + 1}. Tap a word for its example and word family.',
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ],
    );
  }

  /// Linking words grouped by function (bank only).
  List<Widget> _linking(BuildContext context, String q) {
    final t = context.tk;
    final store = context.store;
    final out = <Widget>[];
    for (final g in ResBank.connectorGroups) {
      final items = g.l('items').where((c) =>
          q.isEmpty || c.s('word').toLowerCase().contains(q) || c.s('use').toLowerCase().contains(q)).toList();
      if (items.isEmpty) continue;
      out.add(AppCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            Text(g.s('title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            if (g.s('note').isNotEmpty)
              Text(g.s('note'), style: TextStyle(fontSize: 12, color: t.textMuted)),
            const SizedBox(height: 4),
            for (final c in items)
              InkWell(
                onTap: () => showResWord(context, c.s('id')),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(c.s('word'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            Text(c.s('use'), style: TextStyle(fontSize: 12.5, height: 1.35, color: t.textMuted)),
                            TrMeaning(c.s('id'), fontSize: 12.5),
                            Text.rich(
                              TextSpan(children: boldSpans(c.s('example'))),
                              style: TextStyle(fontSize: 13, height: 1.35, fontStyle: FontStyle.italic, color: t.textSoft),
                            ),
                          ],
                        ),
                      ),
                      if (c.s('register').isNotEmpty) Tag(c.s('register'), height: 22, fontSize: 11),
                      Icon(
                        isWordSaved(store, c.s('id')) ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                        size: 16,
                        color: t.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ));
    }
    if (out.isEmpty) {
      out.add(Text('No linking words match “$_query”.', style: TextStyle(fontSize: 13, color: t.textMuted)));
    }
    return out;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.current, required this.onTap, this.selected = false});

  final int day;
  final int current;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final done = day < current;
    final isCurrent = day == current;
    final bg = done ? t.primary : t.surface;
    final fg = done ? t.onPrimary : (isCurrent ? t.text : t.textMuted);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isCurrent || selected
            ? BorderSide(color: selected && !isCurrent ? t.accentStrong : t.text, width: selected ? 2.5 : 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Day',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.data,
    required this.status,
    required this.onToggle,
    required this.saved,
    required this.onSave,
    this.onOpen,
  });

  final bool saved;
  final VoidCallback? onOpen;
  final VoidCallback onSave;

  final Map<String, dynamic> data;

  /// 'new' | 'learning' | 'mastered'.
  final String status;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final known = status == 'mastered';
    final learning = status == 'learning';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        spacing: 12,
        children: [
          SpeakButton(
            text: data.s('word'),
            tooltip: 'Play ${data.s('word')}',
            size: 36,
            radius: 12,
            iconSize: 18,
            bg: t.surfaceAlt2,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${data.s('word')} '),
                      TextSpan(
                        text: data.s('partOfSpeech'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  data.s('meaning'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                TrMeaning(data.s('id'), fontSize: 12, maxLines: 1),
              ],
            ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSave,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                size: 18,
                color: saved ? t.text : t.textMuted,
              ),
            ),
          ),
          ResMiniPill(
            label: known ? 'Known' : (learning ? 'Learning' : 'New'),
            height: 26,
            bg: known ? t.primary : (learning ? ResPalette.pink : t.surfaceAlt2),
            fg: known ? t.onPrimary : (learning ? ResPalette.ink : t.textMuted),
            border: known || learning ? null : t.border,
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}
