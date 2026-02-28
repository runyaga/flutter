import 'package:soliplex_agent/soliplex_agent.dart';

String formatResult(AgentResult result) {
  final id = result.threadKey.threadId;
  return switch (result) {
    AgentSuccess(:final output) => '[$id] SUCCESS: $output',
    AgentFailure(:final reason, :final error) =>
      '[$id] FAILED ($reason): $error',
    AgentTimedOut(:final elapsed) => '[$id] TIMED OUT after $elapsed',
  };
}
