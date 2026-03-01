import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

/// Test data factory with sensible defaults.
class TestData {
  TestData._();

  static RunInfo createRun({
    String id = 'run_1',
    String threadId = 'thread_1',
  }) {
    return RunInfo(
      id: id,
      threadId: threadId,
      createdAt: DateTime(2025),
    );
  }

  static TextMessage createUserMessage({
    String id = 'msg_user_1',
    String text = 'Hello',
  }) {
    return TextMessage.create(
      id: id,
      user: ChatUser.user,
      text: text,
    );
  }

  static TextMessage createAssistantMessage({
    String id = 'msg_assistant_1',
    String text = 'Hi there!',
  }) {
    return TextMessage.create(
      id: id,
      user: ChatUser.assistant,
      text: text,
    );
  }
}
