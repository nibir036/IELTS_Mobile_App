import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/switch_fab.dart';
import '../home/dashboard_screen.dart';
import '../home/module_hub_screen.dart';
import '../home/profile_screen.dart';
import '../mock/mock_library_screen.dart';
import '../resources/community_channels_screen.dart';

/// Bottom-nav shell: Home (B1) · Practice (B3) · Mock tests (G1) ·
/// Community (H3) · Profile (B7). The floating pill nav matches the canvas.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  /// Lets a tab screen switch tabs: `MainShell.of(context)?.select(2)`.
  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  /// Space tab screens leave at the bottom so content clears the nav.
  static const double navClearance = 112;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex.clamp(0, 4).toInt();

  /// Swipe left / right between the five tabs; tapping the nav slides there.
  late final PageController _pages = PageController(initialPage: _index);

  /// True while a tap-driven slide runs, so the in-between pages it passes
  /// don't flicker the nav highlight.
  bool _jumping = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Switch tab (nav tap or `MainShell.of(context)?.select(i)`). Neighbours
  /// slide over; a far tab jumps next to the target first, so the slide is
  /// always one page long and the tabs in between aren't built.
  Future<void> select(int i) async {
    if (i == _index || !_pages.hasClients) {
      if (i != _index) setState(() => _index = i);
      return;
    }
    setState(() => _index = i);
    _jumping = true;
    final from = _pages.page?.round() ?? _index;
    if ((i - from).abs() > 1) _pages.jumpToPage(i > from ? i - 1 : i + 1);
    await _pages.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    _jumping = false;
  }

  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  static Widget _tab(int i) => switch (i) {
        0 => const DashboardScreen(),
        1 => const ModuleHubScreen(),
        2 => const MockLibraryScreen(),
        3 => const CommunityChannelsScreen(),
        _ => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // The phone's back button: first to the Home tab, then out to the start
    // screen (IELTS / Study abroad) rather than closing the app.
    return PopScope(
      canPop: _index == 0 && !NextedAccess.I.enabled,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        if (_index != 0) {
          select(0);
        } else if (NextedAccess.I.enabled) {
          context.resetTo(Routes.chooser);
        }
      },
      child: Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          // Tabs are built the first time they're shown and then kept (with
          // their scroll position); only the current tab runs animations.
          Positioned.fill(
            child: ScrollConfiguration(
              // Mouse drags swipe too (web / desktop testing), not just touch.
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: _dragDevices),
              child: PageView.builder(
                controller: _pages,
                itemCount: 5,
                onPageChanged: (i) {
                  if (!_jumping && i != _index) setState(() => _index = i);
                },
                itemBuilder: (context, i) => _KeepTab(
                  child: TickerMode(enabled: i == _index, child: _tab(i)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18 + MediaQuery.of(context).padding.bottom * 0.5,
            child: _NavBar(index: _index, onTap: select),
          ),
          // One tap from anywhere in IELTS to the study-abroad side: the peach
          // "STUDY ABROAD" pill just above the nav bar, only for students who
          // have access to that side.
          Positioned(
            right: 20,
            bottom: 104 + MediaQuery.of(context).padding.bottom * 0.5,
            child: AnimatedBuilder(
              animation: NextedAccess.I,
              builder: (context, _) => NextedAccess.I.enabled
                  ? AppSwitchFab.toStudyAbroad(onTap: () => context.resetTo(Routes.nexted))
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Keeps a tab alive once built, so swiping back doesn't rebuild it.
class _KeepTab extends StatefulWidget {
  const _KeepTab({required this.child});

  final Widget child;

  @override
  State<_KeepTab> createState() => _KeepTabState();
}

class _KeepTabState extends State<_KeepTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Bottom nav: each tab has its own colour. The selected tab's icon sits on
/// a gradient bubble that slides across, swaps to its filled glyph with a
/// bounce, and its label lights up in the tab's colour.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData, String, VividTone)>[
    (AppIcons.home, AppIcons.homeFilled, 'Home', Vivid.brand),
    (AppIcons.practice, AppIcons.practiceFilled, 'Practice', Vivid.reading),
    (AppIcons.mock, AppIcons.mockFilled, 'Mock', Vivid.mock),
    (AppIcons.chat, AppIcons.chatFilled, 'Community', Vivid.community),
    (AppIcons.profile, AppIcons.profileFilled, 'Profile', Vivid.speaking),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final n = _items.length;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final slide = Duration(milliseconds: reduce ? 0 : 420);

    // Icons only: the name is read out by screen readers and shown on a
    // long press.
    final bar = SizedBox(
      height: 62,
      child: Stack(
        children: [
          // The sliding bubble behind the selected icon.
          AnimatedAlign(
            duration: slide,
            curve: Curves.easeOutBack,
            alignment: Alignment(-1 + 2 * index / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              child: SizedBox(
                height: 40,
                child: Center(
                  child: AnimatedContainer(
                  duration: slide,
                  curve: Curves.easeOutCubic,
                  width: 56,
                  height: 40,
                  // One accent for every tab (black by day, peach at night),
                  // like the big ride and food apps - calm, not a rainbow.
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _items[i].$3,
                    child: Pressable(
                      scale: 0.86,
                      child: InkResponse(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(i);
                        },
                        radius: 34,
                        highlightShape: BoxShape.circle,
                        child: Tooltip(
                          message: _items[i].$3,
                          child: SizedBox(
                            height: 62,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: reduce ? 0 : 320),
                                transitionBuilder: (child, a) => ScaleTransition(
                                  scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                                  child: child,
                                ),
                                child: Icon(
                                  i == index ? _items[i].$2 : _items[i].$1,
                                  key: ValueKey<bool>(i == index),
                                  size: 24,
                                  color: i == index ? t.onPrimary : t.textMuted,
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
        ],
      ),
    );

    // Frosted pill: blurs the page scrolling underneath.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isNight ? 0.45 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: t.isNight ? t.raised : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: t.glassBorder),
            ),
            child: Material(type: MaterialType.transparency, child: bar),
          ),
        ),
      ),
    );
  }
}
