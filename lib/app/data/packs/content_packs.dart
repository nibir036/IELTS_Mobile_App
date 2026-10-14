import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/api_client.dart';
import '../../services/config.dart';
import 'pack_cache_io.dart' if (dart.library.js_interop) 'pack_cache_web.dart';

/// The app's content comes from the server's database as "content packs"
/// (server/src/lib/packs.ts): question banks, guides, courses, translations
/// and the UI text. Keep these keys in step with the server's list.
class Packs {
  Packs._();

  /// UI text and demo content (assets/demo/demo_data.json). The only pack
  /// also bundled in the app, so the login screens work before any download.
  static const String ui = 'ui';
  static const String l10nIndex = 'l10n.index';

  static const List<String> banks = <String>['reading', 'listening', 'writing', 'speaking', 'resources', 'tests', 'sentence'];
  static const List<String> guides = <String>['reading', 'writing', 'speaking', 'grammar', 'listening', 'vocab'];
  static const List<String> courses = <String>['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab'];

  static String bank(String name) => 'bank.$name';
  static String guide(String module) => 'guide.$module';
  static String course(String module) => 'course.$module';
  static String l10n(String lang, String module) => 'l10n.$lang.$module';

  /// What every signed-in student needs before the app opens (translations
  /// are fetched when a language is picked).
  static final List<String> core = <String>[
    for (final b in banks) bank(b),
    for (final g in guides) guide(g),
    for (final c in courses) course(c),
  ];

  static const String bundledUi = 'assets/demo/demo_data.json';

  /// The repo file a pack is made from (the server's source; read directly
  /// by `flutter test`).
  static String fileOf(String key) {
    if (key == ui) return bundledUi;
    if (key == l10nIndex) return 'assets/content/l10n/index.json';
    final p = key.split('.');
    if (p.length == 2 && p[0] == 'bank') return 'assets/content/${p[1]}_bank.json';
    if (p.length == 2 && p[0] == 'guide') return 'assets/content/${p[1]}_guide.json';
    if (p.length == 2 && p[0] == 'course') return 'assets/content/lessons/${p[1]}.json';
    if (p.length == 3 && p[0] == 'l10n') return 'assets/content/l10n/${p[1]}/${p[2]}.json';
    return '';
  }
}

/// One entry of the server's pack list.
class PackInfo {
  const PackInfo(this.key, this.version, this.gzBytes, this.public);

  final String key;
  final String version;
  final int gzBytes;
  final bool public;

  static PackInfo? fromJson(Object? j) {
    if (j is! Map) return null;
    final key = j['key'], version = j['version'];
    if (key is! String || version is! String) return null;
    final gz = j['gzBytes'];
    return PackInfo(key, version, gz is num ? gz.toInt() : 0, j['public'] == true);
  }
}

/// Downloads content packs, keeps them on the device and hands their JSON to
/// [Demo] / [ContentL10n]. A pack is downloaded again only when the server's
/// version differs from the one kept here.
///
/// * First open after signing in: [ContentGate] covers the app with a
///   progress screen until the core packs are here.
/// * Later opens: the kept packs load at once; [refresh] checks for newer
///   versions in the background and swaps them in ([onPacksChanged]).
class PackStore extends ChangeNotifier {
  PackStore._();

  static final PackStore I = PackStore._();

  final PackCache _cache = PackCache();

  final List<Future<void> Function(Set<String> keys)> _handlers = <Future<void> Function(Set<String> keys)>[];

  /// [handler] reloads changed packs into memory ([Demo], [ContentL10n]).
  void onPacksChanged(Future<void> Function(Set<String> keys) handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  Future<void> init() => _cache.init();

  /// True when [key] can be read without a download.
  bool has(String key) => PackCache.isTest || _cache.versions.containsKey(key);

  bool get coreReady => Packs.core.every(has);

  /// Signed in to the server but the content isn't on this device yet.
  bool get needsDownload => AppConfig.hasApi && ApiClient.signedIn && !coreReady;

  /// A pack's JSON text, or null when it isn't here (yet).
  Future<String?> read(String key) async {
    if (PackCache.isTest) return PackCache.readRepoFile(Packs.fileOf(key));
    final text = await _cache.read(key);
    if (text != null) return text;
    if (key == Packs.ui) {
      try {
        return await rootBundle.loadString(Packs.bundledUi);
      } catch (_) {}
    }
    return null;
  }

  // ── downloading ──────────────────────────────────────────────────────────

  bool _busy = false;
  bool get busy => _busy;

  /// 0..1 while downloading.
  double _progress = 0;
  double get progress => _progress;

  /// The last download problem (null when the last check worked).
  String? _error;
  String? get error => _error;

  List<PackInfo>? _manifest;
  DateTime? _checkedAt;
  bool _checkedSignedIn = false;
  Future<void>? _running;

  static const Duration _recheckAfter = Duration(minutes: 10);

  /// Brings the kept packs up to date with the server (public packs when
  /// signed out; everything this student uses when signed in). Cheap when
  /// nothing changed: one small list request.
  Future<void> refresh({bool force = false}) {
    if (!AppConfig.hasApi || PackCache.isTest) return Future<void>.value();
    final signedIn = ApiClient.signedIn;
    final recent = _checkedAt != null &&
        DateTime.now().difference(_checkedAt!) < _recheckAfter &&
        _checkedSignedIn == signedIn &&
        (!signedIn || coreReady);
    if (!force && recent && _error == null) return Future<void>.value();
    return _running ??= _refresh(signedIn).whenComplete(() => _running = null);
  }

  Future<List<PackInfo>> _fetchManifest() async {
    final r = await ApiClient.get('/v1/content/packs', auth: false);
    final list = r['packs'];
    final packs = <PackInfo>[
      if (list is List)
        for (final j in list)
          if (PackInfo.fromJson(j) case final p?) p,
    ];
    _manifest = packs;
    return packs;
  }

  Future<void> _refresh(bool signedIn) async {
    _busy = true;
    _error = null;
    _progress = 0;
    notifyListeners();
    final changed = <String>{};
    try {
      final manifest = await _fetchManifest();
      final wanted = manifest.where((p) {
        if (p.public) return true;
        if (!signedIn) return false;
        // Core packs, plus translations already kept here (kept current).
        return Packs.core.contains(p.key) || _cache.versions.containsKey(p.key);
      });
      final stale = wanted.where((p) => _cache.versions[p.key] != p.version).toList();
      final total = stale.fold<int>(0, (a, p) => a + (p.gzBytes > 0 ? p.gzBytes : 1));
      var done = 0;
      for (final p in stale) {
        await _download(p);
        changed.add(p.key);
        done += p.gzBytes > 0 ? p.gzBytes : 1;
        _progress = total == 0 ? 1 : done / total;
        notifyListeners();
      }
      _checkedAt = DateTime.now();
      _checkedSignedIn = signedIn;
    } on ApiException catch (e) {
      _error = e.isNetwork ? 'Can’t reach the server. Check your connection.' : e.message;
    } catch (_) {
      _error = 'The lessons couldn’t be downloaded. Please try again.';
    } finally {
      if (changed.isNotEmpty) {
        for (final h in List.of(_handlers)) {
          try {
            await h(changed);
          } catch (_) {}
        }
      }
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _download(PackInfo p) async {
    final text = await ApiClient.getText('/v1/content/packs/${p.key}?v=${p.version}', auth: !p.public);
    final t = text.trimLeft();
    if (!t.startsWith('{') && !t.startsWith('[')) throw StateError('pack ${p.key} is not JSON');
    await _cache.write(p.key, p.version, text);
  }

  /// Makes sure [key] is here (a translation picked in Settings), fetching it
  /// when needed. False when it can't be had (offline, signed out, no such pack).
  Future<bool> ensure(String key) async {
    if (has(key)) return true;
    if (!AppConfig.hasApi || PackCache.isTest) return false;
    // Let a running refresh finish first (it may be fetching this very pack).
    final running = _running;
    if (running != null) {
      await running;
      if (has(key)) return true;
    }
    try {
      final manifest = _manifest ?? await _fetchManifest();
      final p = manifest.where((x) => x.key == key).firstOrNull;
      if (p == null || (!p.public && !ApiClient.signedIn)) return false;
      await _download(p);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the kept packs (Settings → reset, or a broken download).
  Future<void> clear() async {
    await _cache.clear();
    _checkedAt = null;
    notifyListeners();
  }
}
