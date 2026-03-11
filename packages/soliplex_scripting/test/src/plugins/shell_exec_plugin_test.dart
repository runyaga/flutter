import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('ShellExecPlugin', () {
    late Directory tempDir;
    late ShellExecPlugin plugin;
    late Map<String, HostFunction> byName;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('shell_exec_test_');
      plugin = ShellExecPlugin(rootPath: tempDir.path);
      byName = {for (final f in plugin.functions) f.schema.name: f};
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('namespace is shell', () {
      expect(plugin.namespace, 'shell');
    });

    test('provides 2 functions', () {
      expect(plugin.functions, hasLength(2));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['shell_run', 'shell_allowed']));
    });

    test('pythonPrelude defines run and allowed_commands wrappers', () {
      final prelude = plugin.pythonPrelude;
      expect(prelude, contains('def run('));
      expect(prelude, contains('def allowed_commands('));
      expect(prelude, contains('_help_docs[run]'));
      expect(prelude, contains('_help_docs[allowed_commands]'));
    });

    test('systemPromptContext is non-null', () {
      expect(plugin.systemPromptContext, isNotNull);
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('shell_run'));
      expect(names, contains('shell_allowed'));
    });

    test('defaultAllowedCommands is dart and echo only', () {
      expect(
        ShellExecPlugin.defaultAllowedCommands,
        unorderedEquals(['dart', 'echo']),
      );
    });

    test('custom allowedCommands overrides defaults', () {
      final custom =
          ShellExecPlugin(rootPath: tempDir.path, allowedCommands: {'echo'});
      final fn =
          custom.functions.firstWhere((f) => f.schema.name == 'shell_run');

      expect(
        () => fn.handler({'command': 'dart'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    group('shell_run', () {
      test('runs allowed command and returns stdout', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'echo',
          'args': ['hello'],
        });

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect((map['stdout']! as String).trim(), 'hello');
        expect(map['exit_code'], 0);
      });

      test('captures stderr on failure', () async {
        // Use custom allowlist with ls for this test.
        final custom = ShellExecPlugin(
          rootPath: tempDir.path,
          allowedCommands: {'ls'},
        );
        final fn =
            custom.functions.firstWhere((f) => f.schema.name == 'shell_run');

        final result = await fn.handler({
          'command': 'ls',
          'args': ['__nonexistent_path_12345__'],
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], isNot(0));
        expect(map['stderr'], isA<String>());
      });

      test('runs with no args', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'echo',
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], 0);
      });

      test('resolves cwd within sandbox', () async {
        Directory(p.join(tempDir.path, 'sub')).createSync();

        // Use custom allowlist with pwd for this test.
        final custom = ShellExecPlugin(
          rootPath: tempDir.path,
          allowedCommands: {'pwd'},
        );
        final fn =
            custom.functions.firstWhere((f) => f.schema.name == 'shell_run');

        final result = await fn.handler({
          'command': 'pwd',
          'cwd': 'sub',
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], 0);
        expect(
          (map['stdout']! as String).trim(),
          p.join(tempDir.resolveSymbolicLinksSync(), 'sub'),
        );
      });

      test('rejects disallowed command', () async {
        expect(
          () => byName['shell_run']!.handler({'command': 'rm'}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('not allowed'),
            ),
          ),
        );
      });

      test('rejects non-string command', () async {
        expect(
          () => byName['shell_run']!.handler({'command': 123}),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects cwd escaping sandbox', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'args': ['hi'],
            'cwd': '../../../tmp',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles timeout by killing process', () async {
        final shortTimeout = ShellExecPlugin(
          rootPath: tempDir.path,
          allowedCommands: {'sleep'},
          timeout: const Duration(milliseconds: 100),
        );
        final fn = shortTimeout.functions
            .firstWhere((f) => f.schema.name == 'shell_run');

        expect(
          () => fn.handler({
            'command': 'sleep',
            'args': ['10'],
          }),
          throwsA(isA<StateError>()),
        );
      });

      test('passes list args as strings', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'echo',
          'args': [1, 2, 'three'],
        });

        final map = result! as Map<String, Object?>;
        expect((map['stdout']! as String).trim(), '1 2 three');
      });
    });

    group('dart subcommand restrictions', () {
      test('allows dart analyze', () async {
        // dart analyze exits quickly in an empty dir.
        final result = await byName['shell_run']!.handler({
          'command': 'dart',
          'args': ['analyze'],
        });

        final map = result! as Map<String, Object?>;
        // May fail (no pubspec) but should NOT be rejected by validation.
        expect(map, isA<Map<String, Object?>>());
      });

      test('allows dart format', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'dart',
          'args': ['format', '--set-exit-if-changed', '.'],
        });

        final map = result! as Map<String, Object?>;
        expect(map, isA<Map<String, Object?>>());
      });

      test('allows dart --version (flags only)', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'dart',
          'args': ['--version'],
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], 0);
      });

      test('rejects dart run', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['run', 'evil.dart'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('dart run not allowed'),
            ),
          ),
        );
      });

      test('rejects dart compile', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['compile', 'exe', 'main.dart'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('dart compile not allowed'),
            ),
          ),
        );
      });

      test('rejects dart create', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['create', 'evil_pkg'],
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects dart run even with leading flags', () async {
        // dart --enable-asserts run evil.dart
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['--enable-asserts', 'run', 'evil.dart'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('dart run not allowed'),
            ),
          ),
        );
      });

      test('allows dart pub get', () async {
        // Will fail (no pubspec) but should not be rejected by validation.
        final result = await byName['shell_run']!.handler({
          'command': 'dart',
          'args': ['pub', 'get'],
        });

        expect(result, isA<Map<String, Object?>>());
      });

      test('rejects dart pub global', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['pub', 'global', 'activate', 'evil_pkg'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('dart pub global not allowed'),
            ),
          ),
        );
      });

      test('rejects dart pub run', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['pub', 'run', 'evil_script'],
          }),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('argument path validation', () {
      test('rejects absolute paths in args', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'args': ['/etc/passwd'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Absolute paths not allowed'),
            ),
          ),
        );
      });

      test('rejects path traversal with ../', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'args': ['../../../etc/passwd'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Path traversal not allowed'),
            ),
          ),
        );
      });

      test('rejects path traversal with /..', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'args': ['foo/../../etc'],
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects standalone ..', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'args': ['..'],
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects absolute paths in flag values', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['analyze', '--packages=/evil/path'],
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Absolute paths in flag values'),
            ),
          ),
        );
      });

      test('rejects traversal in flag values', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'dart',
            'args': ['analyze', '--output=../evil'],
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('allows relative paths within sandbox', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'echo',
          'args': ['lib/src/foo.dart'],
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], 0);
      });

      test('allows normal flags', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'echo',
          'args': ['--fatal-infos', '--reporter=json'],
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], 0);
      });
    });

    group('environment sanitization', () {
      test('child process receives only sanitized env vars', () async {
        final custom = ShellExecPlugin(
          rootPath: tempDir.path,
          allowedCommands: {'env'},
        );
        final fn =
            custom.functions.firstWhere((f) => f.schema.name == 'shell_run');

        final result = await fn.handler({'command': 'env'});
        final map = result! as Map<String, Object?>;
        final envOutput = map['stdout']! as String;

        // Common env vars that should NOT be passed through.
        expect(envOutput, isNot(contains('USER=')));
        expect(envOutput, isNot(contains('SHELL=')));
        expect(envOutput, isNot(contains('TERM=')));
        expect(envOutput, isNot(contains('LANG=')));

        // Only PATH, HOME, and optionally PUB_CACHE should be present.
        final lines =
            envOutput.trim().split('\n').where((l) => l.isNotEmpty).toList();
        expect(lines.length, lessThanOrEqualTo(3));
      });

      test('sanitizedEnv contains PATH and HOME', () {
        final env = ShellExecPlugin.sanitizedEnv();
        expect(env, contains('PATH'));
        expect(env, contains('HOME'));
      });
    });

    group('shell_allowed', () {
      test('returns sorted list of allowed commands', () async {
        final result = await byName['shell_allowed']!.handler({});

        expect(result, isA<List<String>>());
        final list = result! as List<String>;
        expect(list, ['dart', 'echo']);
      });

      test('reflects custom allowlist', () async {
        final custom = ShellExecPlugin(
          rootPath: tempDir.path,
          allowedCommands: {'foo', 'bar'},
        );
        final fn = custom.functions
            .firstWhere((f) => f.schema.name == 'shell_allowed');
        final result = await fn.handler({});

        expect(result, ['bar', 'foo']);
      });
    });

    group('cwd path traversal', () {
      test('rejects parent directory traversal in cwd', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'cwd': '../../etc',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects absolute cwd outside root', () async {
        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'cwd': '/etc',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects symlink cwd escape', () async {
        // Create a symlink inside sandbox pointing outside.
        Link(p.join(tempDir.path, 'evil_link')).createSync('/tmp');

        expect(
          () => byName['shell_run']!.handler({
            'command': 'echo',
            'cwd': 'evil_link',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('schemas', () {
      test('shell_run has command, args, and cwd params', () {
        final schema = byName['shell_run']!.schema;
        expect(schema.params, hasLength(3));
        expect(schema.params[0].name, 'command');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[1].name, 'args');
        expect(schema.params[1].type, HostParamType.list);
        expect(schema.params[1].isRequired, isFalse);
        expect(schema.params[2].name, 'cwd');
        expect(schema.params[2].type, HostParamType.string);
        expect(schema.params[2].isRequired, isFalse);
      });

      test('shell_allowed has no params', () {
        final schema = byName['shell_allowed']!.schema;
        expect(schema.params, isEmpty);
      });
    });
  });
}
