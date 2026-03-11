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

    test('defaultAllowedCommands includes dart', () {
      expect(ShellExecPlugin.defaultAllowedCommands, contains('dart'));
    });

    test('custom allowedCommands overrides defaults', () {
      final custom =
          ShellExecPlugin(rootPath: tempDir.path, allowedCommands: {'echo'});
      final fn =
          custom.functions.firstWhere((f) => f.schema.name == 'shell_run');

      // echo is allowed.
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
        // ls on a non-existent path writes to stderr.
        final result = await byName['shell_run']!.handler({
          'command': 'ls',
          'args': ['__nonexistent_path_12345__'],
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], isNot(0));
        expect(map['stderr'], isA<String>());
      });

      test('runs with no args', () async {
        final result = await byName['shell_run']!.handler({
          'command': 'pwd',
        });

        final map = result! as Map<String, Object?>;
        expect(map['exit_code'], 0);
        expect(
          (map['stdout']! as String).trim(),
          tempDir.resolveSymbolicLinksSync(),
        );
      });

      test('resolves cwd within sandbox', () async {
        Directory(p.join(tempDir.path, 'sub')).createSync();

        final result = await byName['shell_run']!.handler({
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

      test('handles timeout', () async {
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

    group('shell_allowed', () {
      test('returns sorted list of allowed commands', () async {
        final result = await byName['shell_allowed']!.handler({});

        expect(result, isA<List<String>>());
        final list = result! as List<String>;
        expect(list, contains('dart'));
        expect(list, contains('echo'));
        // Verify sorted.
        final sorted = List<String>.from(list)..sort();
        expect(list, sorted);
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

    group('path traversal', () {
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
