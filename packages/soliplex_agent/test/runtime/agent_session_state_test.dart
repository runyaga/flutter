import 'package:soliplex_agent/src/runtime/agent_session_state.dart';
import 'package:test/test.dart';

void main() {
  group('AgentSessionState', () {
    test('has exactly 5 values', () {
      expect(AgentSessionState.values, hasLength(5));
    });

    test('contains all expected values', () {
      expect(
        AgentSessionState.values,
        containsAll([
          AgentSessionState.spawning,
          AgentSessionState.running,
          AgentSessionState.completed,
          AgentSessionState.failed,
          AgentSessionState.cancelled,
        ]),
      );
    });

    test('each value has a distinct name', () {
      final names = AgentSessionState.values.map((v) => v.name).toSet();
      expect(names, hasLength(AgentSessionState.values.length));
    });
  });
}
