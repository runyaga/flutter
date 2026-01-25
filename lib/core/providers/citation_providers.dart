import 'package:soliplex_frontend/core/models/agui_features/ask_history.dart'
    as ask_history_models;

/// Re-export Citation with a label getter extension for widgets.
///
/// The base Citation model comes from ask_history.dart (generated from schema).
/// We extend it here with UI convenience methods.
extension CitationLabel on ask_history_models.Citation {
  /// Returns a user-friendly label for the citation.
  ///
  /// Priority:
  /// 1. Document title if available
  /// 2. Page number if available
  /// 3. 'Source' as fallback
  String get label {
    if (documentTitle != null && documentTitle!.isNotEmpty) {
      return documentTitle!;
    }
    if (pageNumbers != null && pageNumbers!.isNotEmpty) {
      return 'Page ${pageNumbers!.first}';
    }
    return 'Source';
  }
}

/// Type alias for convenience - uses the schema-generated Citation model.
typedef Citation = ask_history_models.Citation;

/// Extracts citations from an ask_history state snapshot.
///
/// The backend sends ask_history as:
/// ```json
/// {
///   "ask_history": {
///     "questions": [
///       {
///         "index": 0,
///         "timestamp": "...",
///         "question": "...",
///         "response": "...",
///         "citations": [...]
///       }
///     ]
///   }
/// }
/// ```
///
/// This function extracts all citations from the questions list.
List<Citation> extractCitationsFromState(Map<String, dynamic>? stateSnapshot) {
  if (stateSnapshot == null) return [];

  final askHistoryData = stateSnapshot['ask_history'];
  if (askHistoryData == null) return [];

  // Parse the ask_history structure (it's an object with 'questions' key)
  if (askHistoryData is! Map<String, dynamic>) return [];

  final askHistory = ask_history_models.AskHistory.fromJson(askHistoryData);

  final citations = <Citation>[];
  final questions = askHistory.questions;
  if (questions != null) {
    for (final question in questions) {
      final questionCitations = question.citations;
      if (questionCitations != null) {
        for (final c in questionCitations) {
          citations.add(c);
        }
      }
    }
  }
  return citations;
}

/// Extracts citations for a specific message based on turn index or timestamp.
///
/// MAPPING STRATEGY:
/// 1. Primary: Match by turn index (ask_history[i].index == turnIndex)
/// 2. Fallback: Match by timestamp (within 5 seconds of message creation)
///
/// The index field is set by the backend's ask_with_rich_citations tool
/// to enable precise frontend mapping.
///
/// Note: The current generated AskHistory model doesn't expose index/timestamp
/// fields on QuestionResponseCitations. Until the model is updated, this uses
/// raw JSON access for the mapping fields.
List<Citation> extractCitationsForMessage({
  required Map<String, dynamic>? stateSnapshot,
  required int? messageTurnIndex,
  required DateTime messageCreatedAt,
}) {
  if (stateSnapshot == null) return [];

  final askHistoryData = stateSnapshot['ask_history'];
  if (askHistoryData == null) return [];
  if (askHistoryData is! Map<String, dynamic>) return [];

  // Access questions list directly from JSON to get index/timestamp fields
  final questionsList = askHistoryData['questions'] as List?;
  if (questionsList == null) return [];

  final citations = <Citation>[];

  for (final entry in questionsList) {
    if (entry is! Map<String, dynamic>) continue;

    final entryIndex = entry['index'] as int?;
    final entryTimestamp = entry['timestamp'] as String?;

    // Primary match: by turn index
    bool matches = messageTurnIndex != null &&
        entryIndex != null &&
        entryIndex == messageTurnIndex;

    // Fallback match: by timestamp (within 5 seconds)
    if (!matches && entryTimestamp != null) {
      try {
        final entryTime = DateTime.parse(entryTimestamp);
        final diff = entryTime.difference(messageCreatedAt).abs();
        matches = diff.inSeconds <= 5;
      } catch (_) {
        // Invalid timestamp format, skip fallback
      }
    }

    if (matches) {
      final entryCitations = entry['citations'] as List?;
      if (entryCitations != null) {
        for (final c in entryCitations) {
          if (c is Map<String, dynamic>) {
            citations.add(Citation.fromJson(c));
          }
        }
      }
    }
  }

  return citations;
}

/// Family provider for citations associated with a specific message.
///
/// Returns citations from the ask_history state that match the given message.
/// Matching is done by message ID (which corresponds to turn index).
///
/// **Usage**:
/// ```dart
/// final citations = ref.watch(citationsForMessageProvider(roomId, messageId));
/// ```
///
/// **Note**: The roomId parameter is currently unused but kept for API
/// compatibility. The citation state is scoped to the active run.
List<Citation> citationsForMessageProvider(String roomId, String messageId) {
  // For now, return empty list - citations require mission state integration
  // which will be wired up when the active_run_provider exposes ask_history.
  // This stub allows the app to compile while the full integration is completed.
  return [];
}
