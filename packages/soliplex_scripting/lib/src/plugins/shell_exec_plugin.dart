import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Plugin exposing sandboxed shell command execution to Monty scripts.
///
/// Commands are restricted to an allowlist and working
/// directories are resolved relative to `rootPath`. This enables agentic
/// TDD workflows where the LLM writes code, runs `dart analyze` and
/// `dart test`, reads errors, and iterates.
class ShellExecPlugin extends MontyPlugin {
  /// Creates a [ShellExecPlugin] rooted at [rootPath].
  ///
  /// Only commands in [allowedCommands] may be executed. Defaults to
  /// the Dart toolchain and basic POSIX utilities.
  ShellExecPlugin({
    required String rootPath,
    Set<String>? allowedCommands,
    this.timeout = const Duration(seconds: 30),
  })  : _rootPath = Directory(rootPath).resolveSymbolicLinksSync(),
        _allowedCommands = allowedCommands ?? defaultAllowedCommands;

  /// Default set of allowed commands.
  static const defaultAllowedCommands = <String>{
    'cat',
    'dart',
    'diff',
    'echo',
    'find',
    'grep',
    'head',
    'ls',
    'pwd',
    'tail',
    'wc',
    'which',
  };

  final String _rootPath;
  final Set<String> _allowedCommands;

  /// Maximum duration for a single command execution.
  final Duration timeout;

  @override
  String get namespace => 'shell';

  @override
  String? get systemPromptContext => 'Execute sandboxed shell commands. '
      'Commands must be in the allowlist. '
      'Use run(command, args, cwd) to execute.';

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

  /// Resolves [cwd] within the sandbox root.
  ///
  /// Returns the root path when [cwd] is null, empty, or `.`.
  /// Throws [ArgumentError] if the resolved path escapes the root.
  String _resolveCwd(String? cwd) {
    if (cwd == null || cwd.isEmpty || cwd == '.') return _rootPath;
    final joined = p.join(_rootPath, cwd);
    final normalized = p.canonicalize(joined);
    if (!p.isWithin(_rootPath, normalized) && normalized != _rootPath) {
      throw ArgumentError('Working directory escapes sandbox root: $cwd');
    }
    return normalized;
  }

  // -- shell_run -------------------------------------------------------------

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

          final cwd = args['cwd'];
          final workDir = _resolveCwd(cwd is String ? cwd : null);

          ProcessResult result;
          try {
            result = await Process.run(
              command,
              execArgs,
              workingDirectory: workDir,
            ).timeout(timeout);
          } on TimeoutException {
            throw StateError(
              'Command timed out after ${timeout.inSeconds}s: '
              '$command ${execArgs.join(' ')}',
            );
          }

          return <String, Object?>{
            'stdout': result.stdout as String,
            'stderr': result.stderr as String,
            'exit_code': result.exitCode,
          };
        },
      );

  // -- shell_allowed ---------------------------------------------------------

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
