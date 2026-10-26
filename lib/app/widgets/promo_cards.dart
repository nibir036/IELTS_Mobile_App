import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/demo.dart';
import '../nav.dart';
import '../routes.dart';
import '../theme/palette.dart';
import 'app_icons.dart';
import 'mascot.dart';
import 'vivid.dart';

/// Custom banner cards you can add later without a new app release.
///
/// Every banner carousel and cross-promotion banner in the app first shows
/// the cards from the content (pack `ui` = `assets/demo/demo_data.json`,
/// served from the server's database), then the built-in ones. A custom card
/// with the same `id` as a built-in card replaces it. To add one, put this
/// in the UI JSON, push, and the app picks it up on its next open:
///
/// ```json
/// "promos": {
///   "cards": [
///     {
///       "id": "eid_offer",
///       "place": "ielts_home",           // see [PromoPlace]
///       "title": "Eid offer: Pro for less",
///       "subtitle": "All mock tests and AI feedback",
///       "cta": "See plans",
///       "badge": "OFFER",
///       "tone": "speaking",              // listening | reading | writing | speaking | mock | vocab | community | brand | fire
///       "pose": "grad",                  // Nexi: wave | point | grad | thumbs | writing | reading | speaking | listening
///       "icon": "medal",                 // used when there is no pose / image
///       "image": "https://…/banner.png", // optional picture instead of Nexi
///       "route": "/home/plans",          // an app screen (Routes.*) …
///       "url": "https://nexted.app",     // … or a web page
///       "from": "2026-11-01", "until": "2026-11-30",  // optional dates
///       "order": 1
///     }
///   ],
///   "messages": {                        // headlines for the cross-promotion banners
///     "ielts_cross":  [{"title": "…", "subtitle": "…"}],
///     "abroad_cross": [{"title": "…", "subtitle": "…"}]
///   }
/// }
/// ```
class PromoPlace {
  PromoPlace._();

  /// "Dive right in" banners on the IELTS Home.
  static const ielts = 'ielts_home';

  /// Banners at the top of Resources.
  static const resources = 'resources';

  /// Banners on the Study abroad home.
  static const abroad = 'abroad_home';
}

class PromoCards {
  PromoCards._();

  static Map<String, dynamic> get _root => Demo.section('promos');

  /// Custom cards for [place] (in `order`, only inside their dates), then
  /// [builtIn] minus any a custom card replaces.
  static List<PromoItem> forPlace(BuildContext context, String place, List<PromoItem> builtIn) {
    final now = DateTime.now();
    final custom = <(int, PromoItem)>[];
    for (final c in _root.l('cards')) {
      if (c.s('place') != place) continue;
      final from = DateTime.tryParse(c.s('from'));
      final until = DateTime.tryParse(c.s('until'));
      if (from != null && now.isBefore(from)) continue;
      if (until != null && now.isAfter(until.add(const Duration(days: 1)))) continue;
      if (c.s('title').isEmpty) continue;
      custom.add((c.i('order'), _fromJson(context, c)));
    }
    custom.sort((a, b) => a.$1.compareTo(b.$1));
    final ids = <String>{for (final (_, p) in custom) if (p.id.isNotEmpty) p.id};
    return <PromoItem>[
      for (final (_, p) in custom) p,
      for (final p in builtIn)
        if (p.id.isEmpty || !ids.contains(p.id)) p,
    ];
  }

  /// Headlines for a cross-promotion banner (`ielts_cross` / `abroad_cross`),
  /// or [builtIn] when the content has none.
  static List<JourneyMessage> messages(String key, List<JourneyMessage> builtIn) {
    final list = _root.m('messages').l(key);
    final out = <JourneyMessage>[
      for (final m in list)
        if (m.s('title').isNotEmpty) JourneyMessage(m.s('title'), m.s('subtitle')),
    ];
    return out.isEmpty ? builtIn : out;
  }

  static PromoItem _fromJson(BuildContext context, Map<String, dynamic> c) {
    final route = c.s('route');
    final url = c.s('url');
    return PromoItem(
      id: c.s('id'),
      title: c.s('title'),
      subtitle: c.s('subtitle'),
      cta: c.s('cta').isEmpty ? 'Open' : c.s('cta'),
      badge: c.s('badge').isEmpty ? null : c.s('badge'),
      tone: Vivid.forKey(c.s('tone')),
      pose: _pose(c.s('pose')),
      icon: _icon(c.s('icon')),
      image: c.s('image').isEmpty ? null : c.s('image'),
      onTap: () => openPromoTarget(context, route: route, url: url),
    );
  }

  static NexiPose? _pose(String key) {
    for (final p in NexiPose.values) {
      if (p.name == key) return p;
    }
    return null;
  }

  static IconData? _icon(String key) => switch (key) {
        '' => null,
        'medal' => AppIcons.medal,
        'school' => AppIcons.school,
        'quiz' => AppIcons.quiz,
        'mic' => AppIcons.mic,
        'writing' => AppIcons.writing,
        'reading' => AppIcons.reading,
        'listening' => AppIcons.listening,
        'mock' => AppIcons.mock,
        'star' => AppIcons.star,
        'bolt' => AppIcons.bolt,
        'trophy' => AppIcons.trophy,
        'flight' => AppIcons.flight,
        'chat' => AppIcons.chat,
        _ => AppIcons.sparkle,
      };
}

/// Opens a card's target: an app screen (`route`) or a web page (`url`).
/// The two halves of the app (IELTS `/home`, Study abroad `/nexted`) are
/// opened fresh, the way the switch buttons open them; other screens are
/// pushed on top.
Future<void> openPromoTarget(BuildContext context, {String route = '', String url = ''}) async {
  if (route.isNotEmpty) {
    if (route == Routes.home || route == Routes.nexted || route == Routes.chooser) {
      await context.resetTo(route);
    } else {
      await context.push(route);
    }
    return;
  }
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    // Web pages only: a link from the content or an ad banner must never
    // open intent:, sms:, file: or other apps' links.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) context.toast('Couldn’t open the link');
  }
}
