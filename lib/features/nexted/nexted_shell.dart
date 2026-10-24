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
/// bottom, which the nav would cover); the other four are tabs.
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

  /// Tabs are built the first time they're opened, then kept.
  late final Set<int> _built = <int>{_index};

  static const List<(IconData, IconData, String)> _items = <(IconData, IconData, String)>[
    (AppIcons.home, AppIcons.homeFilled, 'Home'),
    (AppIcons.compass, AppIcons.compassFilled, 'Guidance'),
    (AppIcons.doc, AppIcons.docFilled, 'Documents'),
    (AppIcons.chat, AppIcons.chatFilled, 'Counsellor'),
    (AppIcons.profile, AppIcons.profileFilled, 'Profile'),
  ];

  void select(int i) {
    if (i == NextedShell.counsellorItem) {
      context.push(Routes.nextedCounsellor);
      return;
    }
    if (i == _index) return;
    setState(() {
      _index = i;
      _built.add(i);
    });
  }

  Widget _tab(int i) => switch (i) {
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
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    if (i == NextedShell.counsellorItem)
                      const SizedBox.shrink()
                    else
                      TickerMode(
                        enabled: i == _index,
                        child: _built.contains(i) ? _tab(i) : const SizedBox.shrink(),
                      ),
                ],
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
