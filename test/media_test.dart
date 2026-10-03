import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/services/media.dart';

/// Every media file the content points at is either bundled in the app
/// (pubspec assets) or uploaded to R2 (a [Media] folder) — never neither.
void main() {
  test('content media paths are bundled or mapped to R2', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final bundled = RegExp(r'^\s*-\s*(assets/\S+)', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();
    bool isBundled(String p) => bundled.any((b) => b.endsWith('/') ? p.startsWith(b) : p == b);

    final files = <File>[
      File('assets/demo/demo_data.json'),
      ...Directory('assets/content').listSync().whereType<File>().where((f) => f.path.endsWith('.json')),
    ];
    final path = RegExp(r'assets/[A-Za-z0-9_./-]+\.(?:mp3|wav|m4a|png|jpe?g|webp|gif)');
    final missing = <String>{};
    var remote = 0;
    for (final f in files) {
      for (final m in path.allMatches(f.readAsStringSync())) {
        final p = m.group(0)!;
        if (Media.keyOf(p) != null) {
          remote++;
        } else if (!isBundled(p)) {
          missing.add(p);
        }
      }
    }
    expect(missing, isEmpty, reason: 'neither bundled nor in R2: ${missing.take(10)}');
    expect(remote, greaterThan(0));
  });

  test('R2 keys follow the bucket layout', () {
    expect(Media.keyOf('assets/audio/listening/P1-FN.mp3'), 'listening/audio/P1-FN.mp3');
    expect(Media.keyOf('assets/listening/maps/P1-PM_map1.png'), 'listening/maps/P1-PM_map1.png');
    expect(Media.keyOf('assets/writing/tests/wt_01_task1.jpg'), 'writing/task1-images/wt_01_task1.jpg');
    expect(Media.keyOf('assets/diagrams/app/diagram_label_01.webp'), 'reading/images/diagram_label_01.webp');
    expect(Media.keyOf('assets/audio/sound_check.mp3'), isNull);
    // No API configured in tests → bundled behaviour.
    expect(Media.url('assets/audio/listening/P1-FN.mp3'), isNull);
  });
}
