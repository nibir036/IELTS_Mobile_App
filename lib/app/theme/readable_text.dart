import 'package:flutter/widgets.dart';

/// Makes small text easier to read on phones without blowing up headings:
/// the smaller a font, the more it grows (9-10 → +2, 11-12 → +1.5,
/// 13-14 → +1, 15-17 → +0.5, 18 and up unchanged). The phone's own text
/// size setting still applies on top (capped so layouts hold).
class ReadableTextScaler extends TextScaler {
  const ReadableTextScaler(this.system);

  /// The phone's accessibility text scaling.
  final TextScaler system;

  static double bump(double size) {
    if (size < 11) return size + 2;
    if (size < 13) return size + 1.5;
    if (size < 15) return size + 1;
    if (size < 18) return size + 0.5;
    return size;
  }

  @override
  double scale(double fontSize) => system.scale(bump(fontSize));

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => system.textScaleFactor;

  @override
  bool operator ==(Object other) => other is ReadableTextScaler && other.system == system;

  @override
  int get hashCode => Object.hash(ReadableTextScaler, system);
}

/// Wraps the app (MaterialApp.builder) with [ReadableTextScaler].
Widget readableText(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: ReadableTextScaler(mq.textScaler.clamp(maxScaleFactor: 1.6)),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
