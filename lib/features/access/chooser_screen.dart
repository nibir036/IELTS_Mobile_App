import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/vivid.dart';

/// Where the student lands after signing in: the two halves of the app.
///
/// **IELTS** opens the trainer (the bottom-nav shell). **Study abroad** opens
/// the nexted.app module. A student without study-abroad access never sees
/// this screen - they go straight to the IELTS app.
class ChooserScreen extends StatefulWidget {
  const ChooserScreen({super.key});

  @override
  State<ChooserScreen> createState() => _ChooserScreenState();
}

class _ChooserScreenState extends State<ChooserScreen> {
  bool _left = false;

  @override
  void initState() {
    super.initState();
    NextedAccess.I.refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _skipIfOnlyIelts());
  }

  /// Nothing to choose between: open the IELTS app.
  void _skipIfOnlyIelts() {
    if (_left || !mounted) return;
    if (NextedAccess.I.loaded && !NextedAccess.I.enabled) {
      _left = true;
      context.resetTo(Routes.home);
    }
  }

  void _open(String route) {
    _left = true;
    context.resetTo(route);
  }

  /// Sign out and go back to the login screen.
  Future<void> _logout() async {
    final ok = await showAppDialog<bool>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const Text('Log out?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            Text(
              'You’ll need your phone number and password to sign in again.',
              style: TextStyle(fontSize: 14, height: 1.45, color: ctx.tk.textMuted),
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: OutlineButtonX(
                    label: 'Cancel',
                    height: 48,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                Expanded(
                  child: PrimaryButton(
                    label: 'Log out',
                    height: 48,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await Store.I.signOut();
    NextedAccess.I.clear();
    if (!mounted) return;
    _left = true;
    context.resetTo(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final name = Store.I.current?.name ?? '';
    final first = name.trim().isEmpty ? '' : name.trim().split(' ').first;

    return AnimatedBuilder(
      animation: NextedAccess.I,
      builder: (context, _) {
        // Navigate after this frame, never in the middle of a build.
        WidgetsBinding.instance.addPostFrameCallback((_) => _skipIfOnlyIelts());
        final study = NextedAccess.I.enabled;

        return AppScreen(
          gap: 16,
          fill: true,
          scrollBack: false,
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          children: [
            // The greeting on the left, Nexi in a graduation cap on the right:
            // one picture for both halves (the band score, then the campus).
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Text(
                          first.isEmpty ? 'Welcome back' : 'Welcome back,\n$first',
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                        Text(
                          'Where would you like to start?',
                          style: TextStyle(fontSize: 15, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const FloatY(amplitude: 4, child: Nexi(NexiPose.grad, height: 132)),
              ],
            ),
            const SizedBox(height: 2),

            _ModeCard(
              icon: AppIcons.school,
              title: 'IELTS',
              tagline: 'Get the band score you need',
              subtitle: 'Listening, Reading, Writing and Speaking, mock tests, '
                  'your study plan and the whole resources library.',
              onTap: () => _open(Routes.home),
              tone: Vivid.brand,
            ),

            if (study)
              _ModeCard(
                icon: AppIcons.flight,
                title: 'Study abroad',
                tagline: 'Your dream campus is closer than you think',
                subtitle: 'Your profile and documents, AI counsellor, course matching, '
                    'scholarships and your applications.',
                onTap: () => _open(Routes.nexted),
                // Both doors are the same card, so neither half reads as the
                // lesser one.
                tone: Vivid.mock,
              ),

            const Spacer(),
            Text(
              study
                  ? 'You can come back here any time with the switch button.'
                  : 'Loading your account…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
            Center(
              child: SoftButton(
                label: 'Log out',
                leading: AppIcons.logout,
                height: 44,
                onTap: _logout,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One door on the start screen: a clean card with a soft icon, the name, a
/// one-line promise and what's inside. Squishes when pressed.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.tagline,
    required this.subtitle,
    required this.onTap,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String tagline;
  final String subtitle;
  final VoidCallback onTap;
  final VividTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: '$title. $tagline',
      child: AppCard(
        radius: 26,
        padding: const EdgeInsets.all(20),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Row(
              spacing: 12,
              children: [
                VividIcon(icon, tone: tone, size: 48, iconSize: 24, radius: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: t.text),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                  child: Icon(AppIcons.forward, size: 18, color: t.onPrimary),
                ),
              ],
            ),
            Text(
              tagline,
              style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: t.text),
            ),
            Text(subtitle, style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}
