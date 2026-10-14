import 'dart:async';

import 'package:flutter/material.dart';

import '../data/packs/content_packs.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/app_icons.dart';
import '../widgets/kit.dart';

/// Covers the app while this device downloads its lessons for the first time
/// (the question banks, guides and courses come from the server as content
/// packs, see [PackStore]). Later opens use the copy kept on the phone, so
/// this screen shows only once per install (or after the content was wiped).
class ContentGate extends StatefulWidget {
  const ContentGate({super.key, required this.child});

  final Widget child;

  @override
  State<ContentGate> createState() => _ContentGateState();
}

class _ContentGateState extends State<ContentGate> {
  bool _covering = false;

  void _kick() {
    final p = PackStore.I;
    if (p.needsDownload && !p.busy && p.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(PackStore.I.refresh(force: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[PackStore.I, Store.I]),
      builder: (context, _) {
        final need = PackStore.I.needsDownload;
        if (need) {
          _covering = true;
          _kick();
        } else if (_covering) {
          // Just finished: screens built underneath meanwhile had no content.
          _covering = false;
          WidgetsBinding.instance.addPostFrameCallback((_) => Store.I.contentReloaded());
        }
        return Stack(
          children: [
            widget.child,
            if (need) const Positioned.fill(child: _DownloadScreen()),
          ],
        );
      },
    );
  }
}

class _DownloadScreen extends StatelessWidget {
  const _DownloadScreen();

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: PackStore.I, builder: _build);

  Widget _build(BuildContext context, Widget? _) {
    final t = context.tk;
    final p = PackStore.I;
    final error = p.error;
    final pct = (p.progress * 100).clamp(0, 100).round();
    return Material(
      color: t.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Center(child: IconCircle(error == null ? AppIcons.download : AppIcons.cloudOff, size: 72)),
              const SizedBox(height: 6),
              Text(
                error == null ? 'Getting your lessons ready' : 'Download paused',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),
              Text(
                error ??
                    'We’re downloading the practice questions, guides and courses to this phone. '
                        'This happens once and takes about a minute.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: t.textSoft),
              ),
              if (error == null) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.busy && p.progress > 0 ? p.progress : null,
                    minHeight: 8,
                    color: t.peach,
                    backgroundColor: t.surfaceAlt2,
                  ),
                ),
                Text(
                  p.progress > 0 ? '$pct%' : 'Starting…',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: t.textMuted),
                ),
              ] else ...[
                const SizedBox(height: 8),
                PrimaryButton(
                  label: p.busy ? 'Trying…' : 'Try again',
                  onTap: p.busy ? null : () => PackStore.I.refresh(force: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
