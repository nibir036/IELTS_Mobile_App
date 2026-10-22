import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/kit.dart';

/// Direct Apply (25.4).
///
/// Writes an application into the shared backend and leaves it there: NextED
/// staff are notified on the desktop web app and work it manually, and every
/// status change they make comes back to the student's phone. The app never
/// moves a status itself.
///
/// Returns true when the application was created.
Future<bool> nextedApply(
  BuildContext context, {
  required String type, // 'course' | 'scholarship' | 'university'
  required String refId,
  required String title,
  String provider = '',
}) async {
  if (!NextedApi.ready) {
    context.toast('Connect the study-abroad server to apply.');
    return false;
  }

  final ok = await showAppDialog<bool>(
    context,
    Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          const Text(
            'Send this application?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text(
            provider.isEmpty ? title : '$title\n$provider',
            style: TextStyle(fontSize: 14, height: 1.45, color: ctx.tk.textSoft),
          ),
          Text(
            'Your NextED counsellor picks it up and works it for you. You’ll see '
            'every step here, and we’ll ask if anything else is needed.',
            style: TextStyle(fontSize: 13, height: 1.45, color: ctx.tk.textMuted),
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
                  label: 'Apply',
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
  if (ok != true || !context.mounted) return false;

  try {
    final r = await NextedApi.post(NextedConfig.applications, <String, dynamic>{
      'type': type,
      'refId': refId,
      'title': title,
      'provider': provider,
    });
    if (!context.mounted) return true;
    final app = r.m('application').isEmpty ? r : r.m('application');
    final reference = app.s('reference').isEmpty ? app.s('id') : app.s('reference');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(reference.isEmpty ? 'Application sent' : 'Application sent · $reference'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push(Routes.nextedApplications),
          ),
        ),
      );
    return true;
  } on ApiException catch (e) {
    if (context.mounted) context.toast(e.message);
    return false;
  }
}
