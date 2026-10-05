import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../nav.dart';

/// Native share sheet for plain-text summaries (results, reports,
/// certificates). Falls back to copying the text when sharing isn't
/// available (e.g. some desktop browsers).
class ShareService {
  ShareService._();

  static Future<void> shareText(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    var copied = false;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      if (result.status == ShareResultStatus.unavailable) {
        await Clipboard.setData(ClipboardData(text: text));
        copied = true;
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      copied = true;
    }
    if (copied && context.mounted) {
      context.toast('Copied to clipboard - paste it anywhere to share');
    }
  }

  /// Copies [text] and confirms with a toast.
  static Future<void> copy(BuildContext context, String text, {String message = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) context.toast(message);
  }
}
