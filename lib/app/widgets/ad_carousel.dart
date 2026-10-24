import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/config.dart';
import '../services/nexted_api.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';
import 'cross_promo.dart';
import 'motion.dart';
import 'promo_cards.dart' show openPromoTarget;

// Ad banners on the two home pages.
//
// The banners are finished images uploaded from the admin page (server:
// routes/banners.ts, GET /v1/banners). They slide past in a carousel; the
// app's own banner (Study abroad on the IELTS side, IELTS prep on the
// Study abroad side) stays as the last slide, and is all that shows while
// no ad is live. A new or deleted banner reaches the app within a couple of
// minutes, without an update.

/// One uploaded banner.
class AdBanner {
  const AdBanner({
    required this.id,
    required this.place,
    required this.title,
    required this.image,
    required this.linkType,
    required this.link,
  });

  factory AdBanner.fromJson(Map<String, dynamic> j) => AdBanner(
        id: '${j['id'] ?? ''}',
        place: '${j['place'] ?? ''}',
        title: '${j['title'] ?? ''}',
        image: '${j['image'] ?? ''}',
        linkType: '${j['linkType'] ?? 'none'}',
        link: '${j['link'] ?? ''}',
      );

  final String id;

  /// ielts | abroad | both
  final String place;

  /// Alt text for screen readers.
  final String title;

  /// Server path of the image (/v1/banners/<id>/image?v=…).
  final String image;

  /// none | screen | url
  final String linkType;
  final String link;

  String get imageUrl {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return '$base$image';
  }
}

/// The live banners, fetched at most every two minutes.
class AdBanners extends ChangeNotifier {
  AdBanners._();

  static final AdBanners I = AdBanners._();

  static const String ielts = 'ielts';
  static const String abroad = 'abroad';

  List<AdBanner> _all = const <AdBanner>[];
  DateTime? _fetched;
  bool _busy = false;

  List<AdBanner> forPlace(String place) =>
      _all.where((b) => (b.place == place || b.place == 'both') && b.image.isNotEmpty).toList();

  Future<void> refresh() async {
    if (!AppConfig.hasApi || _busy) return;
    final at = _fetched;
    if (at != null && DateTime.now().difference(at) < const Duration(minutes: 2)) return;
    _busy = true;
    try {
      final j = await ApiClient.get('/v1/banners', auth: false);
      final list = j['banners'];
      _all = list is List
          ? <AdBanner>[
              for (final b in list)
                if (b is Map) AdBanner.fromJson(b.cast<String, dynamic>()),
            ]
          : const <AdBanner>[];
      _fetched = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Offline or the server is down: keep what we had (or the built-in banner).
    } finally {
      _busy = false;
    }
  }
}

/// IELTS home: ads for "ielts", then the Study abroad banner (for students
/// who can open that side).
class IeltsHomeBanners extends StatelessWidget {
  const IeltsHomeBanners({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: NextedAccess.I,
        builder: (context, _) => AdCarousel(
          place: AdBanners.ielts,
          fallback: const StudyAbroadPromo(),
          showFallback: NextedAccess.I.enabled,
        ),
      );
}

/// Study abroad home: ads for "abroad", then the IELTS prep banner.
class AbroadHomeBanners extends StatelessWidget {
  const AbroadHomeBanners({super.key});

  @override
  Widget build(BuildContext context) => const AdCarousel(place: AdBanners.abroad, fallback: IeltsPromo());
}

/// The carousel: swipe, or it moves on by itself every few seconds.
class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key, required this.place, required this.fallback, this.showFallback = true});

  final String place;

  /// The app's own banner: the last slide, and the only one with no ads.
  final Widget fallback;
  final bool showFallback;

  /// Same height as the built-in banner (JourneyBanner).
  static const double height = 184;

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final PageController _pages = PageController();
  Timer? _timer;
  int _page = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    AdBanners.I.addListener(_changed);
    unawaited(AdBanners.I.refresh());
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    AdBanners.I.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    // A banner removed while it was showing: go back to the first slide.
    final n = _slides().length;
    if (_page >= n && _pages.hasClients) {
      _page = 0;
      _pages.jumpToPage(0);
    }
  }

  List<Widget> _slides() => <Widget>[
        for (final b in AdBanners.I.forPlace(widget.place)) _AdSlide(banner: b),
        if (widget.showFallback) widget.fallback,
      ];

  void _advance() {
    if (!mounted || _dragging || !_pages.hasClients) return;
    if (!TickerMode.of(context)) return; // tab not showing
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final n = _slides().length;
    if (n < 2) return;
    final next = (_page + 1) % n;
    unawaited(_pages.animateToPage(
      next,
      duration: Duration(milliseconds: next == 0 ? 600 : 450),
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides();
    if (AdBanners.I.forPlace(widget.place).isEmpty) return widget.fallback;
    if (slides.length == 1) return slides.first;
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AdCarousel.height,
          // Clip at the sides only, so the banners keep their shadows.
          child: ClipRect(
            clipper: const _SidesOnly(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.axis != Axis.horizontal) return false;
                if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
                if (n is ScrollEndNotification) _dragging = false;
                return false;
              },
              child: PageView.builder(
                controller: _pages,
                clipBehavior: Clip.none,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: slides[i],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Banner ${_page + 1} of ${slides.length}',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 5,
            children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? t.text : t.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidesOnly extends CustomClipper<Rect> {
  const _SidesOnly();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -40, size.width, size.height + 40);

  @override
  bool shouldReclip(_SidesOnly oldClipper) => false;
}

/// One uploaded banner image; a tap opens its screen or web page.
class _AdSlide extends StatelessWidget {
  const _AdSlide({required this.banner});

  final AdBanner banner;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final r = BorderRadius.circular(26);
    final tappable = banner.linkType != 'none' && banner.link.isNotEmpty;
    final image = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: t.surfaceAlt,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: t.isNight ? 0.4 : 0.12), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Image.network(
          banner.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: AdCarousel.height,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(color: t.surfaceAlt, child: const SizedBox.expand()),
          errorBuilder: (context, _, _) => ColoredBox(
            color: t.surfaceAlt,
            child: Center(child: Icon(AppIcons.cloudOff, color: t.textMuted)),
          ),
        ),
      ),
    );
    return Semantics(
      button: tappable,
      image: true,
      label: banner.title.isEmpty ? 'Banner' : banner.title,
      child: tappable
          ? Pressable(
              scale: 0.975,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openPromoTarget(
                  context,
                  route: banner.linkType == 'screen' ? banner.link : '',
                  url: banner.linkType == 'url' ? banner.link : '',
                ),
                child: image,
              ),
            )
          : image,
    );
  }
}
