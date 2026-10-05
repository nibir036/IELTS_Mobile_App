import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// A8 · Microphone Permission.
class MicPermissionScreen extends StatelessWidget {
  const MicPermissionScreen({super.key});

  static IconData _icon(String key) {
    switch (key) {
      case 'mic':
        return AppIcons.speaking;
      case 'sparkle':
        return AppIcons.sparkle;
      case 'lock':
        return AppIcons.lock;
      default:
        return AppIcons.info;
    }
  }

  /// Home, or the screen passed as `args['next']` (A7 → the diagnostic).
  static void _finish(BuildContext context, bool allowed) {
    final next = context.routeArgs['next'];
    Store.I.updateProfile(<String, dynamic>{
      'micAllowed': allowed,
      'onboarded': true,
    });
    context.resetTo(next is String && next.isNotEmpty ? next : Routes.home);
  }

  static Future<void> _allow(BuildContext context) async {
    final granted = await VoiceRecorder.requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      context.toast('Microphone blocked - you can enable it later in Settings');
    }
    _finish(context, granted);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final data = Demo.section('access').m('micPermission');
    final benefits = data.l('benefits');

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          PrimaryButton(
            label: 'Allow microphone',
            radius: 999,
            onTap: () => _allow(context),
          ),
          SizedBox(
            height: 48,
            child: Material(
              color: Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _finish(context, false),
                child: Center(
                  child: Text(
                    'Not now',
                    style: TextStyle(fontSize: 15, color: t.textMuted),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Blocked it before? Open ',
                children: [
                  TextSpan(
                    text: data.s('settingsPath'),
                    style: TextStyle(fontWeight: FontWeight.w500, color: t.text),
                  ),
                  const TextSpan(text: ' and switch it on.'),
                ],
              ),
              style: TextStyle(fontSize: 12, height: 1.45, color: t.textMuted),
            ),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              size: 56,
              radius: 20,
              iconSize: 22,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Text(
                'Speaking setup',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.border),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: 24,
                    top: 24,
                    right: 24,
                    bottom: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.isNight
                              ? const Color(0xFF3A3A3A)
                              : const Color(0xFFF0E2DD),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: 50,
                    top: 50,
                    right: 50,
                    bottom: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: kPeachGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(AppIcons.speaking, size: 40, color: kOnPeach),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            const Text(
              'Allow microphone\naccess',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w300,
                height: 1.1,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              'Speaking practice needs your mic.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              for (final b in benefits)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.raised,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon(b.s('icon')), size: 18, color: t.text),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          Text(b.s('title'), style: const TextStyle(fontSize: 15)),
                          Text(
                            b.s('body'),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: t.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
