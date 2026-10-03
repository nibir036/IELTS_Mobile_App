import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../home/dashboard_screen.dart';
import '../home/module_hub_screen.dart';
import '../home/profile_screen.dart';
import '../mock/mock_library_screen.dart';
import '../resources/community_channels_screen.dart';
import '../resources/widgets.dart' show communityUnreadThreads;

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
    final unread = communityUnreadThreads(context.store);
    return Scaffold(
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
            left: 20,
            right: 20,
            bottom: 22 + MediaQuery.of(context).padding.bottom * 0.5,
            child: _NavBar(
              index: _index,
              onTap: select,
              chatBadge: unread > 0 ? '$unread' : null,
            ),
          ),
        ],
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

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap, this.chatBadge});

  final int index;
  final ValueChanged<int> onTap;
  final String? chatBadge;

  static const _items = <(IconData, String)>[
    (AppIcons.home, 'Home'),
    (AppIcons.practice, 'Practice'),
    (AppIcons.mock, 'Mock tests'),
    (AppIcons.chat, 'Community chat'),
    (AppIcons.profile, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isNight ? 0.4 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < _items.length; i++)
            Tooltip(
              message: _items[i].$2,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: i == index ? t.primary : t.primary.withValues(alpha: 0),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedScale(
                          scale: i == index ? 1.08 : 1,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            _items[i].$1,
                            size: 22,
                            color: i == index ? t.onPrimary : t.textMuted,
                          ),
                        ),
                        if (i == 3 && chatBadge != null)
                          Positioned(
                            top: 8,
                            right: 6,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.alert,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                chatBadge!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: t.isNight ? t.onAlert : const Color(0xFF151515),
                                ),
                              ),
                            ),
                          ),
                      ],
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
