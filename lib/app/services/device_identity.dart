import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This install's device id: a random id made once and kept on the device
/// (not a hardware id). The server allows an account on at most 2 devices
/// and one signed-in screen at a time (server/src/lib/devices.ts).
class DeviceIdentity {
  DeviceIdentity._();

  static const String _key = 'ielts_ai_device_id_v1';
  static String _id = '';

  static String get id => _id;

  /// "Android phone (3fa9)" (the short code tells two phones apart).
  /// Plain ASCII only: Android's HTTP client refuses any other character in
  /// a header value (a "·" here made every request fail as "can't reach").
  static String get name => '$platformLabel (${_id.length >= 4 ? _id.substring(0, 4) : _id})';

  static String _ascii(String v) => v.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

  static String get platform {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  static String get platformLabel => switch (platform) {
        'Web' => 'Web browser',
        'Android' => 'Android phone',
        'iOS' => 'iPhone',
        'Windows' => 'Windows PC',
        'macOS' => 'Mac',
        _ => '$platform device',
      };

  /// Headers sent with every API call.
  static Map<String, String> get headers => <String, String>{
        if (_id.isNotEmpty) 'X-Device-Id': _ascii(_id),
        if (_id.isNotEmpty) 'X-Device-Name': _ascii(name),
        'X-Device-Platform': _ascii(platform),
      };

  static Future<void> init() async {
    if (_id.isNotEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_key);
      if (saved != null && saved.length >= 16) {
        _id = saved;
        return;
      }
      _id = _newId();
      await p.setString(_key, _id);
    } catch (_) {
      _id = _id.isEmpty ? _newId() : _id;
    }
  }

  static String _newId() {
    final r = Random.secure();
    return List<String>.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
