import 'package:flutter_test/flutter_test.dart';

/// Citation data from ask_history - copy of the model for testing.
/// This mirrors the Citation class in citation_providers.dart.
class Citation {
  final String documentId;
  final String chunkId;
  final List<int> pageNumbers;
  final String content;
  final String? documentTitle;

  Citation({
    required this.documentId,
    required this.chunkId,
    required this.pageNumbers,
    required this.content,
    this.documentTitle,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      documentId: json['document_id'] as String? ?? '',
      chunkId: json['chunk_id'] as String? ?? '',
      pageNumbers: (json['page_numbers'] as List?)?.cast<int>() ?? [],
      content: json['content'] as String? ?? '',
      documentTitle: json['document_title'] as String?,
    );
  }

  String get label {
    if (documentTitle != null && documentTitle!.isNotEmpty) {
      return documentTitle!;
    }
    if (pageNumbers.isNotEmpty) {
      return 'Page ${pageNumbers.first}';
    }
    return 'Source';
  }
}

void main() {
  group('Citation', () {
    test('fromJson creates Citation correctly', () {
      final json = {
        'document_id': 'doc-123',
        'chunk_id': 'chunk-456',
        'page_numbers': [1, 2, 3],
        'content': 'Sample content text',
        'document_title': 'Test Document',
      };

      final citation = Citation.fromJson(json);

      expect(citation.documentId, equals('doc-123'));
      expect(citation.chunkId, equals('chunk-456'));
      expect(citation.pageNumbers, equals([1, 2, 3]));
      expect(citation.content, equals('Sample content text'));
      expect(citation.documentTitle, equals('Test Document'));
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{
        'document_id': 'doc-123',
        'chunk_id': 'chunk-456',
      };

      final citation = Citation.fromJson(json);

      expect(citation.documentId, equals('doc-123'));
      expect(citation.chunkId, equals('chunk-456'));
      expect(citation.pageNumbers, isEmpty);
      expect(citation.content, equals(''));
      expect(citation.documentTitle, isNull);
    });

    test('fromJson handles null values gracefully', () {
      final json = <String, dynamic>{
        'document_id': null,
        'chunk_id': null,
        'page_numbers': null,
        'content': null,
        'document_title': null,
      };

      final citation = Citation.fromJson(json);

      expect(citation.documentId, isEmpty);
      expect(citation.chunkId, isEmpty);
      expect(citation.pageNumbers, isEmpty);
      expect(citation.content, isEmpty);
      expect(citation.documentTitle, isNull);
    });

    test('label returns documentTitle when available', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'c1',
        pageNumbers: [42],
        content: 'text',
        documentTitle: 'Research Paper',
      );

      expect(citation.label, equals('Research Paper'));
    });

    test('label returns page number when no title', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'c1',
        pageNumbers: [42],
        content: 'text',
      );

      expect(citation.label, equals('Page 42'));
    });

    test('label returns Source when no title or page', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'c1',
        pageNumbers: [],
        content: 'text',
      );

      expect(citation.label, equals('Source'));
    });

    test('label returns Source when title is empty string', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'c1',
        pageNumbers: [],
        content: 'text',
        documentTitle: '',
      );

      expect(citation.label, equals('Source'));
    });
  });

  group('Citation mapping logic', () {
    // Helper function to simulate citationsForMessage logic
    // This mirrors the logic in citationsForMessageProvider
    List<Citation> extractCitationsForMessage({
      required Map<String, dynamic> stateSnapshot,
      required int? turnIndex,
      required DateTime? timestamp,
    }) {
      final askHistory = stateSnapshot['ask_history'] as List?;
      if (askHistory == null) return [];

      final citations = <Citation>[];
      for (final entry in askHistory) {
        if (entry is! Map<String, dynamic>) continue;

        final entryIndex = entry['index'] as int?;
        final entryTimestamp = entry['timestamp'] as String?;

        // Primary match: by turn index
        bool matches =
            turnIndex != null && entryIndex != null && entryIndex == turnIndex;

        // Fallback match: by timestamp (within 5 seconds)
        if (!matches && entryTimestamp != null && timestamp != null) {
          try {
            final entryTime = DateTime.parse(entryTimestamp);
            final diff = entryTime.difference(timestamp).abs();
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

    test('maps citations by turn index (primary strategy)', () {
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 2,
            'query': 'What is X?',
            'citations': [
              {
                'document_id': 'doc-1',
                'chunk_id': 'c1',
                'page_numbers': [1],
                'content': 'Citation text',
              }
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 2,
        timestamp: null,
      );

      expect(citations.length, equals(1));
      expect(citations[0].documentId, equals('doc-1'));
    });

    test('falls back to timestamp matching when no index match', () {
      final now = DateTime.now();
      final stateSnapshot = {
        'ask_history': [
          {
            'timestamp': now.toIso8601String(),
            'query': 'What is X?',
            'citations': [
              {
                'document_id': 'doc-2',
                'chunk_id': 'c2',
                'page_numbers': [5],
                'content': 'Timestamp-matched content',
              }
            ]
          }
        ]
      };

      // Message with timestamp within 5 seconds, no turnIndex match
      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: null,
        timestamp: now.add(const Duration(seconds: 2)),
      );

      expect(citations.length, equals(1));
      expect(citations[0].documentId, equals('doc-2'));
    });

    test('timestamp match fails if beyond 5 seconds', () {
      final now = DateTime.now();
      final stateSnapshot = {
        'ask_history': [
          {
            'timestamp': now.toIso8601String(),
            'query': 'What is X?',
            'citations': [
              {
                'document_id': 'doc-2',
                'chunk_id': 'c2',
                'page_numbers': [5],
                'content': 'Content',
              }
            ]
          }
        ]
      };

      // Message with timestamp beyond 5 seconds
      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: null,
        timestamp: now.add(const Duration(seconds: 10)),
      );

      expect(citations, isEmpty);
    });

    test('returns empty when no match found', () {
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 5,
            'query': 'X?',
            'citations': [
              {'document_id': 'd1', 'chunk_id': 'c1'}
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 99,
        timestamp: null,
      );

      expect(citations, isEmpty);
    });

    test('returns multiple citations for same message', () {
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 3,
            'query': 'Complex query',
            'citations': [
              {'document_id': 'doc-1', 'chunk_id': 'c1', 'content': 'First'},
              {'document_id': 'doc-2', 'chunk_id': 'c2', 'content': 'Second'},
              {'document_id': 'doc-3', 'chunk_id': 'c3', 'content': 'Third'},
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 3,
        timestamp: null,
      );

      expect(citations.length, equals(3));
      expect(citations[0].documentId, equals('doc-1'));
      expect(citations[1].documentId, equals('doc-2'));
      expect(citations[2].documentId, equals('doc-3'));
    });

    test('handles citations with missing index field (timestamp fallback)', () {
      final now = DateTime.now();
      final stateSnapshot = {
        'ask_history': [
          {
            // No index field
            'timestamp': now.toIso8601String(),
            'query': 'What is Y?',
            'citations': [
              {
                'document_id': 'doc-no-index',
                'chunk_id': 'c1',
                'content': 'Content without index',
              }
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1, // Won't match because no index in entry
        timestamp:
            now.add(const Duration(seconds: 1)), // Should match timestamp
      );

      expect(citations.length, equals(1));
      expect(citations[0].documentId, equals('doc-no-index'));
    });

    test('index match takes precedence over timestamp on same entry', () {
      final now = DateTime.now();
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 1,
            // Timestamp is far in the past, would NOT match by timestamp alone
            'timestamp':
                now.subtract(const Duration(minutes: 10)).toIso8601String(),
            'query': 'First query',
            'citations': [
              {'document_id': 'doc-by-index', 'chunk_id': 'c1'}
            ]
          },
          {
            'index': 99,
            // This timestamp would match but index doesn't, so no match
            'timestamp':
                now.subtract(const Duration(minutes: 20)).toIso8601String(),
            'query': 'Second query',
            'citations': [
              {'document_id': 'doc-no-match', 'chunk_id': 'c2'}
            ]
          }
        ]
      };

      // Should match by index=1 on first entry
      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: now,
      );

      expect(citations.length, equals(1));
      expect(citations[0].documentId, equals('doc-by-index'));
    });

    test('returns empty when ask_history is null', () {
      final stateSnapshot = <String, dynamic>{};

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: null,
      );

      expect(citations, isEmpty);
    });

    test('returns empty when ask_history is empty', () {
      final stateSnapshot = {'ask_history': <dynamic>[]};

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: null,
      );

      expect(citations, isEmpty);
    });

    test('handles entry with null citations list', () {
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 1,
            'query': 'Query without citations',
            'citations': null,
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: null,
      );

      expect(citations, isEmpty);
    });

    test('handles entry with empty citations list', () {
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 1,
            'query': 'Query with empty citations',
            'citations': <dynamic>[],
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: null,
      );

      expect(citations, isEmpty);
    });

    test('collects citations from multiple matching entries', () {
      final now = DateTime.now();
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 5,
            'timestamp': now.toIso8601String(),
            'citations': [
              {'document_id': 'doc-a', 'chunk_id': 'c1'}
            ]
          },
          {
            'index': 5, // Same index (shouldn't happen but test resilience)
            'timestamp': now.add(const Duration(seconds: 1)).toIso8601String(),
            'citations': [
              {'document_id': 'doc-b', 'chunk_id': 'c2'}
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 5,
        timestamp: null,
      );

      // Should collect from both entries
      expect(citations.length, equals(2));
      expect(citations[0].documentId, equals('doc-a'));
      expect(citations[1].documentId, equals('doc-b'));
    });

    test('skips non-map entries in ask_history', () {
      final stateSnapshot = {
        'ask_history': [
          'invalid string entry',
          123,
          null,
          {
            'index': 1,
            'citations': [
              {'document_id': 'valid-doc', 'chunk_id': 'c1'}
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: null,
      );

      expect(citations.length, equals(1));
      expect(citations[0].documentId, equals('valid-doc'));
    });

    test('skips non-map citations in list', () {
      final stateSnapshot = {
        'ask_history': [
          {
            'index': 1,
            'citations': [
              'invalid string citation',
              123,
              null,
              {'document_id': 'valid-doc', 'chunk_id': 'c1'}
            ]
          }
        ]
      };

      final citations = extractCitationsForMessage(
        stateSnapshot: stateSnapshot,
        turnIndex: 1,
        timestamp: null,
      );

      expect(citations.length, equals(1));
      expect(citations[0].documentId, equals('valid-doc'));
    });
  });
}
