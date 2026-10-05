import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../reading/widgets.dart' show boldSpans;
import 'widgets.dart';

/// H11 · Article / Tips page. Optional route arg `articleId`. Bookmarks and
/// the furthest tip read per article are user data (Store kv).
class ArticleTipsScreen extends StatefulWidget {
  const ArticleTipsScreen({super.key});

  @override
  State<ArticleTipsScreen> createState() => _ArticleTipsScreenState();
}

class _ArticleTipsScreenState extends State<ArticleTipsScreen> with ContentLangListener {
  /// All articles, or only one series when opened with `{'series': …}`.
  late List<Map<String, dynamic>> _articles =
      Demo.section('resources').l('articles');
  int _article = 0;
  int _tip = 0;
  bool _argsRead = false;

  /// Remembers the furthest tip read in the current article. Called from
  /// callbacks only (never during build).
  void _markRead() {
    if (_articles.isEmpty) return;
    final id = _articles[_article].s('id');
    final progress = kvIntMap(Store.I, ResKeys.articleProgress);
    if ((progress[id] ?? -1) >= _tip) return;
    progress[id] = _tip;
    Store.I.setKv(ResKeys.articleProgress, progress);
  }

  /// Opens an article where the user left off, else at its default tip.
  int _startTip(int article) {
    final a = _articles[article];
    final read = kvIntMap(Store.I, ResKeys.articleProgress)[a.s('id')];
    final n = a.l('tips').length;
    if (read != null && n > 0) return read.clamp(0, n - 1).toInt();
    return a.i('defaultTip');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final series = context.routeArgs['series'];
    if (series is String && series.isNotEmpty) {
      final only = _articles.where((a) => a.s('series') == series).toList();
      if (only.isNotEmpty) _articles = only;
    }
    final id = context.routeArgs['articleId'];
    if (id is String) {
      final i = _articles.indexWhere((a) => a.s('id') == id);
      if (i >= 0) _article = i;
    }
    if (_articles.isNotEmpty) {
      _tip = _startTip(_article);
    }
  }

  void _selectArticle(int i, {bool fromStart = false}) {
    setState(() {
      _article = i;
      _tip = fromStart ? 0 : _startTip(i);
    });
    _markRead();
  }

  void _prev() {
    if (_tip > 0) {
      setState(() => _tip--);
    } else if (_article > 0) {
      setState(() {
        _article--;
        final n = _articles[_article].l('tips').length;
        _tip = n == 0 ? 0 : n - 1;
      });
    }
  }

  void _next(int tipCount) {
    if (_tip + 1 < tipCount) {
      setState(() => _tip++);
      _markRead();
    } else if (_article + 1 < _articles.length) {
      _selectArticle(_article + 1, fromStart: true);
    } else {
      context.toast('That’s the last tip in this series');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (_articles.isEmpty) {
      return const AppScreen(children: [TopBar(title: 'Tips')]);
    }
    final a = ContentL10n.tipArticle(_articles[_article]);
    final tips = a.l('tips');
    final tipIndex = tips.isEmpty ? 0 : _tip.clamp(0, tips.length - 1).toInt();
    final tip = tips.isEmpty ? <String, dynamic>{} : tips[tipIndex];
    final tryIt = a.m('tryIt');
    final atStart = _article == 0 && tipIndex == 0;
    final store = context.store;
    final saved = store.kvSetHas(ResKeys.articleBookmarks, a.s('id'));
    final readUpTo = kvIntMap(store, ResKeys.articleProgress)[a.s('id')] ?? -1;

    return AppScreen(
      gap: 12,
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Opacity(
              opacity: atStart ? 0.45 : 1,
              child: SoftButton(
                label: 'Previous tip',
                leading: AppIcons.chevronLeft,
                height: 52,
                radius: 18,
                expand: true,
                bg: t.isNight ? t.surface : t.raised,
                onTap: atStart ? null : _prev,
              ),
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'Next tip',
              trailing: AppIcons.chevronRight,
              height: 52,
              radius: 18,
              fontSize: 14,
              onTap: () => _next(tips.length),
            ),
          ),
        ],
      ),
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Text(
                a.s('breadcrumb'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ),
            IconBox(
              icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
              tooltip: 'Save',
              onTap: () {
                Store.I.kvSetToggle(ResKeys.articleBookmarks, a.s('id'));
                context.toast(saved ? 'Removed from your library' : 'Saved to your library');
              },
            ),
          ],
        ),
        ChipRow(
          labels: [for (final x in _articles) x.s('chip')],
          selected: _article,
          onChanged: (i) => _selectArticle(i),
        ),
        if (const <String>{'reading', 'writing', 'speaking'}.contains(a.s('series')))
          ContentLangSwitch(module: a.s('series')),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              a.s('title'),
              textDirection: ContentL10n.currentLang.direction,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                height: 1.15,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              a.s('meta'),
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ],
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  'In this guide',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              for (var i = 0; i < tips.length; i++)
                InkWell(
                  onTap: () {
                    setState(() => _tip = i);
                    _markRead();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 36,
                    child: Row(
                      spacing: 10,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == tipIndex ? t.primary : t.surfaceAlt2,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: i != tipIndex && i <= readUpTo
                              ? Icon(AppIcons.check, size: 12, color: t.textMuted)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: i == tipIndex ? t.onPrimary : t.textMuted,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Text(
                            tips[i].s('title'),
                            textDirection: ContentL10n.currentLang.direction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: i == tipIndex
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: i == tipIndex ? t.text : t.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${tipIndex + 1}. ${tip.s('title')}. ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              ...boldSpans(tip.s('body')),
            ],
          ),
          textDirection: ContentL10n.currentLang.direction,
          style: TextStyle(fontSize: 15, height: 1.6, color: t.text),
        ),
        if (tryIt.s('text').isNotEmpty)
          HeroCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () {
              final route = resRoute(tryIt.s('target'));
              if (route == null) {
                context.toast('Not available in this version');
              } else {
                final args = tryIt['args'];
                context.push(route, args: args is Map ? args : null);
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Icon(AppIcons.bulb, size: 18, color: t.peach),
                Expanded(
                  child: Text(
                    tryIt.s('text'),
                    textDirection: ContentL10n.currentLang.direction,
                    style: TextStyle(fontSize: 13, height: 1.45, color: t.heroText),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
