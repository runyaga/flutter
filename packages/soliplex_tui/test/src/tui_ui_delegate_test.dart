import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_tui/src/services/tui_ui_delegate.dart';
import 'package:test/test.dart';

class _MockAgentSession extends Mock implements AgentSession {
  _MockAgentSession(this._id);

  final String _id;

  @override
  String get id => _id;
}

void main() {
  late TuiUiDelegate delegate;
  late _MockAgentSession session;

  setUp(() {
    delegate = TuiUiDelegate();
    session = _MockAgentSession('session-1');
  });

  tearDown(() {
    delegate.dispose();
  });

  group('TuiUiDelegate queue', () {
    test('single request is dispatched to signal', () async {
      final sig = delegate.signalFor('session-1');
      expect(sig.value, isNull);

      final future = delegate.requestToolApproval(
        session: session,
        toolName: 'native.shell',
        arguments: {'command': 'ls'},
        rationale: 'List files',
      );

      // Request should be visible in the signal.
      expect(sig.value, isNotNull);
      expect(sig.value!.toolName, 'native.shell');

      // Resolve it.
      delegate.resolve(approved: true);
      expect(await future, isTrue);
      expect(sig.value, isNull);
    });

    test('denied request returns false', () async {
      delegate.signalFor('session-1');

      final future = delegate.requestToolApproval(
        session: session,
        toolName: 'native.shell',
        arguments: {'command': 'rm -rf /'},
        rationale: 'Delete everything',
      );

      delegate.resolve(approved: false);
      expect(await future, isFalse);
    });

    test('always-allow skips future approvals', () async {
      delegate.signalFor('session-1');

      final first = delegate.requestToolApproval(
        session: session,
        toolName: 'native.clipboard',
        arguments: {},
        rationale: 'Read clipboard',
      );

      delegate.resolve(approved: true, always: true);
      expect(await first, isTrue);
      expect(delegate.alwaysAllowed, contains('native.clipboard'));

      // Second request for same tool should auto-approve.
      final second = delegate.requestToolApproval(
        session: session,
        toolName: 'native.clipboard',
        arguments: {},
        rationale: 'Read clipboard again',
      );
      expect(await second, isTrue);
    });

    test('FIFO: second request waits until first resolves', () async {
      delegate.signalFor('session-1');

      final first = delegate.requestToolApproval(
        session: session,
        toolName: 'native.shell',
        arguments: {'command': 'ls'},
        rationale: 'First',
      );

      final second = delegate.requestToolApproval(
        session: session,
        toolName: 'native.file_read',
        arguments: {'path': '/tmp/x'},
        rationale: 'Second',
      );

      // Only first should be visible.
      final sig = delegate.signalFor('session-1');
      expect(sig.value!.toolName, 'native.shell');

      // Resolve first.
      delegate.resolve(approved: true);
      expect(await first, isTrue);

      // Now second should be visible.
      // Allow microtask to process.
      await Future<void>.delayed(Duration.zero);
      expect(sig.value, isNotNull);
      expect(sig.value!.toolName, 'native.file_read');

      // Resolve second.
      delegate.resolve(approved: true);
      expect(await second, isTrue);
    });

    test('dispose rejects pending requests', () async {
      delegate.signalFor('session-1');

      final future = delegate.requestToolApproval(
        session: session,
        toolName: 'native.shell',
        arguments: {},
        rationale: 'Test',
      );

      // Resolve the dispatched request first so it's not in the queue.
      // Actually, dispose should handle the signal-visible request too.
      delegate.dispose();

      // The dispatched request's completer should have been completed
      // with false by dispose. But it was dispatched (not in queue).
      // The current implementation only rejects queued entries.
      // The dispatched one's completer is on the signal's value.
      // Let's verify it completes (not hanging).
      final result = await future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('Hung'),
      );
      expect(result, isFalse);
    });

    test('cleanup removes session signal', () {
      final sig = delegate.signalFor('session-1');
      expect(sig.value, isNull);

      delegate.cleanup('session-1');

      // Getting signal again creates a fresh one.
      final sig2 = delegate.signalFor('session-1');
      expect(identical(sig, sig2), isFalse);
    });
  });
}
