import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/app_icons.dart';
import '../widgets/kit.dart';
import 'api_client.dart';
import 'config.dart';

/// IELTS AI needs the internet (mobile data or Wi-Fi) to work: scores,
/// progress and media all come from the server. While the phone is offline
/// a full-screen notice covers the app (the screen underneath keeps its
/// state, e.g. a test in progress) and goes away by itself once the
/// connection is back.
class Connection extends ChangeNotifier {
  Connection._();
  static final Connection I = Connection._();

  bool _online = true;
  bool get online => _online;

  bool _checking = false;
  bool get checking => _checking;

  Timer? _timer;

  /// Start watching (call once at start-up).
  void init() {
    if (!AppConfig.hasApi) return;
    ApiClient.onNetworkError = () => unawaited(check());
    unawaited(check());
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => unawaited(check()));
  }

  Future<void>? _running;

  /// Checks now. A first failure is re-checked after 3 s before the notice
  /// shows, so one dropped request doesn't flash it.
  Future<void> check() => _running ??= () async {
        _checking = true;
        notifyListeners();
        var ok = await ApiClient.ping();
        if (!ok && _online) {
          await Future<void>.delayed(const Duration(seconds: 3));
          ok = await ApiClient.ping();
        }
        _checking = false;
        if (ok != _online) {
          _online = ok;
          // Offline: look again more often until it's back.
          _timer?.cancel();
          _timer = Timer.periodic(Duration(seconds: ok ? 30 : 5), (_) => unawaited(check()));
        }
        notifyListeners();
      }()
          .whenComplete(() => _running = null);
}

/// Wraps the whole app (MaterialApp.builder).
class ConnectionGate extends StatelessWidget {
  const ConnectionGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Connection.I,
      builder: (context, _) => Stack(
        children: [
          child,
          if (!Connection.I.online) const Positioned.fill(child: _OfflineScreen()),
        ],
      ),
    );
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final checking = Connection.I.checking;
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
              Center(child: IconCircle(AppIcons.wifiOff, size: 72)),
              const SizedBox(height: 6),
              const Text(
                'Turn on mobile data',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),
              Text(
                'IELTS AI needs an internet connection to score your answers and save your progress. '
                'Turn on mobile data or connect to Wi-Fi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: t.textSoft),
              ),
              Text(
                'Your work on this screen is kept. It carries on as soon as you are back online.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: checking ? 'Checking…' : 'Try again',
                onTap: checking ? null : () => Connection.I.check(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
