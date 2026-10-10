import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/data/demo.dart';
import 'app/data/l10n.dart';
import 'app/data/store.dart';
import 'app/services/connection_gate.dart';
import 'app/services/notification_service.dart';
import 'app/services/sync_service.dart';

/// IELTS AI by nextED.
///
/// Content is bundled (`assets/`). Accounts and progress live in a local
/// store on the device (`lib/app/data/store.dart`); built with
/// `--dart-define=API_BASE_URL=…` they belong to server accounts and are
/// synced by [SyncService]. Without it the app runs offline with demo
/// accounts.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Demo.load();
  await Store.I.load();
  SyncService.I.init();
  Connection.I.init();
  unawaited(SyncService.I.syncNow());
  await ContentL10n.init();
  unawaited(NotificationService.I.init());
  runApp(const IeltsAiApp());
}
