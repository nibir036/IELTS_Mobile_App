import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/store.dart';
import 'api_client.dart';
import 'config.dart';
import 'entitlements.dart';

/// Keeps the signed-in account's progress in step with the API server.
///
/// The app still works from its local store (fast, offline); this service
/// copies changes both ways:
/// * **push** - attempts, saved state (kv), study tasks, notifications and
///   profile edits that differ from what was last synced (compared by a hash
///   per item), plus deletions; sent a few seconds after a change, when the
///   app goes to the background and on start.
/// * **pull** - everything the server changed since the last sync
///   (`GET /v1/sync?since=`), e.g. results from another phone or the
///   server-scored writing / speaking attempts.
///
/// What was synced is remembered per account in SharedPreferences, so
/// offline changes are sent the next time the server is reachable.
class SyncService {
  SyncService._();

  static final SyncService I = SyncService._();

  static const _attemptSkills = <String>{'listening', 'reading', 'writing', 'speaking', 'mock', 'vocab'};
  static final _idOk = RegExp(r'^[A-Za-z0-9_\-]{1,80}$');
  static final _keyOk = RegExp(r'^[A-Za-z0-9_.:\-]{1,200}$');
  static final _dayOk = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static const _maxJson = 500 * 1024;

  /// Profile keys the server owns (billing) or that only matter on this device.
  static const _localProfileKeys = <String>{'plan', 'isDemo', 'seedVersion', 'examDaysFromNow'};

  bool get active => AppConfig.hasApi && ApiClient.signedIn && Store.I.current?.id == ApiClient.session?.userId;

  _Snapshot? _snap;
  Timer? _timer;
  bool _busy = false;
  bool _again = false;

  /// Completes when the push that is running now ends (pull waits for it,
  /// so it never reads the server's copy halfway through an upload).
  Completer<void>? _pushDone;

  /// Last sync error (null when the last sync worked).
  String? lastError;
  DateTime? lastSyncedAt;

  /// Wires the store's change hook. Call once at start-up.
  void init() {
    Store.onCommit = schedule;
  }

  /// Push a few seconds after the latest change.
  void schedule() {
    if (!active) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () => unawaited(push()));
  }

  /// Push now (app going to the background).
  Future<void> flush() async {
    if (!active) return;
    _timer?.cancel();
    await push();
  }

  /// Start-up / resume / after log-in: send local changes, then fetch the
  /// server's.
  Future<void> syncNow() async {
    if (!active) return;
    _timer?.cancel();
    await push();
    await pull();
  }

  /// Forget the sync state of [userId] (log-out / account deleted).
  Future<void> forget(String userId) async {
    _timer?.cancel();
    if (_snap?.userId == userId) _snap = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_Snapshot.prefsKey(userId));
    } catch (_) {}
  }

  // ── push ────────────────────────────────────────────────────────────────

  Future<void> push() async {
    if (!active) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    final done = _pushDone = Completer<void>();
    try {
      final snap = await _snapshot();
      final data = Store.I.data;
      final acc = Store.I.current!;

      // Attempts.
      final attempts = <Map<String, dynamic>>[];
      final attemptHash = <String, String>{};
      final localAttemptIds = <String>{};
      for (final a in data.attempts) {
        localAttemptIds.add(a.id);
        if (!_idOk.hasMatch(a.id) || !_attemptSkills.contains(a.skill)) continue;
        final j = a.toJson();
        final h = _hash(j);
        if (snap.attempts[a.id] == h) continue;
        if (jsonEncode(j).length > _maxJson) continue;
        attempts.add(j);
        attemptHash[a.id] = h;
      }
      final removedAttempts = snap.attempts.keys.where((id) => !localAttemptIds.contains(id)).toList();

      // Saved state.
      final state = <String, Object?>{};
      final stateHash = <String, String>{};
      for (final e in data.kv.entries) {
        if (!_keyOk.hasMatch(e.key) || e.value == null) continue;
        final enc = jsonEncode(e.value);
        if (enc.length > _maxJson) continue;
        final h = _hashString(enc);
        if (snap.kv[e.key] == h) continue;
        state[e.key] = e.value;
        stateHash[e.key] = h;
      }
      for (final k in snap.kv.keys) {
        if (!data.kv.containsKey(k) || data.kv[k] == null) state[k] = null;
      }

      // Study tasks.
      final tasks = <Map<String, dynamic>>[];
      final taskHash = <String, String>{};
      final localTaskIds = <String>{};
      for (final t in data.tasks) {
        final id = '${t['id'] ?? ''}';
        localTaskIds.add(id);
        if (!_idOk.hasMatch(id) || '${t['title'] ?? ''}'.isEmpty || !_dayOk.hasMatch('${t['date'] ?? ''}')) continue;
        final h = _hash(t);
        if (snap.tasks[id] == h) continue;
        tasks.add(t);
        taskHash[id] = h;
      }
      final removedTasks = snap.tasks.keys.where((id) => !localTaskIds.contains(id)).toList();

      // Notifications.
      final notes = <Map<String, dynamic>>[];
      final noteHash = <String, String>{};
      final localNoteIds = <String>{};
      for (final n in data.notifications) {
        final id = '${n['id'] ?? ''}';
        localNoteIds.add(id);
        if (!_idOk.hasMatch(id) || '${n['title'] ?? ''}'.isEmpty) continue;
        final h = _hash(n);
        if (snap.notes[id] == h) continue;
        notes.add(_noteOut(n));
        noteHash[id] = h;
      }
      final removedNotes = snap.notes.keys.where((id) => !localNoteIds.contains(id)).toList();

      // Profile.
      final profile = _profileOut(acc);
      final profilePatch = <String, Object?>{};
      for (final e in profile.entries) {
        if (jsonEncode(snap.profile[e.key]) != jsonEncode(e.value)) profilePatch[e.key] = e.value;
      }
      for (final k in snap.profile.keys) {
        if (!profile.containsKey(k)) profilePatch[k] = null;
      }
      final nameChanged = snap.name != acc.name;

      // Send.
      if (attempts.isNotEmpty || state.isNotEmpty || tasks.isNotEmpty || notes.isNotEmpty) {
        for (var i = 0; i < attempts.length || i == 0; i += 100) {
          final chunk = attempts.skip(i).take(100).toList();
          final r = await ApiClient.request('POST', '/v1/sync', body: <String, dynamic>{
            'attempts': chunk,
            if (i == 0) 'state': state,
            if (i == 0) 'tasks': tasks,
            if (i == 0) 'notifications': notes,
          }, timeout: const Duration(seconds: 60));
          final saved = <String>{
            for (final id in (((r['attempts'] as Map?)?['saved'] as List?) ?? const <Object>[])) '$id',
          };
          for (final a in chunk) {
            final id = '${a['id']}';
            if (saved.contains(id)) snap.attempts[id] = attemptHash[id]!;
          }
          if (i == 0) {
            state.forEach((k, v) {
              if (v == null) {
                snap.kv.remove(k);
              } else {
                snap.kv[k] = stateHash[k]!;
              }
            });
            snap.tasks.addAll(taskHash);
            snap.notes.addAll(noteHash);
          }
          if (attempts.isEmpty) break;
        }
      }
      for (final id in removedAttempts) {
        await ApiClient.request('DELETE', '/v1/attempts/$id');
        snap.attempts.remove(id);
      }
      for (final id in removedTasks) {
        await ApiClient.request('DELETE', '/v1/tasks/$id');
        snap.tasks.remove(id);
      }
      for (final id in removedNotes) {
        await ApiClient.request('DELETE', '/v1/notifications/$id');
        snap.notes.remove(id);
      }
      if (profilePatch.isNotEmpty || nameChanged) {
        await ApiClient.request('PATCH', '/v1/me', body: <String, dynamic>{
          if (nameChanged) 'name': acc.name,
          if (profilePatch.isNotEmpty) 'profile': profilePatch,
        });
        snap.profile = profile;
        snap.name = acc.name;
      }
      await snap.save();
      lastError = null;
      lastSyncedAt = DateTime.now();
    } on ApiException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = '$e';
    } finally {
      _busy = false;
      done.complete();
      if (_again) {
        _again = false;
        schedule();
      }
    }
  }

  // ── pull ────────────────────────────────────────────────────────────────

  Future<void> pull() async {
    if (!active) return;
    try {
      final snap = await _snapshot();
      final since = snap.since;
      final r = await ApiClient.get(
        since == null ? '/v1/sync' : '/v1/sync?since=${Uri.encodeQueryComponent(since)}',
      );
      final data = Store.I.data;
      var changed = false;

      for (final raw in (r['attempts'] as List?) ?? const <Object>[]) {
        if (raw is! Map) continue;
        final a = Attempt.fromJson(raw.cast<String, dynamic>());
        // A server-graded attempt the app never adopted (mock sections, a
        // failed or still-running speaking session) has only the server's
        // shape: it counts on the server but isn't shown in the app.
        if (a.data.containsKey('aiGraded') && !a.data.containsKey('source')) continue;
        final i = data.attempts.indexWhere((x) => x.id == a.id);
        if (i >= 0) {
          data.attempts[i] = a;
        } else {
          data.attempts.add(a);
        }
        snap.attempts[a.id] = _hash(a.toJson());
        changed = true;
      }
      data.attempts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final raw in (r['notifications'] as List?) ?? const <Object>[]) {
        if (raw is! Map) continue;
        final n = _noteIn(raw.cast<String, dynamic>());
        final i = data.notifications.indexWhere((x) => x['id'] == n['id']);
        if (i >= 0) {
          data.notifications[i] = n;
        } else {
          data.notifications.add(n);
        }
        snap.notes['${n['id']}'] = _hash(n);
        changed = true;
      }
      data.notifications.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));

      for (final raw in (r['tasks'] as List?) ?? const <Object>[]) {
        if (raw is! Map) continue;
        final t = Map<String, dynamic>.from(raw);
        if ('${t['kind'] ?? ''}'.isEmpty) t.remove('kind');
        // The study plan dropped this task (rolled over, paused, replaced).
        if (t['removed'] == true) {
          data.tasks.removeWhere((x) => x['id'] == t['id']);
          snap.tasks.remove('${t['id']}');
          changed = true;
          continue;
        }
        final i = data.tasks.indexWhere((x) => x['id'] == t['id']);
        if (i >= 0) {
          data.tasks[i] = t;
        } else {
          data.tasks.add(t);
        }
        snap.tasks['${t['id']}'] = _hash(t);
        changed = true;
      }

      final state = r['state'];
      if (state is Map) {
        state.forEach((k, v) {
          data.kv['$k'] = v;
          snap.kv['$k'] = _hashString(jsonEncode(v));
          changed = true;
        });
      }

      // Profile + plan. Wait for an upload in progress first, and keep
      // profile edits made on this phone that haven't reached the server yet
      // (e.g. a new photo picked while the app was coming back to the front):
      // the server's copy would otherwise overwrite them and they would never
      // be sent.
      while (_busy) {
        await (_pushDone?.future ?? Future<void>.value());
      }
      final me = await ApiClient.get('/v1/me');
      Entitlements.I.apply(me['usage']);
      final user = me['user'];
      if (user is Map) {
        final before = Store.I.current;
        final pending = <String, Object?>{};
        String? pendingName;
        if (before != null) {
          final out = _profileOut(before);
          out.forEach((k, v) {
            if (jsonEncode(snap.profile[k]) != jsonEncode(v)) pending[k] = v;
          });
          for (final k in snap.profile.keys) {
            if (!out.containsKey(k)) pending[k] = null;
          }
          if (snap.name != null && snap.name != before.name) pendingName = before.name;
        }
        Store.I.applyRemoteUser(user.cast<String, dynamic>());
        final acc = Store.I.current;
        if (acc != null) {
          snap.profile = _profileOut(acc);
          snap.name = acc.name;
          if (pending.isNotEmpty || pendingName != null) {
            // Put the local edits back and send them on the next push.
            Store.I.updateProfile(pending, name: pendingName);
          }
        }
      }

      snap.since = '${r['serverTime'] ?? ''}'.isEmpty ? null : '${r['serverTime']}';
      await snap.save();
      if (changed) Store.I.applyRemoteChanges();
      lastError = null;
      lastSyncedAt = DateTime.now();
    } on ApiException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = '$e';
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  Future<_Snapshot> _snapshot() async {
    final id = Store.I.current!.id;
    if (_snap?.userId == id) return _snap!;
    return _snap = await _Snapshot.load(id);
  }

  Map<String, dynamic> _profileOut(Account acc) => <String, dynamic>{
        for (final e in acc.profile.entries)
          if (!_localProfileKeys.contains(e.key) && e.value != null) e.key: e.value,
      };

  /// Local notification → server shape (attemptId travels in args).
  static Map<String, dynamic> _noteOut(Map<String, dynamic> n) {
    final args = <String, dynamic>{
      if (n['args'] is Map) ...(n['args'] as Map).cast<String, dynamic>(),
      if (n['attemptId'] != null) 'attemptId': n['attemptId'],
    };
    return <String, dynamic>{
      'id': n['id'],
      'type': n['type'] ?? 'system',
      'skill': n['skill'] ?? '',
      'title': n['title'],
      'body': n['body'] ?? '',
      'read': n['read'] == true,
      'target': n['target'] ?? '',
      if (args.isNotEmpty) 'args': args,
      'createdAt': n['createdAt'],
    };
  }

  static Map<String, dynamic> _noteIn(Map<String, dynamic> n) {
    final out = <String, dynamic>{...n};
    final args = n['args'];
    if (args is Map && args['attemptId'] != null) {
      out['attemptId'] = args['attemptId'];
      final rest = Map<String, dynamic>.from(args)..remove('attemptId');
      if (rest.isEmpty) {
        out.remove('args');
      } else {
        out['args'] = rest;
      }
    }
    for (final k in <String>['skill', 'target', 'body']) {
      if ('${out[k] ?? ''}'.isEmpty) out.remove(k);
    }
    return out;
  }

  static String _hash(Object? v) => _hashString(jsonEncode(v));

  /// FNV-1a (64-bit split in two 32-bit halves) - stable across app runs,
  /// unlike String.hashCode.
  static String _hashString(String s) {
    var h1 = 0x811c9dc5, h2 = 0x050c5d1f;
    for (final c in s.codeUnits) {
      h1 = ((h1 ^ c) * 0x01000193) & 0xffffffff;
      h2 = ((h2 ^ (c + 7)) * 0x01000193) & 0xffffffff;
    }
    return '${h1.toRadixString(36)}${h2.toRadixString(36)}${s.length.toRadixString(36)}';
  }
}

/// What was last synced for one account (item hashes + pull cursor).
class _Snapshot {
  _Snapshot(this.userId);

  final String userId;
  String? since;
  String? name;
  Map<String, String> attempts = <String, String>{};
  Map<String, String> kv = <String, String>{};
  Map<String, String> tasks = <String, String>{};
  Map<String, String> notes = <String, String>{};
  Map<String, dynamic> profile = <String, dynamic>{};

  static String prefsKey(String userId) => 'ielts_ai_sync_v1_$userId';

  static Map<String, String> _strMap(Object? v) =>
      v is Map ? <String, String>{for (final e in v.entries) '${e.key}': '${e.value}'} : <String, String>{};

  static Future<_Snapshot> load(String userId) async {
    final s = _Snapshot(userId);
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(prefsKey(userId));
      if (raw != null) {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        s.since = j['since'] is String ? j['since'] as String : null;
        s.name = j['name'] is String ? j['name'] as String : null;
        s.attempts = _strMap(j['attempts']);
        s.kv = _strMap(j['kv']);
        s.tasks = _strMap(j['tasks']);
        s.notes = _strMap(j['notes']);
        s.profile = j['profile'] is Map ? (j['profile'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      }
    } catch (_) {}
    return s;
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        prefsKey(userId),
        jsonEncode(<String, dynamic>{
          'since': since,
          'name': name,
          'attempts': attempts,
          'kv': kv,
          'tasks': tasks,
          'notes': notes,
          'profile': profile,
        }),
      );
    } catch (_) {}
  }
}
