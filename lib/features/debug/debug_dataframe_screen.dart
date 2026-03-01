// TEMPORARY: Debug DataFrame REPL — remove after validation.
// Cleanup: delete this file when no longer needed.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

/// REPL-style debug screen for testing DataFrame operations directly.
///
/// Executes df_* host functions backed by a local [DfRegistry], without
/// needing a Monty bridge or backend connection.
class DebugDataFrameScreen extends ConsumerStatefulWidget {
  const DebugDataFrameScreen({super.key});

  @override
  ConsumerState<DebugDataFrameScreen> createState() =>
      _DebugDataFrameScreenState();
}

class _DebugDataFrameScreenState extends ConsumerState<DebugDataFrameScreen> {
  final _inputController = TextEditingController();
  final _outputLines = <_OutputLine>[];
  final _scrollController = ScrollController();

  late final DfRegistry _registry;
  late final Map<String, _DfCommand> _commands;

  @override
  void initState() {
    super.initState();
    _registry = DfRegistry();
    _commands = _buildCommands();
    _addOutput('DataFrame REPL ready. Type "help" for commands.', _Kind.info);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _registry.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.amber.shade100,
          child: const Text(
            '\u26A0 TEMPORARY SCAFFOLDING \u2014 remove after validation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: _outputLines.length,
            itemBuilder: (_, i) => _buildLine(_outputLines[i]),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text(
                '\u276F ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'df_create, df_head, df_filter, help ...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onSubmitted: (_) => _execute(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _execute,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear output',
                onPressed: () => setState(_outputLines.clear),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLine(_OutputLine line) {
    final (color, prefix) = switch (line.kind) {
      _Kind.input => (Colors.blue.shade700, '\u276F '),
      _Kind.result => (Colors.green.shade800, '  '),
      _Kind.error => (Colors.red.shade700, '! '),
      _Kind.info => (Colors.grey.shade600, '# '),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        '$prefix${line.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  void _addOutput(String text, _Kind kind) {
    setState(() => _outputLines.add(_OutputLine(text, kind)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _execute() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    _inputController.clear();
    _addOutput(input, _Kind.input);

    if (input == 'help') {
      _showHelp();
      return;
    }

    // Parse: command_name arg1 arg2 ...  OR  command_name(json_args)
    final parenMatch = RegExp(r'^(\w+)\((.+)\)$').firstMatch(input);
    final spaceMatch = RegExp(r'^(\w+)\s*(.*)$').firstMatch(input);

    final String name;
    final String rawArgs;
    if (parenMatch != null) {
      name = parenMatch.group(1)!;
      rawArgs = parenMatch.group(2)!;
    } else if (spaceMatch != null) {
      name = spaceMatch.group(1)!;
      rawArgs = spaceMatch.group(2)!;
    } else {
      _addOutput('Could not parse command. Type "help".', _Kind.error);
      return;
    }

    final cmd = _commands[name];
    if (cmd == null) {
      _addOutput('Unknown command: $name. Type "help".', _Kind.error);
      return;
    }

    try {
      final result = await cmd.execute(rawArgs);
      _addOutput(result, _Kind.result);
    } on Object catch (e) {
      _addOutput('$e', _Kind.error);
    }
  }

  void _showHelp() {
    final buf = StringBuffer('Available commands:\n');
    for (final entry in _commands.entries) {
      buf.writeln('  ${entry.key.padRight(20)} ${entry.value.help}');
    }
    buf
      ..writeln('\nExamples:')
      ..writeln(
        '  df_create([{"name":"Alice","age":30},{"name":"Bob","age":25}])',
      )
      ..writeln('  df_head 1')
      ..writeln(
        '  df_filter({"handle":1,"column":"age","op":">","value":28})',
      )
      ..writeln('  df_shape 1')
      ..writeln('  df_columns 1')
      ..writeln(r'  df_from_csv name,age\nAlice,30\nBob,25');
    _addOutput(buf.toString(), _Kind.info);
  }

  Map<String, _DfCommand> _buildCommands() {
    final fns = buildDfFunctions(_registry);
    final byName = {for (final f in fns) f.schema.name: f};
    final cmds = <String, _DfCommand>{};

    for (final entry in byName.entries) {
      final schema = entry.value.schema;
      final handler = entry.value.handler;
      final paramDesc = schema.params.map((p) => p.name).join(', ');
      cmds[entry.key] = _DfCommand(
        help: '($paramDesc) ${schema.description}',
        execute: (rawArgs) async {
          // Try JSON object parse first
          Map<String, Object?> args;
          if (rawArgs.startsWith('{')) {
            args = Map<String, Object?>.from(
              jsonDecode(rawArgs) as Map,
            );
          } else if (rawArgs.isEmpty) {
            args = {};
          } else {
            // Single-arg shorthand: first param gets the parsed value
            if (schema.params.isEmpty) {
              args = {};
            } else {
              final firstParam = schema.params.first;
              args = {firstParam.name: _parseSimpleArg(rawArgs)};
            }
          }

          final result = await handler(args);
          return _formatResult(result);
        },
      );
    }

    return cmds;
  }

  Object? _parseSimpleArg(String raw) {
    final trimmed = raw.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) return asDouble;
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
    if (trimmed == 'null') return null;
    // Try JSON parse
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return trimmed;
    }
  }

  String _formatResult(Object? result) {
    if (result == null) return '(null)';
    if (result is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(result);
    }
    if (result is Map) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(result);
    }
    return '$result';
  }
}

enum _Kind { input, result, error, info }

class _OutputLine {
  const _OutputLine(this.text, this.kind);
  final String text;
  final _Kind kind;
}

class _DfCommand {
  const _DfCommand({required this.help, required this.execute});
  final String help;
  final Future<String> Function(String rawArgs) execute;
}
