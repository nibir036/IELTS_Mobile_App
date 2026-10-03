import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../data/store.dart';
import 'kit.dart';

/// The signed-in student's avatar: their photo (`profile.photo`, base64
/// JPEG saved by the edit-avatar sheet) or their initials. Rebuilds with the
/// store because callers read `context.store`.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 48});

  final double size;

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Decoded photo bytes of the current account, or null.
  static Uint8List? photoBytes() {
    final raw = Store.I.current?.profile['photo'];
    if (raw is! String || raw.isEmpty) return null;
    final hit = _cache[raw];
    if (hit != null) return hit;
    try {
      final bytes = base64Decode(raw);
      _cache
        ..clear()
        ..[raw] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = Store.I.current;
    final bytes = photoBytes();
    return Avatar(
      acc?.initials ?? '?',
      size: size,
      image: bytes == null ? null : MemoryImage(bytes),
    );
  }
}
