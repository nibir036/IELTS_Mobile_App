import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/app_icons.dart';
import 'api_client.dart';
import 'config.dart';

/// Watches whether the server can be reached.
///
/// The app needs the server for the things only it can do - scoring an
/// answer, saving progress, the study-abroad file. It does **not** need it to
/// open: the question banks, guides and lessons are kept on the phone once
/// they have been downloaded, so a student on a train with no signal can
/// still read, practise and plan.
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
///
/// Being offline shows a slim bar at the top, not a screen over everything.
/// A full-screen block was the wrong trade: it hid an app that still works -
/// the content is already on the phone - and it turned a server that happened
/// to be down into an app that looked broken. The bar says what is and isn't
/// available and gets out of the way; the few actions that really need the
/// server say so themselves when they are used.
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
          if (!Connection.I.online)
            const Positioned(left: 0, right: 0, top: 0, child: _OfflineBar()),
        ],
      ),
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final checking = Connection.I.checking;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Material(
          color: t.isNight ? t.surface : t.raised,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: checking ? null : () => Connection.I.check(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.wifiOff, size: 15, color: t.textMuted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      checking
                          ? 'Reconnecting…'
                          : 'Offline - saved lessons work, scoring and new answers don’t',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: t.textSoft),
                    ),
                  ),
                  if (!checking) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.text),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
