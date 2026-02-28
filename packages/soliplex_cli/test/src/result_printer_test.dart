import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_cli/src/result_printer.dart';
import 'package:test/test.dart';

const ThreadKey _key = (
  serverId: 'default',
  roomId: 'room',
  threadId: 'abc-123',
);

void main() {
  group('formatResult', () {
    test('formats AgentSuccess', () {
      const result = AgentSuccess(
        threadKey: _key,
        output: 'The answer is 42.',
        runId: 'run-1',
      );

      expect(
        formatResult(result),
        equals('[abc-123] SUCCESS: The answer is 42.'),
      );
    });

    test('formats AgentFailure', () {
      const result = AgentFailure(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'Connection reset',
      );

      expect(
        formatResult(result),
        equals(
          '[abc-123] FAILED '
          '(FailureReason.networkLost): Connection reset',
        ),
      );
    });

    test('formats AgentTimedOut', () {
      const result = AgentTimedOut(
        threadKey: _key,
        elapsed: Duration(seconds: 30),
      );

      expect(
        formatResult(result),
        equals('[abc-123] TIMED OUT after 0:00:30.000000'),
      );
    });
  });
}
