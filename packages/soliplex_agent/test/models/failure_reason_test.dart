import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

void main() {
  group('FailureReason', () {
    test('has exactly 6 values', () {
      expect(FailureReason.values, hasLength(6));
    });

    test('contains all expected values', () {
      expect(
        FailureReason.values,
        containsAll([
          FailureReason.serverError,
          FailureReason.authExpired,
          FailureReason.networkLost,
          FailureReason.rateLimited,
          FailureReason.toolExecutionFailed,
          FailureReason.internalError,
        ]),
      );
    });

    test('each value has a distinct name', () {
      final names = FailureReason.values.map((v) => v.name).toSet();
      expect(names, hasLength(FailureReason.values.length));
    });
  });
}
