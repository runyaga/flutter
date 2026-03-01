import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';

/// Maximum continuation runs before circuit breaker trips.
const maxContinuationDepth = 10;

/// Cubit driving the AG-UI event processing loop for the TUI.
class TuiChatCubit extends Cubit<TuiChatState> {
  TuiChatCubit({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistry toolRegistry,
    required String roomId,
    required String threadId,
  })  : _api = api,
        _agUiClient = agUiClient,
        _toolRegistry = toolRegistry,
        _roomId = roomId,
        _threadId = threadId,
        super(const TuiIdleState());

  final SoliplexApi _api;
  final AgUiClient _agUiClient;
  final ToolRegistry _toolRegistry;
  final String _roomId;
  final String _threadId;

  bool _showReasoning = true;
  bool _isRunning = false;
  StreamSubscription<BaseEvent>? _streamSubscription;
  Conversation _conversation = const Conversation(threadId: '');

  /// Initialize conversation state (e.g. from thread history).
  void initialize({Conversation? conversation}) {
    if (conversation != null) {
      _conversation = conversation;
      emit(TuiIdleState(messages: _conversation.messages));
    }
  }

  /// Send a user message and start the event processing loop.
  Future<void> sendMessage(String text) async {
    if (_isRunning) return;
    Loggers.app.info('Sending message (${text.length} chars)');

    // Initialize conversation if needed.
    if (_conversation.threadId.isEmpty) {
      _conversation = Conversation.empty(threadId: _threadId);
    }

    final userMessage = TextMessage.create(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      user: ChatUser.user,
      text: text,
    );
    _conversation = _conversation.withAppendedMessage(userMessage);

    _isRunning = true;
    try {
      await _startRun(depth: 0);
    } finally {
      _isRunning = false;
    }
  }

  /// Cancel the active stream.
  Future<void> cancelRun() async {
    Loggers.app.info('Run cancelled by user');
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _isRunning = false;
    _conversation = _conversation.withStatus(
      const Cancelled(reason: 'User cancelled'),
    );
    emit(TuiIdleState(messages: _conversation.messages));
  }

  /// Toggle reasoning pane visibility.
  void toggleReasoning() {
    _showReasoning = !_showReasoning;
    final current = state;
    if (current is TuiStreamingState) {
      emit(
        TuiStreamingState(
          messages: current.messages,
          conversation: current.conversation,
          streaming: current.streaming,
          reasoningText: current.reasoningText,
          showReasoning: _showReasoning,
        ),
      );
    }
  }

  Future<void> _startRun({required int depth}) async {
    Loggers.agui.info('Starting run (depth=$depth)');
    if (depth >= maxContinuationDepth) {
      Loggers.agui.warning('Circuit breaker at depth $depth');
      emit(
        TuiErrorState(
          messages: _conversation.messages,
          errorMessage:
              'Circuit breaker: exceeded $maxContinuationDepth continuation '
              'runs',
        ),
      );
      return;
    }

    try {
      final run = await _api.createRun(_roomId, _threadId);
      Loggers.agui.debug('Created run: ${run.id}');
      final aguiMessages = convertToAgui(_conversation.messages);

      final input = SimpleRunAgentInput(
        threadId: _threadId,
        runId: run.id,
        messages: aguiMessages,
        tools: _toolRegistry.toolDefinitions,
        state:
            _conversation.aguiState.isNotEmpty ? _conversation.aguiState : null,
      );

      var streaming = const AwaitingText() as StreamingState;
      var hadError = false;

      final eventStream = _agUiClient.runAgent(
        'rooms/$_roomId/agui/$_threadId/${run.id}',
        input,
      );

      final completer = Completer<void>();

      _streamSubscription = eventStream.listen(
        (event) {
          Loggers.agui.trace('Event: ${event.runtimeType}');
          final result = processEvent(_conversation, streaming, event);
          _conversation = result.conversation;
          streaming = result.streaming;

          // Extract reasoning text from streaming state.
          final reasoningText = switch (streaming) {
            AwaitingText(:final bufferedThinkingText) => bufferedThinkingText,
            TextStreaming(:final thinkingText) => thinkingText,
          };

          emit(
            TuiStreamingState(
              messages: _conversation.messages,
              conversation: _conversation,
              streaming: streaming,
              reasoningText: reasoningText.isNotEmpty ? reasoningText : null,
              showReasoning: _showReasoning,
            ),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          Loggers.agui
              .error('Stream error', error: error, stackTrace: stackTrace);
          hadError = true;
          emit(
            TuiErrorState(
              messages: _conversation.messages,
              errorMessage: error.toString(),
            ),
          );
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;
      _streamSubscription = null;

      // Don't continue after a stream error.
      if (hadError) return;

      // Check for pending tool calls after stream ends.
      final pendingTools = _conversation.toolCalls
          .where((tc) => tc.status == ToolCallStatus.pending)
          .toList();

      if (pendingTools.isNotEmpty) {
        Loggers.tool.info('${pendingTools.length} pending tool calls');
        await _executeToolsAndContinue(pendingTools, depth: depth);
      } else {
        emit(TuiIdleState(messages: _conversation.messages));
      }
    } on Exception catch (e, s) {
      Loggers.agui.error('Run failed', error: e, stackTrace: s);
      emit(
        TuiErrorState(
          messages: _conversation.messages,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _executeToolsAndContinue(
    List<ToolCallInfo> pendingTools, {
    required int depth,
  }) async {
    emit(
      TuiExecutingToolsState(
        messages: _conversation.messages,
        conversation: _conversation,
        pendingTools: pendingTools,
      ),
    );

    final executedTools = <ToolCallInfo>[];

    for (final tc in pendingTools) {
      Loggers.tool.info('Executing tool: ${tc.name}');
      // Mark as executing.
      _updateToolCallStatus(tc.id, ToolCallStatus.executing);

      try {
        final result = await _toolRegistry.execute(tc);
        Loggers.tool.debug('Tool ${tc.name} completed');
        executedTools.add(
          tc.copyWith(status: ToolCallStatus.completed, result: result),
        );
        _updateToolCallStatus(
          tc.id,
          ToolCallStatus.completed,
          result: result,
        );
      } on Exception catch (e) {
        Loggers.tool.error('Tool ${tc.name} failed', error: e);
        final errorResult = 'Error: $e';
        executedTools.add(
          tc.copyWith(status: ToolCallStatus.failed, result: errorResult),
        );
        _updateToolCallStatus(
          tc.id,
          ToolCallStatus.failed,
          result: errorResult,
        );
      }
    }

    // Append tool call message with results to conversation.
    final toolMessage = ToolCallMessage.fromExecuted(
      id: 'tools_${DateTime.now().millisecondsSinceEpoch}',
      toolCalls: executedTools,
    );
    _conversation = _conversation.withAppendedMessage(toolMessage);

    // Start continuation run.
    await _startRun(depth: depth + 1);
  }

  void _updateToolCallStatus(
    String toolCallId,
    ToolCallStatus status, {
    String? result,
  }) {
    final updatedToolCalls = _conversation.toolCalls.map((tc) {
      if (tc.id == toolCallId) {
        return tc.copyWith(status: status, result: result ?? tc.result);
      }
      return tc;
    }).toList();
    _conversation = _conversation.copyWith(toolCalls: updatedToolCalls);
  }

  @override
  Future<void> close() async {
    Loggers.app.debug('Cubit closing');
    await _streamSubscription?.cancel();
    return super.close();
  }
}
