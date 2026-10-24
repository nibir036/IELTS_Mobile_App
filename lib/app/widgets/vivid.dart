import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';
import 'kit.dart';
import 'mascot.dart';
import 'motion.dart';

/// Colourful building blocks for the home-style screens (food-delivery-app
/// look): gradient icons, a search pill, banner carousels and category tiles.
/// Colours come from [Vivid]; motion from motion.dart.

// ─────────────────────────────────────────────────────────────────────────────
// Icons
// ─────────────────────────────────────────────────────────────────────────────

/// Soft icon tile: a quiet tint of the icon's colour family with the glyph
/// in the deeper shade - colour as a hint, not a shout. [float] makes it bob
/// gently. ([shadow] is kept for older call sites and ignored.)
class VividIcon extends StatelessWidget {
  const VividIcon(
    this.icon, {
    super.key,
    this.tone,
    this.size = 48,
    this.iconSize,
    this.radius,
    this.float = false,
    this.shadow = true,
  });

  final IconData icon;

  /// Colour family; defaults to the icon's own ([Vivid.forIcon]).
  final VividTone? tone;
  final double size;
  final double? iconSize;
  final double? radius;
  final bool float;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = tone ?? Vivid.forIcon(icon);
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: v.tile(t),
        borderRadius: BorderRadius.circular(radius ?? size * 0.32),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.48, color: v.ink(t)),
    );
    return float ? FloatY(amplitude: size * 0.05, child: box) : box;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Headers & search
// ─────────────────────────────────────────────────────────────────────────────

/// Bold section heading with an emoji and a "See all" link.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.emoji, this.subtitle, this.action, this.onAction});

  final String title;
  final String? emoji;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      if (emoji != null) TextSpan(text: '$emoji  '),
                      TextSpan(text: title),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: t.text),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
              ],
            ),
          ),
          if (action != null)
            Pressable(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      Text(
                        action!,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Vivid.brand.ink(t)),
                      ),
                      Icon(AppIcons.chevronRight, size: 18, color: Vivid.brand.ink(t)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Big rounded search bar (opens the search screen). The hint rolls through
/// [hints] so students see what they can look for.
class SearchPill extends StatefulWidget {
  const SearchPill({super.key, required this.onTap, this.hints = const <String>['Search the app']});

  final VoidCallback onTap;
  final List<String> hints;

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    if (widget.hints.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
        if (mounted && TickerMode.of(context)) {
          setState(() => _i = (_i + 1) % widget.hints.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      label: 'Search',
      child: Pressable(
        scale: 0.98,
        child: Material(
          color: t.isNight ? t.surface : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: t.isNight ? t.border : const Color(0xFFF1E4DF))),
          shadowColor: Colors.black.withValues(alpha: 0.12),
          elevation: t.isNight ? 0 : 3,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const VividIcon(AppIcons.search, tone: Vivid.brand, size: 38, iconSize: 20, shadow: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduce ? 0 : 420),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: <Widget>[...previous, ?current],
                        ),
                        child: Text(
                          widget.hints[_i % widget.hints.length],
                          key: ValueKey<int>(_i),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, color: t.textMuted),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(999)),
                    child: Icon(AppIcons.filter, size: 18, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded chip with an emoji (target band, days left, streak).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.emoji, required this.label, this.tone, this.onTap});

  final String emoji;
  final String label;
  final VividTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = tone ?? Vivid.brand;
    return Pressable(
      child: Material(
        color: v.tile(t),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: v.ink(t)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banners
// ─────────────────────────────────────────────────────────────────────────────

/// One banner in a [PromoCarousel].
class PromoItem {
  const PromoItem({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.tone,
    required this.onTap,
    this.pose,
    this.icon,
    this.badge,
    this.image,
    this.id = '',
  });

  /// Stable id (custom cards from the server replace a built-in card with the same id).
  final String id;
  final String title;
  final String subtitle;
  final String cta;
  final VividTone tone;
  final VoidCallback onTap;

  /// Picture on the right instead of Nexi: an `https://` link or an
  /// `assets/...` path. Falls back to Nexi if it can't be loaded.
  final String? image;

  /// Nexi in this pose on the right (else [icon]).
  final NexiPose? pose;
  final IconData? icon;

  /// Small label in the top-left ("NEW", "FREE", "AI").
  final String? badge;
}

/// Swipeable gradient banners that move on by themselves, with growing
/// page dots, a parallax mascot and a shine sweep.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.items, this.height = 164, this.autoplay = true});

  final List<PromoItem> items;
  final double height;
  final bool autoplay;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _pc = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay && widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 4600), (_) => _next());
    }
  }

  void _next() {
    if (!mounted || _touching || !_pc.hasClients) return;
    if (!TickerMode.of(context)) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final n = (_page + 1) % widget.items.length;
    _pc.animateToPage(n, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        SizedBox(
            height: widget.height,
            child: Listener(
              onPointerDown: (_) => _touching = true,
              onPointerUp: (_) => _touching = false,
              onPointerCancel: (_) => _touching = false,
              child: PageView.builder(
                controller: _pc,
                padEnds: false,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _pc,
                  builder: (context, child) {
                    var delta = 0.0;
                    if (_pc.hasClients && _pc.position.haveDimensions) {
                      delta = (_pc.page ?? _page.toDouble()) - i;
                    } else {
                      delta = (_page - i).toDouble();
                    }
                    final scale = 1 - (delta.abs() * 0.06).clamp(0.0, 0.06);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Transform.scale(
                        scale: scale,
                        child: _PromoCard(item: widget.items[i], parallax: delta),
                      ),
                    );
                  },
                ),
              ),
            ),
        ),
        if (widget.items.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: i == _page ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? widget.items[i].tone.deep : t.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.item, required this.parallax});

  final PromoItem item;

  /// How far this page is from the centre (-1..1), for the art parallax.
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final v = item.tone;
    final r = BorderRadius.circular(24);
    final hasImage = (item.image ?? '').isNotEmpty;
    return Semantics(
      button: true,
      label: '${item.title}. ${item.cta}',
      child: Pressable(
        scale: 0.98,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: v.gradient,
            boxShadow: <BoxShadow>[BoxShadow(color: v.glow(0.25), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: item.onTap,
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -50,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)),
                    ),
                  ),
                  const Positioned.fill(child: ShineSweep(opacity: 0.12)),
                  Positioned(
                    right: 8 - parallax * 30,
                    bottom: 0,
                    child: hasImage
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PromoImage(item.image!, pose: item.pose),
                          )
                        : FloatY(amplitude: 3, child: Nexi(item.pose ?? NexiPose.point, height: 124)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 112, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge, title and line shrink a little to fit when
                        // they are bigger than the card (large text setting,
                        // long titles) instead of overflowing.
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) => FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: box.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  if (item.badge != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        item.badge!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, height: 1.3, color: Colors.white.withValues(alpha: 0.92)),
                                  ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Flexible(
                                child: Text(
                                  item.cta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: v.deep),
                                ),
                              ),
                              Icon(AppIcons.forward, size: 16, color: v.deep),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A custom card's picture (web link or asset), with Nexi as the fallback.
class _PromoImage extends StatelessWidget {
  const _PromoImage(this.src, {this.pose});

  final String src;
  final NexiPose? pose;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object _, StackTrace? _) => Nexi(pose ?? NexiPose.wave, height: 120);
    final img = src.startsWith('http')
        ? Image.network(src, width: 110, height: 120, fit: BoxFit.contain, errorBuilder: fallback)
        : Image.asset(src, width: 110, height: 120, fit: BoxFit.contain, errorBuilder: fallback);
    return ClipRRect(borderRadius: BorderRadius.circular(18), child: img);
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Category tiles
// ─────────────────────────────────────────────────────────────────────────────

/// Clean category card: plain surface, a soft tinted icon, the title, one
/// quiet line, an optional badge and progress line - and, when [pose] is
/// given, Nexi peeking from the bottom-right corner (the text keeps clear of
/// him, so nothing is ever covered).
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.title,
    required this.tone,
    required this.onTap,
    this.subtitle,
    this.pose,
    this.icon,
    this.badge,
    this.progress,
    this.height = 140,
    this.floatDelay = 0,
  });

  final String title;
  final String? subtitle;
  final VividTone tone;
  final VoidCallback onTap;
  final NexiPose? pose;
  final IconData? icon;
  final String? badge;

  /// 0..1 progress line along the bottom (null = none).
  final double? progress;
  final double height;

  /// 0..1: offsets Nexi's bobbing so tiles don't move in step.
  final double floatDelay;

  /// Nexi on the tile. Oct 2026: moved from the bottom-right corner (where it
  /// squeezed the titles to "Band descrip...") up to the empty top-right,
  /// beside the icon, so the title and subtitle get the full width.
  static const bool showNexi = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = tone;
    final hasNexi = showNexi && pose != null;
    return Semantics(
      button: true,
      label: [title, ?subtitle, ?badge].join(', '),
      child: AppCard(
        radius: 22,
        height: height,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Stack(
          children: [
            if (hasNexi)
              Positioned(
                right: 8,
                top: 6,
                child: FloatY(
                  amplitude: 2.5,
                  delay: floatDelay,
                  child: Nexi(pose!, height: height * 0.46),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VividIcon(icon ?? AppIcons.sparkle, tone: v, size: 38, iconSize: 20, radius: 12),
                      const Spacer(),
                      if (badge != null)
                        Flexible(
                          flex: 3,
                          child: Text(
                            badge!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.text),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Nexi sits above the words, so they use the full width.
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          // Two lines, so a long name wraps instead of "Band descrip...".
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: t.text,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: t.textMuted),
                            ),
                          ),
                        if (progress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _GrowLine(value: progress!, tone: v),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress line that fills up when it first shows.
class _GrowLine extends StatelessWidget {
  const _GrowLine({required this.value, required this.tone});

  final double value;
  final VividTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 4,
        color: t.track,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, w, _) => FractionallySizedBox(
            widthFactor: w,
            child: Container(height: 4, color: tone.ink(t)),
          ),
        ),
      ),
    );
  }
}

/// Small square shortcut (icon on top, label under) for a row of quick links.
class QuickTile extends StatelessWidget {
  const QuickTile({super.key, required this.icon, required this.label, required this.onTap, this.tone, this.dot = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VividTone? tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = tone ?? Vivid.forIcon(icon);
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        scale: 0.92,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 7,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: v.tile(t), borderRadius: BorderRadius.circular(20)),
                      alignment: Alignment.center,
                      child: VividIcon(icon, tone: v, size: 40, iconSize: 21, radius: 13),
                    ),
                    if (dot)
                      Positioned(right: -6, top: -6, child: PulseDot(color: t.alert, size: 9)),
                  ],
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cross-promotion banner (IELTS ⇄ Study abroad)
// ─────────────────────────────────────────────────────────────────────────────

/// One line of a [JourneyBanner].
class JourneyMessage {
  const JourneyMessage(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Big "live" banner that links the two halves of the app. The headline
/// rolls through [messages] every few seconds, Nexi floats on the right with
/// little emojis drifting around him, and a soft light sweeps across.
class JourneyBanner extends StatefulWidget {
  const JourneyBanner({
    super.key,
    required this.tag,
    required this.messages,
    required this.cta,
    required this.colors,
    required this.onTap,
    this.pose = NexiPose.grad,
    this.emojis = const <String>['✈️', '🎓', '🌍'],
  });

  /// Small label at the top ("✈️ STUDY ABROAD").
  final String tag;
  final List<JourneyMessage> messages;
  final String cta;

  /// Background gradient, top-left to bottom-right.
  final List<Color> colors;
  final VoidCallback onTap;
  final NexiPose pose;
  final List<String> emojis;

  @override
  State<JourneyBanner> createState() => _JourneyBannerState();
}

class _JourneyBannerState extends State<JourneyBanner> {
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    if (widget.messages.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
        if (!mounted || !TickerMode.of(context)) return;
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
        setState(() => _i = (_i + 1) % widget.messages.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();
    final m = widget.messages[_i % widget.messages.length];
    final r = BorderRadius.circular(26);
    final accent = widget.colors.last;
    final emoji = widget.emojis.isEmpty ? '' : widget.emojis.first;
    return Semantics(
      button: true,
      label: '${m.title}. ${widget.cta}',
      child: Pressable(
        scale: 0.975,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.colors),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: SizedBox(
                height: 184,
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -60,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.13)),
                      ),
                    ),
                    const Positioned.fill(child: ShineSweep(opacity: 0.12)),
                    if (emoji.isNotEmpty)
                      Positioned(
                        right: 112,
                        top: 18,
                        child: FloatY(
                          amplitude: 5,
                          rotate: 0.15,
                          period: const Duration(milliseconds: 2400),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: FloatY(amplitude: 4, child: Nexi(widget.pose, height: 136)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 124, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // The headline glides to the next one every few seconds.
                          // When the text is bigger than the space (large text setting,
                          // a long custom headline), it shrinks a little to fit
                          // instead of overflowing.
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) => ClipRect(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 520),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: a,
                                  child: SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                                    child: child,
                                  ),
                                ),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topLeft,
                                  children: <Widget>[...previous, ?current],
                                ),
                                child: FittedBox(
                                  key: ValueKey<int>(_i),
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topLeft,
                                  child: SizedBox(
                                  width: box.maxWidth,
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      m.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        height: 1.18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.3,
                                        color: Colors.white.withValues(alpha: 0.92),
                                      ),
                                    ),
                                  ],
                                  ),
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.cta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent),
                                  ),
                                ),
                                Icon(AppIcons.forward, size: 16, color: accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
