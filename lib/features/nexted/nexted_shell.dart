import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/switch_fab.dart';
import '../shell/main_shell.dart' show AppNavBar;
import 'nexted_documents_screen.dart';
import 'nexted_hub_screen.dart';
import 'nexted_journey_screen.dart';
import 'nexted_profile_screen.dart';

/// The study-abroad side, with the same floating bottom nav as IELTS:
/// Home · Guidance · Documents · Counsellor · Profile.
///
/// The Counsellor opens as its own screen (it has a typing box at the
/// bottom, which the nav would cover); the other four are tabs, and a
/// swipe left / right moves between them, like the IELTS side.
class NextedShell extends StatefulWidget {
  const NextedShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static const int homeTab = 0;
  static const int journeyTab = 1;
  static const int documentsTab = 2;
  static const int counsellorItem = 3;
  static const int profileTab = 4;

  /// Lets a tab switch tabs: `NextedShell.of(context)?.select(NextedShell.documentsTab)`.
  static NextedShellState? of(BuildContext context) => context.findAncestorStateOfType<NextedShellState>();

  @override
  State<NextedShell> createState() => NextedShellState();
}

class NextedShellState extends State<NextedShell> {
  late int _index = widget.initialIndex == NextedShell.counsellorItem ? 0 : widget.initialIndex.clamp(0, 4).toInt();

  /// Nav item -> page: the Counsellor (item 3) has no page.
  static int _pageOf(int item) => item > NextedShell.counsellorItem ? item - 1 : item;
  static int _itemOf(int page) => page >= NextedShell.counsellorItem ? page + 1 : page;

  /// Swipe between Home, Guidance, Documents and Profile; tapping the nav
  /// slides there.
  late final PageController _pages = PageController(initialPage: _pageOf(_index));

  /// True while a tap-driven slide runs, so the pages it passes don't
  /// flicker the nav highlight.
  bool _jumping = false;

  static const List<(IconData, IconData, String)> _items = <(IconData, IconData, String)>[
    (AppIcons.home, AppIcons.homeFilled, 'Home'),
    (AppIcons.compass, AppIcons.compassFilled, 'Guidance'),
    (AppIcons.doc, AppIcons.docFilled, 'Documents'),
    (AppIcons.chat, AppIcons.chatFilled, 'Counsellor'),
    (AppIcons.profile, AppIcons.profileFilled, 'Profile'),
  ];

  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> select(int i) async {
    if (i == NextedShell.counsellorItem) {
      context.push(Routes.nextedCounsellor);
      return;
    }
    if (i == _index || !_pages.hasClients) {
      if (i != _index) setState(() => _index = i);
      return;
    }
    setState(() => _index = i);
    _jumping = true;
    final to = _pageOf(i);
    final from = _pages.page?.round() ?? to;
    // A far tab jumps next to the target first, so the slide is one page.
    if ((to - from).abs() > 1) _pages.jumpToPage(to > from ? to - 1 : to + 1);
    await _pages.animateToPage(to, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    _jumping = false;
  }

  Widget _tab(int page) => switch (_itemOf(page)) {
        NextedShell.homeTab => const NextedHubScreen(),
        NextedShell.journeyTab => const NextedJourneyScreen(embedded: true),
        NextedShell.documentsTab => const NextedDocumentsScreen(embedded: true),
        _ => const NextedProfileScreen(embedded: true),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bottom = MediaQuery.of(context).padding.bottom * 0.5;
    // The phone's back button: first back to Home, then out to the start
    // screen (IELTS / Study abroad) - never straight out of the app.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || !mounted) return;
        if (_index != NextedShell.homeTab) {
          select(NextedShell.homeTab);
        } else {
          context.resetTo(Routes.chooser);
        }
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: ScrollConfiguration(
                // Mouse drags swipe too (web / desktop testing), not just touch.
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: _dragDevices),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: 4,
                  onPageChanged: (p) {
                    final i = _itemOf(p);
                    if (!_jumping && i != _index) setState(() => _index = i);
                  },
                  itemBuilder: (context, p) => _KeepTab(
                    child: TickerMode(enabled: _itemOf(p) == _index, child: _tab(p)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18 + bottom,
              child: AppNavBar(index: _index, onTap: select, items: _items),
            ),
            // Across to IELTS, just above the nav - on Home and Guidance only;
            // Documents and Profile have their own button there.
            if (_index == NextedShell.homeTab || _index == NextedShell.journeyTab)
              Positioned(
                right: 20,
                bottom: 104 + bottom,
                child: AppSwitchFab.toIelts(onTap: () => context.resetTo(Routes.home)),
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
