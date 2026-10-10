import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../nav.dart';

/// Native share sheet: plain-text summaries (results, reports) and cards
/// shared as a picture (certificates). Falls back to copying the text when
/// sharing isn't available (e.g. some desktop browsers).
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

  /// Shares the widget under [boundaryKey] (a [RepaintBoundary]) as a PNG,
  /// exactly as it looks on screen, on a [background] margin so its rounded
  /// corners don't turn black in apps that convert to JPEG. [caption] goes
  /// with the picture where the target app allows text; if the picture
  /// can't be made, [caption] is shared as text instead.
  static Future<void> shareWidgetImage(
    BuildContext context,
    GlobalKey boundaryKey, {
    required String fileName,
    required String caption,
    String? subject,
    Color background = const Color(0xFFFFFFFF),
    double margin = 24,
  }) async {
    Uint8List? png;
    try {
      png = await _capture(boundaryKey, background: background, margin: margin);
    } catch (e) {
      debugPrint('[share] capture failed: $e');
    }
    if (!context.mounted) return;
    if (png == null) {
      await shareText(context, caption, subject: subject);
      return;
    }
    final name = fileName.endsWith('.png') ? fileName : '$fileName.png';
    try {
      final XFile file;
      if (kIsWeb) {
        file = XFile.fromData(png, name: name, mimeType: 'image/png');
      } else {
        final path = '${(await getTemporaryDirectory()).path}/$name';
        await XFile.fromData(png, mimeType: 'image/png').saveTo(path);
        file = XFile(path, name: name, mimeType: 'image/png');
      }
      final result = await SharePlus.instance.share(
        ShareParams(files: [file], text: caption, subject: subject),
      );
      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        await shareText(context, caption, subject: subject);
      }
    } catch (e) {
      debugPrint('[share] image share failed: $e');
      if (context.mounted) await shareText(context, caption, subject: subject);
    }
  }

  /// Renders the boundary at 3x for a sharp picture.
  static Future<Uint8List?> _capture(GlobalKey key, {required Color background, required double margin}) async {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    const ratio = 3.0;
    final card = await boundary.toImage(pixelRatio: ratio);
    final pad = margin * ratio;
    final w = card.width + pad * 2;
    final h = card.height + pad * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = background);
    canvas.drawImage(card, Offset(pad, pad), Paint()..filterQuality = FilterQuality.high);
    final image = await recorder.endRecording().toImage(w.round(), h.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    card.dispose();
    image.dispose();
    return bytes?.buffer.asUint8List();
  }

  /// Copies [text] and confirms with a toast.
  static Future<void> copy(BuildContext context, String text, {String message = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) context.toast(message);
  }
}
