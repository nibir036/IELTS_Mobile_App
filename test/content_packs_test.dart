import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/data/packs/content_packs.dart';

/// The app's pack keys match the content files the server turns into packs
/// (server/src/lib/packs.ts), and none of those files is bundled any more.
void main() {
  test('every core pack has its source file', () {
    for (final key in <String>[Packs.ui, Packs.l10nIndex, ...Packs.core]) {
      final file = Packs.fileOf(key);
      expect(file, isNotEmpty, reason: key);
      expect(File(file).existsSync(), isTrue, reason: '$key → $file');
    }
  });

  test('every translation in the index has its pack file', () {
    final index = (jsonDecode(File(Packs.fileOf(Packs.l10nIndex)).readAsStringSync()) as Map).cast<String, dynamic>();
    for (final e in index.entries) {
      for (final lang in e.value as List) {
        final file = Packs.fileOf(Packs.l10n('$lang', e.key));
        expect(File(file).existsSync(), isTrue, reason: file);
      }
    }
  });

  test('the server lists the same banks, guides and courses', () {
    final ts = File('server/src/lib/packs.ts').readAsStringSync();
    List<String> listOf(String name) {
      final m = RegExp('export const $name = \\[([^\\]]*)\\]').firstMatch(ts);
      expect(m, isNotNull, reason: name);
      return RegExp(r"'([a-z]+)'").allMatches(m!.group(1)!).map((x) => x.group(1)!).toList();
    }

    expect(listOf('BANKS'), Packs.banks);
    expect(listOf('GUIDES'), Packs.guides);
    expect(listOf('COURSES'), Packs.courses);
  });

  test('only the UI text is bundled; the rest comes from the server', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/demo/demo_data.json'));
    expect(RegExp(r'^\s*-\s*assets/content', multiLine: true).hasMatch(pubspec), isFalse);
  });

  test('a pack reads from the repo file in tests', () async {
    final raw = await PackStore.I.read(Packs.bank('tests'));
    expect(raw, isNotNull);
    expect((jsonDecode(raw!) as Map).containsKey('listening'), isTrue);
  });
}
