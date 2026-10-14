/// Content packs on the web: kept in memory for this tab only. Each pack is
/// fetched with its version in the URL, which the server marks as cacheable
/// for good, so the browser's own cache answers repeat loads instantly.
class PackCache {
  final Map<String, String> versions = <String, String>{};
  final Map<String, String> _text = <String, String>{};

  static bool get isTest => false;

  static Future<String?> readRepoFile(String path) async => null;

  Future<void> init() async {}

  Future<String?> read(String key) async => _text[key];

  Future<void> write(String key, String version, String text) async {
    _text[key] = text;
    versions[key] = version;
  }

  Future<void> clear() async {
    versions.clear();
    _text.clear();
  }
}
