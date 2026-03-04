import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme/steampunk_theme.dart';
import '../features/chat/chat_panel.dart';
import '../features/connection/connect_screen.dart';
import '../layout/mirc_shell.dart';
import 'runyaga_config.dart';

/// Launch the Boiler Room application.
///
/// Call from your app's main():
/// ```dart
/// void main() {
///   runApp(const RunyagaApp());
/// }
/// ```
class RunyagaApp extends StatelessWidget {
  const RunyagaApp({
    this.config = const RunyagaConfig(),
    super.key,
  });

  final RunyagaConfig config;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: config.appTitle,
        theme: boilerRoomTheme(),
        debugShowCheckedModeBanner: false,
        home: const SelectionArea(child: _AppShell()),
      ),
    );
  }
}

/// Root shell managing connection → chat transition.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _isConnected = false;

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return ConnectScreen(
        onConnected: () => setState(() => _isConnected = true),
      );
    }

    return const MircShell(
      chatPanel: ChatPanel(),
    );
  }
}
