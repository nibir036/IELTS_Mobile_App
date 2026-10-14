import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/data/demo.dart';
import 'app/data/l10n.dart';
import 'app/data/packs/content_packs.dart';
import 'app/data/store.dart';
import 'app/services/billing_service.dart';
import 'app/services/connection_gate.dart';
import 'app/services/device_identity.dart';
import 'app/services/notification_service.dart';
import 'app/services/sync_service.dart';

/// IELTS AI by nextED.
///
/// Content (question banks, guides, courses, translations, UI text) comes
/// from the server's database as content packs kept on the device
/// ([PackStore]); only the UI text is also bundled. Accounts and progress
/// live in a local store on the device (`lib/app/data/store.dart`); built
/// with `--dart-define=API_BASE_URL=…` they belong to server accounts and
/// are synced by [SyncService]. Without it the app runs offline with demo
/// accounts and no question banks.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Demo.load();
  // Before the store: API calls carry this install's device id.
  await DeviceIdentity.init();
  await Store.I.load();
  SyncService.I.init();
  // Google Play purchases (also ones that finished while the app was closed).
  BillingService.I.init();
  Connection.I.init();
  unawaited(SyncService.I.syncNow());
  // Newer content packs; the first download after signing in is shown by ContentGate.
  unawaited(PackStore.I.refresh());
  await ContentL10n.init();
  unawaited(NotificationService.I.init());
  runApp(const IeltsAiApp());
}
