import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('LocalFsPlugin', () {
    late Directory tempDir;
    late LocalFsPlugin plugin;
    late Map<String, HostFunction> byName;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('local_fs_test_');
      plugin = LocalFsPlugin(rootPath: tempDir.path);
      byName = {for (final f in plugin.functions) f.schema.name: f};
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('namespace is fs', () {
      expect(plugin.namespace, 'fs');
    });

    test('provides 8 functions', () {
      expect(plugin.functions, hasLength(8));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll([
          'fs_cat',
          'fs_ls',
          'fs_write',
          'fs_mkdir',
          'fs_rm',
          'fs_stat',
          'fs_exists',
          'fs_find',
        ]),
      );
    });

    test('pythonPrelude defines Linux-style wrapper functions', () {
      final prelude = plugin.pythonPrelude;
      expect(prelude, contains('def cat('));
      expect(prelude, contains('def ls('));
      expect(prelude, contains('def write('));
      expect(prelude, contains('def mkdir('));
      expect(prelude, contains('def rm('));
      expect(prelude, contains('def stat('));
      expect(prelude, contains('def exists('));
      expect(prelude, contains('def find('));
    });

    test('systemPromptContext is non-null', () {
      expect(plugin.systemPromptContext, isNotNull);
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('fs_cat'));
      expect(names, contains('fs_write'));
      expect(names, contains('fs_mkdir'));
      expect(names, contains('fs_find'));
    });

    group('fs_cat', () {
      test('reads file contents', () async {
        File(p.join(tempDir.path, 'hello.txt')).writeAsStringSync('world');

        final result = await byName['fs_cat']!.handler({'path': 'hello.txt'});

        expect(result, 'world');
      });

      test('throws for non-existent file', () async {
        expect(
          () => byName['fs_cat']!.handler({'path': 'missing.txt'}),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws for non-string path', () async {
        expect(
          () => byName['fs_cat']!.handler({'path': 123}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fs_ls', () {
      test('lists directory entries with type', () async {
        File(p.join(tempDir.path, 'a.txt')).writeAsStringSync('');
        Directory(p.join(tempDir.path, 'sub')).createSync();

        final result = await byName['fs_ls']!.handler({'path': '.'});

        expect(result, isA<List<Map<String, Object?>>>());
        final entries = result! as List<Map<String, Object?>>;
        final names = entries.map((e) => e['name']).toSet();
        expect(names, containsAll(['a.txt', 'sub']));

        final subEntry = entries.firstWhere((e) => e['name'] == 'sub');
        expect(subEntry['type'], 'directory');
        final fileEntry = entries.firstWhere((e) => e['name'] == 'a.txt');
        expect(fileEntry['type'], 'file');
      });

      test('recurse lists nested entries', () async {
        Directory(p.join(tempDir.path, 'sub')).createSync();
        File(p.join(tempDir.path, 'sub', 'deep.txt')).writeAsStringSync('');

        final result = await byName['fs_ls']!.handler({
          'path': '.',
          'recursive': true,
        });

        final entries = result! as List<Map<String, Object?>>;
        final names = entries.map((e) => e['name']).toSet();
        expect(names, contains(p.join('sub', 'deep.txt')));
      });

      test('throws for non-existent directory', () async {
        expect(
          () => byName['fs_ls']!.handler({'path': 'nope'}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fs_write', () {
      test('writes file contents', () async {
        await byName['fs_write']!.handler({
          'path': 'output.txt',
          'content': 'hello',
        });

        final file = File(p.join(tempDir.path, 'output.txt'));
        expect(file.readAsStringSync(), 'hello');
      });

      test('overwrites existing file', () async {
        File(p.join(tempDir.path, 'over.txt')).writeAsStringSync('old');

        await byName['fs_write']!.handler({
          'path': 'over.txt',
          'content': 'new',
        });

        expect(
          File(p.join(tempDir.path, 'over.txt')).readAsStringSync(),
          'new',
        );
      });

      test('throws for non-string content', () async {
        expect(
          () => byName['fs_write']!.handler({
            'path': 'x.txt',
            'content': 42,
          }),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fs_mkdir', () {
      test('creates directory', () async {
        await byName['fs_mkdir']!.handler({'path': 'newdir'});

        expect(
          Directory(p.join(tempDir.path, 'newdir')).existsSync(),
          isTrue,
        );
      });

      test('creates nested directories recursively', () async {
        await byName['fs_mkdir']!.handler({'path': 'a/b/c'});

        expect(
          Directory(p.join(tempDir.path, 'a', 'b', 'c')).existsSync(),
          isTrue,
        );
      });

      test('is idempotent on existing directory', () async {
        Directory(p.join(tempDir.path, 'existing')).createSync();

        await byName['fs_mkdir']!.handler({'path': 'existing'});

        expect(
          Directory(p.join(tempDir.path, 'existing')).existsSync(),
          isTrue,
        );
      });
    });

    group('fs_rm', () {
      test('deletes existing file', () async {
        final file = File(p.join(tempDir.path, 'doomed.txt'))
          ..writeAsStringSync('bye');

        await byName['fs_rm']!.handler({'path': 'doomed.txt'});

        expect(file.existsSync(), isFalse);
      });

      test('deletes empty directory', () async {
        Directory(p.join(tempDir.path, 'emptydir')).createSync();

        await byName['fs_rm']!.handler({'path': 'emptydir'});

        expect(
          Directory(p.join(tempDir.path, 'emptydir')).existsSync(),
          isFalse,
        );
      });

      test('throws for non-existent path', () async {
        expect(
          () => byName['fs_rm']!.handler({'path': 'ghost.txt'}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fs_stat', () {
      test('returns metadata for file', () async {
        File(p.join(tempDir.path, 'info.txt')).writeAsStringSync('data');

        final result = await byName['fs_stat']!.handler({'path': 'info.txt'});

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['size'], greaterThan(0));
        expect(map['modified'], isA<String>());
        expect(map['is_directory'], isFalse);
      });

      test('returns is_directory true for directory', () async {
        Directory(p.join(tempDir.path, 'dir')).createSync();

        final result = await byName['fs_stat']!.handler({'path': 'dir'});

        final map = result! as Map<String, Object?>;
        expect(map['is_directory'], isTrue);
      });

      test('throws for non-existent path', () async {
        expect(
          () => byName['fs_stat']!.handler({'path': 'nope'}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fs_exists', () {
      test('returns true for existing file', () async {
        File(p.join(tempDir.path, 'present.txt')).writeAsStringSync('');

        final result = await byName['fs_exists']!.handler({
          'path': 'present.txt',
        });

        expect(result, isTrue);
      });

      test('returns false for missing file', () async {
        final result = await byName['fs_exists']!.handler({
          'path': 'absent.txt',
        });

        expect(result, isFalse);
      });

      test('returns true for existing directory', () async {
        Directory(p.join(tempDir.path, 'sub')).createSync();

        final result = await byName['fs_exists']!.handler({'path': 'sub'});

        expect(result, isTrue);
      });
    });

    group('fs_find', () {
      test('finds files matching glob pattern', () async {
        File(p.join(tempDir.path, 'a.txt')).writeAsStringSync('');
        File(p.join(tempDir.path, 'b.dart')).writeAsStringSync('');
        Directory(p.join(tempDir.path, 'sub')).createSync();
        File(p.join(tempDir.path, 'sub', 'c.txt')).writeAsStringSync('');

        final result = await byName['fs_find']!.handler({
          'path': '.',
          'pattern': '*.txt',
        });

        expect(result, isA<List<String>>());
        final paths = result! as List<String>;
        expect(paths, contains('a.txt'));
        expect(paths, isNot(contains('b.dart')));
      });

      test('** pattern matches recursively', () async {
        Directory(p.join(tempDir.path, 'sub')).createSync();
        File(p.join(tempDir.path, 'sub', 'deep.txt')).writeAsStringSync('');

        final result = await byName['fs_find']!.handler({
          'path': '.',
          'pattern': '**/*.txt',
        });

        final paths = result! as List<String>;
        expect(paths, contains(p.join('sub', 'deep.txt')));
      });

      test('throws for non-existent directory', () async {
        expect(
          () => byName['fs_find']!.handler({
            'path': 'nope',
            'pattern': '*',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('path traversal', () {
      test('rejects parent directory traversal', () async {
        expect(
          () => byName['fs_cat']!.handler({
            'path': '../../../etc/passwd',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects absolute paths outside root', () async {
        expect(
          () => byName['fs_cat']!.handler({'path': '/etc/passwd'}),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('fs_exists rejects traversal', () async {
        expect(
          () => byName['fs_exists']!.handler({
            'path': '../../etc/passwd',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects empty path', () async {
        expect(
          () => byName['fs_cat']!.handler({'path': ''}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('schemas', () {
      test('fs_cat has path param', () {
        final schema = byName['fs_cat']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'path');
        expect(schema.params[0].type, HostParamType.string);
      });

      test('fs_write has path and content params', () {
        final schema = byName['fs_write']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'path');
        expect(schema.params[1].name, 'content');
      });

      test('fs_ls has path and optional recursive', () {
        final schema = byName['fs_ls']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'path');
        expect(schema.params[1].name, 'recursive');
        expect(schema.params[1].isRequired, isFalse);
      });

      test('fs_find has path and pattern params', () {
        final schema = byName['fs_find']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'path');
        expect(schema.params[1].name, 'pattern');
      });

      test('fs_stat has path param', () {
        final schema = byName['fs_stat']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'path');
      });
    });
  });
}
