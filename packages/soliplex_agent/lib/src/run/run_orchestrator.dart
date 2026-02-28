import 'dart:async';

import 'package:soliplex_agent/src/models/failure_reason.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
import 'package:soliplex_agent/src/run/error_classifier.dart';
import 'package:soliplex_agent/src/run/run_state.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Orchestrates a single AG-UI run lifecycle.
///
/// State machine: Idle -> Running -> Completed/Failed/Cancelled.
/// Only one run at a time; concurrent `startRun()` throws [StateError].
class RunOrchestrator {
  RunOrchestrator({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistry toolRegistry,
    required Logger logger,
  })  : _api = api,
        _agUiClient = agUiClient,
        _toolRegistry = toolRegistry,
        _logger = logger;

  final SoliplexApi _api;
  final AgUiClient _agUiClient;
  final ToolRegistry _toolRegistry;
  final Logger _logger;

  final StreamController<RunState> _controller =
      StreamController<RunState>.broadcast();

  RunState _currentState = const IdleState();
  bool _disposed = false;
  CancelToken? _cancelToken;
  StreamSubscription<BaseEvent>? _subscription;
  bool _receivedTerminalEvent = false;

  /// The current state of the orchestrator.
  RunState get currentState => _currentState;

  /// Broadcast stream of state transitions.
  Stream<RunState> get stateChanges => _controller.stream;

  /// Starts a new agent run.
  ///
  /// Throws [StateError] if already running or disposed.
  Future<void> startRun({
    required ThreadKey key,
    required String userMessage,
    String? existingRunId,
    ThreadHistory? cachedHistory,
  }) async {
    _guardNotRunning();
    try {
      final runId = await _createOrUseRun(key, existingRunId);
      final conversation = _buildConversation(
        key,
        userMessage,
        cachedHistory,
      );
      final input = _buildInput(key, runId, conversation);
      final endpoint = _buildEndpoint(key, runId);
      final initialState = RunningState(
        threadKey: key,
        runId: runId,
        conversation: conversation,
        streaming: const AwaitingText(),
      );
      _subscribeToStream(endpoint, input, initialState);
    } on Object catch (error, stackTrace) {
      _handleStartError(key, error, stackTrace);
    }
  }

  /// Cancels the current run. No-op if idle.
  void cancelRun() {
    _guardNotDisposed();
    if (_currentState is! RunningState) return;
    final running = _currentState as RunningState;
    _cancelToken?.cancel();
    _cleanup();
    _setState(
      CancelledState(
        threadKey: running.threadKey,
        conversation: running.conversation,
      ),
    );
  }

  /// Resets to [IdleState], cancelling any active run.
  void reset() {
    _guardNotDisposed();
    _cancelToken?.cancel();
    _cleanup();
    _setState(const IdleState());
  }

  /// Syncs to a thread without starting a run.
  ///
  /// Pass `null` to clear (reset to idle).
  void syncToThread(ThreadKey? key) {
    _guardNotDisposed();
    if (key == null) {
      reset();
      return;
    }
    if (_currentState is RunningState) {
      throw StateError('Cannot sync while a run is active');
    }
    _setState(const IdleState());
  }

  /// Releases all resources. Must be called when done.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelToken?.cancel();
    _cleanup();
    unawaited(_controller.close());
  }

  // ---------------------------------------------------------------------------
  // Private helpers — each <=40 LOC, <=4 params
  // ---------------------------------------------------------------------------

  void _guardNotRunning() {
    _guardNotDisposed();
    if (_currentState is RunningState) {
      throw StateError('A run is already active');
    }
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw StateError('RunOrchestrator has been disposed');
    }
  }

  Future<String> _createOrUseRun(
    ThreadKey key,
    String? existingRunId,
  ) async {
    if (existingRunId != null) return existingRunId;
    final runInfo = await _api.createRun(key.roomId, key.threadId);
    return runInfo.id;
  }

  Conversation _buildConversation(
    ThreadKey key,
    String userMessage,
    ThreadHistory? cachedHistory,
  ) {
    final priorMessages = cachedHistory?.messages ?? <ChatMessage>[];
    final userMsg = TextMessage.create(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      user: ChatUser.user,
      text: userMessage,
    );
    return Conversation(
      threadId: key.threadId,
      messages: [...priorMessages, userMsg],
      aguiState: cachedHistory?.aguiState ?? const {},
      messageStates: cachedHistory?.messageStates ?? const {},
    );
  }

  SimpleRunAgentInput _buildInput(
    ThreadKey key,
    String runId,
    Conversation conversation,
  ) {
    final aguiMessages = convertToAgui(conversation.messages);
    return SimpleRunAgentInput(
      threadId: key.threadId,
      runId: runId,
      messages: aguiMessages,
      tools: _toolRegistry.toolDefinitions,
    );
  }

  String _buildEndpoint(ThreadKey key, String runId) {
    return 'rooms/${key.roomId}/agui/${key.threadId}/$runId';
  }

  void _subscribeToStream(
    String endpoint,
    SimpleRunAgentInput input,
    RunningState initialState,
  ) {
    _cancelToken = CancelToken();
    _receivedTerminalEvent = false;
    final stream = _agUiClient.runAgent(
      endpoint,
      input,
      cancelToken: _cancelToken,
    );
    _setState(initialState);
    _subscription = stream.listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );
  }

  void _onEvent(BaseEvent event) {
    final running = _currentState;
    if (running is! RunningState) return;
    final result = processEvent(
      running.conversation,
      running.streaming,
      event,
    );
    _mapEventResult(running, result, event);
  }

  void _mapEventResult(
    RunningState previous,
    EventProcessingResult result,
    BaseEvent event,
  ) {
    if (event is RunFinishedEvent) {
      _receivedTerminalEvent = true;
      _cleanup();
      _setState(
        CompletedState(
          threadKey: previous.threadKey,
          runId: previous.runId,
          conversation: result.conversation,
        ),
      );
      return;
    }
    if (event is RunErrorEvent) {
      _receivedTerminalEvent = true;
      _cleanup();
      _setState(
        FailedState(
          threadKey: previous.threadKey,
          reason: FailureReason.serverError,
          error: event.message,
          conversation: result.conversation,
        ),
      );
      return;
    }
    _setState(
      previous.copyWith(
        conversation: result.conversation,
        streaming: result.streaming,
      ),
    );
  }

  void _onStreamDone() {
    if (_receivedTerminalEvent) return;
    final running = _currentState;
    if (running is! RunningState) return;
    _cleanup();
    _logger.warning('Stream ended without terminal event');
    _setState(
      FailedState(
        threadKey: running.threadKey,
        reason: FailureReason.networkLost,
        error: 'Stream ended without terminal event',
        conversation: running.conversation,
      ),
    );
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    final running = _currentState;
    if (running is! RunningState) return;
    _cleanup();
    if (error is CancellationError) {
      _setState(
        CancelledState(
          threadKey: running.threadKey,
          conversation: running.conversation,
        ),
      );
      return;
    }
    final reason = classifyError(error);
    _logger.error(
      'Run failed',
      error: error,
      stackTrace: stackTrace,
    );
    _setState(
      FailedState(
        threadKey: running.threadKey,
        reason: reason,
        error: error.toString(),
        conversation: running.conversation,
      ),
    );
  }

  void _handleStartError(
    ThreadKey key,
    Object error,
    StackTrace stackTrace,
  ) {
    _cleanup();
    final reason = classifyError(error);
    _logger.error(
      'Failed to start run',
      error: error,
      stackTrace: stackTrace,
    );
    _setState(
      FailedState(
        threadKey: key,
        reason: reason,
        error: error.toString(),
      ),
    );
  }

  void _setState(RunState newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  void _cleanup() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _cancelToken = null;
  }
}
