import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:open_responses/open_responses.dart' as or;
import 'package:soliplex_completions/src/llm_event.dart';
import 'package:soliplex_completions/src/llm_provider.dart';
import 'package:soliplex_completions/src/llm_tool.dart';

/// LLM provider backed by open_responses.
///
/// Supports any provider that implements the OpenResponses spec:
/// Ollama, OpenAI, HuggingFace, LM Studio, OpenRouter, etc.
///
/// Implements [LlmProvider] for backwards compatibility with legacy
/// callers (Monty llmCompleter/llmChatCompleter). The primary API
/// is [chatStream] for streaming with native tool support.
class OpenResponsesLlmProvider implements LlmProvider {
  OpenResponsesLlmProvider._({
    required or.OpenResponsesClient client,
    required this.model,
    this.systemPrompt,
  }) : _client = client;

  /// Ollama (local).
  ///
  /// Pass [httpClient] to route through the Soliplex HTTP decorator chain
  /// (logging, platform adapters, etc.). Use `SoliplexHttpAdapter` to bridge.
  factory OpenResponsesLlmProvider.ollama({
    required String model,
    String baseUrl = 'http://localhost:11434/v1',
    String? systemPrompt,
    http.Client? httpClient,
  }) {
    return OpenResponsesLlmProvider._(
      client: or.OpenResponsesClient(
        config: or.OpenResponsesConfig(baseUrl: baseUrl),
        httpClient: httpClient,
      ),
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  /// OpenAI.
  factory OpenResponsesLlmProvider.openai({
    required String apiKey,
    String model = 'gpt-4o',
    String? systemPrompt,
    http.Client? httpClient,
  }) {
    return OpenResponsesLlmProvider._(
      client: or.OpenResponsesClient(
        config: or.OpenResponsesConfig(
          authProvider: or.BearerTokenProvider(apiKey),
        ),
        httpClient: httpClient,
      ),
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  /// OpenRouter.
  factory OpenResponsesLlmProvider.openrouter({
    required String apiKey,
    required String model,
    String? systemPrompt,
    http.Client? httpClient,
  }) {
    return OpenResponsesLlmProvider._(
      client: or.OpenResponsesClient(
        config: or.OpenResponsesConfig(
          baseUrl: 'https://openrouter.ai/api/v1',
          authProvider: or.BearerTokenProvider(apiKey),
        ),
        httpClient: httpClient,
      ),
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  /// Any OpenResponses-compatible provider.
  factory OpenResponsesLlmProvider.custom({
    required String baseUrl,
    required String model,
    String? apiKey,
    String? systemPrompt,
    http.Client? httpClient,
  }) {
    return OpenResponsesLlmProvider._(
      client: or.OpenResponsesClient(
        config: or.OpenResponsesConfig(
          baseUrl: baseUrl,
          authProvider: apiKey != null ? or.BearerTokenProvider(apiKey) : null,
        ),
        httpClient: httpClient,
      ),
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  final or.OpenResponsesClient _client;

  /// The model identifier.
  final String model;

  /// Optional default system prompt.
  final String? systemPrompt;

  // ---------------------------------------------------------------------------
  // Streaming API (primary)
  // ---------------------------------------------------------------------------

  /// Stream a chat completion with optional tools.
  ///
  /// Returns Soliplex domain events (not open_responses types).
  Stream<LlmEvent> chatStream({
    required List<LlmChatMessage> messages,
    List<LlmToolDef>? tools,
    String? systemPrompt,
    int? maxTokens,
    Future<void>? abortTrigger,
  }) async* {
    final input = _convertMessages(messages);
    final orTools = tools?.map(_convertTool).toList();
    final instructions = systemPrompt ?? this.systemPrompt;

    final request = or.CreateResponseRequest(
      model: model,
      input: input,
      instructions: instructions,
      tools: orTools,
      maxOutputTokens: maxTokens,
    );

    try {
      final stream = _client.responses.createStream(
        request,
        abortTrigger: abortTrigger,
      );

      await for (final event in stream) {
        final mapped = _mapStreamingEvent(event);
        if (mapped != null) yield mapped;
      }
    } on Object catch (e) {
      // Seal the ACL: prevent open_responses exception types from leaking.
      yield LlmError(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Non-streaming API (for tool calls if streaming is unreliable)
  // ---------------------------------------------------------------------------

  /// Send a chat completion with tools (non-streaming).
  ///
  /// Returns domain events synthesized from the complete response.
  /// Use this as fallback when streaming tool calls are unreliable
  /// (e.g., Ollama streaming `FunctionCallArgumentsDeltaEvent` null bug).
  Stream<LlmEvent> chatNonStreaming({
    required List<LlmChatMessage> messages,
    List<LlmToolDef>? tools,
    String? systemPrompt,
    int? maxTokens,
  }) async* {
    final input = _convertMessages(messages);
    final orTools = tools?.map(_convertTool).toList();
    final instructions = systemPrompt ?? this.systemPrompt;

    final request = or.CreateResponseRequest(
      model: model,
      input: input,
      instructions: instructions,
      tools: orTools,
      maxOutputTokens: maxTokens,
    );

    try {
      final response = await _client.responses.create(request);

      // Extract text output.
      final text = response.outputText;
      if (text != null && text.isNotEmpty) {
        yield LlmTextDelta(text);
        yield LlmTextDone(text);
      }

      // Extract tool calls.
      for (final call in response.functionCalls) {
        yield LlmToolCallStart(callId: call.callId, name: call.name);
        yield LlmToolCallArgsDelta(
          callId: call.callId,
          delta: call.arguments,
        );
        yield LlmToolCallDone(
          callId: call.callId,
          arguments: call.arguments,
        );
      }

      yield const LlmDone();
    } on Object catch (e) {
      yield LlmError(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy LlmProvider interface
  // ---------------------------------------------------------------------------

  @override
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final input = <or.Item>[or.MessageItem.userText(prompt)];

    final request = or.CreateResponseRequest(
      model: model,
      input: input,
      instructions: systemPrompt ?? this.systemPrompt,
      maxOutputTokens: maxTokens,
    );

    final response = await _client.responses.create(request);
    return response.outputText ?? '';
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final typed = messages
        .map(
          (m) => switch (m.role) {
            'system' => LlmSystemMessage(m.content) as LlmChatMessage,
            'assistant' => LlmAssistantMessage(content: m.content),
            _ => LlmUserMessage(m.content),
          },
        )
        .toList();
    final input = _convertMessages(typed);

    final request = or.CreateResponseRequest(
      model: model,
      input: input,
      instructions: systemPrompt ?? this.systemPrompt,
      maxOutputTokens: maxTokens,
    );

    final response = await _client.responses.create(request);
    return response.outputText ?? '';
  }

  /// Closes the underlying HTTP client.
  void close() => _client.close();

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  List<or.Item> _convertMessages(List<LlmChatMessage> messages) {
    final items = <or.Item>[];
    for (final m in messages) {
      switch (m) {
        case LlmUserMessage(:final content):
          items.add(or.MessageItem.userText(content));
        case LlmAssistantMessage(:final content, :final toolCalls):
          if (content != null && content.isNotEmpty) {
            items.add(or.MessageItem.assistantText(content));
          }
          if (toolCalls != null) {
            for (final tc in toolCalls) {
              items.add(
                or.FunctionCallItem(
                  callId: tc.id,
                  name: tc.name,
                  arguments: tc.arguments,
                ),
              );
            }
          }
        case LlmToolResultMessage(:final callId, :final output):
          items.add(
            or.FunctionCallOutputItem.string(callId: callId, output: output),
          );
        case LlmSystemMessage(:final content):
          items.add(or.MessageItem.systemText(content));
      }
    }
    return items;
  }

  static or.FunctionTool _convertTool(LlmToolDef tool) {
    return or.FunctionTool(
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters,
    );
  }

  static LlmEvent? _mapStreamingEvent(or.StreamingEvent event) {
    return switch (event) {
      or.OutputTextDeltaEvent(:final delta) => LlmTextDelta(delta),
      or.OutputTextDoneEvent(:final text) => LlmTextDone(text),
      or.FunctionCallArgumentsDeltaEvent(:final callId, :final delta) =>
        LlmToolCallArgsDelta(callId: callId, delta: delta),
      or.FunctionCallArgumentsDoneEvent(:final callId, :final arguments) =>
        LlmToolCallDone(callId: callId, arguments: arguments),
      or.OutputItemAddedEvent(:final item) => switch (item) {
          or.FunctionCallOutputItemResponse(:final callId, :final name) =>
            LlmToolCallStart(callId: callId, name: name),
          _ => null,
        },
      or.ResponseCompletedEvent() => const LlmDone(),
      or.ResponseFailedEvent(:final response) =>
        LlmError(response.error?.message ?? 'Response failed'),
      or.ErrorEvent(:final error) => LlmError(error.message),
      _ => null, // Ignore events we don't need (reasoning, refusal, etc.)
    };
  }
}
