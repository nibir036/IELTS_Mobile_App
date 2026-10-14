import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Content packs kept on the phone: one JSON file per pack in the app's
/// private support folder, plus index.json with each pack's version.
class PackCache {
  Directory? _dir;
  final Map<String, String> versions = <String, String>{};

  /// True in `flutter test`: packs are read from the repo's content files.
  static bool get isTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// A repo file (tests only), e.g. 'assets/content/reading_bank.json'.
  static Future<String?> readRepoFile(String path) async {
    final f = File(path);
    return f.existsSync() ? f.readAsString() : null;
  }

  File _file(String key) => File('${_dir!.path}/$key.json');
  File get _index => File('${_dir!.path}/index.json');

  Future<void> init() async {
    if (_dir != null || isTest) return;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/content_packs');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _dir = dir;
      if (_index.existsSync()) {
        final m = jsonDecode(await _index.readAsString());
        if (m is Map) {
          for (final e in m.entries) {
            // Only packs whose file is really there.
            if (e.value is String && _file('${e.key}').existsSync()) versions['${e.key}'] = e.value as String;
          }
        }
      }
    } catch (_) {
      _dir = null;
      versions.clear();
    }
  }

  Future<String?> read(String key) async {
    if (_dir == null || !versions.containsKey(key)) return null;
    try {
      return await _file(key).readAsString();
    } catch (_) {
      versions.remove(key);
      return null;
    }
  }

  Future<void> write(String key, String version, String text) async {
    if (_dir == null) return;
    // Write beside, then swap in: a crash mid-write never leaves half a pack.
    final tmp = File('${_dir!.path}/$key.json.part');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(_file(key).path);
    versions[key] = version;
    await _index.writeAsString(jsonEncode(versions), flush: true);
  }

  Future<void> clear() async {
    versions.clear();
    try {
      if (_dir != null && _dir!.existsSync()) {
        for (final f in _dir!.listSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {}
  }
}
