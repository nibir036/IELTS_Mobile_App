import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen frame
// ─────────────────────────────────────────────────────────────────────────────

/// Standard screen: page background, safe area, 20px side padding, vertical
/// [gap] between [children]. Content scrolls; [footer] stays pinned at the
/// bottom (use it for the main CTA that sits at the bottom of an artboard).
///
/// Set [fill] to true when the children use `Spacer()` to push content to the
/// bottom on tall phones (the artboard's `margin-top: auto`). In fill mode
/// do not put ListView / GridView / LayoutBuilder inside [children].
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.gap = 14,
    this.footer,
    this.footerPadding = const EdgeInsets.fromLTRB(20, 8, 20, 16),
    this.fill = false,
    this.scroll = true,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.background,
    this.scrollBack = true,
  });

  /// Show a floating back button when the student scrolls up a little
  /// (pushed screens only). See [BackOnScrollUp].
  final bool scrollBack;

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;
  final Widget? footer;
  final EdgeInsets footerPadding;
  final bool fill;
  final bool scroll;
  final CrossAxisAlignment crossAxisAlignment;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return StaggerIn(
      children: children,
      builder: (context, items) => _frame(context, items),
    );
  }

  Widget _frame(BuildContext context, List<Widget> children) {
    final t = context.tk;
    final column = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: children,
    );

    Widget body;
    if (!scroll) {
      body = Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          spacing: gap,
          children: children,
        ),
      );
    } else if (fill) {
      body = LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, box.maxHeight - padding.vertical),
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                spacing: gap,
                children: children,
              ),
            ),
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(padding: padding, child: column);
    }

    final content = SafeArea(
      bottom: footer == null,
      child: Column(
        children: [
          Expanded(child: body),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(padding: footerPadding, child: footer!),
            ),
        ],
      ),
    );
    final framed = scrollBack && scroll ? BackOnScrollUp(child: content) : content;
    return Scaffold(
      backgroundColor: background ?? t.bg,
      body: background != null
          ? framed
          : Stack(children: [const Positioned.fill(child: GlassBackdrop()), framed]),
    );
  }
}

/// Facebook-style back button: the screen's own header (and its back
/// button) scrolls away with the content; scrolling up a little slides a
/// floating frosted back button in at the same spot, and scrolling down
/// hides it again. Only on screens that can go back.
///
/// Wrap a screen's body (anything containing its vertical scroll view).
class BackOnScrollUp extends StatefulWidget {
  const BackOnScrollUp({super.key, required this.child, this.onBack});

  final Widget child;

  /// Defaults to `Navigator.maybePop` (respects PopScope guards).
  final VoidCallback? onBack;

  @override
  State<BackOnScrollUp> createState() => _BackOnScrollUpState();
}

class _BackOnScrollUpState extends State<BackOnScrollUp> {
  /// Below this offset the real header is still on screen.
  static const double _headerZone = 72;

  bool _shown = false;
  double _travel = 0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (n.metrics.pixels <= _headerZone) {
        _travel = 0;
        _set(false);
      } else {
        // Count travel in one direction; reset when it flips.
        _travel = (d < 0) == (_travel < 0) ? _travel + d : d;
        if (_travel < -12) _set(true);
        if (_travel > 12) _set(false);
      }
    }
    return false;
  }

  void _set(bool v) {
    if (v != _shown) setState(() => _shown = v);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    if (!canPop && widget.onBack == null) return widget.child;
    final t = context.tk;
    final top = MediaQuery.paddingOf(context).top;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: top + 10,
            left: 16,
            child: IgnorePointer(
              ignoring: !_shown,
              child: AnimatedSlide(
                offset: _shown ? Offset.zero : const Offset(0, -1.6),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _shown ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Tooltip(
                    message: 'Back',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: t.isNight ? 0.4 : 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Material(
                            color: t.isNight ? const Color(0xCC1A1D2C) : const Color(0xE6FFFFFF),
                            shape: CircleBorder(side: BorderSide(color: t.glassBorder)),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
                              child: SizedBox(
                                width: 46,
                                height: 46,
                                child: Icon(AppIcons.back, size: 19, color: t.text),
                              ),
                            ),
                          ),
                        ),
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

/// Page background: the base colour with a soft peach glow top-left and a
/// blue glow bottom-right, so glass cards ([AppCard]) read as frosted.
/// Gradients only (no blur filter), so it's cheap on budget phones.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, this.flip = false});

  /// Swap the corners (variety between screens).
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget blob(Color c, Alignment a, double size) => Align(
          alignment: a,
          child: FractionalTranslation(
            translation: Offset(a.x * 0.35, a.y * 0.25),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [c.withValues(alpha: t.isNight ? 0.55 : 0.75), c.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        );
    return IgnorePointer(
      child: ColoredBox(
        color: t.bg,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = math.max(box.maxWidth, 320.0) * 1.1;
            return Stack(
              children: [
                blob(t.blobA, flip ? Alignment.topRight : Alignment.topLeft, size),
                blob(t.blobB, flip ? Alignment.bottomLeft : Alignment.bottomRight, size),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Real frosted glass (blurs what's behind): for floating bars and hero
/// panels. Use sparingly - each one costs a blur pass.
class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.color,
    this.blur = 18,
    this.padding = EdgeInsets.zero,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final double blur;
  final EdgeInsets padding;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? t.glassFill,
            borderRadius: r,
            border: border ? Border.all(color: t.glassBorder) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Header row: back button, optional title/subtitle, trailing actions.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.actions = const <Widget>[],
    this.center,
  });

  final String? title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Replaces the title block (e.g. a progress bar or step indicator).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 10,
      children: [
        if (showBack)
          IconBox(
            icon: AppIcons.back,
            tooltip: 'Back',
            iconSize: 18,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        Expanded(
          child: center ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                ],
              ),
        ),
        ...actions,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

/// Square-ish icon button (header buttons, 44–48px, radius 16–18).
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.radius = 16,
    this.iconSize = 20,
    this.bg,
    this.fg,
    this.tooltip,
    this.dot = false,
    this.circle = false,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double radius;
  final double iconSize;
  final Color? bg;
  final Color? fg;
  final String? tooltip;

  /// Small alert dot in the top-right corner (notifications).
  final bool dot;
  final bool circle;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    Widget box = Material(
      color: bg ?? t.raised,
      shape: borderColor == null
          ? shape
          : (circle
              ? CircleBorder(side: BorderSide(color: borderColor!))
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                  side: BorderSide(color: borderColor!),
                )),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: iconSize, color: fg ?? t.text),
              if (dot)
                Positioned(
                  top: size * 0.25,
                  right: size * 0.27,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: t.alert,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) {
      box = Tooltip(message: tooltip!, child: box);
    }
    return box;
  }
}

/// Main button: peach gradient pill with dark text (the course style).
/// Pass [bg]/[fg] for a solid colour instead.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.trailing,
    this.height = 56,
    this.radius = 999,
    this.bg,
    this.fg,
    this.fontSize = 16,
    this.expand = true,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final IconData? trailing;
  final double height;
  final double radius;
  final Color? bg;
  final Color? fg;
  final double fontSize;
  final bool expand;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final peach = bg == null;
    final foreground = fg ?? (peach ? kOnPeach : context.tk.onPrimary);
    final r = BorderRadius.circular(radius.clamp(0, height / 2).toDouble());
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: Material(
          color: peach ? Colors.transparent : bg,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: peach ? kPeachGradient : null, borderRadius: r),
            child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  if (leading != null)
                    Icon(leading, size: 18, color: foreground),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: peach ? FontWeight.w600 : FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Icon(trailing, size: 18, color: foreground),
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

/// Outlined button (1.5px border in text colour). 58px, radius 20.
class OutlineButtonX extends StatelessWidget {
  const OutlineButtonX({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.trailing,
    this.height = 58,
    this.radius = 20,
    this.color,
    this.fontSize = 16,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final IconData? trailing;
  final double height;
  final double radius;
  final Color? color;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = color ?? t.text;
    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                if (leading != null) Icon(leading, size: 18, color: c),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: c,
                    ),
                  ),
                ),
                if (trailing != null) Icon(trailing, size: 18, color: c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft button on [AppTokens.surfaceAlt] (secondary actions, small pills).
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.trailing,
    this.height = 44,
    this.radius = 999,
    this.bg,
    this.fg,
    this.fontSize = 14,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final IconData? trailing;
  final double height;
  final double radius;
  final Color? bg;
  final Color? fg;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = fg ?? t.text;
    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: bg ?? t.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                if (leading != null) Icon(leading, size: 16, color: c),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: c,
                    ),
                  ),
                ),
                if (trailing != null) Icon(trailing, size: 16, color: c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big pill CTA from the splash ("Get started" + round arrow chip).
class PillCta extends StatelessWidget {
  const PillCta({
    super.key,
    required this.label,
    this.onTap,
    this.icon = AppIcons.forward,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const ShapeDecoration(gradient: kPeachGradient, shape: StadiumBorder()),
          child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kOnPeach,
                    ),
                  ),
                ),
                Container(
                  width: height - 16,
                  height: height - 16,
                  decoration: const BoxDecoration(
                    color: kOnPeach,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFFFFB8A3)),
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

/// Plain text link (e.g. "Forgot password?").
class LinkText extends StatelessWidget {
  const LinkText(
    this.text, {
    super.key,
    this.onTap,
    this.fontSize = 14,
    this.color,
    this.weight = FontWeight.w500,
    this.underline = false,
  });

  final String text;
  final VoidCallback? onTap;
  final double fontSize;
  final Color? color;
  final FontWeight weight;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: color ?? context.tk.text,
            decoration:
                underline ? TextDecoration.underline : TextDecoration.none,
            decorationColor: color ?? context.tk.text,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surfaces
// ─────────────────────────────────────────────────────────────────────────────

/// White (Day) / #151515 (Night) card. Default radius 26.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 26,
    this.color,
    this.borderColor,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        // Frosted glass over the page's colour blobs (see [GlassBackdrop]).
        color: color ?? t.glassFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor ?? (color == null ? t.glassBorder : Colors.transparent)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Hero card in the course style: dark navy with a soft peach glow
/// (top-left) and blue glow (bottom-right), in Day and Night. Text inside is
/// light ([AppTokens.heroText]); use [AppTokens.heroMuted] for labels,
/// [AppTokens.heroChip] for inner tiles and `onHero: true` on progress.
///
/// [gradient] is ignored (kept so older call sites still compile).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 28,
    this.onTap,
    this.gradient,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: t.heroText),
      child: IconTheme.merge(
        data: IconThemeData(color: t.heroText),
        child: Padding(padding: padding, child: child),
      ),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: t.heroGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: t.isNight
            ? null
            : const [BoxShadow(color: Color(0x2E151827), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: HeroGlow()),
            onTap == null ? content : InkWell(onTap: onTap, child: content),
          ],
        ),
      ),
    );
  }
}

/// The peach (top-left) and blue (bottom-right) glow behind hero cards and
/// the dark lesson screens.
class HeroGlow extends StatelessWidget {
  const HeroGlow({super.key, this.size = 420, this.strength = 0.28});

  final double size;
  final double strength;

  @override
  Widget build(BuildContext context) {
    Widget glow(Color c, Alignment a) => Align(
          alignment: a,
          child: FractionalTranslation(
            translation: Offset(a.x * 0.4, a.y * 0.3),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [c.withValues(alpha: strength), c.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        );
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: [
            glow(const Color(0xFFFF9C82), Alignment.topLeft),
            glow(const Color(0xFF5B7CF0), Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}

/// Peach gradient used by the main buttons and progress fills.
const LinearGradient kPeachGradient = LinearGradient(colors: [Color(0xFFFFB8A3), Color(0xFFFF9C82)]);
const LinearGradient kPeachFillGradient = LinearGradient(colors: [Color(0xFFFFB8A3), Color(0xFFFF7E67)]);

/// Ink colour for text on peach.
const Color kOnPeach = Color(0xFF151515);

/// Circle with an icon (skill icons in cards). Day #F5EEF2/black · Night #262626/cream.
class IconCircle extends StatelessWidget {
  const IconCircle(
    this.icon, {
    super.key,
    this.size = 40,
    this.iconSize,
    this.bg,
    this.fg,
  });

  final IconData icon;
  final double size;
  final double? iconSize;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? t.surfaceAlt, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize ?? size * 0.48, color: fg ?? t.iconAccent),
    );
  }
}

/// Rounded square with a letter/number (list leading: "M", "L", "Q1" …).
class LetterBadge extends StatelessWidget {
  const LetterBadge(
    this.text, {
    super.key,
    this.size = 36,
    this.radius = 12,
    this.bg,
    this.fg,
    this.fontSize = 13,
  });

  final String text;
  final double size;
  final double radius;
  final Color? bg;
  final Color? fg;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? t.surfaceAlt2,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: fg ?? t.iconAccent,
        ),
      ),
    );
  }
}

/// Initials avatar (Day black / Night cream).
class Avatar extends StatelessWidget {
  const Avatar(
    this.initials, {
    super.key,
    this.size = 48,
    this.bg,
    this.fg,
    this.image,
  });

  final String initials;
  final double size;
  final Color? bg;
  final Color? fg;

  /// Optional photo; shown instead of the initials when set.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg ?? t.primary,
        shape: BoxShape.circle,
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      child: image != null ? null : Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w500,
          color: fg ?? t.onPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tags, chips, tabs
// ─────────────────────────────────────────────────────────────────────────────

enum TagTone { primary, soft, outline, alert, accent, danger, success, hero }

/// Small pill label (26px). [TagTone.primary] = "Word of the day" style.
class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.tone = TagTone.soft,
    this.icon,
    this.height = 26,
    this.fontSize = 12,
  });

  final String text;
  final TagTone tone;
  final IconData? icon;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg;
    Color fg;
    Color? border;
    switch (tone) {
      case TagTone.primary:
        bg = t.primary;
        fg = t.onPrimary;
      case TagTone.soft:
        bg = t.surfaceAlt;
        fg = t.text;
      case TagTone.outline:
        bg = Colors.transparent;
        fg = t.text;
        border = t.border;
      case TagTone.alert:
        bg = t.alert;
        fg = t.onAlert;
      case TagTone.accent:
        bg = t.accentSoft;
        fg = t.isNight ? t.primary : t.text;
      case TagTone.danger:
        bg = t.dangerSoft;
        fg = t.dangerText;
      case TagTone.success:
        bg = t.successSoft;
        fg = t.success;
      case TagTone.hero:
        bg = t.heroChip;
        fg = t.heroText;
    }
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon != null) Icon(icon, size: fontSize + 2, color: fg),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable filter chip (36px). Selected = primary fill.
class ChipPill extends StatelessWidget {
  const ChipPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.height = 36,
    this.count,
    this.shrink = false,
  });

  /// Ellipsize a long label to fit the width it gets (use inside a [Wrap]
  /// or a bounded parent - not in a horizontal scroll view).
  final bool shrink;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bg = selected ? t.primary : t.raised;
    final fg = selected ? t.onPrimary : t.text;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
    );
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (icon != null) Icon(icon, size: 16, color: fg),
                if (shrink) Flexible(child: labelText) else labelText,
                if (count != null)
                  Text(
                    count!,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? t.onPrimary.withValues(alpha: 0.7)
                          : t.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroll row of [ChipPill]s with single selection.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        spacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            ChipPill(
              label: labels[i],
              selected: i == selected,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

/// Pill segmented control (track = raised, selected = primary).
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 44,
    this.trackColor,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor ?? t.raised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == index ? t.primary : Colors.transparent,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Center(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: i == index ? t.onPrimary : t.textMuted,
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

// ─────────────────────────────────────────────────────────────────────────────
// Progress
// ─────────────────────────────────────────────────────────────────────────────

/// Linear progress bar. On hero cards pass `onHero: true` (black on a
/// semi-transparent track - the Night rule for cream cards).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.onHero = false,
    this.track,
    this.fill,
  });

  final double value;
  final double height;
  final bool onHero;
  final Color? track;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        width: double.infinity,
        color: track ?? (onHero ? t.heroTrack : t.track),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              gradient: fill == null ? kPeachFillGradient : null,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of equal segments (step indicators, password strength, OTP steps).
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.count,
    required this.filled,
    this.height = 5,
    this.gap = 6,
    this.onHero = false,
  });

  final int count;
  final int filled;
  final double height;
  final double gap;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: gap,
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: i < filled
                    ? (onHero ? t.heroFill : t.fill)
                    : (onHero ? t.heroTrack : (t.isNight ? t.surface : t.border)),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Circular progress ring with a centred child (band score rings).
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    this.size = 116,
    this.stroke = 10,
    this.child,
    this.onHero = false,
    this.track,
    this.fill,
  });

  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final bool onHero;
  final Color? track;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          track: track ?? (onHero ? t.heroTrack : t.track),
          fill: fill ?? (onHero ? t.heroFill : t.fill),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.fill,
  });

  final double value;
  final double stroke;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.stroke != stroke;
}

/// Box filled with the canvas's diagonal stripe pattern (highlighted bar,
/// "in progress" segments).
class StripedBox extends StatelessWidget {
  const StripedBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.a,
    this.b,
    this.stripe = 3,
    this.gap = 4,
  });

  final double? width;
  final double? height;
  final double radius;
  final Color? a;
  final Color? b;
  final double stripe;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _StripePainter(
            a: a ?? t.stripeA,
            b: b ?? t.stripeB,
            stripe: stripe,
            gap: gap,
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter({
    required this.a,
    required this.b,
    required this.stripe,
    required this.gap,
  });

  final Color a;
  final Color b;
  final double stripe;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final p = Paint()
      ..color = a
      ..strokeWidth = stripe;
    final step = stripe + gap;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) =>
      old.a != a || old.b != b || old.stripe != stripe || old.gap != gap;
}

/// Simple vertical bar chart (study time per day etc.).
/// [highlight] index gets the stripe pattern.
class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.values,
    required this.labels,
    this.height = 92,
    this.highlight,
    this.barColor,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final int? highlight;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                spacing: 6,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: maxV <= 0
                            ? 0.1
                            : (values[i] / maxV).clamp(0.1, 1.0).toDouble(),
                        widthFactor: 1,
                        child: i == highlight
                            ? const StripedBox(width: double.infinity)
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: barColor ??
                                      (t.isNight ? t.surfaceAlt : t.track),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Text(
                    i < labels.length ? labels[i] : '',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: i == highlight ? t.text : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lists & text
// ─────────────────────────────────────────────────────────────────────────────

/// Section heading with an optional trailing action ("See all").
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.subtitle,
    this.fontSize = 18,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? subtitle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
              ),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(fontSize: 12, color: t.textMuted)),
            ],
          ),
        ),
        if (action != null)
          LinkText(action!, onTap: onAction, fontSize: 13, color: t.textMuted),
      ],
    );
  }
}

/// A list row: leading widget, title/subtitle, trailing widget.
/// Set [divider] to draw the top hairline used in card lists.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.divider = false,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.titleSize = 14,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  final EdgeInsets padding;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: t.divider)) : null,
        ),
        child: Row(
          spacing: 12,
          children: [
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: titleSize),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// 1px hairline in the divider colour.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color, this.vertical = false});

  final Color? color;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tk.divider;
    return vertical
        ? Container(width: 1, color: c)
        : Container(height: 1, color: c);
  }
}

/// Key–value row ("Target ····· 7.5").
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
    this.label,
    this.value, {
    super.key,
    this.labelColor,
    this.fontSize = 14,
  });

  final String label;
  final String value;
  final Color? labelColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: labelColor ?? context.tk.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Large light display number (band scores: 104px weight 300 etc.).
class BigNumber extends StatelessWidget {
  const BigNumber(
    this.text, {
    super.key,
    this.size = 56,
    this.color,
    this.weight = FontWeight.w300,
  });

  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: 0.95,
        letterSpacing: -size * 0.04,
        color: color,
      ),
    );
  }
}

/// Page headline (32px weight 500, tight tracking).
class Headline extends StatelessWidget {
  const Headline(
    this.text, {
    super.key,
    this.size = 32,
    this.weight = FontWeight.w500,
    this.color,
    this.subtitle,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            height: 1.1,
            letterSpacing: -size * 0.025,
            color: color,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: context.tk.textMuted,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forms
// ─────────────────────────────────────────────────────────────────────────────

/// Labelled input (56px, radius 18) as in the Login / Sign-up artboards.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.prefix,
    this.prefixIcon,
    this.password = false,
    this.keyboardType,
    this.onChanged,
    this.height = 56,
    this.maxLines = 1,
    this.suffix,
  });

  final String? label;
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;

  /// Widget before the input (e.g. the "+880 ▾" country code block).
  final Widget? prefix;
  final IconData? prefixIcon;
  final bool password;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final double height;
  final int maxLines;
  final Widget? suffix;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _c =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  bool _obscure = true;

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final multi = widget.maxLines > 1;
    final field = Container(
      height: multi ? null : widget.height,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: multi ? 12 : 0),
      decoration: BoxDecoration(
        color: t.isNight ? t.surface : t.raised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Row(
        spacing: 10,
        children: [
          if (widget.prefixIcon != null)
            Icon(widget.prefixIcon, size: 20, color: t.textMuted),
          ?widget.prefix,
          Expanded(
            child: TextField(
              controller: _c,
              obscureText: widget.password && _obscure,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              maxLines: widget.password ? 1 : widget.maxLines,
              minLines: 1,
              style: TextStyle(
                fontSize: 16,
                color: t.text,
                letterSpacing: widget.password && _obscure ? 2 : 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(color: t.textFaint, fontSize: 16),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.password)
            InkWell(
              onTap: () => setState(() => _obscure = !_obscure),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _obscure ? AppIcons.eye : AppIcons.eyeOff,
                  size: 20,
                  color: t.textMuted,
                ),
              ),
            ),
          ?widget.suffix,
        ],
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          widget.label!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: t.textMuted,
          ),
        ),
        field,
      ],
    );
  }
}

/// "+880 ▾" prefix block for phone inputs.
class CountryCodePrefix extends StatelessWidget {
  const CountryCodePrefix({super.key, this.code = '+880'});

  final String code;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 24,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.isNight ? t.text : t.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Icon(AppIcons.chevronDown, size: 16, color: t.text),
        ],
      ),
    );
  }
}

/// Rounded checkbox with label (primary fill when checked).
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.fontSize = 14,
    this.labelColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final double fontSize;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: value ? t.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: value ? null : Border.all(color: t.textMuted, width: 1.5),
              ),
              child: value
                  ? Icon(AppIcons.check, size: 14, color: t.onPrimary)
                  : null,
            ),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.4,
                  color: labelColor ?? t.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable option card (radio style) used by quizzes and selectors.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leadingText,
    this.state = OptionState.none,
    this.subtitle,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// "A", "B" … shown in a letter badge.
  final String? leadingText;
  final OptionState state;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg = t.surface;
    Color? border = t.border;
    Color fg = t.text;
    IconData? mark;
    switch (state) {
      case OptionState.correct:
        bg = t.successSoft;
        border = t.success;
        mark = AppIcons.checkCircle;
      case OptionState.wrong:
        bg = t.dangerSoft;
        border = t.danger;
        fg = t.dangerText;
        mark = AppIcons.error;
      case OptionState.none:
        if (selected) {
          bg = t.primary;
          border = null;
          fg = t.onPrimary;
        }
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: border == null ? BorderSide.none : BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            spacing: 12,
            children: [
              if (leadingText != null)
                LetterBadge(
                  leadingText!,
                  size: 30,
                  radius: 10,
                  bg: selected && state == OptionState.none
                      ? t.onPrimary.withValues(alpha: 0.15)
                      : t.surfaceAlt,
                  fg: selected && state == OptionState.none
                      ? t.onPrimary
                      : t.iconAccent,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontSize: 15, color: fg)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected && state == OptionState.none
                              ? t.onPrimary.withValues(alpha: 0.7)
                              : t.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (mark != null)
                Icon(
                  mark,
                  size: 20,
                  color: state == OptionState.correct ? t.success : t.danger,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum OptionState { none, correct, wrong }

// ─────────────────────────────────────────────────────────────────────────────
// Brand
// ─────────────────────────────────────────────────────────────────────────────

/// "IA" logo tile.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.primary,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Text(
        'IA',
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: t.isNight ? t.onPrimary : t.accentStrong,
        ),
      ),
    );
  }
}

/// Logo tile + "IELTS AI" + "by nextED".
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 40, this.showTagline = true});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        BrandMark(size: size),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'IELTS AI',
              style: TextStyle(
                fontSize: size * 0.48,
                fontWeight: FontWeight.w600,
                height: 1.05,
                letterSpacing: -0.3,
              ),
            ),
            if (showTagline)
              Text(
                'by nextED',
                style: TextStyle(
                  fontSize: size * 0.3,
                  height: 1.1,
                  color: t.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Sun / moon pill that switches Day ↔ Night.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final controller = ThemeScope.of(context);
    Widget item(IconData icon, bool active, bool night, String label) {
      return Semantics(
        button: true,
        label: label,
        child: Material(
          color: active ? t.primary : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => controller.setNight(night),
            child: SizedBox(
              width: 44,
              height: 36,
              child: Icon(
                icon,
                size: 18,
                color: active ? t.onPrimary : t.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          item(AppIcons.sun, !t.isNight, false, 'Light mode'),
          item(AppIcons.moon, t.isNight, true, 'Dark mode'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Misc
// ─────────────────────────────────────────────────────────────────────────────

/// Small round dot.
class Dot extends StatelessWidget {
  const Dot({super.key, this.size = 8, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? context.tk.alert,
          shape: BoxShape.circle,
        ),
      );
}

/// Fake waveform bars (recording / audio screens).
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    super.key,
    this.count = 36,
    this.height = 48,
    this.progress = 0,
    this.color,
    this.playedColor,
    this.seed = 7,
  });

  final int count;
  final double height;

  /// 0..1 - bars before this fraction use [playedColor].
  final double progress;
  final Color? color;
  final Color? playedColor;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final rnd = math.Random(seed);
    final heights = List<double>.generate(
      count,
      (i) => 0.2 + 0.8 * (0.5 + 0.5 * math.sin(i * 0.7 + seed)) * (0.6 + 0.4 * rnd.nextDouble()),
    );
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 3,
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Container(
                height: height * heights[i],
                decoration: BoxDecoration(
                  color: (i / count) < progress
                      ? (playedColor ?? t.fill)
                      : (color ?? (t.isNight ? t.surfaceAlt : t.border)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder block for images / charts that aren't built yet.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    this.height = 160,
    this.label,
    this.icon = AppIcons.chart,
    this.radius = 20,
  });

  final double height;
  final String? label;
  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(icon, color: t.textMuted, size: 28),
            if (label != null)
              Text(label!, style: TextStyle(fontSize: 12, color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Shows a styled bottom sheet with [child].
Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}

/// Shows a centred dialog card with [child].
Future<T?> showAppDialog<T>(BuildContext context, Widget child) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.tk.sheet,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    ),
  );
}

/// Empty state for anything that depends on the student's own activity
/// (new accounts have none): icon circle, title, message, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = AppIcons.sparkle,
    this.actionLabel,
    this.onAction,
    this.card = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Wrap in an [AppCard].
  final bool card;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final body = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          IconCircle(icon, size: 52),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          if (message != null)
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted),
            ),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: PrimaryButton(
                label: actionLabel!,
                onTap: onAction,
                height: 48,
                radius: 16,
                fontSize: 14,
                expand: false,
              ),
            ),
        ],
      ),
    );
    if (!card) return Center(child: body);
    return AppCard(padding: EdgeInsets.zero, child: SizedBox(width: double.infinity, child: body));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Motion
// ─────────────────────────────────────────────────────────────────────────────

/// Plays a one-time entrance for a screen's sections: each child fades in and
/// rises 18px, one after another (first 8 staggered, the rest together).
/// Used by [AppScreen]; wrap other lists with it the same way. Skipped when
/// the system asks for reduced motion.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.children, required this.builder});

  final List<Widget> children;
  final Widget Function(BuildContext context, List<Widget> children) builder;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  static const int _staggered = 8;
  static const int _stepMs = 55;
  static const int _itemMs = 420;
  static const int _totalMs = _itemMs + _stepMs * (_staggered - 1);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  final List<Animation<double>> _curves = <Animation<double>>[];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  Animation<double> _curve(int i) {
    while (_curves.length <= i) {
      final k = math.min(_curves.length, _staggered - 1);
      final start = k * _stepMs / _totalMs;
      final end = (k * _stepMs + _itemMs) / _totalMs;
      _curves.add(_c.drive(CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic))));
    }
    return _curves[i];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (var i = 0; i < widget.children.length; i++)
        // Spacer / Expanded must stay direct children of the Column.
        if (widget.children[i] is Spacer || widget.children[i] is Flexible)
          widget.children[i]
        else
          _Rise(animation: _curve(i), child: widget.children[i]),
    ];
    return widget.builder(context, items);
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 18 * (1 - animation.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Fades + slides a widget in when it first appears ([delay] lets several
/// line up). For cards that pop up after a load or a state change.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 14),
    this.duration = const Duration(milliseconds: 380),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a = _c.drive(CurveTween(curve: Curves.easeOutCubic));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Transform.translate(
          offset: widget.offset * (1 - _a.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Blurs [child] behind a "Coming soon" card. The content underneath can't
/// be tapped or read by screen readers. [onBack] adds a back button.
class ComingSoonWall extends StatelessWidget {
  const ComingSoonWall({
    super.key,
    required this.child,
    required this.title,
    required this.message,
    this.icon = AppIcons.chat,
    this.onBack,
    this.bottomInset = 0,
  });

  final Widget child;
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onBack;

  /// Space kept clear at the bottom (e.g. the floating nav bar).
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: ExcludeSemantics(child: child)),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: ColoredBox(
              color: t.bg.withValues(alpha: t.isNight ? 0.55 : 0.45),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, 0, 28, bottomInset),
                  child: Center(
                    child: FadeIn(
                      child: AppCard(
                        radius: 28,
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        borderColor: t.border,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                              child: Icon(icon, size: 24, color: t.onPrimary),
                            ),
                            const Tag('Coming soon', tone: TagTone.accent),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: -0.4),
                            ),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onBack != null)
          Positioned(
            left: 20,
            top: 12 + MediaQuery.paddingOf(context).top,
            child: IconBox(icon: AppIcons.back, tooltip: 'Back', iconSize: 18, onTap: onBack),
          ),
      ],
    );
  }
}
