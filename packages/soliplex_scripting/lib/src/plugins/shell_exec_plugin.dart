import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Plugin exposing sandboxed shell command execution to Monty scripts.
///
/// Security layers:
/// 1. **Command allowlist** — only permitted executables may run.
/// 2. **Dart subcommand restrictions** — blocks `dart run`, `dart eval`,
///    `dart compile` (arbitrary code execution).
/// 3. **Argument path validation** — rejects absolute paths, `..`
///    traversal, and absolute paths in flag values.
/// 4. **CWD sandboxing** — working directory must resolve within
///    `rootPath`; symlinks are resolved to prevent escape.
/// 5. **Environment sanitization** — child processes receive only
///    `PATH`, `HOME`, and `PUB_CACHE` (no secret leakage).
/// 6. **Process kill on timeout** — child processes are killed (not
///    orphaned) when the timeout expires.
///
/// **Custom allowlists:** If you override [defaultAllowedCommands],
/// beware that commands like `find` (has `-exec`), `xargs`, `awk`,
/// and `perl` can execute arbitrary subcommands. The argument
/// validation layer does NOT prevent this.
class ShellExecPlugin extends MontyPlugin {
  /// Creates a [ShellExecPlugin] rooted at [rootPath].
  ///
  /// Only commands in [allowedCommands] may be executed. Defaults to
  /// `dart` and `echo` only.
  ShellExecPlugin({
    required String rootPath,
    Set<String>? allowedCommands,
    this.timeout = const Duration(seconds: 30),
  })  : _rootPath = Directory(rootPath).resolveSymbolicLinksSync(),
        _allowedCommands = allowedCommands ?? defaultAllowedCommands;

  /// Default allowlist: only the Dart toolchain and echo.
  ///
  /// General-purpose commands (`cat`, `grep`, `find`, etc.) are
  /// excluded because their arguments accept arbitrary file paths
  /// that cannot be reliably sandboxed.
  static const defaultAllowedCommands = <String>{'dart', 'echo'};

  /// Dart subcommands that cannot execute arbitrary code.
  static const safeDartSubcommands = <String>{
    'analyze',
    'fix',
    'format',
    'pub',
    'test',
  };

  /// Safe `dart pub` subcommands.
  static const safeDartPubSubcommands = <String>{
    'deps',
    'get',
    'outdated',
    'upgrade',
  };

  final String _rootPath;
  final Set<String> _allowedCommands;

  /// Maximum duration for a single command execution.
  ///
  /// When exceeded, the child process is killed via `Process.kill()`.
  final Duration timeout;

  @override
  String get namespace => 'shell';

  @override
  String? get systemPromptContext =>
      'Execute sandboxed shell commands (dart analyze, dart test, etc). '
      'Commands restricted to allowlist; args cannot contain absolute '
      'paths or path traversal.';

  @override
  String get pythonPrelude => '''
def run(command, args=None, cwd=None):
    if args == None:
        args = []
    return shell_run(command=command, args=args, cwd=cwd)
_help_docs[run] = "Execute a shell command. Usage: run(command, args=None, cwd=None)"
_help_list = _help_list + [["run", "Execute a sandboxed shell command"]]

def allowed_commands():
    return shell_allowed()
_help_docs[allowed_commands] = "List allowed commands. Usage: allowed_commands()"
_help_list = _help_list + [["allowed_commands", "List allowed shell commands"]]''';

  @override
  List<HostFunction> get functions => [_run(), _allowed()];

  // ---------------------------------------------------------------------------
  // Security: CWD resolution
  // ---------------------------------------------------------------------------

  /// Resolves [cwd] within the sandbox root.
  ///
  /// When the target exists on disk, symlinks are resolved first so a
  /// malicious symlink inside the sandbox cannot escape the root. When
  /// the target does not exist yet, the path is canonicalized lexically.
  ///
  /// Throws [ArgumentError] if the resolved path escapes the root.
  String _resolveCwd(String? cwd) {
    if (cwd == null || cwd.isEmpty || cwd == '.') return _rootPath;
    final joined = p.join(_rootPath, cwd);
    final normalized =
        FileSystemEntity.typeSync(joined) != FileSystemEntityType.notFound
            ? Directory(joined).resolveSymbolicLinksSync()
            : p.canonicalize(joined);
    if (!p.isWithin(_rootPath, normalized) && normalized != _rootPath) {
      throw ArgumentError('Working directory escapes sandbox root: $cwd');
    }
    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Security: argument validation
  // ---------------------------------------------------------------------------

  /// Validates that arguments do not contain path escapes.
  ///
  /// Rejects:
  /// - Absolute paths (`/etc/passwd`)
  /// - Path traversal (`../`, `/..`)
  /// - Absolute paths in flag values (`--output=/tmp/foo`)
  static void validateArgSafety(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith('/')) {
        throw ArgumentError(
          'Absolute paths not allowed in arguments: $arg',
        );
      }
      if (arg.contains('=/')) {
        throw ArgumentError(
          'Absolute paths in flag values not allowed: $arg',
        );
      }
      if (arg == '..' || arg.contains('../') || arg.contains('/..')) {
        throw ArgumentError(
          'Path traversal not allowed in arguments: $arg',
        );
      }
    }
  }

  /// Validates that a `dart` invocation uses a safe subcommand.
  ///
  /// Blocks `dart run`, `dart compile`, `dart create` which can
  /// execute arbitrary code. Only [safeDartSubcommands] are allowed.
  /// For `dart pub`, only [safeDartPubSubcommands] are allowed.
  static void validateDartSubcommand(List<String> args) {
    // Find the subcommand (first non-flag argument).
    final nonFlags = args.where((a) => !a.startsWith('-')).toList();
    if (nonFlags.isEmpty) return; // e.g., `dart --version`

    final sub = nonFlags.first;
    if (!safeDartSubcommands.contains(sub)) {
      throw ArgumentError(
        'dart $sub not allowed. '
        'Allowed: ${safeDartSubcommands.join(', ')}',
      );
    }

    if (sub == 'pub' && nonFlags.length > 1) {
      final pubSub = nonFlags[1];
      if (!safeDartPubSubcommands.contains(pubSub)) {
        throw ArgumentError(
          'dart pub $pubSub not allowed. '
          'Allowed: ${safeDartPubSubcommands.join(', ')}',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Security: environment sanitization
  // ---------------------------------------------------------------------------

  /// Returns a sanitized environment with only essential variables.
  ///
  /// Prevents leakage of API keys, session tokens, and other secrets
  /// from the parent process's environment.
  static Map<String, String> sanitizedEnv() {
    final env = Platform.environment;
    return <String, String>{
      if (env.containsKey('PATH')) 'PATH': env['PATH']!,
      if (env.containsKey('HOME')) 'HOME': env['HOME']!,
      if (env.containsKey('PUB_CACHE')) 'PUB_CACHE': env['PUB_CACHE']!,
    };
  }

  // ---------------------------------------------------------------------------
  // Host functions
  // ---------------------------------------------------------------------------

  HostFunction _run() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'shell_run',
          description: 'Execute a shell command and return stdout, stderr, and '
              'exit code.',
          params: [
            HostParam(
              name: 'command',
              type: HostParamType.string,
              description: 'Command to execute (must be in allowlist).',
            ),
            HostParam(
              name: 'args',
              type: HostParamType.list,
              description: 'Command arguments as a list of strings.',
              isRequired: false,
            ),
            HostParam(
              name: 'cwd',
              type: HostParamType.string,
              description: 'Working directory relative to sandbox root.',
              isRequired: false,
            ),
          ],
        ),
        handler: (args) async {
          final command = args['command'];
          if (command is! String) {
            throw ArgumentError('command must be a string.');
          }
          if (!_allowedCommands.contains(command)) {
            throw ArgumentError(
              'Command not allowed: $command. '
              'Allowed: ${(_allowedCommands.toList()..sort()).join(', ')}',
            );
          }

          final rawArgs = args['args'];
          final execArgs = <String>[];
          if (rawArgs is List) {
            for (final arg in rawArgs) {
              execArgs.add(arg.toString());
            }
          }

          // Security: validate arguments BEFORE execution.
          validateArgSafety(execArgs);
          if (command == 'dart') {
            validateDartSubcommand(execArgs);
          }

          final cwd = args['cwd'];
          final workDir = _resolveCwd(cwd is String ? cwd : null);

          // Use Process.start so we can kill on timeout (not orphan).
          final process = await Process.start(
            command,
            execArgs,
            workingDirectory: workDir,
            environment: sanitizedEnv(),
            includeParentEnvironment: false,
          );

          try {
            final results = await Future.wait<Object>([
              process.stdout.transform(utf8.decoder).join(),
              process.stderr.transform(utf8.decoder).join(),
              process.exitCode,
            ]).timeout(timeout);

            return <String, Object?>{
              'stdout': results[0] as String,
              'stderr': results[1] as String,
              'exit_code': results[2] as int,
            };
          } on TimeoutException {
            process.kill();
            throw StateError(
              'Command timed out after ${timeout.inSeconds}s: '
              '$command ${execArgs.join(' ')}',
            );
          }
        },
      );

  HostFunction _allowed() => HostFunction(
        schema: const HostFunctionSchema(
          name: 'shell_allowed',
          description: 'List all commands that are allowed to be executed.',
        ),
        handler: (args) async {
          return _allowedCommands.toList()..sort();
        },
      );
}
